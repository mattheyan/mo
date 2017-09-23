$projectRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent

. "$($projectRoot)\MoTabExpansion.ps1"

Describe "MoTabExpansion" {
    Context "When no arguments are specified" {
        It "Should return the list of commands" {
            Write-Host "Comparing file output to expected results..."
            $te = MoTabExpansion "mo "
            ($te -join "|") | Should Be "install|publish|source|path"
        }
    }
}
