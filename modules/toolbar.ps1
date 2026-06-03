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
        if ($script:currentTheme -eq "dark") { Apply-Theme "light" } else { Apply-Theme "dark" }
    })
}

if ($controls["BtnGearExport"]) {
    $controls["BtnGearExport"].Add_Click({
        try {
            $sfd = New-Object Microsoft.Win32.SaveFileDialog
            $sfd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $sfd.Title = "Export Config"
            $sfd.FileName = "HksUtil-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).json"
            $sfd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $sfd.ShowDialog($window)
            if ($result -ne $true) { return }
            $data = @{
                AppSelections = @($appCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
                TweakSelections = @($tweakCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
                FeatureSelections = @($featuresCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
            }
            $prefState = @{}
            foreach ($pk in $prefCheckboxes.Keys) {
                if ($prefCheckboxes[$pk]) { $prefState[$pk] = ($prefCheckboxes[$pk].IsChecked -eq $true) }
            }
            $data.PreferenceStates = $prefState
            $json = $data | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($sfd.FileName, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Log "Exported to $($sfd.FileName)" "Success"
            Show-Info "Export Complete" "Config exported to:`n$($sfd.FileName)"
        } catch { Write-Log "Export failed: $_" "Error" }
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearImport"]) {
    $controls["BtnGearImport"].Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        try {
            $ofd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $ofd.Title = "Import Config"
            $ofd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $ofd.ShowDialog($window)
            if ($result -ne $true) { return }
            $json = [System.IO.File]::ReadAllText($ofd.FileName, [System.Text.UTF8Encoding]::new($false))
            $data = $json | ConvertFrom-Json

            # NEW format: AppSelections (array of winget IDs)
            if ($data.AppSelections) {
                foreach ($aid in $data.AppSelections) {
                    $cb = $appCheckboxes | Where-Object { $_.Tag -eq $aid }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            # OLD format: CheckedApps (array of {Name, Content})
            if ($data.CheckedApps) {
                foreach ($appEntry in $data.CheckedApps) {
                    $cb = $appCheckboxes | Where-Object { $_.Tag -eq $appEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            # NEW format: TweakSelections (array of keys)
            if ($data.TweakSelections) {
                foreach ($tk in $data.TweakSelections) {
                    $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tk }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            # OLD format: CheckedTweaks (array of {Name, Content})
            if ($data.CheckedTweaks) {
                foreach ($tweakEntry in $data.CheckedTweaks) {
                    $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tweakEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            if ($data.FeatureSelections) {
                foreach ($fk in $data.FeatureSelections) {
                    $cb = $featuresCheckboxes | Where-Object { $_.Tag -eq $fk }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            if ($data.PreferenceStates) {
                foreach ($pk in $data.PreferenceStates.PSObject.Properties.Name) {
                    if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $data.PreferenceStates.$pk -eq $true }
                }
            }

            Write-Log "Imported from $($ofd.FileName)" "Success"
            Show-Info "Import Complete" "Configuration imported."
        } catch { Write-Log "Import failed: $_" "Error" }
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
