function Apply-Filters {
    Write-Log "Applying search filters..." "Info"
    $filter = if ($controls["SearchBox"]) { $controls["SearchBox"].Text.ToLower() } else { "" }
    $showInstalled = $controls["ChkShowInstalled"] -and $controls["ChkShowInstalled"].IsChecked
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
        try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { Write-Log "Filter visibility failed: $_" "Warn" }
    }
    foreach ($panelName in @("TweaksPanel1","TweaksPanel2","TweaksPanel3")) {
        if (-not $controls[$panelName]) { continue }
        foreach ($cb in $controls[$panelName].Children) {
            if ($cb -isnot [System.Windows.Controls.CheckBox]) { continue }
            $isVisible = $true
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { Write-Log "Filter visibility failed: $_" "Warn" }
        }
    }
    if ($controls["SearchHint"]) { $controls["SearchHint"].Visibility = if ($filter) { "Collapsed" } else { "Visible" } }
    Write-Log "Filters applied." "Success"
}

if ($controls["SearchBox"]) {
    $controls["SearchBox"].Add_TextChanged({
        Apply-Filters
    })
}
