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
            Write-Verbose "Found module root '$($root.Path)'."

            $module = Resolve-Module -Name $Name -ModulesFolder "$($root.Path)\Modules" -EA 0

            if ($module) {
                if (-not($Version) -or $module.Version -eq $Version) {
                    Write-Message "Module $($Name)@$($module.Version) is already installed."
                    return 
                } elseif (-not($module.Version)) {
                    Write-Warning "Module $($Name)@??? is installed."
                    return
                } elseif ($module.Version -ge $Version) {
                    Write-Warning "Module $($Name)@$($module.Version) is installed."
                    return
                } else {
                    Write-Message "Module $($Name)@$(if($module.Version){$module.Version}else{'???'}) is installed."
                }
            }

            $findPackageArgs = @{
                'Name' = $Name
                'Provider' = 'NuGet'
            }

            if ($Version) {
                $findPackageArgs['RequiredVersion'] = $Version
            }

            Write-Message "Searching for module '$($Name)'..."
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

                Write-Message "Downloading module $($package.Name)@$($package.Version)..."
                $packages = $package | Save-Package @savePackageArgs

                $packagesToUnpack = [array]($packages | Where-Object {
                    Write-Verbose "Downloaded module $($_.PackageFilename)."

                    # Attempt to detect dependencies that are already installed
                    if ($_.Name -ne $Name) {
                        Write-Verbose "Checking for module '$($_.Name)'..."
                        $module = Resolve-Module -Name $_.Name -ModulesFolder "$($root.Path)\Modules" -EA 0

                        if ($module) {
                            if ($module.Version -eq $_.Version) {
                                Write-Verbose "Module $($_.Name)@$($module.Version) is already installed."
                                return $false
                            } elseif (-not($module.Version)) {
                                Write-Warning "Module $($_.Name)@??? is installed."
                                return $false
                            } elseif ($module.Version -ge $_.Version) {
                                Write-Warning "Module $($_.Name)@$($module.Version) is installed."
                                return $false
                            } else {
                                Write-Verbose "Module $($_.Name)@$(if($module.Version){$module.Version}else{'???'}) is installed."
                            }
                        }
                    }

                    return $true
                })

                if ($packagesToUnpack.Count -gt 0) {
                    $modulesFolder = "$($root.Path)\Modules"

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

                        Invoke-Robocopy @robocopyArgs -Verbose:$false | Out-Null

                        # Remove-Item $unzipDir -Force -Recurse -Confirm:$false | Out-Null

                        $robocopyArgs = @{
                            'Source' = $stagingDir
                            'Destination' = "$($modulesFolder)\$($_.Name)"
                            'MirrorDirectoryTree' = $true
                        }

                        Write-Message "Copying files to .\Modules\$($_.Name)..."
                        Invoke-Robocopy @robocopyArgs -Verbose:$false | Out-Null
                    }
                }
            } else {
                Write-Error "Couldn't find module '$($Name)'."
            }
        } else {
            Write-Error "Couldn't find module root."
        }
    }
}
