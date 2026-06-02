$script:currentTheme = "dark"

function Apply-Theme { param($n); Set-Theme $n }

function Set-Theme {
    param($ThemeName)
    $key = $ThemeName.ToLower()
    if (-not $script:themesConfig -or -not $script:themesConfig.$key) {
        Write-Log "Theme '$ThemeName' not found in themes config." "Warn"
        return
    }
    try {
        $colors = $script:themesConfig.$key
        $converter = [System.Windows.Media.BrushConverter]::new()
        $newDict = New-Object System.Windows.ResourceDictionary

        foreach ($prop in $colors.PSObject.Properties.Name) {
            $brush = $converter.ConvertFrom($colors.$prop)
            $newDict.Add($prop, $brush)
        }

        $script:currentTheme = $ThemeName
        Write-Log "Theme: $ThemeName" "Success"

        if ([System.Windows.Application]::Current) {
            $appResources = [System.Windows.Application]::Current.Resources
            $existingTheme = @($appResources.MergedDictionaries | Where-Object { $_.Source -eq $null -and $_.Count -gt 0 -and -not $_.Contains("ToolBarButtonBaseStyle") })
            foreach ($dict in $existingTheme) { $appResources.MergedDictionaries.Remove($dict) }
            $appResources.MergedDictionaries.Add($newDict)
        } elseif ($window) {
            $existingTheme = @($window.Resources.MergedDictionaries | Where-Object { $_.Source -eq $null })
            foreach ($dict in $existingTheme) { $window.Resources.MergedDictionaries.Remove($dict) }
            $window.Resources.MergedDictionaries.Add($newDict)
        }

        if ($window -and $colors.windowBackground) {
            $window.Background = $converter.ConvertFrom($colors.windowBackground)
        }
    } catch { Write-Log "Theme apply failed: $_" "Error" }
}
