<#

.SYNOPSIS

Builds a PowerShell module from a collection of script files.

#>
[CmdletBinding()]
param(
    # http://stackoverflow.com/a/2795683
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

$moduleRoot = Find-ModuleRoot -Indicators ModuleDotPsd1File
if (-not($moduleRoot)) {
    Write-Error "Cannot find module root from '$($PWD.Path)'."
    return
}

$moduleSpec = Import-PSData (Join-Path $moduleRoot 'module.psd1')

# Name, Version, and Author are required.

$manifestArgs = @{
    Path = ".\$($moduleSpec.Name).psd1"
    RootModule = "$($moduleSpec.Name).psm1"
    ModuleVersion = $moduleSpec.Version
    Author = $moduleSpec.Author
    Copyright = $moduleSpec.Copyright
    Description = $moduleSpec.Description
}

if ($moduleSpec.Id) {
    $manifestArgs['Guid'] = $moduleSpec.Id
} else {
    # If an id is not speicified, then generate a repeatable
    # guid based on the module name (which shouldn't change).
    $manifestArgs['Guid'] = Get-ModuleGuid $moduleSpec.Name
}

if ($moduleSpec.Company) {
    $manifestArgs['CompanyName'] = $moduleSpec.Company
} else {
    $manifestArgs['CompanyName'] = 'None'
}

if ($moduleSpec.Dependencies) {
    $manifestArgs['RequiredModules'] = $moduleSpec.Dependencies
}

# Create a new module manifest
New-ModuleManifest @manifestArgs

# Invoke an `Assemble` script build
Invoke-ScriptBuild -Name $moduleSpec.Name -Force -ErrorAction Stop `
    -SourcePath (Join-Path $moduleRoot 'Scripts') `
    -TargetPath $moduleRoot `

Write-Output $moduleSpec
