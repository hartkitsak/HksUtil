if (-not $sync.ContainsKey('logLevel')) { $sync.logLevel = "Success" }

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
    if ($Type -eq "Info" -and $sync.logLevel -ne "Info") { return }
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
    if ($sync.controls["StatusText"]) { $sync.controls["StatusText"].Text = $Text }
}

function Update-SelectedCount {
    $count = ($appCheckboxes | Where-Object { $_.IsChecked -eq $true }).Count
    if ($sync.controls["LblSelectedCount"]) { $sync.controls["LblSelectedCount"].Text = "Selected Apps: $count" }
}
