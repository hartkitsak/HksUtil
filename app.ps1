# HksUtil v2.0 - Windows Optimizer (Sidebar Nav + Toggles + DNS + Features)
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Write-Log {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Type) {
        "Info"    { Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray; Write-Host $Message }
        "Success" { Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray; Write-Host "[OK] $Message" -ForegroundColor Green }
        "Error"   { Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray; Write-Host "[ERR] $Message" -ForegroundColor Red }
        "Warn"    { Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray; Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        "Header"  { Write-Host "`n[$timestamp] " -NoNewline -ForegroundColor DarkGray; Write-Host "=== $Message ===" -ForegroundColor Cyan }
    }
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

$script:installedAppIds = @{}
$script:currentTheme = "Dark"

function Set-Status {
    param([string]$Text)
    if ($controls["StatusText"]) { $controls["StatusText"].Text = $Text }
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
                if ($id -and $output -match [regex]::Escape($id)) {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch { Write-Log "Installed cache update failed: $_" "Warn" }
    Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Log "HksUtil v2.0 Starting..." "Header"

# --- Theme System ---
function Apply-Theme {
    param([string]$themeName)
    $themeFile = Join-Path $PSScriptRoot "themes\$themeName.xaml"
    if (-not (Test-Path $themeFile)) { Write-Log "Theme file not found: $themeFile" "Error"; return }
    try {
        [xml]$xml = Get-Content $themeFile -Raw
        $rd = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xml))
        $window.Resources.MergedDictionaries.Clear()
        $window.Resources.MergedDictionaries.Add($rd)
        $script:currentTheme = $themeName
        Write-Log "Theme applied: $themeName" "Success"
    } catch { Write-Log "Theme apply failed: $_" "Error" }
}

# Load UI
try {
    $xamlPath = Join-Path $PSScriptRoot "ui.xaml"
    $xamlContent = Get-Content $xamlPath -Raw
    $xamlContent = $xamlContent -replace 'x:Name', 'Name'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    Apply-Theme "Dark"
} catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }

$controls = @{}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { $controls[$_.Name] = $window.FindName($_.Name) }

# Window drag on title
$controls["TitleText"].Add_MouseLeftButtonDown({ $window.DragMove() })

# Load Configs
$configPath = Join-Path $PSScriptRoot "config"
Write-Log "Loading configs..." "Info"

try { $appsConfig = Get-Content (Join-Path $configPath "apps.json") -Raw | ConvertFrom-Json; Write-Log "apps.json ($($appsConfig.PSObject.Properties.Name.Count) categories)" "Success" } catch { Write-Log "apps.json failed: $_" "Error"; $appsConfig = @{} }
try { $tweaksConfig = Get-Content (Join-Path $configPath "tweaks.json") -Raw | ConvertFrom-Json; Write-Log "tweaks.json ($($tweaksConfig.PSObject.Properties.Name.Count) groups)" "Success" } catch { Write-Log "tweaks.json failed: $_" "Error"; $tweaksConfig = @{} }

try { $dnsConfig = Get-Content (Join-Path $configPath "dns.json") -Raw | ConvertFrom-Json; Write-Log "dns.json ($($dnsConfig.PSObject.Properties.Name.Count) providers)" "Success" } catch { Write-Log "dns.json failed: $_" "Error"; $dnsConfig = @{} }
try { $prefsConfig = Get-Content (Join-Path $configPath "preferences.json") -Raw | ConvertFrom-Json; Write-Log "preferences.json ($($prefsConfig.PSObject.Properties.Name.Count) preferences)" "Success" } catch { Write-Log "preferences.json failed: $_" "Error"; $prefsConfig = @{} }
try { $featuresConfig = Get-Content (Join-Path $configPath "features.json") -Raw | ConvertFrom-Json; Write-Log "features.json ($($featuresConfig.PSObject.Properties.Name.Count) sections)" "Success" } catch { Write-Log "features.json failed: $_" "Error"; $featuresConfig = @{} }

# --- Sidebar Navigation ---
$script:currentPage = "Install"
$pages = @{
    "Install" = $controls["PageInstall"]
    "Tweaks" = $controls["PageTweaks"]
    "Features" = $controls["PageFeatures"]
    "Preferences" = $controls["PagePreferences"]
    "Legacy" = $controls["PageLegacy"]
    "Settings" = $controls["PageSettings"]
}
$navButtons = @{
    "Install" = $controls["NavInstall"]
    "Tweaks" = $controls["NavTweaks"]
    "Features" = $controls["NavFeatures"]
    "Preferences" = $controls["NavPreferences"]
    "Legacy" = $controls["NavLegacy"]
    "Settings" = $controls["NavSettings"]
}

function Switch-Page {
    param([string]$pageName)
    if (-not $pages.ContainsKey($pageName)) { return }
    
    foreach ($key in $pages.Keys) {
        if ($pages[$key]) { $pages[$key].Visibility = if ($key -eq $pageName) { "Visible" } else { "Collapsed" } }
    }
    
    foreach ($key in $navButtons.Keys) {
        $btn = $navButtons[$key]
        if ($btn) {
            if ($key -eq $pageName) {
                $btn.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, "selectedBackground")
                $btn.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, "accentColor")
                $btn.FontWeight = "SemiBold"
            } else {
                $btn.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
                $btn.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, "textMuted")
                $btn.FontWeight = "Normal"
            }
        }
    }
    
    $script:currentPage = $pageName
    Write-Log "Switched to: $pageName" "Info"
}

foreach ($key in $navButtons.Keys) {
    $btn = $navButtons[$key]
    $btn.Tag = $key
    $btn.Add_Click({ Switch-Page $this.Tag })
}

# --- Toolbar Handlers ---
if ($controls["BtnToolbarTheme"]) {
    $controls["BtnToolbarTheme"].Add_Click({
        $newTheme = if ($script:currentTheme -eq "Dark") { "Light" } else { "Dark" }
        Apply-Theme $newTheme
    })
}

if ($controls["BtnToolbarClose"]) {
    $controls["BtnToolbarClose"].Add_Click({ $window.Close() })
}

if ($controls["GearPopup"]) {
    $controls["GearPopup"].Add_Closed({ $controls["BtnToolbarSettings"].IsChecked = $false })
}

if ($controls["BtnToolbarMinimize"]) {
    $controls["BtnToolbarMinimize"].Add_Click({ $window.WindowState = "Minimized" })
}

if ($controls["BtnToolbarMaximize"]) {
    $controls["BtnToolbarMaximize"].Add_Click({
        if ($window.WindowState -eq "Normal") {
            $window.WindowState = "Maximized"
            $controls["BtnToolbarMaximize"].Content = [char]0xE923
        } else {
            $window.WindowState = "Normal"
            $controls["BtnToolbarMaximize"].Content = [char]0xE922
        }
    })
}

# --- Gear Popup Handlers ---
if ($controls["BtnGearExport"]) {
    $controls["BtnGearExport"].Add_Click({
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.FileName = "HksUtil_Config.json"
        $dlg.DefaultExt = ".json"
        $dlg.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        if ($dlg.ShowDialog($window)) {
            $export = @{ AppSelections = @($appCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag }); PreferenceStates = @{} }
            foreach ($pk in $prefCheckboxes.Keys) { $export.PreferenceStates[$pk] = $prefCheckboxes[$pk].IsChecked }
            try { $export | ConvertTo-Json | Out-File $dlg.FileName -Encoding utf8; Write-Log "Config exported." "Success"; Show-Info "Export Complete" "Config saved." } catch { Write-Log "Export failed: $_" "Error"; Show-Info "Export Failed" $_ }
        }
    })
}

if ($controls["BtnGearImport"]) {
    $controls["BtnGearImport"].Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.DefaultExt = ".json"
        $dlg.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        if ($dlg.ShowDialog($window)) {
            try {
                $import = Get-Content $dlg.FileName -Raw | ConvertFrom-Json
                foreach ($cb in $appCheckboxes) { $cb.IsChecked = @($import.AppSelections) -contains $cb.Tag }
                if ($import.PreferenceStates) { foreach ($pk in $import.PreferenceStates.PSObject.Properties.Name) { if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = [bool]$import.PreferenceStates.$pk } } }
                Update-SelectedCount; Write-Log "Config imported." "Success"; Show-Info "Import Complete" "Config loaded."
            } catch { Write-Log "Import failed: $_" "Error"; Show-Info "Import Failed" $_ }
        }
    })
}

if ($controls["BtnGearAbout"]) { $controls["BtnGearAbout"].Add_Click({ Show-Info "About HksUtil" "HksUtil v2.0`nWindows Optimizer & Utility Tool`n`nBuilt with PowerShell + WPF" }) }
if ($controls["BtnGearDocs"]) { $controls["BtnGearDocs"].Add_Click({ Show-Info "Documentation" "Documentation available at the project repository." }) }
if ($controls["BtnGearSponsors"]) { $controls["BtnGearSponsors"].Add_Click({ Show-Info "Sponsors" "Support open-source development." }) }


# --- DNS ---
if ($controls["DnsRadioPanel"] -and $dnsConfig) {
    $script:dnsNames = @($dnsConfig.PSObject.Properties.Name)
    $script:dnsConfig = $dnsConfig
    $script:dnsRadioButtons = @{}
    $isFirst = $true
    foreach ($dnsName in $script:dnsNames) {
        $dns = $dnsConfig.$dnsName
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Tag = $dnsName
        $rb.Style = $window.FindResource("DnsCardStyle")
        $rb.GroupName = "DnsProvider"

        $sp = New-Object System.Windows.Controls.StackPanel
        $sp.Orientation = "Horizontal"
        $sp.VerticalAlignment = "Center"

        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.Text = "$dnsName - $($dns.description)"
        $nameTb.FontSize = 12
        $nameTb.FontWeight = "SemiBold"
        $nameTb.VerticalAlignment = "Center"
        $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor")
        $sp.Children.Add($nameTb) | Out-Null

        $ipTb = New-Object System.Windows.Controls.TextBlock
        $ipv4 = if ($dns.PSObject.Properties.Name -contains "ipv4") { $dns.ipv4 -join ", " } else { "" }
        $ipTb.Text = "  $ipv4"
        $ipTb.FontSize = 10
        $ipTb.FontFamily = "Consolas"
        $ipTb.VerticalAlignment = "Center"
        $ipTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted")
        $sp.Children.Add($ipTb) | Out-Null

        $rb.Content = $sp
        $rb.Add_Checked({
            Write-Log "DNS selected: $($this.Tag)" "Info"
        })

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
        $dns = $script:dnsConfig.$dnsName

        $ipv4 = if ($dns.PSObject.Properties.Name -contains "ipv4") { $dns.ipv4 } else { @() }
        if (-not (Show-Confirm "Apply DNS" "Set DNS to $dnsName?`n`nIPv4: $($ipv4 -join ', ')") ) { return }

        Write-Log "Setting DNS to $dnsName..." "Info"
        try {
            $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
            if (-not $adapter) { Write-Log "No active network adapter found." "Error"; return }
            $ifIndex = $adapter.ifIndex
            $ifName = $adapter.Name

            $ipv6 = if ($dns.PSObject.Properties.Name -contains "ipv6") { $dns.ipv6 } else { @() }

            Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses ($ipv4 + $ipv6)
            Write-Log "DNS set to $dnsName successfully." "Success"
            Show-Info "DNS Applied" "DNS has been set to $dnsName.`n`nIPv4: $($ipv4 -join ', ')"
        } catch {
            Write-Log "Failed to set DNS: $_" "Error"
            try {
                $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
                if (-not $adapter) { Write-Log "No active adapter for netsh." "Error"; return }
                $ifName = $adapter.Name
                netsh interface ip set dns "$ifName" static $($ipv4[0])
                for ($i = 1; $i -lt $ipv4.Count; $i++) { netsh interface ip add dns "$ifName" $($ipv4[$i]) index=$($i+1) }
                Write-Log "DNS set via netsh fallback." "Success"
                Show-Info "DNS Applied" "DNS set via netsh.`n$dnsName ($($ipv4 -join ', '))"
            } catch { Write-Log "netsh fallback also failed: $_" "Error" }
        }
    })
}

# --- Terminal Profile ---
function Invoke-TerminalAction {
    param([string]$Action)
    $url = if ($Action -eq "install") { "https://raw.githubusercontent.com/hartkitsak/Terminal-Dotfiles/master/install.ps1" } else { "https://raw.githubusercontent.com/hartkitsak/Terminal-Dotfiles/master/uninstall.ps1" }
    $cmd = "irm '$url' | iex"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
    $encoded = [Convert]::ToBase64String($bytes)
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -WindowStyle Hidden
}

if ($controls["BtnTerminalDotfiles"]) {
    $controls["BtnTerminalDotfiles"].Add_Click({
        Write-Log "Launching Terminal Dotfiles installer..." "Header"
        try { Invoke-TerminalAction "install"; Write-Log "Terminal Dotfiles installer launched." "Success" }
        catch { Write-Log "Terminal Dotfiles install failed: $_" "Error" }
    })
}

if ($controls["BtnUninstallTerminal"]) {
    $controls["BtnUninstallTerminal"].Add_Click({
        if (-not (Show-Confirm "Uninstall" "Uninstall Terminal Dotfiles? This will remove custom profiles and themes.")) { return }
        Write-Log "Launching Terminal Dotfiles uninstaller..." "Header"
        try { Invoke-TerminalAction "uninstall"; Write-Log "Terminal Dotfiles uninstaller launched." "Warn" }
        catch { Write-Log "Terminal Dotfiles uninstall failed: $_" "Error" }
    })
}

# --- Utility Buttons ---
$script:desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"

if ($controls["BtnCreateShortcut"]) {
    $controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = $script:desktopShortcutPath
        if (Test-Path $lnkPath) { Write-Log "Shortcut already exists." "Warn"; return }
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $shortcut.TargetPath = "powershell.exe"
            $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            $shortcut.WorkingDirectory = $PSScriptRoot
            $shortcut.Description = "HksUtil v2.0 - Windows Optimizer"
            $shortcut.Save()
            Write-Log "Desktop shortcut created." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
    })
}



if ($controls["BtnUninstallTerminal"]) {
    $controls["BtnUninstallTerminal"].Add_Click({
        if (-not (Show-Confirm "Uninstall" "Uninstall Terminal Dotfiles? This will remove custom profiles and themes.")) { return }
        Write-Log "Launching Terminal Dotfiles uninstaller..." "Header"
        try { Invoke-TerminalAction "uninstall"; Write-Log "Terminal Dotfiles uninstaller launched." "Warn" }
        catch { Write-Log "Terminal Dotfiles uninstall failed: $_" "Error" }
    })
}

function Invoke-TerminalAction {
    param([string]$Action)
    $url = if ($Action -eq "install") { "https://raw.githubusercontent.com/hartkitsak/Terminal-Dotfiles/master/install.ps1" } else { "https://raw.githubusercontent.com/hartkitsak/Terminal-Dotfiles/master/uninstall.ps1" }
    $cmd = "irm '$url' | iex"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
    $encoded = [Convert]::ToBase64String($bytes)
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -WindowStyle Normal
}

# --- Undo System (hashtable to prevent duplicates) ---
$script:tweakUndoLog = @{}

function Save-OriginalValues {
    param($tweakKey, $tweak)
    if ($script:tweakUndoLog.ContainsKey($tweakKey)) { return }
    
    $undoEntry = @{ Key = $tweakKey; Registry = @(); Services = @(); Scripts = @() }
    
    if ($tweak.PSObject.Properties.Name -contains "registry") {
        foreach ($reg in $tweak.registry) {
            $currentValue = $null
            if (Test-Path $reg.path) {
                try { $currentValue = (Get-ItemProperty $reg.path -Name $reg.name -ErrorAction SilentlyContinue).$($reg.name) } catch {}
            }
            $undoEntry.Registry += @{ Path = $reg.path; Name = $reg.name; OriginalValue = $currentValue; Type = $reg.type }
        }
    }
    
    if ($tweak.PSObject.Properties.Name -contains "services") {
        foreach ($svc in $tweak.services) {
            $currentStatus = $null; $currentStartup = $null
            try {
                $svcObj = Get-Service $svc.name -ErrorAction SilentlyContinue
                if ($svcObj) {
                    $currentStatus = $svcObj.Status
                    $currentStartup = (Get-CimInstance Win32_Service -Filter "Name='$($svc.name)'" -ErrorAction SilentlyContinue).StartMode
                }
            } catch {}
            $undoEntry.Services += @{ Name = $svc.name; OriginalStatus = $currentStatus; OriginalStartup = $currentStartup }
        }
    }
    
    if ($tweak.PSObject.Properties.Name -contains "undoScript") { $undoEntry.Scripts += $tweak.undoScript }
    $script:tweakUndoLog[$tweakKey] = $undoEntry
}

function Invoke-UndoTweaks {
    if ($script:tweakUndoLog.Count -eq 0) { Write-Log "No tweaks to undo." "Warn"; return }
    $tweakNames = $script:tweakUndoLog.Keys | ForEach-Object { $_.Replace("WPFTweaks", "") -replace "([a-z])([A-Z])", '$1 $2' }
    $msg = "Undo the following tweaks?`n`n" + ($tweakNames -join "`n")
    if (-not (Show-Confirm "Undo Tweaks" $msg)) { return }
    
    Write-Log "Undoing last tweaks..." "Header"
    foreach ($key in $script:tweakUndoLog.Keys) {
        $entry = $script:tweakUndoLog[$key]
        Write-Log "Undoing: $($entry.Key)" "Info"
        foreach ($svc in $entry.Services) {
            try {
                if ($svc.OriginalStartup -and $svc.OriginalStartup -ne "Disabled") { Set-Service $svc.Name -StartupType $svc.OriginalStartup -ErrorAction SilentlyContinue }
                if ($svc.OriginalStatus -and $svc.OriginalStatus -ne "Stopped") { Start-Service $svc.Name -ErrorAction SilentlyContinue }
                Write-Log "Service $($svc.Name) restored." "Success"
            } catch { Write-Log "Service undo failed: $_" "Error" }
        }
        foreach ($reg in $entry.Registry) {
            try {
                if (!(Test-Path $reg.Path)) { New-Item $reg.Path -Force | Out-Null }
                if ($null -ne $reg.OriginalValue) { Set-ItemProperty $reg.Path -Name $reg.Name -Value $reg.OriginalValue -Force }
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

# --- Build Apps UI ---
$appCheckboxes = @()
$appPanels = @()
$appPanelIndex = 0
$script:categoryItems = @{}
$script:categoryCollapsed = @{}
if (($controls["AppPanel1"] -and $controls["AppPanel2"] -and $controls["AppPanel3"]) -and $appsConfig) {
    $appPanels = @($controls["AppPanel1"], $controls["AppPanel2"], $controls["AppPanel3"])
    foreach ($category in $appsConfig.PSObject.Properties.Name) {
        $catCount = ($appsConfig.$category.PSObject.Properties.Name).Count
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = "- $($category.ToUpper()) ($catCount)"; $header.Style = $window.FindResource("CategoryHeader"); $header.Cursor = "Hand"
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
            $cb.Content = $app.content; $cb.Tag = $app.winget; $cb.Style = $window.FindResource("TweakCheckBox")
            if ($app.description) { $cb.ToolTip = "$($app.content)`n`n$($app.description)`n`nID: $($app.winget)" }
            $cb.Add_Checked({ Update-SelectedCount })
            $cb.Add_Unchecked({ Update-SelectedCount })
            $appPanels[$appPanelIndex].Children.Add($cb) | Out-Null
            $appCheckboxes += $cb
            $script:categoryItems[$category] += $cb
        }
        $appPanelIndex = ($appPanelIndex + 1) % 3
    }
    foreach ($cat in $script:categoryItems.Keys) {
        $script:categoryCollapsed[$cat] = $false
    }
    Write-Log "Built $($appCheckboxes.Count) app cards." "Success"
}

# --- Build Preferences UI ---
$prefCheckboxes = @{}
if ($controls["PrefsPanel1"] -and $controls["PrefsPanel2"] -and $controls["PrefsPanel3"] -and $prefsConfig) {
    $panels = @($controls["PrefsPanel1"], $controls["PrefsPanel2"], $controls["PrefsPanel3"])
    $panelIndex = 0
    foreach ($prefKey in $prefsConfig.PSObject.Properties.Name) {
        $pref = $prefsConfig.$prefKey
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $pref.content; $cb.Tag = $prefKey; $cb.Style = $window.FindResource("ToggleSwitch")
        if ($pref.description) { $cb.ToolTip = $pref.description }
        
        $currentState = $null
        if ($pref.PSObject.Properties.Name -contains "registry_on" -and $pref.registry_on.Count -gt 0) {
            $firstReg = $pref.registry_on[0]
            if (Test-Path $firstReg.path) {
                try { $currentState = (Get-ItemProperty $firstReg.path -Name $firstReg.name -ErrorAction SilentlyContinue).$($firstReg.name) } catch {}
            }
        }
        $cb.IsChecked = ($currentState -eq $pref.registry_on[0].value)
        
        $cb.Add_Checked({
            $pk = $this.Tag
            $p = $prefsConfig.$pk
            if ($p.PSObject.Properties.Name -contains "registry_on") {
                foreach ($r in $p.registry_on) {
                    try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Force } catch {}
                }
            }
            Write-Log "Pref ON: $($p.content)" "Success"
        })
        
        $cb.Add_Unchecked({
            $pk = $this.Tag
            $p = $prefsConfig.$pk
            if ($p.PSObject.Properties.Name -contains "registry_off") {
                foreach ($r in $p.registry_off) {
                    try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Force } catch {}
                }
            }
            Write-Log "Pref OFF: $($p.content)" "Warn"
        })
        
        $panels[$panelIndex].Children.Add($cb) | Out-Null
        $prefCheckboxes[$prefKey] = $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($prefCheckboxes.Count) preference toggles." "Success"
}

# --- Build Tweaks UI ---
$tweakCheckboxes = @()
$panelIndex = 0
if ($controls["TweaksPanel1"] -and $controls["TweaksPanel2"] -and $controls["TweaksPanel3"] -and $tweaksConfig) {
    $panels = @($controls["TweaksPanel1"], $controls["TweaksPanel2"], $controls["TweaksPanel3"])
    foreach ($groupKey in $tweaksConfig.PSObject.Properties.Name) {
        $group = $tweaksConfig.$groupKey
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = $groupKey; $header.FontSize = 16; $header.FontWeight = "Bold"
        $header.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "categoryHeaderColor")
        $header.Margin = "0,0,0,10"
        $panels[$panelIndex].Children.Add($header) | Out-Null
        
        foreach ($tweakKey in $group.PSObject.Properties.Name) {
            $tweak = $group.$tweakKey
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $tweak.content; $cb.Tag = $tweakKey; $cb.Style = $window.FindResource("TweakCheckBox")
            if ($tweak.description) { $cb.ToolTip = $tweak.description }
            $panels[$panelIndex].Children.Add($cb) | Out-Null
            $tweakCheckboxes += $cb
        }
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($tweakCheckboxes.Count) tweak checkboxes." "Success"
}

# --- Build Features & Fixes UI ---
$featuresCheckboxes = @()
if ($controls["FeaturesPanel1"] -and $controls["FeaturesPanel2"] -and $controls["FeaturesPanel3"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Features") {
    $panels = @($controls["FeaturesPanel1"], $controls["FeaturesPanel2"], $controls["FeaturesPanel3"])
    $panelIndex = 0
    $features = $featuresConfig.Features
    foreach ($featKey in $features.PSObject.Properties.Name) {
        $feat = $features.$featKey
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $feat.content; $cb.Tag = $featKey; $cb.Style = $window.FindResource("TweakCheckBox")
        if ($feat.description) { $cb.ToolTip = $feat.description }
        $panels[$panelIndex].Children.Add($cb) | Out-Null
        $featuresCheckboxes += $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($featuresCheckboxes.Count) feature checkboxes." "Success"
}
if ($controls["FixesWrapPanel"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Fixes") {
    $fixes = $featuresConfig.Fixes
    foreach ($fixKey in $fixes.PSObject.Properties.Name) {
        $fix = $fixes.$fixKey
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource("FeatureCard")
        $btn.Content = $fix.content
        $btn.ToolTip = $fix.description
        $btn.Tag = $fix
        $btn.Add_Click({
            $f = $this.Tag
            if (-not (Show-Confirm "Run Fix" "Execute: $($f.content)?")) { return }
            Write-Log "Running fix: $($f.content)" "Header"
            try { & ([scriptblock]::Create($f.script)); Write-Log "Fix completed: $($f.content)" "Success"; Show-Info "Fix Complete" "$($f.content)`n`nCompleted successfully." } catch { Write-Log "Fix failed: $_" "Error"; Show-Info "Fix Failed" "$($f.content)`n`nError: $_" }
        })
        $controls["FixesWrapPanel"].Children.Add($btn) | Out-Null
    }
    Write-Log "Built $($fixes.PSObject.Properties.Name.Count) fix buttons." "Success"
}

# --- Build Legacy Windows Panels UI ---
$legacyPanels = @(
    @{ Name = "Computer Management"; Desc = "Manage disks, services, event viewer, and more"; Command = "compmgmt.msc" },
    @{ Name = "Control Panel"; Desc = "Classic Windows Control Panel"; Command = "control" },
    @{ Name = "Network Connections"; Desc = "Manage network adapters and connections"; Command = "ncpa.cpl" },
    @{ Name = "Power Panel"; Desc = "Configure power plans and battery settings"; Command = "powercfg.cpl" },
    @{ Name = "Printer Panel"; Desc = "Manage printers and print queues"; Command = "printui" },
    @{ Name = "Region"; Desc = "Set regional format, language, and location"; Command = "intl.cpl" },
    @{ Name = "Sound Settings"; Desc = "Configure audio devices and sound effects"; Command = "mmsys.cpl" },
    @{ Name = "System Properties"; Desc = "View system info, performance, remote settings"; Command = "sysdm.cpl" },
    @{ Name = "Time and Date"; Desc = "Set date, time, and timezone"; Command = "timedate.cpl" },
    @{ Name = "Windows Restore"; Desc = "System Restore - create or restore restore points"; Command = "rstrui.exe" }
)

if ($controls["LegacyPanel1"] -and $controls["LegacyPanel2"] -and $controls["LegacyPanel3"]) {
    $panels = @($controls["LegacyPanel1"], $controls["LegacyPanel2"], $controls["LegacyPanel3"])
    $panelIndex = 0
    foreach ($panel in $legacyPanels) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource("FeatureCard")
        $btn.ToolTip = "$($panel.Name)`n$($panel.Desc)`n`nLaunch: $($panel.Command)"
        $btn.Tag = $panel.Command
        $btn.Width = 380

        $sp = New-Object System.Windows.Controls.StackPanel
        $sp.Orientation = "Horizontal"

        $textSp = New-Object System.Windows.Controls.StackPanel
        $textSp.Orientation = "Vertical"
        $textSp.VerticalAlignment = "Center"

        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.Text = $panel.Name
        $nameTb.FontSize = 13
        $nameTb.FontWeight = "SemiBold"
        $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor")
        $textSp.Children.Add($nameTb) | Out-Null

        $descTb = New-Object System.Windows.Controls.TextBlock
        $descTb.Text = $panel.Desc
        $descTb.FontSize = 11
        $descTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted")
        $descTb.TextWrapping = "Wrap"
        $descTb.MaxWidth = 280
        $textSp.Children.Add($descTb) | Out-Null

        $sp.Children.Add($textSp) | Out-Null
        $btn.Content = $sp

        $btn.Add_Click({
            $cmd = $this.Tag
            Write-Log "Launching: $cmd" "Info"
            try {
                Start-Process $cmd -ErrorAction Stop
                Write-Log "Launched: $cmd" "Success"
            } catch {
                Write-Log "Failed to launch ${cmd}: $_" "Error"
                Show-Info "Error" "Failed to launch $cmd`n`n$_"
            }
        })

        $panels[$panelIndex].Children.Add($btn) | Out-Null
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($legacyPanels.Count) legacy panel buttons." "Success"
}

# --- Filter Logic ---

function Apply-Filters {
    $searchText = $controls["SearchBox"].Text.ToLower()
    $showInstalledOnly = $controls["ChkShowInstalled"].IsChecked -eq $true
    $searchActive = -not [string]::IsNullOrWhiteSpace($searchText)
    foreach ($cb in $appCheckboxes) {
        $name = $cb.Content.ToString().ToLower().Trim()
        $id = $cb.Tag.ToLower()
        $matchesSearch = (-not $searchActive) -or $name.Contains($searchText) -or $id.Contains($searchText)
        $matchesInstalled = (-not $showInstalledOnly) -or $script:installedAppIds.ContainsKey($cb.Tag)
        $cb.Visibility = if ($matchesSearch -and $matchesInstalled) { "Visible" } else { "Collapsed" }
    }
    foreach ($panel in @($controls["AppPanel1"], $controls["AppPanel2"], $controls["AppPanel3"])) {
        $children = $panel.Children
        for ($i = 0; $i -lt $children.Count; $i++) {
            $child = $children[$i]
            if ($child -is [System.Windows.Controls.TextBlock]) {
                $hasVisible = $false
                for ($j = $i + 1; $j -lt $children.Count; $j++) {
                    $next = $children[$j]
                    if ($next -is [System.Windows.Controls.TextBlock]) { break }
                    if ($next -is [System.Windows.Controls.CheckBox] -and $next.Visibility -eq "Visible") { $hasVisible = $true; break }
                }
                $child.Visibility = if ($hasVisible) { "Visible" } else { "Collapsed" }
            }
        }
    }
}

$controls["SearchBox"].Add_TextChanged({
    $controls["SearchHint"].Visibility = if ([string]::IsNullOrWhiteSpace($controls["SearchBox"].Text)) { "Visible" } else { "Collapsed" }
    Apply-Filters
})

$controls["BtnClearSearch"].Add_Click({
    $controls["SearchBox"].Text = ""
    $controls["SearchBox"].Focus()
})

$controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" })

$script:pkgManager = "winget"
function Update-SelectedCount {
    $count = ($appCheckboxes | Where-Object { $_.IsChecked -eq $true }).Count
    if ($controls["LblSelectedCount"]) { $controls["LblSelectedCount"].Text = "Selected Apps: $count" }
}

$controls["PkgWinGet"].Add_Checked({ $script:pkgManager = "winget"; Write-Log "Package manager: WinGet" "Info" })
$controls["PkgChoco"].Add_Checked({ $script:pkgManager = "choco"; Write-Log "Package manager: Chocolatey" "Info" })

$controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" })
$controls["BtnCollapseAll"].Add_Click({
    foreach ($cat in $script:categoryItems.Keys) {
        $script:categoryCollapsed[$cat] = $true
        foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Collapsed" }
    }
    foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    Write-Log "All categories collapsed." "Info"
})
$controls["BtnExpandAll"].Add_Click({
    foreach ($cat in $script:categoryItems.Keys) {
        $script:categoryCollapsed[$cat] = $false
        foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Visible" }
    }
    foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    Write-Log "All categories expanded." "Info"
})

$controls["ChkShowInstalled"].Add_Checked({
    Write-Log "Filtering to installed apps..." "Info"
    if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }
    Apply-Filters
})
$controls["ChkShowInstalled"].Add_Unchecked({ Apply-Filters })

# --- Install/Uninstall ---
$controls["BtnInstall"].Add_Click({
    $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
    if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
    $pkg = $script:pkgManager
    if ($pkg -eq "choco" -and -not (Get-Command choco -ErrorAction SilentlyContinue)) { Show-Info "Chocolatey not found" "Chocolatey is not installed. Install it from https://chocolatey.org/install"; return }
    if (-not (Show-Confirm "Install Apps" "Install $($selected.Count) application(s) via $pkg?")) { return }
    Write-Log "Starting installation via $pkg..." "Header"
    Set-Status "Installing $($selected.Count) app(s) via $pkg..."
    foreach ($cb in $selected) {
        $id = $cb.Tag; Write-Log "Installing $id..." "Info"; Set-Status "Installing $id..."
        try {
            if ($pkg -eq "winget") { winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null }
            else { choco install $id -y 2>&1 | Out-Null }
            Write-Log "Done: $id" "Success"
        } catch { Write-Log "Failed: $id" "Error" }
    }
    Update-InstalledCache
    if ($controls["ChkShowInstalled"].IsChecked) { Apply-Filters }
    Set-Status "Ready"
    Show-Info "Installation Complete" "$($selected.Count) application(s) installed via $pkg."
    Write-Log "Installation complete." "Header"
})

$controls["BtnUninstall"].Add_Click({
    $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
    if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
    $pkg = $script:pkgManager
    if ($pkg -eq "choco" -and -not (Get-Command choco -ErrorAction SilentlyContinue)) { Show-Info "Chocolatey not found" "Chocolatey is not installed."; return }
    if (-not (Show-Confirm "Uninstall Apps" "Uninstall $($selected.Count) application(s) and deep clean leftovers via $pkg?`n`nThis cannot be undone!")) { return }
    Write-Log "Starting uninstallation via $pkg..." "Header"
    Set-Status "Uninstalling $($selected.Count) app(s) via $pkg..."
    foreach ($cb in $selected) {
        $id = $cb.Tag; Write-Log "Uninstalling $id..." "Info"; Set-Status "Uninstalling $id..."
        try {
            if ($pkg -eq "winget") { winget uninstall --id=$id --silent --purge --accept-source-agreements 2>&1 | Out-Null }
            else { choco uninstall $id -y 2>&1 | Out-Null }
            Write-Log "Done: $id" "Success"
        } catch { Write-Log "Failed: $id" "Error" }
        if ($pkg -eq "winget") {
            Write-Log "Deep Cleaning $id..." "Info"; Set-Status "Cleaning $id leftovers..."
            foreach ($term in ($id -split '\.') | Where-Object { $_.Length -gt 4 }) {
                foreach ($basePath in @($env:APPDATA, $env:LOCALAPPDATA, $env:PROGRAMDATA)) {
                    Get-ChildItem -Path $basePath -Directory -Filter "*$term*" -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force; Write-Log "Deleted: $($_.FullName)" "Success" } catch {} }
                }
                foreach ($regPath in @("HKCU:\Software", "HKLM:\SOFTWARE\WOW6432Node")) {
                    if (Test-Path $regPath) { Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $term } | ForEach-Object { try { Remove-Item $_.PSPath -Recurse -Force; Write-Log "Deleted Reg: $($_.Name)" "Success" } catch {} } }
                }
            }
        }
    }
    Update-InstalledCache
    if ($controls["ChkShowInstalled"].IsChecked) { Apply-Filters }
    Set-Status "Ready"
    Show-Info "Uninstall Complete" "$($selected.Count) application(s) uninstalled via $pkg."
    Write-Log "Uninstallation complete." "Header"
})

# --- Tweaks Execution ---
$controls["BtnRunTweaks"].Add_Click({
    $selected = $tweakCheckboxes | Where-Object { $_.IsChecked -eq $true }
    if ($selected.Count -eq 0) { Write-Log "No tweaks selected." "Warn"; return }
    if (-not (Show-Confirm "Run Tweaks" "Apply $($selected.Count) tweak(s)?`n`nYou can undo this later.")) { return }
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
                try { if (!(Test-Path $reg.path)) { New-Item $reg.path -Force | Out-Null }; Set-ItemProperty $reg.path -Name $reg.name -Value $reg.value -Force; Write-Log "Registry: $($reg.name) = $($reg.value)" "Success" } catch { Write-Log "Registry failed: $_" "Error" }
            }
        }
        if ($tweak.PSObject.Properties.Name -contains "appx_packages") {
            foreach ($pkg in $tweak.appx_packages) {
                try { Get-AppxPackage $pkg | Remove-AppxPackage -ErrorAction SilentlyContinue; Write-Log "Removed: $pkg" "Success" } catch { Write-Log "Skip: $pkg" "Warn" }
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

$controls["BtnUndoTweaks"].Add_Click({ Invoke-UndoTweaks })

# --- Features Execution ---
if ($controls["BtnRunFeatures"]) {
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
            try {
                Invoke-Expression $feat.script
                Write-Log "Feature completed: $($feat.content)" "Success"
            } catch { Write-Log "Feature failed: $($feat.content): $_" "Error" }
        }
        Set-Status "Ready"
        Show-Info "Features Complete" "$($selected.Count) feature(s) applied."
        Write-Log "All selected features completed." "Header"
    })
}

# --- Show default page ---
Switch-Page "Install"
Set-Status "Ready"
Update-InstalledCache
Write-Log "GUI Loaded. Waiting for input..." "Success"
try { $window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"
