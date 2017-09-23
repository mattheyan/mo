function Test-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
	    [ValidateSet('ModuleDotPsd1File', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleDotPsd1File')
	)
	
	if (($Indicators -contains 'ModuleDotPsd1File') -and (Test-Path (Join-Path $Path 'module.psd1'))) {
	    return $true
	}
	
	if (($Indicators -contains 'ModulesFolder') -and (Test-Path (Join-Path $Path 'Modules'))) {
	    return $true
	}
	
	return $false
}

function Get-ModuleGuid {
	param(
	    [CmdletBinding()]
	    [string]$id
	)
	
	$md5 = [System.Security.Cryptography.MD5]::Create()
	$data = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($id.ToLower()));
	$guid = New-Object 'System.Guid' -ArgumentList (,$data)
	Write-Output "$($guid.ToString().ToLowerInvariant())"
}

function Find-ModuleRoot {
	[CmdletBinding()]
	param(
	    [Alias('p')]
	    [string]$Path=$PWD.Path,
	
	    [ValidateSet('ModuleDotPsd1File', 'ModulesFolder')]
	    [string[]]$Indicators=@('ModuleDotPsd1File')
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

Export-ModuleMember -Function Find-ModuleRoot
Export-ModuleMember -Function Get-ModuleGuid
Export-ModuleMember -Function Test-ModuleRoot
