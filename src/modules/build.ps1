$appCheckboxes = @()
$cleanerCheckboxes = @()
$prefCheckboxes = @{}
$script:categoryItems = @{}
$script:categoryGrids = @{}
$script:categoryCollapsed = @{}

# --- Build Apps UI ---
if ($sync.controls["AppPanel"] -and $sync.configs.apps) {
    foreach ($category in $sync.configs.apps.PSObject.Properties.Name) {
        $catCount = ($sync.configs.apps.$category.PSObject.Properties.Name).Count
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = "- $($category.ToUpper()) ($catCount)"; $header.Style = Get-WpfResource "CategoryHeader"; $header.Cursor = "Hand"
        $header.Tag = $category
        $sync.controls["AppPanel"].Children.Add($header) | Out-Null
        $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
        $grid.Columns = 4; $grid.HorizontalAlignment = "Stretch"
        $sync.controls["AppPanel"].Children.Add($grid) | Out-Null
        $script:categoryItems[$category] = @()
        $script:categoryGrids[$category] = $grid
        $script:categoryCollapsed[$category] = $false
        $header.Add_MouseLeftButtonDown({
            $cat = $this.Tag
            $script:categoryCollapsed[$cat] = -not $script:categoryCollapsed[$cat]
            $g = $script:categoryGrids[$cat]
            if ($g) { $g.Visibility = if ($script:categoryCollapsed[$cat]) { "Collapsed" } else { "Visible" } }
            $this.Text = if ($script:categoryCollapsed[$cat]) { "+ $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" } else { "- $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" }
        })
        foreach ($appKey in $sync.configs.apps.$category.PSObject.Properties.Name) {
            $app = $sync.configs.apps.$category.$appKey
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $app.winget; $cb.Style = Get-WpfResource "TweakCheckBox"
            $id = $app.winget
            $isInstalled = $id -and $script:installedAppIds.ContainsKey($id)
            $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
            $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = $app.content; $nameTb.VerticalAlignment = "Center"
            $sp.Children.Add($nameTb) | Out-Null
            if ($isInstalled) {
                $badge = New-Object System.Windows.Controls.TextBlock; $badge.Text = " ✓"; $badge.Foreground = [System.Windows.Media.Brushes]::LimeGreen; $badge.FontSize = 12; $badge.FontWeight = "Bold"; $badge.VerticalAlignment = "Center"; $badge.ToolTip = "Installed"
                $sp.Children.Add($badge) | Out-Null
            }
            $cb.Content = $sp
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
            $grid.Children.Add($cb) | Out-Null
            $appCheckboxes += $cb
            $script:categoryItems[$category] += $cb
        }
    }
    foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false }
    Write-Log "Built $($appCheckboxes.Count) app cards." "Success"
}

function Update-AppBadges {
    if (-not $script:installedAppIds -or $appCheckboxes.Count -eq 0) { return }
    foreach ($cb in $appCheckboxes) {
        $id = if ($cb.Tag -ne $null) { $cb.Tag.ToString() } else { "" }
        $sp = $cb.Content
        if ($sp -and $sp -is [System.Windows.Controls.StackPanel]) {
            $existingBadges = @($sp.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] -and $_.Text -eq " ✓" })
            foreach ($b in $existingBadges) { $sp.Children.Remove($b) }
            if ($id -and $script:installedAppIds.ContainsKey($id)) {
                $badge = New-Object System.Windows.Controls.TextBlock; $badge.Text = " ✓"; $badge.Foreground = [System.Windows.Media.Brushes]::LimeGreen; $badge.FontSize = 12; $badge.FontWeight = "Bold"; $badge.VerticalAlignment = "Center"; $badge.ToolTip = "Installed"
                $null = $sp.Children.Add($badge)
            }
        }
    }
}

# --- Build Preferences UI ---
if ($sync.controls["PrefsPanel"] -and $sync.configs.preferences) {
    foreach ($prefKey in $sync.configs.preferences.PSObject.Properties.Name) {
        $pref = $sync.configs.preferences.$prefKey
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $pref.content; $cb.Tag = $prefKey; $cb.Style = Get-WpfResource "ToggleSwitch"
        if ($pref.description) { $cb.ToolTip = $pref.description }
        $hasRegistryOn = $pref.PSObject.Properties.Name -contains "registry_on" -and $pref.registry_on -and $pref.registry_on.Count -gt 0
        if ($hasRegistryOn) {
            $allMatch = $true
            foreach ($r in $pref.registry_on) {
                if (Test-Path $r.path) { try { $val = (Get-ItemProperty $r.path -Name $r.name -ErrorAction SilentlyContinue).$($r.name); if ($val -ne $r.value) { $allMatch = $false; break } } catch { $allMatch = $false; break } }
                else { $allMatch = $false; break }
            }
        }
        $cb.IsChecked = if ($hasRegistryOn) { $allMatch } else { $false }
        $cb.Add_Checked({
            $pk = $this.Tag; $p = $sync.configs.preferences.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_on") { foreach ($r in $p.registry_on) { Set-RegistryValue -Path $r.path -Name $r.name -Value $r.value } }
            Write-Log "Pref ON: $($p.content)" "Success"
        })
        $cb.Add_Unchecked({
            $pk = $this.Tag; $p = $sync.configs.preferences.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_off") { foreach ($r in $p.registry_off) { Set-RegistryValue -Path $r.path -Name $r.name -Value $r.value } }
            Write-Log "Pref OFF: $($p.content)" "Warn"
        })
        $sync.controls["PrefsPanel"].Children.Add($cb) | Out-Null
        $prefCheckboxes[$prefKey] = $cb
    }
    Write-Log "Built $($prefCheckboxes.Count) preference toggles." "Success"
}

# --- Build Cleaner UI ---
if ($sync.controls["CleanerPanel"] -and $sync.configs.cleaner) {
    foreach ($grpKey in $sync.configs.cleaner.PSObject.Properties.Name) {
        $header = New-Object System.Windows.Controls.TextBlock; $header.Text = $grpKey; $header.Style = Get-WpfResource "CategoryHeader"
        $sync.controls["CleanerPanel"].Children.Add($header) | Out-Null
        $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
        $grid.Columns = 4; $grid.HorizontalAlignment = "Stretch"
        $sync.controls["CleanerPanel"].Children.Add($grid) | Out-Null
        foreach ($ck in $sync.configs.cleaner.$grpKey.PSObject.Properties.Name) {
            $c = $sync.configs.cleaner.$grpKey.$ck
            $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $c.content; $cb.Tag = $ck; $cb.Style = Get-WpfResource "TweakCheckBox"
            if ($c.description) { $cb.ToolTip = $c.description }
            $grid.Children.Add($cb) | Out-Null
            $cleanerCheckboxes += $cb
        }
    }
    Write-Log "Built $($cleanerCheckboxes.Count) cleaner checkboxes." "Success"
}

# --- Build System Tools UI ---
if ($sync.controls["ToolsPanel"] -and $sync.configs.legacy) {
    foreach ($panel in $sync.configs.legacy) {
        $desc = if ($panel.PSObject.Properties.Name -contains "description") { $panel.description } else { "" }
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "ToolCard"; $btn.ToolTip = "$($panel.content)`n$desc`n`nLaunch: $($panel.command)"; $btn.Tag = $panel.command; $btn.HorizontalAlignment = "Stretch"
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
        $textSp = New-Object System.Windows.Controls.StackPanel; $textSp.Orientation = "Vertical"; $textSp.VerticalAlignment = "Center"
        $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = $panel.content; $nameTb.FontSize = 14; $nameTb.FontWeight = "SemiBold"; $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor"); $textSp.Children.Add($nameTb) | Out-Null
        $descTb = New-Object System.Windows.Controls.TextBlock; $descTb.Text = $desc; $descTb.FontSize = 11; $descTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted"); $descTb.TextWrapping = "Wrap"; $textSp.Children.Add($descTb) | Out-Null
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
        $sync.controls["ToolsPanel"].Children.Add($btn) | Out-Null
    }
    Write-Log "Built $($sync.configs.legacy.Count) system tool buttons." "Success"
}
