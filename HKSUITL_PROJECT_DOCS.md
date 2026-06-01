# HksUtil v2.0 — Complete Project Documentation

> สร้างขึ้นสำหรับ AI อื่นอ่านแล้วทำงานต่อได้ทันที
> Project: Windows Optimizer Tool (PowerShell + WPF)
> Author: hartkitsak
> Repo: https://github.com/hartkitsak/HksUtil
> Path: D:\dev-setup\HksUtil\ (Windows) ↔ /home/hart_kitsak/projects/HksUtil (WSL)

---

## 1. PROJECT OVERVIEW

HksUtil is a GUI Windows optimization utility built with **PowerShell** (code-behind) and **WPF XAML** (UI layout). It provides:

- **Install Apps** — Search/install/uninstall via WinGet or Chocolatey
- **System Tweaks** — Registry, services, AppX removals with undo
- **Features & Fixes** — Enable Windows features + run system repair scripts
- **Preferences** — Toggle Windows settings with immediate registry apply
- **Legacy Panels** — Quick access to classic Windows control panels
- **Settings** — DNS provider switcher, create shortcut, Terminal Dotfiles install

**Launch method (Windows PowerShell Admin):**
```powershell
powershell -ExecutionPolicy Bypass -File "D:\dev-setup\HksUtil\app.ps1"
```

The script auto-elevates to Admin if not already running as Admin.

---

## 2. FILE STRUCTURE

```
HksUtil/
├── app.ps1                    # Main PowerShell code-behind (~880 lines)
├── ui.xaml                    # WPF XAML UI layout (~650 lines)
├── launcher.ps1               # Bootstrap script for irm|iex install
├── README.md                  # Project documentation
├── .gitignore                 # Git ignore rules
├── .git/                      # Git metadata (1 commit)
├── config/
│   ├── apps.json              # App definitions for Install page (6 categories, 42 apps)
│   ├── tweaks.json            # Tweak definitions (3 groups, 17 tweaks)
│   ├── dns.json               # DNS provider list (8 providers)
│   ├── preferences.json       # Windows preferences (22 toggles)
│   └── features.json          # Features + Fixes definitions (2 sections, 15 entries)
└── themes/
    ├── Dark.xaml               # Dark theme ResourceDictionary (20 keys)
    └── Light.xaml              # Light theme ResourceDictionary (20 keys, same keys)
```

---

## 3. ARCHITECTURE

### 3.1 Startup Flow (app.ps1)

1. Load WPF assemblies (`PresentationFramework`, `PresentationCore`, `WindowsBase`)
2. Define utility functions: `Write-Log`, `Show-Confirm`, `Show-Info`, `Set-Status`, `Update-InstalledCache`, `Apply-Theme`
3. Check Admin → if not, relaunch via `Start-Process -Verb RunAs` then `exit`
4. Load `ui.xaml` via `XamlReader.Load()` (replace `x:Name` → `Name`)
5. Build `$controls` dictionary: all `Name` attributes from XAML → `$window.FindName()`
6. Attach window drag to `TitleText`
7. Load all 5 JSON configs from `config/` directory
8. Set up navigation (`Switch-Page` function + nav button Click handlers)
9. Set up toolbar handlers (theme toggle, min/max/close)
10. Set up Gear popup handlers (export/import config, about/docs/sponsors)
11. Build dynamic UI for each page:
    - **DNS**: RadioButton cards from `dns.json` + Apply button
    - **Terminal Profile**: Install/Uninstall buttons
    - **Shortcut**: Create Desktop Shortcut
    - **Apps**: Category headers + CheckBox cards from `apps.json` + search/filter/install/uninstall
    - **Tweaks**: CheckBox cards from `tweaks.json` + Run/Undo
    - **Features**: CheckBox cards + Fix buttons from `features.json`
    - **Preferences**: ToggleSwitch cards from `preferences.json` (apply immediately)
    - **Legacy**: Hardcoded panel shortcut buttons
12. Show initial page: "Install"

### 3.2 Window Configuration

```xml
WindowStyle="None"
ResizeMode="CanResizeWithGrip"
<WindowChrome CaptionHeight="0" ResizeBorderThickness="5"/>
```

- **No standard title bar** — custom toolbar (Border `ToolbarDrag`) with:
  - Left: app name + version
  - Center: nav buttons (Install, Tweaks, Features, Preferences, Legacy, Settings)
  - Right: theme toggle, gear menu, minimize, maximize, close
- Window drag attached to `TitleText` only
- Resize via WindowChrome grip (5px border)

### 3.3 Grid Layout (ui.xaml)

```xml
<Grid>
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>   <!-- Row 0: ToolbarDrag (title bar) -->
        <RowDefinition Height="*"/>      <!-- Row 1: Content pages (ScrollViewers) -->
        <RowDefinition Height="Auto"/>   <!-- Row 2: StatusBar -->
    </Grid.RowDefinitions>
```

Row 1 contains 6 `ScrollViewer` pages stacked (only one visible at a time via `Visibility`):
- `PageInstall` (default, Visible)
- `PageTweaks` (Collapsed)
- `PageFeatures` (Collapsed)
- `PagePreferences` (Collapsed)
- `PageLegacy` (Collapsed)
- `PageSettings` (Collapsed)

### 3.4 Theme System

- Two theme files: `themes/Dark.xaml` and `themes/Light.xaml`
- Both define **exactly 20 resource keys** (same names, different colors)
- `Apply-Theme` function: loads XAML → creates ResourceDictionary → replaces `$window.Resources.MergedDictionaries[0]`
- All XAML colors use `{DynamicResource}` bindings
- Code-behind colors use `$control.SetResourceReference([type]::Property, "key")`
- `primaryColor` (accent): `#4D9DE0` (same in both themes)
- **Nav buttons** use `SetResourceReference` for `selectedBackground`/`accentColor`/`textMuted` (updated on theme switch)

---

## 4. PAGE-BY-PAGE DETAILS

### 4.1 Install Page (`PageInstall`)

**Controls:**
- `SearchBox` + `SearchHint` — text search with live filtering
- `BtnClearSearch` — clears search
- `ChkShowInstalled` — filter to installed only
- `PkgWinGet` / `PkgChoco` — radio buttons for package manager
- `BtnInstall` / `BtnUninstall` — batch install/uninstall
- `BtnSelectAll` / `BtnClearSelection` — select/deselect all visible
- `BtnCollapseAll` / `BtnExpandAll` — collapse/expand categories
- `LblSelectedCount` — shows "Selected Apps: N"
- `AppPanel1`/`AppPanel2`/`AppPanel3` — 3-column grid for app checkboxes

**Data source:** `config/apps.json` (6 categories, 42 apps)

**App CheckBox style:** `TweakCheckBox` (card with border, selected background on check)

**Category system:**
- Categories start **expanded** (`$script:categoryCollapsed[$cat] = $false`)
- Header shows `"- CATEGORY (N)"` when expanded, `"+ CATEGORY (N)"` when collapsed
- Click header to toggle collapse/expand
- Collapse All / Expand All buttons work on all categories

**Installed filter:**
- `Update-InstalledCache` function runs `winget list --accept-source-agreements`
- Parses output by searching for each app ID using regex
- `ChkShowInstalled` checkbox triggers `Apply-Filters`
- Cache is populated on first check if empty

### 4.2 Tweaks Page (`PageTweaks`)

**Controls:**
- `TweaksPanel1`/`TweaksPanel2`/`TweaksPanel3` — 3-column grid
- `BtnRunTweaks` — apply selected tweaks
- `BtnUndoTweaks` — undo all applied tweaks

**Data source:** `config/tweaks.json` (3 groups, 17 tweaks)

**Tweak CheckBox style:** `TweakCheckBox` (same card style)

**Apply flow:** For each checked tweak:
1. Save original values (`Save-OriginalValues`): service startup/status, registry values
2. Apply services → registry → AppX removal → scripts
3. Tweak is removed from `features.json` list? No — uses its own undo log (`$script:tweakUndoLog`)

**Undo flow:** Restores saved originals.

### 4.3 Features Page (`PageFeatures`)

**Controls:**
- `FeaturesSectionHeader` — "Windows Features" header
- `FeaturesPanel1`/`FeaturesPanel2`/`FeaturesPanel3` — 3-column grid
- `FixesSectionHeader` — "Fixes" header
- `FixesWrapPanel` — wrap panel for fix buttons
- `BtnRunFeatures` — run selected features

**Data source:** `config/features.json` (2 sections: `Features` (9 entries) + `Fixes` (6 entries))

**Features** — CheckBox cards (TweakCheckBox style), each runs a script on click of Run button
**Fixes** — Buttons (FeatureCard style), each runs a script on its own click with confirmation

### 4.4 Preferences Page (`PagePreferences`)

**Controls:**
- `PrefsPanel1`/`PrefsPanel2`/`PrefsPanel3` — 3-column grid

**Data source:** `config/preferences.json` (22 preferences)

**ToggleSwitch style:** Custom CheckBox template with toggle appearance

**Apply on toggle:** Checked = apply `registry_on[]` values, Unchecked = apply `registry_off[]` values
- No "Apply" button — applies immediately on toggle
- Each registry entry has: `path`, `name`, `value`
- **Known issue:** `preferences.json` entries missing `"type"` field — registry writes default to REG_SZ instead of REG_DWORD

### 4.5 Legacy Page (`PageLegacy`)

**Controls:**
- `LegacyPanel1`/`LegacyPanel2`/`LegacyPanel3` — 3-column grid

**Data:** 10 hardcoded entries in `app.ps1` (lines 605-614):
- System Properties, Device Manager, Network Connections, Disk Management, Services, Event Viewer, Task Scheduler, Performance Monitor, Registry Editor, Group Policy Editor

**Card style:** `FeatureCard` (Button with Border, accent color on hover)

### 4.6 Settings Page (`PageSettings`)

**Controls:**
- `DnsRadioPanel` — StackPanel of RadioButton cards (DnsCardStyle)
- `BtnApplyDns` — Apply DNS button
- `BtnCreateShortcut` — Create Desktop Shortcut button
- `BtnTerminalDotfiles` — Install Terminal Profile button
- `BtnUninstallTerminal` — Uninstall Terminal Profile button

**DNS System:**
- RadioButton cards with `DnsCardStyle` (same card look as TweakCheckBox)
- `GroupName="DnsProvider"` — single select
- Reads from `config/dns.json` (8 providers)
- Apply: `Set-DnsClientServerAddress` with primary adapter (`Get-NetAdapter -Physical | Where-Object Status -eq 'Up'`)
- Fallback: `netsh interface ip set dns`
- Confirm dialog before applying

**Terminal Dotfiles:**
- Uses `Invoke-TerminalAction` function
- Runs: `irm https://raw.githubusercontent.com/hartkitsak/Terminal-Dotfiles/master/install.ps1 | iex`
- Launches via `powershell -EncodedCommand` in separate window

**Shortcut:** Creates desktop shortcut via `WScript.Shell` COM object

---

## 5. UI.XAML — STYLE REFERENCE

| Style Key | Target | Purpose |
|-----------|--------|---------|
| `CategoryHeader` | TextBlock | Section headers (accent color, bold) |
| `AppCardCheckBox` | CheckBox | App cards (UNUSED — apps use TweakCheckBox) |
| `TweakCheckBox` | CheckBox | Standard card checkbox (tweaks, apps, features) |
| `ToggleSwitch` | CheckBox | Toggle switch (preferences) |
| `PresetCard` | Button | (Unused in code?) |
| `FeatureCard` | Button | Legacy panel buttons, Fix buttons |
| `NavButtonStyle` | Button | (Unused — TopNavButtonStyle used instead) |
| `ActionBtn` | Button | Filled accent button (primary action) |
| `DangerBtn` | Button | Filled red button (destructive action) |
| `SecondaryBtn` | Button | Filled secondary button |
| `DnsCardStyle` | RadioButton | DNS provider card (same style as TweakCheckBox) |
| `ToolbarIconBtn` | Button | Toolbar icon (MDL2 font) |
| `ToolbarIconToggleBtn` | ToggleButton | Toolbar toggle icon |
| `PopupMenuItem` | Button | Gear menu item |
| `ActionBtnOutline` | Button | Outlined accent button (used in old code) |
| `DangerBtnOutline` | Button | Outlined red button (used in old code) |
| `TopNavButtonStyle` | Button | Navigation tab button |

### DynamicResource Keys (20 total)

`windowBackground`, `headerBackground`, `headerBorder`, `footerBackground`, `footerBorder`,
`cardBackground`, `cardForeground`, `cardBorder`,
`accentColor`, `accentHover`, `categoryHeaderColor`,
`pageTitleColor`, `textMuted`,
`textBoxBackground`, `textBoxForeground`, `textBoxBorder`,
`dangerColor`, `dangerHover`,
`selectedBorder`, `selectedBackground`,
`hoverBackground`, `secondaryBackground`, `secondaryHover`

---

## 6. APP.PS1 — KEY FUNCTIONS

| Function | Lines | Purpose |
|----------|-------|---------|
| `Write-Log` | 6-16 | Console logging with timestamp + color |
| `Show-Confirm` | 18-22 | MessageBox Yes/No |
| `Show-Info` | 24-27 | MessageBox OK |
| `Set-Status` | 32-34 | Update status bar text |
| `Update-InstalledCache` | 36-49 | Run `winget list`, parse installed IDs |
| `Apply-Theme` | 63-76 | Load theme XAML, swap Resources |
| `Switch-Page` | 106-124 | Show one page, update nav button styles |
| `Invoke-TerminalAction` | 309-315 | Run terminal dotfiles install/uninstall |
| `Save-OriginalValues` | 379-411 | Backup service + registry before tweak apply |
| `Invoke-UndoTweaks` | 413-441 | Restore all backed-up values |
| `Apply-Filters` | 672-701 | Search + installed filter on app list |
| `Update-SelectedCount` | 713-715 | Count checked apps, update label |

---

## 7. KNOWN BUGS / ISSUES

### Bugs
1. **`Invoke-TerminalAction` defined twice** (lines 309 and 367) — second overrides first
2. **`BtnUninstallTerminal` wired twice** (lines 327 and 359) — harmless duplicate
3. **`preferences.json` missing `"type"` field** — registry values written as REG_SZ instead of REG_DWORD
4. **`AppCardCheckBox` style never used** — apps use TweakCheckBox instead
5. **`Invoke-WinUtilExplorerUpdate` undefined** — called in tweaks.json Widget remove tweak but function doesn't exist

### Style/Resolved
6. ~~Nav buttons hardcoded colors~~ → Now uses `SetResourceReference` (theme-aware)
7. ~~DNS ComboBox dropdown invisible~~ → Now uses RadioButton cards (DnsCardStyle)
8. ~~Ghost controls (BtnExportConfig etc.)~~ → Removed
9. ~~Window-level DragMove~~ → Removed (only TitleText drag)
10. ~~$appPanels null scope~~ → Fixed (initialized before if block)

---

## 8. CONFIG FILES REFERENCE

### apps.json (6 categories, 42 apps)
```
Browsers (3) | Security & Privacy (4) | Development (11)
Media & Creative (11) | Utilities (10) | Productivity (3)
```

### tweaks.json (3 groups, 17 tweaks)
```
Performance (4) | Privacy (3) | Essential Tweaks (10)
```

### dns.json (8 providers)
```
Google, Cloudflare, Cloudflare_Malware, Cloudflare_Malware_Adult,
Open_DNS, Quad9, AdGuard_Ads_Trackers, AdGuard_Ads_Trackers_Malware_Adult
```
Each: `{ description, ipv4: [2], ipv6: [2] }`

### preferences.json (22 preferences)
Each: `{ content, description, registry_on: [{path, name, value}], registry_off: [{path, name, value}] }`

### features.json (2 sections, 15 entries)
```
Features (9) | Fixes (6)
```
Each: `{ content, description, script }` — Fixes have confirm prompt

---

## 9. CODING CONVENTIONS

- **XAML**: All colors via `{DynamicResource key}`, never hardcoded hex
- **PowerShell**: Dynamic UI built with `New-Object` + `SetResourceReference()` for theme-aware colors
- **Event wiring**: `$controls["Name"].Add_Event({ scriptblock })`
- **Control retrieval**: `$controls = @{}` + `$xaml.SelectNodes("//*[@Name]") | ForEach-Object { $controls[$_.Name] = $window.FindName($_.Name) }`
- **JSON configs**: Loaded via `Get-Content -Raw | ConvertFrom-Json` at startup
- **Config path**: `Join-Path $PSScriptRoot "config"`
- **All user-facing messages** go through `Write-Log` (console) and `Show-Confirm`/`Show-Info` (GUI)
- **Status bar** updates via `Set-Status` function

---

## 10. SYNC WORKFLOW

Edits are made in WSL (`/home/hart_kitsak/projects/HksUtil/`) then copied to Windows D: drive:
```bash
cp /home/hart_kitsak/projects/HksUtil/*.ps1 /mnt/d/dev-setup/HksUtil/
cp /home/hart_kitsak/projects/HksUtil/ui.xaml /mnt/d/dev-setup/HksUtil/ui.xaml
cp /home/hart_kitsak/projects/HksUtil/config/*.json "/mnt/d/dev-setup/HksUtil/config/"
cp /home/hart_kitsak/projects/HksUtil/themes/*.xaml "/mnt/d/dev-setup/HksUtil/themes/"
```

Run on Windows:
```powershell
powershell -ExecutionPolicy Bypass -File "D:\dev-setup\HksUtil\app.ps1"
```
