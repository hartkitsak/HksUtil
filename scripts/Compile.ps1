<#
    Compile.ps1 — Compiles HksUtil modules, config, and XAML into a single script.

    Usage:
        .\scripts\Compile.ps1          # Produces hksutil.ps1 in repo root
        .\scripts\Compile.ps1 -Run     # Compile and launch
#>

param([switch]$Run)

$OFS = "`r`n"
$root = Split-Path $PSScriptRoot -Parent

$outputPath = Join-Path $root "hksutil.ps1"
$script = [System.Collections.Generic.List[string]]::new()

# 1. Read start.ps1 header (with version placeholder)
$header = Get-Content (Join-Path $PSScriptRoot "start.ps1") -Raw
$version = Get-Date -Format 'yy.MM.dd'
$header = $header -replace '#{replaceme}', $version
$script.Add($header)

$script.Add('$controls = @{}')

# 2. Read all modules in dependency order
$moduleOrder = @(
    "logger.ps1", "core.ps1", "theme.ps1",
    "navigation.ps1", "tweaks.ps1", "search.ps1",
    "toolbar.ps1", "dns.ps1", "terminal.ps1",
    "utility.ps1", "build.ps1", "install.ps1", "features.ps1"
)
foreach ($mod in $moduleOrder) {
    $modPath = Join-Path (Join-Path $root "modules") $mod
    if (Test-Path $modPath) {
        $script.Add((Get-Content $modPath -Raw))
    }
}

# 3. Embed individual config files
$configSections = @{
    "meta"        = "meta.json"
    "themes"      = "themes.json"
    "apps"        = "apps.json"
    "tweaks"      = "tweaks.json"
    "dns"         = "dns.json"
    "preferences" = "preferences.json"
    "features"    = "features.json"
}
$configBase = Join-Path $root "config"
foreach ($key in $configSections.Keys) {
    $cfgPath = Join-Path $configBase $configSections[$key]
    if (Test-Path $cfgPath) {
        $cfgJson = Get-Content $cfgPath -Raw -Encoding UTF8
        $script.Add(@"
`$script:embedded_$key = @'
$cfgJson
'@ | ConvertFrom-Json
"@)
    } else {
        Write-Warning "config/$($configSections[$key]) not found."
    }
}
$script.Add(@"
`$script:metaConfig = if (`$script:embedded_meta) { `$script:embedded_meta } else { @{} }
`$script:appsConfig = if (`$script:embedded_apps) { `$script:embedded_apps } else { @{} }
`$script:tweaksConfig = if (`$script:embedded_tweaks) { `$script:embedded_tweaks } else { @{} }
`$script:dnsConfig = if (`$script:embedded_dns) { `$script:embedded_dns } else { @{} }
`$script:prefsConfig = if (`$script:embedded_preferences) { `$script:embedded_preferences } else { @{} }
`$script:featuresConfig = if (`$script:embedded_features) { `$script:embedded_features } else { @{} }
`$script:themesConfig = if (`$script:embedded_themes) { `$script:embedded_themes } else { @{} }
"@)

# 4. Embed xaml/ui.xaml
$xamlPath = Join-Path $root "xaml\ui.xaml"
if (Test-Path $xamlPath) {
    $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
    $script.Add(@"
`$script:embeddedXaml = @'
$xamlContent
'@
"@)
} else {
    Write-Warning "xaml/ui.xaml not found."
}

# 5. Append compiled main body
$script.Add(@'
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
    $xamlContent = $script:embeddedXaml -replace 'x:Name="([^"]+)"', 'Name="$1"'
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
'@)

Set-Content -Path $outputPath -Value $script -Encoding UTF8
Write-Host "Compiled -> $outputPath (v$version)" -ForegroundColor Green

if ($Run) {
    & $outputPath
}
