function Find-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
	    [ValidateSet('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleDotPsd1File', 'ModuleManifest', 'ModulesFolder')
	)
	
	# Based on NPM (and git) file/folder searchig algorithm.
	# https://docs.npmjs.com/files/folders#more-information
	
	$foundItem = $null
	
	Write-Verbose "Checking directory '$($Path)'..."
	if ((Test-ModuleRoot $Path -Indicators $Indicators)) {
	    $foundItem = (Get-Item $Path)
	} else {
	    Get-ParentItem -Path $Path -Recurse | ForEach-Object {
	        Write-Verbose "Checking directory '$($_.FullName)'..."
	        if ((Test-ModuleRoot $_.FullName -Indicators $Indicators)) {
	            $foundItem = $_
	            break
	        }
	    }
	}
	
	Write-Output $foundItem
}
