################################################################################
#  ModuleTools v0.1.0                                                          #
#                                                                              #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

Get-ChildItem "$($PSScriptRoot)\Functions" -Recurse -Filter *.ps1 | ForEach-Object {
    Write-Verbose "Importing '$($_.FullName)'..."
    . $_.FullName
}

Get-ChildItem "$($PSScriptRoot)\Commands" -Recurse -Filter *.ps1 | ForEach-Object {
    Write-Verbose "Importing '$($_.FullName)'..."
    . $_.FullName
}

. $PSScriptRoot\MoTabExpansion.ps1

function Set-MoTabExpansion {
    if (Test-Path Function:\TabExpansion) {
        Rename-Item Function:\TabExpansion TabExpansionBackup
    }

    function global:TabExpansion($line, $lastWord) {
        $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()

        switch -regex ($lastBlock) {
            # Execute git tab completion for all git-related commands
            "^$(Get-AliasPattern mo) (.*)" { MoTabExpansion $lastBlock }

            # Fall back on existing tab expansion
            default {
                if (Test-Path Function:\TabExpansionBackup) {
                    TabExpansionBackup $line $lastWord
                }
            }
        }
    }
}

Set-MoTabExpansion

function Write-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message
    )

    Write-Host $Message
}

function Get-TempFolder {
    [CmdletBinding()]
    param(
    )

    $tempFolder = "$($env:TEMP)\Mo"

    if (-not(Test-Path $tempFolder)) {
        mkdir $tempFolder | Out-Null
    }

    if (-not(Test-Path "$tempFolder\.staging")) {
        New-Item "$tempFolder\.staging" -Type Directory | Out-Null
        $stagingFolderItem = Get-Item "$tempFolder\.staging"
        $stagingFolderItem.Attributes += 'Hidden'
    }

    $stagingFolderItem = Get-Item "$tempFolder\.staging" -Force

    if (-not($stagingFolderItem.Attributes -match '(^|,)\s*Hidden\s*($|,)')) {
        Write-Warning "Staging folder is not hidden."
    }

    return $tempFolder
}

function Get-Hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$InputObject,

        [ValidateSet('Bytes', 'String', 'Guid')]
        [string]$OutputType = 'Bytes'
    )

    if (-not($OutputType)) {
        $outputType = 'Bytes'
    }

    $md5 = [System.Security.Cryptography.MD5]::Create()

    $data = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($InputObject))

    if ($OutputType -eq 'String') {
        return ([System.Text.Encoding]::UTF8.GetString($data))
    } elseif ($OutputType -eq 'Guid') {
        return (New-Object 'System.Guid' -ArgumentList (,$data))
    } else {
        return $data
    }
}

function Invoke-MoCommand {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        $Params
    )

    $PSModuleAutoloadingPreference = 'None'

    $ErrorActionPreference = 'Stop'
    $InformationPreference = 'Continue'

    $here = Split-Path $script:MyInvocation.MyCommand.Path -Parent

    if ($Params -contains '-Verbose' -or $Params -contains '-v') {
        $VerbosePreference = 'Continue'
    }

    <#
    try {
    #>

    $positionalArgs = @('Arg0', 'Arg1')

    Write-Verbose "Parsing unbound arguments..."
    $parsedArgs = $Params | ConvertTo-ParameterHash -PositionalParameters $positionalArgs -ErrorAction Stop

    # Write-Verbose "Args:`r`n$(($parsedArgs.Keys | foreach { (' ' * 11) + $_ + '=' + $parsedArgs[$_] }) -join "`r`n")"

    $verboseEnabled = $parsedArgs | Extract-HashtableKey -Keys 'Verbose','v' -DefaultValue $false

    if ($verboseEnabled) {
        $VerbosePreference = 'Continue'
    }

    if ($parsedArgs.ContainsKey('Arg0')) {
        $arg0 = $parsedArgs['Arg0']
        $parsedArgs.Remove('Arg0') | Out-Null

        if ($parsedArgs.ContainsKey('Arg1')) {
            $arg1 = $parsedArgs['Arg1']
            $parsedArgs.Remove('Arg1') | Out-Null
        } else {
            $arg1 = $null
        }
    } else {
        throw 'Invalid Usage'
    }

    if ($parsedArgs.ContainsKey('Verbose')) {
        $VerbosePreference = 'Continue'
        $parsedArgs.Remove('Verbose') | Out-Null
    }

    Write-Verbose "Checking for 'Invoke-Module$($arg0)Command' cmdlet."
    $cmdlet = Get-Command "Invoke-Module$($arg0)Command" -Module 'Mo' -EA 0

    if ($cmdlet) {
        $verb = $arg0
        $noun = 'Module'

        if ($arg1) {
            $arg0 = $arg1
            $arg1 = $null
        } else {
            $arg0 = $null
        }
    } else {
        if ($arg1) {
            Write-Verbose "Checking for 'Invoke-Module$($arg0)$($arg1)Command' cmdlet."
            $cmdlet = Get-Command "Invoke-Module$($arg0)$($arg1)Command" -Module 'Mo' -EA 0
            if ($cmdlet) {
                $verb = $arg1
                $noun = "Module$($arg0)"

                $arg0 = $null
                $arg1 = $null
            } else {
                throw 'Invalid Usage'
            }
        } else {
            Write-Verbose "Checking for 'Invoke-Module$($arg0)GetCommand' cmdlet."
            $cmdlet = Get-Command "Invoke-Module$($arg0)GetCommand" -Module 'Mo' -EA 0
            if ($cmdlet) {
                $verb = "Get"
                $noun = "Module$($arg0)"

                if ($arg1) {
                    $arg0 = $arg1
                    $arg1 = $null
                } else {
                    $arg0 = $null
                }
            } else {
                throw 'Invalid Usage'
            }
        }
    }

    Write-Verbose "Found cmdlet '$($cmdlet)'."

    if ($arg0) {
        $parameterSets = [array]($cmdlet.Parameters.Values | Select-Object -ExpandProperty ParameterSets -Unique)
        if ($parameterSets.Count -eq 1) {
            $param0 = [array]($cmdlet.Parameters.Values | Where-Object { $_.Attributes.Position -eq 0 })
            if ($param0.Count -eq 1) {
                $parsedArgs[$param0[0].Name] = $arg0
            } else {
                Write-Error "Can't apply positional argument to command $($cmdlet.Name) with $($param0.Count) parameters with position = 0."
                return
            }
        } else {
            Write-Error "Can't apply positional argument to command $($cmdlet.Name) with $($parameterSets.Count) parameter sets."
            return
        }
    }

    Write-Verbose "Parameters:"
    foreach ($key in $parsedArgs.Keys) {
        Write-Verbose "  $($key): $($parsedArgs[$key])"
    }

    & $cmdlet @parsedArgs

    <#
    } catch {
        if ($_.Exception.Message -ne 'Invalid Usage') {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }

        ""
        "Usage:"
        "  mo <command> ...args"
        ""
        "Commands:"
        "  path      - View or modify the %PSModulePath% environment variable"
        ""
    }
    #>
}
