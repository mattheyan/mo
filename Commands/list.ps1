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

    [Parameter(Mandatory=$false,Position=0)]
    [string]$Target,

    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

if ($Global.IsPresent) {
    Get-Module -ListAvailable | ForEach-Object {
        Write-Output "$($_.Name)"
    }
} else {
    $root = Find-ModuleRoot -Path $Path
    if ($root) {
        Get-ChildItem "$($root.FullName)\Modules" | ForEach-Object {
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
}
