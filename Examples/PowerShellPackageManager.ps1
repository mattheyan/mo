$here = Split-Path $MyInvocation.MyCommand.Path -Parent

function mo {
	Remove-Module 'ModuleTools' -EA 0

	if (Get-Module 'ModuleTools' -EA 0) {
		throw "Module 'ModuleTools' is already imported!"
	}

	Import-Module "$($HOME)\Workspace\PowerShellPackageManager\ModuleTools.psd1"

	try {
		& "$($here)\..\Scripts\Invoke-PowerShellPackageManager.ps1" -Params $Args
	} finally {
		Remove-Module 'ModuleTools' -EA 0
	}
}
