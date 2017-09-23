<#

.SYNOPSIS
Displays the `PSModulePath` environment variable.

#>
function Invoke-ModulePathGetCommand {
    [CmdletBinding()]
    param(
    )

    $PSModulePath = Get-ModulePath
    $PSModulePath | Select-Object -ExpandProperty 'Path'
}
