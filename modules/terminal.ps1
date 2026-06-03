if ($controls["BtnTerminalDotfiles"]) {
    $controls["BtnTerminalDotfiles"].Add_Click({
        Write-Log "Installing Nova profile..." "Info"
        try {
            iex (irm "https://raw.githubusercontent.com/hartkitsak/nova/master/install.ps1")
            Write-Log "Nova install complete." "Success"
        } catch { Write-Log "Nova install failed: $_" "Error" }
    })
}

if ($controls["BtnUninstallTerminal"]) {
    $controls["BtnUninstallTerminal"].Add_Click({
        Write-Log "Uninstalling Nova profile..." "Info"
        try {
            iex (irm "https://raw.githubusercontent.com/hartkitsak/nova/master/uninstall.ps1")
            Write-Log "Nova uninstall complete." "Success"
        } catch { Write-Log "Nova uninstall failed: $_" "Error" }
    })
}
