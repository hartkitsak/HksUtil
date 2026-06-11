Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$file = "D:\dev-setup\HksUtil\hksutil.ps1"

Write-Host "=== 1. ParseFile Syntax Check ===" -ForegroundColor Cyan
$tokens = $null; $errors = $null
try {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        Write-Host "Parse errors: $($errors.Count)" -ForegroundColor Yellow
        foreach ($e in $errors) {
            $line = $e.Token.Extent.StartLineNumber
            $col = $e.Token.Extent.StartColumnNumber
            $msg = $e.Message -replace '\s+', ' '
            if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) + "..." }
            Write-Host "  L$line`:$col $msg" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  No parse errors!" -ForegroundColor Green
    }
    Write-Host "  AST: $($ast.EndBlock.Statements.Count) top-level statements, $($tokens.Count) tokens" -ForegroundColor Gray
}
catch { Write-Host "  Parser threw: $_" -ForegroundColor Red }

Write-Host "`n=== 2. Script block compilation test ===" -ForegroundColor Cyan
try {
    $null = [ScriptBlock]::Create((Get-Content $file -Raw -Encoding UTF8))
    Write-Host "  ScriptBlock created successfully!" -ForegroundColor Green
} catch { Write-Host "  ScriptBlock creation failed: $_" -ForegroundColor Red }

Write-Host "`n=== 3. Dual-mode keywords ===" -ForegroundColor Cyan
foreach ($kw in @('embeddedConfigs)', 'embeddedXaml)', 'Register-InstallEvents', 'CreateRestorePoint')) {
    $m = Select-String -Path $file -Pattern $kw -SimpleMatch
    if ($m) { Write-Host "  $kw found (lines: $($m.LineNumber))" -ForegroundColor Green }
    else { Write-Host "  $kw NOT found!" -ForegroundColor Red }
}

Write-Host "`n=== 4. Module dot-source check ===" -ForegroundColor Cyan
$sources = Select-String -Path $file -Pattern '$PSScriptRoot\src\modules' -SimpleMatch
if ($sources) { Write-Host "  WARNING: $($sources.Count) module refs remain!" -ForegroundColor Red }
else { Write-Host "  All module refs removed: OK" -ForegroundColor Green }

Write-Host "`n=== 5. Section markers ===" -ForegroundColor Cyan
$sections = Select-String -Path $file -Pattern '# ============' -SimpleMatch
Write-Host "  Sections: $($sections.Count)" -ForegroundColor Green
$sections | ForEach-Object { Write-Host "    $($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Gray }

Write-Host "`n=== 6. Embedded XAML ===" -ForegroundColor Cyan
if ((Select-String -Path $file -Pattern 'embeddedXaml' -SimpleMatch -CaseSensitive)) {
    $xamlStart = Select-String -Path $file -Pattern "^`$script:embeddedXaml = @" -SimpleMatch
    $xamlEnd = Select-String -Path $file -Pattern "^'@$" -SimpleMatch
    if ($xamlStart) { Write-Host "  XAML start: line $($xamlStart.LineNumber)" -ForegroundColor Green }
    if ($xamlEnd) { Write-Host "  XAML end: line $($xamlEnd.LineNumber)" -ForegroundColor Green }
}

Write-Host "`n=== 7. File info ===" -ForegroundColor Cyan
$fi = Get-Item $file
$lines = (Get-Content $file).Count
Write-Host "  Size: $([math]::Round($fi.Length / 1KB)) KB / $lines lines" -ForegroundColor White

Write-Host "`n=== DONE ===" -ForegroundColor Green
