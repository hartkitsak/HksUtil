if ($sync.controls["BtnCreateShortcut"]) {
    $sync.controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $isTempPath = $PSCommandPath -and ($PSCommandPath -like "$($env:TEMP)\*")
            if ($PSCommandPath -and -not $isTempPath -and (Test-Path $PSCommandPath)) {
                $target = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
                $cmd = "Start-Process powershell.exe -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"'"
            } else {
                $target = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
                $cmd = "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/hartkitsak/HksUtil/main/install.ps1' -UseBasicParsing | Invoke-Expression"
            }
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
            $shortcutArgs = "-ExecutionPolicy Bypass -NoProfile -EncodedCommand $encoded"

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
