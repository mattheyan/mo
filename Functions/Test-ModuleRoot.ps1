function Test-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
	    [ValidateSet('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')
	)
	
	if (($Indicators -contains 'ModuleDotPsd1File') -and (Test-Path (Join-Path $Path 'module.psd1'))) {
	    return $true
	}
	
	if (($Indicators -contains 'ModuleManifest') -and (Test-Path (Join-Path $Path '*.psd1'))) {
	    return $true
	}
	
	if (($Indicators -contains 'ModulesFolder') -and (Test-Path (Join-Path $Path 'Modules'))) {
	    return $true
	}
	
	return $false
}
