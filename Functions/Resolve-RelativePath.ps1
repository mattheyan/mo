function Resolve-RelativePath {
    [CmdletBinding()]
    param(
        [Alias('Path')]
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$InputObject,

        [Alias('Root')]
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    process {
        if ($InputObject.StartsWith("~")) {
            if ($InputObject -eq '~') {
                $relativePath = $null
            } elseif ($InputObject.StartsWith("~\") -or $InputObject.StartsWith("~/")) {
                $relativePath = $InputObject.Substring(2)
            } else {
                Write-Error "Unknown relative path '$($InputObject)'."
                return
            }

            if ($relativePath) {        
                $fullPath = (Join-Path $RootPath $relativePath)
            } else {
                $fullPath = $RootPath
            }
        } else {
            $fullPath = $InputObject
        }

        Write-Output (Resolve-Path $fullPath)
    }
}
