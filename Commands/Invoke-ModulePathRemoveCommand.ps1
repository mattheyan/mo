<#

.SYNOPSIS
Removes a path from the `PSModulePath` environment variable.

#>
function Invoke-ModulePathRemoveCommand {
    [CmdletBinding()]
    param(
	    # The path to remove from the PSModulePath variable.
	    [Parameter(Mandatory=$true, Position=0)]
	    [string]$Path
    )

    Remove-ModulePath -Path $Path
}
