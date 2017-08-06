function Get-RelativePath {
    [CmdletBinding(DefaultParameterSetName='Path')]
    param(
        [Parameter(ParameterSetName='Path', Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string[]]$Path,

        [Parameter(ParameterSetName='LiteralPath', Mandatory=$true)]
        [string[]]$LiteralPath,

        [Parameter(Mandatory=$true)]
        [string]$Root
    )

    if ($LiteralPath) {
        Write-Verbose "Getting relative path for '$($LiteralPath)' within root '$($Root)'."
    } else {
        Write-Verbose "Getting relative path for '$($Path)' within root '$($Root)'."

        $pathObj = Resolve-Path $Path -EA 0
        if (-not($pathObj)) {
            Write-Error "Couldn't resolve path '$($Path)'."
            return
        }

        $literalPath = $pathObj.Path
    }

    if ($Root.EndsWith('\') -or $Root.EndsWith('/')) {
        # Trim trailing slashes
        $Root = $Root.Substring(0, $Root.Length - 1)
    }

    if ($literalPath -eq $Root) {
        Write-Verbose "Given path is equal to the root."
        return ''
    }

    if ($literalPath.StartsWith($Root, $true, [CultureInfo]::CurrentCulture)) {
        $relativePath = ".\$($literalPath.Substring($Root.Length + 1))"
    } else {
        try {
            Push-Location $Root

            $relativePath = Resolve-Path -LiteralPath $literalPath -Relative
        } finally {
            Pop-Location
        }
    }

    if (-not($relativePath)) {
        Write-Error "Couldn't get relative path for item '$($literalPath)'."
        return
    }

    Write-Verbose "Resolved relative path '$($relativePath)'."

    if ($relativePath -eq "..\$(Split-Path $literalPath -Leaf)") {
        Write-Verbose "Given path is equal to the root."
        $relativePath = ''
    } elseif ($relativePath.StartsWith(".\")) {
        $relativePath = $relativePath.Substring(2)
    } elseif ($relativePath.StartsWith("..\")) {
        Write-Error "File '$($literalPath)' doesn't exist within '$($Root)'."
        return
    } elseif ($relativePath -eq (Split-Path $literalPath -Leaf)) {
        # File or directory is within root directory
    } else {
        Write-Error "Unexpected relative path '$($relativePath)' for item '$($literalPath)'."
        return
    }

    return $relativePath
}
