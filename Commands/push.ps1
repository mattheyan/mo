<#

.SYNOPSIS

Pushes a PowerShell module, via a NuGet package, to a package server.

#>
[CmdletBinding()]
param(
    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

Write-Output "Command 'push' in not yet implemented."
Write-Output "https://github.com/mattheyan/PowerShellModuleTool/issues/5"
