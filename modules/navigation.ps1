if (-not $script:pages) { $script:pages = @{} }
if (-not $script:navButtons) { $script:navButtons = @{} }
if (-not $script:navNames) { $script:navNames = @("Install", "Tweaks", "Features", "Preferences", "Legacy", "Settings") }

function Show-NavPanel {
    param($Name)
    foreach ($other in $navNames) {
        if ($sync.controls["Page$other"]) { $sync.controls["Page$other"].Visibility = "Collapsed" }
    }
    if ($sync.controls["Page$Name"]) { $sync.controls["Page$Name"].Visibility = "Visible"; $sync.currentTab = $Name; Write-Log "Switched to: $Name" "Info" }
}

function Switch-Page { param($Name); Show-NavPanel $Name }

if ($sync.controls.Count) {
    foreach ($n in $navNames) {
        if ($sync.controls["Page$n"]) { $pages[$n] = $sync.controls["Page$n"] }
        if ($sync.controls["Nav$n"]) { $navButtons[$n] = $sync.controls["Nav$n"] }
    }
    foreach ($navName in $navNames) {
        $btnName = "Nav$navName"
        $btn = $sync.controls[$btnName]
        if ($btn) {
            $btn.Tag = $navName
            $btn.Add_Click({ Show-NavPanel $this.Tag })
            if ($btn.PSObject.Properties.Name -contains "IsEnabled") { $btn.IsEnabled = $true }
            Write-Log "Navigation: $btnName wired." "Success"
        }
    }
    if ($sync.window) { $sync.window.Add_KeyDown({
        param($sender, $e)
            if ($e.Key -eq "Escape" -and $sync.controls["SearchBox"]) {
                $sync.controls["SearchBox"].Text = ""
                Show-NavPanel $navNames[0]
                $e.Handled = $true
            }
        })
    }
}
