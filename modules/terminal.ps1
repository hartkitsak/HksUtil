if ($controls["BtnTerminalDotfiles"]) {
    $controls["BtnTerminalDotfiles"].Add_Click({
        $profilePath = Join-Path $env:USERPROFILE ".config\powershell\profile.ps1"
        $dir = Split-Path $profilePath -Parent
        if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
        $content = @"
# HksUtil Terminal Profile
Set-Alias hksutil "& '$script:appRoot\app.ps1'"
function Invoke-HksUtil { & '$script:appRoot\app.ps1' }
"@
        [System.IO.File]::WriteAllText($profilePath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Log "Terminal profile installed: $profilePath" "Success"
        Show-Info "Terminal Profile" "Profile installed to:`n$profilePath"
    })
}

if ($controls["BtnUninstallTerminal"]) {
    $controls["BtnUninstallTerminal"].Add_Click({
        $profilePath = Join-Path $env:USERPROFILE ".config\powershell\profile.ps1"
        if (Test-Path $profilePath) {
            Remove-Item $profilePath -Force
            Write-Log "Terminal profile removed." "Success"
            Show-Info "Terminal Profile" "Profile removed."
        } else { Write-Log "No profile found at $profilePath" "Warn"; Show-Info "Terminal Profile" "No profile found." }
    })
}
