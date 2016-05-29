<#

.SYNOPSIS

Creates a NuGet package for publishing a PowerShell module.

#>
[CmdletBinding()]
param(
    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

Write-Output "Command 'pack' in not yet implemented."
Write-Output "https://github.com/mattheyan/PowerShellModuleTool/issues/4"
