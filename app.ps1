<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : development — run .\scripts\Compile.ps1 to build hksutil.ps1
#>

param(
    [string]$Config,
    [switch]$Noui,
    [switch]$Offline,
    [switch]$Apply,
    [string]$Export,
    [switch]$Verbose
)

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host "HksUtil requires FullLanguage mode. Current: $($ExecutionContext.SessionState.LanguageMode)" -ForegroundColor Red
    pause; exit
}

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
        elseif ($null -ne $_.Value) { "-$($_.Key) '$($_.Value)'" }
    }
    $scriptCmd = if ($PSCommandPath) {
        "& { & '$PSCommandPath' $($argList -join ' ') }"
    } else {
        "& { & '$(Join-Path $PSScriptRoot app.ps1)' $($argList -join ' ') }"
    }
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }
    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
    } else {
        Start-Process $powershellCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
    }
    exit
}

$sync = [Hashtable]::Synchronized(@{})
$sync.version = Get-Date -Format 'yy.MM.dd'
$sync.noUI = $Noui
$sync.configs = @{}
$sync.controls = @{}
$sync.ProcessRunning = $false
$sync.selectedApps = [System.Collections.Generic.List[string]]::new()
$sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
$sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()

$maxthreads = [int]$env:NUMBER_OF_PROCESSORS
$hashVars = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'sync', $sync, $null
$initialState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$initialState.Variables.Add($hashVars)
$sync.runspace = [runspacefactory]::CreateRunspacePool(1, $maxthreads, $initialState, $Host)
$sync.runspace.Open()

$script:logLevel = "Success"
if ($Verbose) { $script:logLevel = "Info" }
$script:appRoot = $PSScriptRoot

. "$PSScriptRoot\modules\logger.ps1"
. "$PSScriptRoot\modules\core.ps1"
. "$PSScriptRoot\modules\theme.ps1"

Show-HksUtilLogo

$configPath = Join-Path $PSScriptRoot "config"
Write-Log "Loading configs..." "Info"

try { $sync.configs.themes = Get-Content (Join-Path $configPath "themes.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs.themes = @{}; Write-Log "themes.json failed: $_" "Warn" }
try { $sync.configs.apps = Get-Content (Join-Path $configPath "apps.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs.apps = @{}; Write-Log "apps.json failed: $_" "Warn" }
try { $sync.configs.tweaks = Get-Content (Join-Path $configPath "tweaks.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs.tweaks = @{}; Write-Log "tweaks.json failed: $_" "Warn" }
try { $sync.configs.dns = Get-Content (Join-Path $configPath "dns.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs.dns = @{}; Write-Log "dns.json failed: $_" "Warn" }
try { $sync.configs.preferences = Get-Content (Join-Path $configPath "preferences.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs.preferences = @{}; Write-Log "preferences.json failed: $_" "Warn" }
try { $sync.configs.features = Get-Content (Join-Path $configPath "features.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs.features = @{}; Write-Log "features.json failed: $_" "Warn" }
Write-Log "Config files loaded." "Success"

if ($Export) {
    $sel = @{ CheckedApps = @(); CheckedTweaks = @() }
    try {
        $selJson = $sel | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($Export, $selJson, [System.Text.UTF8Encoding]::new($false))
        Write-Log "Exported to $Export" "Success"
    } catch { Write-Log "Export failed: $_" "Error" }
}

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
            Write-Log "Headless apply complete." "Success"
        } catch { Write-Log "Headless apply failed: $_" "Error" }
    } else { Write-Log "NoUI mode: use -Config <path> -Apply to apply." "Warn" }
    $sync.runspace.Dispose(); $sync.runspace.Close()
    pause; exit
}

try {
    $xamlPath = Join-Path $PSScriptRoot "xaml\ui.xaml"
    $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
    $xamlContent = $xamlContent -replace 'x:Name="([^"]+)"', 'Name="$1"'
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
    $sync.controls["ChkShowInstalled"].Add_Checked({
        Write-Log "Filtering to installed apps..." "Info"
        if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }
        Apply-Filters
    })
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
            if ($importJson.CheckedApps) { foreach ($appEntry in $importJson.CheckedApps) { $cb = $appCheckboxes | Where-Object { $_.Tag -eq $appEntry.Name }; if ($cb) { $cb.IsChecked = $true } } }
            if ($importJson.TweakSelections) { foreach ($cb in $tweakCheckboxes) { $cb.IsChecked = @($importJson.TweakSelections) -contains $cb.Tag } }
            if ($importJson.CheckedTweaks) { foreach ($tweakEntry in $importJson.CheckedTweaks) { $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tweakEntry.Name }; if ($cb) { $cb.IsChecked = $true } } }
            if ($importJson.FeatureSelections) { foreach ($cb in $featuresCheckboxes) { $cb.IsChecked = @($importJson.FeatureSelections) -contains $cb.Tag } }
            if ($importJson.PreferenceStates) { foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) { if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $importJson.PreferenceStates.$pk -eq $true } } }
            Update-SelectedCount; Write-Log "Config loaded from $Config" "Success"
        }
    } catch { Write-Log "Config load failed: $_" "Error" }
}

$sync.window.Add_Closing({
    $sync.runspace.Dispose()
    $sync.runspace.Close()
    [System.GC]::Collect()
})

try { $sync.window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"
