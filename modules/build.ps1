$appCheckboxes = @()
$tweakCheckboxes = @()
$featuresCheckboxes = @()
$prefCheckboxes = @{}
$appPanels = @()
$script:categoryItems = @{}
$script:categoryCollapsed = @{}

# --- Build Apps UI ---
$appPanelIndex = 0
if (($controls["AppPanel1"] -and $controls["AppPanel2"] -and $controls["AppPanel3"]) -and $appsConfig) {
    $appPanels = @($controls["AppPanel1"], $controls["AppPanel2"], $controls["AppPanel3"])
    foreach ($category in $appsConfig.PSObject.Properties.Name) {
        $catCount = ($appsConfig.$category.PSObject.Properties.Name).Count
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = "- $($category.ToUpper()) ($catCount)"; $header.Style = Get-WpfResource "CategoryHeader"; $header.Cursor = "Hand"
        $header.Tag = $category
        $appPanels[$appPanelIndex].Children.Add($header) | Out-Null
        $script:categoryItems[$category] = @()
        $header.Add_MouseLeftButtonDown({
            $cat = $this.Tag
            $collapsed = $script:categoryCollapsed[$cat]
            $script:categoryCollapsed[$cat] = -not $collapsed
            foreach ($item in $script:categoryItems[$cat]) {
                $item.Visibility = if ($script:categoryCollapsed[$cat]) { "Collapsed" } else { "Visible" }
            }
            $this.Text = if ($script:categoryCollapsed[$cat]) { "+ $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" } else { "- $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" }
        })
        foreach ($appKey in $appsConfig.$category.PSObject.Properties.Name) {
            $app = $appsConfig.$category.$appKey
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $app.content; $cb.Tag = $app.winget; $cb.Style = Get-WpfResource "TweakCheckBox"
            if ($app.description) { $cb.ToolTip = "$($app.content)`n`n$($app.description)`n`nID: $($app.winget)" }
            $cb.Add_Checked({ Update-SelectedCount })
            $cb.Add_Unchecked({ Update-SelectedCount })
            $cm = New-Object System.Windows.Controls.ContextMenu
            $miInstall = New-Object System.Windows.Controls.MenuItem; $miInstall.Header = "Install"; $miInstall.Tag = $app.winget
            $miInstall.Add_Click({
                $id = $this.Tag; $pkg = $script:pkgManager; Write-Log "Context: Install $id via $pkg" "Info"
                if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
                if (-not (Show-Confirm "Install" "Install $id via $pkg?")) { return }
                Show-Progress -Text "Installing: $id" -Value 0.5
                try { if ($pkg -eq "winget") { winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null } else { choco install $id -y 2>&1 | Out-Null }; Write-Log "Installed: $id" "Success" } catch { Write-Log "Failed: $id" "Error" }
                Hide-Progress; Update-InstalledCache; Show-Info "Done" "Install of $id completed."
            })
            $miUninstall = New-Object System.Windows.Controls.MenuItem; $miUninstall.Header = "Uninstall"; $miUninstall.Tag = $app.winget
            $miUninstall.Add_Click({
                $id = $this.Tag; $pkg = $script:pkgManager; Write-Log "Context: Uninstall $id via $pkg" "Info"
                if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
                if (-not (Show-Confirm "Uninstall" "Uninstall $id via $pkg?")) { return }
                Show-Progress -Text "Uninstalling: $id" -Value 0.5
                try { if ($pkg -eq "winget") { winget uninstall --id=$id --silent --purge --accept-source-agreements 2>&1 | Out-Null } else { choco uninstall $id -y 2>&1 | Out-Null }; Write-Log "Uninstalled: $id" "Success" } catch { Write-Log "Failed: $id" "Error" }
                Hide-Progress; Update-InstalledCache; Show-Info "Done" "Uninstall of $id completed."
            })
            $miInfo = New-Object System.Windows.Controls.MenuItem; $miInfo.Header = "Info"; $miInfo.Tag = $app
            $miInfo.Add_Click({ $a = $this.Tag; Show-Info "App Info" "$($a.content)`n`nID: $($a.winget)`n$($a.description)" })
            $null = $cm.Items.Add($miInstall); $null = $cm.Items.Add($miUninstall); $null = $cm.Items.Add((New-Object System.Windows.Controls.Separator)); $null = $cm.Items.Add($miInfo)
            $cb.ContextMenu = $cm
            $appPanels[$appPanelIndex].Children.Add($cb) | Out-Null
            $appCheckboxes += $cb
            $script:categoryItems[$category] += $cb
        }
        $appPanelIndex = ($appPanelIndex + 1) % 3
    }
    foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false }
    Write-Log "Built $($appCheckboxes.Count) app cards." "Success"
}

# --- Build Preferences UI ---
$panelIndex = 0
if ($controls["PrefsPanel1"] -and $controls["PrefsPanel2"] -and $controls["PrefsPanel3"] -and $prefsConfig) {
    $prefPanels = @($controls["PrefsPanel1"], $controls["PrefsPanel2"], $controls["PrefsPanel3"])
    foreach ($prefKey in $prefsConfig.PSObject.Properties.Name) {
        $pref = $prefsConfig.$prefKey
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $pref.content; $cb.Tag = $prefKey; $cb.Style = Get-WpfResource "ToggleSwitch"
        if ($pref.description) { $cb.ToolTip = $pref.description }
        $currentState = $null
        $hasRegistryOn = $pref.PSObject.Properties.Name -contains "registry_on" -and $pref.registry_on -and $pref.registry_on.Count -gt 0
        if ($hasRegistryOn) {
            $firstReg = $pref.registry_on[0]
            if (Test-Path $firstReg.path) { try { $currentState = (Get-ItemProperty $firstReg.path -Name $firstReg.name -ErrorAction SilentlyContinue).$($firstReg.name) } catch { Write-Log "Registry read failed: $_" "Warn" } }
        }
        $cb.IsChecked = if ($hasRegistryOn) { $currentState -eq $pref.registry_on[0].value } else { $false }
        $cb.Add_Checked({
            $pk = $this.Tag; $p = $prefsConfig.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_on") { foreach ($r in $p.registry_on) { try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; $t = if ($r.type) { $r.type } else { "String" }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Type $t -Force } catch { Write-Log "Registry write failed: $($r.path) $($r.name)" "Warn" } } }
            Write-Log "Pref ON: $($p.content)" "Success"
        })
        $cb.Add_Unchecked({
            $pk = $this.Tag; $p = $prefsConfig.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_off") { foreach ($r in $p.registry_off) { try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; $t = if ($r.type) { $r.type } else { "String" }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Type $t -Force } catch { Write-Log "Registry write failed: $($r.path) $($r.name)" "Warn" } } }
            Write-Log "Pref OFF: $($p.content)" "Warn"
        })
        $prefPanels[$panelIndex].Children.Add($cb) | Out-Null
        $prefCheckboxes[$prefKey] = $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($prefCheckboxes.Count) preference toggles." "Success"
}

# --- Build Tweaks UI ---
$panelIndex = 0
if ($controls["TweaksPanel1"] -and $controls["TweaksPanel2"] -and $controls["TweaksPanel3"] -and $tweaksConfig) {
    $panels = @($controls["TweaksPanel1"], $controls["TweaksPanel2"], $controls["TweaksPanel3"])
    foreach ($groupKey in $tweaksConfig.PSObject.Properties.Name) {
        $group = $tweaksConfig.$groupKey
        $header = New-Object System.Windows.Controls.TextBlock; $header.Text = $groupKey; $header.FontSize = 16; $header.FontWeight = "Bold"
        $header.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "categoryHeaderColor"); $header.Margin = "0,0,0,10"
        $panels[$panelIndex].Children.Add($header) | Out-Null
        foreach ($tweakKey in $group.PSObject.Properties.Name) {
            $tweak = $group.$tweakKey
            $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $tweak.content; $cb.Tag = $tweakKey; $cb.Style = Get-WpfResource "TweakCheckBox"
            if ($tweak.description) { $cb.ToolTip = $tweak.description }
            $panels[$panelIndex].Children.Add($cb) | Out-Null
            $tweakCheckboxes += $cb
        }
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($tweakCheckboxes.Count) tweak checkboxes." "Success"
}

# --- Build Features & Fixes UI ---
$panelIndex = 0
if ($controls["FeaturesPanel1"] -and $controls["FeaturesPanel2"] -and $controls["FeaturesPanel3"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Features") {
    $featPanels = @($controls["FeaturesPanel1"], $controls["FeaturesPanel2"], $controls["FeaturesPanel3"])
    foreach ($featKey in $featuresConfig.Features.PSObject.Properties.Name) {
        $feat = $featuresConfig.Features.$featKey
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $feat.content; $cb.Tag = $featKey; $cb.Style = Get-WpfResource "TweakCheckBox"
        if ($feat.description) { $cb.ToolTip = $feat.description }
        $featPanels[$panelIndex].Children.Add($cb) | Out-Null
        $featuresCheckboxes += $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($featuresCheckboxes.Count) feature checkboxes." "Success"
}
if ($controls["FixesWrapPanel"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Fixes") {
    foreach ($fixKey in $featuresConfig.Fixes.PSObject.Properties.Name) {
        $fix = $featuresConfig.Fixes.$fixKey
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "FeatureCard"; $btn.Content = $fix.content; $btn.ToolTip = $fix.description; $btn.Tag = $fix
        $btn.Add_Click({
            $f = $this.Tag
            if (-not (Show-Confirm "Run Fix" "Execute: $($f.content)?")) { return }
            Write-Log "Running fix: $($f.content)" "Header"
            try { & ([scriptblock]::Create($f.script)); Write-Log "Fix completed: $($f.content)" "Success"; Show-Info "Fix Complete" "$($f.content)`n`nCompleted successfully." } catch { Write-Log "Fix failed: $_" "Error"; Show-Info "Fix Failed" "$($f.content)`n`nError: $_" }
        })
        $controls["FixesWrapPanel"].Children.Add($btn) | Out-Null
    }
    Write-Log "Built $($featuresConfig.Fixes.PSObject.Properties.Name.Count) fix buttons." "Success"
}

# --- Build Legacy Windows Panels UI ---
$legacyPanels = @(
    @{ Name = "Computer Management"; Desc = "Manage disks, services, event viewer, and more"; Command = "compmgmt.msc" },
    @{ Name = "Control Panel"; Desc = "Classic Windows Control Panel"; Command = "control" },
    @{ Name = "Device Manager"; Desc = "View and update hardware devices and drivers"; Command = "devmgmt.msc" },
    @{ Name = "Disk Management"; Desc = "Manage disk partitions, volumes, and drives"; Command = "diskmgmt.msc" },
    @{ Name = "Event Viewer"; Desc = "View system logs and application events"; Command = "eventvwr.msc" },
    @{ Name = "Network Connections"; Desc = "Manage network adapters and connections"; Command = "ncpa.cpl" },
    @{ Name = "Power Panel"; Desc = "Configure power plans and battery settings"; Command = "powercfg.cpl" },
    @{ Name = "Printer Panel"; Desc = "Manage printers and print queues"; Command = "control printers" },
    @{ Name = "Region"; Desc = "Set regional format, language, and location"; Command = "intl.cpl" },
    @{ Name = "Registry Editor"; Desc = "View and edit Windows registry entries"; Command = "regedit" },
    @{ Name = "Services"; Desc = "Manage Windows services and their startup types"; Command = "services.msc" },
    @{ Name = "Sound Settings"; Desc = "Configure audio devices and sound effects"; Command = "mmsys.cpl" },
    @{ Name = "System Properties"; Desc = "View system info, performance, remote settings"; Command = "sysdm.cpl" },
    @{ Name = "Task Scheduler"; Desc = "Schedule automated tasks and triggers"; Command = "taskschd.msc" },
    @{ Name = "Time and Date"; Desc = "Set date, time, and timezone"; Command = "timedate.cpl" },
    @{ Name = "Windows Restore"; Desc = "System Restore - create or restore restore points"; Command = "rstrui.exe" }
)

if ($controls["LegacyPanel1"] -and $controls["LegacyPanel2"] -and $controls["LegacyPanel3"]) {
    $legacyPanelsArr = @($controls["LegacyPanel1"], $controls["LegacyPanel2"], $controls["LegacyPanel3"])
    $panelIndex = 0
    foreach ($panel in $legacyPanels) {
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "FeatureCard"; $btn.ToolTip = "$($panel.Name)`n$($panel.Desc)`n`nLaunch: $($panel.Command)"; $btn.Tag = $panel.Command; $btn.HorizontalAlignment = "Stretch"
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
        $textSp = New-Object System.Windows.Controls.StackPanel; $textSp.Orientation = "Vertical"; $textSp.VerticalAlignment = "Center"
        $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = $panel.Name; $nameTb.FontSize = 14; $nameTb.FontWeight = "SemiBold"; $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor"); $textSp.Children.Add($nameTb) | Out-Null
        $descTb = New-Object System.Windows.Controls.TextBlock; $descTb.Text = $panel.Desc; $descTb.FontSize = 11; $descTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted"); $descTb.TextWrapping = "Wrap"; $textSp.Children.Add($descTb) | Out-Null
        $sp.Children.Add($textSp) | Out-Null; $btn.Content = $sp
        $btn.Add_Click({
            $cmd = $this.Tag; Write-Log "Launching: $cmd" "Info"
            try {
                $parts = $cmd -split ' ', 2
                $exe = $parts[0]; $args = if ($parts.Count -gt 1) { $parts[1] } else { $null }
                if ($args) { Start-Process $exe -ArgumentList $args -ErrorAction Stop } else { Start-Process $exe -ErrorAction Stop }
                Write-Log "Launched: $cmd" "Success"
            } catch { Write-Log "Failed to launch ${cmd}: $_" "Error"; Show-Info "Error" "Failed to launch $cmd`n`n$_" }
        })
        $legacyPanelsArr[$panelIndex].Children.Add($btn) | Out-Null
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($legacyPanels.Count) legacy panel buttons." "Success"
}
