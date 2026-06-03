$script:desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"

if ($sync.controls["BtnCreateShortcut"]) {
    $sync.controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = $script:desktopShortcutPath
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $pwshPath = (Get-Command powershell.exe).Source
            $shortcut.TargetPath = $pwshPath
            $shortcut.Arguments = "-ExecutionPolicy RemoteSigned -NoProfile -File `"$($sync.appRoot)\app.ps1`""
            $shortcut.Description = "HksUtil v2.0 - Windows Optimizer"
            $shortcut.IconLocation = "$([Environment]::SystemDirectory)\shell32.dll, 1"
            $shortcut.Save()
            Write-Log "Desktop shortcut created." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}
