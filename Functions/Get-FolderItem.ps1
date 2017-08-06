Function Get-FolderItem {
    <#
        .SYNOPSIS
            Lists all files under a specified folder regardless of character limitation on path depth.

        .DESCRIPTION
            Lists all files under a specified folder regardless of character limitation on path depth.

        .PARAMETER Path
            The type name to list out available constructors and parameters

        .PARAMETER Filter
            Optional parameter to specify a specific file or file type. Wildcards (*) allowed.
            Default is '*.*'
        
        .PARAMETER ExcludeFile
            Exclude Files matching given names/paths/wildcards

        .PARAMETER MaxAge
            Exclude files older than n days.

        .PARAMETER MinAge
            Exclude files newer than n days.     

        .EXAMPLE
            Get-FolderItem -Path "C:\users\Administrator\Desktop\PowerShell Scripts"

            LastWriteTime : 4/25/2012 12:08:06 PM
            FullName      : C:\users\Administrator\Desktop\PowerShell Scripts\3_LevelDeep_ACL.ps1
            Name          : 3_LevelDeep_ACL.ps1
            ParentFolder  : C:\users\Administrator\Desktop\PowerShell Scripts
            Length        : 4958

            LastWriteTime : 5/29/2012 6:30:18 PM
            FullName      : C:\users\Administrator\Desktop\PowerShell Scripts\AccountAdded.ps1
            Name          : AccountAdded.ps1
            ParentFolder  : C:\users\Administrator\Desktop\PowerShell Scripts
            Length        : 760

            LastWriteTime : 4/24/2012 5:48:57 PM
            FullName      : C:\users\Administrator\Desktop\PowerShell Scripts\AccountCreate.ps1
            Name          : AccountCreate.ps1
            ParentFolder  : C:\users\Administrator\Desktop\PowerShell Scripts
            Length        : 52812

            Description
            -----------
            Returns all files under the PowerShell Scripts folder.

        .EXAMPLE
            $files = Get-ChildItem | Get-FolderItem
            $files | Group-Object ParentFolder | Select Count,Name

            Count Name
            ----- ----
                95 C:\users\Administrator\Desktop\2012 12 06 SysInt
                15 C:\users\Administrator\Desktop\DataMove
                5 C:\users\Administrator\Desktop\HTMLReportsinPowerShell
                31 C:\users\Administrator\Desktop\PoshPAIG_2_0_1
                30 C:\users\Administrator\Desktop\PoshPAIG_2_1_3
                67 C:\users\Administrator\Desktop\PoshWSUS_2_1
                437 C:\users\Administrator\Desktop\PowerShell Scripts
                9 C:\users\Administrator\Desktop\PowerShell Widgets
                92 C:\users\Administrator\Desktop\Working

            Description
            -----------
            This example shows Get-FolderItem taking pipeline input from Get-ChildItem and then saves
            the output to $files. Group-Object is used with $Files to show the count of files in each
            folder from where the command was executed.

        .EXAMPLE
            Get-FolderItem -Path $Pwd -MinAge 45

            LastWriteTime : 4/25/2012 12:08:06 PM
            FullName      : C:\users\Administrator\Desktop\PowerShell Scripts\3_LevelDeep_ACL.ps1
            Name          : 3_LevelDeep_ACL.ps1
            ParentFolder  : C:\users\Administrator\Desktop\PowerShell Scripts
            Length        : 4958

            LastWriteTime : 5/29/2012 6:30:18 PM
            FullName      : C:\users\Administrator\Desktop\PowerShell Scripts\AccountAdded.ps1
            Name          : AccountAdded.ps1
            ParentFolder  : C:\users\Administrator\Desktop\PowerShell Scripts
            Length        : 760

            Description
            -----------
            Gets files that have a LastWriteTime of greater than 45 days.

        .INPUTS
            System.String
        
        .OUTPUTS
            System.IO.RobocopyDirectoryInfo

        .NOTES
            Name: Get-FolderItem
            Author: Boe Prox
            Date Created: 31 March 2013
            Version History:
            Version 1.12 - 31 Jul 2017
                - Fix typo
            Version 1.11 - 27 Jul 2017
                - Quote excluded files and directories with spaces
                - No job summary
                - Ignore blank lines
            Version 1.10 - 27 Jul 2017
                - Change 'ExcludeDirectories' to 'IgnoreDirectories'
                - Add parameter 'ExcludeDirectory'
                - Use full regex matches
                - Escape dollar signs in script
                - Handle files without an extension
                - Don't return the root directory in results
            Version 1.9 - 21 Jul 2017
                - Always include folders in robocopy output
            Version 1.8 - 21 Jul 2017
                - Don't trim whitespace in results
            Version 1.7 - 20 Jul 2017
                - Add 'Type' property to distinguish between files and directories
                - Add LastWriteTimeUtc and parse the timestamp as UTC
                - Add '.' prefix on extension to make more consistent with 'Get-Item' output
                - Adjust properties to more closely match 'Get-Item' output
                - Add option to exclude junction points
                - Change 'IncludeDirectories' to 'ExcludeDirectories'
            Version 1.6 - 18 Jul 2017
                - Option to include folders
                - Optionally show progress
            Version 1.5 - 09 Jan 2014
                -Fixed bug in ExcludeFile parameter; would only work on one file exclusion and not multiple
                -Allowed for better streaming of output by Invoke-Expression to call the command vs. invoking
                a scriptblock and waiting for that to complete before display output.  
            Version 1.4 - 27 Dec 2013
                -Added FullPathLength property          
            Version 1.3 - 08 Nov 2013
                -Added ExcludeFile parameter
            Version 1.2 - 29 July 2013
                -Added Filter parameter for files
                -Fixed bug with ParentFolder property
                -Added default value for Path parameter            
            Version 1.1
                -Added ability to calculate file hashes
            Version 1.0
                -Initial Creation
    #>
    [cmdletbinding(DefaultParameterSetName='Filter')]
    Param (
        [parameter(Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('FullName')]
        [string[]]$Path = $PWD,

        [string[]]$Filter = '*.*',    
        [string[]]$ExcludeFile,              
        [string[]]$ExcludeDirectory,              
        [switch]$ExcludeJunctions,
        [int]$MaxAge,
        [int]$MinAge,
        [switch]$IgnoreDirectories,
        [switch]$ReportProgress
    )
    Begin {
        $params = New-Object System.Collections.Arraylist
        $params.Add("/L") | Out-Null
        $params.Add("/E") | Out-Null
        $params.AddRange(@("/NJH","/NJS","/BYTES","/FP","/NC")) | Out-Null
        if ($ExcludeJunctions.IsPresent) {
            $params.Add("/XJ") | Out-Null
        }
        $params.AddRange(@("/TS","/R:0","/W:0")) | Out-Null
        If ($PSBoundParameters['MaxAge']) {
            $params.Add("/MaxAge:$MaxAge") | Out-Null
        }
        If ($PSBoundParameters['MinAge']) {
            $params.Add("/MinAge:$MinAge") | Out-Null
        }
    }
    Process {
        $itemIdx = 0
        $itemCount = ([array]$Path).Count
        $itemScale = 100 / $itemCount
        ForEach ($item in $Path) {
            Try {
                $foundDirectories = @()
                $item = (Resolve-Path -LiteralPath $item -ErrorAction Stop).ProviderPath
                If (-Not (Test-Path -LiteralPath $item -Type Container -ErrorAction Stop)) {
                    Write-Warning ("{0} is not a directory and will be skipped" -f $item)
                    Return
                }

                if ($item.EndsWith('\')) {
                    $itemFullName = $item.Substring(0, $item.Length - 1)
                } else {
                    $itemFullName = $item
                }

                $xf = ''
                if ($ExcludeFile) {
                    $xf = ($ExcludeFile | ForEach-Object { if ($_ -like '* *') { "`"$($_)`"" } else { $_ }}) -join ' '
                }

                $xd = ''
                if ($ExcludeDirectory) {
                    $xd = ($ExcludeDirectory | ForEach-Object { if ($_ -like '* *') { "`"$($_)`"" } else { $_ }}) -join ' '
                }

                $Script = "robocopy `"$item`" NULL $Filter $params $(if($xf){'/XF '+$xf}) $(if($xd){'/XD '+$xd})" -replace "\`$", '`$'
                Write-Verbose ("Scanning {0}" -f $item)
                Write-Verbose "PS> $Script"
                if ($ReportProgress) {
                    $outputIdx = 0
                    $outputLines = [array](Invoke-Expression $Script)
                    $outputCount = $outputLines.Count
                    Write-Progress -Activity 'Scanning Folders' -CurrentOperation $item -PercentComplete (($itemIdx / $itemCount) * 100)
                } else {
                    $outputLines = Invoke-Expression $Script
                }
                $outputLines | ForEach {
                    if ($_) {
                        Try {
                            If ($_ -match "^\s*(?<Size>\d+)\s(?<Date>\S+\s\S+)\s+(?<FullName>.*[^\\])$") {
                                Write-Verbose ("Matched: '{0}'" -f $_)
                                $dir = $matches.fullname -replace '^(.*\\).*$','$1'
                                if ($ReportProgress) {
                                    Write-Progress -Activity 'Scanning Folders' -CurrentOperation $dir -PercentComplete ((($itemIdx / $itemCount) * 100) + (($outputIdx / $outputCount) * $itemScale))
                                }
                                $object = New-Object PSObject -Property @{
                                    Type = 'File'
                                    Directory = $matches.fullname -replace '^(.*)\\.*$','$1'
                                    FullName = $matches.FullName
                                    Name = $matches.fullname -replace '^.*\\(.*)$','$1'
                                    Length = [int64]$matches.Size
                                    LastWriteTime = [DateTime]::Parse("$($matches.Date)Z")
                                    LastWriteTimeUtc = [DateTime]::Parse("$($matches.Date)Z").ToUniversalTime()
                                    Extension = $(if (($matches.fullname -replace '^.*\\(.*)$','$1') -like '*.*') { $matches.fullname -replace '^.*(\.[^\\]+)$', '$1' })
                                }
                                $object.pstypenames.insert(0,'System.IO.RobocopyDirectoryInfo')
                                Write-Output $object
                            } ElseIf ($_ -match "^\s*(?<Size>\d+)\s(?<FullName>.*)\\$") {
                                Write-Verbose ("Matched: '{0}'" -f $_)
                                if ($ReportProgress) {
                                    Write-Progress -Activity 'Scanning Folders' -CurrentOperation $matches.fullname -PercentComplete ((($itemIdx / $itemCount) * 100) + (($outputIdx / $outputCount) * $itemScale))
                                }
                                if (-not($IgnoreDirectories.IsPresent)) {
                                    if ($matches.FullName -ne $itemFullName) {
                                        $object = New-Object PSObject -Property @{
                                            Type = 'Directory'
                                            FullName = $matches.FullName
                                            Name = $matches.fullname -replace '^.*\\(.*)$','$1'
                                            Length = [int64]$matches.Size
                                        }
                                        $object.pstypenames.insert(0,'System.IO.RobocopyDirectoryInfo')
                                        Write-Output $object
                                    }
                                }
                            } Else {
                                Write-Verbose ("Not matched: {0}" -f $_)
                            }
                        } Catch {
                            Write-Warning ("{0}" -f $_.Exception.Message)
                            Return
                        }
                        if ($ReportProgress.IsPresent) {
                            $outputIdx += 1
                        }
                    }
                }
            } Catch {
                Write-Warning ("{0}" -f $_.Exception.Message)
                Return
            }

            if ($ReportProgress.IsPresent) {
                $itemIdx += 1
            }
        }
    }
}
