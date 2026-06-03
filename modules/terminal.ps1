if ($controls["TerminalInput"]) {
    $controls["TerminalInput"].Add_KeyDown({
        param($sender, $e)
        if ($e.Key -eq "Return") {
            $input = $controls["TerminalInput"].Text
            if ([string]::IsNullOrWhiteSpace($input)) { return }
            Write-Log "> $input" "Cmd"
            $result = Invoke-TerminalAction $input
            $controls["TerminalInput"].Text = ""
            if (-not [string]::IsNullOrWhiteSpace($result)) { Write-Log $result "Info" }
            $e.Handled = $true
        }
    })
}

if ($controls["BtnTerminalRun"]) {
    $controls["BtnTerminalRun"].Add_Click({
        $script_ = $controls["TerminalInput"].Text
        if ([string]::IsNullOrWhiteSpace($script_)) { return }
        Write-Log "> $script_" "Cmd"
        $result = Invoke-TerminalAction $script_
        $controls["TerminalInput"].Text = ""
        if (-not [string]::IsNullOrWhiteSpace($result)) { Write-Log $result "Info" }
    })
}

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

function Invoke-TerminalAction {
    param($InputText)
    $lower = $InputText.Trim().ToLower()
    switch -Wildcard ($lower) {
        "clear" { $script:logLines.Clear(); Show-HksUtilLogo; return $null }
        "help" { return "Commands: clear, help, theme <dark|light>, winget <args>, choco <args>, ps <cmd>" }
        "theme dark" { Apply-Theme "dark"; return $null }
        "theme light" { Apply-Theme "light"; return $null }
        default {
            if ($lower -match "^(winget|choco)\s") {
                $cmd = $InputText.Trim()
                Write-Log "Executing: $cmd (in visible console window)..." "Info"
                if (-not (Show-Confirm "$($InputText.Split(' ')[0]).exe" "Run '$cmd' in a new console window?")) { return $null }
                try {
                    Start-Process cmd.exe -ArgumentList "/k $cmd" -NoNewWindow:$false
                    Write-Log "Launched in new window." "Success"
                    return $null
                } catch { return "Failed to launch: $_" }
            } elseif ($lower -match "^ps\s") {
                $scriptCmd = $InputText.Trim().Substring(3)
                try {
                    $output = Invoke-Expression $scriptCmd 2>&1 | Out-String
                    if ([string]::IsNullOrWhiteSpace($output)) { return "OK" }
                    return $output.Trim()
                } catch { return "Error: $_" }
            } else { return "Unknown command. Type 'help'." }
        }
    }
}
