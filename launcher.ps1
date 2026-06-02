# HksUtil Launcher
#   irm "https://raw.githubusercontent.com/hartkitsak/HksUtil/main/launcher.ps1" | iex
#   .\launcher.ps1
#   .\launcher.ps1 -Config .\config.json -Apply

param(
    [string]$Config,
    [switch]$Noui,
    [switch]$Offline,
    [switch]$Apply,
    [string]$Export
)

$tmp = "$env:TEMP\HksUtil"
if (-not $Offline) {
    Write-Host "Downloading HksUtil..." -ForegroundColor Cyan
    $base = "https://raw.githubusercontent.com/hartkitsak/HksUtil/main"

    @(
        @{dir=""; file="app.ps1"},
        @{dir="xaml"; file="ui.xaml"},
        @{dir="config"; file="config.json"}
    ) | ForEach-Object {
        $d = Join-Path $tmp $_.dir
        if (-not (Test-Path $d)) { New-Item $d -ItemType Directory -Force | Out-Null }
        iwr -Uri "$base/$($_.dir)/$($_.file)" -OutFile (Join-Path $d $_.file)
    }

    $modules = "logger","core","theme","navigation","tweaks","search","toolbar","dns","terminal","utility","build","install","features"
    $modDir = Join-Path $tmp "modules"
    if (-not (Test-Path $modDir)) { New-Item $modDir -ItemType Directory -Force | Out-Null }
    foreach ($m in $modules) {
        iwr -Uri "$base/modules/$m.ps1" -OutFile (Join-Path $modDir "$m.ps1")
    }
}

$argList = @()
if ($Config) { $argList += "-Config '$Config'" }
if ($Noui) { $argList += "-Noui" }
if ($Apply) { $argList += "-Apply" }
if ($Export) { $argList += "-Export '$Export'" }

Write-Host "Starting HksUtil v2.0..." -ForegroundColor Cyan
& (Join-Path $tmp "app.ps1") @argList
