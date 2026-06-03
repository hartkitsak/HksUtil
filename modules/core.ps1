$script:installedAppIds = @{}
$sync = [Hashtable]::Synchronized(@{})
$sync.version = "2.0"
$sync.configs = @{}
$sync.ProcessRunning = $false
$sync.selectedApps = [System.Collections.Generic.List[string]]::new()
$sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
$sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()
$sync.currentTab = "Install"

$script:logLines = [System.Collections.Generic.List[string]]::new()

function Get-WpfResource { param($Key) try { $window.FindResource($Key) } catch { Write-Log "Missing style: $Key" "Warn"; $null } }

function Invoke-WPFUIThread {
    param([ScriptBlock]$ScriptBlock)
    if ($window -and $window.Dispatcher -and !$window.Dispatcher.CheckAccess()) {
        $window.Dispatcher.Invoke([Action]{ & $ScriptBlock }, "Normal")
    } else {
        & $ScriptBlock
    }
}

function Show-Progress {
    param([string]$Text, [string]$SubText = "", [double]$Value = -1)
    if ($script:NoUI) { Write-Log "[$Text] $SubText" "Info"; return }
    if ($controls["ProgressOverlay"]) {
        Invoke-WPFUIThread {
            if ($controls["ProgressText"]) { $controls["ProgressText"].Text = $Text }
            if ($controls["ProgressSubText"]) { $controls["ProgressSubText"].Text = $SubText }
            if ($controls["ProgressBar"]) {
                if ($Value -ge 0) { $controls["ProgressBar"].Value = $Value; $controls["ProgressBar"].IsIndeterminate = $false }
                else { $controls["ProgressBar"].IsIndeterminate = $true }
            }
            if ($controls["ProgressOverlay"]) { $controls["ProgressOverlay"].Visibility = "Visible" }
        }
    }
    if (-not $script:NoUI) { Set-ProgressTaskbar -state "Normal" -value ([math]::Max(0.01, $Value)) }
}

function Hide-Progress {
    if ($script:NoUI) { return }
    if ($controls["ProgressOverlay"]) {
        Invoke-WPFUIThread { $controls["ProgressOverlay"].Visibility = "Collapsed" }
    }
    Set-ProgressTaskbar -state "None"
}

function Set-ProgressTaskbar {
    param([string]$state = "None", [double]$value = 0)
    if ($script:NoUI) { return }
    try {
        if (-not $window) { return }
        $taskbar = $window.TaskbarItemInfo
        if (-not $taskbar) {
            $taskbar = New-Object System.Windows.Shell.TaskbarItemInfo
            $window.TaskbarItemInfo = $taskbar
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
        foreach ($cat in $appsConfig.PSObject.Properties.Name) {
            foreach ($appKey in $appsConfig.$cat.PSObject.Properties.Name) {
                $id = $appsConfig.$cat.$appKey.winget
                if ($id -and $installedIds.ContainsKey($id.ToLower())) {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch { Write-Log "Installed cache update failed: $_" "Warn" }
    Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success"
}

