$url = "https://raw.githubusercontent.com/hartkitsak/HksUtil/main/hksutil.ps1"
$out = Join-Path $env:TEMP "hksutil.ps1"
try {
    Write-Host "Downloading HksUtil..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    Write-Host "Running HksUtil..." -ForegroundColor Cyan
    & $out @args
} catch { Write-Host "Failed to download/run HksUtil: $_" -ForegroundColor Red; pause; exit }
