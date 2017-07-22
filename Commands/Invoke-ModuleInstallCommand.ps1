<#

.SYNOPSIS
Installs a module.

#>
function Invoke-ModuleInstallCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name
    )

    Write-Verbose "Searching for module root from '$($PWD.Path)'..."

    $root = Find-ModuleRoot

    if ($root) {
        Write-Verbose "Found module root '$($root)'."

        Write-Message "Searching for package '$($Name)'..."
        $package = Find-Package -Name $Name -Provider 'NuGet'

        if ($package) {
            $tempFolder = Get-TempFolder

            Write-Message "Downloading package $($package.Name)@$($package.Version)..."
            $packages = $package | Save-Package -Path $tempFolder -Provider 'NuGet'

            $packagesToUnpack = [array]($packages | Where-Object {
                Write-Message "Downloaded package $($_.PackageFilename)."

                if (Test-Path "$($root)\Modules\$($_.Name)\$($_.Version)") {
                    Write-Message "Package $($_.Name)@$($_.Version) is already installed."
                    return $false
                }

                return $true
            })

            if ($packagesToUnpack.Count -gt 0) {
                $modulesFolder = "$($root)\Modules"

                $modulesFolderHash = $modulesFolder.ToLower() | Get-Hash -OutputType 'Bytes'

                $modulesFolderTempName = [Convert]::ToBase64String($modulesFolderHash)

                if (Test-Path "$tempFolder\.staging\$modulesFolderTempName") {
                    Write-Verbose "Cleaning up old temp directory..."
                    Remove-Item "$tempFolder\.staging\$modulesFolderTempName" -Force -Recurse -Confirm:$false | Out-Null
                }

                mkdir "$tempFolder\.staging\$modulesFolderTempName" | Out-Null

                $packagesToUnpack | ForEach-Object {
                    $nupkgFile = "$tempFolder\$($_.PackageFilename)"
                    $unzipDir = "$tempFolder\$([IO.Path]::GetFileNameWithoutExtension($_.PackageFilename))"

                    Write-Message "Unpacking file $($_.PackageFilename)..."
                    7zip\Expand-Archive -Path $nupkgFile -OutputPath $unzipDir -Force -Silent -SuppressExtensionCheck

                    $stagingDir = "$tempFolder\.staging\$modulesFolderTempName\$($_.Name)"

                    $robocopyArgs = @{
                        'Source' = $unzipDir
                        'Destination' = "$($stagingDir)\$($_.Version)"
                        'MirrorDirectoryTree' = $true
                        'ExcludeFiles' = @('[Content_Types].xml', "$($_.Name).nuspec")
                        'ExcludeDirectories' = @('package', '_rels')
                    }

                    Invoke-Robocopy @robocopyArgs | Out-Null

                    # Remove-Item $unzipDir -Force -Recurse -Confirm:$false | Out-Null

                    $robocopyArgs = @{
                        'Source' = $stagingDir
                        'Destination' = "$($modulesFolder)\$($_.Name)"
                        'MirrorDirectoryTree' = $true
                    }

                    Write-Message "Copying files to .\Modules\$($_.Name)\$($_.Version)..."
                    Invoke-Robocopy @robocopyArgs | Out-Null
                }
            }
        } else {
            Write-Error "Couldn't find package '$($Name)'."
        }
    } else {
        Write-Error "Couldn't find module root."
    }
}
