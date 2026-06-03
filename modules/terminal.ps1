if ($sync.controls["BtnTerminalDotfiles"]) {
    $sync.controls["BtnTerminalDotfiles"].Add_Click({
        Write-Log "Installing Nova profile..." "Info"
        try {
            $tmp = "$env:TEMP\nova-install.ps1"
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hartkitsak/nova/master/install.ps1" -OutFile $tmp -UseBasicParsing
            & $tmp
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Log "Nova install complete." "Success"
        } catch { Write-Log "Nova install failed: $_" "Error" }
    })
}

if ($sync.controls["BtnUninstallTerminal"]) {
    $sync.controls["BtnUninstallTerminal"].Add_Click({
        Write-Log "Uninstalling Nova profile..." "Info"
        try {
            $tmp = "$env:TEMP\nova-uninstall.ps1"
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hartkitsak/nova/master/uninstall.ps1" -OutFile $tmp -UseBasicParsing
            & $tmp
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Log "Nova uninstall complete." "Success"
        } catch { Write-Log "Nova uninstall failed: $_" "Error" }
    })
}
