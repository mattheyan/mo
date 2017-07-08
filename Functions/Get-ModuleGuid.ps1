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
