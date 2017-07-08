# To avoid NuGet provider install prompt?
# (get-packageprovider -Name NuGet).Version
# Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

function Get-ModuleSource {
    [CmdletBinding()]
    param(
    )

    Get-PackageSource -ProviderName 'NuGet'
}

function Add-ModuleSource {
    [CmdletBinding()]
    param(
        [Alias('n')]
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Alias('s')]
        [Alias('Source')]
        [Parameter(Mandatory=$true)]
        [string]$Location,

        [switch]$Trusted
    )

    Register-PackageSource -Name $Name -Location $Location -Trusted -ProviderName 'NuGet'
}

function Remove-ModuleSource {
    [CmdletBinding()]
    param(
        [Alias('n')]
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    Unregister-PackageSource -Name $Name
}
