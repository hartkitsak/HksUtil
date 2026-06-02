$script:desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"

if ($controls["BtnCreateShortcut"]) {
    $controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = $script:desktopShortcutPath
        if (Test-Path $lnkPath) { Write-Log "Shortcut already exists." "Warn"; return }
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $shortcut.TargetPath = "powershell.exe"
            $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            $shortcut.WorkingDirectory = $script:appRoot
            $shortcut.Description = "HksUtil v2.0 - Windows Optimizer"
            $shortcut.Save()
            Write-Log "Desktop shortcut created." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
    })
}
