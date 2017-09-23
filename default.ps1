properties {
    $githubSpec = "^github:\s*([^/]+)/([^/]+)(/.*)?$"

    #$value = 'github:Iristyle/Midori/tools/NuGet.psm1'
    #$value = 'github:OpenMagic/BuildMagic'
    $value = 'github: davotronic5000/PowerShell_Credential_Manager'
}

task DownloadFromGithub {

    if (-not($value -match $githubSpec)) {
        Write-Error "URL '$($value)' is not a valid github spec."
    }

    $owner = $value -replace $githubSpec, '$1'
    $repo = $value -replace $githubSpec, '$2'
    $path = $value -replace $githubSpec, '$3'

    if ($path) {
        $path = $path.Substring(1)

        #$url = "https://raw.githubusercontent.com/$($owner)/$($repo)/master/$path"
        $url = "https://github.com/$($owner)/$($repo)/raw/master/$path"

        Write-Host $url

        $temp = [System.IO.Path]::GetTempFileName()
        $client = New-Object 'System.Net.WebClient'
        $client.DownloadFile($url, $temp) | Out-Null

        # Launch the file in notepad
        & notepad $temp
    } else {
        # $url = "https://codeload.github.com/$($owner)/$($repo)/zip/develop"
        $url = "https://github.com/$($owner)/$($repo)/archive/develop.zip"

        Write-Host $url

        $temp = [System.IO.Path]::GetTempFileName()
        Remove-Item $temp -ErrorAction SilentlyContinue | Out-Null
        $temp = $temp.Substring(0, $temp.Length - 4)
        $client = New-Object 'System.Net.WebClient'
        $client.DownloadFile($url, "$($temp).zip") | Out-Null

        Expand-Archive -Path "$($temp).zip" -DestinationPath $temp -Silent

        explorer "$($temp)\$($repo)-develop"
    }

}
