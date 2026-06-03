<div align="center">
  <pre>
HH   HH KK   KK  SSSSSS  UU   UU TTTTTT IIIIII LL
HH   HH KK  KK  SS       UU   UU   TT     II   LL
HHHHHHH KKKKK    SSSSSS  UU   UU   TT     II   LL
HH   HH KK  KK       SS  UU   UU   TT     II   LL
HH   HH KK   KK  SSSSSS   UUUUU    TT   IIIIII LLLL</pre>
  <h1>HksUtil</h1>
  <h3>Windows Optimizer & Package Manager</h3>
  <p>
    <a href="#features">Features</a> ·
    <a href="#installation">Installation</a> ·
    <a href="#usage">Usage</a> ·
    <a href="#customization">Customization</a> ·
    <a href="#license">License</a>
  </p>
  <p>
    <img src="https://img.shields.io/badge/Windows-10%2F11-0078D4?logo=windows&logoColor=white" alt="Windows">
    <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white" alt="PowerShell">
    <img src="https://img.shields.io/badge/WPF-.NET%204.8-512BD4?logo=dotnet&logoColor=white" alt="WPF">
    <img src="https://img.shields.io/badge/tests-32%20passed-2ea44f" alt="Tests">
    <img src="https://img.shields.io/badge/license-MIT-yellow" alt="License">
  </p>
  <p>
    <a href="https://github.com/hartkitsak/HksUtil/actions/workflows/compile-check.yaml">
      <img src="https://github.com/hartkitsak/HksUtil/actions/workflows/compile-check.yaml/badge.svg" alt="Compile & Check">
    </a>
    <a href="https://github.com/hartkitsak/HksUtil/actions/workflows/unittests.yaml">
      <img src="https://github.com/hartkitsak/HksUtil/actions/workflows/unittests.yaml/badge.svg" alt="Unit Tests">
    </a>
  </p>
</div>

---

## Overview

HksUtil is a Windows utility tool that provides a modern graphical interface for system optimization and package management. Built with **PowerShell** and **WPF**, it combines WinGet/Chocolatey app management, system tweaks, Windows features, and DNS switching into one unified dashboard with Dark and Light themes.

## Features

### 📦 App Management
| | |
|---|---|
| **Package Managers** | WinGet + Chocolatey |
| **App Catalog** | 42 applications across 6 categories |
| **Operations** | Install, uninstall, batch apply |
| **UX** | Search, installed filter, collapsible groups, right-click menu |

### ⚙️ System Tweaks
| | |
|---|---|
| **Performance** | SysMain, Search Indexing, Power Plan, Visual Effects |
| **Privacy** | Telemetry, Activity History, Location Tracking, Tailored Experiences |
| **Essential** | Services tuning, AppX removal, Disk Cleanup, Widgets, WPBT |
| **Safety** | System Restore checkpoint + per-tweak undo log with rollback dialog |

### 🔧 Features & Fixes
- **Windows Features** — .NET Framework, Hyper-V, WSL2, Sandbox, NFS, Legacy Media
- **Repair Scripts** — SFC Scan, DISM Restore, Network Reset, Windows Update Reset, AutoLogon config

### 🎛️ Preferences
20 registry-based toggles applied immediately: dark theme, taskbar alignment, file extensions, hidden files, Num Lock, Caps Lock, S3 sleep, battery percentage, sticky keys, mouse acceleration, smooth scrolling, and more.

### 🖥️ Legacy Panels
One-click access to 16 classic Windows tools: Control Panel, Device Manager, Disk Management, Event Viewer, Registry Editor, Services, Task Scheduler, System Properties, Computer Management, Network Connections, Power Panel, Printer Panel, Region, Sound, Time/Date, System Restore.

### ⚙️ Settings Dashboard
- **DNS Switcher** — Google, Cloudflare, OpenDNS, Quad9, AdGuard
- **Export/Import** — Save and restore app/tweak/feature/preference selections
- **Nova Profile** — Install PowerShell profile with `hksutil` alias via [nova](https://github.com/hartkitsak/nova)
- **Auto-Apply** — Headless mode via `-Noui -Config <path> -Apply`

## Installation

### One-liner (Admin PowerShell)
```powershell
.\app.ps1
```

### Manual (clone)
```powershell
git clone https://github.com/hartkitsak/HksUtil.git
cd HksUtil
.\app.ps1
```

> ⚠️ **Admin required.** The script auto-elevates if not running as Administrator.

## Usage

### GUI Mode
```powershell
.\app.ps1
```

### Compiled Single-File Mode
```powershell
.\scripts\Compile.ps1   # produces hksutil.ps1
.\hksutil.ps1       # run the compiled version
```

### Headless Mode
```powershell
.\app.ps1 -Noui -Config .\config\apps.json -Apply
```

### Export Config
```powershell
.\app.ps1 -Export .\config\exported.json
```

## Requirements

| Component | Version |
|-----------|---------|
| OS | Windows 10 / Windows 11 (64-bit) |
| PowerShell | 5.1 or later |
| .NET | Framework 4.8 (included with Windows 10+) |
| WinGet | Ships with Windows 11 / available via App Installer |
| Chocolatey | Auto-installed on first use (optional) |

## Project Structure

<details>
<summary>Click to expand</summary>

```
HksUtil/
├── app.ps1                     # Entry point — auto-elevate, config load, XAML bootstrap
├── scripts/
│   ├── start.ps1               # Compiled script header template
│   └── Compile.ps1             # Build script — merges modules + config + XAML into hksutil.ps1
├── docs/
│   └── HKSUITL_PROJECT_DOCS.md # AI-oriented project documentation
├── config/                     # 7 JSON config files
│   ├── meta.json               # Version metadata
│   ├── apps.json               # App catalog (42 apps, 6 categories)
│   ├── tweaks.json             # Tweak definitions
│   ├── features.json           # Features + Fixes scripts
│   ├── preferences.json        # 20 registry-based toggles
│   ├── themes.json             # Dark + Light color schemes
│   └── dns.json                # DNS provider list
├── xaml/
│   └── ui.xaml                 # WPF layout (~660 lines)
├── modules/                    # 13 PowerShell modules
│   ├── logger.ps1              # Terminal logging, message boxes
│   ├── core.ps1                # Async dispatch, progress overlay, cache, headless mode
│   ├── theme.ps1               # JSON → BrushConverter runtime theming
│   ├── navigation.ps1          # Page switching, keyboard shortcuts
│   ├── tweaks.ps1              # Tweak engine, undo log, System Restore integration
│   ├── search.ps1              # Live search and installed filter
│   ├── toolbar.ps1             # Title bar controls, gear menu handlers
│   ├── dns.ps1                 # DNS provider switcher
│   ├── terminal.ps1            # Terminal profile management
│   ├── utility.ps1             # Desktop shortcut creation
│   ├── build.ps1               # Dynamic UI builder from config
│   ├── install.ps1             # Batch install/uninstall engine
│   └── features.ps1            # Windows feature toggles
├── tests/                      # Pester test suite (29 tests, 6 files)
├── .github/
│   ├── ISSUE_TEMPLATE/         # Bug report + feature request templates
│   └── workflows/              # CI: compile-check + unit tests
├── LICENSE                     # MIT license
├── README.md                   # This file
└── .gitignore
```

</details>

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | PowerShell 5.1 |
| UI Framework | WPF via XAML |
| Package Managers | WinGet CLI, Chocolatey CLI |
| Runtime | .NET Framework 4.8 |
| Testing | Pester 3.4.0 |
| Linting | PSScriptAnalyzer |
| CI/CD | GitHub Actions (compile + tests) |
| Theming | JSON color config → runtime `BrushConverter` |

## Customization

Edit JSON files in `config/` to customize applications, tweaks, preferences, DNS providers, or themes. The configuration is split across 7 files:

Refer to each file's field names — all sections are self-documenting.

## Contributing

Bug reports and feature requests welcome via [GitHub Issues](https://github.com/hartkitsak/HksUtil/issues). See the issue templates for guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.
