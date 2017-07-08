function Get-ModuleSource {
    [CmdletBinding()]
    param(
    )

    Get-PackageSource -ProviderName 'NuGet'
}
