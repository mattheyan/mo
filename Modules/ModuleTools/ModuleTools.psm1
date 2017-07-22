if (-not($env:PSModulePathProcessID)) {
	$env:PSModulePathProcessID = [System.Diagnostics.Process]::GetCurrentProcess().Id
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

function Reset-ModulePath {
	[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
	param(
	)

	Test-PowerShellProcess -Force

	if ($PSCmdlet.ShouldProcess('PSModulePath', 'Reset Current Session Value')) {
	    $env:PSModulePath = ((Get-ModulePath -Persisted) | foreach 'Path') -join ';'
	}
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

Export-ModuleMember -Function Add-ModulePath
Export-ModuleMember -Function Get-ModulePath
Export-ModuleMember -Function Remove-ModulePath
Export-ModuleMember -Function Reset-ModulePath
Export-ModuleMember -Function Restore-ModulePath
