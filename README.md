# HksUtil

**Version 3.0** — Windows utility for app management, system tweaks, DNS config, disk cleanup, and registry preferences.

## Quick Install

```powershell
irm https://raw.githubusercontent.com/hartkitsak/HksUtil/main/hksutil.ps1 | iex
```

This runs the combined script directly from GitHub. Elevated admin rights are required.

## Features

- **App Installer** — Batch install/uninstall via winget or Chocolatey. 42 apps across Browsers, Security & Privacy, Development, Media & Creative, Utilities, and Productivity.
- **Cleaner** — Remove temp files, usage traces, crash dumps, prefetch logs, and registry history. 18 cleanup tasks.
- **Tools** — Quick-launch 17 system tools (System Restore, Disk Defragmenter, Services, Group Policy, etc.).
- **Preferences** — 20 registry-based toggle switches (Dark Theme, File Extensions, Hidden Files, Mouse Acceleration, Sticky Keys, S3 Sleep, etc.).
- **DNS Switcher** — 9 DNS providers (Google, Cloudflare, Quad9, AdGuard, OpenDNS).
- **Theme Support** — Light/Dark mode with WPF styling.

## Headless Mode

Apply config without GUI:

```powershell
.\hksutil.ps1 -Config .\config.json -Apply
```

`config.json` supports `AppSelections`, `CleanerSelections`, and `PreferenceStates`.

## Dev Mode

Clone and run the source directly:

```powershell
git clone https://github.com/hartkitsak/HksUtil.git
cd HksUtil
.\app.ps1
```

## Build from Source

```powershell
.\scripts\Combine.ps1
```

Requires PowerShell 5.1+ (Windows PowerShell). Output: `hksutil.ps1`

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Winget (recommended) or Chocolatey for app installation
- Administrator privileges for registry/system changes

## Project Structure

```
HksUtil/
├── hksutil.ps1          # Combined single-file build
├── app.ps1              # Dev entry point
├── scripts/
│   ├── Combine.ps1      # Build script (PowerShell)
│   └── combine.py       # Build script fallback (Python)
└── src/
    ├── config/          # JSON configs (apps, dns, preferences, cleaner, etc.)
    ├── modules/         # PowerShell modules (core, build, utility, etc.)
    └── ui.xaml          # WPF UI layout
```

## License

MIT
