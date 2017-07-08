function Remove-ModuleSource {
    [CmdletBinding()]
    param(
        [Alias('n')]
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    Unregister-PackageSource -Name $Name
}
