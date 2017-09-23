function Invoke-Robocopy {
    [CmdletBinding(DefaultParameterSetName='TopLevelCopy', SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        # Source Directory (drive:\path or \\server\share\path).
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Source,

        # Destination Dir  (drive:\path or \\server\share\path).
        [Parameter(ParameterSetName='TopLevelCopy', Mandatory=$true, Position=1)]
        [Parameter(ParameterSetName='TopLevelCopyListOnly', Position=1)]
        [Parameter(ParameterSetName='MirrorDirectoryTree', Mandatory=$true, Position=1)]
        [Parameter(ParameterSetName='MirrorDirectoryTreeListOnly', Position=1)]
        [Parameter(ParameterSetName='CopySubdirectories', Mandatory=$true, Position=1)]
        [Parameter(ParameterSetName='CopySubdirectoriesListOnly', Position=1)]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmpty', Mandatory=$true, Position=1)]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmptyListOnly', Position=1)]
        [string]$Destination,

        # File(s) to copy  (names/wildcards: default is "*.*").
        [Parameter(Position=2)]
        [string[]]$File,

        # MIRror a directory tree (equivalent to -E plus -PURGE).
        [Alias('MIR')]
        [Parameter(ParameterSetName='MirrorDirectoryTree', Mandatory=$true)]
        [Parameter(ParameterSetName='MirrorDirectoryTreeListOnly', Mandatory=$true)]
        [switch]$MirrorDirectoryTree,

        [Alias('L')]
        [Parameter(ParameterSetName='TopLevelCopyListOnly', Mandatory=$true)]
        [Parameter(ParameterSetName='MirrorDirectoryTreeListOnly', Mandatory=$true)]
        [Parameter(ParameterSetName='CopySubdirectoriesListOnly', Mandatory=$true)]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmptyListOnly', Mandatory=$true)]
        [switch]$ListOnly,

        [Alias('S')]
        [Parameter(ParameterSetName='CopySubdirectories', Mandatory=$true)]
        [Parameter(ParameterSetName='CopySubdirectoriesListOnly', Mandatory=$true)]
        [switch]$CopySubdirectories,

        [Alias('E')]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmpty', Mandatory=$true)]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmptyListOnly', Mandatory=$true)]
        [switch]$CopySubdirectoriesIncludingEmpty,

        # Exclude files matching given names/paths/wildcards.
        [string[]]$ExcludeDirectories,

        # Exclude directories matching given names/paths.
        [string[]]$ExcludeFiles,

        [Alias('NP')]
        [Parameter(ParameterSetName='TopLevelCopy')]
        [Parameter(ParameterSetName='TopLevelCopyListOnly')]
        [Parameter(ParameterSetName='MirrorDirectoryTree')]
        [Parameter(ParameterSetName='MirrorDirectoryTreeListOnly')]
        [Parameter(ParameterSetName='CopySubdirectories')]
        [Parameter(ParameterSetName='CopySubdirectoriesListOnly')]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmpty')]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmptyListOnly')]
        [switch]$NoProgress,

        [Parameter(ParameterSetName='TopLevelCopyListOnly')]
        [Parameter(ParameterSetName='MirrorDirectoryTreeListOnly')]
        [Parameter(ParameterSetName='CopySubdirectoriesListOnly')]
        [Parameter(ParameterSetName='CopySubdirectoriesIncludingEmptyListOnly')]
        [switch]$ShowProgress,

        [Alias('TS')]    
        [switch]$IncludeTimeStamps,

        [int]$MinAge,

        [int]$MaxAge,

        [Alias('R')]
        [int]$NumberOfRetries,

        [Alias('W')]
        [int]$WaitTimeBetweenRetries,

        [Alias('FP')]
        [switch]$IncludeFullPathName,

        [Alias('BYTES')]
        [switch]$PrintSizesAsBytes,

        [Alias('NC')]    
        [switch]$NoClass,

        [Alias('XJ')]    
        [switch]$ExcludeJunctionPoints,

        [Alias('NDL')]
        [switch]$NoDirectoryList,

        [Alias('NJH')]
        [switch]$NoJobHeader,

        [Alias('NJS')]
        [switch]$NoJobSummary
    )

    # https://gallery.technet.microsoft.com/scriptcenter/Get-Deeply-Nested-Files-a2148fd7

    # Write-Host "ParameterSet: $($PSCmdlet.ParameterSetName)"

    if (-not(Test-Path -LiteralPath $Source -Type 'Container' -ErrorAction 'Stop')) {
        Write-Error ("Path '$($Source)' is not a directory.")
        return
    }

    # https://blogs.technet.microsoft.com/deploymentguys/2008/06/16/robocopy-exit-codes/
    $validExitCodes = @(
        0, # No errors occurred and no files were copied.
        1 # One of more files were copied successfully.
    )

    $argsArray = New-Object 'System.Collections.Generic.List[string]'

    # $argsArray.Add('robocopy') | Out-Null

    if ($Source -like '* *') {
        $argsArray.Add("`"$($Source)`"") | Out-Null
    } else {
        $argsArray.Add($Source) | Out-Null
    }

    if ($Destination) {
        if ($Destination -like '* *') {
            $argsArray.Add("`"$($Destination)`"") | Out-Null
        } else {
            $argsArray.Add($Destination) | Out-Null
        }
    } else {
        $argsArray.Add('NULL') | Out-Null
    }

    if ($File) {
        $argsArray.AddRange($File) | Out-Null
    }

    if ($ExcludeFiles) {
        $argsArray.Add('/XF') | Out-Null
        foreach ($xf in $ExcludeFiles) {
            if ($xf -like '* *') {
                $argsArray.Add("`"$($xf)`"") | Out-Null
            } else {
                $argsArray.Add($xf) | Out-Null
            }
        }
    }

    if ($ExcludeDirectories) {
        $argsArray.Add('/XD') | Out-Null
        foreach ($xd in $ExcludeDirectories) {
            if ($xd -like '* *') {
                $argsArray.Add("`"$($xd)`"") | Out-Null
            } else {
                $argsArray.Add($xd) | Out-Null
            }
        }
    }

    if ($PrintSizesAsBytes.IsPresent) {
        $argsArray.Add('/BYTES') | Out-Null
    }

    if ($IncludeFullPathName.IsPresent) {
        $argsArray.Add('/FP') | Out-Null
    }

    if ($NoClass.IsPresent) {
        $argsArray.Add('/NC') | Out-Null
    }

    if ($NoDirectoryList.IsPresent) {
        $argsArray.Add("/NDL") | Out-Null
    }

    if ($IncludeTimeStamps.IsPresent) {
        $argsArray.Add("/TS") | Out-Null
    }

    if ($ExcludeJunctionPoints.IsPresent) {
        $argsArray.Add("/XJ") | Out-Null
    }

    if ($PSBoundParameters['NumberOfRetries']) {
        $argsArray.Add("/R:$($NumberOfRetries)") | Out-Null
    }

    if ($PSBoundParameters['WaitTimeBetweenRetries']) {
        $argsArray.Add("/W:$($WaitTimeBetweenRetries)") | Out-Null
    }

    if ($PSBoundParameters['MinAge']) {
        $argsArray.Add("/MinAge:$MinAge") | Out-Null
    }

    if ($PSBoundParameters['MaxAge']) {
        $argsArray.Add("/MaxAge:$MaxAge") | Out-Null
    }

    if ($MirrorDirectoryTree.IsPresent) {
        $argsArray.Add('/MIR') | Out-Null
    }

    if (($ListOnly.IsPresent -and $ShowProgress.IsPresent) -or (-not($ListOnly.IsPresent) -and -not($NoProgress.IsPresent))) {
        $listArgsArray = New-Object 'System.Collections.Generic.List[string]'

        $listArgsArray.Add('robocopy') | Out-Null

        $listArgsArray.AddRange($argsArray) | Out-Null

        $listArgsArray.Add('/L') | Out-Null
        $listArgsArray.Add('/NJH') | Out-Null
        $listArgsArray.Add('/NJS') | Out-Null

        # Write-Host "$($listArgsArray -join ' ')"

        $listOutput = Invoke-ApplicationWithOptions -ArgsArray $listArgsArray -EnsureSuccess $false -ReturnType Output

        Write-Verbose $listOutput

        $lineCount = (($listOutput) -split "`r`n").Count

        $itemCount = $lineCount - 2
    }

    if ($ListOnly.IsPresent) {
        $argsArray.Add('/L') | Out-Null
    }

    if ($NoJobHeader.IsPresent) {
        $argsArray.Add('/NJH') | Out-Null
    }

    if ($NoJobSummary.IsPresent) {
        $argsArray.Add('/NJS') | Out-Null
    }

    $Script = "robocopy $($argsArray)"

    Write-Verbose "PS> $Script"

    if (($ListOnly.IsPresent -and $ShowProgress.IsPresent) -or (-not($ListOnly.IsPresent) -and -not($NoProgress.IsPresent))) {
        $itemIdx = 0
        Write-Progress -Activity 'Robocopy' -PercentComplete (($itemIdx / $itemCount) * 100)
        Invoke-Expression $Script | ForEach {
            if ($_ -match "^\s*(?<Size>\d+)\s(?<Date>\S+\s\S+)\s+(?<FullName>.*[^\\])\s*$") {
                $dir = $matches.FullName -replace '^(.*)\\[^\\]+$', '$1'
                Write-Progress -Activity 'Robocopy' -CurrentOperation $dir -PercentComplete (($itemIdx / $itemCount) * 100)
            } elseif ($_ -match "^\s*(?<Size>\d+)\s(?<FullName>.*)\\\s*$") {
                # Write-Progress -Activity 'Scanning Folders' -CurrentOperation $matches.FullName -PercentComplete ((($itemIdx / $itemCount) * 100) + (($outputIdx / $outputCount) * $itemScale))
            }

            Write-Output $_

            $itemIdx += 1
        }
    } else {
        Invoke-Expression $Script

        if (-not($validExitCodes -contains $LASTEXITCODE)) {
            Write-Error "Robocopy failed with code $($LASTEXITCODE)."
        }
    }
}
