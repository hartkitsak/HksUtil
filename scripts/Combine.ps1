param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\hksutil.ps1")
)

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$modulesDir = Join-Path $root "src\modules"
$configDir = Join-Path $root "src\config"
$xamlPath = Join-Path $root "src\ui.xaml"
$appPath = Join-Path $root "app.ps1"

# ============================================================
# Helper: convert JSON object to PowerShell hashtable literal
# ============================================================
function ConvertTo-PSCode {
    param($Obj)
    if ($Obj -is [array]) {
        $items = $Obj | ForEach-Object { ConvertTo-PSCode $_ }
        return "@(" + ($items -join ',') + ")"
    } elseif ($Obj -is [System.Management.Automation.PSCustomObject]) {
        $pairs = $Obj.PSObject.Properties | ForEach-Object {
            $val = ConvertTo-PSCode $_.Value
            $key = $_.Name.Replace("'", "''")
            "'$key' = $val"
        }
        return "[PSCustomObject]@{" + ($pairs -join '; ') + "}"
    } elseif ($Obj -is [bool]) {
        if ($Obj) { return '$true' } else { return '$false' }
    } elseif ($Obj -is [int] -or $Obj -is [long] -or $Obj -is [double]) {
        return $Obj.ToString()
    } elseif ($Obj -is [string]) {
        return '"' + $Obj.Replace('"', '`"') + '"'
    } elseif ($null -eq $Obj) {
        return '$null'
    } else {
        return '"' + $Obj.ToString().Replace('"', '`"') + '"'
    }
}

# ============================================================
# Read and embed configs as hashtable literals
# ============================================================
Write-Host "Reading configs..."
$configKeys = @("meta", "themes", "apps", "dns", "preferences", "cleaner", "legacy")
$configLines = @()
foreach ($key in $configKeys) {
    $file = Join-Path $configDir "$key.json"
    $json = Get-Content $file -Raw -Encoding UTF8
    $obj = $json | ConvertFrom-Json
    $psCode = ConvertTo-PSCode $obj
    $configLines += "`$script:embeddedConfigs['$key'] = $psCode"
}
$configBlock = $configLines -join "`n"

# ============================================================
# Read and embed XAML (single-quoted here-string)
# ============================================================
Write-Host "Reading XAML..."
$xamlRaw = Get-Content $xamlPath -Raw -Encoding UTF8
$xamlBlock = @"
`$script:embeddedXaml = @'
$xamlRaw
'@
"@

# ============================================================
# Read module files in two groups
# ============================================================
$preXamlMods  = @("logger.ps1", "dialog.ps1", "core.ps1", "theme.ps1", "install.ps1")
$postXamlMods = @("navigation.ps1", "search.ps1", "toolbar.ps1", "dns.ps1", "utility.ps1", "build.ps1", "status.ps1", "cleaner.ps1")

function Read-Module($name) {
    $content = Get-Content (Join-Path $modulesDir $name) -Raw -Encoding UTF8
    return "`n# ============ $name ============`n$content"
}

Write-Host "Reading pre-XAML modules..."
$preXamlCode = ($preXamlMods | ForEach-Object { Write-Host "  + $_"; Read-Module $_ }) -join "`n"

Write-Host "Reading post-XAML modules..."
$postXamlCode = ($postXamlMods | ForEach-Object { Write-Host "  + $_"; Read-Module $_ }) -join "`n"

# ============================================================
# Get version
# ============================================================
$metaObj = (Get-Content (Join-Path $configDir "meta.json") -Raw -Encoding UTF8) | ConvertFrom-Json
$version = $metaObj.version

# ============================================================
# Process app.ps1: remove dot-source lines, add dual-mode blocks
# ============================================================
Write-Host "Processing app.ps1..."
$appLines = Get-Content $appPath -Encoding UTF8

# Remove all module dot-source lines
$filtered = @()
for ($i = 0; $i -lt $appLines.Count; $i++) {
    $n = $i + 1
    if ($appLines[$i] -match '^\.\s+"\$PSScriptRoot\\src\\modules\\.*"') { continue }
    $filtered += $appLines[$i]
}
$appCode = $filtered -join "`n"

# Replace config loading block with dual-mode
$oldConfig = @'
$configPath = Join-Path $PSScriptRoot "src\config"
Write-Log "Loading configs..." "Info"

$configFiles = @{meta = @{}; themes = @{}; apps = @{}; dns = @{}; preferences = @{}; cleaner = @{}; legacy = @() }
foreach ($key in $configFiles.Keys) {
    $file = Join-Path $configPath "$key.json"
    try { $sync.configs[$key] = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs[$key] = $configFiles[$key]; Write-Log "$key.json failed: $_" "Warn" }
}
'@

$newConfig = @'
if ($script:embeddedConfigs) {
    $sync.configs = $script:embeddedConfigs
} else {
    $configPath = Join-Path $PSScriptRoot "src\config"
    Write-Log "Loading configs..." "Info"
    $configFiles = @{meta = @{}; themes = @{}; apps = @{}; dns = @{}; preferences = @{}; cleaner = @{}; legacy = @() }
    foreach ($key in $configFiles.Keys) {
        $file = Join-Path $configPath "$key.json"
        try { $sync.configs[$key] = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs[$key] = $configFiles[$key]; Write-Log "$key.json failed: $_" "Warn" }
    }
}
'@
$appCode = $appCode.Replace($oldConfig, $newConfig)

# Replace XAML loading block with dual-mode
$oldXaml = @'
try {
    $xamlPath = Join-Path $PSScriptRoot "src\ui.xaml"
    $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
    $xamlContent = $xamlContent -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync.window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }
'@

$newXaml = @'
if ($script:embeddedXaml) {
    $xamlContent = $script:embeddedXaml -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync.window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} else {
    try {
        $xamlPath = Join-Path $PSScriptRoot "src\ui.xaml"
        $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
        $xamlContent = $xamlContent -replace 'x:Name="([^"]+)"', 'Name="$1"'
        [xml]$xaml = $xamlContent
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $sync.window = [Windows.Markup.XamlReader]::Load($reader)
        $reader.Close()
    } catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }
}
'@
$appCode = $appCode.Replace($oldXaml, $newXaml)

# ============================================================
# Split appCode into three parts at natural boundaries:
#   Part A:  param() through $script:appRoot = $PSScriptRoot
#   Part B:  Show-HksUtilLogo through Update-InstalledCache
#   Part C:  Register-InstallEvents through end
# Pre-XAML modules go into Part A's position (after appRoot).
# Post-XAML modules go into Part B's position (after Update-InstalledCache).
# ============================================================
# Find boundary markers
$marker1 = "Show-HksUtilLogo"
$marker2 = "Register-InstallEvents"

$pos1 = $appCode.IndexOf("`$script:appRoot = `$PSScriptRoot")
if ($pos1 -eq -1) { throw "Could not find `$script:appRoot = `$PSScriptRoot" }
$endA = $pos1 + "`$script:appRoot = `$PSScriptRoot".Length
# Find the newline after appRoot line to include it
$nlAfterRoot = $appCode.IndexOf("`n", $endA)
if ($nlAfterRoot -gt $endA) { $endA = $nlAfterRoot + 1 }

$appPartA = $appCode.Substring(0, $endA)
$remaining = $appCode.Substring($endA)

# Split remaining at Show-HksUtilLogo → everything before it is blank/config part that goes with pre-XAML
# Actually, split at Register-InstallEvents for part B vs C
$pos2 = $remaining.IndexOf("`n$marker2")
if ($pos2 -eq -1) { $pos2 = $remaining.IndexOf("$marker2`n") }
if ($pos2 -eq -1) { throw "Could not find $marker2" }

$appPartB = $remaining.Substring(0, $pos2 + 1)
$appPartC = $remaining.Substring($pos2 + 1)

# ============================================================
# Assemble final output
# ============================================================
Write-Host "Assembling $OutputPath ..."

$header = @"
<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : $version (combined build — do not edit directly; edit src/ sources)
#>

"@

# The param() block must be first in file, so Part A comes before embedded data.
# But embedded data ($script:embeddedConfigs, $script:embeddedXaml) are just variable
# assignments — they can go after param() and $sync setup.
$embeddedData = @"
`$script:embeddedConfigs = @{}
$configBlock

$xamlBlock
"@

$output = $header + @"

# ============ PARAMETERS & SETUP ============
$appPartA

# ============ EMBEDDED DATA ============
$embeddedData

# ============ PRE-XAML MODULES ============
$preXamlCode

# ============ CORE APP LOGIC ============
$appPartB

# ============ POST-XAML MODULES ============
$postXamlCode

# ============ APP FINALIZATION ============
$appPartC
"@

# Normalize line endings and write
$output = $output -replace "`r`n", "`n"
$null = New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent)
[System.IO.File]::WriteAllText($OutputPath, $output, [System.Text.UTF8Encoding]::new($true))

Write-Host "Done! Combined script: $OutputPath"
Write-Host "Size: $((Get-Item $OutputPath).Length / 1KB) KB"
