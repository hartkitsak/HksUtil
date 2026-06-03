<div align="center">
  <pre>
HH   HH KK   KK  SSSSSS  UU   UU TTTTTT IIIIII LL
HH   HH KK  KK  SS       UU   UU   TT     II   LL
HHHHHHH KKKKK    SSSSSS  UU   UU   TT     II   LL
HH   HH KK  KK       SS  UU   UU   TT     II   LL
HH   HH KK   KK  SSSSSS   UUUUU    TT   IIIIII LLLL</pre>
  <h1>HksUtil</h1>
  <h3>Windows Optimizer & Package Manager</h3>

  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#configuration">Configuration</a> ·
  <a href="#license">License</a>

  <br>

  <img src="https://img.shields.io/badge/Windows-10%2F11-0078D4?logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/WPF-.NET%204.8-512BD4?logo=dotnet&logoColor=white" alt="WPF">
  <img src="https://img.shields.io/badge/tests-32%20passed-2ea44f" alt="Tests">
  <img src="https://img.shields.io/badge/license-MIT-yellow" alt="License">

  <br>

  <a href="https://github.com/hartkitsak/HksUtil/actions/workflows/compile-check.yaml">
    <img src="https://github.com/hartkitsak/HksUtil/actions/workflows/compile-check.yaml/badge.svg" alt="Compile & Check">
  </a>
  <a href="https://github.com/hartkitsak/HksUtil/actions/workflows/unittests.yaml">
    <img src="https://github.com/hartkitsak/HksUtil/actions/workflows/unittests.yaml/badge.svg" alt="Unit Tests">
  </a>
</div>

---

**HksUtil** is a Windows utility with a modern WPF GUI for system optimization and package management. Built with PowerShell and WPF, it combines WinGet/Chocolatey app management, system tweaks, Windows features, DNS switching, and 16 legacy panels into one unified dashboard — with Dark and Light themes.

## Features

### App Management
| | |
|---|---|
| Package Managers | WinGet + Chocolatey |
| App Catalog | 42 applications across 6 categories |
| Operations | Install, uninstall, batch apply |
| UX | Live search, installed filter, collapsible groups, right-click context menu |

### System Tweaks
| | |
|---|---|
| Performance | SysMain, Search Indexing, Power Plan, Visual Effects |
| Privacy | Telemetry, Activity History, Location Tracking |
| Essential | Services tuning, AppX removal, Disk Cleanup, Widgets, WPBT |
| Safety | System Restore checkpoint + per-tweak undo log with rollback dialog |

### Features & Fixes
- **Windows Features** — .NET Framework, Hyper-V, WSL2, Sandbox, NFS, Legacy Media
- **Repair Scripts** — SFC Scan, DISM Restore, Network Reset, Windows Update Reset, AutoLogon

### Preferences
20 registry-based toggles applied immediately: dark theme, taskbar alignment, file extensions, hidden files, Num Lock, Caps Lock, S3 sleep, battery percentage, sticky keys, mouse acceleration, smooth scrolling, and more.

### Legacy Panels
One-click access to 16 classic Windows tools: Control Panel, Device Manager, Disk Management, Event Viewer, Registry Editor, Services, Task Scheduler, System Properties, Computer Management, Network Connections, Power Panel, Printer Panel, Region, Sound, Time/Date, System Restore.

### Settings Dashboard
- **DNS Switcher** — Google, Cloudflare, OpenDNS, Quad9, AdGuard
- **Export/Import** — Save and restore app/tweak/feature/preference selections as JSON
- **Install Nova Profile** — Deploy [nova](https://github.com/hartkitsak/nova) PowerShell profile with one click
- **Desktop Shortcut** — Create a desktop launcher for quick access
- **Auto-Apply** — Headless mode via `-Noui -Config <path> -Apply`

## Installation

### One-liner (recommended)
```powershell
irm https://raw.githubusercontent.com/hartkitsak/HksUtil/main/install.ps1 | iex
```

### Manual
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

### Headless Mode
```powershell
# Apply selections from a config file without showing the UI
.\app.ps1 -Noui -Config .\config\apps.json -Apply
```

### Export Configuration
```powershell
# Export current selections to a JSON file
.\app.ps1 -Export .\config\exported.json
```

### Compile Standalone (for deployment)
```powershell
.\scripts\Compile.ps1       # produces hksutil.ps1 (not tracked in git)
.\scripts\Compile.ps1 -Run  # compile and launch
```

## Requirements

| Component | Version |
|-----------|---------|
| OS | Windows 10 / Windows 11 (64-bit) |
| PowerShell | 5.1 or later |
| .NET | Framework 4.8 (included with Windows 10+) |
| WinGet | Ships with Windows 11 / available via App Installer |
| Chocolatey | Optional — auto-installed on first use |

## Configuration

All configuration is driven by 7 JSON files in `config/`:

| File | Description |
|------|-------------|
| `meta.json` | Version metadata |
| `apps.json` | App catalog (42 apps, 6 categories) |
| `tweaks.json` | Tweak definitions with registry, services, and scripts |
| `features.json` | Windows features + system repair scripts |
| `preferences.json` | 20 registry-based toggle definitions |
| `themes.json` | Dark and Light color schemes (22 keys each) |
| `dns.json` | DNS provider list with IPv4/IPv6 addresses |

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
| Theming | JSON color config → runtime BrushConverter |

## Project Structure

```
HksUtil/
├── app.ps1                  # Development entry point
├── install.ps1              # irm|iex bootstrapper (clones repo + runs app.ps1)
├── scripts/
│   ├── start.ps1            # Script header template
│   └── Compile.ps1          # Build script (produces standalone hksutil.ps1)
├── functions/
│   ├── public/              # Reusable public functions
│   └── private/             # Internal helpers
├── config/                  # 7 JSON config files
├── xaml/
│   └── ui.xaml              # WPF layout (~630 lines)
├── modules/                 # 13 PowerShell modules
│   ├── logger.ps1           # Logging, message boxes, status bar
│   ├── core.ps1             # Async dispatch, progress, cache
│   ├── theme.ps1            # JSON → BrushConverter theming
│   ├── navigation.ps1       # Page switching, keyboard shortcuts
│   ├── tweaks.ps1           # Tweak engine, undo log, System Restore
│   ├── search.ps1           # Live search + installed filter
│   ├── toolbar.ps1          # Title bar, gear menu
│   ├── dns.ps1              # DNS provider switcher
│   ├── terminal.ps1         # Nova profile install/uninstall
│   ├── utility.ps1          # Desktop shortcut creation
│   ├── build.ps1            # Dynamic UI builder
│   ├── install.ps1          # Batch install/uninstall
│   └── features.ps1         # Feature toggles
├── tests/                   # Pester 3.4.0 test suite (32 tests)
├── .github/
│   ├── ISSUE_TEMPLATE/      # Bug report + feature request
│   └── workflows/           # compile-check + unit tests
├── docs/
│   └── HKSUITL_PROJECT_DOCS.md
├── LICENSE
└── README.md
```

## Contributing

Bug reports and feature requests welcome via [GitHub Issues](https://github.com/hartkitsak/HksUtil/issues).

## License

MIT — see [LICENSE](LICENSE) for details.
