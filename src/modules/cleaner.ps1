if ($sync.controls["BtnRunCleaner"] -and $sync.configs.cleaner) {
    $sync.controls["BtnRunCleaner"].Add_Click({
        $selected = $cleanerCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No cleaner items selected." "Warn"; return }
        if ($sync.ProcessRunning) { Write-Log "Operation already in progress." "Warn"; return }
        $itemNames = $selected | ForEach-Object { $_.Content.ToString() }
        $itemList = ($itemNames | ForEach-Object { "• $_" }) -join "`n"
        if (-not (Show-Confirm "Run Cleaner" "Execute $($selected.Count) selected cleanup item(s)?`n`n$itemList")) { return }
        $sync.ProcessRunning = $true
        try {
            Write-Log "Running Selected Cleaner Items..." "Header"; Set-Status "Cleaning..."
            Show-Progress -Text "Cleaning..." -SubText "0 / $($selected.Count)" -Value 0
            $count = 0; $successCount = 0; $failCount = 0; $failedItems = @()
            foreach ($cb in $selected) {
                $ck = $cb.Tag; $cleaner = $null
                foreach ($g in $sync.configs.cleaner.PSObject.Properties.Name) {
                    if ($sync.configs.cleaner.$g.PSObject.Properties.Name -contains $ck) { $cleaner = $sync.configs.cleaner.$g.$ck; break }
                }
                if (-not $cleaner) { continue }
                $count++
                $pct = [math]::Max(0.01, [math]::Round($count / $selected.Count, 2))
                Show-Progress -Text "Running: $($cleaner.content)..." -SubText "$count / $($selected.Count)" -Value $pct
                Write-Log "($count/$($selected.Count)) $($cleaner.content)" "Info"
                try { & ([scriptblock]::Create($cleaner.script)); $successCount++; Write-Log "Cleaned: $($cleaner.content)" "Success" } catch { $failCount++; $failedItems += "$($cleaner.content): $_"; Write-Log "Failed: $($cleaner.content): $_" "Error" }
            }
            if ($failCount -gt 0) { Show-Info "Cleaner Complete" "$successCount succeeded, $failCount failed.`n`n$($failedItems -join "`n")" } else { Show-Info "Cleaner Complete" "All $successCount item(s) completed successfully." }
            Write-Log "Cleaner: $successCount success, $failCount failed." "Header"
        } catch { Write-Log "Cleaner error: $_" "Error" } finally { Hide-Progress; $sync.ProcessRunning = $false; Set-Status "Ready" }
    })
}
