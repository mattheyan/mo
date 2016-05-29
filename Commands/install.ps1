<#

.SYNOPSIS

Installs a PowerShell module locally or globally.

#>
[CmdletBinding()]
param(
    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

Write-Output "Command 'install' in not yet implemented."
Write-Output "https://github.com/mattheyan/PowerShellModuleTool/issues/2"
