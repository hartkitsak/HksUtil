function Set-Status {
    param([string]$Text)
    if ($sync.controls["StatusText"]) { $sync.controls["StatusText"].Text = $Text }
}

function Update-SelectedCount {
    $appCount = ($appCheckboxes | Where-Object { $_.IsChecked -eq $true }).Count
    $cleanerCount = ($cleanerCheckboxes | Where-Object { $_.IsChecked -eq $true }).Count
    $currentTab = $sync.currentTab
    $label = switch ($currentTab) {
        "Install" { "Selected Apps: $appCount" }
        "Cleaner" { "Selected Items: $cleanerCount" }
        default { "Selected Apps: $appCount" }
    }
    if ($sync.controls["LblSelectedCount"]) { $sync.controls["LblSelectedCount"].Text = $label }
}
