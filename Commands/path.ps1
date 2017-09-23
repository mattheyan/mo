<#

.SYNOPSIS

Lists or modifies the paths in the `PSModulePath` environment variable.

#>
[CmdletBinding()]
param(
    # The action to perform on the `PSModulePath` setting.
    [ValidateSet('list', 'add', 'remove')]
    [Parameter(Position = 0)]
    [string]$Action='list',

    # The path to include on the PSModulePath variable.
    [Alias('p')]
    [Parameter()]
    [string]$Path=$PWD.Path,

    [Parameter()]
    [switch]$Force,

    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

if ($Action -eq 'list') {

    ($env:PSModulePath -split ';') | select @{Name='Path';Expression={$_}}

} elseif ($Action -eq 'add') {

    if (($env:PSModulePath -split ';') -contains $Path) {
        Write-Host "Path already contains '$($Path)' in the current session."
    } else {
        $env:PSModulePath += ";$Path"
        Write-Host "Added '$($Path)' to ``PSModulePath`` for the current session." -ForegroundColor Cyan
    }

    $machineValue = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
    if (($machineValue -split ';') -contains $Path) {
        Write-Host "Machine-level ``PSModulePath`` already contains '$($Path)'."
    } else {
        $userValue = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'User')
        if (-not(($userValue -split ';') -contains $Path)) {
            $userValue += ";$($Path)"
            [System.Environment]::SetEnvironmentVariable('PSModulePath', $userValue, 'User')
            Write-Host "Added '$($Path)' to ``PSModulePath`` for the current user." -ForegroundColor Cyan
        }
    }

} elseif ($Action -eq 'remove') {

    $machineValue = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
    if (($machineValue -split ';') -contains $Path) {
        Write-Warning "Cannot remove path '$($Path)' from machine-level ``PSModulePath``."
    } else {

        $userValue = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'User')
        if (($userValue -split ';') -contains $Path) {
            $newUserValue = (($userValue -split ';') | Where-Object { $_ -ne $Path }) -join ';'
            [System.Environment]::SetEnvironmentVariable('PSModulePath', $newUserValue, 'User')
            Write-Host "Removed '$($Path)' from ``PSModulePath`` for the current user." -ForegroundColor Cyan
        }

        if (($env:PSModulePath -split ';') -contains $Path) {
            $env:PSModulePath = (($env:PSModulePath -split ';') | Where-Object { $_ -ne $Path }) -join ';'
            Write-Host "Removed '$($Path)' from ``PSModulePath`` for the current session." -ForegroundColor Cyan
        }

    }

}
