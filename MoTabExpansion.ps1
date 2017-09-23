function script:MoTabExpansion($lastBlock) {
    $lastBlock > "C:\Windows\Temp\MoTabExpansion-$([DateTime]::Now.ToFileTime()).txt"

    return $moCommands
}

$script:moCommands = @('install', 'publish', 'source', 'path')
