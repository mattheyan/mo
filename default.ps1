Write-Message "Loading file '$($MyInvocation.MyCommand.Path)'..."

if (-not($psake)) {
	throw "Script 'psake-common.ps1' must be run as a psake task."
}

if (-not($global:PsakeTaskRoot)) {
	$global:PsakeTaskRoot = $psake.build_script_dir
}

$here = Split-Path $MyInvocation.MyCommand.Path -Parent

Write-Message "[[DarkGreen:PsakeTaskRoot]]: $PsakeTaskRoot"

include '.\Modules\Psake-Choco\psake-tasks.ps1'

properties {
	if ($env:ChocolateyLocal -and (Test-Path $env:ChocolateyLocal)) {
		$outDir = $env:ChocolateyLocal
	} else {
		$outDir = Join-Path $env:LOCALAPPDATA 'PowerShellPackageManager'
		if (-not(Test-Path $outDir)) {
			New-Item $outDir -Type Directory | Out-Null
		}
	}

	$chocoOutDir = $outDir
	$chocoPkgsDir = $PsakeTaskRoot
}

if (Test-Path "$($here)\psake-local.ps1") {
	Write-Message "Loading file '$($here)\psake-local.ps1'..."
	include "$($here)\psake-local.ps1"
}

task EnsureBuildProperties  {
    if (-not($chocoSourceHost)) {
	    $chocoSourceHost = 'myget'
    } elseif ($chocoSourceHost -ne 'myget') {
        throw "Unexpected chocolatey source host '$($chocoSourceHost)'."
    }
}

task EnsureDeployProperties -depends EnsureBuildProperties  {
	# Set property to environment variable if present
	if (-not($chocoApiKey) -and $chocoSourceHost -eq 'myget' -and $env:MyGet_ApiKey) {
		$chocoApiKey = $env:MyGet_ApiKey
	}

	if (-not($chocoApiKey)) {
		throw "Set enviornment variable 'MyGet_ApiKey' to provide access to the choco pkg destination."
	}
}

task UpdateFunctionsToExport {
	$FunctionsToExport = @()

	Get-ChildItem "$($PsakeTaskRoot)\Commands" | ForEach-Object {
		$FunctionsToExport += ([IO.Path]::GetFileNameWithoutExtension($_.Name))
	}

	$FunctionsToExport += 'Invoke-ModuleCommand'

	Update-ModuleManifest "$($PsakeTaskRoot)\PowerShellPackageManager.psd1" -FunctionsToExport $FunctionsToExport
}

task Build -depends EnsureBuildProperties,Choco:BuildPackages

task Deploy -depends EnsureDeployProperties,Choco:DeployPackages
