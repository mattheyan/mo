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
