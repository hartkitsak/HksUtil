$script:pkgManager = "winget"

function Ensure-PackageManager {
    param([string]$Pkg)
    if (Get-Command $Pkg -ErrorAction SilentlyContinue) { return $true }
    Write-Log "$Pkg not found. Installing..." "Info"
    try {
        if ($Pkg -eq "winget") {
            $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            $out = "$env:TEMP\AppInstaller.msixbundle"
            Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
            Add-AppxPackage -Path $out -ErrorAction Stop
            Remove-Item $out -Force -ErrorAction SilentlyContinue
        } elseif ($Pkg -eq "choco") {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        }
        if (Get-Command $Pkg -ErrorAction SilentlyContinue) { Write-Log "$Pkg installed." "Success"; return $true }
        Write-Log "$Pkg install completed but command not found." "Warn"; return $false
    } catch { Write-Log "$Pkg install failed: $_" "Error"; return $false }
}

if ($controls["BtnInstall"]) {
    $controls["BtnInstall"].Add_Click({
        $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
        $pkg = $script:pkgManager
        if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
        if (-not (Show-Confirm "Install Apps" "Install $($selected.Count) application(s) via $pkg?")) { return }
        Write-Log "Starting installation via $pkg..." "Header"
        Set-Status "Installing $($selected.Count) app(s) via $pkg..."
        Show-Progress -Text "Preparing installation..." -Value 0.05
        $count = 0
        foreach ($cb in $selected) {
            $id = $cb.Tag; $count++
            $percent = [math]::Max(0.05, [math]::Min(0.95, ($count / $selected.Count) * 0.9))
            Write-Log "Installing $id..." "Info"; Set-Status "Installing $id..."
            Show-Progress -Text "Installing: $id ($count/$($selected.Count))" -Value $percent
            try {
                if ($pkg -eq "winget") { winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null }
                else { choco install $id -y 2>&1 | Out-Null }
                Write-Log "Done: $id" "Success"
            } catch { Write-Log "Failed: $id`: $_" "Error" }
        }
        Update-InstalledCache
        if ($controls["ChkShowInstalled"]) { Apply-Filters }
        Hide-Progress; Set-Status "Ready"
        Show-Info "Installation Complete" "$($selected.Count) application(s) installed via $pkg."
        Write-Log "Installation complete." "Header"
        Set-ProgressTaskbar -state "Normal" -value 1
    })
}

if ($controls["BtnUninstall"]) {
    $controls["BtnUninstall"].Add_Click({
        $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
        $pkg = $script:pkgManager
        if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
        if (-not (Show-Confirm "Uninstall Apps" "Uninstall $($selected.Count) application(s) and deep clean leftovers via $pkg?`n`nThis cannot be undone!")) { return }
        Write-Log "Starting uninstallation via $pkg..." "Header"
        Set-Status "Uninstalling $($selected.Count) app(s) via $pkg..."
        Show-Progress -Text "Preparing uninstallation..." -Value 0.05
        $count = 0
        foreach ($cb in $selected) {
            $id = $cb.Tag; $count++
            $percent = [math]::Max(0.05, [math]::Min(0.95, ($count / $selected.Count) * 0.9))
            Write-Log "Uninstalling $id..." "Info"; Set-Status "Uninstalling $id..."
            Show-Progress -Text "Uninstalling: $id ($count/$($selected.Count))" -Value $percent
            $ok = $true
            try {
                if ($pkg -eq "winget") { winget uninstall --id=$id --silent --purge --accept-source-agreements 2>&1 | Out-Null }
                else { choco uninstall $id -y 2>&1 | Out-Null }
                Write-Log "Done: $id" "Success"
            } catch { Write-Log "Failed: $id`: $_" "Error"; $ok = $false }
            if ($ok -and $pkg -eq "winget") {
                Write-Log "Deep Cleaning $id..." "Info"; Set-Status "Cleaning $id leftovers..."
                foreach ($term in ($id -split '\.') | Where-Object { $_.Length -gt 4 }) {
                    foreach ($basePath in @($env:APPDATA, $env:LOCALAPPDATA, $env:PROGRAMDATA)) {
                        Get-ChildItem -Path $basePath -Directory -Filter "*$term*" -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force; Write-Log "Deleted: $($_.FullName)" "Success" } catch { Write-Log "Cleanup dir failed: $($_.FullName)" "Warn" } }
                    }
                    foreach ($regPath in @("HKCU:\Software", "HKLM:\SOFTWARE\WOW6432Node")) {
                        if (Test-Path $regPath) { Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.Name.Contains($term) } | ForEach-Object { try { Remove-Item $_.PSPath -Recurse -Force; Write-Log "Deleted Reg: $($_.Name)" "Success" } catch { Write-Log "Cleanup reg failed: $($_.Name)" "Warn" } } }
                    }
                }
            }
        }
        Update-InstalledCache
        if ($controls["ChkShowInstalled"]) { Apply-Filters }
        Hide-Progress; Set-Status "Ready"
        Show-Info "Uninstall Complete" "$($selected.Count) application(s) uninstalled via $pkg."
        Write-Log "Uninstallation complete." "Header"
    })
}

if ($controls["PkgWinGet"]) { $controls["PkgWinGet"].Add_Checked({ $script:pkgManager = "winget"; Write-Log "Package manager: WinGet" "Info" }) }
if ($controls["PkgChoco"]) { $controls["PkgChoco"].Add_Checked({ $script:pkgManager = "choco"; Write-Log "Package manager: Chocolatey" "Info" }) }
