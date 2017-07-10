<#

.SYNOPSIS
Removes a registered module source.

#>
function Invoke-ModuleSourceRemoveCommand {
    [CmdletBinding()]
    param(
        [Alias('n')]
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    Unregister-PackageSource -Name $Name
}
