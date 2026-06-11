$ErrorActionPreference = "Stop"
$file = "D:\dev-setup\HksUtil\hksutil.ps1"

Write-Host "=== 1. Syntax Check ===" -ForegroundColor Cyan
$null = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    Write-Host "SYNTAX ERRORS FOUND: $($errors.Count)" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  Line $($e.Token.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Red }
} else {
    Write-Host "  No syntax errors." -ForegroundColor Green
}

Write-Host "`n=== 2. Dual-mode checks ===" -ForegroundColor Cyan
$configMode = Select-String -Path $file -Pattern 'if \(\$script:embeddedConfigs\)' -SimpleMatch
$xamlMode = Select-String -Path $file -Pattern 'if \(\$script:embeddedXaml\)' -SimpleMatch
$devConfig = Select-String -Path $file -Pattern 'Join-Path \$PSScriptRoot "src\\config"' -SimpleMatch
$devXaml = Select-String -Path $file -Pattern 'Join-Path \$PSScriptRoot "src\\ui.xaml"' -SimpleMatch

if ($configMode) { Write-Host "  embeddedConfigs dual-mode: OK (line $($configMode.LineNumber))" -ForegroundColor Green }
if ($xamlMode) { Write-Host "  embeddedXaml dual-mode: OK (line $($xamlMode.LineNumber))" -ForegroundColor Green }
if ($devConfig) { Write-Host "  dev fallback config: OK (line $($devConfig.LineNumber))" -ForegroundColor Green }
if ($devXaml) { Write-Host "  dev fallback XAML: OK (line $($devXaml.LineNumber))" -ForegroundColor Green }

Write-Host "`n=== 3. No dot-source module lines ===" -ForegroundColor Cyan
$moduleSources = Select-String -Path $file -Pattern '\$PSScriptRoot\\src\\modules' -SimpleMatch
if ($moduleSources) {
    Write-Host "  WARNING: Found $($moduleSources.Count) module references:" -ForegroundColor Yellow
    $moduleSources | ForEach-Object { Write-Host "    Line $_" -ForegroundColor Yellow }
} else {
    Write-Host "  All module dot-source lines removed: OK" -ForegroundColor Green
}

Write-Host "`n=== 4. Restore point CIM method ===" -ForegroundColor Cyan
$restorePoint = Select-String -Path $file -Pattern 'CreateRestorePoint' -SimpleMatch
if ($restorePoint) {
    Write-Host "  CreateRestorePoint found: OK (line $($restorePoint.LineNumber))" -ForegroundColor Green
} else {
    Write-Host "  CreateRestorePoint NOT found!" -ForegroundColor Red
}

Write-Host "`n=== 5. Module count ===" -ForegroundColor Cyan
$preCount = (Select-String -Path $file -Pattern '# ============ \w+\.ps1 ============' -SimpleMatch).Count
Write-Host "  Total modules inlined: $preCount" -ForegroundColor Green

Write-Host "`n=== 6. File info ===" -ForegroundColor Cyan
$fi = Get-Item $file
Write-Host "  Size: $($fi.Length / 1KB) KB"
Write-Host "  Lines: $((Get-Content $file).Count)"

Write-Host "`n=== 7. Embedded XAML check ===" -ForegroundColor Cyan
$startXaml = Select-String -Path $file -Pattern '^\$script:embeddedXaml =' -SimpleMatch
$endXaml = Select-String -Path $file -Pattern "^'@$" -SimpleMatch
if ($startXaml) { Write-Host "  XAML start: line $($startXaml.LineNumber)" }
if ($endXaml) { Write-Host "  XAML end: line $($endXaml.LineNumber)" }

Write-Host "`n=== ALL CHECKS COMPLETE ===" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
