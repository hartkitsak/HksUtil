# ============ CORE MODULE (BUG-FREE VERSION) ============

# --- GLOBAL STATE INITIALIZATION (SAFETY CHECKS) ---
if (-not $script:installedAppIds) { $script:installedAppIds = @{} }
if (-not $sync.ContainsKey('version')) { $sync.version = "2.0" }
if (-not $sync.ContainsKey('configs')) { $sync.configs = @{} }
if (-not $sync.ContainsKey('ProcessRunning')) { $sync.ProcessRunning = $false }
if (-not $sync.ContainsKey('currentTab')) { $sync.currentTab = "Install" }

# --- REGISTRY HELPER ---
function Set-RegistryValue {
    param($Path, $Name, $Value, $Type)
    if (-not $Type) {
        $Type = if ($Value -is [int] -or $Value -is [long] -or $Value -is [byte]) { "DWord" }
                elseif ($Value -is [string]) { "String" }
                else { "String" }
    }
    $validTypes = @("String","ExpandString","Binary","DWord","MultiString","QWord")
    if ($validTypes -notcontains $Type) { Write-Log "Invalid registry type: $Type" "Error"; return }
    if ($Type -in @("DWord","QWord") -and $null -eq $Value) { Write-Log "Null value not allowed for type $Type" "Error"; return }
    $parts = $Path -split '\\', 2
    if ($parts.Count -lt 2 -or $parts[0] -notmatch '^[A-Za-z]+:$') { Write-Log "Invalid registry path: $Path" "Error"; return }
    if ($parts[0] -eq "HKU:") {
        $sid = ($parts[1] -split '\\')[0]
        $drive = Get-PSDrive -Name HKU -ErrorAction SilentlyContinue
        if (-not $drive) { New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Global | Out-Null }
    }
    if (-not (Test-Path $Path)) { try { New-Item -Path $Path -Force | Out-Null } catch { Write-Log "Failed to create registry path: $_" "Error"; return } }
    if ($Value -eq "<RemoveEntry>") { try { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue } catch {}; return }
    try { Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop } catch { Write-Log "Registry write failed: $Path\$Name = $Value ($Type): $_" "Error" }
}

function Get-WpfResource { 
    param($Key) 
    try { 
        $sync.window.FindResource($Key) 
    } catch { 
        Write-Log "Missing style: $Key" "Warn" 
        $null 
    } 
}

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
    if ($sync.noUI) { 
        Write-Log "[$Text] $SubText" "Info"; 
        return 
    }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread {
            if ($sync.controls["ProgressText"]) { $sync.controls["ProgressText"].Text = $Text }
            if ($sync.controls["ProgressSubText"]) { $sync.controls["ProgressSubText"].Text = $SubText }
            if ($sync.controls["ProgressBar"]) {
                if ($Value -ge 0) { 
                    $sync.controls["ProgressBar"].Value = $Value 
                    $sync.controls["ProgressBar"].IsIndeterminate = $false 
                } else { 
                    $sync.controls["ProgressBar"].IsIndeterminate = $true 
                }
            }
            if ($sync.controls["ProgressOverlay"]) { 
                $sync.controls["ProgressOverlay"].Visibility = "Visible" 
            }
        }
    }
    if (-not $sync.noUI) {
        if ($Value -ge 0) {
            Set-ProgressTaskbar -state "Normal" -value ([math]::Max(0.01, $Value))
        } else {
            Set-ProgressTaskbar -state "Indeterminate"
        }
    }
}

function Hide-Progress {
    if ($sync.noUI) { return }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread { 
            $sync.controls["ProgressOverlay"].Visibility = "Collapsed"
            foreach ($page in @("PageInstall","PageCleaner","PageTools","PagePreferences","PageSettings")) {
                if ($sync.controls[$page]) { $sync.controls[$page].Effect = $null }
            }
        }
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
    } catch { 
        Write-Log "Taskbar progress failed: $_" "Warn" 
    }
}

# --- CORE FUNCTION: Update-InstalledCache (SAFETY FIXED) ---
function Update-InstalledCache {
    Write-Log "Updating installed apps cache..." "Info"
    $script:installedAppIds = @{}
    
    # Check winget availability with proper error handling
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        Write-Log "winget not available. Please install Windows Terminal or PowerShellGet." "Error"; 
        return 
    }
    
    try {
        # Capture output and filter only relevant lines
        $rawLines = winget list --accept-source-agreements 2>&1
        
        # Filter for installed packages (has version/id)
        $lines = @()
        foreach ($line in $rawLines) {
            if ($line -match '^\S+\s+') { 
                $lines += $line 
            }
        }
        
        # If no lines found, exit gracefully
        if (-not $lines) { 
            Write-Log "winget list returned no data. System may be empty or winget failed." "Warn"; 
            return 
        }
        
        $installedIds = @{}
        foreach ($line in $lines) {
            # winget list format: Name<2+spaces>Id<2+spaces>Version
            $parts = $line -split '\s{2,}', 3
            if ($parts.Count -ge 2) {
                $id = $parts[1].Trim()
                if ($id -and $id -ne "Id") { $installedIds[$id.ToLower()] = $true }
            }
        }
        
        foreach ($cat in $sync.configs.apps.PSObject.Properties.Name) {
            foreach ($appKey in $sync.configs.apps.$cat.PSObject.Properties.Name) {
                $id = $sync.configs.apps.$cat.$appKey.winget
                
                # Validate ID is not null/empty before checking containment
                if ($id -and $id.Trim() -ne "" -and $installedIds.ContainsKey($id.ToLower().Trim())) {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch {
        Write-Log "Installed cache update failed: $_" "Error"
    }
    
    if ($script:installedAppIds.Count -gt 0) { Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success" }
}

# --- END OF CORE MODULE ---
