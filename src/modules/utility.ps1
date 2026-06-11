if ($sync.controls["BtnCreateShortcut"]) {
    $sync.controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $scriptPath = if ($PSCommandPath -and (Test-Path $PSCommandPath)) { $PSCommandPath } else { Join-Path $script:appRoot "app.ps1" }
            if (-not (Test-Path $scriptPath)) {
                Show-Info "Shortcut Failed" "Cannot locate script at:`n$scriptPath`n`nUse -Dev mode, or save hksutil.ps1 to disk first."
                return
            }
            $target = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $innerArgs = "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
            $innerArgsEscaped = $innerArgs -replace '"', '\"'
            $shortcutArgs = "-ExecutionPolicy Bypass -NoProfile -Command `"Start-Process powershell.exe -Verb RunAs -ArgumentList '$innerArgsEscaped'`""

            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $shortcut.TargetPath = $target
            $shortcut.Arguments = $shortcutArgs
            $shortcut.Description = "HksUtil v$($sync.version) - Windows Optimizer"
            $shortcut.WorkingDirectory = (Split-Path $scriptPath -Parent)
            $shortcut.IconLocation = "$([Environment]::SystemDirectory)\imageres.dll, 109"
            $shortcut.WindowStyle = 7
            $shortcut.Save()

            Write-Log "Desktop shortcut created (elevated)." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}
