function Install-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name
    )

    Write-Verbose "Searching for module root from '$($PWD.Path)'..."

    $root = Find-ModuleRoot

    if ($root) {
        Write-Verbose "Found module root '$($root)'."

        $package = Find-Package -Name $Name

        $package | Save-Package -Path "$($root)\Modules"
    } else {
        Write-Error "Couldn't find module root."
    }
}
