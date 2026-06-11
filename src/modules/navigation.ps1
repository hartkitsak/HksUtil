if (-not $script:pages) { $script:pages = @{} }
if (-not $script:navButtons) { $script:navButtons = @{} }
if (-not $script:navNames) { $script:navNames = @("Install", "Cleaner", "Tools", "Preferences", "Settings") }

function Show-NavPanel {
    param($Name)
    $previousPage = $sync.currentTab
    foreach ($other in $script:navNames) {
        if ($sync.controls["Page$other"] -and $other -ne $Name) { 
            $sync.controls["Page$other"].Visibility = "Collapsed"
            $sync.controls["Page$other"].Opacity = 1
        }
    }
    if ($sync.controls["Page$Name"]) { 
        $sync.controls["Page$Name"].Visibility = "Visible"
        $sync.controls["Page$Name"].Opacity = 0
        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.From = 0; $anim.To = 1; $anim.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
        $sync.controls["Page$Name"].BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
        $sync.currentTab = $Name; Write-Log "Switched to: $Name" "Info"
        if ($sync.controls["SearchBox"] -and $sync.controls["SearchBox"].Text) {
            $sync.controls["SearchBox"].Text = ""
        }
        Update-SelectedCount
    }
    if ($sync.configs.themes -and $script:currentTheme) {
        $colors = $sync.configs.themes.$script:currentTheme
        $converter = [System.Windows.Media.BrushConverter]::new()
        try {
            $activeBrush = $converter.ConvertFrom($colors.accentColor)
            $mutedBrush = $converter.ConvertFrom($colors.textMuted)
            foreach ($n in $script:navNames) {
                $btn = $sync.controls["Nav$n"]
                if ($btn) {
                    if ($n -eq $Name) {
                        $btn.Foreground = $activeBrush
                        $btn.FontWeight = "Bold"
                    } else {
                        $btn.Foreground = $mutedBrush
                        $btn.FontWeight = "Normal"
                    }
                }
            }
        } catch { Write-Log "Nav highlight failed: $_" "Warn" }
    }
}

function Switch-Page { param($Name); Show-NavPanel $Name }

if ($sync.controls.Count) {
    foreach ($n in $script:navNames) {
        if ($sync.controls["Page$n"]) { $script:pages[$n] = $sync.controls["Page$n"] }
        if ($sync.controls["Nav$n"]) { $script:navButtons[$n] = $sync.controls["Nav$n"] }
    }
    foreach ($navName in $script:navNames) {
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
            $navMap = @{ I = "Install"; C = "Cleaner"; T = "Tools"; P = "Preferences"; S = "Settings"; Q = "Install" }
            if ($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Alt -and $navMap.ContainsKey([string]$e.Key)) {
                Show-NavPanel $navMap[[string]$e.Key]
                $e.Handled = $true; return
            }
            if ($e.Key -eq "Escape" -and $sync.controls["SearchBox"]) {
                $sync.controls["SearchBox"].Text = ""
                Show-NavPanel $script:navNames[0]
                $e.Handled = $true
            }
        })
    }
}
