$here = Split-Path $MyInvocation.MyCommand.Path -Parent

function mo {
	Remove-Module 'Mo' -EA 0

	if (Get-Module 'Mo' -EA 0) {
		throw "Module 'Mo' is already imported!"
	}

	Import-Module "$($HOME)\Workspace\mo\Mo.psd1"

	$env:PSModulePathProcessID = [System.Diagnostics.Process]::GetCurrentProcess().Id

	try {
		Invoke-MoCommand -Params $Args
	} finally {
		Remove-Module 'Mo' -EA 0
	}
}
