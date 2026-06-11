#!/usr/bin/env python3
"""Replicate Combine.ps1 logic to generate hksutil.ps1"""

import json, re, os, sys

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
modules_dir = os.path.join(root, 'src', 'modules')
config_dir = os.path.join(root, 'src', 'config')
xaml_path = os.path.join(root, 'src', 'ui.xaml')
app_path = os.path.join(root, 'app.ps1')
output_path = os.path.join(root, 'hksutil.ps1')

def json_to_pscode(obj):
    if isinstance(obj, list):
        items = [json_to_pscode(v) for v in obj]
        return '@(' + ','.join(items) + ')'
    elif isinstance(obj, dict):
        pairs = []
        for k, v in obj.items():
            val = json_to_pscode(v)
            k_esc = k.replace("'", "''")
            pairs.append(f"'{k_esc}' = {val}")
        return '@{' + '; '.join(pairs) + '}'
    elif isinstance(obj, bool):
        return '$true' if obj else '$false'
    elif isinstance(obj, int) or isinstance(obj, float):
        return str(obj)
    elif isinstance(obj, str):
        s = obj.replace('"', '`"')
        return f'"{s}"'
    elif obj is None:
        return '$null'
    else:
        return f'"{str(obj)}"'

# Read version
with open(os.path.join(config_dir, 'meta.json'), encoding='utf-8') as f:
    meta = json.load(f)
version = meta.get('version', '0.0')

# Read configs
config_keys = ['meta', 'themes', 'apps', 'dns', 'preferences', 'cleaner', 'legacy']
config_lines = []
for key in config_keys:
    with open(os.path.join(config_dir, f'{key}.json'), encoding='utf-8') as f:
        obj = json.load(f)
    ps = json_to_pscode(obj)
    config_lines.append(f"$script:embeddedConfigs['{key}'] = {ps}")
config_block = '\n'.join(config_lines)

# Read XAML
with open(xaml_path, encoding='utf-8') as f:
    xaml_raw = f.read()
xaml_block = f'''$script:embeddedXaml = @'
{xaml_raw}
'@'''

# Read modules
pre_xaml_names = ['logger.ps1', 'dialog.ps1', 'core.ps1', 'theme.ps1', 'install.ps1']
post_xaml_names = ['navigation.ps1', 'search.ps1', 'toolbar.ps1', 'dns.ps1', 'utility.ps1', 'build.ps1', 'status.ps1', 'cleaner.ps1']

def read_module(name):
    with open(os.path.join(modules_dir, name), encoding='utf-8') as f:
        content = f.read()
    return f'\n# ============ {name} ============\n{content}'

pre_xaml = '\n'.join(read_module(m) for m in pre_xaml_names)
post_xaml = '\n'.join(read_module(m) for m in post_xaml_names)

# Process app.ps1
with open(app_path, encoding='utf-8') as f:
    app_lines = f.readlines()

# Filter out dot-source module lines
dot_source_re = re.compile(r'^\s*\.\s+"\$PSScriptRoot\\src\\modules\\.*"')
filtered_lines = []
for line in app_lines:
    if dot_source_re.match(line):
        continue
    filtered_lines.append(line)

app_code = ''.join(filtered_lines)

# Replace config loading block with dual-mode
old_config = '''$configPath = Join-Path $PSScriptRoot "src\\config"
Write-Log "Loading configs..." "Info"

$configFiles = @{meta = @{}; themes = @{}; apps = @{}; dns = @{}; preferences = @{}; cleaner = @{}; legacy = @() }
foreach ($key in $configFiles.Keys) {
    $file = Join-Path $configPath "$key.json"
    try { $sync.configs[$key] = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs[$key] = $configFiles[$key]; Write-Log "$key.json failed: $_" "Warn" }
}'''

new_config = '''if ($script:embeddedConfigs) {
    $sync.configs = $script:embeddedConfigs
} else {
    $configPath = Join-Path $PSScriptRoot "src\\config"
    Write-Log "Loading configs..." "Info"
    $configFiles = @{meta = @{}; themes = @{}; apps = @{}; dns = @{}; preferences = @{}; cleaner = @{}; legacy = @() }
    foreach ($key in $configFiles.Keys) {
        $file = Join-Path $configPath "$key.json"
        try { $sync.configs[$key] = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $sync.configs[$key] = $configFiles[$key]; Write-Log "$key.json failed: $_" "Warn" }
    }
}'''

app_code = app_code.replace(old_config, new_config)

# Replace XAML loading block with dual-mode
old_xaml = '''try {
    $xamlPath = Join-Path $PSScriptRoot "src\\ui.xaml"
    $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
    $xamlContent = $xamlContent -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync.window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }'''

new_xaml = '''if ($script:embeddedXaml) {
    $xamlContent = $script:embeddedXaml -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync.window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} else {
    try {
        $xamlPath = Join-Path $PSScriptRoot "src\\ui.xaml"
        $xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8
        $xamlContent = $xamlContent -replace 'x:Name="([^"]+)"', 'Name="$1"'
        [xml]$xaml = $xamlContent
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $sync.window = [Windows.Markup.XamlReader]::Load($reader)
        $reader.Close()
    } catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }
}'''

app_code = app_code.replace(old_xaml, new_xaml)

# Split into 3 parts
pos1 = app_code.index('$script:appRoot = $PSScriptRoot')
end_a = pos1 + len('$script:appRoot = $PSScriptRoot')
nl_after = app_code.index('\n', end_a)
end_a = nl_after + 1

part_a = app_code[:end_a]
remaining = app_code[end_a:]

pos2 = remaining.index('\nRegister-InstallEvents')
part_b = remaining[:pos2 + 1]
part_c = remaining[pos2 + 1:]

# Build output
header = f'''<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : {version} (combined build \u2014 do not edit directly; edit src/ sources)
#>

'''

embedded_data = f'$script:embeddedConfigs = @{{}}\n{config_block}\n\n{xaml_block}'

output = header + f'''

# ============ PARAMETERS & SETUP ============
{part_a}

# ============ EMBEDDED DATA ============
{embedded_data}

# ============ PRE-XAML MODULES ============
{pre_xaml}

# ============ CORE APP LOGIC ============
{part_b}

# ============ POST-XAML MODULES ============
{post_xaml}

# ============ APP FINALIZATION ============
{part_c}'''

# Normalize line endings and write with UTF-8 BOM
output = output.replace('\r\n', '\n')
with open(output_path, 'w', encoding='utf-8-sig') as f:
    f.write(output)

line_count = output.count('\n')
byte_size = len(output.encode('utf-8-sig'))
print(f'Done! Combined script: {output_path}')
print(f'Size: {byte_size // 1024} KB, {line_count} lines')
