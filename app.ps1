param(
    [string]$Config,
    [switch]$Noui,
    [switch]$Offline,
    [switch]$Apply,
    [string]$Export
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    write-host "HksUtil needs to be run as Administrator. Attempting to relaunch."
    $argList = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $argList += if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
        elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
        elseif ($null -ne $_.Value) { "-$($_.Key) '$($_.Value)'" }
    }
    $scriptCmd = if ($PSCommandPath) {
        "& { & '$PSCommandPath' $($argList -join ' ') }"
    } else {
        "& { & '$(Join-Path $PSScriptRoot app.ps1)' $($argList -join ' ') }"
    }
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    Start-Process $powershellCmd -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$scriptCmd`"" -Verb RunAs
    exit
}

$script:appRoot = $PSScriptRoot
$script:NoUI = $Noui

. "$PSScriptRoot\modules\logger.ps1"
. "$PSScriptRoot\modules\core.ps1"
. "$PSScriptRoot\modules\theme.ps1"

Show-HksUtilLogo

$configPath = Join-Path $PSScriptRoot "config"
Write-Log "Loading configs..." "Info"

try {
    $script:cfg = Get-Content (Join-Path $configPath "config.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:appsConfig = if ($script:cfg.apps) { $script:cfg.apps } else { @{} }
    $script:tweaksConfig = if ($script:cfg.tweaks) { $script:cfg.tweaks } else { @{} }
    $script:dnsConfig = if ($script:cfg.dns) { $script:cfg.dns } else { @{} }
    $script:prefsConfig = if ($script:cfg.preferences) { $script:cfg.preferences } else { @{} }
    $script:featuresConfig = if ($script:cfg.features) { $script:cfg.features } else { @{} }
    $script:themesConfig = if ($script:cfg.themes) { $script:cfg.themes } else { @{} }
    Write-Log "config.json loaded ($($script:cfg.PSObject.Properties.Name.Count) sections)" "Success"
} catch { Write-Log "config.json failed: $_" "Error"; $script:cfg = @{} }

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
    pause
    exit
}

try {
    $xamlPath = Join-Path $PSScriptRoot "xaml\ui.xaml"
    $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
    $xamlContent = $xamlContent -replace 'x:Name', 'Name'
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

. "$PSScriptRoot\modules\navigation.ps1"
. "$PSScriptRoot\modules\tweaks.ps1"
. "$PSScriptRoot\modules\search.ps1"
. "$PSScriptRoot\modules\toolbar.ps1"
. "$PSScriptRoot\modules\dns.ps1"
. "$PSScriptRoot\modules\terminal.ps1"
. "$PSScriptRoot\modules\utility.ps1"
. "$PSScriptRoot\modules\build.ps1"
. "$PSScriptRoot\modules\install.ps1"
. "$PSScriptRoot\modules\features.ps1"

if ($controls["BtnClearSearch"]) { $controls["BtnClearSearch"].Add_Click({ if ($controls["SearchBox"]) { $controls["SearchBox"].Text = ""; $controls["SearchBox"].Focus() } }) }
if ($controls["BtnSelectAll"]) { $controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" }) }
if ($controls["BtnClearSelection"]) { $controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" }) }
if ($controls["BtnCollapseAll"]) {
    $controls["BtnCollapseAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $true; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Collapsed" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
        Write-Log "All categories collapsed." "Info"
    })
}
if ($controls["BtnExpandAll"]) {
    $controls["BtnExpandAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Visible" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
        Write-Log "All categories expanded." "Info"
    })
}
if ($controls["ChkShowInstalled"]) {
    $controls["ChkShowInstalled"].Add_Checked({
        Write-Log "Filtering to installed apps..." "Info"
        if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }
        Apply-Filters
    })
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
