if ($controls["BtnTerminalDotfiles"]) {
    $controls["BtnTerminalDotfiles"].Add_Click({
        Write-Log "Installing Nova profile..." "Info"
        try {
            $cmd = 'irm https://raw.githubusercontent.com/hartkitsak/nova/master/install.ps1 | iex'
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -NoNewWindow:$false
            Write-Log "Nova installer launched in new window." "Success"
        } catch { Write-Log "Failed to launch Nova installer: $_" "Error" }
    })
}

if ($controls["BtnUninstallTerminal"]) {
    $controls["BtnUninstallTerminal"].Add_Click({
        Write-Log "Uninstalling Nova profile..." "Info"
        try {
            $cmd = 'irm https://raw.githubusercontent.com/hartkitsak/nova/master/uninstall.ps1 | iex'
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -NoNewWindow:$false
            Write-Log "Nova uninstaller launched in new window." "Success"
        } catch { Write-Log "Failed to launch Nova uninstaller: $_" "Error" }
    })
}
