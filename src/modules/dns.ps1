$script:dnsNames = @()
$script:dnsRadioButtons = @{}

if ($sync.controls["DnsRadioPanel"] -and $sync.configs.dns) {
    $script:dnsNames = @($sync.configs.dns.PSObject.Properties.Name)
    $script:dnsRadioButtons = @{}
    $isFirst = $true
    foreach ($dnsName in $script:dnsNames) {
        $dns = $sync.configs.dns.$dnsName
        if (-not $dns) { continue }
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Tag = $dnsName; $rb.Style = Get-WpfResource "DnsCardStyle"; $rb.GroupName = "DnsProvider"
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"; $sp.VerticalAlignment = "Center"
        $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = "$dnsName - $($dns.description)"; $nameTb.FontSize = 12; $nameTb.FontWeight = "SemiBold"; $nameTb.VerticalAlignment = "Center"; $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor")
        $sp.Children.Add($nameTb) | Out-Null
        $ipTb = New-Object System.Windows.Controls.TextBlock; $ipDisplay = if ($dns.PSObject.Properties.Name -contains "ipv4" -and $dns.ipv4.Count -gt 0) { $dns.ipv4 -join ", " } else { "Auto (DHCP)" }; $ipTb.Text = "  $ipDisplay"; $ipTb.FontSize = 10; $ipTb.FontFamily = "Consolas"; $ipTb.VerticalAlignment = "Center"; $ipTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted")
        $sp.Children.Add($ipTb) | Out-Null
        $rb.Content = $sp
        $rb.Add_Checked({ Write-Log "DNS selected: $($this.Tag)" "Info" })
        $null = $sync.controls["DnsRadioPanel"].Children.Add($rb)
        $script:dnsRadioButtons[$dnsName] = $rb
        if ($isFirst) { $rb.IsChecked = $true; $isFirst = $false }
    }
    Write-Log "Built $($script:dnsNames.Count) DNS radio buttons." "Success"
}

if ($sync.controls["BtnApplyDns"]) {
    $sync.controls["BtnApplyDns"].Add_Click({
        $selectedRb = $script:dnsRadioButtons.Values | Where-Object { $_.IsChecked -eq $true } | Select-Object -First 1
        if (-not $selectedRb) { Write-Log "No DNS provider selected." "Warn"; return }
        $dnsName = $selectedRb.Tag
        $dns = $sync.configs.dns.$dnsName
        $ipv4 = if ($dns.PSObject.Properties.Name -contains "ipv4") { $dns.ipv4 } else { @() }
        Show-Progress -Text "Applying DNS..." -Value 0.3
        if ($dnsName -eq "Default_DHCP") {
            if (-not (Show-Confirm "Reset DNS" "Reset DNS to default DHCP on all adapters?")) { Hide-Progress; return }
            Write-Log "Resetting DNS to DHCP..." "Info"
            try {
                $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
                if (-not $adapters) { Write-Log "No active network adapter found." "Error"; Hide-Progress; return }
                foreach ($adapter in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses }
                Write-Log "DNS reset to DHCP on $($adapters.Count) adapter(s)." "Success"
                Hide-Progress; Show-Info "DNS Reset" "DNS has been reset to DHCP."
            } catch { Write-Log "Failed to reset DNS: $_" "Error"; Hide-Progress }
            return
        }
        if (-not (Show-Confirm "Apply DNS" "Set DNS to $dnsName?`n`nIPv4: $($ipv4 -join ', ')") ) { Hide-Progress; return }
        Write-Log "Setting DNS to $dnsName..." "Info"
        try {
            $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
            if (-not $adapters) { Write-Log "No active network adapter found." "Error"; Hide-Progress; return }
            $ipv6 = if ($dns.PSObject.Properties.Name -contains "ipv6") { $dns.ipv6 } else { @() }
            Show-Progress -Text "Applying $dnsName..." -Value 0.6
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ($ipv4 + $ipv6)
            }
            Write-Log "DNS set to $dnsName on $($adapters.Count) adapter(s)." "Success"
            Hide-Progress; Show-Info "DNS Applied" "DNS has been set to $dnsName.`n`nIPv4: $($ipv4 -join ', ')"
        } catch {
            Write-Log "Failed to set DNS: $_" "Error"
            try {
                $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
                if (-not $adapters) { Write-Log "No active adapter for netsh." "Error"; Hide-Progress; return }
                Show-Progress -Text "Retrying via netsh..." -Value 0.7
                foreach ($adapter in $adapters) {
                    $ifName = $adapter.Name
                    if ($ipv4.Count -gt 0) {
                        netsh interface ip set dns "$ifName" static $($ipv4[0])
                        for ($i = 1; $i -lt $ipv4.Count; $i++) { netsh interface ip add dns "$ifName" $($ipv4[$i]) index=$($i+1) }
                    }
                }
                Write-Log "DNS set via netsh fallback." "Success"
                Hide-Progress; Show-Info "DNS Applied" "DNS set via netsh.`n$dnsName ($($ipv4 -join ', '))"
            } catch { Write-Log "netsh fallback also failed: $_" "Error"; Hide-Progress }
        }
    })
}
