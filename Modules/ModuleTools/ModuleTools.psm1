if (-not($env:PSModulePathProcessID)) {
	$env:PSModulePathProcessID = [System.Diagnostics.Process]::GetCurrentProcess().Id
}


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
	
	
	Test-PowerShellProcess -Force
	
	if ($PSCmdlet.ShouldProcess('PSModulePath', 'Reset Current Session Value')) {
	    $env:PSModulePath = ((Get-ModulePath -Persisted) | foreach 'Path') -join ';'
	}
}

function Resolve-Module {
	[CmdletBinding(DefaultParameterSetName='FromLocation')]
	param(
	    [Alias('Name')]
	    [Parameter(Mandatory=$true, Position=0)]
	    [string]$ModuleName,
	
	    [Alias('Modules')]
	    [Parameter(ParameterSetName='InModulesFolder', Mandatory=$true)]
	    [string]$ModulesFolder,
	
	    [Parameter(ParameterSetName='FromLocation')]
	    [string]$Location
	)
	
	if ($PSCmdlet.ParameterSetName -eq 'FromLocation') {
	    if ($Location) {
	        if (-not(Test-Path $Location)) {
	            Write-Error "Path '$($Location)' doesn't exist."
	            return
	        }
	
	        $Location = (Resolve-Path $Location).Path
	    } else {
	        # Start from the current script's location, -OR- the current working directory
	        if ($MyInvocation.PSScriptRoot) {
	            Write-Verbose "Searching from script file '$($MyInvocation.PSCommandPath)..."
	            $Location = $MyInvocation.PSScriptRoot
	        } else {
	            Write-Verbose "Searching from current working directory '$($PWD.Path)..."
	            $Location = $PWD.Path
	        }
	    }
	
	    Write-Verbose "Attempting to resolve module '$($ModuleName)' from '$($Location)'..."
	
	    $searchDir = $Location
	
	    # Search for the nearest 'Modules' directory
	    while ($searchDir) {
	        if (Test-Path "$searchDir\Modules") {
	            $ModulesFolder = "$searchDir\Modules"
	            break
	        }
	
	        $searchDir = Split-Path $searchDir -Parent
	    }
	
	    if (-not($ModulesFolder)) {
	        Write-Error "Couldn't find 'Modules' folder from '$($Location)'."
	        return
	    }
	
	    $Recurse = $true
	} else {
	    if (-not(Test-Path $ModulesFolder)) {
	        Write-Error "Path '$($ModulesFolder)' doesn't exist."
	        return
	    }
	
	    if (-not(Test-Path $ModulesFolder -Type 'Container')) {
	        Write-Error "Path '$($ModulesFolder)' is not a folder."
	        return
	    }
	
	    $ModulesFolder = (Resolve-Path $ModulesFolder).Path
	
	    $Recurse = $false
	
	    Write-Verbose "Attempting to resolve module '$($ModuleName)' in folder '$($ModulesFolder)'..."
	}
	
	do {
	    $localModules = @()
	
	    Get-ChildItem $ModulesFolder | Where-Object { $_.PSIsContainer } | ForEach-Object {
	
	        Write-Verbose "Searching '$($_.FullName)'..."
	
	        $moduleVersion = $null
	
	        Write-Verbose "Checking for module manifest in root folder..."
	        $moduleFile = Join-Path $_.FullName "$($ModuleName).psd1"
	        if (Test-Path $moduleFile) {
	            $moduleManifest = Import-LocalizedData -FileName "$($ModuleName).psd1" -BaseDirectory $_.FullName
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
	        return
	    }
	
	    if ($Recurse) {
	        $searchDir = Split-Path (Split-Path $ModulesFolder -Parent) -Parent
	
	        $ModulesFolder = $null
	
	        while (-not($ModulesFolder) -and $searchDir) {
	            if (Test-Path "$searchDir\Modules") {
	                $ModulesFolder = "$searchDir\Modules"
	            } else {
	                $searchDir = Split-Path $searchDir -Parent
	            }
	        }
	    } else {
	        $ModulesFolder = $null
	    }
	
	} while ($ModulesFolder)
	
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

Export-ModuleMember -Function Add-ModulePath
Export-ModuleMember -Function Get-ModulePath
Export-ModuleMember -Function Remove-ModulePath
Export-ModuleMember -Function Reset-ModulePath
Export-ModuleMember -Function Restore-ModulePath
Export-ModuleMember -Function Resolve-Module


