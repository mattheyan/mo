<#

.SYNOPSIS

Displays a list of PowerShell modules that are installed.

#>
[CmdletBinding()]
param(
    # The path in which to run the build.
    [Alias('p')]
    [string]$Path=$PWD.Path,

    [Alias('g')]
    [switch]$Global,

    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

if ($Global.IsPresent) {
    Get-Module -ListAvailable | Sort-Object -Property 'Name' | ForEach-Object {
        $name = $_.Name
        $version = $null

        # If there is no manifest, then Get-Module will report '0.0' as the version.
        if ($_.Version -ne '0.0') {
            $version = $_.Version
        }

        Write-Output " - $($_.Name)$(if ($version) { '@' + $version } else { '' })"
    }
} else {
    $moduleRoot = Find-ModuleRoot -Path $Path -Indicators ModuleDotPsd1File,ModulesFolder
    if (-not($moduleRoot)) {
        Write-Error "Cannot find module root from '$($PWD.Path)'."
        return
    }

    if (-not(Test-Path "$($moduleRoot.FullName)\Modules")) {
        Write-Host "No modules found in '$($moduleRoot.FullName)'."
        return
    }

    Get-ChildItem "$($moduleRoot.FullName)\Modules" | ForEach-Object {
        $name = $_.Name
        $version = $null

        $psd1 = Join-Path $_.FullName "$($_.Name).psd1"
        if (Test-Path $psd1) {
            $moduleDef = Import-PSData -Path $psd1
            $version = $moduleDef.ModuleVersion
        } else {
            $nuspec = Join-Path $_.FullName "$($_.Name).nuspec"
            if (Test-Path $nuspec) {
                $pkgDef = [xml](Get-Content $nuspec)
                $version = $pkgDef.package.metadata.version
            }
        }

        Write-Output " - $($_.Name)$(if ($version) { '@' + $version } else { '' })"
    }
}
