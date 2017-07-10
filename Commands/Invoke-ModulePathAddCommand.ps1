<#

.SYNOPSIS
Adds a path to the `PSModulePath` environment variable.

#>
function Invoke-ModulePathAddCommand {
    [CmdletBinding()]
    param(
	    # The path to include in the PSModulePath variable.
	    [Parameter(Mandatory=$true, Position=0)]
	    [string]$Path
    )

    Add-ModulePath -Path $Path
}
