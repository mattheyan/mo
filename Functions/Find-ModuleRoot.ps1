function Find-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
		# A prioritized list of indicators to check for
	    [ValidateSet('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')
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
