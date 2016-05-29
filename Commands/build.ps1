<#

.SYNOPSIS

Builds a PowerShell module from a collection of script files.

#>
[CmdletBinding()]
param(
    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

Write-Output "Command 'build' in not yet implemented."
Write-Output "https://github.com/mattheyan/PowerShellModuleTool/issues/1"
