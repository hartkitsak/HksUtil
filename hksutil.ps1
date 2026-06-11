<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : 3.0 (combined build — do not edit directly; edit src/ sources)
#>



# ============ PARAMETERS & SETUP ============
<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : development — run .\scripts\Combine.ps1 to build hksutil.ps1
#>

# Manual arg parsing (no param() — supports irm | iex)
$Config = $null; $Noui = $false; $Apply = $false; $Verbose = $false
$i = 0
while ($i -lt $args.Count) {
    $a = $args[$i]
    if ($a -like '-*') {
        $name = $a.TrimStart('-')
        if ($name -eq 'Config') { $i++; $Config = $args[$i] }
        elseif ($name -eq 'Noui') { $Noui = $true }
        elseif ($name -eq 'Apply') { $Apply = $true }
        elseif ($name -eq 'Verbose') { $Verbose = $true }
        else { Write-Host "Unknown argument: $a"; exit 1 }
    }
    $i++
}

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host "HksUtil requires FullLanguage mode. Current: $($ExecutionContext.SessionState.LanguageMode)" -ForegroundColor Red
    pause; exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "HksUtil needs to be run as Administrator. Attempting to relaunch."
    $argList = @()
    if ($Config) { $cv = $Config.Replace("'", "''"); $argList += "-Config '$cv'" }
    if ($Noui) { $argList += "-Noui" }
    if ($Apply) { $argList += "-Apply" }
    if ($Verbose) { $argList += "-Verbose" }
    $isTemp = $PSCommandPath -and ($PSCommandPath -like "$($env:TEMP)*")
    $scriptCmd = if ($PSCommandPath -and -not $isTemp) {
        $escapedPath = $PSCommandPath.Replace("'", "''")
        "& { & '$escapedPath' $($argList -join ' ') }"
    } else { "& { `$f = Join-Path `$env:TEMP 'install.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/hartkitsak/HksUtil/main/install.ps1' -OutFile `$f -UseBasicParsing; & `$f $($argList -join ' '); Remove-Item `$f -Force }" }
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }
    try {
        if ($processCmd -eq "wt.exe") {
            Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
        } else {
            Start-Process $powershellCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
        }
    } catch { Write-Host "Elevation cancelled or failed: $_" }
    exit
}

$sync = [Hashtable]::Synchronized(@{})
$sync.version = ""
$sync.build = ""
$sync.noUI = $Noui
$sync.configs = @{}
$sync.ProcessRunning = $false

$sync.controls = @{}
$sync.logLevel = if ($Verbose) { "Info" } else { "Success" }
$script:appRoot = $PSScriptRoot


# ============ EMBEDDED DATA ============
$script:embeddedConfigs = @{}
$script:embeddedConfigs['meta'] = [PSCustomObject]@{'version' = "3.0"; 'build' = ""}
$script:embeddedConfigs['themes'] = [PSCustomObject]@{'light' = [PSCustomObject]@{'windowBackground' = "#F4F8FC"; 'headerBackground' = "#FFFFFF"; 'headerBorder' = "#C4D9ED"; 'footerBackground' = "#FFFFFF"; 'footerBorder' = "#C4D9ED"; 'cardBackground' = "#FFFFFF"; 'cardForeground' = "#1A2733"; 'cardBorder' = "#BDD3E8"; 'accentColor' = "#4D9DE0"; 'accentHover' = "#3A87C8"; 'pageTitleColor' = "#1A2733"; 'categoryHeaderColor' = "#4D9DE0"; 'textMuted' = "#7A96AE"; 'textBoxBackground' = "#FFFFFF"; 'textBoxForeground' = "#1A2733"; 'textBoxBorder' = "#BDD3E8"; 'dangerColor' = "#C0392B"; 'dangerHover' = "#962D22"; 'successColor' = "#2ECC71"; 'warningColor' = "#F39C12"; 'infoColor' = "#4D9DE0"; 'selectedBorder' = "#4D9DE0"; 'selectedBackground' = "#E0EEFA"; 'hoverBackground' = "#EBF3FA"; 'secondaryBackground' = "#FFFFFF"; 'secondaryHover' = "#EBF3FA"}}
$script:embeddedConfigs['apps'] = [PSCustomObject]@{'Browsers' = [PSCustomObject]@{'brave' = [PSCustomObject]@{'content' = "Brave"; 'winget' = "Brave.Brave"; 'description' = "Privacy-first browser with built-in ad blocker"}; 'firefox' = [PSCustomObject]@{'content' = "Firefox"; 'winget' = "Mozilla.Firefox"; 'description' = "Privacy-focused web browser"}; 'tor' = [PSCustomObject]@{'content' = "Tor Browser"; 'winget' = "TorProject.TorBrowser"; 'description' = "Anonymous web browsing via Tor network"}}; 'Security & Privacy' = [PSCustomObject]@{'mullvad' = [PSCustomObject]@{'content' = "Mullvad VPN"; 'winget' = "Mullvad.MullvadVPN"; 'description' = "Privacy-focused VPN service"}; 'protonvpn' = [PSCustomObject]@{'content' = "ProtonVPN"; 'winget' = "Proton.ProtonVPN"; 'description' = "Secure VPN with no-logs policy"}; 'malwarebytes' = [PSCustomObject]@{'content' = "Malwarebytes"; 'winget' = "Malwarebytes.Malwarebytes"; 'description' = "On-demand malware scanner and remover"}; 'veracrypt' = [PSCustomObject]@{'content' = "VeraCrypt"; 'winget' = "IDRIX.VeraCrypt"; 'description' = "Disk encryption software for files and partitions"}}; 'Development' = [PSCustomObject]@{'vscode' = [PSCustomObject]@{'content' = "VS Code"; 'winget' = "Microsoft.VisualStudioCode"; 'description' = "Lightweight source code editor"}; 'github_desktop' = [PSCustomObject]@{'content' = "GitHub Desktop"; 'winget' = "GitHub.GitHubDesktop"; 'description' = "GUI for Git and GitHub"}; 'docker' = [PSCustomObject]@{'content' = "Docker Desktop"; 'winget' = "Docker.DockerDesktop"; 'description' = "Container platform for dev and test"}; 'dbeaver' = [PSCustomObject]@{'content' = "DBeaver"; 'winget' = "DBeaver.DBeaver"; 'description' = "Universal database manager"}; 'bruno' = [PSCustomObject]@{'content' = "Bruno"; 'winget' = "Bruno.Bruno"; 'description' = "Offline-first API testing client"}; 'git' = [PSCustomObject]@{'content' = "Git"; 'winget' = "Git.Git"; 'description' = "Distributed version control system"}; 'nodejs' = [PSCustomObject]@{'content' = "Node.js LTS"; 'winget' = "OpenJS.NodeJS.LTS"; 'description' = "JavaScript runtime built on Chrome's V8 engine"}; 'python' = [PSCustomObject]@{'content' = "Python 3.12"; 'winget' = "Python.Python.3.12"; 'description' = "High-level programming language"}; 'windows_terminal' = [PSCustomObject]@{'content' = "Windows Terminal"; 'winget' = "Microsoft.WindowsTerminal"; 'description' = "Modern terminal application for Windows"}; 'powershell' = [PSCustomObject]@{'content' = "PowerShell 7"; 'winget' = "Microsoft.PowerShell"; 'description' = "Cross-platform shell and scripting language"}; 'ohmyposh' = [PSCustomObject]@{'content' = "Oh My Posh"; 'winget' = "JanDeDobbeleer.OhMyPosh"; 'description' = "Prompt theme engine for any shell"}}; 'Media & Creative' = [PSCustomObject]@{'gimp' = [PSCustomObject]@{'content' = "GIMP"; 'winget' = "GIMP.GIMP"; 'description' = "Free and open-source image editor"}; 'krita' = [PSCustomObject]@{'content' = "Krita"; 'winget' = "Krita.Krita"; 'description' = "Professional digital painting tool"}; 'inkscape' = [PSCustomObject]@{'content' = "Inkscape"; 'winget' = "Inkscape.Inkscape"; 'description' = "Vector graphics editor"}; 'kdenlive' = [PSCustomObject]@{'content' = "Kdenlive"; 'winget' = "KDE.Kdenlive"; 'description' = "Free and open-source video editor"}; 'obs' = [PSCustomObject]@{'content' = "OBS Studio"; 'winget' = "OBSProject.OBSStudio"; 'description' = "Video recording and live streaming software"}; 'audacity' = [PSCustomObject]@{'content' = "Audacity"; 'winget' = "Audacity.Audacity"; 'description' = "Multi-track audio recorder and editor"}; 'mpchc' = [PSCustomObject]@{'content' = "MPC-HC"; 'winget' = "clsid2.mpc-hc"; 'description' = "Lightweight media player"}; 'vlc' = [PSCustomObject]@{'content' = "VLC"; 'winget' = "VideoLAN.VLC"; 'description' = "Free and open source multimedia player"}; 'foobar2000' = [PSCustomObject]@{'content' = "foobar2000"; 'winget' = "PeterPawlowski.foobar2000"; 'description' = "Advanced audio player"}; 'ytdlp' = [PSCustomObject]@{'content' = "yt-dlp"; 'winget' = "yt-dlp.yt-dlp"; 'description' = "Command-line video downloader"}; 'sharex' = [PSCustomObject]@{'content' = "ShareX"; 'winget' = "ShareX.ShareX"; 'description' = "Screen capture and file sharing tool"}}; 'Utilities' = [PSCustomObject]@{'powertoys' = [PSCustomObject]@{'content' = "PowerToys"; 'winget' = "Microsoft.PowerToys"; 'description' = "System utilities: FancyZones, PowerRename, Run, etc."}; 'everything' = [PSCustomObject]@{'content' = "Everything"; 'winget' = "voidtools.Everything"; 'description' = "Lightning-fast file search engine"}; 'ditto' = [PSCustomObject]@{'content' = "Ditto"; 'winget' = "Ditto.Ditto"; 'description' = "Clipboard manager with search history"}; 'hwinfo' = [PSCustomObject]@{'content' = "HWiNFO64"; 'winget' = "REALiX.HWiNFO"; 'description' = "Comprehensive hardware monitoring tool"}; 'syncthing' = [PSCustomObject]@{'content' = "Syncthing"; 'winget' = "Syncthing.Syncthing"; 'description' = "P2P file sync between devices"}; '7zip_zs' = [PSCustomObject]@{'content' = "7-Zip ZS"; 'winget' = "mcmilk.7zip-zstd"; 'description' = "File archiver with Zstandard support"}; 'revo' = [PSCustomObject]@{'content' = "Revo Uninstaller"; 'winget' = "RevoUninstaller.RevoUninstaller"; 'description' = "Advanced uninstaller tool"}; 'bitwarden' = [PSCustomObject]@{'content' = "Bitwarden"; 'winget' = "Bitwarden.Bitwarden"; 'description' = "Open source password manager"}; 'motrix' = [PSCustomObject]@{'content' = "Motrix"; 'winget' = "Motrix.Motrix"; 'description' = "Full-featured download manager"}; 'mobaxterm' = [PSCustomObject]@{'content' = "MobaXterm"; 'winget' = "Mobatek.MobaXterm"; 'description' = "Enhanced terminal with X11 server"}}; 'Productivity' = [PSCustomObject]@{'obsidian' = [PSCustomObject]@{'content' = "Obsidian"; 'winget' = "Obsidian.Obsidian"; 'description' = "Local-first note-taking app with Markdown"}; 'sumatra' = [PSCustomObject]@{'content' = "Sumatra PDF"; 'winget' = "SumatraPDF.SumatraPDF"; 'description' = "Lightweight PDF and ebook reader"}; 'notion' = [PSCustomObject]@{'content' = "Notion"; 'winget' = "Notion.Notion"; 'description' = "All-in-one workspace for notes and tasks"}}}
$script:embeddedConfigs['dns'] = [PSCustomObject]@{'Default_DHCP' = [PSCustomObject]@{'description' = "Default DHCP (reset to auto)"}; 'Google' = [PSCustomObject]@{'description' = "Google Public DNS"; 'ipv4' = @("8.8.8.8","8.8.4.4"); 'ipv6' = @("2001:4860:4860::8888","2001:4860:4860::8844")}; 'Cloudflare' = [PSCustomObject]@{'description' = "Cloudflare DNS (1.1.1.1)"; 'ipv4' = @("1.1.1.1","1.0.0.1"); 'ipv6' = @("2606:4700:4700::1111","2606:4700:4700::1001")}; 'Cloudflare_Malware' = [PSCustomObject]@{'description' = "Cloudflare Malware Protection"; 'ipv4' = @("1.1.1.2","1.0.0.2"); 'ipv6' = @("2606:4700:4700::1112","2606:4700:4700::1002")}; 'Cloudflare_Malware_Adult' = [PSCustomObject]@{'description' = "Cloudflare Malware & Adult Protection"; 'ipv4' = @("1.1.1.3","1.0.0.3"); 'ipv6' = @("2606:4700:4700::1113","2606:4700:4700::1003")}; 'Open_DNS' = [PSCustomObject]@{'description' = "Cisco OpenDNS"; 'ipv4' = @("208.67.222.222","208.67.220.220"); 'ipv6' = @("2620:119:35::35","2620:119:53::53")}; 'Quad9' = [PSCustomObject]@{'description' = "Quad9 Security DNS"; 'ipv4' = @("9.9.9.9","149.112.112.112"); 'ipv6' = @("2620:fe::fe","2620:fe::9")}; 'AdGuard_Ads_Trackers' = [PSCustomObject]@{'description' = "AdGuard DNS (Ads & Trackers)"; 'ipv4' = @("94.140.14.14","94.140.15.15"); 'ipv6' = @("2a10:50c0::ad1:ff","2a10:50c0::ad2:ff")}; 'AdGuard_Ads_Trackers_Malware_Adult' = [PSCustomObject]@{'description' = "AdGuard DNS (Ads, Trackers, Malware, Adult)"; 'ipv4' = @("94.140.14.15","94.140.15.16"); 'ipv6' = @("2a10:50c0::bad1:ff","2a10:50c0::bad2:ff")}}
$script:embeddedConfigs['preferences'] = [PSCustomObject]@{'bsod_verbose' = [PSCustomObject]@{'content' = "BSoD Verbose Mode"; 'description' = "Show detailed error on Blue Screen of Death."; 'registry_on' = @([PSCustomObject]@{'path' = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"; 'name' = "DisplayParameters"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"; 'name' = "DisplayParameters"; 'value' = 0})}; 'login_acrylic' = [PSCustomObject]@{'content' = "Logon Screen Acrylic Blur"; 'description' = "Enable acrylic blur on login screen."; 'registry_on' = @([PSCustomObject]@{'path' = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; 'name' = "DisableAcrylicBackgroundOnLogon"; 'value' = 0}); 'registry_off' = @([PSCustomObject]@{'path' = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; 'name' = "DisableAcrylicBackgroundOnLogon"; 'value' = 1})}; 'login_verbose' = [PSCustomObject]@{'content' = "Logon Verbose Mode"; 'description' = "Display detailed startup/shutdown messages."; 'registry_on' = @([PSCustomObject]@{'path' = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; 'name' = "VerboseStatus"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; 'name' = "VerboseStatus"; 'value' = 0})}; 'mouse_acceleration' = [PSCustomObject]@{'content' = "Mouse Acceleration"; 'description' = "Toggle mouse pointer precision."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Mouse"; 'name' = "MouseSpeed"; 'value' = "1"},[PSCustomObject]@{'path' = "HKCU:\Control Panel\Mouse"; 'name' = "MouseThreshold1"; 'value' = "6"},[PSCustomObject]@{'path' = "HKCU:\Control Panel\Mouse"; 'name' = "MouseThreshold2"; 'value' = "10"}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Mouse"; 'name' = "MouseSpeed"; 'value' = "0"},[PSCustomObject]@{'path' = "HKCU:\Control Panel\Mouse"; 'name' = "MouseThreshold1"; 'value' = "0"},[PSCustomObject]@{'path' = "HKCU:\Control Panel\Mouse"; 'name' = "MouseThreshold2"; 'value' = "0"})}; 'numlock_on' = [PSCustomObject]@{'content' = "Num Lock on Startup"; 'description' = "Enable Num Lock automatically at startup."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Keyboard"; 'name' = "InitialKeyboardIndicators"; 'value' = "2"}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Keyboard"; 'name' = "InitialKeyboardIndicators"; 'value' = "0"})}; 'scrollbars_visible' = [PSCustomObject]@{'content' = "Scrollbars Always Visible"; 'description' = "Force scrollbars to always be visible."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Accessibility"; 'name' = "DynamicScrollbars"; 'value' = "0"}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Accessibility"; 'name' = "DynamicScrollbars"; 'value' = "1"})}; 'bing_search' = [PSCustomObject]@{'content' = "Start Menu Bing Search"; 'description' = "Disable Bing search suggestions."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; 'name' = "DisableSearchBoxSuggestions"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; 'name' = "DisableSearchBoxSuggestions"; 'value' = 0})}; 'start_recommendations' = [PSCustomObject]@{'content' = "Start Menu Recommendations"; 'description' = "Hide recommended section in Start menu."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; 'name' = "HideRecommendedSection"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; 'name' = "HideRecommendedSection"; 'value' = 0})}; 'sticky_keys' = [PSCustomObject]@{'content' = "Sticky Keys"; 'description' = "Disable Sticky Keys accessibility feature."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Accessibility\StickyKeys"; 'name' = "Flags"; 'value' = "506"}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\Control Panel\Accessibility\StickyKeys"; 'name' = "Flags"; 'value' = "510"})}; 'taskbar_center' = [PSCustomObject]@{'content' = "Taskbar Centered Icons"; 'description' = "Center taskbar icons (Windows 11 style)."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "TaskbarAl"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "TaskbarAl"; 'value' = 0})}; 'taskbar_search' = [PSCustomObject]@{'content' = "Taskbar Search Icon"; 'description' = "Show search icon only on taskbar."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; 'name' = "SearchboxTaskbarMode"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; 'name' = "SearchboxTaskbarMode"; 'value' = 0})}; 'taskbar_taskview' = [PSCustomObject]@{'content' = "Taskbar Task View Icon"; 'description' = "Show/hide Task View button."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "ShowTaskViewButton"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "ShowTaskViewButton"; 'value' = 0})}; 'cross_device' = [PSCustomObject]@{'content' = "Cross-Device Resume"; 'description' = "Allow cross-device activity sync."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"; 'name' = "RomeSdk"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"; 'name' = "RomeSdk"; 'value' = 0})}; 'dark_theme' = [PSCustomObject]@{'content' = "Dark Theme for Windows"; 'description' = "Enable Windows dark theme."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; 'name' = "AppsUseLightTheme"; 'value' = 0},[PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; 'name' = "SystemUsesLightTheme"; 'value' = 0}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; 'name' = "AppsUseLightTheme"; 'value' = 1},[PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; 'name' = "SystemUsesLightTheme"; 'value' = 1})}; 'file_extensions' = [PSCustomObject]@{'content' = "File Explorer File Extensions"; 'description' = "Show file extensions."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "HideFileExt"; 'value' = 0}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "HideFileExt"; 'value' = 1})}; 'hidden_files' = [PSCustomObject]@{'content' = "File Explorer Hidden Files"; 'description' = "Show hidden files and folders."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "Hidden"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "Hidden"; 'value' = 2})}; 'mpo' = [PSCustomObject]@{'content' = "Multiplane Overlay"; 'description' = "Enable/disable MPO. Disabling can fix GPU issues."; 'registry_on' = @([PSCustomObject]@{'path' = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"; 'name' = "OverlayTestMode"; 'value' = 5}); 'registry_off' = @([PSCustomObject]@{'path' = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"; 'name' = "OverlayTestMode"; 'value' = 0})}; 's0_standby' = [PSCustomObject]@{'content' = "S0 Sleep Network Connectivity"; 'description' = "Keep network connectivity during Modern Standby."; 'registry_on' = @([PSCustomObject]@{'path' = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"; 'name' = "NetworkConnectivityInStandby"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"; 'name' = "NetworkConnectivityInStandby"; 'value' = 0})}; 's3_sleep' = [PSCustomObject]@{'content' = "S3 Sleep"; 'description' = "Enable traditional S3 sleep state."; 'registry_on' = @([PSCustomObject]@{'path' = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"; 'name' = "PlatformAoAcOverride"; 'value' = 0}); 'registry_off' = @([PSCustomObject]@{'path' = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"; 'name' = "PlatformAoAcOverride"; 'value' = 1})}; 'battery_percent' = [PSCustomObject]@{'content' = "System Tray Battery Percentage"; 'description' = "Show battery percentage in system tray."; 'registry_on' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "ShowBatteryPercentage"; 'value' = 1}); 'registry_off' = @([PSCustomObject]@{'path' = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; 'name' = "ShowBatteryPercentage"; 'value' = 0})}}
$script:embeddedConfigs['cleaner'] = [PSCustomObject]@{'Privacy' = [PSCustomObject]@{'clear_recent_docs' = [PSCustomObject]@{'content' = "Clear Recent Documents History"; 'description' = "Clears the list of recently accessed documents"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedMRU' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU' -Recurse -Force -ErrorAction SilentlyContinue"}; 'clear_run_history' = [PSCustomObject]@{'content' = "Clear Start Menu Run History"; 'description' = "Clears the Run dialog history"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths' -Recurse -Force -ErrorAction SilentlyContinue"}; 'clear_find_history' = [PSCustomObject]@{'content' = "Clear Find File History"; 'description' = "Clears the Windows Search/Find history"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FindComputerMRU' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Doc Find Spec MRU' -Recurse -Force -ErrorAction SilentlyContinue"}; 'clear_printers_history' = [PSCustomObject]@{'content' = "Clear Printers, Computers and People Find History"; 'description' = "Clears network discovery history"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\PrinterPortsMRU' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComputerDescriptions' -Recurse -Force -ErrorAction SilentlyContinue"}; 'clear_mspaint_history' = [PSCustomObject]@{'content' = "Clear MS Paint Recent File History"; 'description' = "Clears the list of recently opened files in Paint"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List' -Recurse -Force -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\MRU' -Name '*' -Force -ErrorAction SilentlyContinue"}; 'clear_wordpad_history' = [PSCustomObject]@{'content' = "Clear MS Wordpad Recent File History"; 'description' = "Clears the list of recently opened files in Wordpad"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List' -Recurse -Force -ErrorAction SilentlyContinue"}; 'clear_regedit_history' = [PSCustomObject]@{'content' = "Clear Regedit Last Opened Key History"; 'description' = "Clears the last visited keys in Registry Editor"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites' -Recurse -Force -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit' -Name 'LastKey' -Force -ErrorAction SilentlyContinue"}; 'clear_common_dialog_history' = [PSCustomObject]@{'content' = "Clear Common Dialog Open/Save Recent History"; 'description' = "Clears the Open/Save dialog history"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU' -Recurse -Force -ErrorAction SilentlyContinue"}; 'clear_common_dialog_folder' = [PSCustomObject]@{'content' = "Clear Common Dialog Last Visited Folder History"; 'description' = "Clears the last visited folder in Open/Save dialogs"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU' -Recurse -Force -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32' -Name 'LastVisitedFolder' -Force -ErrorAction SilentlyContinue"}; 'delete_start_usage_logs' = [PSCustomObject]@{'content' = "Delete Start Menu Usage Logs"; 'description' = "Clears the Start Menu usage tracking data"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage\Apps' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage\RecentApps' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage\Favorites' -Recurse -Force -ErrorAction SilentlyContinue"}; 'clear_registry_traces' = [PSCustomObject]@{'content' = "Clear Registry Usage Traces"; 'description' = "Cleans various MRU and usage trace keys from the registry"; 'script' = "Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StreamMRU' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2' -Recurse -Force -ErrorAction SilentlyContinue"}}; 'System' = [PSCustomObject]@{'delete_prefetch' = [PSCustomObject]@{'content' = "Delete Prefetch & System Logs"; 'description' = "Deletes Prefetch files and Windows log files"; 'script' = "Remove-Item -Path `"$env:WINDIR\Prefetch\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:WINDIR\Logs\*`" -Recurse -Force -ErrorAction SilentlyContinue"}; 'empty_clipboard' = [PSCustomObject]@{'content' = "Empty the Clipboard"; 'description' = "Clears the system clipboard"; 'script' = "$null = [System.Windows.Clipboard]::SetText([string]::Empty)"}; 'empty_recycle_bin' = [PSCustomObject]@{'content' = "Empty the Recycle Bin"; 'description' = "Permanently deletes all items in the Recycle Bin"; 'script' = "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"}; 'delete_temp_files' = [PSCustomObject]@{'content' = "Delete Windows Temporary Files"; 'description' = "Deletes temporary files from user and system Temp folders"; 'script' = "Remove-Item -Path `"$env:TEMP\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:WINDIR\Temp\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:WINDIR\SoftwareDistribution\Download\*`" -Recurse -Force -ErrorAction SilentlyContinue"}; 'delete_crash_dumps' = [PSCustomObject]@{'content' = "Delete Crash Memory Dump Files"; 'description' = "Deletes system crash dump and minidump files"; 'script' = "Remove-Item -Path `"$env:WINDIR\MEMORY.DMP`" -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:WINDIR\Minidump\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:LOCALAPPDATA\CrashDumps\*`" -Recurse -Force -ErrorAction SilentlyContinue"}; 'delete_chkdsk_fragments' = [PSCustomObject]@{'content' = "Delete Chkdsk Recovered File Fragments"; 'description' = "Deletes recovered file fragments from Chkdsk operations"; 'script' = "Remove-Item -Path `"$env:SystemDrive\FOUND.000\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.001\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.002\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.003\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.004\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.005\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.006\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.007\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.008\*`" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:SystemDrive\FOUND.009\*`" -Recurse -Force -ErrorAction SilentlyContinue"}; 'delete_thumbnail_cache' = [PSCustomObject]@{'content' = "Delete Thumbnail Cache"; 'description' = "Clears the Windows thumbnail cache for all users"; 'script' = "try { Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db`" -Force -ErrorAction SilentlyContinue; Remove-Item -Path `"$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer\*.db`" -Force -ErrorAction SilentlyContinue } finally { Start-Process 'explorer.exe' -ErrorAction SilentlyContinue }"}}}
$script:embeddedConfigs['legacy'] = @([PSCustomObject]@{'key' = "rstrui"; 'content' = "System Restore"; 'command' = "rstrui.exe"; 'description' = "Create or restore system restore points"},[PSCustomObject]@{'key' = "ncpa"; 'content' = "Network Information"; 'command' = "ncpa.cpl"; 'description' = "Manage network adapters and connections"},[PSCustomObject]@{'key' = "wscui"; 'content' = "Security Center"; 'command' = "wscui.cpl"; 'description' = "View Windows Security Center status"},[PSCustomObject]@{'key' = "sysdm"; 'content' = "System Properties"; 'command' = "sysdm.cpl"; 'description' = "View system info, performance, remote settings"},[PSCustomObject]@{'key' = "msinfo32"; 'content' = "System Information"; 'command' = "msinfo32"; 'description' = "View detailed system hardware and software information"},[PSCustomObject]@{'key' = "netstat"; 'content' = "TCP/IP Netstat"; 'command' = "cmd /c netstat -an && pause"; 'description' = "Display active network connections and listening ports"},[PSCustomObject]@{'key' = "osk"; 'content' = "On Screen Keyboard"; 'command' = "osk"; 'description' = "Launch the on-screen keyboard"},[PSCustomObject]@{'key' = "dfrgui"; 'content' = "Disk Defragmenter"; 'command' = "dfrgui"; 'description' = "Optimize and defragment disk drives"},[PSCustomObject]@{'key' = "services"; 'content' = "Services"; 'command' = "services.msc"; 'description' = "Manage Windows services and their startup types"},[PSCustomObject]@{'key' = "fsmgmt"; 'content' = "Shared Folders"; 'command' = "fsmgmt.msc"; 'description' = "Manage shared folders and connections"},[PSCustomObject]@{'key' = "gpedit"; 'content' = "Group Policy"; 'command' = "gpedit.msc"; 'description' = "Edit Group Policy settings"},[PSCustomObject]@{'key' = "optionalfeatures"; 'content' = "Add/Remove Windows Components"; 'command' = "OptionalFeatures"; 'description' = "Turn Windows features on or off"},[PSCustomObject]@{'key' = "mrt"; 'content' = "Malicious Software Removal Tool"; 'command' = "mrt /Q"; 'description' = "Scan and remove malicious software"},[PSCustomObject]@{'key' = "sdclt"; 'content' = "Windows Backup and Restore"; 'command' = "sdclt"; 'description' = "Backup and restore files or system image"},[PSCustomObject]@{'key' = "taskschd"; 'content' = "Task Scheduler"; 'command' = "taskschd.msc"; 'description' = "Schedule automated tasks and triggers"},[PSCustomObject]@{'key' = "chkdsk"; 'content' = "Check Disk"; 'command' = "cmd /c chkdsk && pause"; 'description' = "Check disk for file system errors"},[PSCustomObject]@{'key' = "sfc"; 'content' = "System File Checker"; 'command' = "cmd /c sfc /scannow && pause"; 'description' = "Scan and repair protected system files"})

$script:embeddedXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:primitives="clr-namespace:System.Windows.Controls.Primitives;assembly=PresentationFramework"
        Title="HksUtil v2.0 - Windows Optimizer" Width="1200" Height="750" MinWidth="1000" MinHeight="600"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource windowBackground}"
        WindowStyle="None"
        ResizeMode="CanResizeWithGrip">
    <WindowChrome.WindowChrome>
        <WindowChrome CaptionHeight="0" ResizeBorderThickness="5"/>
    </WindowChrome.WindowChrome>
    <Window.Resources>
        <ResourceDictionary>
            <Style TargetType="{x:Type ContextMenu}">
                <Setter Property="SnapsToDevicePixels" Value="True"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="{x:Type ContextMenu}">
                            <Border Background="{DynamicResource cardBackground}"
                                    BorderBrush="{DynamicResource cardBorder}"
                                    BorderThickness="1"
                                    CornerRadius="6"
                                    Padding="4">
                                <ItemsPresenter/>
                            </Border>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="CategoryHeader" TargetType="TextBlock">
                <Setter Property="FontSize" Value="14"/>
                <Setter Property="FontWeight" Value="Bold"/>
                <Setter Property="Foreground" Value="{DynamicResource categoryHeaderColor}"/>
                <Setter Property="Margin" Value="10,15,10,5"/>
            </Style>
            <Style x:Key="TweakCheckBox" TargetType="CheckBox">
                <Setter Property="Margin" Value="5"/>
                <Setter Property="Padding" Value="12,10"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="RenderTransformOrigin" Value="0.5,0.5"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="CheckBox">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}" RenderTransformOrigin="0.5,0.5">
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="6" Opacity="0.12" ShadowDepth="1" Color="Black"/>
                                </Border.Effect>
                                <ContentPresenter/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="RootBorder" Property="BorderBrush" Value="{DynamicResource selectedBorder}"/>
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource selectedBackground}"/>
                                    <Setter TargetName="RootBorder" Property="BorderThickness" Value="2"/>
                                </Trigger>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ToggleSwitch" TargetType="CheckBox">
                <Setter Property="Margin" Value="5"/>
                <Setter Property="Padding" Value="12,10"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="CheckBox">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="6" Opacity="0.12" ShadowDepth="1" Color="Black"/>
                                </Border.Effect>
                                <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
                                    <Grid x:Name="ToggleGrid" Width="42" Height="22" Margin="0,0,10,0" VerticalAlignment="Center">
                                        <Border x:Name="ToggleTrack" Background="{DynamicResource textBoxBorder}" CornerRadius="11" BorderThickness="0"/>
                                        <Border x:Name="ToggleThumb" Width="18" Height="18" CornerRadius="9" Background="White" HorizontalAlignment="Left" Margin="2,0,0,0" BorderThickness="0">
                                            <Border.Effect>
                                                <DropShadowEffect BlurRadius="4" Opacity="0.3" ShadowDepth="1" Color="Black"/>
                                            </Border.Effect>
                                        </Border>
                                    </Grid>
                                    <TextBlock Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="ToggleTrack" Property="Background" Value="{DynamicResource accentColor}"/>
                                    <Setter TargetName="ToggleThumb" Property="Margin" Value="22,0,0,0"/>
                                    <Setter TargetName="RootBorder" Property="BorderBrush" Value="{DynamicResource selectedBorder}"/>
                                </Trigger>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="NavButtonStyle" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="12,10"/>
                <Setter Property="Margin" Value="2,2,2,2"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="HorizontalContentAlignment" Value="Left"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="4">
                                <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource headerBorder}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ActionBtn" TargetType="Button">
                <Setter Property="Background" Value="{DynamicResource accentColor}"/>
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="8" Opacity="0.3" ShadowDepth="2" Color="Black"/>
                                </Border.Effect>
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource accentHover}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="DangerBtn" TargetType="Button">
                <Setter Property="Background" Value="{DynamicResource dangerColor}"/>
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="8" Opacity="0.3" ShadowDepth="2" Color="Black"/>
                                </Border.Effect>
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource dangerHover}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="SecondaryBtn" TargetType="Button">
                <Setter Property="Background" Value="{DynamicResource secondaryBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="4" Opacity="0.1" ShadowDepth="1" Color="Black"/>
                                </Border.Effect>
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource secondaryHover}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ToolCard" TargetType="Button">
                <Setter Property="Margin" Value="5"/>
                <Setter Property="Padding" Value="12,10"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="TextBlock.FontSize" Value="13"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="6" Opacity="0.12" ShadowDepth="1" Color="Black"/>
                                </Border.Effect>
                                <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                    <Setter Property="BorderBrush" Value="{DynamicResource accentColor}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="DnsCardStyle" TargetType="RadioButton">
                <Setter Property="Margin" Value="4,5"/>
                <Setter Property="Padding" Value="12,10"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="RadioButton">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <Border.Effect>
                                    <DropShadowEffect BlurRadius="6" Opacity="0.12" ShadowDepth="1" Color="Black"/>
                                </Border.Effect>
                                <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="RootBorder" Property="BorderBrush" Value="{DynamicResource selectedBorder}"/>
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource selectedBackground}"/>
                                    <Setter TargetName="RootBorder" Property="BorderThickness" Value="2"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ToolbarIconBtn" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="8,4"/>
                <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
                <Setter Property="FontSize" Value="16"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="ToolbarIconToggleBtn" TargetType="ToggleButton">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="8,4"/>
                <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
                <Setter Property="FontSize" Value="16"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="ToggleButton">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                                <Trigger Property="IsChecked" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource selectedBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="PopupMenuItem" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="14,8"/>
                <Setter Property="Margin" Value="2"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="HorizontalContentAlignment" Value="Left"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="4">
                                <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="TopNavButtonStyle" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource textMuted}"/>
                <Setter Property="BorderThickness" Value="0"/>
                <Setter Property="Padding" Value="9,6"/>
                <Setter Property="Margin" Value="2,0"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="4">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="RootBorder" Property="Background" Value="{DynamicResource hoverBackground}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
        </ResourceDictionary>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border x:Name="ToolbarDrag" Grid.Row="0" Background="{DynamicResource headerBackground}" BorderBrush="{DynamicResource headerBorder}" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" Grid.Column="0" Margin="12,6,0,6">
                    <TextBlock x:Name="TitleText" Text="HksUtil" FontSize="16" FontWeight="Bold" Foreground="{DynamicResource accentColor}" VerticalAlignment="Center"/>
                    <TextBlock x:Name="TitleVersionText" Text="v2.0" FontSize="10" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="6,2,0,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Grid.Column="1" Margin="24,0,0,0">
                    <Button x:Name="NavInstall" Style="{StaticResource TopNavButtonStyle}"><StackPanel Orientation="Horizontal"><TextBlock Text="&#xE718;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,4,0" VerticalAlignment="Center"/><TextBlock Text="Install" VerticalAlignment="Center"/></StackPanel></Button>
                    <Button x:Name="NavCleaner" Style="{StaticResource TopNavButtonStyle}"><StackPanel Orientation="Horizontal"><TextBlock Text="&#xE72E;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,4,0" VerticalAlignment="Center"/><TextBlock Text="Cleaner" VerticalAlignment="Center"/></StackPanel></Button>
                    <Button x:Name="NavTools" Style="{StaticResource TopNavButtonStyle}"><StackPanel Orientation="Horizontal"><TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,4,0" VerticalAlignment="Center"/><TextBlock Text="Tools" VerticalAlignment="Center"/></StackPanel></Button>
                    <Button x:Name="NavPreferences" Style="{StaticResource TopNavButtonStyle}"><StackPanel Orientation="Horizontal"><TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,4,0" VerticalAlignment="Center"/><TextBlock Text="Preferences" VerticalAlignment="Center"/></StackPanel></Button>
                    <Button x:Name="NavSettings" Style="{StaticResource TopNavButtonStyle}"><StackPanel Orientation="Horizontal"><TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,4,0" VerticalAlignment="Center"/><TextBlock Text="Settings" VerticalAlignment="Center"/></StackPanel></Button>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Grid.Column="2" Margin="0,0,12,0">
                    <ToggleButton x:Name="BtnToolbarSettings" Content="&#xE713;" Style="{StaticResource ToolbarIconToggleBtn}" ToolTip="Settings"/>
                    <Button x:Name="BtnToolbarMinimize" Content="&#xE921;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Minimize"/>
                    <Button x:Name="BtnToolbarMaximize" Content="&#xE922;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Maximize"/>
                    <Button x:Name="BtnToolbarClose" Content="&#xE711;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Close"/>
                </StackPanel>
            </Grid>
        </Border>

        <Popup x:Name="GearPopup" IsOpen="{Binding IsChecked, ElementName=BtnToolbarSettings}" StaysOpen="False" AllowsTransparency="True" PlacementTarget="{Binding ElementName=BtnToolbarSettings}" Placement="Bottom">
            <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="1" CornerRadius="6" Padding="4" SnapsToDevicePixels="True" UseLayoutRounding="True">
                <StackPanel>
                    <Button x:Name="BtnGearExport" Content="Export Config" Style="{StaticResource PopupMenuItem}"/>
                    <Button x:Name="BtnGearImport" Content="Import Config" Style="{StaticResource PopupMenuItem}"/>
                    <Border Height="1" Margin="4,2" Background="{DynamicResource cardBorder}"/>
                    <Button x:Name="BtnGearAbout" Content="About" Style="{StaticResource PopupMenuItem}"/>
                    <Button x:Name="BtnGearDocs" Content="Documentation" Style="{StaticResource PopupMenuItem}"/>
                    <Button x:Name="BtnGearSponsors" Content="Sponsors" Style="{StaticResource PopupMenuItem}"/>
                </StackPanel>
            </Border>
        </Popup>

        <Grid Grid.Row="1">
            <ScrollViewer x:Name="PageInstall" Visibility="Visible" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleInstall" Text="Install" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescInstall" Text="Search and manage application installations via WinGet or Chocolatey." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="0" CornerRadius="8" Padding="16" Margin="0,0,0,15">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Grid.Column="0" Background="{DynamicResource textBoxBackground}" BorderBrush="{DynamicResource textBoxBorder}" BorderThickness="1" CornerRadius="4" Margin="0,0,8,0">
                                <Grid>
                                    <TextBox x:Name="SearchBox" Padding="6,3" Background="Transparent" Foreground="{DynamicResource textBoxForeground}" BorderThickness="0"/>
                                    <TextBlock x:Name="SearchHint" Text="Search..." Foreground="{DynamicResource textMuted}" Margin="6,3,0,0" IsHitTestVisible="False" Visibility="Visible"/>
                                    <Button x:Name="BtnClearSearch" Content="X" Width="22" Height="22" HorizontalAlignment="Right" Margin="0,0,4,0" Background="{DynamicResource hoverBackground}" Foreground="{DynamicResource textMuted}" BorderBrush="{DynamicResource textBoxBorder}" BorderThickness="1" FontSize="10" Cursor="Hand" FontWeight="Bold"/>
                                </Grid>
                            </Border>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <CheckBox x:Name="ChkShowInstalled" Content="Installed" Foreground="{DynamicResource cardForeground}" VerticalAlignment="Center"/>
                                <TextBlock x:Name="LabelPkgMgr" Text="Package Manager" FontWeight="SemiBold" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="12,0,8,0"/>
                                <RadioButton x:Name="PkgWinGet" Content="WinGet" Foreground="{DynamicResource accentColor}" FontWeight="Bold" IsChecked="True" GroupName="PkgMgr" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                <RadioButton x:Name="PkgChoco" Content="Choco" Foreground="{DynamicResource cardForeground}" FontWeight="SemiBold" GroupName="PkgMgr" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                    <Border x:Name="PkgSelectionBorder" Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="0" CornerRadius="8" Padding="16" Margin="0,0,0,15">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Orientation="Horizontal" Grid.Column="0">
                                <Button x:Name="BtnInstall" Content="Install / Upgrade" Style="{StaticResource ActionBtn}" Width="120"/>
                                <Button x:Name="BtnUninstall" Content="Uninstall" Style="{StaticResource DangerBtn}" Width="110"/>
                                <Button x:Name="BtnSelectAll" Content="Select All" Style="{StaticResource SecondaryBtn}" Width="110"/>
                                <Button x:Name="BtnClearSelection" Content="Clear" Style="{StaticResource SecondaryBtn}" Width="90"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Grid.Column="1">
                                <Button x:Name="BtnCollapseAll" Content="Collapse All Categories" Style="{StaticResource SecondaryBtn}" Width="180"/>
                                <Button x:Name="BtnExpandAll" Content="Expand All Categories" Style="{StaticResource SecondaryBtn}" Width="180"/>
                                <TextBlock x:Name="LblSelectedCount" Text="Selected Apps: 0" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="10,0,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                    <StackPanel x:Name="AppPanel" HorizontalAlignment="Stretch"/>
                    <TextBlock x:Name="EmptyStateInstall" Text="No apps match your search." Foreground="{DynamicResource textMuted}" FontSize="14" Visibility="Collapsed" HorizontalAlignment="Center" Margin="0,30,0,0"/>
                </StackPanel>
            </ScrollViewer>

            <ScrollViewer x:Name="PageCleaner" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleCleaner" Text="Cleaner" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescCleaner" Text="Remove temporary files, usage traces, and free up disk space." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <StackPanel x:Name="CleanerPanel" HorizontalAlignment="Stretch"/>
                    <TextBlock x:Name="EmptyStateCleaner" Text="No items match your search." Foreground="{DynamicResource textMuted}" FontSize="14" Visibility="Collapsed" HorizontalAlignment="Center" Margin="0,30,0,0"/>
                    <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                        <Button x:Name="BtnCleanerSelectAll" Content="Select All" Style="{StaticResource SecondaryBtn}" Width="110"/>
                        <Button x:Name="BtnCleanerClearSelection" Content="Clear" Style="{StaticResource SecondaryBtn}" Width="90" Margin="8,0,0,0"/>
                        <Button x:Name="BtnRunCleaner" Content="Run Selected" Style="{StaticResource ActionBtn}" Margin="8,0,0,0"/>
                    </StackPanel>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PagePreferences" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitlePreferences" Text="Preferences" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescPreferences" Text="Toggle Windows settings and behavior preferences." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <primitives:UniformGrid Columns="4" x:Name="PrefsPanel" HorizontalAlignment="Stretch"/>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageTools" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleTools" Text="Tools" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescTools" Text="Quick access to Windows administration tools and utilities." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <primitives:UniformGrid Columns="4" x:Name="ToolsPanel" HorizontalAlignment="Stretch"/>
                    <TextBlock x:Name="EmptyStateTools" Text="No tools available." Foreground="{DynamicResource textMuted}" FontSize="14" Visibility="Collapsed" HorizontalAlignment="Center" Margin="0,30,0,0"/>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageSettings" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleSettings" Text="Settings" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescSettings" Text="Customize appearance and preferences." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>

                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" CornerRadius="8" Padding="16" Margin="0,0,7.5,15">
                            <StackPanel>
                                <TextBlock Text="DNS" Style="{StaticResource CategoryHeader}" Margin="0,0,0,10"/>
                                <StackPanel x:Name="DnsRadioPanel" Margin="4,0"/>
                                <Button x:Name="BtnApplyDns" Content="Apply DNS" Style="{StaticResource ActionBtn}" HorizontalAlignment="Left" Width="160" Margin="0,10,0,0"/>
                            </StackPanel>
                        </Border>
                        <StackPanel Grid.Column="1">
                            <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" CornerRadius="8" Padding="16" Margin="7.5,0,7.5,15">
                                <StackPanel>
                                    <TextBlock Text="Utilities" Style="{StaticResource CategoryHeader}" Margin="0,0,0,10"/>
                                    <Button x:Name="BtnCreateShortcut" Content="Create Desktop Shortcut" Style="{StaticResource ActionBtn}" HorizontalAlignment="Left" Width="220"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Grid>

                </StackPanel>
            </ScrollViewer>
            <Border x:Name="ProgressOverlay" Background="#80000000" CornerRadius="0" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Visibility="Collapsed">
                <StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <TextBlock x:Name="ProgressText" Text="Installing..." FontSize="18" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center"/>
                    <ProgressBar x:Name="ProgressBar" Width="320" Height="22" Margin="0,15,0,0"/>
                    <TextBlock x:Name="ProgressSubText" Text="" FontSize="12" Foreground="#CCFFFFFF" HorizontalAlignment="Center" Margin="0,8,0,0"/>
                </StackPanel>
            </Border>
        </Grid>

        <Border x:Name="StatusBar" Grid.Row="2" Background="{DynamicResource windowBackground}" BorderBrush="{DynamicResource headerBorder}" BorderThickness="0,1,0,0" Height="26">
            <TextBlock x:Name="StatusText" Text="Ready" Foreground="{DynamicResource textMuted}" FontSize="11" Padding="8,4"/>
        </Border>
    </Grid>
</Window>

'@

# ============ PRE-XAML MODULES ============

# ============ logger.ps1 ============
$script:logFilePath = ""
$script:logBuffer = [System.Collections.Generic.List[hashtable]]::new()
$script:logMaxBuffer = 500
$script:logMaxFileSize = 5MB

$script:logLevels = @{
    Debug   = 0
    Info    = 1
    Success = 2
    Warn    = 3
    Error   = 4
    Fatal   = 5
    Header  = -1
    Cmd     = -1
}

$script:logColors = @{
    Debug   = 'DarkGray'
    Info    = 'DarkGray'
    Success = 'Green'
    Warn    = 'Yellow'
    Error   = 'Red'
    Fatal   = 'Red'
    Header  = 'Cyan'
    Cmd     = 'Cyan'
}

$script:logPrefix = @{
    Debug   = 'DEBUG'
    Info    = 'INFO'
    Success = 'OK'
    Warn    = 'WARN'
    Error   = 'FAIL'
    Fatal   = 'FATAL'
    Header  = ''
    Cmd     = '>'
}

function Show-HksUtilLogo {
    Write-Host @"
HH   HH KK   KK  SSSSSS  UU   UU TTTTTT IIIIII LL
HH   HH KK  KK  SS       UU   UU   TT     II   LL
HHHHHHH KKKKK    SSSSSS  UU   UU   TT     II   LL
HH   HH KK  KK       SS  UU   UU   TT     II   LL
HH   HH KK   KK  SSSSSS   UUUUU    TT   IIIIII LLLL
"@ -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
    Write-Host "    HksUtil v$($sync.version)" -ForegroundColor Cyan
    Write-Host "    Windows Optimizer" -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
}

function Initialize-Logger {
    $dir = Join-Path $env:TEMP "HksUtil"
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    $date = Get-Date -Format "yyyyMMdd"
    $script:logFilePath = Join-Path $dir "HksUtil-$date.log"
    if (Test-Path $script:logFilePath) {
        $file = Get-Item $script:logFilePath
        if ($file.Length -gt $script:logMaxFileSize) {
            $oldPath = [System.IO.Path]::ChangeExtension($script:logFilePath, ".old")
            Move-Item $script:logFilePath $oldPath -Force
        }
    }
    $msg = "Logger initialized: $($script:logFilePath)"
    $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffK")
    Add-Content -Path $script:logFilePath -Value "$timestamp [DEBUG] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Type = "Info")
    if (-not $script:logLevels.ContainsKey($Type)) { $Type = "Info" }
    $minLevel = if ($sync.ContainsKey('logLevel') -and $script:logLevels.ContainsKey($sync.logLevel)) { $script:logLevels[$sync.logLevel] } else { 1 }
    $currentLevel = $script:logLevels[$Type]
    if ($currentLevel -ge 0 -and $currentLevel -lt $minLevel) { return }
    $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffK")
    $prefix = $script:logPrefix[$Type]
    $color = $script:logColors[$Type]
    if ($Type -eq "Header") {
        Write-Host "`n  $Message" -ForegroundColor $color
    } else {
        Write-Host ("  {0,-5} {1}" -f $prefix, $Message) -ForegroundColor $color
    }
    try {
        $logLine = if ($Type -eq "Header") { "`n$timestamp === $Message ===" } else { "$timestamp [$($prefix.PadRight(5))] $Message" }
        Add-Content -Path $script:logFilePath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { Write-Host "  Log write failed: $_" -ForegroundColor Yellow }
    if ($script:logBuffer.Count -ge $script:logMaxBuffer) { $script:logBuffer.RemoveAt(0) }
    $script:logBuffer.Add(@{ Timestamp = $timestamp; Level = $Type; Message = $Message })
}

function Get-LogBuffer {
    param([string]$Level, [int]$Count = 50)
    $result = $script:logBuffer
    if ($Level) { $result = $result | Where-Object { $_.Level -eq $Level } }
    if ($result.Count -gt $Count) { $result = $result[-$Count..-1] }
    return $result
}

function Export-Logs {
    param([string]$Path)
    try {
        Copy-Item $script:logFilePath $Path -Force
        Write-Log "Logs exported to $Path" "Success"
    } catch { Write-Log "Log export failed: $_" "Error" }
}

function Clear-Log {
    try {
        if (Test-Path $script:logFilePath) { Remove-Item $script:logFilePath -Force }
        $script:logBuffer.Clear()
    } catch {}
}

Initialize-Logger


# ============ dialog.ps1 ============
function New-DialogWindow {
    param([string]$Title, [string]$Message, [string]$DialogType = "Info")
    if ($sync.noUI) { return $null }
    $win = New-Object System.Windows.Window
    $win.Title = $Title
    $win.Width = 440; $win.Height = 220
    $win.SizeToContent = "Height"
    $win.WindowStartupLocation = "CenterOwner"
    $win.Owner = $sync.window
    $win.WindowStyle = "None"
    $win.ResizeMode = "NoResize"
    $win.AllowsTransparency = $true
    $win.Background = "#00000000"
    $win.Topmost = $true
    $border = New-Object System.Windows.Controls.Border
    $border.Background = $null
    $border.BorderBrush = $null
    $border.BorderThickness = "0"
    $border.CornerRadius = "10"
    $border.UseLayoutRounding = $true
    $outerBorder = New-Object System.Windows.Controls.Border
    $outerBorder.Background = $sync.window.TryFindResource("cardBackground")
    $outerBorder.BorderBrush = $sync.window.TryFindResource("cardBorder")
    $outerBorder.BorderThickness = "1"
    $outerBorder.CornerRadius = "10"
    $outerBorder.Padding = "24,20"
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Orientation = "Vertical"
    $titleTb = New-Object System.Windows.Controls.TextBlock
    $titleTb.Text = $Title
    $titleTb.FontSize = 18
    $titleTb.FontWeight = "Bold"
    $titleTb.Foreground = $sync.window.TryFindResource("pageTitleColor")
    $titleTb.Margin = "0,0,0,6"
    $stack.Children.Add($titleTb) | Out-Null
    $msgTb = New-Object System.Windows.Controls.TextBlock
    $msgTb.Text = $Message
    $msgTb.FontSize = 13
    $msgTb.Foreground = $sync.window.TryFindResource("cardForeground")
    $msgTb.TextWrapping = "Wrap"
    $msgTb.Margin = "0,0,0,20"
    $stack.Children.Add($msgTb) | Out-Null
    $btnStack = New-Object System.Windows.Controls.StackPanel
    $btnStack.Orientation = "Horizontal"
    $btnStack.HorizontalAlignment = "Right"
    if ($DialogType -eq "Confirm") {
        $yesBtn = New-Object System.Windows.Controls.Button
        $yesBtn.Content = "Yes"
        $yesBtn.Width = 80
        $yesBtn.Height = 32
        $yesBtn.Margin = "0,0,8,0"
        $yesBtn.Cursor = "Hand"
        $yesBtn.Style = $sync.window.FindResource("ActionBtn")
        $yesBtn.Add_Click({ $win.DialogResult = $true; $win.Close() })
        $btnStack.Children.Add($yesBtn) | Out-Null
        $noBtn = New-Object System.Windows.Controls.Button
        $noBtn.Content = "No"
        $noBtn.Width = 80
        $noBtn.Height = 32
        $noBtn.Cursor = "Hand"
        $noBtn.Style = $sync.window.FindResource("SecondaryBtn")
        $noBtn.Add_Click({ $win.DialogResult = $false; $win.Close() })
        $btnStack.Children.Add($noBtn) | Out-Null
    } else {
        $okBtn = New-Object System.Windows.Controls.Button
        $okBtn.Content = "OK"
        $okBtn.Width = 80
        $okBtn.Height = 32
        $okBtn.Cursor = "Hand"
        $okBtn.Style = $sync.window.FindResource("ActionBtn")
        $okBtn.Add_Click({ $win.DialogResult = $true; $win.Close() })
        $btnStack.Children.Add($okBtn) | Out-Null
    }
    $stack.Children.Add($btnStack) | Out-Null
    $border.Child = $stack
    $outerBorder.Child = $border
    $win.Content = $outerBorder
    $effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $effect.BlurRadius = 20
    $effect.Opacity = 0.4
    $effect.ShadowDepth = 0
    $effect.Color = [System.Windows.Media.Colors]::Black
    $outerBorder.Effect = $effect
    $win.Opacity = 0
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
    $anim.From = 0; $anim.To = 1; $anim.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
    $win.BeginAnimation([System.Windows.Window]::OpacityProperty, $anim)
    return $win
}

function Show-Confirm {
    param([string]$Title, [string]$Message)
    if ($sync.noUI) { return $true }
    $win = New-DialogWindow -Title $Title -Message $Message -DialogType "Confirm"
    if (-not $win) { return $true }
    $result = $win.ShowDialog()
    return ($result -eq $true)
}

function Show-Info {
    param([string]$Title, [string]$Message)
    if ($sync.noUI) { return }
    $win = New-DialogWindow -Title $Title -Message $Message -DialogType "Info"
    if (-not $win) { return }
    $null = $win.ShowDialog()
}


# ============ core.ps1 ============
# ============ CORE MODULE (BUG-FREE VERSION) ============

# --- GLOBAL STATE INITIALIZATION (SAFETY CHECKS) ---
if (-not $script:installedAppIds) { $script:installedAppIds = @{} }
if (-not $sync.ContainsKey('version')) { $sync.version = "2.0" }
if (-not $sync.ContainsKey('configs')) { $sync.configs = @{} }
if (-not $sync.ContainsKey('ProcessRunning')) { $sync.ProcessRunning = $false }
if (-not $sync.ContainsKey('currentTab')) { $sync.currentTab = "Install" }

# --- REGISTRY HELPER ---
function Set-RegistryValue {
    param($Path, $Name, $Value, $Type)
    if (-not $Type) {
        $Type = if ($Value -is [int] -or $Value -is [long] -or $Value -is [byte]) { "DWord" }
                elseif ($Value -is [string]) { "String" }
                else { "String" }
    }
    $validTypes = @("String","ExpandString","Binary","DWord","MultiString","QWord")
    if ($validTypes -notcontains $Type) { Write-Log "Invalid registry type: $Type" "Error"; return }
    if ($Type -in @("DWord","QWord") -and $null -eq $Value) { Write-Log "Null value not allowed for type $Type" "Error"; return }
    $parts = $Path -split '\\', 2
    if ($parts.Count -lt 2 -or $parts[0] -notmatch '^[A-Za-z]+:$') { Write-Log "Invalid registry path: $Path" "Error"; return }
    if ($parts[0] -eq "HKU:") {
        $sid = ($parts[1] -split '\\')[0]
        $drive = Get-PSDrive -Name HKU -ErrorAction SilentlyContinue
        if (-not $drive) { New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Global | Out-Null }
    }
    if (-not (Test-Path $Path)) { try { New-Item -Path $Path -Force | Out-Null } catch { Write-Log "Failed to create registry path: $_" "Error"; return } }
    if ($Value -eq "<RemoveEntry>") { try { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue } catch {}; return }
    try { Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop } catch { Write-Log "Registry write failed: $Path\$Name = $Value ($Type): $_" "Error" }
}

function Get-WpfResource { 
    param($Key) 
    try { 
        $sync.window.FindResource($Key) 
    } catch { 
        Write-Log "Missing style: $Key" "Warn" 
        $null 
    } 
}

function Invoke-WPFUIThread {
    param([ScriptBlock]$ScriptBlock)
    if ($sync.window -and $sync.window.Dispatcher -and !$sync.window.Dispatcher.CheckAccess()) {
        $sync.window.Dispatcher.Invoke([Action]{ & $ScriptBlock }, "Normal")
    } else {
        & $ScriptBlock
    }
}

function Show-Progress {
    param([string]$Text, [string]$SubText = "", [double]$Value = -1)
    if ($sync.noUI) { 
        Write-Log "[$Text] $SubText" "Info"; 
        return 
    }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread {
            if ($sync.controls["ProgressText"]) { $sync.controls["ProgressText"].Text = $Text }
            if ($sync.controls["ProgressSubText"]) { $sync.controls["ProgressSubText"].Text = $SubText }
            if ($sync.controls["ProgressBar"]) {
                if ($Value -ge 0) { 
                    $sync.controls["ProgressBar"].Value = $Value 
                    $sync.controls["ProgressBar"].IsIndeterminate = $false 
                } else { 
                    $sync.controls["ProgressBar"].IsIndeterminate = $true 
                }
            }
            if ($sync.controls["ProgressOverlay"]) { 
                $sync.controls["ProgressOverlay"].Visibility = "Visible" 
            }
        }
    }
    if (-not $sync.noUI) {
        if ($Value -ge 0) {
            Set-ProgressTaskbar -state "Normal" -value ([math]::Max(0.01, $Value))
        } else {
            Set-ProgressTaskbar -state "Indeterminate"
        }
    }
}

function Hide-Progress {
    if ($sync.noUI) { return }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread { 
            $sync.controls["ProgressOverlay"].Visibility = "Collapsed"
            foreach ($page in @("PageInstall","PageCleaner","PageTools","PagePreferences","PageSettings")) {
                if ($sync.controls[$page]) { $sync.controls[$page].Effect = $null }
            }
        }
    }
    Set-ProgressTaskbar -state "None"
}

function Set-ProgressTaskbar {
    param([string]$state = "None", [double]$value = 0)
    if ($sync.noUI) { return }
    try {
        if (-not $sync.window) { return }
        $taskbar = $sync.window.TaskbarItemInfo
        if (-not $taskbar) {
            $taskbar = New-Object System.Windows.Shell.TaskbarItemInfo
            $sync.window.TaskbarItemInfo = $taskbar
        }
        switch ($state) {
            "None" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::None }
            "Normal" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Normal; $taskbar.ProgressValue = $value }
            "Error" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Error }
            "Indeterminate" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Indeterminate }
        }
    } catch { 
        Write-Log "Taskbar progress failed: $_" "Warn" 
    }
}

# --- CORE FUNCTION: Update-InstalledCache (SAFETY FIXED) ---
function Update-InstalledCache {
    Write-Log "Updating installed apps cache..." "Info"
    $script:installedAppIds = @{}
    
    # Check winget availability with proper error handling
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        Write-Log "winget not available. Please install Windows Terminal or PowerShellGet." "Error"; 
        return 
    }
    
    try {
        # Capture output and filter only relevant lines
        $rawLines = winget list --accept-source-agreements 2>&1
        
        # Filter for installed packages (has version/id)
        $lines = @()
        foreach ($line in $rawLines) {
            if ($line -match '^\S+\s+') { 
                $lines += $line 
            }
        }
        
        # If no lines found, exit gracefully
        if (-not $lines) { 
            Write-Log "winget list returned no data. System may be empty or winget failed." "Warn"; 
            return 
        }
        
        $installedIds = @{}
        foreach ($line in $lines) {
            # winget list format: Name<2+spaces>Id<2+spaces>Version
            $parts = $line -split '\s{2,}', 3
            if ($parts.Count -ge 2) {
                $id = $parts[1].Trim()
                if ($id -and $id -ne "Id") { $installedIds[$id.ToLower()] = $true }
            }
        }
        
        foreach ($cat in $sync.configs.apps.PSObject.Properties.Name) {
            foreach ($appKey in $sync.configs.apps.$cat.PSObject.Properties.Name) {
                $id = $sync.configs.apps.$cat.$appKey.winget
                
                # Validate ID is not null/empty before checking containment
                if ($id -and $id.Trim() -ne "" -and $installedIds.ContainsKey($id.ToLower().Trim())) {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch {
        Write-Log "Installed cache update failed: $_" "Error"
    }
    
    if ($script:installedAppIds.Count -gt 0) { Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success" }
}

# --- END OF CORE MODULE ---


# ============ theme.ps1 ============
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


# ============ install.ps1 ============
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
            $chocoPath = "$env:PROGRAMDATA\chocolatey\choco.exe"
            if (-not (Test-Path $chocoPath)) {
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                $tmp = "$env:TEMP\choco-install.ps1"
                Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $tmp -UseBasicParsing
                & $tmp
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }
        if (Get-Command $Pkg -ErrorAction SilentlyContinue) { Write-Log "$Pkg installed." "Success"; return $true }
        Write-Log "$Pkg install completed but command not found." "Warn"; return $false
    } catch { Write-Log "$Pkg install failed: $_" "Error"; return $false }
}

function Register-InstallEvents {
    if ($sync.controls["BtnInstall"]) {
        $sync.controls["BtnInstall"].Add_Click({
            $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
            if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
            $pkg = $script:pkgManager
            if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
            if (-not (Show-Confirm "Install Apps" "Install $($selected.Count) application(s) via $pkg?")) { return }
            Write-Log "Starting installation via $pkg..." "Header"
            Set-Status "Installing $($selected.Count) app(s) via $pkg..."
            Show-Progress -Text "Preparing installation..." -Value 0.05
            $count = 0; $successCount = 0; $failCount = 0; $failList = @()
            foreach ($cb in $selected) {
                $id = $cb.Tag; $count++
                $percent = [math]::Max(0.05, [math]::Min(0.95, ($count / $selected.Count) * 0.9))
                Write-Log "Installing $id..." "Info"; Set-Status "Installing $id..."
                Show-Progress -Text "Installing: $id ($count/$($selected.Count))" -Value $percent
                try {
                    if ($pkg -eq "winget") { winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "winget exit code $LASTEXITCODE" } }
                    else { choco install $id -y 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "choco exit code $LASTEXITCODE" } }
                    Write-Log "Done: $id" "Success"; $successCount++
                } catch { Write-Log "Failed: $id`: $_" "Error"; $failCount++; $failList += $id }
            }
            Update-InstalledCache; Update-AppBadges
            if ($sync.controls["ChkShowInstalled"]) { Apply-Filters }
            Hide-Progress; Set-Status "Ready"
            $summary = "$successCount installed, $failCount failed."
            if ($failList.Count -gt 0) { $summary += "`n`nFailed: $($failList -join ', ')" }
            Show-Info "Installation Complete" "$pkg installation complete.`n`n$summary"
            Write-Log "Installation complete. $successCount success, $failCount failed." "Header"
            Set-ProgressTaskbar -state "Normal" -value 1
        })
    }

    if ($sync.controls["BtnUninstall"]) {
        $sync.controls["BtnUninstall"].Add_Click({
            $selected = $appCheckboxes | Where-Object { $_.IsChecked -eq $true }
            if ($selected.Count -eq 0) { Write-Log "No apps selected." "Warn"; return }
            $pkg = $script:pkgManager
            if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
            if (-not (Show-Confirm "Uninstall Apps" "Uninstall $($selected.Count) application(s) and deep clean leftovers via $pkg?`n`nThis cannot be undone!")) { return }
            Write-Log "Starting uninstallation via $pkg..." "Header"
            Set-Status "Uninstalling $($selected.Count) app(s) via $pkg..."
            Show-Progress -Text "Preparing uninstallation..." -Value 0.05
            $count = 0; $successCount = 0; $failCount = 0; $failList = @()
            foreach ($cb in $selected) {
                $id = $cb.Tag; $count++
                $percent = [math]::Max(0.05, [math]::Min(0.95, ($count / $selected.Count) * 0.9))
                Write-Log "Uninstalling $id..." "Info"; Set-Status "Uninstalling $id..."
                Show-Progress -Text "Uninstalling: $id ($count/$($selected.Count))" -Value $percent
                $ok = $true
                try {
                    if ($pkg -eq "winget") { winget uninstall --id=$id --silent --purge --accept-source-agreements 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "winget exit code $LASTEXITCODE" } }
                    else { choco uninstall $id -y 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "choco exit code $LASTEXITCODE" } }
                    Write-Log "Done: $id" "Success"; $successCount++
                } catch { Write-Log "Failed: $id`: $_" "Error"; $ok = $false; $failCount++; $failList += $id }
                if ($ok -and $pkg -eq "winget") {
                    Write-Log "Deep Cleaning $id..." "Info"; Set-Status "Cleaning $id leftovers..."
                    foreach ($term in ($id -split '\.') | Where-Object { $_.Length -gt 4 }) {
                        foreach ($basePath in @($env:APPDATA, $env:LOCALAPPDATA, $env:PROGRAMDATA)) {
                            Get-ChildItem -Path $basePath -Directory -Filter "*$term*" -ErrorAction SilentlyContinue -Depth 2 | ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force; Write-Log "Deleted: $($_.FullName)" "Success" } catch { Write-Log "Cleanup dir failed: $($_.FullName)" "Warn" } }
                        }
                        foreach ($regPath in @("HKCU:\Software", "HKLM:\SOFTWARE\WOW6432Node")) {
                            if (Test-Path $regPath) { Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue -Depth 1 | Where-Object { $_.Name.Contains($term) } | ForEach-Object { try { Remove-Item $_.PSPath -Recurse -Force; Write-Log "Deleted Reg: $($_.Name)" "Success" } catch { Write-Log "Cleanup reg failed: $($_.Name)" "Warn" } } }
                        }
                    }
                }
            }
            Update-InstalledCache; Update-AppBadges
            if ($sync.controls["ChkShowInstalled"]) { Apply-Filters }
            Hide-Progress; Set-Status "Ready"
            $summary = "$successCount uninstalled, $failCount failed."
            if ($failList.Count -gt 0) { $summary += "`n`nFailed: $($failList -join ', ')" }
            Show-Info "Uninstall Complete" "$summary"
            Write-Log "Uninstallation complete. $successCount success, $failCount failed." "Header"
        })
    }

    if ($sync.controls["PkgWinGet"]) { $sync.controls["PkgWinGet"].Add_Checked({ $script:pkgManager = "winget"; Write-Log "Package manager: WinGet" "Info" }) }
    if ($sync.controls["PkgChoco"]) { $sync.controls["PkgChoco"].Add_Checked({ $script:pkgManager = "choco"; Write-Log "Package manager: Chocolatey" "Info" }) }
}


# ============ CORE APP LOGIC ============


# Load non-UI modules early for NoUI mode compatibility

if ($script:embeddedConfigs) {
    $sync.configs = $script:embeddedConfigs
} else {
    $configPath = Join-Path $PSScriptRoot "src\config"
    Write-Log "Loading configs..." "Info"
    $configFiles = @{meta = @{}; themes = @{}; apps = @{}; dns = @{}; preferences = @{}; cleaner = @{}; legacy = @() }
    foreach ($key in $configFiles.Keys) {
        $file = Join-Path $configPath "$key.json"
        try { $sync.configs[$key] = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs[$key] = $configFiles[$key]; Write-Log "$key.json failed: $_" "Warn" }
    }
}
if ($sync.configs.meta) {
    if ($sync.configs.meta.version) { $sync.version = $sync.configs.meta.version }
    if ($sync.configs.meta.build) { $sync.build = $sync.configs.meta.build }
}
Write-Log "Config files loaded." "Success"

Show-HksUtilLogo

if ($sync.noUI) {
    if ($Config -and $Apply) {
        Write-Log "NoUI mode: applying config..." "Header"
        try {
            if ($Config -match "^https?://") { $importJson = Invoke-WebRequest -Uri $Config -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json }
            else { $importJson = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json }

            if ($importJson.AppSelections) {
                Ensure-PackageManager "winget" | Out-Null
                foreach ($id in $importJson.AppSelections) {
                    Write-Log "Headless install: $id" "Info"
                    winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) { Write-Log "Headless install failed: $id (exit $LASTEXITCODE)" "Error" }
                }
            }

            if ($importJson.CleanerSelections) {
                foreach ($ck in $importJson.CleanerSelections) {
                    $cleaner = $null
                    foreach ($g in $sync.configs.cleaner.PSObject.Properties.Name) {
                        if ($sync.configs.cleaner.$g.PSObject.Properties.Name -contains $ck) { $cleaner = $sync.configs.cleaner.$g.$ck; break }
                    }
                    if ($cleaner -and $cleaner.script) { Write-Log "Headless cleaner: $($cleaner.content)" "Info"; & ([scriptblock]::Create($cleaner.script)) }
                }
            }

            if ($importJson.PreferenceStates) {
                foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) {
                    $pref = $sync.configs.preferences.$pk
                    if (-not $pref) { continue }
                    $entries = if ($importJson.PreferenceStates.$pk) { $pref.registry_on } else { $pref.registry_off }
                    foreach ($reg in $entries) {
                        Set-RegistryValue -Path $reg.path -Name $reg.name -Value $reg.value
                    }
                    Write-Log "Headless pref: $($pref.content) = $($importJson.PreferenceStates.$pk)" "Info"
                }
            }

            Write-Log "Headless apply complete." "Success"
        } catch { Write-Log "Headless apply failed: $_" "Error" }
    } else { Write-Log "NoUI mode: use -Config <path> -Apply." "Warn" }
    pause; exit
}

if ($script:embeddedXaml) {
    $xamlContent = $script:embeddedXaml -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync.window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} else {
    try {
        $xamlPath = Join-Path $PSScriptRoot "src\ui.xaml"
        $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
        $xamlContent = $xamlContent -replace 'x:Name="([^"]+)"', 'Name="$1"'
        [xml]$xaml = $xamlContent
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $sync.window = [Windows.Markup.XamlReader]::Load($reader)
        $reader.Close()
    } catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }
}

$xaml.SelectNodes("//*[@Name]") | ForEach-Object { $sync.controls[$_.Name] = $sync.window.FindName($_.Name) }
foreach ($k in @($sync.controls.Keys)) { if (-not $sync.controls[$k]) { $sync.controls.Remove($k) } }

$buildSuffix = if ($sync.build) { " (build $($sync.build))" } else { "" }
$sync.window.Title = "HksUtil v$($sync.version)$buildSuffix - Windows Optimizer"
if ($sync.controls["TitleVersionText"]) { $sync.controls["TitleVersionText"].Text = "v$($sync.version)$buildSuffix" }
Apply-Theme "light"
if ($sync.controls["TitleText"]) { $sync.controls["TitleText"].Add_MouseLeftButtonDown({ try { $sync.window.DragMove() } catch { } }) }

Update-InstalledCache


# ============ POST-XAML MODULES ============

# ============ navigation.ps1 ============
if (-not $script:pages) { $script:pages = @{} }
if (-not $script:navButtons) { $script:navButtons = @{} }
if (-not $script:navNames) { $script:navNames = @("Install", "Cleaner", "Tools", "Preferences", "Settings") }

function Show-NavPanel {
    param($Name)
    $previousPage = $sync.currentTab
    foreach ($other in $script:navNames) {
        if ($sync.controls["Page$other"] -and $other -ne $Name) { 
            $sync.controls["Page$other"].Visibility = "Collapsed"
            $sync.controls["Page$other"].Opacity = 1
        }
    }
    if ($sync.controls["Page$Name"]) { 
        $sync.controls["Page$Name"].Visibility = "Visible"
        $sync.controls["Page$Name"].Opacity = 0
        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.From = 0; $anim.To = 1; $anim.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
        $sync.controls["Page$Name"].BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
        $sync.currentTab = $Name; Write-Log "Switched to: $Name" "Info"
        if ($sync.controls["SearchBox"] -and $sync.controls["SearchBox"].Text) {
            $sync.controls["SearchBox"].Text = ""
        }
        Update-SelectedCount
    }
    if ($sync.configs.themes -and $script:currentTheme) {
        $colors = $sync.configs.themes.$script:currentTheme
        $converter = [System.Windows.Media.BrushConverter]::new()
        try {
            $activeBrush = $converter.ConvertFrom($colors.accentColor)
            $mutedBrush = $converter.ConvertFrom($colors.textMuted)
            foreach ($n in $script:navNames) {
                $btn = $sync.controls["Nav$n"]
                if ($btn) {
                    if ($n -eq $Name) {
                        $btn.Foreground = $activeBrush
                        $btn.FontWeight = "Bold"
                    } else {
                        $btn.Foreground = $mutedBrush
                        $btn.FontWeight = "Normal"
                    }
                }
            }
        } catch { Write-Log "Nav highlight failed: $_" "Warn" }
    }
}

function Switch-Page { param($Name); Show-NavPanel $Name }

if ($sync.controls.Count) {
    foreach ($n in $script:navNames) {
        if ($sync.controls["Page$n"]) { $script:pages[$n] = $sync.controls["Page$n"] }
        if ($sync.controls["Nav$n"]) { $script:navButtons[$n] = $sync.controls["Nav$n"] }
    }
    foreach ($navName in $script:navNames) {
        $btnName = "Nav$navName"
        $btn = $sync.controls[$btnName]
        if ($btn) {
            $btn.Tag = $navName
            $btn.Add_Click({ Show-NavPanel $this.Tag })
            if ($btn.PSObject.Properties.Name -contains "IsEnabled") { $btn.IsEnabled = $true }
            Write-Log "Navigation: $btnName wired." "Success"
        }
    }
    if ($sync.window) { $sync.window.Add_KeyDown({
        param($sender, $e)
            $navMap = @{ I = "Install"; C = "Cleaner"; T = "Tools"; P = "Preferences"; S = "Settings"; Q = "Install" }
            if ($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Alt -and $navMap.ContainsKey([string]$e.Key)) {
                Show-NavPanel $navMap[[string]$e.Key]
                $e.Handled = $true; return
            }
            if ($e.Key -eq "Escape" -and $sync.controls["SearchBox"]) {
                $sync.controls["SearchBox"].Text = ""
                Show-NavPanel $script:navNames[0]
                $e.Handled = $true
            }
        })
    }
}


# ============ search.ps1 ============
function Apply-Filters {
    Write-Log "Applying search filters..." "Info"
    $filter = if ($sync.controls["SearchBox"]) { $sync.controls["SearchBox"].Text.ToLower() } else { "" }
    $showInstalled = $sync.controls["ChkShowInstalled"] -and $sync.controls["ChkShowInstalled"].IsChecked
    $currentTab = $sync.currentTab
    
    # Filter app checkboxes on Install page
    if ($currentTab -eq "Install") {
        foreach ($cb in $appCheckboxes) {
            $isVisible = $true
            if ($showInstalled) {
                $id = if ($cb.Tag -ne $null) { $cb.Tag.ToString() } else { "" }
                $isVisible = $isVisible -and $script:installedAppIds.ContainsKey($id)
            }
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
        }
    }
    
    # Filter checkboxes on Cleaner page (nested in per-category UniformGrids)
    if ($currentTab -eq "Cleaner") {
        foreach ($cb in $cleanerCheckboxes) {
            $isVisible = $true
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $tooltip = if ($cb.ToolTip -ne $null) { $cb.ToolTip.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter) -or $tooltip.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
        }
    }
    
    # Filter checkboxes on Preferences page
    if ($currentTab -eq "Preferences" -and $sync.controls["PrefsPanel"]) {
        foreach ($cb in $sync.controls["PrefsPanel"].Children) {
            if ($cb -isnot [System.Windows.Controls.CheckBox]) { continue }
            $isVisible = $true
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $tooltip = if ($cb.ToolTip -ne $null) { $cb.ToolTip.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter) -or $tooltip.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
        }
    }
    
    # Filter tool buttons
    if ($currentTab -eq "Tools") {
        foreach ($panelName in @("ToolsPanel")) {
            if (-not $sync.controls[$panelName]) { continue }
            foreach ($btn in $sync.controls[$panelName].Children) {
                if ($btn -isnot [System.Windows.Controls.Button]) { continue }
                $isVisible = $true
                if ($filter) {
                    $content = if ($btn.Content -ne $null) { 
                        $tb = $btn.Content
                        if ($tb -is [System.Windows.Controls.StackPanel]) {
                            $innerSp = $tb.Children | Where-Object { $_ -is [System.Windows.Controls.StackPanel] } | Select-Object -First 1
                            if ($innerSp) { $firstChild = $innerSp.Children | Select-Object -First 1; if ($firstChild -is [System.Windows.Controls.TextBlock]) { $firstChild.Text.ToLower() } else { "" } } else { "" }
                        } else { "" }
                    } else { "" }
                    $tooltip = if ($btn.ToolTip -ne $null) { $btn.ToolTip.ToString().ToLower() } else { "" }
                    $isVisible = $isVisible -and ($content.Contains($filter) -or $tooltip.Contains($filter))
                }
                try { $btn.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { }
            }
        }
    }
    
    # Empty state
    $anyVisible = $false
    if ($currentTab -eq "Install") { $anyVisible = ($appCheckboxes | Where-Object { $_.Visibility -eq "Visible" }).Count -gt 0 }
    elseif ($currentTab -eq "Cleaner") { $anyVisible = ($cleanerCheckboxes | Where-Object { $_.Visibility -eq "Visible" }).Count -gt 0 }
    elseif ($currentTab -eq "Preferences") {
        $anyVisible = @($prefCheckboxes.Values | Where-Object { $_.Visibility -eq "Visible" }).Count -gt 0
    }
    if ($sync.controls["EmptyState$currentTab"]) { $sync.controls["EmptyState$currentTab"].Visibility = if ($filter -and -not $anyVisible) { "Visible" } else { "Collapsed" } }
    
    if ($sync.controls["SearchHint"]) { $sync.controls["SearchHint"].Visibility = if ($filter) { "Collapsed" } else { "Visible" } }
    Write-Log "Filters applied." "Success"
}

if ($sync.controls["SearchBox"]) {
    $sync.controls["SearchBox"].Add_TextChanged({ Apply-Filters })
}
if ($sync.controls["BtnClearSearch"]) {
    $sync.controls["BtnClearSearch"].Add_Click({
        $sync.controls["SearchBox"].Text = ""
        Apply-Filters
    })
}


# ============ toolbar.ps1 ============
if ($sync.controls["BtnToolbarClose"]) {
    $sync.controls["BtnToolbarClose"].Add_Click({ $sync.window.Close() })
}

if ($sync.controls["BtnToolbarMinimize"]) {
    $sync.controls["BtnToolbarMinimize"].Add_Click({ $sync.window.WindowState = "Minimized" })
}

if ($sync.controls["BtnToolbarMaximize"]) {
    $sync.controls["BtnToolbarMaximize"].Add_Click({
        $sync.window.WindowState = if ($sync.window.WindowState -eq "Maximized") { "Normal" } else { "Maximized" }
    })
}

if ($sync.controls["GearPopup"]) {
    $sync.controls["GearPopup"].Add_Closed({ if ($sync.controls["BtnToolbarSettings"]) { $sync.controls["BtnToolbarSettings"].IsChecked = $false } })
}

if ($sync.controls["BtnGearExport"]) {
    $sync.controls["BtnGearExport"].Add_Click({
        try {
            $sfd = New-Object Microsoft.Win32.SaveFileDialog
            $sfd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $sfd.Title = "Export Config"
            $sfd.FileName = "HksUtil-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).json"
            $sfd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $sfd.ShowDialog($sync.window)
            if ($result -ne $true) { return }
            $data = @{
                AppSelections = @($appCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
                CleanerSelections = @($cleanerCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
            }
            $prefState = @{}
            foreach ($pk in $prefCheckboxes.Keys) {
                if ($prefCheckboxes[$pk]) { $prefState[$pk] = ($prefCheckboxes[$pk].IsChecked -eq $true) }
            }
            $data.PreferenceStates = $prefState
            $json = $data | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($sfd.FileName, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Log "Exported to $($sfd.FileName)" "Success"
            Show-Info "Export Complete" "Config exported to:`n$($sfd.FileName)"
        } catch { Write-Log "Export failed: $_" "Error" }
        if ($sync.controls["BtnToolbarSettings"]) { $sync.controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($sync.controls["BtnGearImport"]) {
    $sync.controls["BtnGearImport"].Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        try {
            $ofd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $ofd.Title = "Import Config"
            $ofd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $ofd.ShowDialog($sync.window)
            if ($result -ne $true) { return }
            $json = [System.IO.File]::ReadAllText($ofd.FileName, [System.Text.UTF8Encoding]::new($false))
            $data = $json | ConvertFrom-Json

            # NEW format: AppSelections (array of winget IDs)
            if ($data.AppSelections) {
                foreach ($aid in $data.AppSelections) {
                    $cb = $appCheckboxes | Where-Object { $_.Tag -eq $aid }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            # OLD format: CheckedApps (array of {Name, Content})
            if ($data.CheckedApps) {
                foreach ($appEntry in $data.CheckedApps) {
                    $cb = $appCheckboxes | Where-Object { $_.Tag -eq $appEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            if ($data.CleanerSelections) {
                foreach ($ck in $data.CleanerSelections) {
                    $cb = $cleanerCheckboxes | Where-Object { $_.Tag -eq $ck }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            if ($data.PreferenceStates) {
                foreach ($pk in $data.PreferenceStates.PSObject.Properties.Name) {
                    if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $data.PreferenceStates.$pk -eq $true }
                }
            }

            Write-Log "Imported from $($ofd.FileName)" "Success"
            Show-Info "Import Complete" "Configuration imported."
        } catch { Write-Log "Import failed: $_" "Error" }
        if ($sync.controls["BtnToolbarSettings"]) { $sync.controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($sync.controls["BtnGearAbout"]) {
    $sync.controls["BtnGearAbout"].Add_Click({
        Show-Info "About HksUtil v$($sync.version)" "HksUtil v$($sync.version) - Windows Optimizer`n`nA Windows utility for application management, system tweaks, DNS configuration, and more.`n`nBuilt with PowerShell and WPF."
        if ($sync.controls["BtnToolbarSettings"]) { $sync.controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($sync.controls["BtnGearDocs"]) {
    $sync.controls["BtnGearDocs"].Add_Click({
        Start-Process "https://github.com/hartkitsak/HksUtil"
        if ($sync.controls["BtnToolbarSettings"]) { $sync.controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($sync.controls["BtnGearSponsors"]) {
    $sync.controls["BtnGearSponsors"].Add_Click({
        Show-Info "Sponsors" "HksUtil is an open-source project.`n`nIf you find this tool useful, consider supporting the project."
        if ($sync.controls["BtnToolbarSettings"]) { $sync.controls["BtnToolbarSettings"].IsChecked = $false }
    })
}


# ============ dns.ps1 ============
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

        $hasNetAdapter = Get-Command Get-NetAdapter -ErrorAction SilentlyContinue
        if (-not $hasNetAdapter) {
            try { Import-Module NetAdapter -ErrorAction Stop; $hasNetAdapter = $true } catch { $hasNetAdapter = $false }
        }

        if (-not $hasNetAdapter) {
            Write-Log "Get-NetAdapter unavailable; using netsh." "Info"
            $adapters = @()
            try { $nics = netsh interface show interface | Select-String 'Connected' | ForEach-Object { ($_ -split '\s{2,}')[-1].Trim() } } catch {}
            if ($nics.Count -eq 0) { Write-Log "No active network adapter found." "Error"; Hide-Progress; return }
            if ($dnsName -eq "Default_DHCP") {
                if (-not (Show-Confirm "Reset DNS" "Reset DNS to default DHCP on all adapters?")) { Hide-Progress; return }
                Write-Log "Resetting DNS to DHCP via netsh..." "Info"
                try { foreach ($n in $nics) { netsh interface ip set dns "$n" dhcp }; Write-Log "DNS reset to DHCP." "Success"; Hide-Progress; Show-Info "DNS Reset" "DNS has been reset to DHCP." } catch { Write-Log "Failed to reset DNS via netsh: $_" "Error"; Hide-Progress }
                return
            }
            if (-not (Show-Confirm "Apply DNS" "Set DNS to $dnsName?`n`nIPv4: $($ipv4 -join ', ')") ) { Hide-Progress; return }
            Show-Progress -Text "Applying $dnsName via netsh..." -Value 0.6
            try {
                foreach ($n in $nics) {
                    netsh interface ip set dns "$n" static $($ipv4[0])
                    for ($i = 1; $i -lt $ipv4.Count; $i++) { netsh interface ip add dns "$n" $($ipv4[$i]) index=$($i+1) }
                }
                Write-Log "DNS set to $dnsName via netsh." "Success"; Hide-Progress; Show-Info "DNS Applied" "DNS set to $dnsName via netsh.`n$($ipv4 -join ', ')"
            } catch { Write-Log "Failed to set DNS via netsh: $_" "Error"; Hide-Progress }
            return
        }

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


# ============ utility.ps1 ============
if ($sync.controls["BtnCreateShortcut"]) {
    $sync.controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $scriptPath = if ($PSCommandPath -and (Test-Path $PSCommandPath)) { $PSCommandPath } else { Join-Path $script:appRoot "app.ps1" }
            if (-not (Test-Path $scriptPath)) {
                Show-Info "Shortcut Failed" "Cannot locate script at:`n$scriptPath`n`nUse -Dev mode, or save hksutil.ps1 to disk first."
                return
            }
            $target = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $cmd = "Start-Process powershell.exe -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`"'"
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
            $shortcutArgs = "-ExecutionPolicy Bypass -NoProfile -EncodedCommand $encoded"

            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $shortcut.TargetPath = $target
            $shortcut.Arguments = $shortcutArgs
            $shortcut.Description = "HksUtil v$($sync.version) - Windows Optimizer"
            $shortcut.WorkingDirectory = (Split-Path $scriptPath -Parent)
            $shortcut.IconLocation = "$([Environment]::SystemDirectory)\imageres.dll, 109"
            $shortcut.WindowStyle = 7
            $shortcut.Save()

            Write-Log "Desktop shortcut created (elevated)." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}


# ============ build.ps1 ============
$appCheckboxes = @()
$cleanerCheckboxes = @()
$prefCheckboxes = @{}
$script:categoryItems = @{}
$script:categoryGrids = @{}
$script:categoryCollapsed = @{}

# --- Build Apps UI ---
if ($sync.controls["AppPanel"] -and $sync.configs.apps) {
    foreach ($category in $sync.configs.apps.PSObject.Properties.Name) {
        $catCount = ($sync.configs.apps.$category.PSObject.Properties.Name).Count
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = "- $($category.ToUpper()) ($catCount)"; $header.Style = Get-WpfResource "CategoryHeader"; $header.Cursor = "Hand"
        $header.Tag = $category
        $sync.controls["AppPanel"].Children.Add($header) | Out-Null
        $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
        $grid.Columns = 4; $grid.HorizontalAlignment = "Stretch"
        $sync.controls["AppPanel"].Children.Add($grid) | Out-Null
        $script:categoryItems[$category] = @()
        $script:categoryGrids[$category] = $grid
        $script:categoryCollapsed[$category] = $false
        $header.Add_MouseLeftButtonDown({
            $cat = $this.Tag
            $script:categoryCollapsed[$cat] = -not $script:categoryCollapsed[$cat]
            $g = $script:categoryGrids[$cat]
            if ($g) { $g.Visibility = if ($script:categoryCollapsed[$cat]) { "Collapsed" } else { "Visible" } }
            $this.Text = if ($script:categoryCollapsed[$cat]) { "+ $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" } else { "- $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" }
        })
        foreach ($appKey in $sync.configs.apps.$category.PSObject.Properties.Name) {
            $app = $sync.configs.apps.$category.$appKey
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $app.winget; $cb.Style = Get-WpfResource "TweakCheckBox"
            $id = $app.winget
            $isInstalled = $id -and $script:installedAppIds.ContainsKey($id)
            $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
            $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = $app.content; $nameTb.VerticalAlignment = "Center"
            $sp.Children.Add($nameTb) | Out-Null
            if ($isInstalled) {
                $badge = New-Object System.Windows.Controls.TextBlock; $badge.Text = " ✓"; $badge.Foreground = [System.Windows.Media.Brushes]::LimeGreen; $badge.FontSize = 12; $badge.FontWeight = "Bold"; $badge.VerticalAlignment = "Center"; $badge.ToolTip = "Installed"
                $sp.Children.Add($badge) | Out-Null
            }
            $cb.Content = $sp
            if ($app.description) { $cb.ToolTip = "$($app.content)`n`n$($app.description)`n`nID: $($app.winget)" }
            $cb.Add_Checked({ Update-SelectedCount })
            $cb.Add_Unchecked({ Update-SelectedCount })
            $cm = New-Object System.Windows.Controls.ContextMenu
            $miInstall = New-Object System.Windows.Controls.MenuItem; $miInstall.Header = "Install"; $miInstall.Tag = $app.winget
            $miInstall.Add_Click({
                $id = $this.Tag; $pkg = $script:pkgManager; Write-Log "Context: Install $id via $pkg" "Info"
                if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
                if (-not (Show-Confirm "Install" "Install $id via $pkg?")) { return }
                Show-Progress -Text "Installing: $id" -Value 0.5
                try { if ($pkg -eq "winget") { winget install --id=$id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null } else { choco install $id -y 2>&1 | Out-Null }; Write-Log "Installed: $id" "Success" } catch { Write-Log "Failed: $id" "Error" }
                Hide-Progress; Update-InstalledCache; Show-Info "Done" "Install of $id completed."
            })
            $miUninstall = New-Object System.Windows.Controls.MenuItem; $miUninstall.Header = "Uninstall"; $miUninstall.Tag = $app.winget
            $miUninstall.Add_Click({
                $id = $this.Tag; $pkg = $script:pkgManager; Write-Log "Context: Uninstall $id via $pkg" "Info"
                if (-not (Ensure-PackageManager $pkg)) { Show-Info "Error" "Failed to ensure $pkg."; return }
                if (-not (Show-Confirm "Uninstall" "Uninstall $id via $pkg?")) { return }
                Show-Progress -Text "Uninstalling: $id" -Value 0.5
                try { if ($pkg -eq "winget") { winget uninstall --id=$id --silent --purge --accept-source-agreements 2>&1 | Out-Null } else { choco uninstall $id -y 2>&1 | Out-Null }; Write-Log "Uninstalled: $id" "Success" } catch { Write-Log "Failed: $id" "Error" }
                Hide-Progress; Update-InstalledCache; Show-Info "Done" "Uninstall of $id completed."
            })
            $miInfo = New-Object System.Windows.Controls.MenuItem; $miInfo.Header = "Info"; $miInfo.Tag = $app
            $miInfo.Add_Click({ $a = $this.Tag; Show-Info "App Info" "$($a.content)`n`nID: $($a.winget)`n$($a.description)" })
            $null = $cm.Items.Add($miInstall); $null = $cm.Items.Add($miUninstall); $null = $cm.Items.Add((New-Object System.Windows.Controls.Separator)); $null = $cm.Items.Add($miInfo)
            $cb.ContextMenu = $cm
            $grid.Children.Add($cb) | Out-Null
            $appCheckboxes += $cb
            $script:categoryItems[$category] += $cb
        }
    }
    foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false }
    Write-Log "Built $($appCheckboxes.Count) app cards." "Success"
}

function Update-AppBadges {
    if (-not $script:installedAppIds -or $appCheckboxes.Count -eq 0) { return }
    foreach ($cb in $appCheckboxes) {
        $id = if ($cb.Tag -ne $null) { $cb.Tag.ToString() } else { "" }
        if ($cb.Content -isnot [System.Windows.Controls.StackPanel]) { continue }
        $sp = $cb.Content
        $existingBadges = @($sp.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] -and $_.Text -eq " ✓" })
        foreach ($b in $existingBadges) { $sp.Children.Remove($b) }
        if ($id -and $script:installedAppIds.ContainsKey($id)) {
            $badge = New-Object System.Windows.Controls.TextBlock; $badge.Text = " ✓"; $badge.Foreground = [System.Windows.Media.Brushes]::LimeGreen; $badge.FontSize = 12; $badge.FontWeight = "Bold"; $badge.VerticalAlignment = "Center"; $badge.ToolTip = "Installed"
            $null = $sp.Children.Add($badge)
        }
    }
}

# --- Build Preferences UI ---
if ($sync.controls["PrefsPanel"] -and $sync.configs.preferences) {
    foreach ($prefKey in $sync.configs.preferences.PSObject.Properties.Name) {
        $pref = $sync.configs.preferences.$prefKey
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $pref.content; $cb.Tag = $prefKey; $cb.Style = Get-WpfResource "ToggleSwitch"
        if ($pref.description) { $cb.ToolTip = $pref.description }
        $hasRegistryOn = $pref.PSObject.Properties.Name -contains "registry_on" -and $pref.registry_on -and $pref.registry_on.Count -gt 0
        if ($hasRegistryOn) {
            $allMatch = $true
            foreach ($r in $pref.registry_on) {
                if (Test-Path $r.path) { try { $val = (Get-ItemProperty $r.path -Name $r.name -ErrorAction SilentlyContinue).$($r.name); if ($val -ne $r.value) { $allMatch = $false; break } } catch { $allMatch = $false; break } }
                else { $allMatch = $false; break }
            }
        }
        $cb.IsChecked = if ($hasRegistryOn) { $allMatch } else { $false }
        $cb.Add_Checked({
            $pk = $this.Tag; $p = $sync.configs.preferences.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_on") { foreach ($r in $p.registry_on) { Set-RegistryValue -Path $r.path -Name $r.name -Value $r.value } }
            Write-Log "Pref ON: $($p.content)" "Success"
        })
        $cb.Add_Unchecked({
            $pk = $this.Tag; $p = $sync.configs.preferences.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_off") { foreach ($r in $p.registry_off) { Set-RegistryValue -Path $r.path -Name $r.name -Value $r.value } }
            Write-Log "Pref OFF: $($p.content)" "Warn"
        })
        $sync.controls["PrefsPanel"].Children.Add($cb) | Out-Null
        $prefCheckboxes[$prefKey] = $cb
    }
    Write-Log "Built $($prefCheckboxes.Count) preference toggles." "Success"
}

# --- Build Cleaner UI ---
if ($sync.controls["CleanerPanel"] -and $sync.configs.cleaner) {
    foreach ($grpKey in $sync.configs.cleaner.PSObject.Properties.Name) {
        $header = New-Object System.Windows.Controls.TextBlock; $header.Text = $grpKey; $header.Style = Get-WpfResource "CategoryHeader"
        $sync.controls["CleanerPanel"].Children.Add($header) | Out-Null
        $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
        $grid.Columns = 4; $grid.HorizontalAlignment = "Stretch"
        $sync.controls["CleanerPanel"].Children.Add($grid) | Out-Null
        foreach ($ck in $sync.configs.cleaner.$grpKey.PSObject.Properties.Name) {
            $c = $sync.configs.cleaner.$grpKey.$ck
            $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $c.content; $cb.Tag = $ck; $cb.Style = Get-WpfResource "TweakCheckBox"
            if ($c.description) { $cb.ToolTip = $c.description }
            $grid.Children.Add($cb) | Out-Null
            $cleanerCheckboxes += $cb
        }
    }
    Write-Log "Built $($cleanerCheckboxes.Count) cleaner checkboxes." "Success"
}

# --- Build System Tools UI ---
if ($sync.controls["ToolsPanel"] -and $sync.configs.legacy) {
    foreach ($panel in $sync.configs.legacy) {
        $desc = if ($panel.PSObject.Properties.Name -contains "description") { $panel.description } else { "" }
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "ToolCard"; $btn.ToolTip = "$($panel.content)`n$desc`n`nLaunch: $($panel.command)"; $btn.Tag = $panel.command; $btn.HorizontalAlignment = "Stretch"
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
        $textSp = New-Object System.Windows.Controls.StackPanel; $textSp.Orientation = "Vertical"; $textSp.VerticalAlignment = "Center"
        $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = $panel.content; $nameTb.FontSize = 14; $nameTb.FontWeight = "SemiBold"; $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor"); $textSp.Children.Add($nameTb) | Out-Null
        $descTb = New-Object System.Windows.Controls.TextBlock; $descTb.Text = $desc; $descTb.FontSize = 11; $descTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted"); $descTb.TextWrapping = "Wrap"; $textSp.Children.Add($descTb) | Out-Null
        $sp.Children.Add($textSp) | Out-Null; $btn.Content = $sp
        $btn.Add_Click({
            $cmd = $this.Tag; Write-Log "Launching: $cmd" "Info"
            try {
                $parts = $cmd -split ' ', 2
                $exe = $parts[0]; $args = if ($parts.Count -gt 1) { $parts[1] } else { $null }
                if ($args) { Start-Process $exe -ArgumentList $args -ErrorAction Stop } else { Start-Process $exe -ErrorAction Stop }
                Write-Log "Launched: $cmd" "Success"
            } catch { Write-Log "Failed to launch ${cmd}: $_" "Error"; Show-Info "Error" "Failed to launch $cmd`n`n$_" }
        })
        $sync.controls["ToolsPanel"].Children.Add($btn) | Out-Null
    }
    Write-Log "Built $($sync.configs.legacy.Count) system tool buttons." "Success"
}


# ============ status.ps1 ============
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


# ============ cleaner.ps1 ============
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


# ============ APP FINALIZATION ============
Register-InstallEvents

if ($sync.controls["BtnSelectAll"]) { $sync.controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" }) }
if ($sync.controls["BtnClearSelection"]) { $sync.controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" }) }
if ($sync.controls["BtnCleanerSelectAll"]) { $sync.controls["BtnCleanerSelectAll"].Add_Click({ foreach ($cb in $cleanerCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Write-Log "All visible cleaner items selected." "Info" }) }
if ($sync.controls["BtnCleanerClearSelection"]) { $sync.controls["BtnCleanerClearSelection"].Add_Click({ foreach ($cb in $cleanerCheckboxes) { $cb.IsChecked = $false }; Write-Log "Cleaner selection cleared." "Info" }) }
if ($sync.controls["BtnCollapseAll"]) {
    $sync.controls["BtnCollapseAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) {
            $script:categoryCollapsed[$cat] = $true
            if ($script:categoryGrids[$cat]) { $script:categoryGrids[$cat].Visibility = "Collapsed" }
        }
        foreach ($panel in @($sync.controls["AppPanel"])) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($sync.controls["BtnExpandAll"]) {
    $sync.controls["BtnExpandAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) {
            $script:categoryCollapsed[$cat] = $false
            if ($script:categoryGrids[$cat]) { $script:categoryGrids[$cat].Visibility = "Visible" }
        }
        foreach ($panel in @($sync.controls["AppPanel"])) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($sync.controls["ChkShowInstalled"]) {
    $sync.controls["ChkShowInstalled"].Add_Checked({
        Write-Log "Filtering to installed apps..." "Info"
        if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }
        Apply-Filters
    })
    $sync.controls["ChkShowInstalled"].Add_Unchecked({ Apply-Filters })
}

Update-AppBadges
Switch-Page "Install"
Set-Status "Ready"
Update-InstalledCache
Write-Log "GUI Loaded. Waiting for input..." "Success"

if ($Config -and -not $Apply) {
    Write-Log "Loading config: $Config" "Header"
    try {
        if ($Config -match "^https?://") { $importJson = Invoke-WebRequest -Uri $Config -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json }
        elseif (Test-Path $Config) { $importJson = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json }
        else { Write-Log "Config path not found: $Config" "Warn"; $importJson = $null }
        if ($importJson) {
            if ($importJson.AppSelections) { foreach ($cb in $appCheckboxes) { $cb.IsChecked = @($importJson.AppSelections) -contains $cb.Tag } }
            if ($importJson.CheckedApps) { foreach ($appEntry in $importJson.CheckedApps) { $cb = $appCheckboxes | Where-Object { $_.Tag -eq $appEntry.Name }; if ($cb) { $cb.IsChecked = $true } } }
            if ($importJson.CleanerSelections) { foreach ($cb in $cleanerCheckboxes) { $cb.IsChecked = @($importJson.CleanerSelections) -contains $cb.Tag } }
            if ($importJson.PreferenceStates) { foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) { if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $importJson.PreferenceStates.$pk -eq $true } } }
            Update-SelectedCount; Write-Log "Config loaded from $Config" "Success"
        }
    } catch { Write-Log "Config load failed: $_" "Error" }
}

$sync.window.Add_Closing({
    [System.GC]::Collect()
})

try { $sync.window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"
