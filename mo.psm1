$root = Split-Path $MyInvocation.MyCommand.Path -Parent

Write-Verbose "Importing modules..."
Get-ChildItem "$($root)\Modules" | ForEach-Object {
    if ($_.PSIsContainer) {
        Write-Verbose "Searching directory '$($_.Name)'..."
        $psd1 = Join-Path $_.FullName "$($_.Name).psd1"
        if (Test-Path $psd1) {
            Write-Verbose "Importing '$($_.Name).psd1'..."
            Import-Module $psd1
        } else {
            $psm1 = Join-Path $_.FullName "$($_.Name).psm1"
            if (Test-Path $psm1) {
                Write-Verbose "Importing '$($_.Name).psm1'..."
                Import-Module $psd1
            } else {
                Write-Verbose "No module in directory."
            }
        }
    }
}

function Test-ModuleRoot {
    [CmdletBinding()]
    param(
        [Alias('p')]
        [string]$Path=$PWD.Path
    )

    if (Test-Path (Join-Path $Path 'module.psd1')) {
        return $true
    }

    if (Test-Path (Join-Path $Path 'Modules')) {
        return $true
    }

    return $false
}

# Based on NPM (and git) file/folder searchig algorithm.
# https://docs.npmjs.com/files/folders#more-information
function Find-ModuleRoot {
    [CmdletBinding()]
    param(
        [Alias('p')]
        [string]$Path=$PWD.Path
    )

    $markerItem = $null

    Write-Verbose "Checking directory '$($Path)'..."
    if (Test-ModuleRoot $Path) {
        $markerItem = (Get-Item $Path)
    } else {
        Get-ParentItem -Path $Path -Recurse | ForEach-Object {
            Write-Verbose "Checking directory '$($_.FullName)'..."
            if (Test-ModuleRoot $_.FullName) {
                $markerItem = $_
                break
            }
        }
    }

    Write-Output $markerItem
}
