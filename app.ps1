<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : development — run .\scripts\Combine.ps1 to build hksutil.ps1
#>

# Manual arg parsing (no param() — supports irm | iex)
$Config = $null; $Noui = $false; $Apply = $false; $Verbose = $false
$i = 0
while ($i -lt $args.Count) {
    $a = $args[$i]
    if ($a -like '-*') {
        $name = $a.TrimStart('-')
        if ($name -eq 'Config') { $i++; $Config = $args[$i] }
        elseif ($name -eq 'Noui') { $Noui = $true }
        elseif ($name -eq 'Apply') { $Apply = $true }
        elseif ($name -eq 'Verbose') { $Verbose = $true }
        else { Write-Host "Unknown argument: $a"; exit 1 }
    }
    $i++
}

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
    if ($Config) { $cv = $Config.Replace("'", "''"); $argList += "-Config '$cv'" }
    if ($Noui) { $argList += "-Noui" }
    if ($Apply) { $argList += "-Apply" }
    if ($Verbose) { $argList += "-Verbose" }
    $scriptCmd = if ($PSCommandPath) {
        "& { & '$PSCommandPath' $($argList -join ' ') }"
    } else { "& { . ([scriptblock]::Create((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/hartkitsak/HksUtil/main/hksutil.ps1' -UseBasicParsing).Content)) }" }
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }
    try {
        if ($processCmd -eq "wt.exe") {
            Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
        } else {
            Start-Process $powershellCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
        }
    } catch { Write-Host "Elevation cancelled or failed: $_" }
    exit
}

$sync = [Hashtable]::Synchronized(@{})
$sync.version = ""
$sync.build = ""
$sync.noUI = $Noui
$sync.configs = @{}
$sync.ProcessRunning = $false

$sync.controls = @{}
$sync.logLevel = if ($Verbose) { "Info" } else { "Success" }
$script:appRoot = $PSScriptRoot

. "$PSScriptRoot\src\modules\logger.ps1"
. "$PSScriptRoot\src\modules\dialog.ps1"
. "$PSScriptRoot\src\modules\core.ps1"
. "$PSScriptRoot\src\modules\theme.ps1"

# Load non-UI modules early for NoUI mode compatibility
. "$PSScriptRoot\src\modules\install.ps1"

$configPath = Join-Path $PSScriptRoot "src\config"
Write-Log "Loading configs..." "Info"

$configFiles = @{meta = @{}; themes = @{}; apps = @{}; dns = @{}; preferences = @{}; cleaner = @{}; legacy = @() }
foreach ($key in $configFiles.Keys) {
    $file = Join-Path $configPath "$key.json"
    try { $sync.configs[$key] = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs[$key] = $configFiles[$key]; Write-Log "$key.json failed: $_" "Warn" }
}
if ($sync.configs.meta) {
    if ($sync.configs.meta.version) { $sync.version = $sync.configs.meta.version }
    if ($sync.configs.meta.build) { $sync.build = $sync.configs.meta.build }
}
Write-Log "Config files loaded." "Success"

Show-HksUtilLogo

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
                    if ($LASTEXITCODE -ne 0) { Write-Log "Headless install failed: $id (exit $LASTEXITCODE)" "Error" }
                }
            }

            if ($importJson.CleanerSelections) {
                foreach ($ck in $importJson.CleanerSelections) {
                    $cleaner = $null
                    foreach ($g in $sync.configs.cleaner.PSObject.Properties.Name) {
                        if ($sync.configs.cleaner.$g.PSObject.Properties.Name -contains $ck) { $cleaner = $sync.configs.cleaner.$g.$ck; break }
                    }
                    if ($cleaner -and $cleaner.script) { Write-Log "Headless cleaner: $($cleaner.content)" "Info"; & ([scriptblock]::Create($cleaner.script)) }
                }
            }

            if ($importJson.PreferenceStates) {
                foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) {
                    $pref = $sync.configs.preferences.$pk
                    if (-not $pref) { continue }
                    $entries = if ($importJson.PreferenceStates.$pk) { $pref.registry_on } else { $pref.registry_off }
                    foreach ($reg in $entries) {
                        Set-RegistryValue -Path $reg.path -Name $reg.name -Value $reg.value
                    }
                    Write-Log "Headless pref: $($pref.content) = $($importJson.PreferenceStates.$pk)" "Info"
                }
            }

            Write-Log "Headless apply complete." "Success"
        } catch { Write-Log "Headless apply failed: $_" "Error" }
    } else { Write-Log "NoUI mode: use -Config <path> -Apply." "Warn" }
    pause; exit
}

try {
    $xamlPath = Join-Path $PSScriptRoot "src\ui.xaml"
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

$buildSuffix = if ($sync.build) { " (build $($sync.build))" } else { "" }
$sync.window.Title = "HksUtil v$($sync.version)$buildSuffix - Windows Optimizer"
if ($sync.controls["TitleVersionText"]) { $sync.controls["TitleVersionText"].Text = "v$($sync.version)$buildSuffix" }
Apply-Theme "light"
if ($sync.controls["TitleText"]) { $sync.controls["TitleText"].Add_MouseLeftButtonDown({ $sync.window.DragMove() }) }

Update-InstalledCache
. "$PSScriptRoot\src\modules\navigation.ps1"
. "$PSScriptRoot\src\modules\search.ps1"
. "$PSScriptRoot\src\modules\toolbar.ps1"
. "$PSScriptRoot\src\modules\dns.ps1"
. "$PSScriptRoot\src\modules\utility.ps1"
. "$PSScriptRoot\src\modules\build.ps1"
. "$PSScriptRoot\src\modules\status.ps1"
. "$PSScriptRoot\src\modules\cleaner.ps1"
Register-InstallEvents

if ($sync.controls["BtnSelectAll"]) { $sync.controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" }) }
if ($sync.controls["BtnClearSelection"]) { $sync.controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" }) }
if ($sync.controls["BtnCleanerSelectAll"]) { $sync.controls["BtnCleanerSelectAll"].Add_Click({ foreach ($cb in $cleanerCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Write-Log "All visible cleaner items selected." "Info" }) }
if ($sync.controls["BtnCleanerClearSelection"]) { $sync.controls["BtnCleanerClearSelection"].Add_Click({ foreach ($cb in $cleanerCheckboxes) { $cb.IsChecked = $false }; Write-Log "Cleaner selection cleared." "Info" }) }
if ($sync.controls["BtnCollapseAll"]) {
    $sync.controls["BtnCollapseAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) {
            $script:categoryCollapsed[$cat] = $true
            if ($script:categoryGrids[$cat]) { $script:categoryGrids[$cat].Visibility = "Collapsed" }
        }
        foreach ($panel in @($sync.controls["AppPanel"])) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($sync.controls["BtnExpandAll"]) {
    $sync.controls["BtnExpandAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) {
            $script:categoryCollapsed[$cat] = $false
            if ($script:categoryGrids[$cat]) { $script:categoryGrids[$cat].Visibility = "Visible" }
        }
        foreach ($panel in @($sync.controls["AppPanel"])) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
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

Update-AppBadges
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
            if ($importJson.CleanerSelections) { foreach ($cb in $cleanerCheckboxes) { $cb.IsChecked = @($importJson.CleanerSelections) -contains $cb.Tag } }
            if ($importJson.PreferenceStates) { foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) { if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $importJson.PreferenceStates.$pk -eq $true } } }
            Update-SelectedCount; Write-Log "Config loaded from $Config" "Success"
        }
    } catch { Write-Log "Config load failed: $_" "Error" }
}

$sync.window.Add_Closing({
    [System.GC]::Collect()
})

try { $sync.window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"
