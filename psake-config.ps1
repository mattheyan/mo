# Use the default for consistency
$config.buildFileName="default.ps1"

# Model output after gulp
$config.taskNameFormat = {
    param(
        $taskName
    )

    $ts = Get-Date

    Write-Host "[" -NoNewLine
    Write-Host "$($ts.ToString('HH:mm:ss'))" -ForegroundColor Gray -NoNewLine
    Write-Host "] Starting '" -NoNewLine
    Write-Host $taskName -ForegroundColor DarkCyan -NoNewLine
    Write-Host "'..."
}

$config.modules = @(
    '.\Modules\7zip\7zip.psd1'
)
