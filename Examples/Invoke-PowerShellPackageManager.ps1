$PSModuleAutoloadingPreference = 'None'

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$here = Split-Path $script:MyInvocation.MyCommand.Path -Parent

if ($Args -contains '-Verbose' -or $Args -contains '-v') {
    $VerbosePreference = 'Continue'
}

Write-Verbose "InvocationSource: $InvocationSource"

<#
try {
#>

$positionalArgs = @('Arg0', 'Arg1')

Write-Verbose "Parsing unbound arguments..."
$parsedArgs = $Args | & "$($here)\ConvertTo-ParameterHash.ps1" -PositionalParameters $positionalArgs -ErrorAction Stop

Write-Verbose "Args:`r`n$(($parsedArgs.Keys | foreach { (' ' * 11) + $_ + '=' + $parsedArgs[$_] }) -join "`r`n")"

$invocationSource = $parsedArgs | & "$($here)\Extract-HashtableKey.ps1" -Keys 'InvocationSource' -DefaultValue 'PowerShell'

$global:MO_InvocationSource = $InvocationSource

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

Write-Verbose "Checking for '$($arg0)-Module' cmdlet."
$cmdlet = Get-Command "$($arg0)-Module" -Module 'PowerShellPackageManager' -EA 0

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
        Write-Verbose "Checking for '$($arg1)-Module$($arg0)' cmdlet."
        $cmdlet = Get-Command "$($arg1)-Module$($arg0)" -Module 'PowerShellPackageManager' -EA 0
        if ($cmdlet) {
            $verb = $arg1
            $noun = "Module$($arg0)"

            $arg0 = $null
            $arg1 = $null
        } else {
            throw 'Invalid Usage'
        }
    } else {
        Write-Verbose "Checking for 'Get-Module$($arg0)' cmdlet."
        $cmdlet = Get-Command "Get-Module$($arg0)" -Module 'PowerShellPackageManager' -EA 0
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

if ($verb -eq 'Get') {
    $result = & $cmdlet @parsedArgs
    if ($noun -eq 'ModulePath') {
        $result | Select-Object -ExpandProperty 'Path'
    } elseif ($noun -eq 'ModuleSource') {
        $result | ForEach-Object {
            Write-Output "$($_.Name) - $($_.Location) ($(if ($_.IsTrusted) { 'Trusted' } else { 'Untrusted' }))"
        }
    } else {
        $result
    }
} else {

    & $cmdlet @parsedArgs
}

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
