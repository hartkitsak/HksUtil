# HksUtil v2.0

A Windows optimization and app management tool built with PowerShell and WPF. Dark/Light themed GUI for installing apps, applying tweaks, running system fixes, and more.

## Quick Start

```powershell
irm "https://raw.githubusercontent.com/hartkitsak/HksUtil/main/launcher.ps1" | iex
```

Or clone and run locally:

```powershell
git clone https://github.com/hartkitsak/HksUtil.git
cd HksUtil
.\app.ps1
```

## Features

### 📦 Install Apps
Browse and install/uninstall applications via **WinGet** or **Chocolatey**. Search by name, filter by installed status, collapse categories. Apps are organized into categories and displayed in a 3-column grid.

### ⚙️ System Tweaks
Apply or undo Windows tweaks with one click. Categories include:
- **Performance** — Disable Superfetch, disable search indexing, high performance power plan, visual effects tuning
- **Privacy** — Disable telemetry, activity history, location tracking
- **Essential Tweaks** — Telemetry & services, remove pre-installed apps, disk cleanup, widgets removal, WPBT disable, and more
- **UI** — Small taskbar icons

### 🔧 Features & Fixes
- **Windows Features** — Enable .NET Framework, Hyper-V, WSL2, Windows Sandbox, NFS, legacy media components, registry backup tasks
- **Fixes** — AutoLogon, network reset, NTP sync, SFC scan, Windows Update reset, WinGet reinstall

### 🎛️ Preferences
Toggle registry-based Windows settings on/off:
BSoD verbose mode, taskbar alignment, search icon, dark theme, file extensions, hidden files, S3 sleep, battery percentage, scrollbars, sticky keys, Num Lock, mouse acceleration, and more.

### 🧹 Clean
Clean temp files and Windows Update cache.

### 🖥️ Legacy Panels
Quick access to classic Windows control panel tools.

### ⚙️ Settings
- **Theme** — Dark / Light mode
- **DNS** — Switch DNS providers (Google, Cloudflare, OpenDNS, Quad9, AdGuard)
- **Export/Import** — Save and restore app selections and preferences

## Requirements

- Windows 10 / Windows 11
- PowerShell 5.1+ or PowerShell 7+
- WinGet (built-in on Windows 11 and latest Windows 10)
- Internet connection for first run

## Project Structure

```
HksUtil/
├── app.ps1              # Main script (WPF GUI + logic)
├── ui.xaml              # XAML layout
├── launcher.ps1         # Bootstrap for irm | iex
├── config/
│   ├── apps.json        # Application catalog
│   ├── tweaks.json      # Tweak definitions
│   ├── features.json    # Features & fixes
│   ├── preferences.json # Registry-based toggles
│   ├── themes.json      # Dark/Light color schemes
│   └── dns.json         # DNS provider list
└── Tweaks/              # Tweak documentation
```

## Customization

Edit the JSON files in `config/` to add your own apps, tweaks, or preferences. The app catalog in `apps.json` follows this structure:

```json
{
  "CategoryName": {
    "app_key": {
      "content": "Display Name",
      "winget": "Publisher.PackageName",
      "description": "Tooltip description"
    }
  }
}
```

## License

MIT
