param([switch]$Dev)

$repo = "https://github.com/hartkitsak/HksUtil.git"
$dir = "$env:USERPROFILE\HksUtil"

if ($Dev) { $dir = "$env:USERPROFILE\HksUtil-dev" }

if (-not (Test-Path $dir)) {
    git clone --depth 1 $repo $dir 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to clone repository." -ForegroundColor Red
        pause; exit
    }
} else {
    pushd $dir
    git pull 2>$null
    popd
}

& "$dir\app.ps1" @args
