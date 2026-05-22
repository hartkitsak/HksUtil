# HksUtil v2.0

A Windows optimization tool built with PowerShell and WPF. Install apps, apply system tweaks, run cleanup, and more — all from a modern GUI.

## Features

- **Install Apps** — Browse and install/uninstall apps via WinGet or Chocolatey
- **System Tweaks** — Apply/undo Windows tweaks with one click
- **Features & Fixes** — Enable Windows features and run system fixes
- **Preferences** — Toggle Windows settings and behaviors
- **Clean** — Remove temp files and update cache
- **Legacy Panels** — Quick access to classic Windows control panels
- **Settings** — Theme (Dark/Light), DNS management, config export/import

## Usage

```powershell
irm "https://raw.githubusercontent.com/YOUR_USER/HksUtil/main/launcher.ps1" | iex
```

Or clone and run locally:

```powershell
git clone https://github.com/YOUR_USER/HksUtil.git
cd HksUtil
.\app.ps1
```

## Requirements

- Windows 10 / Windows 11
- PowerShell 5.1+ (Windows PowerShell) or PowerShell 7+
- WinGet (built-in on Windows 11 / latest Windows 10)
- Internet connection for first run (app list)

## UI

- Dark/Light theme
- 3-column app grid with search & category filtering
- Status bar with progress feedback
- Resizable window (min 1000×600)

## Project Structure

```
HksUtil/
├── app.ps1          # Main application script
├── ui.xaml          # WPF UI layout
├── launcher.ps1     # Bootstrap script for remote execution
├── config/          # JSON configuration files
│   ├── apps.json    # Application catalog
│   ├── tweaks.json  # System tweak definitions
│   ├── features.json
│   ├── preferences.json
│   ├── themes.json  # Dark/Light theme colors
│   └── dns.json     # DNS provider list
└── Tweaks/          # Documentation for each tweak
```
