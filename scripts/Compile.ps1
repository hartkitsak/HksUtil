<#
    Compile.ps1 — Compiles HksUtil functions, modules, config, and XAML into a single script.

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

# 2. Read all functions (public/private) in alphabetical order
$funcDir = Join-Path $root "functions"
if (Test-Path $funcDir) {
    Get-ChildItem "$funcDir\**\*.ps1" -Recurse | Sort-Object Name | ForEach-Object {
        $funcContent = Get-Content $_.FullName -Raw
        $funcName = $_.BaseName -replace '-','_'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($funcContent)
        $b64 = [Convert]::ToBase64String($bytes)
        $script.Add("`$script:__fn_$funcName = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$b64'))")
        $script.Add($funcContent)
    }
}

# 3. Read all modules in dependency order
$moduleOrder = @(
    "logger.ps1", "core.ps1", "theme.ps1",
    "navigation.ps1", "tweaks.ps1", "search.ps1",
    "toolbar.ps1", "dns.ps1", "terminal.ps1",
    "utility.ps1", "build.ps1", "install.ps1", "features.ps1"
)
foreach ($mod in $moduleOrder) {
    $modPath = Join-Path (Join-Path $root "modules") $mod
    if (Test-Path $modPath) {
        $modContent = Get-Content $modPath -Raw
        $modName = $mod -replace '\.ps1$',''
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($modContent)
        $b64 = [Convert]::ToBase64String($bytes)
        $script.Add("`$script:__mod_$modName = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$b64'))")
        $script.Add($modContent)
    }
}

# 4. Embed individual config files into $sync.configs
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
`$sync.configs.$key = @'
$cfgJson
'@ | ConvertFrom-Json
"@)
    } else {
        Write-Warning "config/$($configSections[$key]) not found."
    }
}

# 5. Embed xaml/ui.xaml
$xamlPath = Join-Path $root "xaml\ui.xaml"
if (Test-Path $xamlPath) {
    $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
    $script.Add(@"
`$script:embeddedXaml = @'
$xamlContent
'@
"@)
}

# 6. Append compiled main body
$script.Add(@'
if ($Verbose) { $sync.logLevel = "Info" }
$sync.appRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Show-HksUtilLogo
Write-Log "Starting HksUtil v$($sync.version)..." "Header"

if ($sync.noUI) {
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

            if ($importJson.TweakSelections) {
                foreach ($tk in $importJson.TweakSelections) {
                    $tweak = $null
                    foreach ($g in $sync.configs.tweaks.PSObject.Properties.Name) {
                        if ($sync.configs.tweaks.$g.PSObject.Properties.Name -contains $tk) { $tweak = $sync.configs.tweaks.$g.$tk; break }
                    }
                    if (-not $tweak) { continue }
                    Write-Log "Headless tweak: $($tweak.content)" "Info"
                    foreach ($svc in $tweak.services) {
                        if ($svc.action -eq "stop_disable") { Stop-Service $svc.name -Force -ErrorAction SilentlyContinue; Set-Service $svc.name -StartupType Disabled -ErrorAction SilentlyContinue }
                        if ($svc.action -eq "set_manual") { Set-Service $svc.name -StartupType Manual -ErrorAction SilentlyContinue }
                    }
                    foreach ($reg in $tweak.registry) {
                        if (!(Test-Path $reg.path)) { New-Item $reg.path -Force | Out-Null }
                        Set-ItemProperty $reg.path -Name $reg.name -Value $reg.value -Type $reg.type -Force
                    }
                    foreach ($pkg in $tweak.appx_packages) {
                        Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue | Remove-AppxPackage
                        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pkg } | Remove-AppxProvisionedPackage -Online
                    }
                    if ($tweak.script) { & ([scriptblock]::Create($tweak.script)) }
                }
            }

            if ($importJson.FeatureSelections) {
                foreach ($fk in $importJson.FeatureSelections) {
                    $feature = $null
                    foreach ($g in @("Features","Fixes")) {
                        if ($sync.configs.features.$g.PSObject.Properties.Name -contains $fk) { $feature = $sync.configs.features.$g.$fk; break }
                    }
                    if ($feature -and $feature.script) { Write-Log "Headless feature: $($feature.content)" "Info"; & ([scriptblock]::Create($feature.script)) }
                }
            }

            if ($importJson.PreferenceStates) {
                foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) {
                    $pref = $sync.configs.preferences.$pk
                    if (-not $pref) { continue }
                    $entries = if ($importJson.PreferenceStates.$pk) { $pref.registry_on } else { $pref.registry_off }
                    foreach ($reg in $entries) {
                        if (!(Test-Path $reg.path)) { New-Item $reg.path -Force | Out-Null }
                        Set-ItemProperty $reg.path -Name $reg.name -Value $reg.value
                    }
                    Write-Log "Headless pref: $($pref.content) = $($importJson.PreferenceStates.$pk)" "Info"
                }
            }

            Write-Log "Headless apply complete." "Success"
        } catch { Write-Log "Headless apply failed: $_" "Error" }
    } else { Write-Log "NoUI mode: use -Config <path> -Apply to apply." "Warn" }
    $sync.runspace.Close(); $sync.runspace.Dispose(); pause; exit
}

try {
    $xamlContent = $script:embeddedXaml -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync.window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }

$sync.controls = @{}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { $sync.controls[$_.Name] = $sync.window.FindName($_.Name) }
foreach ($k in @($sync.controls.Keys)) { if (-not $sync.controls[$k]) { $sync.controls.Remove($k) } }

Apply-Theme "dark"
if ($sync.controls["TitleText"]) { $sync.controls["TitleText"].Add_MouseLeftButtonDown({ $sync.window.DragMove() }) }

# Re-execute modules with populated controls
$script:__modOrder = @("logger","core","theme","navigation","tweaks","search","toolbar","dns","terminal","utility","build","install","features")
foreach ($_m in $script:__modOrder) {
    $_var = "__mod_$_m"
    $_code = Get-Variable $_var -ValueOnly -ErrorAction SilentlyContinue
    if ($_code) { . ([ScriptBlock]::Create($_code)) }
}

if ($sync.controls["BtnClearSearch"]) { $sync.controls["BtnClearSearch"].Add_Click({ if ($sync.controls["SearchBox"]) { $sync.controls["SearchBox"].Text = ""; $sync.controls["SearchBox"].Focus() } }) }
if ($sync.controls["BtnSelectAll"]) { $sync.controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" }) }
if ($sync.controls["BtnClearSelection"]) { $sync.controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" }) }
if ($sync.controls["BtnCollapseAll"]) {
    $sync.controls["BtnCollapseAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $true; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Collapsed" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($sync.controls["BtnExpandAll"]) {
    $sync.controls["BtnExpandAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Visible" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($sync.controls["ChkShowInstalled"]) {
    $sync.controls["ChkShowInstalled"].Add_Checked({ Write-Log "Filtering to installed apps..." "Info"; if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }; Apply-Filters })
    $sync.controls["ChkShowInstalled"].Add_Unchecked({ Apply-Filters })
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

$sync.window.Add_Closing({
    $sync.runspace.Close()
    $sync.runspace.Dispose()
    [System.GC]::Collect()
})

try { $sync.window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"
'@)

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outputPath, ($script -join "`r`n"), $utf8NoBom)
Write-Host "Compiled -> $outputPath (v$version)" -ForegroundColor Green

if ($Run) {
    & $outputPath
}
