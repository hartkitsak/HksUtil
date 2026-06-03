$script:tweakUndoLog = @{}
$script:lastRestorePoint = $null

function Save-OriginalValues {
    param($tweakKey, $tweak)
    if ($script:tweakUndoLog.ContainsKey($tweakKey)) { return }
    $undoEntry = @{ Key = $tweakKey; Registry = @(); Services = @(); Scripts = @() }
    if ($tweak.PSObject.Properties.Name -contains "registry") {
        foreach ($reg in $tweak.registry) {
            $currentValue = $null
            if ($reg.path -and (Test-Path $reg.path)) {
                try { $currentValue = (Get-ItemProperty $reg.path -Name $reg.name -ErrorAction SilentlyContinue).$($reg.name) } catch { Write-Log "Registry read failed for undo: $_" "Warn" }
            }
            $undoEntry.Registry += @{ Path = $reg.path; Name = $reg.name; OriginalValue = $currentValue; Type = $reg.type }
        }
    }
    if ($tweak.PSObject.Properties.Name -contains "services") {
        foreach ($svc in $tweak.services) {
            try {
                $svcObj = Get-Service $svc.name -ErrorAction SilentlyContinue
                if ($svcObj) {
                    $undoEntry.Services += @{ Name = $svc.name; OriginalStatus = $svcObj.Status; OriginalStartup = (Get-CimInstance Win32_Service -Filter "Name='$($svc.name)'" -ErrorAction SilentlyContinue).StartMode }
                }
                } catch { Write-Log "Service capture failed: $_" "Warn" }
        }
    }
    if ($tweak.PSObject.Properties.Name -contains "undoScript") { $undoEntry.Scripts += $tweak.undoScript }
    $script:tweakUndoLog[$tweakKey] = $undoEntry
}

function New-SystemRestorePoint {
    param([string]$Description = "HksUtil Tweaks")
    try {
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        $script:lastRestorePoint = Get-Date
        Write-Log "Restore point created: $Description" "Success"
    } catch { Write-Log "Restore point skipped (service not available): $_" "Warn" }
}

function Invoke-UndoTweaks {
    if ($script:tweakUndoLog.Count -eq 0) { Write-Log "No tweaks to undo." "Warn"; return }

    $sb = New-Object System.Windows.Controls.StackPanel; $sb.Orientation = "Vertical"
    $sb.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text = "Choose undo method:"; Margin = "0,0,0,10"; FontWeight = "Bold" })) | Out-Null
    $rbLog = New-Object System.Windows.Controls.RadioButton -Property @{ Content = "Undo via Log (registry + services)"; IsChecked = $true; Margin = "0,0,0,5" }
    $rbRestore = New-Object System.Windows.Controls.RadioButton -Property @{ Content = "System Restore (roll back to last restore point)"; Margin = "0,0,0,5" }
    if (-not (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) { $rbRestore.IsEnabled = $false; $rbRestore.Content += " (none available)" }
    $sb.Children.Add($rbLog) | Out-Null; $sb.Children.Add($rbRestore) | Out-Null

    $w = New-Object System.Windows.Window -Property @{ Title = "Undo Tweaks"; Content = $sb; Width = 420; Height = 180; WindowStartupLocation = "CenterOwner"; Owner = $window; ShowInTaskbar = $false }
    $btnPanel = New-Object System.Windows.Controls.StackPanel -Property @{ Orientation = "Horizontal"; HorizontalAlignment = "Right"; Margin = "0,15,0,0" }
    $okBtn = New-Object System.Windows.Controls.Button -Property @{ Content = "OK"; Width = 80; Height = 28; Margin = "0,0,10,0"; IsDefault = $true }
    $cancelBtn = New-Object System.Windows.Controls.Button -Property @{ Content = "Cancel"; Width = 80; Height = 28; IsCancel = $true }
    $btnPanel.Children.Add($okBtn) | Out-Null; $btnPanel.Children.Add($cancelBtn) | Out-Null
    $sb.Children.Add($btnPanel) | Out-Null
    $result = $false
    $okBtn.Add_Click({ $result = $true; $w.Close() })
    $cancelBtn.Add_Click({ $w.Close() })
    $w.ShowDialog() | Out-Null
    if (-not $result) { return }

    if ($rbRestore.IsChecked) {
        try {
            $rp = Get-ComputerRestorePoint | Sort-Object CreationTime -Descending | Select-Object -First 1
            if ($rp) { Write-Log "Starting system restore to $($rp.Description)..." "Header"; Show-Info "System Restore" "Your computer will restart to complete the system restore."; Restore-Computer -RestorePoint $rp.SequenceNumber -Confirm:$false }
        } catch { Write-Log "System restore failed: $_" "Error" }
        return
    }

    Write-Log "Undoing last tweaks via log..." "Header"
    $tweakNames = $script:tweakUndoLog.Keys | ForEach-Object { $_.Replace("WPFTweaks", "") -replace "([a-z])([A-Z])", '$1 $2' }
    $msg = "Undo the following tweaks?`n`n" + ($tweakNames -join "`n")
    if (-not (Show-Confirm "Undo via Log" $msg)) { return }
    foreach ($key in $script:tweakUndoLog.Keys) {
        $entry = $script:tweakUndoLog[$key]
        Write-Log "Undoing: $($entry.Key)" "Info"
        foreach ($svc in $entry.Services) {
            try {
                if ($svc.OriginalStartup -and $svc.OriginalStartup -ne "Disabled") { $startType = $svc.OriginalStartup; if ($startType -eq "Auto") { $startType = "Automatic" }; Set-Service $svc.Name -StartupType $startType -ErrorAction SilentlyContinue }
                if ($svc.OriginalStatus -and $svc.OriginalStatus -ne "Stopped") { Start-Service $svc.Name -ErrorAction SilentlyContinue }
                Write-Log "Service $($svc.Name) restored." "Success"
            } catch { Write-Log "Service undo failed: $_" "Error" }
        }
        foreach ($reg in $entry.Registry) {
            try {
                if (!(Test-Path $reg.Path)) { New-Item $reg.Path -Force | Out-Null }
                if ($null -ne $reg.OriginalValue) { Set-ItemProperty $reg.Path -Name $reg.Name -Value $reg.OriginalValue -Type $reg.Type -Force }
                else { Remove-ItemProperty $reg.Path -Name $reg.Name -ErrorAction SilentlyContinue }
                Write-Log "Registry $($reg.Name) restored." "Success"
            } catch { Write-Log "Registry undo failed: $_" "Error" }
        }
        foreach ($scriptBlock in $entry.Scripts) {
            try { & ([scriptblock]::Create($scriptBlock)); Write-Log "Undo script executed." "Success" } catch { Write-Log "Undo script failed: $_" "Error" }
        }
    }
    $script:tweakUndoLog = @{}
    Write-Log "All tweaks undone." "Header"
}

if ($controls["BtnRunTweaks"]) {
    $controls["BtnRunTweaks"].Add_Click({
        $selected = $tweakCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No tweaks selected." "Warn"; return }
        if (-not (Show-Confirm "Run Tweaks" "Apply $($selected.Count) tweak(s)?`n`nA system restore point will be created first.")) { return }
        Write-Log "Creating restore point..." "Info"
        New-SystemRestorePoint
        Write-Log "Running Selected Tweaks..." "Header"
        Set-Status "Applying $($selected.Count) tweak(s)..."
        foreach ($cb in $selected) {
            $tweakKey = $cb.Tag; $tweak = $null
            foreach ($groupKey in $tweaksConfig.PSObject.Properties.Name) {
                $group = $tweaksConfig.$groupKey
                if ($group.PSObject.Properties.Name -contains $tweakKey) { $tweak = $group.$tweakKey; break }
            }
            if (-not $tweak) { continue }
            Write-Log "Applying: $($tweak.content)" "Info"
            Save-OriginalValues -tweakKey $tweakKey -tweak $tweak
            if ($tweak.PSObject.Properties.Name -contains "services") {
                foreach ($svc in $tweak.services) {
                    try {
                        if ($svc.action -eq "stop_disable") { Stop-Service $svc.name -Force -ErrorAction SilentlyContinue; Set-Service $svc.name -StartupType Disabled -ErrorAction SilentlyContinue }
                        if ($svc.action -eq "set_manual") { Set-Service $svc.name -StartupType Manual -ErrorAction SilentlyContinue }
                        Write-Log "Service $($svc.name): $($svc.action)" "Success"
                    } catch { Write-Log "Service $($svc.name) failed: $_" "Error" }
                }
            }
            if ($tweak.PSObject.Properties.Name -contains "registry") {
                foreach ($reg in $tweak.registry) {
                    try { if (!(Test-Path $reg.path)) { New-Item $reg.path -Force | Out-Null }; Set-ItemProperty $reg.path -Name $reg.name -Value $reg.value -Type $reg.type -Force; Write-Log "Registry: $($reg.name) = $($reg.value)" "Success" } catch { Write-Log "Registry failed: $_" "Error" }
                }
            }
            if ($tweak.PSObject.Properties.Name -contains "appx_packages") {
                foreach ($pkg in $tweak.appx_packages) {
                    try {
                        Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
                        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pkg } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                        Write-Log "Removed: $pkg" "Success"
                    } catch { Write-Log "Skip: $pkg`n$_" "Warn" }
                }
            }
            if ($tweak.PSObject.Properties.Name -contains "script") {
                try { & ([scriptblock]::Create($tweak.script)); Write-Log "Script executed." "Success" } catch { Write-Log "Script failed: $_" "Error" }
            }
            if ($tweak.PSObject.Properties.Name -contains "info") { Write-Log $tweak.info "Warn" }
        }
        Set-Status "Ready"
        Show-Info "Tweaks Complete" "$($selected.Count) tweak(s) applied.`n`nUndo from Tweaks tab."
        Write-Log "All selected tweaks completed." "Header"
    })
}

if ($controls["BtnUndoTweaks"]) { $controls["BtnUndoTweaks"].Add_Click({ Invoke-UndoTweaks }) }
