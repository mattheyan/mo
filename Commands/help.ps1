<#

.SYNOPSIS

Displays general help information or help about specific commands.

#>
[CmdletBinding()]
param(
    [Alias('t')]
    [Parameter(HelpMessage='The command to retreive help for.')]
    # The command to retreive help for.
    [string]$Command,

    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

$here = Split-Path $MyInvocation.MyCommand.Path -Parent

$commandPath = Join-Path $here "$($Command).ps1"

if (Test-Path $commandPath) {
    $help = Get-Help $commandPath
    $usageText = ((($help.syntax | Out-String) -split "`r`n") | Where-Object -Property Length -GT 0) -join ' '
    $usage = $usageText.Replace($commandPath, $Command).Replace("  [<CommonParameters>]", '').Replace(" [<CommonParameters>]", '').Replace(" [[-Params] <Object>]", '').Replace(" [[-Params]  <Object>]", '')
    $parameters = $help.parameters | ForEach-Object parameter | Where-Object -Property name -NE 'Params'

    Write-Host "Usage: mo $usage"
    Write-Host ""
    Write-Host $help.Synopsis
    Write-Host ""
    $parameters | ForEach-Object {
        Write-Host " -$($_.name)" -NoNewLine
        for ($len = $_.name.Length + 2; $len -lt 20; $len += 1) {
            Write-Host ' ' -NoNewLine
        }
        $_.description | ForEach-Object Text | Write-Host
    } | Out-Null
    Write-Host ""
} else {
    Write-Host "Unknown command: '$($Command)'" -ForegroundColor Red
    exit 1
}
