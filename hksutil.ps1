<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : 69.06.03
#>

param(
    [string]$Config,
    [switch]$Noui,
    [switch]$Offline,
    [switch]$Apply,
    [string]$Export,
    [switch]$Verbose
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "HksUtil needs to be run as Administrator. Attempting to relaunch."
    $argList = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $argList += if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
        elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
        elseif ($_.Value) { "-$($_.Key) '$($_.Value)'" }
    }
    $scriptCmd = if ($PSCommandPath) {
        "& { & '$PSCommandPath' $($argList -join ' ') }"
    } else {
        "& { & '$(Split-Path $MyInvocation.MyCommand.Path -Parent)\hksutil.ps1' $($argList -join ' ') }"
    }
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    Start-Process $powershellCmd -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$scriptCmd`"" -Verb RunAs
    exit
}

$script:hksVersion = "69.06.03"
$script:NoUI = $Noui

$controls = @{}
$script:logLevel = "Success"

function Show-HksUtilLogo {
    Write-Host @"
HH   HH KK   KK  SSSSSS  UU   UU TTTTTT IIIIII LL
HH   HH KK  KK  SS       UU   UU   TT     II   LL
HHHHHHH KKKKK    SSSSSS  UU   UU   TT     II   LL
HH   HH KK  KK       SS  UU   UU   TT     II   LL
HH   HH KK   KK  SSSSSS   UUUUU    TT   IIIIII LLLL
"@ -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
    Write-Host "    HksUtil v2.0" -ForegroundColor Cyan
    Write-Host "    Windows Optimizer" -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
}

function Write-Log {
    param([string]$Message, [string]$Type = "Info")
    if ($Type -eq "Header") {
        Write-Host "`n  $Message" -ForegroundColor Cyan
        if ($script:logLines) { $script:logLines.Add("  $Message") }
        return
    }
    $level = switch ($Type) {
        "Info"    { "INFO" }
        "Success" { "OK" }
        "Error"   { "FAIL" }
        "Warn"    { "WARN" }
        "Cmd"     { ">" }
    }
    $color = switch ($Type) {
        "Info"    { "DarkGray" }
        "Success" { "Green" }
        "Error"   { "Red" }
        "Warn"    { "Yellow" }
        "Cmd"     { "Cyan" }
    }
    if ($script:logLines) { $script:logLines.Add("$level $Message") }
    if ($Type -eq "Info" -and $script:logLevel -ne "Info") { return }
    Write-Host ("  {0,-5} {1}" -f $level, $Message) -ForegroundColor $color
}

function Show-Confirm {
    param([string]$Title, [string]$Message)
    $result = [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Show-Info {
    param([string]$Title, [string]$Message)
    [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Set-Status {
    param([string]$Text)
    if ($controls["StatusText"]) { $controls["StatusText"].Text = $Text }
}

function Update-SelectedCount {
    $count = ($appCheckboxes | Where-Object { $_.IsChecked -eq $true }).Count
    if ($controls["LblSelectedCount"]) { $controls["LblSelectedCount"].Text = "Selected Apps: $count" }
}

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
        $output = winget list --accept-source-agreements 2>&1 | Out-String
        foreach ($cat in $appsConfig.PSObject.Properties.Name) {
            foreach ($appKey in $appsConfig.$cat.PSObject.Properties.Name) {
                $id = $appsConfig.$cat.$appKey.winget
                if ($id -and $output -match "\b$([regex]::Escape($id))\b") {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch { Write-Log "Installed cache update failed: $_" "Warn" }
    Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success"
}


$script:currentTheme = "dark"

function Apply-Theme {
    param($ThemeName)
    $key = $ThemeName.ToLower()
    if (-not $script:themesConfig -or -not $script:themesConfig.$key) {
        Write-Log "Theme '$ThemeName' not found in themes config." "Warn"
        return
    }
    try {
        $colors = $script:themesConfig.$key
        $converter = [System.Windows.Media.BrushConverter]::new()
        $newDict = New-Object System.Windows.ResourceDictionary

        foreach ($prop in $colors.PSObject.Properties.Name) {
            $brush = $converter.ConvertFrom($colors.$prop)
            $newDict.Add($prop, $brush)
        }

        $script:currentTheme = $ThemeName
        Write-Log "Theme: $ThemeName" "Success"

        if ([System.Windows.Application]::Current) {
            $appResources = [System.Windows.Application]::Current.Resources
            $existingTheme = @($appResources.MergedDictionaries | Where-Object { $_.Source -eq $null -and $_.Count -gt 0 -and -not $_.Contains("ToolBarButtonBaseStyle") })
            foreach ($dict in $existingTheme) { $appResources.MergedDictionaries.Remove($dict) }
            $appResources.MergedDictionaries.Add($newDict)
        } elseif ($window) {
            $existingTheme = @($window.Resources.MergedDictionaries | Where-Object { $_.Source -eq $null })
            foreach ($dict in $existingTheme) { $window.Resources.MergedDictionaries.Remove($dict) }
            $window.Resources.MergedDictionaries.Add($newDict)
        }

        if ($window -and $colors.windowBackground) {
            $window.Background = $converter.ConvertFrom($colors.windowBackground)
        }
    } catch { Write-Log "Theme apply failed: $_" "Error" }
}

$script:pages = @{}
$script:navButtons = @{}
$script:navNames = @("Install", "Tweaks", "Features", "Preferences", "Legacy", "Settings")

foreach ($n in $navNames) {
    if ($controls["Page$n"]) { $pages[$n] = $controls["Page$n"] }
    if ($controls["Nav$n"]) { $navButtons[$n] = $controls["Nav$n"] }
}

function Show-NavPanel {
    param($Name)
    foreach ($other in $navNames) {
        if ($controls["Page$other"]) { $controls["Page$other"].Visibility = "Collapsed" }
    }
    if ($controls["Page$Name"]) { $controls["Page$Name"].Visibility = "Visible"; $sync.currentTab = $Name; Write-Log "Switched to: $Name" "Info" }
}

function Switch-Page { param($Name); Show-NavPanel $Name }

foreach ($navName in $navNames) {
    $btnName = "Nav$navName"
    $btn = $controls[$btnName]
    if ($btn) {
        $btn.Tag = $navName
        $btn.Add_Click({ Show-NavPanel $this.Tag })
        if ($btn.PSObject.Properties.Name -contains "IsEnabled") { $btn.IsEnabled = $true }
        Write-Log "Navigation: $btnName wired." "Success"
    } else { Write-Log "Navigation button $btnName not found." "Warn" }
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

$script:tweakUndoLog = @{}
$script:lastRestorePoint = $null

function Save-OriginalValues {
    param($tweakKey, $tweak)
    if ($script:tweakUndoLog.ContainsKey($tweakKey)) { return }
    $undoEntry = @{ Key = $tweakKey; Registry = @(); Services = @(); Scripts = @() }
    if ($tweak.PSObject.Properties.Name -contains "registry") {
        foreach ($reg in $tweak.registry) {
            $currentValue = $null
            if (Test-Path $reg.path) {
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
            if ($rp) { Write-Log "Starting system restore to $($rp.Description)..." "Header"; Restore-Computer -RestorePoint $rp.SequenceNumber -Confirm:$false }
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
            try { Invoke-Expression $scriptBlock; Write-Log "Undo script executed." "Success" } catch { Write-Log "Undo script failed: $_" "Error" }
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
                try { Invoke-Expression $tweak.script; Write-Log "Script executed." "Success" } catch { Write-Log "Script failed: $_" "Error" }
            }
            if ($tweak.PSObject.Properties.Name -contains "info") { Write-Log $tweak.info "Warn" }
        }
        Set-Status "Ready"
        Show-Info "Tweaks Complete" "$($selected.Count) tweak(s) applied.`n`nUndo from Tweaks tab."
        Write-Log "All selected tweaks completed." "Header"
    })
}

if ($controls["BtnUndoTweaks"]) { $controls["BtnUndoTweaks"].Add_Click({ Invoke-UndoTweaks }) }

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

if ($controls["BtnToolbarClose"]) {
    $controls["BtnToolbarClose"].Add_Click({ $window.Close() })
}

if ($controls["BtnToolbarMinimize"]) {
    $controls["BtnToolbarMinimize"].Add_Click({ $window.WindowState = "Minimized" })
}

if ($controls["BtnToolbarMaximize"]) {
    $controls["BtnToolbarMaximize"].Add_Click({
        $window.WindowState = if ($window.WindowState -eq "Maximized") { "Normal" } else { "Maximized" }
    })
}

if ($controls["BtnToolbarTheme"]) {
    $controls["BtnToolbarTheme"].Add_Click({
        if ($script:currentTheme -eq "dark") { Apply-Theme "light" } else { Apply-Theme "dark" }
    })
}

if ($controls["BtnGearExport"]) {
    $controls["BtnGearExport"].Add_Click({
        try {
            $sfd = New-Object Microsoft.Win32.SaveFileDialog
            $sfd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $sfd.Title = "Export Config"
            $sfd.FileName = "HksUtil-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).json"
            $sfd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $sfd.ShowDialog($window)
            if ($result -ne $true) { return }
            $data = @{
                AppSelections = @($appCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
                TweakSelections = @($tweakCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
                FeatureSelections = @($featuresCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
            }
            $prefState = @{}
            foreach ($pk in $prefCheckboxes.Keys) {
                if ($prefCheckboxes[$pk]) { $prefState[$pk] = ($prefCheckboxes[$pk].IsChecked -eq $true) }
            }
            $data.PreferenceStates = $prefState
            $json = $data | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($sfd.FileName, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Log "Exported to $($sfd.FileName)" "Success"
            Show-Info "Export Complete" "Config exported to:`n$($sfd.FileName)"
        } catch { Write-Log "Export failed: $_" "Error" }
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearImport"]) {
    $controls["BtnGearImport"].Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        try {
            $ofd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $ofd.Title = "Import Config"
            $ofd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $ofd.ShowDialog($window)
            if ($result -ne $true) { return }
            $json = [System.IO.File]::ReadAllText($ofd.FileName, [System.Text.UTF8Encoding]::new($false))
            $data = $json | ConvertFrom-Json

            # NEW format: AppSelections (array of winget IDs)
            if ($data.AppSelections) {
                foreach ($aid in $data.AppSelections) {
                    $cb = $appCheckboxes | Where-Object { $_.Tag -eq $aid }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            # OLD format: CheckedApps (array of {Name, Content})
            if ($data.CheckedApps) {
                foreach ($appEntry in $data.CheckedApps) {
                    $cb = $appCheckboxes | Where-Object { $_.Tag -eq $appEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            # NEW format: TweakSelections (array of keys)
            if ($data.TweakSelections) {
                foreach ($tk in $data.TweakSelections) {
                    $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tk }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            # OLD format: CheckedTweaks (array of {Name, Content})
            if ($data.CheckedTweaks) {
                foreach ($tweakEntry in $data.CheckedTweaks) {
                    $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tweakEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            if ($data.FeatureSelections) {
                foreach ($fk in $data.FeatureSelections) {
                    $cb = $featuresCheckboxes | Where-Object { $_.Tag -eq $fk }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            if ($data.PreferenceStates) {
                foreach ($pk in $data.PreferenceStates.PSObject.Properties.Name) {
                    if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $data.PreferenceStates.$pk -eq $true }
                }
            }

            Write-Log "Imported from $($ofd.FileName)" "Success"
            Show-Info "Import Complete" "Configuration imported."
        } catch { Write-Log "Import failed: $_" "Error" }
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearAbout"]) {
    $controls["BtnGearAbout"].Add_Click({
        Show-Info "About HksUtil v2.0" "HksUtil v2.0 - Windows Optimizer`n`nA Windows utility for application management, system tweaks, DNS configuration, and more.`n`nBuilt with PowerShell and WPF."
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearDocs"]) {
    $controls["BtnGearDocs"].Add_Click({
        Start-Process "https://github.com/hartkitsak/HksUtil"
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearSponsors"]) {
    $controls["BtnGearSponsors"].Add_Click({
        Show-Info "Sponsors" "HksUtil is an open-source project.`n`nIf you find this tool useful, consider supporting the project."
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

$script:dnsNames = @()
$script:dnsRadioButtons = @{}

if ($controls["DnsRadioPanel"] -and $dnsConfig) {
    $script:dnsNames = @($dnsConfig.PSObject.Properties.Name)
    $script:dnsRadioButtons = @{}
    $isFirst = $true
    foreach ($dnsName in $script:dnsNames) {
        $dns = $dnsConfig.$dnsName
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Tag = $dnsName; $rb.Style = Get-WpfResource "DnsCardStyle"; $rb.GroupName = "DnsProvider"
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"; $sp.VerticalAlignment = "Center"
        $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = "$dnsName - $($dns.description)"; $nameTb.FontSize = 12; $nameTb.FontWeight = "SemiBold"; $nameTb.VerticalAlignment = "Center"; $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor")
        $sp.Children.Add($nameTb) | Out-Null
        $ipTb = New-Object System.Windows.Controls.TextBlock; $ipDisplay = if ($dns.PSObject.Properties.Name -contains "ipv4" -and $dns.ipv4.Count -gt 0) { $dns.ipv4 -join ", " } else { "Auto (DHCP)" }; $ipTb.Text = "  $ipDisplay"; $ipTb.FontSize = 10; $ipTb.FontFamily = "Consolas"; $ipTb.VerticalAlignment = "Center"; $ipTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted")
        $sp.Children.Add($ipTb) | Out-Null
        $rb.Content = $sp
        $rb.Add_Checked({ Write-Log "DNS selected: $($this.Tag)" "Info" })
        $null = $controls["DnsRadioPanel"].Children.Add($rb)
        $script:dnsRadioButtons[$dnsName] = $rb
        if ($isFirst) { $rb.IsChecked = $true; $isFirst = $false }
    }
    Write-Log "Built $($script:dnsNames.Count) DNS radio buttons." "Success"
}

if ($controls["BtnApplyDns"]) {
    $controls["BtnApplyDns"].Add_Click({
        $selectedRb = $script:dnsRadioButtons.Values | Where-Object { $_.IsChecked -eq $true } | Select-Object -First 1
        if (-not $selectedRb) { Write-Log "No DNS provider selected." "Warn"; return }
        $dnsName = $selectedRb.Tag
        $dns = $dnsConfig.$dnsName
        $ipv4 = if ($dns.PSObject.Properties.Name -contains "ipv4") { $dns.ipv4 } else { @() }
        if ($dnsName -eq "Default_DHCP") {
            if (-not (Show-Confirm "Reset DNS" "Reset DNS to default DHCP on all adapters?")) { return }
            Write-Log "Resetting DNS to DHCP..." "Info"
            try {
                $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
                if (-not $adapters) { Write-Log "No active network adapter found." "Error"; return }
                foreach ($adapter in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses }
                Write-Log "DNS reset to DHCP on $($adapters.Count) adapter(s)." "Success"
                Show-Info "DNS Reset" "DNS has been reset to DHCP."
            } catch { Write-Log "Failed to reset DNS: $_" "Error" }
            return
        }
        if (-not (Show-Confirm "Apply DNS" "Set DNS to $dnsName?`n`nIPv4: $($ipv4 -join ', ')") ) { return }
        Write-Log "Setting DNS to $dnsName..." "Info"
        try {
            $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
            if (-not $adapters) { Write-Log "No active network adapter found." "Error"; return }
            $ipv6 = if ($dns.PSObject.Properties.Name -contains "ipv6") { $dns.ipv6 } else { @() }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ($ipv4 + $ipv6)
            }
            Write-Log "DNS set to $dnsName on $($adapters.Count) adapter(s)." "Success"
            Show-Info "DNS Applied" "DNS has been set to $dnsName.`n`nIPv4: $($ipv4 -join ', ')"
        } catch {
            Write-Log "Failed to set DNS: $_" "Error"
            try {
                $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
                if (-not $adapters) { Write-Log "No active adapter for netsh." "Error"; return }
                foreach ($adapter in $adapters) {
                    $ifName = $adapter.Name
                    if ($ipv4.Count -gt 0) {
                        netsh interface ip set dns "$ifName" static $($ipv4[0])
                        for ($i = 1; $i -lt $ipv4.Count; $i++) { netsh interface ip add dns "$ifName" $($ipv4[$i]) index=$($i+1) }
                    }
                }
                Write-Log "DNS set via netsh fallback." "Success"
                Show-Info "DNS Applied" "DNS set via netsh.`n$dnsName ($($ipv4 -join ', '))"
            } catch { Write-Log "netsh fallback also failed: $_" "Error" }
        }
    })
}

if ($controls["BtnTerminalDotfiles"]) {
    $controls["BtnTerminalDotfiles"].Add_Click({
        Write-Log "Installing Nova profile..." "Info"
        try {
            iex (irm "https://raw.githubusercontent.com/hartkitsak/nova/master/install.ps1")
            Write-Log "Nova install complete." "Success"
        } catch { Write-Log "Nova install failed: $_" "Error" }
    })
}

if ($controls["BtnUninstallTerminal"]) {
    $controls["BtnUninstallTerminal"].Add_Click({
        Write-Log "Uninstalling Nova profile..." "Info"
        try {
            iex (irm "https://raw.githubusercontent.com/hartkitsak/nova/master/uninstall.ps1")
            Write-Log "Nova uninstall complete." "Success"
        } catch { Write-Log "Nova uninstall failed: $_" "Error" }
    })
}

$script:desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"

if ($controls["BtnCreateShortcut"]) {
    $controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = $script:desktopShortcutPath
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $shortcut.TargetPath = "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe"
            $shortcut.Arguments = '-ExecutionPolicy Bypass -Command "Start-Process powershell.exe -verb runas -ArgumentList ''-Command \"irm https://raw.githubusercontent.com/hartkitsak/HksUtil/main/.ps1 | iex\"''"'
            $shortcut.Description = "HksUtil v2.0 - Windows Optimizer"
            $shortcut.IconLocation = "C:\WINDOWS\system32\pifmgr.dll, 4"
            $shortcut.Save()
            Write-Log "Desktop shortcut created." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}

$appCheckboxes = @()
$tweakCheckboxes = @()
$featuresCheckboxes = @()
$prefCheckboxes = @{}
$appPanels = @()
$script:categoryItems = @{}
$script:categoryCollapsed = @{}

# --- Build Apps UI ---
$appPanelIndex = 0
if (($controls["AppPanel1"] -and $controls["AppPanel2"] -and $controls["AppPanel3"]) -and $appsConfig) {
    $appPanels = @($controls["AppPanel1"], $controls["AppPanel2"], $controls["AppPanel3"])
    foreach ($category in $appsConfig.PSObject.Properties.Name) {
        $catCount = ($appsConfig.$category.PSObject.Properties.Name).Count
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = "- $($category.ToUpper()) ($catCount)"; $header.Style = Get-WpfResource "CategoryHeader"; $header.Cursor = "Hand"
        $header.Tag = $category
        $appPanels[$appPanelIndex].Children.Add($header) | Out-Null
        $script:categoryItems[$category] = @()
        $header.Add_MouseLeftButtonDown({
            $cat = $this.Tag
            $collapsed = $script:categoryCollapsed[$cat]
            $script:categoryCollapsed[$cat] = -not $collapsed
            foreach ($item in $script:categoryItems[$cat]) {
                $item.Visibility = if ($script:categoryCollapsed[$cat]) { "Collapsed" } else { "Visible" }
            }
            $this.Text = if ($script:categoryCollapsed[$cat]) { "+ $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" } else { "- $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" }
        })
        foreach ($appKey in $appsConfig.$category.PSObject.Properties.Name) {
            $app = $appsConfig.$category.$appKey
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $app.content; $cb.Tag = $app.winget; $cb.Style = Get-WpfResource "TweakCheckBox"
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
                try { if ($pkg -eq "winget") { winget install --id=$id --silent --accept-package-agreements 2>&1 | Out-Null } else { choco install $id -y 2>&1 | Out-Null }; Write-Log "Installed: $id" "Success" } catch { Write-Log "Failed: $id" "Error" }
                Hide-Progress; Update-InstalledCache; Show-Info "Done" "Install of $id completed."
            })
            $miUninstall = New-Object System.Windows.Controls.MenuItem; $miUninstall.Header = "Uninstall"; $miUninstall.Tag = $app.winget
            $miUninstall.Add_Click({
                $id = $this.Tag; $pkg = $script:pkgManager; Write-Log "Context: Uninstall $id via $pkg" "Info"
                if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
                if (-not (Show-Confirm "Uninstall" "Uninstall $id via $pkg?")) { return }
                Show-Progress -Text "Uninstalling: $id" -Value 0.5
                try { if ($pkg -eq "winget") { winget uninstall --id=$id --silent --purge 2>&1 | Out-Null } else { choco uninstall $id -y 2>&1 | Out-Null }; Write-Log "Uninstalled: $id" "Success" } catch { Write-Log "Failed: $id" "Error" }
                Hide-Progress; Update-InstalledCache; Show-Info "Done" "Uninstall of $id completed."
            })
            $miInfo = New-Object System.Windows.Controls.MenuItem; $miInfo.Header = "Info"; $miInfo.Tag = $app
            $miInfo.Add_Click({ $a = $this.Tag; Show-Info "App Info" "$($a.content)`n`nID: $($a.winget)`n$($a.description)" })
            $null = $cm.Items.Add($miInstall); $null = $cm.Items.Add($miUninstall); $null = $cm.Items.Add((New-Object System.Windows.Controls.Separator)); $null = $cm.Items.Add($miInfo)
            $cb.ContextMenu = $cm
            $appPanels[$appPanelIndex].Children.Add($cb) | Out-Null
            $appCheckboxes += $cb
            $script:categoryItems[$category] += $cb
        }
        $appPanelIndex = ($appPanelIndex + 1) % 3
    }
    foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false }
    Write-Log "Built $($appCheckboxes.Count) app cards." "Success"
}

# --- Build Preferences UI ---
$panelIndex = 0
if ($controls["PrefsPanel1"] -and $controls["PrefsPanel2"] -and $controls["PrefsPanel3"] -and $prefsConfig) {
    $prefPanels = @($controls["PrefsPanel1"], $controls["PrefsPanel2"], $controls["PrefsPanel3"])
    foreach ($prefKey in $prefsConfig.PSObject.Properties.Name) {
        $pref = $prefsConfig.$prefKey
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $pref.content; $cb.Tag = $prefKey; $cb.Style = Get-WpfResource "ToggleSwitch"
        if ($pref.description) { $cb.ToolTip = $pref.description }
        $currentState = $null
        $hasRegistryOn = $pref.PSObject.Properties.Name -contains "registry_on" -and $pref.registry_on -and $pref.registry_on.Count -gt 0
        if ($hasRegistryOn) {
            $firstReg = $pref.registry_on[0]
            if (Test-Path $firstReg.path) { try { $currentState = (Get-ItemProperty $firstReg.path -Name $firstReg.name -ErrorAction SilentlyContinue).$($firstReg.name) } catch { Write-Log "Registry read failed: $_" "Warn" } }
        }
        $cb.IsChecked = if ($hasRegistryOn) { $currentState -eq $pref.registry_on[0].value } else { $false }
        $cb.Add_Checked({
            $pk = $this.Tag; $p = $prefsConfig.$pk
            if ($p.PSObject.Properties.Name -contains "registry_on") { foreach ($r in $p.registry_on) { try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; $t = if ($r.type) { $r.type } else { "String" }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Type $t -Force } catch { Write-Log "Registry write failed: $($r.path) $($r.name)" "Warn" } } }
            Write-Log "Pref ON: $($p.content)" "Success"
        })
        $cb.Add_Unchecked({
            $pk = $this.Tag; $p = $prefsConfig.$pk
            if ($p.PSObject.Properties.Name -contains "registry_off") { foreach ($r in $p.registry_off) { try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; $t = if ($r.type) { $r.type } else { "String" }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Type $t -Force } catch { Write-Log "Registry write failed: $($r.path) $($r.name)" "Warn" } } }
            Write-Log "Pref OFF: $($p.content)" "Warn"
        })
        $prefPanels[$panelIndex].Children.Add($cb) | Out-Null
        $prefCheckboxes[$prefKey] = $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($prefCheckboxes.Count) preference toggles." "Success"
}

# --- Build Tweaks UI ---
$panelIndex = 0
if ($controls["TweaksPanel1"] -and $controls["TweaksPanel2"] -and $controls["TweaksPanel3"] -and $tweaksConfig) {
    $panels = @($controls["TweaksPanel1"], $controls["TweaksPanel2"], $controls["TweaksPanel3"])
    foreach ($groupKey in $tweaksConfig.PSObject.Properties.Name) {
        $group = $tweaksConfig.$groupKey
        $header = New-Object System.Windows.Controls.TextBlock; $header.Text = $groupKey; $header.FontSize = 16; $header.FontWeight = "Bold"
        $header.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "categoryHeaderColor"); $header.Margin = "0,0,0,10"
        $panels[$panelIndex].Children.Add($header) | Out-Null
        foreach ($tweakKey in $group.PSObject.Properties.Name) {
            $tweak = $group.$tweakKey
            $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $tweak.content; $cb.Tag = $tweakKey; $cb.Style = Get-WpfResource "TweakCheckBox"
            if ($tweak.description) { $cb.ToolTip = $tweak.description }
            $panels[$panelIndex].Children.Add($cb) | Out-Null
            $tweakCheckboxes += $cb
        }
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($tweakCheckboxes.Count) tweak checkboxes." "Success"
}

# --- Build Features & Fixes UI ---
$panelIndex = 0
if ($controls["FeaturesPanel1"] -and $controls["FeaturesPanel2"] -and $controls["FeaturesPanel3"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Features") {
    $featPanels = @($controls["FeaturesPanel1"], $controls["FeaturesPanel2"], $controls["FeaturesPanel3"])
    foreach ($featKey in $featuresConfig.Features.PSObject.Properties.Name) {
        $feat = $featuresConfig.Features.$featKey
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $feat.content; $cb.Tag = $featKey; $cb.Style = Get-WpfResource "TweakCheckBox"
        if ($feat.description) { $cb.ToolTip = $feat.description }
        $featPanels[$panelIndex].Children.Add($cb) | Out-Null
        $featuresCheckboxes += $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($featuresCheckboxes.Count) feature checkboxes." "Success"
}
if ($controls["FixesWrapPanel"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Fixes") {
    foreach ($fixKey in $featuresConfig.Fixes.PSObject.Properties.Name) {
        $fix = $featuresConfig.Fixes.$fixKey
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "FeatureCard"; $btn.Content = $fix.content; $btn.ToolTip = $fix.description; $btn.Tag = $fix
        $btn.Add_Click({
            $f = $this.Tag
            if (-not (Show-Confirm "Run Fix" "Execute: $($f.content)?")) { return }
            Write-Log "Running fix: $($f.content)" "Header"
            try { & ([scriptblock]::Create($f.script)); Write-Log "Fix completed: $($f.content)" "Success"; Show-Info "Fix Complete" "$($f.content)`n`nCompleted successfully." } catch { Write-Log "Fix failed: $_" "Error"; Show-Info "Fix Failed" "$($f.content)`n`nError: $_" }
        })
        $controls["FixesWrapPanel"].Children.Add($btn) | Out-Null
    }
    Write-Log "Built $($featuresConfig.Fixes.PSObject.Properties.Name.Count) fix buttons." "Success"
}

# --- Build Legacy Windows Panels UI ---
$legacyPanels = @(
    @{ Name = "Computer Management"; Desc = "Manage disks, services, event viewer, and more"; Command = "compmgmt.msc" },
    @{ Name = "Control Panel"; Desc = "Classic Windows Control Panel"; Command = "control" },
    @{ Name = "Device Manager"; Desc = "View and update hardware devices and drivers"; Command = "devmgmt.msc" },
    @{ Name = "Disk Management"; Desc = "Manage disk partitions, volumes, and drives"; Command = "diskmgmt.msc" },
    @{ Name = "Event Viewer"; Desc = "View system logs and application events"; Command = "eventvwr.msc" },
    @{ Name = "Network Connections"; Desc = "Manage network adapters and connections"; Command = "ncpa.cpl" },
    @{ Name = "Power Panel"; Desc = "Configure power plans and battery settings"; Command = "powercfg.cpl" },
    @{ Name = "Printer Panel"; Desc = "Manage printers and print queues"; Command = "control printers" },
    @{ Name = "Region"; Desc = "Set regional format, language, and location"; Command = "intl.cpl" },
    @{ Name = "Registry Editor"; Desc = "View and edit Windows registry entries"; Command = "regedit" },
    @{ Name = "Services"; Desc = "Manage Windows services and their startup types"; Command = "services.msc" },
    @{ Name = "Sound Settings"; Desc = "Configure audio devices and sound effects"; Command = "mmsys.cpl" },
    @{ Name = "System Properties"; Desc = "View system info, performance, remote settings"; Command = "sysdm.cpl" },
    @{ Name = "Task Scheduler"; Desc = "Schedule automated tasks and triggers"; Command = "taskschd.msc" },
    @{ Name = "Time and Date"; Desc = "Set date, time, and timezone"; Command = "timedate.cpl" },
    @{ Name = "Windows Restore"; Desc = "System Restore - create or restore restore points"; Command = "rstrui.exe" }
)

if ($controls["LegacyPanel1"] -and $controls["LegacyPanel2"] -and $controls["LegacyPanel3"]) {
    $legacyPanelsArr = @($controls["LegacyPanel1"], $controls["LegacyPanel2"], $controls["LegacyPanel3"])
    $panelIndex = 0
    foreach ($panel in $legacyPanels) {
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "FeatureCard"; $btn.ToolTip = "$($panel.Name)`n$($panel.Desc)`n`nLaunch: $($panel.Command)"; $btn.Tag = $panel.Command; $btn.Width = 380
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
        $textSp = New-Object System.Windows.Controls.StackPanel; $textSp.Orientation = "Vertical"; $textSp.VerticalAlignment = "Center"
        $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = $panel.Name; $nameTb.FontSize = 13; $nameTb.FontWeight = "SemiBold"; $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor"); $textSp.Children.Add($nameTb) | Out-Null
        $descTb = New-Object System.Windows.Controls.TextBlock; $descTb.Text = $panel.Desc; $descTb.FontSize = 11; $descTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted"); $descTb.TextWrapping = "Wrap"; $descTb.MaxWidth = 280; $textSp.Children.Add($descTb) | Out-Null
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
        $legacyPanelsArr[$panelIndex].Children.Add($btn) | Out-Null
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($legacyPanels.Count) legacy panel buttons." "Success"
}

$script:pkgManager = "winget"

function Ensure-PackageManager {
    param([string]$Pkg)
    if (Get-Command $Pkg -ErrorAction SilentlyContinue) { return $true }
    Write-Log "$Pkg not found. Installing..." "Info"
    try {
        if ($Pkg -eq "winget") {
            $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            $out = "$env:TEMP\AppInstaller.msixbundle"
            Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
            Add-AppxPackage -Path $out -ErrorAction Stop
            Remove-Item $out -Force -ErrorAction SilentlyContinue
        } elseif ($Pkg -eq "choco") {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        }
        if (Get-Command $Pkg -ErrorAction SilentlyContinue) { Write-Log "$Pkg installed." "Success"; return $true }
        Write-Log "$Pkg install completed but command not found." "Warn"; return $false
    } catch { Write-Log "$Pkg install failed: $_" "Error"; return $false }
}

if ($controls["BtnInstall"]) {
    $controls["BtnInstall"].Add_Click({
        $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
        $pkg = $script:pkgManager
        if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
        if (-not (Show-Confirm "Install Apps" "Install $($selected.Count) application(s) via $pkg?")) { return }
        Write-Log "Starting installation via $pkg..." "Header"
        Set-Status "Installing $($selected.Count) app(s) via $pkg..."
        Show-Progress -Text "Preparing installation..." -Value 0.05
        $count = 0
        foreach ($cb in $selected) {
            $id = $cb.Tag; $count++
            $percent = [math]::Max(0.05, [math]::Min(0.95, ($count / $selected.Count) * 0.9))
            Write-Log "Installing $id..." "Info"; Set-Status "Installing $id..."
            Show-Progress -Text "Installing: $id ($count/$($selected.Count))" -Value $percent
            try {
                if ($pkg -eq "winget") { winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null }
                else { choco install $id -y 2>&1 | Out-Null }
                Write-Log "Done: $id" "Success"
            } catch { Write-Log "Failed: $id`: $_" "Error" }
        }
        Update-InstalledCache
        if ($controls["ChkShowInstalled"]) { Apply-Filters }
        Hide-Progress; Set-Status "Ready"
        Show-Info "Installation Complete" "$($selected.Count) application(s) installed via $pkg."
        Write-Log "Installation complete." "Header"
        Set-ProgressTaskbar -state "Normal" -value 1
    })
}

if ($controls["BtnUninstall"]) {
    $controls["BtnUninstall"].Add_Click({
        $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
        $pkg = $script:pkgManager
        if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
        if (-not (Show-Confirm "Uninstall Apps" "Uninstall $($selected.Count) application(s) and deep clean leftovers via $pkg?`n`nThis cannot be undone!")) { return }
        Write-Log "Starting uninstallation via $pkg..." "Header"
        Set-Status "Uninstalling $($selected.Count) app(s) via $pkg..."
        Show-Progress -Text "Preparing uninstallation..." -Value 0.05
        $count = 0
        foreach ($cb in $selected) {
            $id = $cb.Tag; $count++
            $percent = [math]::Max(0.05, [math]::Min(0.95, ($count / $selected.Count) * 0.9))
            Write-Log "Uninstalling $id..." "Info"; Set-Status "Uninstalling $id..."
            Show-Progress -Text "Uninstalling: $id ($count/$($selected.Count))" -Value $percent
            $ok = $true
            try {
                if ($pkg -eq "winget") { winget uninstall --id=$id --silent --purge --accept-source-agreements 2>&1 | Out-Null }
                else { choco uninstall $id -y 2>&1 | Out-Null }
                Write-Log "Done: $id" "Success"
            } catch { Write-Log "Failed: $id`: $_" "Error"; $ok = $false }
            if ($ok -and $pkg -eq "winget") {
                Write-Log "Deep Cleaning $id..." "Info"; Set-Status "Cleaning $id leftovers..."
                foreach ($term in ($id -split '\.') | Where-Object { $_.Length -gt 4 }) {
                    foreach ($basePath in @($env:APPDATA, $env:LOCALAPPDATA, $env:PROGRAMDATA)) {
                        Get-ChildItem -Path $basePath -Directory -Filter "*$term*" -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force; Write-Log "Deleted: $($_.FullName)" "Success" } catch { Write-Log "Cleanup dir failed: $($_.FullName)" "Warn" } }
                    }
                    foreach ($regPath in @("HKCU:\Software", "HKLM:\SOFTWARE\WOW6432Node")) {
                        if (Test-Path $regPath) { Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.Name.Contains($term) } | ForEach-Object { try { Remove-Item $_.PSPath -Recurse -Force; Write-Log "Deleted Reg: $($_.Name)" "Success" } catch { Write-Log "Cleanup reg failed: $($_.Name)" "Warn" } } }
                    }
                }
            }
        }
        Update-InstalledCache
        if ($controls["ChkShowInstalled"]) { Apply-Filters }
        Hide-Progress; Set-Status "Ready"
        Show-Info "Uninstall Complete" "$($selected.Count) application(s) uninstalled via $pkg."
        Write-Log "Uninstallation complete." "Header"
    })
}

if ($controls["PkgWinGet"]) { $controls["PkgWinGet"].Add_Checked({ $script:pkgManager = "winget"; Write-Log "Package manager: WinGet" "Info" }) }
if ($controls["PkgChoco"]) { $controls["PkgChoco"].Add_Checked({ $script:pkgManager = "choco"; Write-Log "Package manager: Chocolatey" "Info" }) }

if ($controls["BtnRunFeatures"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Features") {
    $controls["BtnRunFeatures"].Add_Click({
        $selected = $featuresCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No features selected." "Warn"; return }
        if (-not (Show-Confirm "Run Features" "Apply $($selected.Count) selected feature(s)?")) { return }
        Write-Log "Running Selected Features..." "Header"
        Set-Status "Running $($selected.Count) feature(s)..."
        foreach ($cb in $selected) {
            $featKey = $cb.Tag
            $feat = $featuresConfig.Features.$featKey
            if (-not $feat) { continue }
            Write-Log "Running: $($feat.content)" "Info"
            try { Invoke-Expression $feat.script; Write-Log "Feature completed: $($feat.content)" "Success" } catch { Write-Log "Feature failed: $($feat.content): $_" "Error" }
        }
        Set-Status "Ready"
        Show-Info "Features Complete" "$($selected.Count) feature(s) applied."
        Write-Log "All selected features completed." "Header"
    })
}

$script:embedded_meta = @'
{
  "version": "2.0"
}

'@ | ConvertFrom-Json
$script:embedded_features = @'
{
  "Features": {
    "dotnet": { "content": ".NET Framework (2, 3, 4)", "description": "Enable .NET Framework 3.5 and 4.8", "script": "Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs -All -NoRestart" },
    "hyperv": { "content": "Hyper-V", "description": "Enable Hyper-V virtualization", "script": "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart" },
    "f8_boot_enable": { "content": "Legacy F8 Boot Recovery - Enable", "description": "Enable legacy F8 boot menu", "script": "bcdedit /set {default} bootmenupolicy legacy" },
    "f8_boot_disable": { "content": "Legacy F8 Boot Recovery - Disable", "description": "Disable legacy F8 boot menu", "script": "bcdedit /set {default} bootmenupolicy standard" },
    "legacy_media": { "content": "Legacy Media Components (WMP, DirectPlay)", "description": "Enable Windows Media Player and DirectPlay", "script": "Enable-WindowsOptionalFeature -Online -FeatureName 'WindowsMediaPlayer' -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName 'DirectPlay' -All -NoRestart" },
    "nfs": { "content": "Network File System (NFS)", "description": "Enable Services for NFS", "script": "Enable-WindowsOptionalFeature -Online -FeatureName 'ServicesForNFS-ClientOnly' -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName 'ClientForNFS-Infrastructure' -All -NoRestart" },
    "registry_backup": { "content": "Registry Backup (Daily Task 12:30am)", "description": "Schedule daily registry backup task", "script": "schtasks /create /tn 'Registry Backup' /tr 'regedit /e C:\\Windows\\System32\\config\\RegBack\\registry_backup.reg' /sc daily /st 00:30 /f" },
    "sandbox": { "content": "Windows Sandbox", "description": "Enable Windows Sandbox", "script": "Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All -NoRestart" },
    "wsl": { "content": "Windows Subsystem for Linux (WSL)", "description": "Enable WSL2 and Virtual Machine Platform", "script": "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart" }
  },
  "Fixes": {
    "autologon": { "content": "AutoLogon - Run", "description": "Open the Autologon configuration tool", "script": "Start-Process 'https://live.sysinternals.com/Autologon.exe'" },
    "reset_network": { "content": "Network - Reset", "description": "Reset TCP/IP, Winsock, flush DNS", "script": "netsh winsock reset; netsh int ip reset; ipconfig /release; ipconfig /renew; ipconfig /flushdns" },
    "ntp_server": { "content": "NTP Server - Enable", "description": "Sync time with pool.ntp.org", "script": "w32tm /config /manualpeerlist:'pool.ntp.org' /syncfromflags:manual /reliable:yes /update; w32tm /resync" },
    "sfc_scan": { "content": "System Corruption Scan - Run", "description": "Run SFC scan to check system files", "script": "sfc /scannow" },
    "system_repair": { "content": "System Repair - Full (Chkdsk + SFC + DISM)", "description": "Run chkdsk, SFC, and DISM repair", "script": "chkdsk /scan; sfc /scannow; dism /online /cleanup-image /restorehealth" },
    "update_repair": { "content": "Windows Update - Full Repair", "description": "Complete Windows Update component repair", "script": "net stop wuauserv /y; net stop cryptSvc /y; net stop bits /y; net stop msiserver /y; Ren C:\\Windows\\SoftwareDistribution SoftwareDistribution.old; Ren C:\\Windows\\System32\\catroot2 catroot2.old; netsh winsock reset; net start wuauserv; net start cryptSvc; net start bits; net start msiserver" },
    "reset_wu": { "content": "Windows Update - Reset", "description": "Reset Windows Update components", "script": "net stop wuauserv; net stop cryptSvc; net stop bits; net stop msiserver; Ren C:\\Windows\\SoftwareDistribution SoftwareDistribution.old; Ren C:\\Windows\\System32\\catroot2 catroot2.old; net start wuauserv; net start cryptSvc; net start bits; net start msiserver" },
    "reinstall_winget": { "content": "WinGet - Reinstall", "description": "Reinstall WinGet package manager", "script": "Get-AppxPackage Microsoft.DesktopAppInstaller | Remove-AppxPackage; start 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1'" }
  }
}

'@ | ConvertFrom-Json
$script:embedded_preferences = @'
{
  "bsod_verbose": { "content": "BSoD Verbose Mode", "description": "Show detailed error on Blue Screen of Death.", "registry_on": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\CrashControl","name":"DisplayParameters","value":1}], "registry_off": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\CrashControl","name":"DisplayParameters","value":0}] },
  "login_acrylic": { "content": "Logon Screen Acrylic Blur", "description": "Enable acrylic blur on login screen.", "registry_on": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"DisableAcrylicBackgroundOnLogon","value":0}], "registry_off": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"DisableAcrylicBackgroundOnLogon","value":1}] },
  "login_verbose": { "content": "Logon Verbose Mode", "description": "Display detailed startup/shutdown messages.", "registry_on": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System","name":"VerboseStatus","value":1}], "registry_off": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System","name":"VerboseStatus","value":0}] },
  "mouse_acceleration": { "content": "Mouse Acceleration", "description": "Toggle mouse pointer precision.", "registry_on": [{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseSpeed","value":"1"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold1","value":"6"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold2","value":"10"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseSpeed","value":"0"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold1","value":"0"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold2","value":"0"}] },
  "numlock_on": { "content": "Num Lock on Startup", "description": "Enable Num Lock automatically at startup.", "registry_on": [{"path":"HKCU:\\Control Panel\\Keyboard","name":"InitialKeyboardIndicators","value":"2"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Keyboard","name":"InitialKeyboardIndicators","value":"0"}] },
  "scrollbars_visible": { "content": "Scrollbars Always Visible", "description": "Force scrollbars to always be visible.", "registry_on": [{"path":"HKCU:\\Control Panel\\Accessibility","name":"DynamicScrollbars","value":"0"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Accessibility","name":"DynamicScrollbars","value":"1"}] },
  "bing_search": { "content": "Start Menu Bing Search", "description": "Disable Bing search suggestions.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"DisableSearchBoxSuggestions","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"DisableSearchBoxSuggestions","value":0}] },
  "start_recommendations": { "content": "Start Menu Recommendations", "description": "Hide recommended section in Start menu.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"HideRecommendedSection","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"HideRecommendedSection","value":0}] },
  "sticky_keys": { "content": "Sticky Keys", "description": "Disable Sticky Keys accessibility feature.", "registry_on": [{"path":"HKCU:\\Control Panel\\Accessibility\\StickyKeys","name":"Flags","value":"506"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Accessibility\\StickyKeys","name":"Flags","value":"510"}] },
  "taskbar_center": { "content": "Taskbar Centered Icons", "description": "Center taskbar icons (Windows 11 style).", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"TaskbarAl","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"TaskbarAl","value":0}] },
  "taskbar_search": { "content": "Taskbar Search Icon", "description": "Show search icon only on taskbar.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Search","name":"SearchboxTaskbarMode","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Search","name":"SearchboxTaskbarMode","value":0}] },
  "taskbar_taskview": { "content": "Taskbar Task View Icon", "description": "Show/hide Task View button.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowTaskViewButton","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowTaskViewButton","value":0}] },
  "cross_device": { "content": "Cross-Device Resume", "description": "Allow cross-device activity sync.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CDP","name":"RomeSdk","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CDP","name":"RomeSdk","value":0}] },
  "dark_theme": { "content": "Dark Theme for Windows", "description": "Enable Windows dark theme.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"AppsUseLightTheme","value":0},{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"SystemUsesLightTheme","value":0}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"AppsUseLightTheme","value":1},{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"SystemUsesLightTheme","value":1}] },
  "file_extensions": { "content": "File Explorer File Extensions", "description": "Show file extensions.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"HideFileExt","value":0}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"HideFileExt","value":1}] },
  "hidden_files": { "content": "File Explorer Hidden Files", "description": "Show hidden files and folders.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"Hidden","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"Hidden","value":2}] },
  "mpo": { "content": "Multiplane Overlay", "description": "Enable/disable MPO. Disabling can fix GPU issues.", "registry_on": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm","name":"OverlayTestMode","value":5}], "registry_off": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm","name":"OverlayTestMode","value":0}] },
  "s0_standby": { "content": "S0 Sleep Network Connectivity", "description": "Keep network connectivity during Modern Standby.", "registry_on": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power","name":"NetworkConnectivityInStandby","value":1}], "registry_off": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power","name":"NetworkConnectivityInStandby","value":0}] },
  "s3_sleep": { "content": "S3 Sleep", "description": "Enable traditional S3 sleep state.", "registry_on": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power","name":"PlatformAoAcOverride","value":0}], "registry_off": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power","name":"PlatformAoAcOverride","value":1}] },
  "battery_percent": { "content": "System Tray Battery Percentage", "description": "Show battery percentage in system tray.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowBatteryPercentage","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowBatteryPercentage","value":0}] }
}

'@ | ConvertFrom-Json
$script:embedded_dns = @'
{
  "Default_DHCP": { "description": "Default DHCP (reset to auto)" },
  "Google": { "description": "Google Public DNS", "ipv4": ["8.8.8.8","8.8.4.4"], "ipv6": ["2001:4860:4860::8888","2001:4860:4860::8844"] },
  "Cloudflare": { "description": "Cloudflare DNS (1.1.1.1)", "ipv4": ["1.1.1.1","1.0.0.1"], "ipv6": ["2606:4700:4700::1111","2606:4700:4700::1001"] },
  "Cloudflare_Malware": { "description": "Cloudflare Malware Protection", "ipv4": ["1.1.1.2","1.0.0.2"], "ipv6": ["2606:4700:4700::1112","2606:4700:4700::1002"] },
  "Cloudflare_Malware_Adult": { "description": "Cloudflare Malware & Adult Protection", "ipv4": ["1.1.1.3","1.0.0.3"], "ipv6": ["2606:4700:4700::1113","2606:4700:4700::1003"] },
  "Open_DNS": { "description": "Cisco OpenDNS", "ipv4": ["208.67.222.222","208.67.220.220"], "ipv6": ["2620:119:35::35","2620:119:53::53"] },
  "Quad9": { "description": "Quad9 Security DNS", "ipv4": ["9.9.9.9","149.112.112.112"], "ipv6": ["2620:fe::fe","2620:fe::9"] },
  "AdGuard_Ads_Trackers": { "description": "AdGuard DNS (Ads & Trackers)", "ipv4": ["94.140.14.14","94.140.15.15"], "ipv6": ["2a10:50c0::ad1:ff","2a10:50c0::ad2:ff"] },
  "AdGuard_Ads_Trackers_Malware_Adult": { "description": "AdGuard DNS (Ads, Trackers, Malware, Adult)", "ipv4": ["94.140.14.15","94.140.15.16"], "ipv6": ["2a10:50c0::bad1:ff","2a10:50c0::bad2:ff"] }
}

'@ | ConvertFrom-Json
$script:embedded_tweaks = @'
{
  "Performance": {
    "disable_sysmain": { "content": "Disable SysMain (Superfetch)", "description": "Reduces disk usage and RAM consumption", "services": [{"name": "SysMain", "action": "stop_disable"}] },
    "disable_search_index": { "content": "Disable Search Indexing", "description": "Reduces CPU and disk usage from Windows Search", "services": [{"name": "WSearch", "action": "stop_disable"}] },
    "high_perf_power": { "content": "High Performance Power Plan", "description": "Sets power plan to high performance", "script": "powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" },
    "visual_perf": {
      "content": "Visual Effects - Set to Best Performance", "description": "Sets the system preferences to performance.",
      "registry": [
        {"path": "HKCU:\\Control Panel\\Desktop", "name": "DragFullWindows", "value": "0", "type": "String"},
        {"path": "HKCU:\\Control Panel\\Desktop", "name": "MenuShowDelay", "value": "200", "type": "String"},
        {"path": "HKCU:\\Control Panel\\Desktop\\WindowMetrics", "name": "MinAnimate", "value": "0", "type": "String"},
        {"path": "HKCU:\\Control Panel\\Keyboard", "name": "KeyboardDelay", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "ListviewAlphaSelect", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "ListviewShadow", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "TaskbarAnimations", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects", "name": "VisualFXSetting", "value": 3, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\DWM", "name": "EnableAeroPeek", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "TaskbarMn", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "ShowTaskViewButton", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search", "name": "SearchboxTaskbarMode", "value": 0, "type": "DWord"}
      ],
      "script": "Set-ItemProperty -Path \"HKCU:\\Control Panel\\Desktop\" -Name \"UserPreferencesMask\" -Type Binary -Value ([byte[]](144,18,3,128,16,0,0,0))",
      "undoScript": "Remove-ItemProperty -Path \"HKCU:\\Control Panel\\Desktop\" -Name \"UserPreferencesMask\""
    }
  },
  "Privacy": {
    "disable_telemetry": { "content": "Disable Telemetry", "description": "Disables Windows telemetry and data collection", "registry": [{"path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection", "name": "AllowTelemetry", "value": 0, "type": "DWord"}] },
    "disable_activity_history": { "content": "Disable Activity History", "description": "Stops Windows from tracking your activity", "registry": [{"path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System", "name": "EnableActivityFeed", "value": 0, "type": "DWord"}] },
    "disable_location": { "content": "Disable Location Tracking", "description": "Disables location services", "registry": [{"path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\LocationAndSensors", "name": "DisableLocation", "value": 1, "type": "DWord"}] }
  },
  "Essential Tweaks": {
    "WPFTweaksActivity": { "content": "Activity History - Disable", "description": "Erases recent docs, clipboard, and run history.", "registry": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"EnableActivityFeed","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"PublishUserActivities","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"UploadUserActivities","value":0,"type":"DWord"}] },
    "WPFTweaksConsumerFeatures": { "content": "ConsumerFeatures - Disable", "description": "Disables automatic installation of games/third-party apps from Windows Store.", "registry": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent","name":"DisableWindowsConsumerFeatures","value":1,"type":"DWord"}] },
    "WPFTweaksDiskCleanup": { "content": "Disk Cleanup - Run", "description": "Runs Disk Cleanup on Drive C: and removes old Windows Updates.", "script": "cleanmgr.exe /d C: /VERYLOWDISK\nDism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase" },
    "WPFTweaksDisableExplorerAutoDiscovery": { "content": "File Explorer Automatic Folder Discovery - Disable", "description": "Windows Explorer automatically tries to guess the type of the folder based on its contents, slowing down browsing.", "script": "`$bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"\n`$bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"\nRemove-Item -Path `$bags -Recurse -Force\nRemove-Item -Path `$bagMRU -Recurse -Force\n`$allFolders = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\\AllFolders\\Shell\"\nif (!(Test-Path `$allFolders)) { New-Item -Path `$allFolders -Force }\nNew-ItemProperty -Path `$allFolders -Name \"FolderType\" -Value \"NotSpecified\" -PropertyType String -Force", "undoScript": "`$bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"\n`$bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"\nRemove-Item -Path `$bags -Recurse -Force\nRemove-Item -Path `$bagMRU -Recurse -Force" },
    "WPFTweaksLocation": { "content": "Location Tracking - Disable", "description": "Disables Location Tracking.", "services": [{"name":"lfsvc","action":"stop_disable"}], "registry": [{"path":"HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location","name":"Value","value":"Deny","type":"String"},{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Sensor\\Overrides\\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}","name":"SensorPermissionState","value":0,"type":"DWord"},{"path":"HKLM:\\SYSTEM\\Maps","name":"AutoUpdateEnabled","value":0,"type":"DWord"}] },
    "WPFTweaksServices": { "content": "Services - Set to Manual", "description": "Sets non-essential services to Manual startup.", "services": [{"name":"CscService","action":"stop_disable"},{"name":"DiagTrack","action":"stop_disable"},{"name":"MapsBroker","action":"set_manual"},{"name":"StorSvc","action":"set_manual"},{"name":"SharedAccess","action":"stop_disable"}], "script": "`$Memory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB\nSet-ItemProperty -Path \"HKLM:\\SYSTEM\\CurrentControlSet\\Control\" -Name SvcHostSplitThresholdInKB -Value `$Memory" },
    "WPFTweaksTelemetry": { "content": "Telemetry - Disable", "description": "Disables Microsoft Telemetry.", "registry": [{"path":"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo","name":"Enabled","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Privacy","name":"TailoredExperiencesWithDiagnosticDataEnabled","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Speech_OneCore\\Settings\\OnlineSpeechPrivacy","name":"HasAccepted","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Input\\TIPC","name":"Enabled","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\InputPersonalization","name":"RestrictImplicitInkCollection","value":1,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\InputPersonalization","name":"RestrictImplicitTextCollection","value":1,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\InputPersonalization\\TrainedDataStore","name":"HarvestContacts","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Personalization\\Settings","name":"AcceptedPrivacyPolicy","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\DataCollection","name":"AllowTelemetry","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"Start_TrackProgs","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"PublishUserActivities","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Siuf\\Rules","name":"NumberOfSIUFInPeriod","value":0,"type":"DWord"}], "script": "Set-MpPreference -SubmitSamplesConsent 2\nSet-Service -Name diagtrack -StartupType Disabled\nSet-Service -Name wermgr -StartupType Disabled\nRemove-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Siuf\\Rules\" -Name PeriodInNanoSeconds", "undoScript": "Set-MpPreference -SubmitSamplesConsent 1\nSet-Service -Name diagtrack -StartupType Automatic\nSet-Service -Name wermgr -StartupType Automatic\nNew-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Siuf\\Rules\" -Name PeriodInNanoSeconds -Value 1 -PropertyType DWord" },
    "WPFTweaksDeleteTempFiles": { "content": "Temporary Files - Remove", "description": "Erases TEMP Folders.", "script": "Remove-Item -Path \"`$Env:Temp\\*\" -Recurse -Force\nRemove-Item -Path \"`$Env:SystemRoot\\Temp\\*\" -Recurse -Force" },
    "WPFTweaksDeBloat": { "content": "Unwanted Pre-Installed Apps - Remove", "description": "Removes Windows pre-installed applications.", "appx_packages": ["Microsoft.WindowsFeedbackHub","Microsoft.BingNews","Microsoft.BingSearch","Microsoft.BingWeather","Clipchamp.Clipchamp","Microsoft.Todos","Microsoft.PowerAutomateDesktop","Microsoft.MicrosoftSolitaireCollection","Microsoft.WindowsSoundRecorder","Microsoft.MicrosoftStickyNotes","Microsoft.Windows.DevHome","Microsoft.Paint","Microsoft.OutlookForWindows","Microsoft.WindowsAlarms","Microsoft.StartExperiencesApp","Microsoft.GetHelp","Microsoft.ZuneMusic","MicrosoftCorporationII.QuickAssist","MSTeams"], "script": "`$TeamsPath = \"`$Env:LocalAppData\\Microsoft\\Teams\\Update.exe\"\nif (Test-Path `$TeamsPath) { Start-Process `$TeamsPath -ArgumentList -uninstall -wait; Remove-Item `$TeamsPath -Recurse -Force }" },
    "WPFTweaksWidget": { "content": "Widgets - Remove", "description": "Removes taskbar widgets.", "script": "Get-Process *Widget* | Stop-Process\nGet-AppxPackage Microsoft.WidgetsPlatformRuntime -AllUsers | Remove-AppxPackage -AllUsers\nGet-AppxPackage MicrosoftWindows.Client.WebExperience -AllUsers | Remove-AppxPackage -AllUsers" },
    "WPFTweaksWPBT": { "content": "Windows Platform Binary Table (WPBT) - Disable", "description": "Prevents vendors from executing code at boot without consent.", "registry": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager","name":"DisableWpbtExecution","value":1,"type":"DWord"}] }
  }
}

'@ | ConvertFrom-Json
$script:embedded_themes = @'
{
  "dark": {
    "windowBackground": "#1C1C1E", "headerBackground": "#242426", "headerBorder": "#3A3A3C",
    "footerBackground": "#242426", "footerBorder": "#3A3A3C",
    "cardBackground": "#2C2C2E", "cardForeground": "#D4CEBC", "cardBorder": "#48484A",
    "accentColor": "#4D9DE0", "accentHover": "#3A87C8",
    "pageTitleColor": "#E8E0CC", "categoryHeaderColor": "#4D9DE0", "textMuted": "#8E8E93",
    "textBoxBackground": "#2C2C2E", "textBoxForeground": "#D4CEBC", "textBoxBorder": "#48484A",
    "dangerColor": "#C0392B", "dangerHover": "#962D22",
    "selectedBorder": "#4D9DE0", "selectedBackground": "#162840",
    "hoverBackground": "#262628", "secondaryBackground": "#242426", "secondaryHover": "#262628"
  },
  "light": {
    "windowBackground": "#F4F8FC", "headerBackground": "#FFFFFF", "headerBorder": "#C4D9ED",
    "footerBackground": "#FFFFFF", "footerBorder": "#C4D9ED",
    "cardBackground": "#FFFFFF", "cardForeground": "#1A2733", "cardBorder": "#BDD3E8",
    "accentColor": "#4D9DE0", "accentHover": "#3A87C8",
    "pageTitleColor": "#1A2733", "categoryHeaderColor": "#4D9DE0", "textMuted": "#7A96AE",
    "textBoxBackground": "#FFFFFF", "textBoxForeground": "#1A2733", "textBoxBorder": "#BDD3E8",
    "dangerColor": "#C0392B", "dangerHover": "#962D22",
    "selectedBorder": "#4D9DE0", "selectedBackground": "#E0EEFA",
    "hoverBackground": "#EBF3FA", "secondaryBackground": "#FFFFFF", "secondaryHover": "#EBF3FA"
  }
}

'@ | ConvertFrom-Json
$script:embedded_apps = @'
{
  "Browsers": {
    "brave": { "content": "Brave", "winget": "Brave.Brave", "description": "Privacy-first browser with built-in ad blocker" },
    "firefox": { "content": "Firefox", "winget": "Mozilla.Firefox", "description": "Privacy-focused web browser" },
    "tor": { "content": "Tor Browser", "winget": "TorProject.TorBrowser", "description": "Anonymous web browsing via Tor network" }
  },
  "Security & Privacy": {
    "mullvad": { "content": "Mullvad VPN", "winget": "Mullvad.MullvadVPN", "description": "Privacy-focused VPN service" },
    "protonvpn": { "content": "ProtonVPN", "winget": "Proton.ProtonVPN", "description": "Secure VPN with no-logs policy" },
    "malwarebytes": { "content": "Malwarebytes", "winget": "Malwarebytes.Malwarebytes", "description": "On-demand malware scanner and remover" },
    "veracrypt": { "content": "VeraCrypt", "winget": "IDRIX.VeraCrypt", "description": "Disk encryption software for files and partitions" }
  },
  "Development": {
    "vscode": { "content": "VS Code", "winget": "Microsoft.VisualStudioCode", "description": "Lightweight source code editor" },
    "github_desktop": { "content": "GitHub Desktop", "winget": "GitHub.GitHubDesktop", "description": "GUI for Git and GitHub" },
    "docker": { "content": "Docker Desktop", "winget": "Docker.DockerDesktop", "description": "Container platform for dev and test" },
    "dbeaver": { "content": "DBeaver", "winget": "DBeaver.DBeaver", "description": "Universal database manager" },
    "bruno": { "content": "Bruno", "winget": "Bruno.Bruno", "description": "Offline-first API testing client" },
    "git": { "content": "Git", "winget": "Git.Git", "description": "Distributed version control system" },
    "nodejs": { "content": "Node.js LTS", "winget": "OpenJS.NodeJS.LTS", "description": "JavaScript runtime built on Chrome's V8 engine" },
    "python": { "content": "Python 3.12", "winget": "Python.Python.3.12", "description": "High-level programming language" },
    "windows_terminal": { "content": "Windows Terminal", "winget": "Microsoft.WindowsTerminal", "description": "Modern terminal application for Windows" },
    "powershell": { "content": "PowerShell 7", "winget": "Microsoft.PowerShell", "description": "Cross-platform shell and scripting language" },
    "ohmyposh": { "content": "Oh My Posh", "winget": "JanDeDobbeleer.OhMyPosh", "description": "Prompt theme engine for any shell" }
  },
  "Media & Creative": {
    "gimp": { "content": "GIMP", "winget": "GIMP.GIMP", "description": "Free and open-source image editor" },
    "krita": { "content": "Krita", "winget": "Krita.Krita", "description": "Professional digital painting tool" },
    "inkscape": { "content": "Inkscape", "winget": "Inkscape.Inkscape", "description": "Vector graphics editor" },
    "kdenlive": { "content": "Kdenlive", "winget": "KDE.Kdenlive", "description": "Free and open-source video editor" },
    "obs": { "content": "OBS Studio", "winget": "OBSProject.OBSStudio", "description": "Video recording and live streaming software" },
    "audacity": { "content": "Audacity", "winget": "Audacity.Audacity", "description": "Multi-track audio recorder and editor" },
    "mpchc": { "content": "MPC-HC", "winget": "clsid2.mpc-hc", "description": "Lightweight media player" },
    "vlc": { "content": "VLC", "winget": "VideoLAN.VLC", "description": "Free and open source multimedia player" },
    "foobar2000": { "content": "foobar2000", "winget": "PeterPawlowski.foobar2000", "description": "Advanced audio player" },
    "ytdlp": { "content": "yt-dlp", "winget": "yt-dlp.yt-dlp", "description": "Command-line video downloader" },
    "sharex": { "content": "ShareX", "winget": "ShareX.ShareX", "description": "Screen capture and file sharing tool" }
  },
  "Utilities": {
    "powertoys": { "content": "PowerToys", "winget": "Microsoft.PowerToys", "description": "System utilities: FancyZones, PowerRename, Run, etc." },
    "everything": { "content": "Everything", "winget": "voidtools.Everything", "description": "Lightning-fast file search engine" },
    "ditto": { "content": "Ditto", "winget": "Ditto.Ditto", "description": "Clipboard manager with search history" },
    "hwinfo": { "content": "HWiNFO64", "winget": "REALiX.HWiNFO", "description": "Comprehensive hardware monitoring tool" },
    "syncthing": { "content": "Syncthing", "winget": "Syncthing.Syncthing", "description": "P2P file sync between devices" },
    "7zip_zs": { "content": "7-Zip ZS", "winget": "mcmilk.7zip-zstd", "description": "File archiver with Zstandard support" },
    "revo": { "content": "Revo Uninstaller", "winget": "RevoUninstaller.RevoUninstaller", "description": "Advanced uninstaller tool" },
    "bitwarden": { "content": "Bitwarden", "winget": "Bitwarden.Bitwarden", "description": "Open source password manager" },
    "motrix": { "content": "Motrix", "winget": "Motrix.Motrix", "description": "Full-featured download manager" },
    "mobaxterm": { "content": "MobaXterm", "winget": "Mobatek.MobaXterm", "description": "Enhanced terminal with X11 server" }
  },
  "Productivity": {
    "obsidian": { "content": "Obsidian", "winget": "Obsidian.Obsidian", "description": "Local-first note-taking app with Markdown" },
    "sumatra": { "content": "Sumatra PDF", "winget": "SumatraPDF.SumatraPDF", "description": "Lightweight PDF and ebook reader" },
    "notion": { "content": "Notion", "winget": "Notion.Notion", "description": "All-in-one workspace for notes and tasks" }
  }
}

'@ | ConvertFrom-Json
$script:appsConfig = if ($script:embedded_apps) { $script:embedded_apps } else { @{} }
$script:tweaksConfig = if ($script:embedded_tweaks) { $script:embedded_tweaks } else { @{} }
$script:dnsConfig = if ($script:embedded_dns) { $script:embedded_dns } else { @{} }
$script:prefsConfig = if ($script:embedded_preferences) { $script:embedded_preferences } else { @{} }
$script:featuresConfig = if ($script:embedded_features) { $script:embedded_features } else { @{} }
$script:themesConfig = if ($script:embedded_themes) { $script:embedded_themes } else { @{} }
$script:embeddedXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HksUtil v2.0 - Windows Optimizer" Width="1200" Height="750" MinWidth="1000" MinHeight="600"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource windowBackground}"
        WindowStyle="None"
        ResizeMode="CanResizeWithGrip">
    <WindowChrome.WindowChrome>
        <WindowChrome CaptionHeight="0" ResizeBorderThickness="5"/>
    </WindowChrome.WindowChrome>
    <Window.Resources>
        <ResourceDictionary>
            <Style TargetType="{x:Type ContextMenu}">
                <Setter Property="SnapsToDevicePixels" Value="True"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="{x:Type ContextMenu}">
                            <Border Background="{DynamicResource cardBackground}"
                                    BorderBrush="{DynamicResource cardBorder}"
                                    BorderThickness="1"
                                    CornerRadius="6"
                                    Padding="4">
                                <ItemsPresenter/>
                            </Border>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="CategoryHeader" TargetType="TextBlock">
                <Setter Property="FontSize" Value="14"/>
                <Setter Property="FontWeight" Value="Bold"/>
                <Setter Property="Foreground" Value="{DynamicResource categoryHeaderColor}"/>
                <Setter Property="Margin" Value="10,15,10,5"/>
            </Style>
            <Style x:Key="TweakCheckBox" TargetType="CheckBox">
                <Setter Property="Margin" Value="5"/>
                <Setter Property="Padding" Value="8,6"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="180"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="CheckBox">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <TextBlock Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" HorizontalAlignment="Left" TextWrapping="Wrap" MaxWidth="500"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="RootBorder" Property="BorderBrush" Value="{DynamicResource selectedBorder}"/>
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource selectedBackground}"/>
                                    <Setter TargetName="RootBorder" Property="BorderThickness" Value="2"/>
                                </Trigger>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ToggleSwitch" TargetType="CheckBox">
                <Setter Property="Margin" Value="5"/>
                <Setter Property="Padding" Value="8,6"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource textBoxBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="200"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="CheckBox">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="RootBorder" Property="BorderBrush" Value="{DynamicResource selectedBorder}"/>
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource selectedBackground}"/>
                                    <Setter TargetName="RootBorder" Property="BorderThickness" Value="2"/>
                                </Trigger>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="PresetCard" TargetType="Button">
                <Setter Property="Margin" Value="8"/>
                <Setter Property="Padding" Value="15,12"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="180"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource hoverBackground}"/>
                                    <Setter Property="BorderBrush" Value="{DynamicResource accentColor}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="FeatureCard" TargetType="Button">
                <Setter Property="Margin" Value="5"/>
                <Setter Property="Padding" Value="12,10"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="280"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource hoverBackground}"/>
                                    <Setter Property="BorderBrush" Value="{DynamicResource accentColor}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="NavButtonStyle" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="12,10"/>
                <Setter Property="Margin" Value="2,2,2,2"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="HorizontalContentAlignment" Value="Left"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="4">
                                <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource headerBorder}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ActionBtn" TargetType="Button">
                <Setter Property="Background" Value="{DynamicResource accentColor}"/>
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource accentHover}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="DangerBtn" TargetType="Button">
                <Setter Property="Background" Value="{DynamicResource dangerColor}"/>
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource dangerHover}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="SecondaryBtn" TargetType="Button">
                <Setter Property="Background" Value="{DynamicResource secondaryBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource secondaryHover}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="DnsCardStyle" TargetType="RadioButton">
                <Setter Property="Margin" Value="4,5"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="RadioButton">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="10,8">
                                <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="RootBorder" Property="BorderBrush" Value="{DynamicResource selectedBorder}"/>
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource selectedBackground}"/>
                                    <Setter TargetName="RootBorder" Property="BorderThickness" Value="2"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ToolbarIconBtn" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="8,4"/>
                <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
                <Setter Property="FontSize" Value="16"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ToolbarIconToggleBtn" TargetType="ToggleButton">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="8,4"/>
                <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
                <Setter Property="FontSize" Value="16"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="ToggleButton">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource selectedBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="PopupMenuItem" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="14,8"/>
                <Setter Property="Margin" Value="2"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="HorizontalContentAlignment" Value="Left"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="4">
                                <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ActionBtnOutline" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource accentColor}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource accentColor}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource accentColor}"/>
                                    <Setter Property="Foreground" Value="White"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="DangerBtnOutline" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource dangerColor}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource dangerColor}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource dangerColor}"/>
                                    <Setter Property="Foreground" Value="White"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>

            <Style x:Key="TopNavButtonStyle" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="9,6"/>
                <Setter Property="Margin" Value="2,0"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="4">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
        </ResourceDictionary>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border x:Name="ToolbarDrag" Grid.Row="0" Background="{DynamicResource headerBackground}" BorderBrush="{DynamicResource headerBorder}" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" Grid.Column="0" Margin="12,6,0,6">
                    <TextBlock x:Name="TitleText" Text="HksUtil" FontSize="16" FontWeight="Bold" Foreground="{DynamicResource accentColor}" VerticalAlignment="Center"/>
                    <TextBlock Text="v2.0" FontSize="10" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="6,2,0,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Grid.Column="1" Margin="24,0,0,0">
                    <Button x:Name="NavInstall" Content="Install" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavTweaks" Content="Tweaks" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavFeatures" Content="Features" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavPreferences" Content="Preferences" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavLegacy" Content="Legacy" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavSettings" Content="Settings" Style="{StaticResource TopNavButtonStyle}"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Grid.Column="2" Margin="0,0,12,0">
                    <Button x:Name="BtnToolbarTheme" Content="&#xE706;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Toggle Theme"/>
                    <ToggleButton x:Name="BtnToolbarSettings" Content="&#xE713;" Style="{StaticResource ToolbarIconToggleBtn}" ToolTip="Settings"/>
                    <Button x:Name="BtnToolbarMinimize" Content="&#xE921;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Minimize"/>
                    <Button x:Name="BtnToolbarMaximize" Content="&#xE922;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Maximize"/>
                    <Button x:Name="BtnToolbarClose" Content="&#xE711;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Close"/>
                </StackPanel>
            </Grid>
        </Border>

        <Popup x:Name="GearPopup" IsOpen="{Binding IsChecked, ElementName=BtnToolbarSettings}" StaysOpen="False" AllowsTransparency="True" PlacementTarget="{Binding ElementName=BtnToolbarSettings}" Placement="Bottom">
            <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="1" CornerRadius="6" Padding="4" SnapsToDevicePixels="True" UseLayoutRounding="True">
                <StackPanel>
                    <Button x:Name="BtnGearExport" Content="Export Config" Style="{StaticResource PopupMenuItem}"/>
                    <Button x:Name="BtnGearImport" Content="Import Config" Style="{StaticResource PopupMenuItem}"/>
                    <Border Height="1" Margin="4,2" Background="{DynamicResource cardBorder}"/>
                    <Button x:Name="BtnGearAbout" Content="About" Style="{StaticResource PopupMenuItem}"/>
                    <Button x:Name="BtnGearDocs" Content="Documentation" Style="{StaticResource PopupMenuItem}"/>
                    <Button x:Name="BtnGearSponsors" Content="Sponsors" Style="{StaticResource PopupMenuItem}"/>
                </StackPanel>
            </Border>
        </Popup>

        <Grid Grid.Row="1">
            <ScrollViewer x:Name="PageInstall" Visibility="Visible" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleInstall" Text="Install Applications" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescInstall" Text="Search and manage application installations via WinGet or Chocolatey." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="0" CornerRadius="8" Padding="16" Margin="0,0,0,15">
                        <StackPanel Orientation="Horizontal">
                            <Grid Width="260">
                                <TextBox x:Name="SearchBox" Padding="8,5" Background="{DynamicResource textBoxBackground}" Foreground="{DynamicResource textBoxForeground}" BorderBrush="{DynamicResource textBoxBorder}" BorderThickness="1"/>
                                <TextBlock x:Name="SearchHint" Text="Search apps..." Foreground="{DynamicResource textMuted}" Margin="8,5,0,0" IsHitTestVisible="False" Visibility="Visible"/>
                            </Grid>
                            <Button x:Name="BtnClearSearch" Content="X" Width="28" Height="28" Margin="5,0,0,0" Background="{DynamicResource hoverBackground}" Foreground="{DynamicResource textMuted}" BorderBrush="{DynamicResource textBoxBorder}" BorderThickness="1" FontSize="12" Cursor="Hand" FontWeight="Bold"/>
                            <CheckBox x:Name="ChkShowInstalled" Content="Installed" Foreground="{DynamicResource cardForeground}" Margin="10,0,0,0" VerticalAlignment="Center"/>
                            <TextBlock x:Name="LabelPkgMgr" Text="Package Manager" FontWeight="SemiBold" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="12,0,8,0"/>
                            <RadioButton x:Name="PkgWinGet" Content="WinGet" Foreground="{DynamicResource accentColor}" FontWeight="Bold" IsChecked="True" GroupName="PkgMgr" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <RadioButton x:Name="PkgChoco" Content="Choco" Foreground="{DynamicResource cardForeground}" FontWeight="SemiBold" GroupName="PkgMgr" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                    <Border x:Name="PkgSelectionBorder" Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="0" CornerRadius="8" Padding="16" Margin="0,0,0,15">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Orientation="Horizontal" Grid.Column="0">
                                <Button x:Name="BtnInstall" Content="Install / Upgrade" Style="{StaticResource ActionBtn}" Width="120"/>
                                <Button x:Name="BtnUninstall" Content="Uninstall" Style="{StaticResource DangerBtn}" Width="110"/>
                                <Button x:Name="BtnSelectAll" Content="Select All" Style="{StaticResource SecondaryBtn}" Width="110"/>
                                <Button x:Name="BtnClearSelection" Content="Clear" Style="{StaticResource SecondaryBtn}" Width="90"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Grid.Column="1">
                                <Button x:Name="BtnCollapseAll" Content="Collapse All Categories" Style="{StaticResource SecondaryBtn}" Width="180"/>
                                <Button x:Name="BtnExpandAll" Content="Expand All Categories" Style="{StaticResource SecondaryBtn}" Width="180"/>
                                <TextBlock x:Name="LblSelectedCount" Text="Selected Apps: 0" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="10,0,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="AppPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="AppPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="AppPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageTweaks" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleTweaks" Text="System Tweaks" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescTweaks" Text="Select tweaks to apply. You can undo them later." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="TweaksPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="TweaksPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="TweaksPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                    <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                        <Button x:Name="BtnRunTweaks" Content="Apply Selected Tweaks" Style="{StaticResource ActionBtn}"/>
                        <Button x:Name="BtnUndoTweaks" Content="Undo All Tweaks" Style="{StaticResource DangerBtn}"/>
                    </StackPanel>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageFeatures" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleFeatures" Text="Features &amp; Fixes" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescFeatures" Text="Enable Windows features and run system fixes." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <TextBlock x:Name="FeaturesSectionHeader" Text="Windows Features" Style="{StaticResource CategoryHeader}" Margin="0,0,0,10"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="FeaturesPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="FeaturesPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="FeaturesPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                    <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                        <Button x:Name="BtnRunFeatures" Content="Run Features" Style="{StaticResource ActionBtn}"/>
                    </StackPanel>
                    <TextBlock x:Name="FixesSectionHeader" Text="Fixes" Style="{StaticResource CategoryHeader}" Margin="0,25,0,10"/>
                    <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="0" CornerRadius="8" Padding="16">
                        <WrapPanel x:Name="FixesWrapPanel"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PagePreferences" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitlePreferences" Text="Preferences" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescPreferences" Text="Toggle Windows settings and behavior preferences." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="PrefsPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="PrefsPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="PrefsPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageLegacy" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleLegacy" Text="Legacy Windows Panels" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescLegacy" Text="Quick access to classic Windows control panels and system tools." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="LegacyPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="LegacyPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="LegacyPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageSettings" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleSettings" Text="Settings" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescSettings" Text="Customize appearance and preferences." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>

                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" CornerRadius="8" Padding="16" Margin="0,0,7.5,15">
                            <StackPanel>
                                <TextBlock Text="DNS" Style="{StaticResource CategoryHeader}" Margin="0,0,0,10"/>
                                <StackPanel x:Name="DnsRadioPanel" Margin="4,0"/>
                                <Button x:Name="BtnApplyDns" Content="Apply DNS" Style="{StaticResource ActionBtn}" HorizontalAlignment="Left" Width="160" Margin="0,10,0,0"/>
                            </StackPanel>
                        </Border>
                        <StackPanel Grid.Column="1">
                            <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" CornerRadius="8" Padding="16" Margin="7.5,0,7.5,15">
                                <StackPanel>
                                    <TextBlock Text="Utilities" Style="{StaticResource CategoryHeader}" Margin="0,0,0,10"/>
                                    <Button x:Name="BtnCreateShortcut" Content="Create Desktop Shortcut" Style="{StaticResource ActionBtn}" HorizontalAlignment="Left" Width="220"/>
                                    <Button x:Name="BtnTerminalDotfiles" Content="Install Nova Profile" Style="{StaticResource ActionBtn}" HorizontalAlignment="Left" Width="220"/>
                                    <Button x:Name="BtnUninstallTerminal" Content="Uninstall Nova Profile" Style="{StaticResource DangerBtn}" HorizontalAlignment="Left" Width="220"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                </StackPanel>
            </ScrollViewer>
            <Border x:Name="ProgressOverlay" Background="#80000000" CornerRadius="0" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Visibility="Collapsed">
                <StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <TextBlock x:Name="ProgressText" Text="Installing..." FontSize="18" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center"/>
                    <ProgressBar x:Name="ProgressBar" Width="320" Height="22" Margin="0,15,0,0"/>
                    <TextBlock x:Name="ProgressSubText" Text="" FontSize="12" Foreground="#CCFFFFFF" HorizontalAlignment="Center" Margin="0,8,0,0"/>
                </StackPanel>
            </Border>
        </Grid>

        <Border x:Name="StatusBar" Grid.Row="2" Background="{DynamicResource windowBackground}" BorderBrush="{DynamicResource headerBorder}" BorderThickness="0,1,0,0" Height="26">
            <TextBlock x:Name="StatusText" Text="Ready" Foreground="{DynamicResource textMuted}" FontSize="11" Padding="8,4"/>
        </Border>
    </Grid>
</Window>

'@
if ($Verbose) { $script:logLevel = "Info" }
$script:appRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Show-HksUtilLogo
Write-Log "Starting HksUtil v$script:hksVersion..." "Header"

if ($Export) {
    $sel = @{ CheckedApps = @(); CheckedTweaks = @() }
    try {
        $selJson = $sel | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($Export, $selJson, [System.Text.UTF8Encoding]::new($false))
        Write-Log "Exported to $Export" "Success"
    } catch { Write-Log "Export failed: $_" "Error" }
}

if ($NoUI) {
    if ($Config -and $Apply) {
        Write-Log "NoUI mode: applying config..." "Header"
        try {
            if ($Config -match "^https?://") { $importJson = Invoke-WebRequest -Uri $Config -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json }
            else { $importJson = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json }
            if ($importJson.AppSelections) {
                    Ensure-PackageManager "winget" | Out-Null
                    foreach ($id in $importJson.AppSelections) {
                        Write-Log "Headless install: $id" "Info"
                        winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
                    }
                }
            Write-Log "Headless apply complete." "Success"
        } catch { Write-Log "Headless apply failed: $_" "Error" }
    } else { Write-Log "NoUI mode: use -Config <path> -Apply to apply." "Warn" }
    pause; exit
}

try {
    $xamlContent = $script:embeddedXaml -replace 'x:Name', 'Name'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }

$controls = @{}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { $controls[$_.Name] = $window.FindName($_.Name) }
foreach ($k in @($controls.Keys)) { if (-not $controls[$k]) { $controls.Remove($k) } }

Apply-Theme "dark"
if ($controls["TitleText"]) { $controls["TitleText"].Add_MouseLeftButtonDown({ $window.DragMove() }) }

. "$script:appRoot\modules\navigation.ps1"
. "$script:appRoot\modules\tweaks.ps1"
. "$script:appRoot\modules\search.ps1"
. "$script:appRoot\modules\toolbar.ps1"
. "$script:appRoot\modules\dns.ps1"
. "$script:appRoot\modules\terminal.ps1"
. "$script:appRoot\modules\utility.ps1"
. "$script:appRoot\modules\build.ps1"
. "$script:appRoot\modules\install.ps1"
. "$script:appRoot\modules\features.ps1"

if ($controls["BtnClearSearch"]) { $controls["BtnClearSearch"].Add_Click({ if ($controls["SearchBox"]) { $controls["SearchBox"].Text = ""; $controls["SearchBox"].Focus() } }) }
if ($controls["BtnSelectAll"]) { $controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" }) }
if ($controls["BtnClearSelection"]) { $controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" }) }
if ($controls["BtnCollapseAll"]) {
    $controls["BtnCollapseAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $true; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Collapsed" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($controls["BtnExpandAll"]) {
    $controls["BtnExpandAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Visible" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($controls["ChkShowInstalled"]) {
    $controls["ChkShowInstalled"].Add_Checked({ Write-Log "Filtering to installed apps..." "Info"; if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }; Apply-Filters })
    $controls["ChkShowInstalled"].Add_Unchecked({ Apply-Filters })
}

Switch-Page "Install"
Set-Status "Ready"
Update-InstalledCache
Write-Log "GUI Loaded. Waiting for input..." "Success"

if ($Config -and -not $Apply) {
    Write-Log "Loading config: $Config" "Header"
    try {
        if ($Config -match "^https?://") { $importJson = Invoke-WebRequest -Uri $Config -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json }
        elseif (Test-Path $Config) { $importJson = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json }
        else { Write-Log "Config path not found: $Config" "Warn"; $importJson = $null }
        if ($importJson) {
            if ($importJson.AppSelections) { foreach ($cb in $appCheckboxes) { $cb.IsChecked = @($importJson.AppSelections) -contains $cb.Tag } }
            if ($importJson.PreferenceStates) { foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) { if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $importJson.PreferenceStates.$pk -eq $true } } }
            Update-SelectedCount; Write-Log "Config loaded from $Config" "Success"
        }
    } catch { Write-Log "Config load failed: $_" "Error" }
}

try { $window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"
