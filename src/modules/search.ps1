function Apply-Filters {
    Write-Log "Applying search filters..." "Info"
    $filter = if ($sync.controls["SearchBox"]) { $sync.controls["SearchBox"].Text.ToLower() } else { "" }
    $showInstalled = $sync.controls["ChkShowInstalled"] -and $sync.controls["ChkShowInstalled"].IsChecked
    $currentTab = $sync.currentTab
    
    # Filter app checkboxes on Install page
    if ($currentTab -eq "Install") {
        foreach ($cb in $appCheckboxes) {
            $isVisible = $true
            if ($showInstalled) {
                $id = if ($cb.Tag -ne $null) { $cb.Tag.ToString() } else { "" }
                $isVisible = $isVisible -and $script:installedAppIds.ContainsKey($id)
            }
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
        }
    }
    
    # Filter checkboxes on Cleaner page (nested in per-category UniformGrids)
    if ($currentTab -eq "Cleaner") {
        foreach ($cb in $cleanerCheckboxes) {
            $isVisible = $true
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $tooltip = if ($cb.ToolTip -ne $null) { $cb.ToolTip.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter) -or $tooltip.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
        }
    }
    
    # Filter checkboxes on Preferences page
    if ($currentTab -eq "Preferences" -and $sync.controls["PrefsPanel"]) {
        foreach ($cb in $sync.controls["PrefsPanel"].Children) {
            if ($cb -isnot [System.Windows.Controls.CheckBox]) { continue }
            $isVisible = $true
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $tooltip = if ($cb.ToolTip -ne $null) { $cb.ToolTip.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter) -or $tooltip.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
        }
    }
    
    # Filter tool buttons
    if ($currentTab -eq "Tools") {
        foreach ($panelName in @("ToolsPanel")) {
            if (-not $sync.controls[$panelName]) { continue }
            foreach ($btn in $sync.controls[$panelName].Children) {
                if ($btn -isnot [System.Windows.Controls.Button]) { continue }
                $isVisible = $true
                if ($filter) {
                    $content = if ($btn.Content -ne $null) { 
                        $tb = $btn.Content
                        if ($tb -is [System.Windows.Controls.StackPanel]) {
                            $innerSp = $tb.Children | Where-Object { $_ -is [System.Windows.Controls.StackPanel] } | Select-Object -First 1
                            if ($innerSp) { ($innerSp.Children | Select-Object -First 1).Text.ToString().ToLower() } else { "" }
                        } else { "" }
                    } else { "" }
                    $tooltip = if ($btn.ToolTip -ne $null) { $btn.ToolTip.ToString().ToLower() } else { "" }
                    $isVisible = $isVisible -and ($content.Contains($filter) -or $tooltip.Contains($filter))
                }
                try { $btn.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
            }
        }
    }
    
    # Empty state
    $anyVisible = $false
    if ($currentTab -eq "Install") { $anyVisible = ($appCheckboxes | Where-Object { $_.Visibility -eq "Visible" }).Count -gt 0 }
    elseif ($currentTab -eq "Cleaner") { $anyVisible = ($cleanerCheckboxes | Where-Object { $_.Visibility -eq "Visible" }).Count -gt 0 }
    elseif ($currentTab -eq "Preferences") {
        $anyVisible = @($prefCheckboxes.Values | Where-Object { $_.Visibility -eq "Visible" }).Count -gt 0
    }
    if ($sync.controls["EmptyState$currentTab"]) { $sync.controls["EmptyState$currentTab"].Visibility = if ($filter -and -not $anyVisible) { "Visible" } else { "Collapsed" } }
    
    if ($sync.controls["SearchHint"]) { $sync.controls["SearchHint"].Visibility = if ($filter) { "Collapsed" } else { "Visible" } }
    Write-Log "Filters applied." "Success"
}

if ($sync.controls["SearchBox"]) {
    $sync.controls["SearchBox"].Add_TextChanged({ Apply-Filters })
}
if ($sync.controls["BtnClearSearch"]) {
    $sync.controls["BtnClearSearch"].Add_Click({
        $sync.controls["SearchBox"].Text = ""
        Apply-Filters
    })
}
