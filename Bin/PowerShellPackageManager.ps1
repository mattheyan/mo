$here = Split-Path $MyInvocation.MyCommand.Path -Parent

function mo {
	Remove-Module 'PowerShellPackageManager' -EA 0

	if (Get-Module 'PowerShellPackageManager' -EA 0) {
		throw "Module 'PowerShellPackageManager' is already imported!"
	}

	Import-Module "$($HOME)\Workspace\PowerShellPackageManager\PowerShellPackageManager.psd1"

	$env:PSModulePathProcessID = [System.Diagnostics.Process]::GetCurrentProcess().Id

	try {
		& "$($here)\..\Scripts\Invoke-PowerShellPackageManager.ps1" -Params $Args
	} finally {
		Remove-Module 'PowerShellPackageManager' -EA 0
	}
}
