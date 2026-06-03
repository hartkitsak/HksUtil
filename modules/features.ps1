if ($controls["BtnRunFeatures"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Features") {
    $controls["BtnRunFeatures"].Add_Click({
        $selected = $featuresCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No features selected." "Warn"; return }
        if (-not (Show-Confirm "Run Features" "Apply $($selected.Count) selected feature(s)?")) { return }
        Write-Log "Running Selected Features..." "Header"
        Set-Status "Running $($selected.Count) feature(s)..."
        foreach ($cb in $selected) {
            $featKey = $cb.Tag
            $feat = $featuresConfig.Features.$featKey
            if (-not $feat) { continue }
            Write-Log "Running: $($feat.content)" "Info"
            try { Invoke-Expression $feat.script; Write-Log "Feature completed: $($feat.content)" "Success" } catch { Write-Log "Feature failed: $($feat.content): $_" "Error" }
        }
        Set-Status "Ready"
        Show-Info "Features Complete" "$($selected.Count) feature(s) applied."
        Write-Log "All selected features completed." "Header"
    })
}
