function Test-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
		# A prioritized list of indicators to check for
	    [ValidateSet('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')
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
