$script:currentTheme = "light"

function Apply-Theme {
    param($ThemeName)
    $key = $ThemeName.ToLower()
    if (-not $sync.configs.themes -or -not $sync.configs.themes.$key) {
        Write-Log "Theme '$ThemeName' not found in themes config." "Warn"
        return
    }
    try {
        $colors = $sync.configs.themes.$key
        $converter = [System.Windows.Media.BrushConverter]::new()
        $newDict = New-Object System.Windows.ResourceDictionary

        foreach ($prop in $colors.PSObject.Properties.Name) {
            if ($prop -eq "__HksUtilTheme__") { continue }
            $brush = $converter.ConvertFrom($colors.$prop)
            if (-not $brush) { Write-Log "Invalid theme color: '$prop' = '$($colors.$prop)'" "Warn"; continue }
            $newDict.Add($prop, $brush)
        }
        $newDict.Add("__HksUtilTheme__", $true)
        if ($converter -and $converter.GetType().GetMethod('Dispose')) { $converter.Dispose() }

        $script:currentTheme = $ThemeName
        Write-Log "Theme: $ThemeName" "Success"

        if ([System.Windows.Application]::Current) {
            $appResources = [System.Windows.Application]::Current.Resources
            $existingTheme = @($appResources.MergedDictionaries | Where-Object { $_.Source -eq $null -and $_.Contains("__HksUtilTheme__") })
            foreach ($dict in $existingTheme) { $appResources.MergedDictionaries.Remove($dict) }
            $appResources.MergedDictionaries.Add($newDict)
        } elseif ($sync.window) {
            $existingTheme = @($sync.window.Resources.MergedDictionaries | Where-Object { $_.Source -eq $null })
            foreach ($dict in $existingTheme) { $sync.window.Resources.MergedDictionaries.Remove($dict) }
            $sync.window.Resources.MergedDictionaries.Add($newDict)
        }

        if ($sync.window -and $colors.windowBackground) {
            $sync.window.Background = $converter.ConvertFrom($colors.windowBackground)
        }
    } catch { Write-Log "Theme apply failed: $_" "Error" }
}
