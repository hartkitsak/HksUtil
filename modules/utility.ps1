$script:desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"

if ($controls["BtnCreateShortcut"]) {
    $controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = $script:desktopShortcutPath
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $shortcut.TargetPath = "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe"
            $shortcut.Arguments = '-ExecutionPolicy Bypass -Command "Start-Process powershell.exe -verb runas -ArgumentList ''-Command \"irm https://raw.githubusercontent.com/hartkitsak/HksUtil/main/hksutil.ps1 | iex\"''"'
            $shortcut.Description = "HksUtil v2.0 - Windows Optimizer"
            $shortcut.IconLocation = "C:\WINDOWS\system32\pifmgr.dll, 4"
            $shortcut.Save()
            Write-Log "Desktop shortcut created." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}
