function Add-ModulePath {
	[CmdletBinding(PositionalBinding=$false, SupportsShouldProcess=$true, ConfirmImpact='Medium')]
	param(
	    # The path to include in the PSModulePath variable.
	    [Parameter(Mandatory=$true, Position=0)]
	    [string]$Path,
	
	    # Add the path even if it does not exist.
	    [Parameter(Mandatory=$false)]
	    [switch]$Force
	)
	
	
	if (-not(Test-Path $Path) -and -not($Force.IsPresent)) {
	    Write-Error "Path '$($Path)' does not exist."
	    return
	}
	
	# Ensure that the persisted values match the current session values.
	# TODO: Allow for the two to be out-of-sync (adds complexity & possible edge cases).
	$currentPSModulePath = Get-ModulePath -AsString
	$persistedPSModulePath = Get-ModulePath -Persisted -AsString
	if ($currentPSModulePath -ne $persistedPSModulePath) {
	    Write-Verbose "  Current: $currentPSModulePath"
	    Write-Verbose "Persisted: $persistedPSModulePath"
	    Write-Error "Current 'PSModulePath' does not match persited environment variables."
	    return
	}
	
	$systemModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
	if ($systemModulePath -and ($systemModulePath -split ';') -contains $Path) {
	    Write-Verbose "Machine-level 'PSModulePath' already contains '$($Path)'."
	} else {
	    $userModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'User')
	    if (-not($userModulePath) -or -not(($userModulePath -split ';') -contains $Path)) {
	        if ($PSCmdlet.ShouldProcess('PSModulePath', 'Add Path')) {
	            $userModulePath += "$(if($userModulePath){';'})$($Path)"
	            [System.Environment]::SetEnvironmentVariable('PSModulePath', $userModulePath, 'User')
	            Write-Verbose "Added '$($Path)' to 'PSModulePath' for the current user."
	
	            try {
	                # After modifying the 'PSModulePath' environment variable, attempt to re-load it into the current session.
	                Reset-ModulePath
	            } catch {
	                Write-Warning $_.Exception.Message
	            }
	        }
	    }
	}
}

function Expand-ModulePackage {
	################################################################################
	#  Expand-ModulePackage v0.2.0                                                 #
	#  --------------------------------------------------------------------------  #
	#  Extract a module package and clean up package files.                        #
	#  --------------------------------------------------------------------------  #
	#  Author(s): Bryan Matthews                                                   #
	#  Company: VC3, Inc.                                                          #
	#  --------------------------------------------------------------------------  #
	#  Change Log:                                                                 #
	#  [0.3.0] - 2017-09-24                                                        #
	#  Changed:                                                                    #
	#  - Give no special preference to 'Expand-Archive' command.                   #
	#  - Avoid silent error when attempting to find 'Expand-Archive' command.      #
	#  - Use 'SuppressExtensionCheck' when using 7zip to avoid temp file.          #
	#  - Retry cleanup up to 3 times to get around potential temporary errors.     #
	#  [0.2.0] - 2017-09-24                                                        #
	#  Fixed:                                                                      #
	#  - Fix temp file typo.                                                       #
	#  - Import built-in module b/c auto-loading may not result in its discovery.  #
	#  - Always rename zip file since 7zip shim also throws errors.                #
	#  [0.1.0] - 2017-09-21                                                        #
	#  Added:                                                                      #
	#  - Unzip via 'Expand-Archive' or custom script.                              #
	#  - Delete 'package' and '_rels' folders.                                     #
	#  - Delete '[Content_Types].xml' and '*.nuspec' files.                        #
	################################################################################
	[CmdletBinding()]
	param(
	    [Alias('Path')]
	    [Alias('FullName')]
	    [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
	    [string]$PackageFileName,
	
	    [Parameter(Mandatory=$true)]
	    [string]$ModuleName,
	
	    [Parameter(Mandatory=$true)]
	    [string]$DestinationPath,
	
	    [ScriptBlock]$UnzipScript,
	
	    [switch]$Force
	)
	
	Write-Verbose "Expanding module package '$($PackageFileName)'..."
	
	if (Test-Path $DestinationPath -Type Container) {
	    if ($Force.IsPresent) {
	        Write-Verbose "Removing destination directory '$($DestinationPath)'."
	        Remove-Item $DestinationPath -Recurse -Force -Confirm:$false -EA 0 | Out-Null
	        Remove-Item $DestinationPath -Recurse -Force -Confirm:$false | Out-Null
	    } else {
	        Write-Error "Destination path '$($DestinationPath)' already exists."
	        return
	    }
	}
	
	$PackageFileExtension = [IO.Path]::GetExtension($PackageFileName)
	
	Write-Verbose "Package file extension is '$($PackageFileExtension)'."
	
	if ($UnzipScript) {
	    Write-Verbose "Running custom unzip script..."
	    $unzipPath = & $UnzipScript $PackageFileName $DestinationPath
	    if ($unzipPath) {
	        if ($unzipPath -ne $DestinationPath) {
	            Write-Warning "Custom script unzipped file into unexpected destination '$($unzipPath)'."
	        }
	    } else {
	        Write-Error "Failed to unzip file '$($PackageFileName)' with custom script."
	        return
	    }
	} else {
	    Write-Verbose "Searching for 'Expand-Archive' command."
	
	    try {
	        if (-not(Get-Module 'Microsoft.PowerShell.Archive' -EA 0)) {
	            if (Get-Module 'Microsoft.PowerShell.Archive' -ListAvailable -EA 0) {
	                # Import-Module 'Microsoft.PowerShell.Archive'
	            }
	        }
	    } catch {
	        Write-Verbose "Encountered error '$($_.Exception.Message)' while attempting to import module 'Microsoft.PowerShell.Archive'."
	    }
	
	    # NOTE: Use wildcard & filtering to avoid problematic error handling in custom PowerShell host (ex: chocolatey)
	    $expandArchiveCommand = Get-Command '*-Archive' -EA 0 | Where-Object { $_.Name -eq 'Expand-Archive' }
	
	    if ($expandArchiveCommand) {
	        if ($expandArchiveCommand -is [array]) {
	            if ($expandArchiveCommand.Count -eq 1) {
	                Write-Verbose "Found 'Expand-Archive' command in module '$($expandArchiveCommand.ModuleName)'."
	            } else {
	                Write-Verbose "Found $($expandArchiveCommand.Count) 'Expand-Archive' commands."
	                $expandArchiveCommand = $expandArchiveCommand[0]
	                Write-Verbose "Using the first available 'Expand-Archive' command, from module '$($expandArchiveCommand.ModuleName)'."
	            }
	        } else {
	            Write-Verbose "Found 1 'Expand-Archive' command."
	        }
	
	        $expandArchiveArgs = @{
	            'Path' = $PackageFileName
	            'DestinationPath' = $DestinationPath 
	        }
	
	        if ($expandArchiveCommand.ModuleName -eq 'Microsoft.PowerShell.Archive') {
	            # The built-in 'Expand-Archive' will fail on extensions other than '.zip'
	            if ($PackageFileExtension -ne '.zip') {
	                Write-Verbose "Copying to temporary '.zip' file to avoid error."
	                $tmpFile = "$($env:TEMP)\$([guid]::NewGuid()).zip"
	                Copy-Item $PackageFileName $tmpFile
	                $expandArchiveArgs['Path'] = $tmpFile
	            }
	        } elseif ($expandArchiveCommand.ModuleName -eq '7zip') {
	            $expandArchiveArgs['Silent'] = $true
	            $expandArchiveArgs['IgnoreNonFatalErrors'] = $true
	            if ($PackageFileExtension -ne '.zip') {
	                $expandArchiveArgs['SuppressExtensionCheck'] = $true
	            }
	        }
	
	        & $expandArchiveCommand @expandArchiveArgs
	    } else {
	        Write-Error "Unable to find an 'Expand-Archive' command for extracting the package file."
	    }
	}
	
	if (-not(Test-Path $DestinationPath -Type Container)) {
	    Write-Error "Destination path '$($DestinationPath)' does not exist after unzip operation."
	    return
	}
	
	Write-Verbose "Cleaning up unzipped module output..."
	
	# Make multiple attempts to clean package files since deletions could fail
	# temporarily due to file locking, recurive deletion, etc.
	$cleanSuccessful = $false
	$cleanAttempts = 0
	
	do {
	    $cleanAttempts += 1
	
	    try {
	        if (Test-Path "$($DestinationPath)\_rels") {
	            Write-Verbose "Removing '_rels' folder."
	            Remove-Item "$($DestinationPath)\_rels" -Recurse -Force -Confirm:$false | Out-Null
	        }
	
	        if (Test-Path "$($DestinationPath)\package") {
	            Write-Verbose "Removing 'package' folder."
	            Remove-Item "$($DestinationPath)\package" -Recurse -Force -Confirm:$false | Out-Null
	        }
	
	        if (Test-Path -LiteralPath "$($DestinationPath)\[Content_Types].xml") {
	            Write-Verbose "Removing '[Content_Types].xml' file."
	            Remove-Item -LiteralPath "$($DestinationPath)\[Content_Types].xml" -Force -Confirm:$false | Out-Null
	        }
	
	        if (Test-Path "$($DestinationPath)\$($ModuleName).nuspec") {
	            Write-Verbose "Removing nuspec file."
	            Remove-Item "$($DestinationPath)\$($ModuleName).nuspec" -Force -Confirm:$false | Out-Null
	        }
	
	        $cleanSuccessful = $true
	    } catch {
	        Write-Verbose "Encountered error '$($_.Exception.Message)' while cleaning package files."
	    }
	} while (-not($cleanSuccessful) -and $cleanAttempts -lt 3)
}

function Find-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
	    # A prioritized list of indicators to check for
	    [ValidateSet('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleManifest', 'ModulesFolder')
	)
	
	# Based on NPM (and git) file/folder searchig algorithm.
	# https://docs.npmjs.com/files/folders#more-information
	
	$rootPath = $null
	$rootIndicator = $null
	
	Write-Verbose "Checking directory '$($Path)'..."
	foreach ($indicator in $indicators) {
	    if (-not($rootPath)) {
	        if (Test-ModuleRoot $Path -Indicators $indicator) {
	            Write-Verbose "Found module root indicator '$($indicator)'."
	            $rootPath = $Path
	            $rootIndicator = $indicator
	            break
	        }
	    }
	}
	
	if (-not($rootPath)) {
	    Get-ParentItem -Path $Path -Recurse | ForEach-Object {
	        if (-not($rootPath)) {
	            Write-Verbose "Checking directory '$($_.FullName)'..."
	            foreach ($indicator in $indicators) {
	                if (-not($rootPath)) {
	                    if (Test-ModuleRoot $_.FullName -Indicators $indicator) {
	                        Write-Verbose "Found module root indicator '$($indicator)'."
	                        $rootPath = $_.FullName
	                        $rootIndicator = $indicator
	                        break
	                    }
	                }
	            }
	
	            if ($rootPath) {
	                break
	            }
	        }
	    }
	}
	
	if ($rootPath) {
	    $root = New-Object 'PSObject'
	
	    $root | Add-Member -Type 'NoteProperty' -Name 'Indicator' -Value $rootIndicator
	    $root | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $rootPath
	
	    Write-Output $root
	}
}

function Get-ModulePath {
	[CmdletBinding()]
	param(
	    # If specified, returns the persisted value of 'PSModulePath'.
	    [Parameter(Mandatory=$false)]
	    [switch]$Persisted,
	
	    # If specified, returns the value of 'PSModulePath' as a semicolon-delimited string.
	    [Parameter(Mandatory=$false)]
	    [switch]$AsString
	)
	
	
	if ($Persisted.IsPresent) {
	    $pathItems = @()
	
	    $userModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
	    if ($userModulePath) {
	        Write-Verbose "Found user PSModulePath '$($userModulePath)'."
	        $pathItems += $userModulePath.Split(@(';'), 'RemoveEmptyEntries')
	    } else {
	        Write-Verbose "Using default user PSModulePath '$(Split-Path $PROFILE -Parent)\Modules'."
	        $pathItems += "$(Split-Path $PROFILE -Parent)\Modules"
	    }
	
	    $pathItems += "$($env:ProgramFiles)\WindowsPowerShell\Modules"
	
	    $systemModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
	    if ($systemModulePath) {
	        Write-Verbose "Found system PSModulePath '$($systemModulePath)'."
	        $pathItems += $systemModulePath.Split(@(';'), 'RemoveEmptyEntries')
	    }
	
	    if ($AsString.IsPresent) {
	        Write-Output ($pathItems -join ';')
	    } else {
	        Write-Output ($pathItems | select @{Name='Path';Expression={$_}})
	    }
	} elseif ($AsString.IsPresent) {
	    Write-Output $env:PSModulePath
	} else {
	    if ($env:PSModulePath) {
	        Write-Output ($env:PSModulePath.Split(@(';'), 'RemoveEmptyEntries') | select @{Name='Path';Expression={$_}})
	    }
	}
}

function Remove-ModulePath {
	[CmdletBinding(PositionalBinding=$false, SupportsShouldProcess=$true, ConfirmImpact='Medium')]
	param(
	    # The path to remove from the PSModulePath variable.
	    [Parameter(Mandatory=$true, Position=0)]
	    [string]$Path
	)
	
	
	# Ensure that the persisted values match the current session values.
	# TODO: Allow for the two to be out-of-sync (adds complexity & possible edge cases).
	$currentPSModulePath = Get-ModulePath -AsString
	$persistedPSModulePath = Get-ModulePath -Persisted -AsString
	if ($currentPSModulePath -ne $persistedPSModulePath) {
	    Write-Verbose "  Current: $currentPSModulePath"
	    Write-Verbose "Persisted: $persistedPSModulePath"
	    Write-Error "Current 'PSModulePath' does not match persited environment variables."
	    return
	}
	
	if (-not((Get-ModulePath -Persisted | foreach 'Path') -contains $Path)) {
	    Write-Error "Path '$($Path)' is not in the 'PSModulePath' variable."
	    return
	}
	
	$systemModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
	if (($systemModulePath -split ';') -contains $Path) {
	    Write-Error "Cannot remove path '$($Path)' from machine-level ``PSModulePath``."
	} else {
	    $userModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'User')
	    if (($userModulePath -split ';') -contains $Path) {
	        if ($PSCmdlet.ShouldProcess('PSModulePath', 'Remove Path')) {
	            $userModulePath = (($userModulePath -split ';') | Where-Object { $_ -ne $Path }) -join ';'
	            [System.Environment]::SetEnvironmentVariable('PSModulePath', $userModulePath, 'User')
	            Write-Verbose "Removed '$($Path)' from ``PSModulePath`` for the current user."
	
	            try {
	                # After modifying the 'PSModulePath' environment variable, attempt to re-load it into the current session.
	                Reset-ModulePath
	            } catch {
	                Write-Warning $_.Exception.Message
	            }
	        }
	    }
	}
}

function Reset-ModulePath {
	[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
	param(
	)
	
	
	if ($PSCmdlet.ShouldProcess('PSModulePath', 'Reset Current Session Value')) {
	    $env:PSModulePath = ((Get-ModulePath -Persisted) | foreach 'Path') -join ';'
	}
}

function Resolve-Module {
	################################################################################
	#  Resolve-Module v0.3.0                                                       #
	#  --------------------------------------------------------------------------  #
	#  Discover PowerShell modules in the NPM "require" style.                     #
	#  --------------------------------------------------------------------------  #
	#  Author(s): Bryan Matthews                                                   #
	#  Company: VC3, Inc.                                                          #
	#  --------------------------------------------------------------------------  #
	#  Change Log:                                                                 #
	#  [0.3.0] - 2017-09-21                                                        #
	#  Added:                                                                      #
	#  - Support installing from local directory path                              #
	#  - Support specifying and/or local vs. global search                         #
	#  - Support searching a specific folder                                       #
	#  - Support searching -only- user or machine scope                            #
	#  [0.2.0] - 2017-08-04                                                        #
	#  Fixed:                                                                      #
	#  - Use 'BindingVariable' in 'Import-LocalizedData' call                      #
	#  [0.1.0] - 2017-07-13                                                        #
	#  Added:                                                                      #
	#  - Support for finding and importing '.psm1' and '.psd1' files.              #
	#  - Support for finding module files in a nested version folder.              #
	################################################################################
	[CmdletBinding(DefaultParameterSetName='SearchLocalAndGlobal')]
	param(
	    [Alias('Name')]
	    [Parameter(Mandatory=$true, Position=0)]
	    [string]$ModuleName,
	
	    [Parameter(ParameterSetName='SearchLocal')]
	    [string]$ModulesFolder,
	
	    [Parameter(ParameterSetName='SearchGlobal')]
	    [switch]$Global,
	
	    [Parameter(ParameterSetName='SearchLocalAndGlobal')]
	    [Parameter(ParameterSetName='SearchGlobal')]
	    [ValidateSet('CurrentUser', 'System')]
	    [string]$Scope
	)
	
	Write-Verbose "Attempting to resolve module '$($ModuleName)'..."
	
	if ($PSCmdlet.ParameterSetName -like 'SearchLocal*') {
	    $localModules = @()
	
	    if (-not($ModulesFolder)) {
	        if ($MyInvocation.PSScriptRoot) {
	            Write-Verbose "Searching from script file '$($MyInvocation.PSCommandPath)..."
	            $searchDir = $MyInvocation.PSScriptRoot
	        } else {
	            Write-Verbose "Searching from current working directory '$($PWD.Path)..."
	            $searchDir = $PWD.Path
	        }
	
	        $ModulesFolder = Join-Path $searchDir 'Modules'
	    }
	
	    do {
	        if (-not($ModulesFolder)) {
	            $ModulesFolder = Join-Path $searchDir 'Modules'
	        }
	
	        if (Test-Path ($ModulesFolder)) {
	            Get-ChildItem $ModulesFolder | Where-Object { $_.PSIsContainer } | ForEach-Object {
	
	                Write-Verbose "Searching '$($_.FullName)'..."
	
	                $moduleVersion = $null
	
	                Write-Verbose "Checking for module manifest in root folder..."
	                $moduleFile = Join-Path $_.FullName "$($ModuleName).psd1"
	                if (Test-Path $moduleFile) {
	                    Import-LocalizedData -BindingVariable 'moduleManifest' -FileName "$($ModuleName).psd1" -BaseDirectory $_.FullName
	                    $moduleVersion = $moduleManifest.ModuleVersion
	                    Write-Verbose "Found module manifest for '$($ModuleName)' v$($moduleVersion)."
	                } else {
	                    Write-Verbose "Checking for module file in root folder..."
	                    $moduleFile = Join-Path $_.FullName "$($ModuleName).psm1"
	                    if (Test-Path $moduleFile) {
	                        Write-Verbose "Found module file for '$($ModuleName)'."
	                    } else {
	                        # NOTE: Check for a single *version* folder (simplification).
	                        $versionFolder = $null
	                        Write-Verbose "Looking for version folder..."
	                        $children = [array](Get-ChildItem $_.FullName)
	                        Write-Verbose "Found $($children.Count) children: $(($children | Select-Object -ExpandProperty Name) -join ', ')."
	                        if (($children.Count -eq 1) -and $children[0].PSIsContainer) {
	                            try {
	                                [System.Version]::Parse($children[0].Name) | Out-Null
	                                $versionFolder = $children[0]
	                            } catch {
	                                # Not a version, do nothing
	                                Write-Verbose "Unable to parse '$($children[0].Name)' as a .NET version."
	                            }
	                        }
	
	                        if ($versionFolder) {
	                            Write-Verbose "Checking for module manifest in '$($versionFolder.Name)' folder..."
	                            $moduleFile = Join-Path $versionFolder.FullName "$($ModuleName).psd1"
	                            if (Test-Path $moduleFile) {
	                                Write-Verbose "Found module manifest for '$($ModuleName)'."
	                            } else {
	                                Write-Verbose "Module manifest couldn't be found in version folder."
	                                $moduleFile = $null
	                            }
	                        } else {
	                            Write-Verbose "No version folder was found."
	                            $moduleFile = $null
	                        }
	                    }
	                }
	
	                if ($moduleFile) {
	                    Write-Verbose "Found module '$($ModuleName)' at '$($moduleFile)'."
	
	                    $module = New-Object 'PSObject'
	
	                    $module | Add-Member -Type 'NoteProperty' -Name 'Name' -Value $ModuleName
	                    $module | Add-Member -Type 'NoteProperty' -Name 'Version' -Value $moduleVersion
	                    $module | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $moduleFile
	
	                    $localModules += $module
	                }
	            }
	
	            if ($localModules.Count -gt 0) {
	                Write-Output $localModules
	                return;
	            }
	
	            $searchDir = $null
	        } elseif ($searchDir) {
	            $searchDir = Split-Path $searchDir -Parent
	        }
	    } while ($searchDir)
	}
	
	if ($PSCmdlet.ParameterSetName -like 'Search*Global') {
	    Write-Verbose "Attempting to find global '$($ModuleName)' module on the %PSModulePath%..."
	
	    $candidateRootPaths = $null
	
	    if ($Scope -eq 'System') {
	        $candidateRootPaths = @()
	
	        $candidateRootPaths += "$($env:ProgramFiles)\WindowsPowerShell\Modules"
	
	        $systemValue = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
	        if ($systemValue) {
	            $candidateRootPaths += $systemValue.Split(@(';'), 'RemoveEmptyEntries')
	        }
	
	        Write-Verbose "Using candidate root paths '$($candidateRootPaths -join ';')'."
	    } elseif ($Scope -eq 'CurrentUser') {
	        $candidateRootPaths = @()
	
	        $candidateRootPaths += "$(Split-Path $PROFILE -Parent)\Modules"
	
	        $userValue = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
	        if ($userValue) {
	            $systemValues = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine').Split(@(';'), 'RemoveEmptyEntries')
	            $candidateRootPaths += $userValue.Split(@(';'), 'RemoveEmptyEntries') | Where-Object { -not($systemValues -contains $_) }
	        }
	
	        Write-Verbose "Using candidate root paths '$($candidateRootPaths -join ';')'."
	    }
	
	    $globalModules = @()
	
	    Get-Module -Name $ModuleName -ListAvailable | ForEach-Object {
	        $moPath = $_.Path
	
	        if (-not($candidateRootPaths) -or ($candidateRootPaths | Where-Object { $moPath.StartsWith($_, $true, [Globalization.CultureInfo]::CurrentCulture) })) {
	            Write-Verbose "Found installed module '$($ModuleName)' at '$($_.Path)'."
	
	            $module = New-Object 'PSObject'
	
	            $module | Add-Member -Type 'NoteProperty' -Name 'Name' -Value $ModuleName
	            $module | Add-Member -Type 'NoteProperty' -Name 'Version' -Value $_.Version
	            $module | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $_.Path
	
	            $globalModules += $module
	        }
	    }
	
	    if ($globalModules.Count -gt 0) {
	        Write-Output $globalModules
	        return
	    }
	}
	
	Write-Error "Couldn't resolve module '$($ModuleName)'."
}

function Restore-ModulePath {
	<#
	.SYNOPSIS
	Restores the 'PSModulePath' environment variable to its default setting.
	#>
	[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
	param(
	)
	
	
	if ($PSCmdlet.ShouldProcess('PSModulePath', 'Restore to Default Setting')) {
	    [Environment]::SetEnvironmentVariable('PSModulePath', "$($Home)\Documents\WindowsPowerShell\Modules", 'User')
	    [Environment]::SetEnvironmentVariable('PSModulePath', 'C:\Windows\system32\WindowsPowerShell\v1.0\Modules\', 'Machine')
	
	    try {
	        # After restoring the 'PSModulePath' environment variable, attempt to re-load it into the current session.
	        Reset-ModulePath
	    } catch {
	        Write-Warning $_.Exception.Message
	    }
	}
}

function Test-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
	    # A prioritized list of indicators to check for
	    [ValidateSet('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleManifest', 'ModulesFolder')
	)
	
	foreach ($indicator in $Indicators) {
	    switch ($indicator) {
	        'ModuleDotPsd1File' {
	            if (Test-Path (Join-Path $Path 'module.psd1')) {
	                return $true
	            }
	        }
	        'ModuleManifest' {
	            $psd1Files = [array](Resolve-Path (Join-Path $Path '*.psd1') -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -ne 'module.psd1' })
	            if ($psd1Files.Count -eq 1) {
	                return $true
	            } elseif ($psd1Files.Count -gt 1) {
	                Write-Warning "Found multiple '.psd1' files at path '$($Path)'."
	            }
	        }
	        'ModulesFolder' {
	            if (Test-Path (Join-Path $Path 'Modules')) {
	                return $true
	            }
	        }
	    }
	}
	
	return $false
}

function Test-PowerShellProcess {
	[CmdletBinding()]
	param(
	    [switch]$Force
	)
	
	
	if ($env:PSModulePathProcessID) {
	    $currentProcess = [System.Diagnostics.Process]::GetCurrentProcess()
	    if ($env:PSModulePathProcessID -ne $currentProcess.Id) {
	        if ($Force.IsPresent) {
	            throw "Cannot reset module path from outside of the PowerShell process."
	        } else {
	            Write-Warning "Changes to the PSModulePath will not take effect from within the calling process."
	        }
	    }
	} else {
	    Write-Warning "Changes to the PSModulePath may not take effect from within the calling process."
	}
}

