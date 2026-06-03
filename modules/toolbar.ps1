if ($controls["BtnToolbarClose"]) {
    $controls["BtnToolbarClose"].Add_Click({ $window.Close() })
}

if ($controls["BtnToolbarMinimize"]) {
    $controls["BtnToolbarMinimize"].Add_Click({ $window.WindowState = "Minimized" })
}

if ($controls["BtnToolbarMaximize"]) {
    $controls["BtnToolbarMaximize"].Add_Click({
        $window.WindowState = if ($window.WindowState -eq "Maximized") { "Normal" } else { "Maximized" }
    })
}

if ($controls["BtnToolbarTheme"]) {
    $controls["BtnToolbarTheme"].Add_Click({
        if ($script:currentTheme -eq "dark") { Set-Theme "light" } else { Set-Theme "dark" }
    })
}

if ($controls["BtnGearExport"]) {
    $controls["BtnGearExport"].Add_Click({
        try {
            $data = @{
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Version = $sync.version
                LogLines = $script:logLines
                CheckedApps = @($appCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { @{Name = $_.Tag; Content = $_.Content} })
                CheckedTweaks = @($tweakCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { @{Name = $_.Tag; Content = $_.Content} })
            }
            $json = $data | ConvertTo-Json -Depth 5
            $path = [Environment]::GetFolderPath("Desktop") + "\HksUtil-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).json"
            [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Log "Exported to $path" "Success"
            Show-Info "Export Complete" "Config exported to:`n$path"
        } catch { Write-Log "Export failed: $_" "Error" }
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearImport"]) {
    $controls["BtnGearImport"].Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        try {
            $ofd.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $ofd.Title = "Import Config"
            $ofd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $ofd.ShowDialog($window)
            if ($result -ne $true) { return }
            $json = [System.IO.File]::ReadAllText($ofd.FileName, [System.Text.UTF8Encoding]::new($false))
            $data = $json | ConvertFrom-Json
            if ($data.CheckedApps) {
                foreach ($appEntry in $data.CheckedApps) {
                    $cb = $appCheckboxes | Where-Object { $_.Tag -eq $appEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            if ($data.CheckedTweaks) {
                foreach ($tweakEntry in $data.CheckedTweaks) {
                    $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tweakEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            Write-Log "Imported from $($ofd.FileName)" "Success"
            Show-Info "Import Complete" "Configuration imported."
        } catch { Write-Log "Import failed: $_" "Error" }
        finally { $ofd.Dispose() }
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearAbout"]) {
    $controls["BtnGearAbout"].Add_Click({
        Show-Info "About HksUtil v2.0" "HksUtil v2.0 - Windows Optimizer`n`nA Windows utility for application management, system tweaks, DNS configuration, and more.`n`nBuilt with PowerShell and WPF."
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearDocs"]) {
    $controls["BtnGearDocs"].Add_Click({
        Start-Process "https://github.com/hartkitsak/HksUtil"
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearSponsors"]) {
    $controls["BtnGearSponsors"].Add_Click({
        Show-Info "Sponsors" "HksUtil is an open-source project.`n`nIf you find this tool useful, consider supporting the project."
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}
