$script:logFilePath = ""
$script:logBuffer = [System.Collections.Generic.List[hashtable]]::new()
$script:logMaxBuffer = 500
$script:logMaxFileSize = 5MB

$script:logLevels = @{
    Debug   = 0
    Info    = 1
    Success = 2
    Warn    = 3
    Error   = 4
    Fatal   = 5
    Header  = -1
    Cmd     = -1
}

$script:logColors = @{
    Debug   = 'DarkGray'
    Info    = 'DarkGray'
    Success = 'Green'
    Warn    = 'Yellow'
    Error   = 'Red'
    Fatal   = 'Red'
    Header  = 'Cyan'
    Cmd     = 'Cyan'
}

$script:logPrefix = @{
    Debug   = 'DEBUG'
    Info    = 'INFO'
    Success = 'OK'
    Warn    = 'WARN'
    Error   = 'FAIL'
    Fatal   = 'FATAL'
    Header  = ''
    Cmd     = '>'
}

function Show-HksUtilLogo {
    Write-Host @"
HH   HH KK   KK  SSSSSS  UU   UU TTTTTT IIIIII LL
HH   HH KK  KK  SS       UU   UU   TT     II   LL
HHHHHHH KKKKK    SSSSSS  UU   UU   TT     II   LL
HH   HH KK  KK       SS  UU   UU   TT     II   LL
HH   HH KK   KK  SSSSSS   UUUUU    TT   IIIIII LLLL
"@ -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
    Write-Host "    HksUtil v$($sync.version)" -ForegroundColor Cyan
    Write-Host "    Windows Optimizer" -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
}

function Initialize-Logger {
    $dir = Join-Path $env:TEMP "HksUtil"
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    $date = Get-Date -Format "yyyyMMdd"
    $script:logFilePath = Join-Path $dir "HksUtil-$date.log"
    if (Test-Path $script:logFilePath) {
        $file = Get-Item $script:logFilePath
        if ($file.Length -gt $script:logMaxFileSize) {
            $oldPath = [System.IO.Path]::ChangeExtension($script:logFilePath, ".old")
            Move-Item $script:logFilePath $oldPath -Force
        }
    }
    $msg = "Logger initialized: $($script:logFilePath)"
    $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffK")
    Add-Content -Path $script:logFilePath -Value "$timestamp [DEBUG] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Type = "Info")
    if (-not $script:logLevels.ContainsKey($Type)) { $Type = "Info" }
    $minLevel = if ($sync.ContainsKey('logLevel') -and $script:logLevels.ContainsKey($sync.logLevel)) { $script:logLevels[$sync.logLevel] } else { 1 }
    $currentLevel = $script:logLevels[$Type]
    if ($currentLevel -ge 0 -and $currentLevel -lt $minLevel) { return }
    $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffK")
    $prefix = $script:logPrefix[$Type]
    $color = $script:logColors[$Type]
    if ($Type -eq "Header") {
        Write-Host "`n  $Message" -ForegroundColor $color
    } else {
        Write-Host ("  {0,-5} {1}" -f $prefix, $Message) -ForegroundColor $color
    }
    try {
        $logLine = if ($Type -eq "Header") { "`n$timestamp === $Message ===" } else { "$timestamp [$($prefix.PadRight(5))] $Message" }
        Add-Content -Path $script:logFilePath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { Write-Host "  Log write failed: $_" -ForegroundColor Yellow }
    if ($script:logBuffer.Count -ge $script:logMaxBuffer) { $script:logBuffer.RemoveAt(0) }
    $script:logBuffer.Add(@{ Timestamp = $timestamp; Level = $Type; Message = $Message })
}

function Get-LogBuffer {
    param([string]$Level, [int]$Count = 50)
    $result = $script:logBuffer
    if ($Level) { $result = $result | Where-Object { $_.Level -eq $Level } }
    if ($result.Count -gt $Count) { $result = $result[-$Count..-1] }
    return $result
}

function Export-Logs {
    param([string]$Path)
    try {
        Copy-Item $script:logFilePath $Path -Force
        Write-Log "Logs exported to $Path" "Success"
    } catch { Write-Log "Log export failed: $_" "Error" }
}

function Clear-Log {
    try {
        if (Test-Path $script:logFilePath) { Remove-Item $script:logFilePath -Force }
        $script:logBuffer.Clear()
    } catch {}
}

Initialize-Logger
