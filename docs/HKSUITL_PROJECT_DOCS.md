# HksUtil v2.0 — Complete Project Documentation

> สร้างขึ้นสำหรับ AI อื่นอ่านแล้วทำงานต่อได้ทันที
> Project: Windows Optimizer Tool (PowerShell + WPF)
> Author: hartkitsak
> Repo: https://github.com/hartkitsak/HksUtil
> Path: D:\dev-setup\HksUtil

---

## 1. PROJECT OVERVIEW

HksUtil is a GUI Windows optimization utility built with **PowerShell 5.1** (code-behind) and **WPF XAML** (UI layout). It provides:

- **Install Apps** — Search/install/uninstall via WinGet or Chocolatey (42 apps, 6 categories)
- **System Tweaks** — Registry, services, AppX removals with undo + System Restore
- **Features & Fixes** — Enable Windows features + run system repair scripts
- **Preferences** — Toggle 20 Windows settings with immediate registry apply
- **Legacy Panels** — Quick access to 16 classic Windows control panels/tools
- **Settings** — DNS provider switcher, Export/Import config, Terminal Dotfiles install, desktop shortcut

**Launch:**
```powershell
powershell -ExecutionPolicy Bypass -File "D:\dev-setup\HksUtil\app.ps1"
# Or remote:
git clone https://github.com/hartkitsak/HksUtil.git
.\HksUtil\app.ps1
```

The script auto-elevates to Admin if not already running as Admin.

---

## 2. FILE STRUCTURE

```
HksUtil/
├── app.ps1                    # Entry point (~160 lines: auto-elevate, dot-source, XAML, NoUI)
├── scripts/
│   ├── start.ps1              # Compiled script header template (header, params, admin check)
│   └── Compile.ps1            # Build script — merges → hksutil.ps1 (single-file output)
├── docs/
│   └── HKSUITL_PROJECT_DOCS.md # This file
├── README.md                  # GitHub documentation
├── LICENSE                    # MIT license (file)
├── .gitignore
├── config/                    # 7 JSON config files
│   ├── meta.json              # Version metadata
│   ├── apps.json              # App catalog
│   ├── tweaks.json            # Tweak definitions
│   ├── features.json          # Features + Fixes scripts
│   ├── preferences.json       # Registry-based toggles
│   ├── themes.json            # Color schemes
│   └── dns.json               # DNS providers
├── xaml/
│   └── ui.xaml                # WPF UI layout (~640 lines)
├── modules/                   # 11 PowerShell modules
│   ├── logger.ps1             # Write-Log, Show-HksUtilLogo, Show-Confirm, Show-Info, Set-Status
│   ├── core.ps1               # $sync hashtable, Invoke-WPFUIThread, Show/Hide-Progress, Set-ProgressTaskbar,
│   │                          # Update-InstalledCache, Ensure-PackageManager, Get-WpfResource,
│   │                          # $script:logLines initialization
│   ├── theme.ps1              # Apply-Theme via config.json → BrushConverter (no XAML ResourceDictionary)
│   ├── navigation.ps1         # Switch-Page, nav button wiring, keyboard handler
│   ├── tweaks.ps1             # Save-OriginalValues, Invoke-UndoTweaks (log-based + System Restore dialog),
│   │                          # Set-TweakRegistry, Set-TweakServices, Invoke-TweakScript
│   ├── search.ps1             # Apply-Filters (search text + installed filter), SearchHint toggle
│   ├── toolbar.ps1            # Title bar button handlers (theme, min/max/close, gear menu: export, import, about, docs, sponsors)
│   ├── dns.ps1                # DNS radio button cards + Apply button
│   ├── terminal.ps1           # Nova profile install/uninstall via irm|iex
│   ├── utility.ps1            # Create desktop shortcut via WScript.Shell COM
│   ├── build.ps1              # Dynamic UI builder for all pages (apps, tweaks, features, preferences, legacy)
│   ├── install.ps1            # Batch install/uninstall logic (Invoke-Install, Invoke-Uninstall)
│   └── features.ps1           # Invoke-RunFeatures (applies checked feature checkboxes)
├── tests/                     # Pester 3.4.0 test suite (29 tests, 6 files)
├── .github/
│   ├── ISSUE_TEMPLATE/        # bug_report.yaml, feature_request.yaml, config.yml
│   └── workflows/             # compile-check.yaml, unittests.yaml
└── .gitignore
```

---

## 3. ARCHITECTURE

### 3.1 Startup Flow (app.ps1)

1. Assert Admin → if not, relaunch via `Start-Process -Verb RunAs` then `exit`
2. Load WPF assemblies
3.  Set `$script:appRoot = $PSScriptRoot`
4.  Parse `-Noui`, `-Config <path>`, `-Apply`, `-Export` parameters
5.  Load all 7 JSON files from `config/` → `$script:appsConfig`, `$script:tweaksConfig`, etc.
6.  **GUI mode**: Load `xaml/ui.xaml` → XamlReader → build `$controls` hashtable
7.  Dot-source all 13 modules from `modules/` (order: logger → core → theme → navigation → tweaks → search → toolbar → dns → terminal → utility → build → install → features)
8.  Apply theme (default "dark")
9.  Show initial page: "Install"
10. **NoUI mode**: Skip XAML, inline headless install logic (config → batch queue)

### 3.2 Window Configuration

```xml
WindowStyle="None"
ResizeMode="CanResizeWithGrip"
<WindowChrome CaptionHeight="0" ResizeBorderThickness="5"/>
```

- **Custom title bar** — `ToolbarDrag` Border with:
  - Left: app name + version
  - Center: nav buttons (Install, Tweaks, Features, Preferences, Legacy, Settings)
  - Right: theme toggle, gear menu, minimize, maximize, close
- Window drag attached to `TitleText` only
- Resize via WindowChrome (5px border)

### 3.3 Grid Layout (ui.xaml)

```
Row 0: ToolbarDrag (title bar, auto height)
Row 1: Content pages (6 ScrollViewers, stacked, one visible at a time)
Row 2: StatusBar (auto height)
```

6 pages: `PageInstall`, `PageTweaks`, `PageFeatures`, `PagePreferences`, `PageLegacy`, `PageSettings`

### 3.4 Module Dependency Graph

```
app.ps1
 ├── logger.ps1        (no deps)
 ├── core.ps1          (depends: logger)
 ├── theme.ps1         (depends: core [$sync, $controls])
 ├── navigation.ps1    (depends: core [$sync, $controls])
 ├── tweaks.ps1        (depends: logger, core)
 ├── search.ps1        (depends: core [$controls])
 ├── toolbar.ps1       (depends: logger, core, theme, navigation)
 ├── dns.ps1           (depends: logger, core [$controls])
 ├── terminal.ps1      (depends: logger, core)
 ├── utility.ps1       (no deps)
 ├── build.ps1         (depends: core [$controls, $window], logger)
 ├── install.ps1       (depends: logger, core)
 └── features.ps1      (depends: logger, core)
```

### 3.5 NoUI Headless Mode

```powershell
.\app.ps1 -Noui -Config .\config\apps.json -Apply
.\app.ps1 -Export .\config\exported-config.json
```

- `-Noui` skips XAML loading, sets `$script:NoUI = $true`
- `-Export <path>` saves current config to JSON
- `-Apply` reads config → runs installs via `Ensure-PackageManager` + batch queue
- Progress functions (`Show-Progress`, `Hide-Progress`) fallback to console logging in NoUI mode

### 3.6 Theme System (JSON-based)

**No XAML ResourceDictionary files.** Theme colors are stored in `config.json` → `themes` section:

```json
"themes": {
  "dark": { "Background": "#FF1E1E1E", "Foreground": "#FFFFFFFF", ... },
  "light": { "Background": "#FFFFFFFF", "Foreground": "#FF000000", ... }
}
```

`Apply-Theme` reads from `$script:themesConfig` → creates `SolidColorBrush` via `BrushConverter` → sets `$window.Resources` dictionary entries. Fallback to console when `Application.Current` is null.

**Resource keys (22 total):**
`Background`, `Foreground`, `HeaderBackground`, `HeaderBorder`, `FooterBackground`, `FooterBorder`,
`CardBackground`, `CardForeground`, `CardBorder`,
`AccentColor`, `AccentHover`, `CategoryHeaderColor`,
`PageTitleColor`, `TextMuted`,
`TextBoxBackground`, `TextBoxForeground`, `TextBoxBorder`,
`DangerColor`, `DangerHover`,
`SelectedBorder`, `SelectedBackground`,
`HoverBackground`, `SecondaryBackground`, `SecondaryHover`

---

## 4. PAGE-BY-PAGE DETAILS

### 4.1 Install Page

**Controls:** `SearchBox`, `SearchHint`, `BtnClearSearch`, `ChkShowInstalled`, `PkgWinGet`, `PkgChoco`, `BtnInstall`, `BtnUninstall`, `BtnSelectAll`, `BtnClearSelection`, `BtnCollapseAll`, `BtnExpandAll`, `LblSelectedCount`, `AppPanel1/2/3`

**Data source:** `config/apps.json` (6 categories, 42 apps)

**Features:**
- App checkboxes with `TweakCheckBox` card style + context menu (Install/Uninstall/Info)
- Category headers (collapsible, expand/collapse all)
- Live search via `Apply-Filters` (matches name, description, winget ID)
- Installed filter via `Update-InstalledCache` (parses `winget list`)
- Right-click context menu per app

### 4.2 Tweaks Page

**Controls:** `TweaksPanel1/2/3`, `BtnRunTweaks`, `BtnUndoTweaks`

**Data source:** `config/tweaks.json` (3 groups)

**Apply flow:**
1. `New-SystemRestorePoint` → `Checkpoint-Computer`
2. For each checked tweak: `Save-OriginalValues` (backup services + registry)
3. Apply services → registry → AppX removal → scripts
4. Log to `$script:tweakUndoLog`

**Undo flow:** `Invoke-UndoTweaks` shows dialog:
- **Log-based undo** — Restore registry values + service startup types (maps "Auto" → "Automatic")
- **System Restore** — via `Restore-Computer` (disabled when no restore points exist)

### 4.3 Features Page

**Controls:** `FeaturesPanel1/2/3`, `FixesWrapPanel`, `BtnRunFeatures`

**Data source:** `config/features.json` (2 sub-sections: Features + Fixes)

- **Features** — CheckBox cards, batch run via `BtnRunFeatures` → `Invoke-RunFeatures`
- **Fixes** — Button cards (FeatureCard style), each with confirm dialog, runs inline scriptblock

### 4.4 Preferences Page

**Controls:** `PrefsPanel1/2/3`

**Data source:** `config/preferences.json` (20 items)

**ToggleSwitch style:** Custom CheckBox template (toggle appearance)
**Apply on toggle:** Checked → `registry_on[]`, Unchecked → `registry_off[]`
No "Apply" button — applies immediately.

### 4.5 Legacy Page

**Controls:** `LegacyPanel1/2/3`

**Data:** 16 hardcoded entries in `build.ps1`:

| Panel | Command | Description |
|-------|---------|-------------|
| Computer Management | `compmgmt.msc` | Manage disks, services, event viewer |
| Control Panel | `control` | Classic Windows Control Panel |
| Device Manager | `devmgmt.msc` | View and update hardware devices |
| Disk Management | `diskmgmt.msc` | Manage disk partitions and volumes |
| Event Viewer | `eventvwr.msc` | View system logs and events |
| Network Connections | `ncpa.cpl` | Manage network adapters |
| Power Panel | `powercfg.cpl` | Configure power plans |
| Printer Panel | `control printers` | Manage printers and print queues |
| Region | `intl.cpl` | Regional format, language, location |
| Registry Editor | `regedit` | View and edit registry |
| Services | `services.msc` | Manage Windows services |
| Sound Settings | `mmsys.cpl` | Configure audio devices |
| System Properties | `sysdm.cpl` | System info, performance, remote |
| Task Scheduler | `taskschd.msc` | Schedule automated tasks |
| Time and Date | `timedate.cpl` | Set date, time, timezone |
| Windows Restore | `rstrui.exe` | System Restore |

**Card style:** `FeatureCard` (Button with Border, accent hover)

### 4.6 Settings Page

**Controls:** `DnsRadioPanel`, `BtnApplyDns`, `BtnCreateShortcut`, `BtnTerminalDotfiles`, `BtnUninstallTerminal`

**DNS System:**
- RadioButton cards with `DnsCardStyle`, `GroupName="DnsProvider"`
- Reads from `config/dns.json` (8 providers)
- Apply: `Set-DnsClientServerAddress` (primary physical adapter), fallback: `netsh interface ip set dns`
- Confirm dialog before applying

**Terminal Dotfiles:**
- `BtnTerminalDotfiles`: Downloads nova install script via `Invoke-WebRequest`, runs locally, then deletes
- `BtnUninstallTerminal`: Same pattern for nova uninstall

**Shortcut:** Creates desktop shortcut via `WScript.Shell` COM object

---

## 5. CONFIG REFERENCE

7 separate JSON files in `config/`:

### meta
```json
{ "version": "2.0", "author": "hartkitsak" }
```

### themes
```json
"dark": { "Background": "#FF1E1E1E", "Foreground": "#FFFFFFFF", ... },
"light": { "Background": "#FFFFFFFF", "Foreground": "#FF000000", ... }
```
22 color keys per theme, applied at runtime via BrushConverter.

### apps
6 categories — Browsers (3), Security & Privacy (4), Development (11), Media & Creative (11), Utilities (10), Productivity (3)
Each app: `{ content, winget, description }`

### tweaks
3 groups — Performance (4), Privacy (3), Essential Tweaks (10)
Each tweak: `{ content, description, registry: [{path, name, value, type}], services: [{name, startup, status}], appx: [], script }`

### dns
8 providers — Google, Cloudflare, Cloudflare_Malware, Cloudflare_Malware_Adult, Open_DNS, Quad9, AdGuard_Ads_Trackers, AdGuard_Ads_Trackers_Malware_Adult
Each: `{ description, ipv4: [2], ipv6: [2] }`

### preferences
20 toggles. Each: `{ content, description, registry_on: [{path, name, value}], registry_off: [{path, name, value}] }`

### features
2 sub-sections:
- Features (9 entries) — `{ content, description, script }` for Windows feature enable
- Fixes (6 entries) — `{ content, description, confirm, script }` for repair scripts with confirmation

---

## 6. UI.XAML STYLE REFERENCE

| Style Key | Target | Used By |
|-----------|--------|---------|
| `CategoryHeader` | TextBlock | Section headers (accent, bold) |
| `TweakCheckBox` | CheckBox | App/tweak/feature cards |
| `ToggleSwitch` | CheckBox | Preference toggles |
| `FeatureCard` | Button | Legacy panels, Fix buttons |
| `ActionBtn` | Button | Filled accent primary action |
| `DangerBtn` | Button | Filled red destructive action |
| `SecondaryBtn` | Button | Filled secondary action |
| `DnsCardStyle` | RadioButton | DNS provider cards |
| `ToolbarIconBtn` | Button | Toolbar icon (MDL2 font) |
| `ToolbarIconToggleBtn` | ToggleButton | Toolbar toggle icon |
| `PopupMenuItem` | Button | Gear menu item |
| `TopNavButtonStyle` | Button | Navigation tab buttons |

---

## 7. KEY FUNCTIONS

| Function | Module | Purpose |
|----------|--------|---------|
| `Write-Log` | logger.ps1 | Console logging — levels: OK/INFO/WARN/FAIL/>/Header |
| `Show-HksUtilLogo` | logger.ps1 | ASCII art logo + `=====HksUtil v2.0=====` header |
| `Show-Confirm` | logger.ps1 | MessageBox Yes/No (always returns $true in NoUI) |
| `Show-Info` | logger.ps1 | MessageBox OK (no-op in NoUI) |
| `Set-Status` | logger.ps1 | Update status bar text |
| `Invoke-WPFUIThread` | core.ps1 | Synchronous dispatch on WPF dispatcher (or direct call) |
| `Show-Progress` | core.ps1 | Show overlay with text + progress bar (or console in NoUI) |
| `Hide-Progress` | core.ps1 | Hide overlay |
| `Set-ProgressTaskbar` | core.ps1 | Taskbar progress state |
| `Update-InstalledCache` | core.ps1 | Run `winget list`, parse installed app IDs |
| `Ensure-PackageManager` | core.ps1 | Auto-install WinGet/Choco if missing |
| `Get-WpfResource` | core.ps1 | Safe `$window.FindResource()` with try/catch, returns null on miss |
| `Apply-Theme` | theme.ps1 | Read config.json themes → BrushConverter → set Resources |
| `Switch-Page` | navigation.ps1 | Show one page, update nav button styles |
| `Save-OriginalValues` | tweaks.ps1 | Backup service startup + registry before tweak |
| `Invoke-UndoTweaks` | tweaks.ps1 | Log-based or System Restore undo dialog |
| `Apply-Filters` | search.ps1 | Search text match + installed filter on apps |
| `Update-SelectedCount` | search.ps1 | Count checked apps, update LblSelectedCount |
| `Invoke-TerminalAction` | terminal.ps1 | Run dotfiles install/uninstall in new window |
| `Invoke-Install` | install.ps1 | Batch install checked apps |
| `Invoke-Uninstall` | install.ps1 | Batch uninstall checked apps |
| `Invoke-RunFeatures` | features.ps1 | Run selected feature scripts |

---

## 8. CODING CONVENTIONS

- **XAML**: All colors via `{DynamicResource key}`, never hardcoded hex
- **PowerShell**: Dynamic UI via `New-Object` + `SetResourceReference()` for theme-aware colors
- **Event wiring**: `$controls["Name"].Add_Event({ scriptblock })` or `$btn.Add_Click({ $this.Tag ... })`
- **Control retrieval**: XAML parse → `$xaml.SelectNodes("//*[@Name]")` → `$controls[$key] = $window.FindName($key)`
- **Config load**: `Get-Content -Raw -Encoding UTF8 | ConvertFrom-Json` on each file in `config/`
- **All user-facing messages**: `Write-Log` (console) and `Show-Confirm`/`Show-Info` (GUI)
- **Progress**: `Show-Progress`/`Hide-Progress` wrappers (GUI overlay or console fallback)
- **Module loading**: Dot-sourced in strict order (app.ps1 lines 99-111)

---

## 9. CRITICAL RULES & BUG HISTORY

### Critical Rules for AI

1. **`$PSScriptRoot`** in dot-sourced files resolves to caller's directory for inline code, but unpredictably inside functions — always capture at dot-source time into a script-level variable (`$script:appRoot`).

2. **`Children.Add()`** in WPF returns int (insertion index); must pipe to `Out-Null` or assign to `$null`.

3. **`ConvertTo-Json`** default depth is 2; must specify `-Depth` for nested objects.

4. **Registry `Set-ItemProperty`** without `-Type` defaults to `String` even for DWORD data.

5. **Pester 3.4.0** does not support `-Tag` on `It`; uses `Should` (not `Should -Be`).

6. **`[System.Windows.Application]::Current`** may be `$null` when running from PowerShell (no WPF Application object). Always check before accessing `.Resources`.

7. **`$controls.Keys`** enumeration must use a copy (`@($controls.Keys)`) when removing entries during iteration.

8. **PowerShell `foreach`** does NOT create a new scope per iteration; closure variables inside event handlers must be captured via `$this.Tag`.

9. **`$script:config`** must NOT be used as variable name — collides with `[string]$Config` parameter. Use `$script:cfg`.

10. **`Win32_Service.StartMode`** returns `"Auto"` for Automatic services; `Set-Service -StartupType` requires `"Automatic"`. Map before calling.
11. **COM objects** (`WScript.Shell`) must be released with `[Runtime.InteropServices.Marshal]::ReleaseComObject()` in `finally` block.
12. **`OpenFileDialog`** must be disposed via `try/finally` pattern to avoid resource leaks.
13. **`Start-Process`** with multi-word command (e.g. `"control printers"`) must split into `-FilePath` and `-ArgumentList`.
14. **`$controls["BtnToolbarSettings"]`** may be `$null` if the settings toggle button is absent — always guard before `.IsChecked = $false`.
15. **`$null -eq $_.Value`** check preferred over truthy `$_.Value` for arg builder — `$false` or `0` are valid non-null values.

### Bugs Found & Fixed

| # | Bug | File | Fix |
|---|-----|------|-----|
| 1 | `$script:config` collides with `[string]$Config` parameter | app.ps1 | Renamed to `$script:cfg` |
| 2 | `Apply-Theme "Dark"` but config key is `"dark"` (lowercase) | app.ps1 | Changed to lowercase |
| 3 | `registry_on[0].value` accessed outside guard | build.ps1:78-83 | Unified into `$hasRegistryOn` |
| 4 | `Get-Content $Config` without `Test-Path` | app.ps1 | Added path validation |
| 5 | `$script:logLines` never defined | core.ps1 | Initialized at module load |
| 6 | `Write-Log "Cmd"` type unhandled | logger.ps1 | Added `"Cmd" → ">"` with Cyan |
| 7 | Service undo uses `"Auto"` but `Set-Service` needs `"Automatic"` | tweaks.ps1:79 | Added mapping |
| 8 | `BtnGetInstalled` removed from XAML + handler | xaml/ui.ps1 | Removed stale binding |
| 9 | `[bool]` cast inverts logic (`[bool]"false"` → $true) | app.ps1, Compile.ps1 | Changed to `-eq $true` |
| 10 | `Set-ItemProperty` missing `-Type` parameter | build.ps1 | Added `$t` fallback to `"String"` |
| 11 | `FindResource` unguarded (8 calls) | dns.ps1, build.ps1 | Created `Get-WpfResource` helper in core.ps1 |
| 12 | `logLines` never populated by Write-Log | logger.ps1, core.ps1 | Write-Log appends; init moved to module-level |
| 13 | SearchBox null access in BtnClearSearch | app.ps1 | Added `if ($controls["SearchBox"])` guard |
| 14 | ChkShowInstalled wired twice | search.ps1 | Removed from search.ps1, kept in app.ps1 |
| 15 | `$controls` null in compiled script | Compile.ps1 | `$controls = @{}` injected before module embed |

### 47 → 72 Code Audit Issues (All Fixed)

- **HIGH (15):** Show-Progress named params, registry `-Type`, deep clean guard, null control guards, `$sync.PSScriptRoot` removed, anchored regex cache, `Apply-Filters` null Tag guard, confirmation before execution, `-Encoding UTF8` on all `Get-Content`, `$reader.Close()` disposal, TerminalInput missing from XAML, [bool] cast invert, Set-ItemProperty -Type, FindResource unguarded, logLines never populated, SearchBox null, ChkShowInstalled double-wire, $controls null
- **MEDIUM + LOW (57):** empty catch → Write-Log (8 spots), Relaunch arg builder null check, Features section guard, navigation null guard (pages/navButtons), BtnToolbarSettings guard (5 spots), OpenFileDialog dispose, COM release, pwsh fallback, Start-Process multi-word split, dead code removed (importInProgress, Invoke-HksUtilHeadless), typed enum, ConvertTo-Json -Depth 5, null `$controls` filtered, `$scriptCmd` else branch, file header removal, formatting cleanup

---

## 10. TEST SUITE

**Framework:** Pester 3.4.0
**Total tests:** 32 (7 files)
**Run:** `Invoke-Pester .\tests\` from repo root

| File | Tests | Coverage |
|------|-------|----------|
| `logger.Tests.ps1` | 6 | Show-HksUtilLogo, Write-Log (all 6 types), Show-Confirm/Info/Set-Status |
| `core.Tests.ps1` | 6 | Invoke-WPFUIThread (2), Show-Progress (3), Set-ProgressTaskbar, Update-InstalledCache |
| `navigation.Tests.ps1` | 6 | Switch-Page defined, pages/navButtons hashtable, nav buttons Tag, Update-SelectedCount (3) |
| `search.Tests.ps1` | 4 | Apply-Filters (no filter, with search), Update-SelectedCount (3), null guard |
| `terminal.Tests.ps1` | 3 | Invoke-TerminalAction defined, winget launch, choco launch |
| `theme.Tests.ps1` | 3 | Apply-Theme defined, currentTheme defaults, appRoot set |
| `tweaks.Tests.ps1` | 4 | Save-OriginalValues (3), Invoke-UndoTweaks empty |

---

## 11. BUILD SYSTEM (Compile.ps1)

`Compile.ps1` merges all source files into a single portable `hksutil.ps1`:

**Flow:**
1. Read `scripts/start.ps1` → replace `#{replaceme}` with version date (`yy.MM.dd`)
2. Read all 13 modules in dependency order (logger → core → theme → navigation → tweaks → search → toolbar → dns → terminal → utility → build → install → features)
3.  Read all JSON files from `config/` → embed as here-strings → parse at runtime
4. Read `xaml/ui.xaml` → embed as here-string → parse at runtime
5. Append compiled main body (NoUI/Export logic, XAML loading, UI setup, event handlers)
6. Write to `hksutil.ps1`

**Usage:**
```powershell
.\scripts\Compile.ps1        # Produces hksutil.ps1
.\scripts\Compile.ps1 -Run   # Compile and launch
```

The output `hksutil.ps1` is gitignored (not tracked in repo). Compiled version supports the same params as `app.ps1`.

---

## 12. CI/CD (GitHub Actions)

Two workflows in `.github/workflows/`:

**compile-check.yaml:**
- Trigger: push/PR to main, manual dispatch, or called by other workflows
- Job: Checkout → run `scripts/Compile.ps1` → fail on error

**unittests.yaml:**
- Trigger: push/PR to main, manual dispatch
- Jobs:
  - `lint`: PSScriptAnalyzer on ubuntu-latest (settings from `lint/PSScriptAnalyser.ps1`)
  - `test`: Install Pester 3.4.0 → run `Invoke-Pester tests/*.Tests.ps1` on windows-latest

---

## 13. VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.x | — | Monolithic app.ps1 (1135 lines), 6 separate JSON configs, XAML theme files |
| 2.0 | 2026 | 14-file modular split, unified config.json, 32 Pester tests, NoUI mode, JSON-based theming, System Restore, 47 code audit fixes, 8 bug fixes |
| 2.1 | 2026 | LICENSE file, .github/ISSUE_TEMPLATE, .github/workflows (CI/CD), lint/PSScriptAnalyser.ps1, Compile.ps1 build system, 16 Legacy panels |
| 2.2 | 2026 | All 8 HIGH + 14 MEDIUM + 12 LOW bugs fixed. empty catch → Write-Log, COM release, pwsh fallback, Start-Process multi-word split, dead code removal, navigation null guards, toolbar settings guards, OpenFileDialog dispose, Relaunch arg builder fix, Features section guard |
| 2.3 | 2026 | Context menu `--accept-source-agreements`, preference null guard, DNS null check, tweak `$reg.path` null guard, `Invoke-Expression` → `[scriptblock]::Create()`, `iex (irm)` → `Invoke-WebRequest` + dot-source, chocolatey install via download + dot-source, hardcoded paths fixed, `chkdsk /scan` removed, `net stop /y` → `Stop-Service`, `x:Name` regex fix, `Join-Path` 3-arg compat fix, `BrushConverter` dispose, winget list parsed by lines, recursive clean depth-limited, parameter splatting aligned, config docs updated, hksutil.ps1 gitignored |
