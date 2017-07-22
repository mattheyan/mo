<#

.SYNOPSIS
Installs a module.

#>
function Invoke-ModuleInstallCommand {
    [CmdletBinding(DefaultParameterSetName='LocalModule')]
    param(
        [Parameter(ParameterSetName='LocalModule', Position=0)]
        [Parameter(ParameterSetName='GlobalModule', Mandatory=$true, Position=0)]
        [string]$Name,

        [string]$Version,

        [string]$Source,

        [Parameter(ParameterSetName='GlobalModule', Mandatory=$true)]
        [switch]$Global,

        [ValidateSet('AllUsers', 'CurrentUser')]
        [Parameter(ParameterSetName='GlobalModule', Mandatory=$true)]
        [string]$Scope
    )

    if ($Global.IsPresent) {
        $findModuleArgs = @{
            'Name' = $Name
        }

        if ($Version) {
            $findModuleArgs['RequiredVersion'] = $Version
        }

        if ($Source) {
            $findModuleArgs['Repository'] = $Source
        }

        Write-Message "Searching for module '$($Name)'..."
        $module = Find-Module @findModuleArgs

        if ($module) {
            $installModuleArgs = @{}

            if ($Scope) {
                $installModuleArgs['Scope'] = $Scope
            }

            Write-Message "Installing module $($module.Name)@$($module.Version)..."
            $module | Install-Module @installModuleArgs
        } else {
            Write-Error "Couldn't find module '$($Name)'."
        }
    } else {
        Write-Verbose "Searching for module root from '$($PWD.Path)'..."

        $root = Find-ModuleRoot

        if ($root) {
            Write-Verbose "Found module root '$($root)'."

            $findPackageArgs = @{
                'Name' = $Name
                'Provider' = 'NuGet'
            }

            if ($Version) {
                $findPackageArgs['RequiredVersion'] = $Version
            }

            Write-Message "Searching for package '$($Name)'..."
            $package = Find-Package @findPackageArgs

            if ($package) {
                $tempFolder = Get-TempFolder

                $savePackageArgs = @{
                    'Path' = $tempFolder
                    'Provider' = 'NuGet'
                }

                if ($Version) {
                    $savePackageArgs['RequiredVersion'] = $Version
                }

                Write-Message "Downloading package $($package.Name)@$($package.Version)..."
                $packages = $package | Save-Package @savePackageArgs

                $packagesToUnpack = [array]($packages | Where-Object {
                    Write-Message "Downloaded package $($_.PackageFilename)."

                    if (Test-Path "$($root)\Modules\$($_.Name)") {
                        if (Test-Path "$($root)\Modules\$($_.Name)\$($_.Version)") {
                            Write-Message "Package $($_.Name)@$($_.Version) is already installed."
                            return $false
                        }

                        if (Test-Path "$($root)\Modules\$($_.Name)\$($_.Name).psd1") {
                            try {
                                $manifest = Import-PSData "$($root)\Modules\$($_.Name)\$($_.Name).psd1"
                                if ($manifest.ModuleVersion -ge $_.Version) {
                                    Write-Message "Package $($_.Name)@$($_.Version) is already installed."
                                    return $false
                                }
                            } catch {
                                Write-Warning "Unable to parse module manifest '.\Modules\$($_.Name)\$($_.Name).psd1"
                            }
                        }
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
                            'Destination' = $stagingDir
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

                        Write-Message "Copying files to .\Modules\$($_.Name)..."
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
}
