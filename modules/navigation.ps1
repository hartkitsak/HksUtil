$script:pages = @{}
$script:navButtons = @{}
$script:navNames = @("Install", "Tweaks", "Features", "Preferences", "Legacy", "Settings")

function Show-NavPanel {
    param($Name)
    foreach ($other in $navNames) {
        if ($controls["Page$other"]) { $controls["Page$other"].Visibility = "Collapsed" }
    }
    if ($controls["Page$Name"]) { $controls["Page$Name"].Visibility = "Visible"; $sync.currentTab = $Name; Write-Log "Switched to: $Name" "Info" }
}

function Switch-Page { param($Name); Show-NavPanel $Name }

if ($controls.Count) {
    foreach ($n in $navNames) {
        if ($controls["Page$n"]) { $pages[$n] = $controls["Page$n"] }
        if ($controls["Nav$n"]) { $navButtons[$n] = $controls["Nav$n"] }
    }
    foreach ($navName in $navNames) {
        $btnName = "Nav$navName"
        $btn = $controls[$btnName]
        if ($btn) {
            $btn.Tag = $navName
            $btn.Add_Click({ Show-NavPanel $this.Tag })
            if ($btn.PSObject.Properties.Name -contains "IsEnabled") { $btn.IsEnabled = $true }
            Write-Log "Navigation: $btnName wired." "Success"
        }
    }
    if ($window) { $window.Add_KeyDown({
        param($sender, $e)
            if ($e.Key -eq "Escape" -and $controls["SearchBox"]) {
                $controls["SearchBox"].Text = ""
                Show-NavPanel $navNames[0]
                $e.Handled = $true
            }
        })
    }
}
