<#

.SYNOPSIS
Publish a module.

.DESCRIPTION

First, attempt to find a module relative to the current directory.

* Look for the module root via a module.ps1 file or a module manifest.
    - If a name is specified, then also look for a 'Modules' folder.
* If the module root is found via a 'Modules' folder...
    - Resolve the module with the given name within the 'Modules' folder.
    - The containing folder will be passed to `Publish-Module`.
* If the module root is found via a module.psd1 file...
    - Resolve the 'Destination' property and find the corresponding module manifest.
* 

Otherwise, look for a module with the given name on the %PSModulePath%.

#>
function Invoke-ModulePublishCommand {
    [CmdletBinding()]
    param(
        [string]$Name,

        [Alias('S')]
        [string]$Source,

        [Alias('SNW')]
        [switch]$SuppressNameWarning
    )

    Write-Verbose "Searching for module root from '$($PWD.Path)'..."

    $root = Find-ModuleRoot -Indicators 'ModuleDotPsd1File','ModuleManifest','ModulesFolder'

    if ($Name) {
        $indicators = @('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')
    } else {
        $indicators = @('ModuleDotPsd1File', 'ModuleManifest')
    }

    if ($root) {
        Write-Verbose "Found module root '$($root.Path)'."

        if ($root.Indicator -eq 'ModulesFolder') {
            $modulesFolder = "$($root.Path)\Modules"

            Write-Verbose "Found modules folder '$($modulesFolder)'."

            $module = Resolve-Module -ModuleName $Name -ModulesFolder $modulesFolder -EA 0

            if ($module) {
                $moduleToPublish = $module.Name
                $versionToPublish = $module.Version
                $folderToPublish = Split-Path $module.Path -Parent
            }
        } else {
            if ($root.Indicator -eq 'ModuleDotPsd1File') {
				$moduleFile = (Resolve-Path "$($root.Path)\module.psd1").Path

                Write-Verbose "Found module spec '$($moduleFile)'."

                $moduleSpec = Import-PSData -Path $moduleFile

                $moduleName = $moduleSpec.Name

                if ($moduleSpec.Source) {
                    $xd += (Resolve-Path (Join-Path $root.Path $moduleSpec.Source)).Path
                }

                $moduleDest = $moduleSpec.Destination

                if ($moduleDest -eq '.') {
                    $rootPath = $root.Path
                } else {
                    $rootPath = (Resolve-Path (Join-Path $root.Path $moduleDest)).Path
                }

				$moduleManifestFile = (Resolve-Path "$($rootPath)\$($moduleName).psd1").Path

                Write-Verbose "Found module manifest '$($moduleManifestFile)'."

                $moduleToPublish = $moduleSpec.Name
            } else {
                $moduleFile = $null

                $rootPath = $root.Path

				$moduleManifestFile = (Resolve-Path "$($root.Path)\*.psd1").Path

                Write-Verbose "Found module manifest '$($moduleManifestFile)'."
                
                $moduleToPublish = [IO.Path]::GetFileNameWithoutExtension($moduleManifestFile)
            }

            $moduleManifest = Import-PSData $moduleManifestFile

            $versionToPublish = $moduleManifest.ModuleVersion

            $exclusions = Get-ModuleExclusions -RootPath $rootPath -ModuleFile $moduleFile

            $tempFolder = Get-TempFolder

            Write-Verbose "ModulesFolderTempName: $modulesFolderTempName"

            $rootPathHash = $rootPath.ToLower() | Get-Hash -OutputType 'Bytes'

            $rootPathTempName = [Uri]::EscapeDataString([Convert]::ToBase64String($rootPathHash))

            Write-Verbose "RootPathTempName: $rootPathTempName"

            $stagingDir = "$tempFolder\.staging\$rootPathTempName"

            if (Test-Path $stagingDir) {
                Write-Verbose "Cleaning up old temp directory..."
                Remove-Item $stagingDir -Force -Recurse -Confirm:$false | Out-Null
            }

            mkdir $stagingDir | Out-Null

            $robocopyArgs = @{
                'Source' = $rootPath
                'Destination' = "$($stagingDir)\$($moduleToPublish)"
                'MirrorDirectoryTree' = $true
                'ExcludeDirectories' = $exclusions.Directories
                'ExcludeFiles' = $exclusions.Files
            }

            Write-Verbose "Copying files to the staging directory..."

            Invoke-Robocopy @robocopyArgs -Verbose:$false | Out-Null

            $folderToPublish = "$($stagingDir)\$($moduleToPublish)"

            Get-FolderItem -Path $folderToPublish -Verbose:$false | ForEach-Object { Write-Verbose "$($_.FullName.Substring($folderToPublish.Length + 1))" }

            Write-Verbose "FolderToPublish: $folderToPublish"
        }

        $publishArgs = @{
            'Path' = $folderToPublish
        }

        if ($Source) {
            $publishArgs['Repository'] = $Source
        }

        Write-Verbose "Publishing $($moduleToPublish) v$($versionToPublish)..."
        Publish-Module @publishArgs
    }
}
