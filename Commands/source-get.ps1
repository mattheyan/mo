<#

.SYNOPSIS
Gets the registered module sources.

#>
function Invoke-ModuleSourceGetCommand {
    [CmdletBinding()]
    param(
    )

    $sources = Get-PackageSource -ProviderName 'NuGet'
    
    $sources | ForEach-Object {
        Write-Output "$($_.Name) - $($_.Location) ($(if ($_.IsTrusted) { 'Trusted' } else { 'Untrusted' }))"
    }
}
