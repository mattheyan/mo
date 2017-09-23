[CmdletBinding()]
param(
    [Alias('p')]
    [string]$Path=$PWD.Path,

    [ValidateSet('ModuleDotPsd1File', 'ModulesFolder')]
    [string[]]$Indicators=@('ModuleDotPsd1File')
)

# Based on NPM (and git) file/folder searchig algorithm.
# https://docs.npmjs.com/files/folders#more-information

$foundItem = $null

Write-Verbose "Checking directory '$($Path)'..."
if ((.\Test-ModuleRoot.ps1 $Path -Indicators $Indicators)) {
    $foundItem = (Get-Item $Path)
} else {
    Get-ParentItem -Path $Path -Recurse | ForEach-Object {
        Write-Verbose "Checking directory '$($_.FullName)'..."
        if ((.\Test-ModuleRoot.ps1 $_.FullName -Indicators $Indicators)) {
            $foundItem = $_
            break
        }
    }
}

Write-Output $foundItem
