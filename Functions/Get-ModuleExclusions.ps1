function Get-ModuleExclusions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,

        [object]$ModuleFile
    )

    $exclusions = New-Object 'PSObject'

    $exclusions | Add-Member -Type 'NoteProperty' -Name 'Directories' -Value @()

    $exclusions | Add-Member -Type 'NoteProperty' -Name 'Files' -Value @()

    if ($moduleFile) {
        $moduleSpec = Import-PSData -Path $moduleFile

        if (Get-RelativePath $moduleFile -Root $RootPath -EA 0) {
            Write-Verbose "Excluding 'module.psd1'."
            $exclusions.Files += $moduleFile
        }

        if ($moduleSpec.Source) {
            $moduleSource = (Resolve-Path (Join-Path $root.Path $moduleSpec.Source)).Path
            $moduleSourceRelativePath = Get-RelativePath $moduleSpec.Source -Root $RootPath -EA 0
            if ($moduleSourceRelativePath) {
                Write-Verbose "Excluding source directory '$($moduleSourceRelativePath)'."
                $Exclusions.Directories += $moduleSource
            }
        }
    }

    if (Test-Path "$($RootPath)\.git") {
        Write-Verbose "Excluding '.git' directory."
        $exclusions.Directories += "$($RootPath)\.git"

        if (Test-Path "$($RootPath)\.gitignore") {
            Get-Content "$($RootPath)\.gitignore" | ForEach-Object {
                $exclusions.Files += "$($RootPath)\.gitignore"
                if ($_.EndsWith('/')) {
                    Write-Verbose "Checking path '$($RootPath)\$($_.Substring(0, $_.Length - 1))'..."
                    Resolve-Path "$($RootPath)\$($_.Substring(0, $_.Length - 1))" -EA 0 | ForEach-Object {
                        $relPath = Get-RelativePath $_.Path -Root $RootPath
                        Write-Verbose "Excluding folder '$($relPath)'."
                        $exclusions.Directories += $_.Path
                    }
                } else {
                    Write-Verbose "Checking path '$($RootPath)\$($_)'..."
                    Resolve-Path "$($RootPath)\$($_)" -EA 0 | ForEach-Object {
                        $relPath = Get-RelativePath $_.Path -Root $RootPath
                        Write-Verbose "Excluding file '$($relPath)'."
                        $exclusions.Files += $_.Path
                    }
                }
            }
        }
    }

    if (Test-Path "$($RootPath)\.moignore") {
        Get-Content "$($RootPath)\.moignore" | ForEach-Object {
            $exclusions.Files += "$($RootPath)\.moignore"
            if ($_.EndsWith('/')) {
                Write-Verbose "Checking path '$($RootPath)\$($_.Substring(0, $_.Length - 1))'..."
                Resolve-Path "$($RootPath)\$($_.Substring(0, $_.Length - 1))" -EA 0 | ForEach-Object {
                    $relPath = Get-RelativePath $_.Path -Root $RootPath
                    Write-Verbose "Excluding folder '$($relPath)'."
                    $exclusions.Directories += $_.Path
                }
            } else {
                Write-Verbose "Checking path '$($RootPath)\$($_)'..."
                Resolve-Path "$($RootPath)\$($_)" -EA 0 | ForEach-Object {
                    $relPath = Get-RelativePath $_.Path -Root $RootPath
                    Write-Verbose "Excluding file '$($relPath)'."
                    $exclusions.Files += $_.Path
                }
            }
        }
    }

    return $exclusions
}
