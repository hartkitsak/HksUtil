if ($sync.controls["BtnCreateShortcut"]) {
    $sync.controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $isTempPath = $PSCommandPath -and ($PSCommandPath -like "$($env:TEMP)\*")
            if ($PSCommandPath -and -not $isTempPath -and (Test-Path $PSCommandPath)) {
                $shortcutArgs = "-ExecutionPolicy Bypass -Command Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"'"
            } else {
                $shortcutArgs = "-ExecutionPolicy Bypass -Command Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command `"Invoke-WebRequest -Uri ''https://raw.githubusercontent.com/hartkitsak/HksUtil/main/install.ps1'' -UseBasicParsing | Invoke-Expression`"'"
            }
            $target = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $shortcut.TargetPath = $target
            $shortcut.Arguments = $shortcutArgs
            $shortcut.Description = "HksUtil v$($sync.version) - Windows Optimizer"
            $shortcut.WorkingDirectory = if ($PSCommandPath -and -not $isTempPath -and (Test-Path $PSCommandPath)) { Split-Path $PSCommandPath -Parent } else { $env:USERPROFILE }
            $shortcut.IconLocation = "$([Environment]::SystemDirectory)\imageres.dll, 109"
            $shortcut.WindowStyle = 7
            $shortcut.Save()

            Write-Log "Desktop shortcut created (elevated)." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}
