if (-not $script:installedAppIds) { $script:installedAppIds = @{} }
if (-not $sync.ContainsKey('version')) { $sync.version = "2.0" }
if (-not $sync.ContainsKey('configs')) { $sync.configs = @{} }
if (-not $sync.ContainsKey('ProcessRunning')) { $sync.ProcessRunning = $false }
if (-not $sync.ContainsKey('selectedApps')) { $sync.selectedApps = [System.Collections.Generic.List[string]]::new() }
if (-not $sync.ContainsKey('selectedTweaks')) { $sync.selectedTweaks = [System.Collections.Generic.List[string]]::new() }
if (-not $sync.ContainsKey('selectedFeatures')) { $sync.selectedFeatures = [System.Collections.Generic.List[string]]::new() }
if (-not $sync.ContainsKey('currentTab')) { $sync.currentTab = "Install" }
if (-not $script:logLines) { $script:logLines = [System.Collections.Generic.List[string]]::new() }

function Get-WpfResource { param($Key) try { $sync.window.FindResource($Key) } catch { Write-Log "Missing style: $Key" "Warn"; $null } }

function Invoke-WPFUIThread {
    param([ScriptBlock]$ScriptBlock)
    if ($sync.window -and $sync.window.Dispatcher -and !$sync.window.Dispatcher.CheckAccess()) {
        $sync.window.Dispatcher.Invoke([Action]{ & $ScriptBlock }, "Normal")
    } else {
        & $ScriptBlock
    }
}

function Show-Progress {
    param([string]$Text, [string]$SubText = "", [double]$Value = -1)
    if ($sync.noUI) { Write-Log "[$Text] $SubText" "Info"; return }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread {
            if ($sync.controls["ProgressText"]) { $sync.controls["ProgressText"].Text = $Text }
            if ($sync.controls["ProgressSubText"]) { $sync.controls["ProgressSubText"].Text = $SubText }
            if ($sync.controls["ProgressBar"]) {
                if ($Value -ge 0) { $sync.controls["ProgressBar"].Value = $Value; $sync.controls["ProgressBar"].IsIndeterminate = $false }
                else { $sync.controls["ProgressBar"].IsIndeterminate = $true }
            }
            if ($sync.controls["ProgressOverlay"]) { $sync.controls["ProgressOverlay"].Visibility = "Visible" }
        }
    }
    if (-not $sync.noUI) { Set-ProgressTaskbar -state "Normal" -value ([math]::Max(0.01, $Value)) }
}

function Hide-Progress {
    if ($sync.noUI) { return }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread { $sync.controls["ProgressOverlay"].Visibility = "Collapsed" }
    }
    Set-ProgressTaskbar -state "None"
}

function Set-ProgressTaskbar {
    param([string]$state = "None", [double]$value = 0)
    if ($sync.noUI) { return }
    try {
        if (-not $sync.window) { return }
        $taskbar = $sync.window.TaskbarItemInfo
        if (-not $taskbar) {
            $taskbar = New-Object System.Windows.Shell.TaskbarItemInfo
            $sync.window.TaskbarItemInfo = $taskbar
        }
        switch ($state) {
            "None" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::None }
            "Normal" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Normal; $taskbar.ProgressValue = $value }
            "Error" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Error }
            "Indeterminate" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Indeterminate }
        }
    } catch { Write-Log "Taskbar progress failed: $_" "Warn" }
}

function Update-InstalledCache {
    Write-Log "Updating installed apps cache..." "Info"
    $script:installedAppIds = @{}
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "winget not available." "Warn"; return }
    try {
        $lines = winget list --accept-source-agreements 2>&1 | Where-Object { $_ -match '^[\w\-\.]+\s+' }
        $installedIds = @{}
        foreach ($line in $lines) {
            if ($line -match '^([\w\-\.]+)\s+') { $installedIds[$matches[1].ToLower()] = $true }
        }
        foreach ($cat in $sync.configs.apps.PSObject.Properties.Name) {
            foreach ($appKey in $sync.configs.apps.$cat.PSObject.Properties.Name) {
                $id = $sync.configs.apps.$cat.$appKey.winget
                if ($id -and $installedIds.ContainsKey($id.ToLower())) {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch { Write-Log "Installed cache update failed: $_" "Warn" }
    Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success"
}

