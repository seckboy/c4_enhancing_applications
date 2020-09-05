[CmdletBinding()]
param()

function Get-MaxInfoFromSqlServer {
    [CmdletBinding()]
    param()

    $sqlServerKeyName = 'Software\Microsoft\Microsoft SQL Server'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $sqlServerKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $verSpecificRootDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$sqlServerKeyName\$version" -Value 'VerSpecificRootDir'
            if (!$verSpecificRootDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($verSpecificRootDir, 'Dac', 'bin', 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromSqlServerDtaf {
    [CmdletBinding()]
    param()

    $dtafKeyName = 'Software\Microsoft\Microsoft SQL Server\Data-Tier Application Framework'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $dtafKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
       foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$dtafKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($installDir, 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromVisualStudio_15_0 {
    [CmdletBinding()]
    param()

    $vs15 = Get-VisualStudio -MajorVersion 15
    if ($vs15 -and $vs15.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder15 = $vs15.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder15, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio_16_0 {
    [CmdletBinding()]
    param()

    $vs16 = Get-VisualStudio -MajorVersion 16
    if ($vs16 -and $vs16.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder16 = $vs16.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder16, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio {
    [CmdletBinding()]
    param()

    $visualStudioKeyName = 'Software\Microsoft\VisualStudio'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $visualStudioKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $d = 0
                if (([decimal]::TryParse($_, [ref]$d))) {
                    $d
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$visualStudioKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for the DAC directory.
            $dacDirectory = [System.IO.Path]::Combine($installDir, 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
            $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

            if($sqlPacakgeInfo -and $sqlPacakgeInfo.File)
           {
                return $sqlPacakgeInfo
            }
        }
    }
}

function Get-SqlPacakgeFromDacDirectory {
    [CmdletBinding()]
    param([string] $dacDirectory)


    if (!(Test-Container -LiteralPath $dacDirectory)) {
        return
    }

    # Get the DAC version folders.
    $dacVersions =
        Get-ChildItem -LiteralPath $dacDirectory |
        Where-Object { $_ -is [System.IO.DirectoryInfo] }
        # Filter to include integer key names only.
        ForEach-Object {
            $i = 0
            if (([int]::TryParse($_.Name, [ref]$i))) {
                $i
            }
        } |
        Sort-Object -Descending
    foreach ($dacVersion in $dacVersions) {
        # Test for SqlPackage.exe.
        $file = [System.IO.Path]::Combine($dacDirectory, $dacVersion, 'SqlPackage.exe')
        if (!(Test-Leaf -LiteralPath $file)) {
            continue
        }

        # Return the info as an object with properties (for sorting).
        return New-Object psobject -Property @{
            File = $file
            Version = $dacVersion
        }
    }
}

$sqlPackageInfo = @( )
$sqlPackageInfo += (Get-MaxInfoFromSqlServer)
$sqlPackageInfo += (Get-MaxInfoFromSqlServerDtaf)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_15_0)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_16_0)
$sqlPackageInfo |
    Sort-Object -Property Version -Descending |
    Select -First 1 |
    ForEach-Object { Write-Capability -Name 'SqlPackage' -Value $_.File }

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAAYjQECLdwr5CZ
# E6oAdxVrEIBBc3bCEwlIDegfA3go66CCDYEwggX/MIID56ADAgECAhMzAAABh3IX
# chVZQMcJAAAAAAGHMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAwMzA0MTgzOTQ3WhcNMjEwMzAzMTgzOTQ3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOt8kLc7P3T7MKIhouYHewMFmnq8Ayu7FOhZCQabVwBp2VS4WyB2Qe4TQBT8aB
# znANDEPjHKNdPT8Xz5cNali6XHefS8i/WXtF0vSsP8NEv6mBHuA2p1fw2wB/F0dH
# sJ3GfZ5c0sPJjklsiYqPw59xJ54kM91IOgiO2OUzjNAljPibjCWfH7UzQ1TPHc4d
# weils8GEIrbBRb7IWwiObL12jWT4Yh71NQgvJ9Fn6+UhD9x2uk3dLj84vwt1NuFQ
# itKJxIV0fVsRNR3abQVOLqpDugbr0SzNL6o8xzOHL5OXiGGwg6ekiXA1/2XXY7yV
# Fc39tledDtZjSjNbex1zzwSXAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhov4ZyO96axkJdMjpzu2zVXOJcsw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDU4Mzg1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAixmy
# S6E6vprWD9KFNIB9G5zyMuIjZAOuUJ1EK/Vlg6Fb3ZHXjjUwATKIcXbFuFC6Wr4K
# NrU4DY/sBVqmab5AC/je3bpUpjtxpEyqUqtPc30wEg/rO9vmKmqKoLPT37svc2NV
# BmGNl+85qO4fV/w7Cx7J0Bbqk19KcRNdjt6eKoTnTPHBHlVHQIHZpMxacbFOAkJr
# qAVkYZdz7ikNXTxV+GRb36tC4ByMNxE2DF7vFdvaiZP0CVZ5ByJ2gAhXMdK9+usx
# zVk913qKde1OAuWdv+rndqkAIm8fUlRnr4saSCg7cIbUwCCf116wUJ7EuJDg0vHe
# yhnCeHnBbyH3RZkHEi2ofmfgnFISJZDdMAeVZGVOh20Jp50XBzqokpPzeZ6zc1/g
# yILNyiVgE+RPkjnUQshd1f1PMgn3tns2Cz7bJiVUaqEO3n9qRFgy5JuLae6UweGf
# AeOo3dgLZxikKzYs3hDMaEtJq8IP71cX7QXe6lnMmXU/Hdfz2p897Zd+kU+vZvKI
# 3cwLfuVQgK2RZ2z+Kc3K3dRPz2rXycK5XCuRZmvGab/WbrZiC7wJQapgBodltMI5
# GMdFrBg9IeF7/rP4EqVQXeKtevTlZXjpuNhhjuR+2DMt/dWufjXpiW91bo3aH6Ea
# jOALXmoxgltCp1K7hrS6gmsvj94cLRf50QQ4U8Qwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVZzCCFWMCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAYdyF3IVWUDHCQAAAAABhzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgpdGVQ1vJ
# KBrY2+Qj5T0tLoY4YucPgGH6/W+XYzlfDZAwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBlUn/2p/UK5zobo5xOh1wxw99Sud69NHE6v52ZDsvO
# 55TkDsheUMTKo/ZPQ10S+cfR1I7WutXNH/2WapWosueqNzsHYONehJxCrgwm5Oyi
# YwKLvgddaHhXNrQNpD+tRyIg1FJ6qsc8QWMWLspEdkDX1XbrZgxl129ZvRAa8qXj
# +EpGNiDi7O/BhI9Vm1Q13V1tJiyq8CTqpNFZeY+onecztVcGgbb6rvTuA7S0lEOm
# 8MXg961giSiHvJRawL1shsABgqBxw9q2JIuHRWKqVAfX2vdrIXb31SBMHrMsy7Vc
# zvVAZUHmgUOQ2iVmTllK+ph8ek4HWPEjUuXRUNwSIAYMoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIPPk4Ox584V1qwEK0NvO5xiM3BZASzoDDadoUe4m
# 1NWRAgZfO/E7t9oYEzIwMjAwODI2MTczNjA0LjE4NlowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpDNEJELUUzN0YtNUZGQzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABIziw5K3YWpCdAAAA
# AAEjMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTQ1NloXDTIxMDMxNzAxMTQ1Nlowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpDNEJE
# LUUzN0YtNUZGQzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ280MmwZKXcAS7x2ZvA
# 4TOOCzw+63Xs9ULGWtdZDN3Vl+aGQEsMwErIkgzQi0fTO0sOD9N3hO1HaTWHoS80
# N/Qb6oLR2WCZkv/VM4WFnThOv3yA5zSt+vuKNwrjEHFC0jlMDCJqaU7St6WJbl/k
# AP5sgM0qtpEEQhxtVaf8IoV5lq8vgMJNr30O4rqLYEi/YZWQZYwQHAiVMunCYpJi
# ccnNONRRdg2D3Tyu22eEJwPQP6DkeEioMy9ehMmBrkjADVOgQV+T4mir+hAJeINy
# sps6wgRO5qjuV5+jvczNQa1Wm7jxsqBv04GClIp5NHvrXQmZ9mpZdj3rjxFuZbKj
# d3ECAwEAAaOCARswggEXMB0GA1UdDgQWBBSB1GwUgNONG/kRwrBo3hkV+AyeHjAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQBb5QG3qlfoW6r1V4lT+kO8LUzF32S3
# fUfgn/S1QQBPzORs/6ujj09ytHWNDfOewwkSya1f8S9e+BbnXknH5l3R6nS2BkRT
# ANtTmXxvMLTCyveYe/JQIfos+Z3iJ0b1qHDSnEj6Qmdf1MymrPAk5jxhxhiiXlwI
# LUjvH56y7rLHxK0wnsH12EO9MnkaSNXJNCmSmfgUEkDNzu53C39l6XNRAPauz2/W
# slIUZcX3NDCMgv5hZi2nhd99HxyaJJscn1f8hZXA++f1HNbq8bdkh3OYgRnNr7Qd
# nO+Guvtu3dyGqYdQMMGPnAt4L7Ew9ykjy0Uoz64/r0SbQIRYty5eM9M3MIIGcTCC
# BFmgAwIBAgIKYQmBKgAAAAAAAjANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJv
# b3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcN
# MjUwNzAxMjE0NjU1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0
# VBDVpQoAgoX77XxoSyxfxcPlYcJ2tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEw
# RA/xYIiEVEMM1024OAizQt2TrNZzMFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQe
# dGFnkV+BVLHPk0ySwcSmXdFhE24oxhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKx
# Xf13Hz3wV3WsvYpCTUBR0Q+cBj5nf/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4G
# kbaICDXoeByw6ZnNPOcvRLqn9NxkvaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEA
# AaOCAeYwggHiMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7
# fEYbxTNoWoVtVTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0g
# AQH/BIGVMIGSMIGPBgkrBgEEAYI3LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9QS0kvZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYB
# BQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUA
# bQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOh
# IW+z66bM9TG+zwXiqf76V20ZMLPCxWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS
# +7lTjMz0YBKKdsxAQEGb3FwX/1z5Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlK
# kVIArzgPF/UveYFl2am1a+THzvbKegBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon
# /VWvL/625Y4zu2JfmttXQOnxzplmkIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOi
# PPp/fZZqkHimbdLhnPkd/DjYlPTGpQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/
# fmNZJQ96LjlXdqJxqgaKD4kWumGnEcua2A5HmoDF0M2n0O99g/DhO3EJ3110mCII
# YdqwUB5vvfHhAN/nMQekkzr3ZUd46PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0
# cs0d9LiFAR6A+xuJKlQ5slvayA1VmXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7a
# KLixqduWsqdCosnPGUFN4Ib5KpqjEWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQ
# cdeh0sVV42neV8HR3jDA/czmTfsNv11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+
# NR4Iuto229Nfj950iEkSoYIC0jCCAjsCAQEwgfyhgdSkgdEwgc4xCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBP
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpD
# NEJELUUzN0YtNUZGQzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAuhdmjeDinhfC7gw1KBCeM/v7V4GggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOLw+3UwIhgPMjAyMDA4MjYxOTE3MDlaGA8yMDIwMDgyNzE5MTcwOVowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA4vD7dQIBADAKAgEAAgI4JwIB/zAHAgEAAgIRlDAK
# AgUA4vJM9QIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBADkX4+Tsfa83II33
# kXdMKbwn2ibFskd+akTWaYWIUOXJGRR8Q4Uo3WBF4rlnEfxDct9lUXYiGuXlrsXh
# +bRpYWTu3p19Hs3EFCiizC71INdhZajEue6BZhhHM/Q3hT/fwipapMAUQ8z2oEdj
# +0goiSZEgujb9cHsXOHVe4U87ylIMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEjOLDkrdhakJ0AAAAAASMwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQggjlRVSNwMho/z2iurIYkA72Sws1XMF32lAVZsME71L8wgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCARmjODP/tEzMQNo6OsxKQADL8pwKJkM5YnXKrq
# +xWBszCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# Iziw5K3YWpCdAAAAAAEjMCIEIElVoDs18gwHddQTfElrkf7qKK5xZRgTUhSy+ghk
# 4TtzMA0GCSqGSIb3DQEBCwUABIIBAHPQhJZN6bGUpCYXndQV3BzuW7dleNypGSLN
# /d9RxhSEtVIa5N2RJilxHec8cCrgI2RS8wURGysnddcB3653yazLmYKmd60xd4go
# tesgXCGfTvgUQXynCmVEQUSrXKDjWw1JilA2CYr2zOTYsVyVFdiASkv316sDeaUE
# ND68rCrq+X17F4K5W96jw6Q0Puy4apa6FPqzjtgBPR2YBEhawNxj/WzWC9OzKOWD
# D7pxxmdVrF1kEGH7UPt6BXd+CggnOziGFWTIjR37OqxvEN339vvV+HYvVuw/YpPp
# wqn7gvY7yUma7a/T6qD2wtzy0krKqiHKgjyPx7as0m0lYjZD5S0=
# SIG # End signature block
