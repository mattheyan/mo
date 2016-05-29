<#

.SYNOPSIS

Creates a link to a PowerShell module, or references a linked module.

#>
[CmdletBinding()]
param(
    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

Write-Output "Command 'link' in not yet implemented."
Write-Output "https://github.com/mattheyan/PowerShellModuleTool/issues/3"
