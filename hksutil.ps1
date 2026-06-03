<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : 26.06.03
#>

param(
    [string]$Config,
    [switch]$Noui,
    [switch]$Offline,
    [switch]$Apply,
    [string]$Export,
    [switch]$Verbose
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "HksUtil needs to be run as Administrator. Attempting to relaunch."
    $argList = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $argList += if ($_.Value -is [switch] -and $_.Value) { "-$($_.Key)" }
        elseif ($_.Value -is [array]) { "-$($_.Key) $($_.Value -join ',')" }
        elseif ($null -ne $_.Value) { "-$($_.Key) '$($_.Value)'" }
    }
    $scriptCmd = if ($PSCommandPath) {
        "& { & '$PSCommandPath' $($argList -join ' ') }"
    } else {
        "& { & '$(Split-Path $MyInvocation.MyCommand.Path -Parent)\hksutil.ps1' $($argList -join ' ') }"
    }
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    Start-Process $powershellCmd -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$scriptCmd`"" -Verb RunAs
    exit
}

$script:hksVersion = "26.06.03"
$script:NoUI = $Noui

$controls = @{}
$script:__mod_logger = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpsb2dMZXZlbCA9ICJTdWNjZXNzIgoKZnVuY3Rpb24gU2hvdy1Ia3NVdGlsTG9nbyB7CiAgICBXcml0ZS1Ib3N0IEAiCkhIICAgSEggS0sgICBLSyAgU1NTU1NTICBVVSAgIFVVIFRUVFRUVCBJSUlJSUkgTEwKSEggICBISCBLSyAgS0sgIFNTICAgICAgIFVVICAgVVUgICBUVCAgICAgSUkgICBMTApISEhISEhIIEtLS0tLICAgIFNTU1NTUyAgVVUgICBVVSAgIFRUICAgICBJSSAgIExMCkhIICAgSEggS0sgIEtLICAgICAgIFNTICBVVSAgIFVVICAgVFQgICAgIElJICAgTEwKSEggICBISCBLSyAgIEtLICBTU1NTU1MgICBVVVVVVSAgICBUVCAgIElJSUlJSSBMTExMCiJAIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbgogICAgV3JpdGUtSG9zdCAiICA9PT09PT09PT09PT09PT09PT09PT09PT0iIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbgogICAgV3JpdGUtSG9zdCAiICAgIEhrc1V0aWwgdjIuMCIgLUZvcmVncm91bmRDb2xvciBDeWFuCiAgICBXcml0ZS1Ib3N0ICIgICAgV2luZG93cyBPcHRpbWl6ZXIiIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbgogICAgV3JpdGUtSG9zdCAiICA9PT09PT09PT09PT09PT09PT09PT09PT0iIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbgp9CgpmdW5jdGlvbiBXcml0ZS1Mb2cgewogICAgcGFyYW0oW3N0cmluZ10kTWVzc2FnZSwgW3N0cmluZ10kVHlwZSA9ICJJbmZvIikKICAgIGlmICgkVHlwZSAtZXEgIkhlYWRlciIpIHsKICAgICAgICBXcml0ZS1Ib3N0ICJgbiAgJE1lc3NhZ2UiIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbgogICAgICAgIGlmICgkc2NyaXB0OmxvZ0xpbmVzKSB7ICRzY3JpcHQ6bG9nTGluZXMuQWRkKCIgICRNZXNzYWdlIikgfQogICAgICAgIHJldHVybgogICAgfQogICAgJGxldmVsID0gc3dpdGNoICgkVHlwZSkgewogICAgICAgICJJbmZvIiAgICB7ICJJTkZPIiB9CiAgICAgICAgIlN1Y2Nlc3MiIHsgIk9LIiB9CiAgICAgICAgIkVycm9yIiAgIHsgIkZBSUwiIH0KICAgICAgICAiV2FybiIgICAgeyAiV0FSTiIgfQogICAgICAgICJDbWQiICAgICB7ICI+IiB9CiAgICB9CiAgICAkY29sb3IgPSBzd2l0Y2ggKCRUeXBlKSB7CiAgICAgICAgIkluZm8iICAgIHsgIkRhcmtHcmF5IiB9CiAgICAgICAgIlN1Y2Nlc3MiIHsgIkdyZWVuIiB9CiAgICAgICAgIkVycm9yIiAgIHsgIlJlZCIgfQogICAgICAgICJXYXJuIiAgICB7ICJZZWxsb3ciIH0KICAgICAgICAiQ21kIiAgICAgeyAiQ3lhbiIgfQogICAgfQogICAgaWYgKCRzY3JpcHQ6bG9nTGluZXMpIHsgJHNjcmlwdDpsb2dMaW5lcy5BZGQoIiRsZXZlbCAkTWVzc2FnZSIpIH0KICAgIGlmICgkVHlwZSAtZXEgIkluZm8iIC1hbmQgJHNjcmlwdDpsb2dMZXZlbCAtbmUgIkluZm8iKSB7IHJldHVybiB9CiAgICBXcml0ZS1Ib3N0ICgiICB7MCwtNX0gezF9IiAtZiAkbGV2ZWwsICRNZXNzYWdlKSAtRm9yZWdyb3VuZENvbG9yICRjb2xvcgp9CgpmdW5jdGlvbiBTaG93LUNvbmZpcm0gewogICAgcGFyYW0oW3N0cmluZ10kVGl0bGUsIFtzdHJpbmddJE1lc3NhZ2UpCiAgICAkcmVzdWx0ID0gW1N5c3RlbS5XaW5kb3dzLk1lc3NhZ2VCb3hdOjpTaG93KCRNZXNzYWdlLCAkVGl0bGUsIFtTeXN0ZW0uV2luZG93cy5NZXNzYWdlQm94QnV0dG9uXTo6WWVzTm8sIFtTeXN0ZW0uV2luZG93cy5NZXNzYWdlQm94SW1hZ2VdOjpRdWVzdGlvbikKICAgIHJldHVybiAkcmVzdWx0IC1lcSBbU3lzdGVtLldpbmRvd3MuTWVzc2FnZUJveFJlc3VsdF06Olllcwp9CgpmdW5jdGlvbiBTaG93LUluZm8gewogICAgcGFyYW0oW3N0cmluZ10kVGl0bGUsIFtzdHJpbmddJE1lc3NhZ2UpCiAgICBbU3lzdGVtLldpbmRvd3MuTWVzc2FnZUJveF06OlNob3coJE1lc3NhZ2UsICRUaXRsZSwgW1N5c3RlbS5XaW5kb3dzLk1lc3NhZ2VCb3hCdXR0b25dOjpPSywgW1N5c3RlbS5XaW5kb3dzLk1lc3NhZ2VCb3hJbWFnZV06OkluZm9ybWF0aW9uKSB8IE91dC1OdWxsCn0KCmZ1bmN0aW9uIFNldC1TdGF0dXMgewogICAgcGFyYW0oW3N0cmluZ10kVGV4dCkKICAgIGlmICgkY29udHJvbHNbIlN0YXR1c1RleHQiXSkgeyAkY29udHJvbHNbIlN0YXR1c1RleHQiXS5UZXh0ID0gJFRleHQgfQp9CgpmdW5jdGlvbiBVcGRhdGUtU2VsZWN0ZWRDb3VudCB7CiAgICAkY291bnQgPSAoJGFwcENoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0pLkNvdW50CiAgICBpZiAoJGNvbnRyb2xzWyJMYmxTZWxlY3RlZENvdW50Il0pIHsgJGNvbnRyb2xzWyJMYmxTZWxlY3RlZENvdW50Il0uVGV4dCA9ICJTZWxlY3RlZCBBcHBzOiAkY291bnQiIH0KfQo='))
$script:logLevel = "Success"

function Show-HksUtilLogo {
    Write-Host @"
HH   HH KK   KK  SSSSSS  UU   UU TTTTTT IIIIII LL
HH   HH KK  KK  SS       UU   UU   TT     II   LL
HHHHHHH KKKKK    SSSSSS  UU   UU   TT     II   LL
HH   HH KK  KK       SS  UU   UU   TT     II   LL
HH   HH KK   KK  SSSSSS   UUUUU    TT   IIIIII LLLL
"@ -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
    Write-Host "    HksUtil v2.0" -ForegroundColor Cyan
    Write-Host "    Windows Optimizer" -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor Cyan
}

function Write-Log {
    param([string]$Message, [string]$Type = "Info")
    if ($Type -eq "Header") {
        Write-Host "`n  $Message" -ForegroundColor Cyan
        if ($script:logLines) { $script:logLines.Add("  $Message") }
        return
    }
    $level = switch ($Type) {
        "Info"    { "INFO" }
        "Success" { "OK" }
        "Error"   { "FAIL" }
        "Warn"    { "WARN" }
        "Cmd"     { ">" }
    }
    $color = switch ($Type) {
        "Info"    { "DarkGray" }
        "Success" { "Green" }
        "Error"   { "Red" }
        "Warn"    { "Yellow" }
        "Cmd"     { "Cyan" }
    }
    if ($script:logLines) { $script:logLines.Add("$level $Message") }
    if ($Type -eq "Info" -and $script:logLevel -ne "Info") { return }
    Write-Host ("  {0,-5} {1}" -f $level, $Message) -ForegroundColor $color
}

function Show-Confirm {
    param([string]$Title, [string]$Message)
    $result = [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Show-Info {
    param([string]$Title, [string]$Message)
    [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Set-Status {
    param([string]$Text)
    if ($controls["StatusText"]) { $controls["StatusText"].Text = $Text }
}

function Update-SelectedCount {
    $count = ($appCheckboxes | Where-Object { $_.IsChecked -eq $true }).Count
    if ($controls["LblSelectedCount"]) { $controls["LblSelectedCount"].Text = "Selected Apps: $count" }
}

$script:__mod_core = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDppbnN0YWxsZWRBcHBJZHMgPSBAe30KJHN5bmMgPSBbSGFzaHRhYmxlXTo6U3luY2hyb25pemVkKEB7fSkKJHN5bmMudmVyc2lvbiA9ICIyLjAiCiRzeW5jLmNvbmZpZ3MgPSBAe30KJHN5bmMuUHJvY2Vzc1J1bm5pbmcgPSAkZmFsc2UKJHN5bmMuc2VsZWN0ZWRBcHBzID0gW1N5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXV06Om5ldygpCiRzeW5jLnNlbGVjdGVkVHdlYWtzID0gW1N5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXV06Om5ldygpCiRzeW5jLnNlbGVjdGVkRmVhdHVyZXMgPSBbU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddXTo6bmV3KCkKJHN5bmMuY3VycmVudFRhYiA9ICJJbnN0YWxsIgoKJHNjcmlwdDpsb2dMaW5lcyA9IFtTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ11dOjpuZXcoKQoKZnVuY3Rpb24gR2V0LVdwZlJlc291cmNlIHsgcGFyYW0oJEtleSkgdHJ5IHsgJHdpbmRvdy5GaW5kUmVzb3VyY2UoJEtleSkgfSBjYXRjaCB7IFdyaXRlLUxvZyAiTWlzc2luZyBzdHlsZTogJEtleSIgIldhcm4iOyAkbnVsbCB9IH0KCmZ1bmN0aW9uIEludm9rZS1XUEZVSVRocmVhZCB7CiAgICBwYXJhbShbU2NyaXB0QmxvY2tdJFNjcmlwdEJsb2NrKQogICAgaWYgKCR3aW5kb3cgLWFuZCAkd2luZG93LkRpc3BhdGNoZXIgLWFuZCAhJHdpbmRvdy5EaXNwYXRjaGVyLkNoZWNrQWNjZXNzKCkpIHsKICAgICAgICAkd2luZG93LkRpc3BhdGNoZXIuSW52b2tlKFtBY3Rpb25deyAmICRTY3JpcHRCbG9jayB9LCAiTm9ybWFsIikKICAgIH0gZWxzZSB7CiAgICAgICAgJiAkU2NyaXB0QmxvY2sKICAgIH0KfQoKZnVuY3Rpb24gU2hvdy1Qcm9ncmVzcyB7CiAgICBwYXJhbShbc3RyaW5nXSRUZXh0LCBbc3RyaW5nXSRTdWJUZXh0ID0gIiIsIFtkb3VibGVdJFZhbHVlID0gLTEpCiAgICBpZiAoJHNjcmlwdDpOb1VJKSB7IFdyaXRlLUxvZyAiWyRUZXh0XSAkU3ViVGV4dCIgIkluZm8iOyByZXR1cm4gfQogICAgaWYgKCRjb250cm9sc1siUHJvZ3Jlc3NPdmVybGF5Il0pIHsKICAgICAgICBJbnZva2UtV1BGVUlUaHJlYWQgewogICAgICAgICAgICBpZiAoJGNvbnRyb2xzWyJQcm9ncmVzc1RleHQiXSkgeyAkY29udHJvbHNbIlByb2dyZXNzVGV4dCJdLlRleHQgPSAkVGV4dCB9CiAgICAgICAgICAgIGlmICgkY29udHJvbHNbIlByb2dyZXNzU3ViVGV4dCJdKSB7ICRjb250cm9sc1siUHJvZ3Jlc3NTdWJUZXh0Il0uVGV4dCA9ICRTdWJUZXh0IH0KICAgICAgICAgICAgaWYgKCRjb250cm9sc1siUHJvZ3Jlc3NCYXIiXSkgewogICAgICAgICAgICAgICAgaWYgKCRWYWx1ZSAtZ2UgMCkgeyAkY29udHJvbHNbIlByb2dyZXNzQmFyIl0uVmFsdWUgPSAkVmFsdWU7ICRjb250cm9sc1siUHJvZ3Jlc3NCYXIiXS5Jc0luZGV0ZXJtaW5hdGUgPSAkZmFsc2UgfQogICAgICAgICAgICAgICAgZWxzZSB7ICRjb250cm9sc1siUHJvZ3Jlc3NCYXIiXS5Jc0luZGV0ZXJtaW5hdGUgPSAkdHJ1ZSB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRjb250cm9sc1siUHJvZ3Jlc3NPdmVybGF5Il0pIHsgJGNvbnRyb2xzWyJQcm9ncmVzc092ZXJsYXkiXS5WaXNpYmlsaXR5ID0gIlZpc2libGUiIH0KICAgICAgICB9CiAgICB9CiAgICBpZiAoLW5vdCAkc2NyaXB0Ok5vVUkpIHsgU2V0LVByb2dyZXNzVGFza2JhciAtc3RhdGUgIk5vcm1hbCIgLXZhbHVlIChbbWF0aF06Ok1heCgwLjAxLCAkVmFsdWUpKSB9Cn0KCmZ1bmN0aW9uIEhpZGUtUHJvZ3Jlc3MgewogICAgaWYgKCRzY3JpcHQ6Tm9VSSkgeyByZXR1cm4gfQogICAgaWYgKCRjb250cm9sc1siUHJvZ3Jlc3NPdmVybGF5Il0pIHsKICAgICAgICBJbnZva2UtV1BGVUlUaHJlYWQgeyAkY29udHJvbHNbIlByb2dyZXNzT3ZlcmxheSJdLlZpc2liaWxpdHkgPSAiQ29sbGFwc2VkIiB9CiAgICB9CiAgICBTZXQtUHJvZ3Jlc3NUYXNrYmFyIC1zdGF0ZSAiTm9uZSIKfQoKZnVuY3Rpb24gU2V0LVByb2dyZXNzVGFza2JhciB7CiAgICBwYXJhbShbc3RyaW5nXSRzdGF0ZSA9ICJOb25lIiwgW2RvdWJsZV0kdmFsdWUgPSAwKQogICAgaWYgKCRzY3JpcHQ6Tm9VSSkgeyByZXR1cm4gfQogICAgdHJ5IHsKICAgICAgICBpZiAoLW5vdCAkd2luZG93KSB7IHJldHVybiB9CiAgICAgICAgJHRhc2tiYXIgPSAkd2luZG93LlRhc2tiYXJJdGVtSW5mbwogICAgICAgIGlmICgtbm90ICR0YXNrYmFyKSB7CiAgICAgICAgICAgICR0YXNrYmFyID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5TaGVsbC5UYXNrYmFySXRlbUluZm8KICAgICAgICAgICAgJHdpbmRvdy5UYXNrYmFySXRlbUluZm8gPSAkdGFza2JhcgogICAgICAgIH0KICAgICAgICBzd2l0Y2ggKCRzdGF0ZSkgewogICAgICAgICAgICAiTm9uZSIgeyAkdGFza2Jhci5Qcm9ncmVzc1N0YXRlID0gW1N5c3RlbS5XaW5kb3dzLlNoZWxsLlRhc2tiYXJJdGVtUHJvZ3Jlc3NTdGF0ZV06Ok5vbmUgfQogICAgICAgICAgICAiTm9ybWFsIiB7ICR0YXNrYmFyLlByb2dyZXNzU3RhdGUgPSBbU3lzdGVtLldpbmRvd3MuU2hlbGwuVGFza2Jhckl0ZW1Qcm9ncmVzc1N0YXRlXTo6Tm9ybWFsOyAkdGFza2Jhci5Qcm9ncmVzc1ZhbHVlID0gJHZhbHVlIH0KICAgICAgICAgICAgIkVycm9yIiB7ICR0YXNrYmFyLlByb2dyZXNzU3RhdGUgPSBbU3lzdGVtLldpbmRvd3MuU2hlbGwuVGFza2Jhckl0ZW1Qcm9ncmVzc1N0YXRlXTo6RXJyb3IgfQogICAgICAgICAgICAiSW5kZXRlcm1pbmF0ZSIgeyAkdGFza2Jhci5Qcm9ncmVzc1N0YXRlID0gW1N5c3RlbS5XaW5kb3dzLlNoZWxsLlRhc2tiYXJJdGVtUHJvZ3Jlc3NTdGF0ZV06OkluZGV0ZXJtaW5hdGUgfQogICAgICAgIH0KICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlRhc2tiYXIgcHJvZ3Jlc3MgZmFpbGVkOiAkXyIgIldhcm4iIH0KfQoKZnVuY3Rpb24gVXBkYXRlLUluc3RhbGxlZENhY2hlIHsKICAgIFdyaXRlLUxvZyAiVXBkYXRpbmcgaW5zdGFsbGVkIGFwcHMgY2FjaGUuLi4iICJJbmZvIgogICAgJHNjcmlwdDppbnN0YWxsZWRBcHBJZHMgPSBAe30KICAgIGlmICgtbm90IChHZXQtQ29tbWFuZCB3aW5nZXQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7IFdyaXRlLUxvZyAid2luZ2V0IG5vdCBhdmFpbGFibGUuIiAiV2FybiI7IHJldHVybiB9CiAgICB0cnkgewogICAgICAgICRsaW5lcyA9IHdpbmdldCBsaXN0IC0tYWNjZXB0LXNvdXJjZS1hZ3JlZW1lbnRzIDI+JjEgfCBXaGVyZS1PYmplY3QgeyAkXyAtbWF0Y2ggJ15bXHdcLVwuXStccysnIH0KICAgICAgICAkaW5zdGFsbGVkSWRzID0gQHt9CiAgICAgICAgZm9yZWFjaCAoJGxpbmUgaW4gJGxpbmVzKSB7CiAgICAgICAgICAgIGlmICgkbGluZSAtbWF0Y2ggJ14oW1x3XC1cLl0rKVxzKycpIHsgJGluc3RhbGxlZElkc1skbWF0Y2hlc1sxXS5Ub0xvd2VyKCldID0gJHRydWUgfQogICAgICAgIH0KICAgICAgICBmb3JlYWNoICgkY2F0IGluICRhcHBzQ29uZmlnLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICAgICBmb3JlYWNoICgkYXBwS2V5IGluICRhcHBzQ29uZmlnLiRjYXQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgICAgICAgICAkaWQgPSAkYXBwc0NvbmZpZy4kY2F0LiRhcHBLZXkud2luZ2V0CiAgICAgICAgICAgICAgICBpZiAoJGlkIC1hbmQgJGluc3RhbGxlZElkcy5Db250YWluc0tleSgkaWQuVG9Mb3dlcigpKSkgewogICAgICAgICAgICAgICAgICAgICRzY3JpcHQ6aW5zdGFsbGVkQXBwSWRzWyRpZF0gPSAkdHJ1ZQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiSW5zdGFsbGVkIGNhY2hlIHVwZGF0ZSBmYWlsZWQ6ICRfIiAiV2FybiIgfQogICAgV3JpdGUtTG9nICJJbnN0YWxsZWQgY2FjaGU6ICQoJHNjcmlwdDppbnN0YWxsZWRBcHBJZHMuQ291bnQpIGFwcHMiICJTdWNjZXNzIgp9Cgo='))
$script:installedAppIds = @{}
$sync = [Hashtable]::Synchronized(@{})
$sync.version = "2.0"
$sync.configs = @{}
$sync.ProcessRunning = $false
$sync.selectedApps = [System.Collections.Generic.List[string]]::new()
$sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
$sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()
$sync.currentTab = "Install"

$script:logLines = [System.Collections.Generic.List[string]]::new()

function Get-WpfResource { param($Key) try { $window.FindResource($Key) } catch { Write-Log "Missing style: $Key" "Warn"; $null } }

function Invoke-WPFUIThread {
    param([ScriptBlock]$ScriptBlock)
    if ($window -and $window.Dispatcher -and !$window.Dispatcher.CheckAccess()) {
        $window.Dispatcher.Invoke([Action]{ & $ScriptBlock }, "Normal")
    } else {
        & $ScriptBlock
    }
}

function Show-Progress {
    param([string]$Text, [string]$SubText = "", [double]$Value = -1)
    if ($script:NoUI) { Write-Log "[$Text] $SubText" "Info"; return }
    if ($controls["ProgressOverlay"]) {
        Invoke-WPFUIThread {
            if ($controls["ProgressText"]) { $controls["ProgressText"].Text = $Text }
            if ($controls["ProgressSubText"]) { $controls["ProgressSubText"].Text = $SubText }
            if ($controls["ProgressBar"]) {
                if ($Value -ge 0) { $controls["ProgressBar"].Value = $Value; $controls["ProgressBar"].IsIndeterminate = $false }
                else { $controls["ProgressBar"].IsIndeterminate = $true }
            }
            if ($controls["ProgressOverlay"]) { $controls["ProgressOverlay"].Visibility = "Visible" }
        }
    }
    if (-not $script:NoUI) { Set-ProgressTaskbar -state "Normal" -value ([math]::Max(0.01, $Value)) }
}

function Hide-Progress {
    if ($script:NoUI) { return }
    if ($controls["ProgressOverlay"]) {
        Invoke-WPFUIThread { $controls["ProgressOverlay"].Visibility = "Collapsed" }
    }
    Set-ProgressTaskbar -state "None"
}

function Set-ProgressTaskbar {
    param([string]$state = "None", [double]$value = 0)
    if ($script:NoUI) { return }
    try {
        if (-not $window) { return }
        $taskbar = $window.TaskbarItemInfo
        if (-not $taskbar) {
            $taskbar = New-Object System.Windows.Shell.TaskbarItemInfo
            $window.TaskbarItemInfo = $taskbar
        }
        switch ($state) {
            "None" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::None }
            "Normal" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Normal; $taskbar.ProgressValue = $value }
            "Error" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Error }
            "Indeterminate" { $taskbar.ProgressState = [System.Windows.Shell.TaskbarItemProgressState]::Indeterminate }
        }
    } catch { Write-Log "Taskbar progress failed: $_" "Warn" }
}

function Update-InstalledCache {
    Write-Log "Updating installed apps cache..." "Info"
    $script:installedAppIds = @{}
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "winget not available." "Warn"; return }
    try {
        $lines = winget list --accept-source-agreements 2>&1 | Where-Object { $_ -match '^[\w\-\.]+\s+' }
        $installedIds = @{}
        foreach ($line in $lines) {
            if ($line -match '^([\w\-\.]+)\s+') { $installedIds[$matches[1].ToLower()] = $true }
        }
        foreach ($cat in $appsConfig.PSObject.Properties.Name) {
            foreach ($appKey in $appsConfig.$cat.PSObject.Properties.Name) {
                $id = $appsConfig.$cat.$appKey.winget
                if ($id -and $installedIds.ContainsKey($id.ToLower())) {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch { Write-Log "Installed cache update failed: $_" "Warn" }
    Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success"
}


$script:__mod_theme = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpjdXJyZW50VGhlbWUgPSAiZGFyayIKCmZ1bmN0aW9uIEFwcGx5LVRoZW1lIHsKICAgIHBhcmFtKCRUaGVtZU5hbWUpCiAgICAka2V5ID0gJFRoZW1lTmFtZS5Ub0xvd2VyKCkKICAgIGlmICgtbm90ICRzY3JpcHQ6dGhlbWVzQ29uZmlnIC1vciAtbm90ICRzY3JpcHQ6dGhlbWVzQ29uZmlnLiRrZXkpIHsKICAgICAgICBXcml0ZS1Mb2cgIlRoZW1lICckVGhlbWVOYW1lJyBub3QgZm91bmQgaW4gdGhlbWVzIGNvbmZpZy4iICJXYXJuIgogICAgICAgIHJldHVybgogICAgfQogICAgdHJ5IHsKICAgICAgICAkY29sb3JzID0gJHNjcmlwdDp0aGVtZXNDb25maWcuJGtleQogICAgICAgICRjb252ZXJ0ZXIgPSBbU3lzdGVtLldpbmRvd3MuTWVkaWEuQnJ1c2hDb252ZXJ0ZXJdOjpuZXcoKQogICAgICAgICRuZXdEaWN0ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5SZXNvdXJjZURpY3Rpb25hcnkKCiAgICAgICAgZm9yZWFjaCAoJHByb3AgaW4gJGNvbG9ycy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpIHsKICAgICAgICAgICAgJGJydXNoID0gJGNvbnZlcnRlci5Db252ZXJ0RnJvbSgkY29sb3JzLiRwcm9wKQogICAgICAgICAgICAkbmV3RGljdC5BZGQoJHByb3AsICRicnVzaCkKICAgICAgICB9CiAgICAgICAgaWYgKCRjb252ZXJ0ZXIgLWFuZCAkY29udmVydGVyLkdldFR5cGUoKS5HZXRNZXRob2QoJ0Rpc3Bvc2UnKSkgeyAkY29udmVydGVyLkRpc3Bvc2UoKSB9CgogICAgICAgICRzY3JpcHQ6Y3VycmVudFRoZW1lID0gJFRoZW1lTmFtZQogICAgICAgIFdyaXRlLUxvZyAiVGhlbWU6ICRUaGVtZU5hbWUiICJTdWNjZXNzIgoKICAgICAgICBpZiAoW1N5c3RlbS5XaW5kb3dzLkFwcGxpY2F0aW9uXTo6Q3VycmVudCkgewogICAgICAgICAgICAkYXBwUmVzb3VyY2VzID0gW1N5c3RlbS5XaW5kb3dzLkFwcGxpY2F0aW9uXTo6Q3VycmVudC5SZXNvdXJjZXMKICAgICAgICAgICAgJGV4aXN0aW5nVGhlbWUgPSBAKCRhcHBSZXNvdXJjZXMuTWVyZ2VkRGljdGlvbmFyaWVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uU291cmNlIC1lcSAkbnVsbCAtYW5kICRfLkNvdW50IC1ndCAwIC1hbmQgLW5vdCAkXy5Db250YWlucygiVG9vbEJhckJ1dHRvbkJhc2VTdHlsZSIpIH0pCiAgICAgICAgICAgIGZvcmVhY2ggKCRkaWN0IGluICRleGlzdGluZ1RoZW1lKSB7ICRhcHBSZXNvdXJjZXMuTWVyZ2VkRGljdGlvbmFyaWVzLlJlbW92ZSgkZGljdCkgfQogICAgICAgICAgICAkYXBwUmVzb3VyY2VzLk1lcmdlZERpY3Rpb25hcmllcy5BZGQoJG5ld0RpY3QpCiAgICAgICAgfSBlbHNlaWYgKCR3aW5kb3cpIHsKICAgICAgICAgICAgJGV4aXN0aW5nVGhlbWUgPSBAKCR3aW5kb3cuUmVzb3VyY2VzLk1lcmdlZERpY3Rpb25hcmllcyB8IFdoZXJlLU9iamVjdCB7ICRfLlNvdXJjZSAtZXEgJG51bGwgfSkKICAgICAgICAgICAgZm9yZWFjaCAoJGRpY3QgaW4gJGV4aXN0aW5nVGhlbWUpIHsgJHdpbmRvdy5SZXNvdXJjZXMuTWVyZ2VkRGljdGlvbmFyaWVzLlJlbW92ZSgkZGljdCkgfQogICAgICAgICAgICAkd2luZG93LlJlc291cmNlcy5NZXJnZWREaWN0aW9uYXJpZXMuQWRkKCRuZXdEaWN0KQogICAgICAgIH0KCiAgICAgICAgaWYgKCR3aW5kb3cgLWFuZCAkY29sb3JzLndpbmRvd0JhY2tncm91bmQpIHsKICAgICAgICAgICAgJHdpbmRvdy5CYWNrZ3JvdW5kID0gJGNvbnZlcnRlci5Db252ZXJ0RnJvbSgkY29sb3JzLndpbmRvd0JhY2tncm91bmQpCiAgICAgICAgfQogICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiVGhlbWUgYXBwbHkgZmFpbGVkOiAkXyIgIkVycm9yIiB9Cn0K'))
$script:currentTheme = "dark"

function Apply-Theme {
    param($ThemeName)
    $key = $ThemeName.ToLower()
    if (-not $script:themesConfig -or -not $script:themesConfig.$key) {
        Write-Log "Theme '$ThemeName' not found in themes config." "Warn"
        return
    }
    try {
        $colors = $script:themesConfig.$key
        $converter = [System.Windows.Media.BrushConverter]::new()
        $newDict = New-Object System.Windows.ResourceDictionary

        foreach ($prop in $colors.PSObject.Properties.Name) {
            $brush = $converter.ConvertFrom($colors.$prop)
            $newDict.Add($prop, $brush)
        }
        if ($converter -and $converter.GetType().GetMethod('Dispose')) { $converter.Dispose() }

        $script:currentTheme = $ThemeName
        Write-Log "Theme: $ThemeName" "Success"

        if ([System.Windows.Application]::Current) {
            $appResources = [System.Windows.Application]::Current.Resources
            $existingTheme = @($appResources.MergedDictionaries | Where-Object { $_.Source -eq $null -and $_.Count -gt 0 -and -not $_.Contains("ToolBarButtonBaseStyle") })
            foreach ($dict in $existingTheme) { $appResources.MergedDictionaries.Remove($dict) }
            $appResources.MergedDictionaries.Add($newDict)
        } elseif ($window) {
            $existingTheme = @($window.Resources.MergedDictionaries | Where-Object { $_.Source -eq $null })
            foreach ($dict in $existingTheme) { $window.Resources.MergedDictionaries.Remove($dict) }
            $window.Resources.MergedDictionaries.Add($newDict)
        }

        if ($window -and $colors.windowBackground) {
            $window.Background = $converter.ConvertFrom($colors.windowBackground)
        }
    } catch { Write-Log "Theme apply failed: $_" "Error" }
}

$script:__mod_navigation = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpwYWdlcyA9IEB7fQokc2NyaXB0Om5hdkJ1dHRvbnMgPSBAe30KJHNjcmlwdDpuYXZOYW1lcyA9IEAoIkluc3RhbGwiLCAiVHdlYWtzIiwgIkZlYXR1cmVzIiwgIlByZWZlcmVuY2VzIiwgIkxlZ2FjeSIsICJTZXR0aW5ncyIpCgpmdW5jdGlvbiBTaG93LU5hdlBhbmVsIHsKICAgIHBhcmFtKCROYW1lKQogICAgZm9yZWFjaCAoJG90aGVyIGluICRuYXZOYW1lcykgewogICAgICAgIGlmICgkY29udHJvbHNbIlBhZ2Ukb3RoZXIiXSkgeyAkY29udHJvbHNbIlBhZ2Ukb3RoZXIiXS5WaXNpYmlsaXR5ID0gIkNvbGxhcHNlZCIgfQogICAgfQogICAgaWYgKCRjb250cm9sc1siUGFnZSROYW1lIl0pIHsgJGNvbnRyb2xzWyJQYWdlJE5hbWUiXS5WaXNpYmlsaXR5ID0gIlZpc2libGUiOyAkc3luYy5jdXJyZW50VGFiID0gJE5hbWU7IFdyaXRlLUxvZyAiU3dpdGNoZWQgdG86ICROYW1lIiAiSW5mbyIgfQp9CgpmdW5jdGlvbiBTd2l0Y2gtUGFnZSB7IHBhcmFtKCROYW1lKTsgU2hvdy1OYXZQYW5lbCAkTmFtZSB9CgppZiAoJGNvbnRyb2xzLkNvdW50KSB7CiAgICBmb3JlYWNoICgkbiBpbiAkbmF2TmFtZXMpIHsKICAgICAgICBpZiAoJGNvbnRyb2xzWyJQYWdlJG4iXSkgeyAkcGFnZXNbJG5dID0gJGNvbnRyb2xzWyJQYWdlJG4iXSB9CiAgICAgICAgaWYgKCRjb250cm9sc1siTmF2JG4iXSkgeyAkbmF2QnV0dG9uc1skbl0gPSAkY29udHJvbHNbIk5hdiRuIl0gfQogICAgfQogICAgZm9yZWFjaCAoJG5hdk5hbWUgaW4gJG5hdk5hbWVzKSB7CiAgICAgICAgJGJ0bk5hbWUgPSAiTmF2JG5hdk5hbWUiCiAgICAgICAgJGJ0biA9ICRjb250cm9sc1skYnRuTmFtZV0KICAgICAgICBpZiAoJGJ0bikgewogICAgICAgICAgICAkYnRuLlRhZyA9ICRuYXZOYW1lCiAgICAgICAgICAgICRidG4uQWRkX0NsaWNrKHsgU2hvdy1OYXZQYW5lbCAkdGhpcy5UYWcgfSkKICAgICAgICAgICAgaWYgKCRidG4uUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiSXNFbmFibGVkIikgeyAkYnRuLklzRW5hYmxlZCA9ICR0cnVlIH0KICAgICAgICAgICAgV3JpdGUtTG9nICJOYXZpZ2F0aW9uOiAkYnRuTmFtZSB3aXJlZC4iICJTdWNjZXNzIgogICAgICAgIH0KICAgIH0KICAgIGlmICgkd2luZG93KSB7ICR3aW5kb3cuQWRkX0tleURvd24oewogICAgICAgIHBhcmFtKCRzZW5kZXIsICRlKQogICAgICAgICAgICBpZiAoJGUuS2V5IC1lcSAiRXNjYXBlIiAtYW5kICRjb250cm9sc1siU2VhcmNoQm94Il0pIHsKICAgICAgICAgICAgICAgICRjb250cm9sc1siU2VhcmNoQm94Il0uVGV4dCA9ICIiCiAgICAgICAgICAgICAgICBTaG93LU5hdlBhbmVsICRuYXZOYW1lc1swXQogICAgICAgICAgICAgICAgJGUuSGFuZGxlZCA9ICR0cnVlCiAgICAgICAgICAgIH0KICAgICAgICB9KQogICAgfQp9Cg=='))
$script:pages = @{}
$script:navButtons = @{}
$script:navNames = @("Install", "Tweaks", "Features", "Preferences", "Legacy", "Settings")

function Show-NavPanel {
    param($Name)
    foreach ($other in $navNames) {
        if ($controls["Page$other"]) { $controls["Page$other"].Visibility = "Collapsed" }
    }
    if ($controls["Page$Name"]) { $controls["Page$Name"].Visibility = "Visible"; $sync.currentTab = $Name; Write-Log "Switched to: $Name" "Info" }
}

function Switch-Page { param($Name); Show-NavPanel $Name }

if ($controls.Count) {
    foreach ($n in $navNames) {
        if ($controls["Page$n"]) { $pages[$n] = $controls["Page$n"] }
        if ($controls["Nav$n"]) { $navButtons[$n] = $controls["Nav$n"] }
    }
    foreach ($navName in $navNames) {
        $btnName = "Nav$navName"
        $btn = $controls[$btnName]
        if ($btn) {
            $btn.Tag = $navName
            $btn.Add_Click({ Show-NavPanel $this.Tag })
            if ($btn.PSObject.Properties.Name -contains "IsEnabled") { $btn.IsEnabled = $true }
            Write-Log "Navigation: $btnName wired." "Success"
        }
    }
    if ($window) { $window.Add_KeyDown({
        param($sender, $e)
            if ($e.Key -eq "Escape" -and $controls["SearchBox"]) {
                $controls["SearchBox"].Text = ""
                Show-NavPanel $navNames[0]
                $e.Handled = $true
            }
        })
    }
}

$script:__mod_tweaks = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDp0d2Vha1VuZG9Mb2cgPSBAe30KJHNjcmlwdDpsYXN0UmVzdG9yZVBvaW50ID0gJG51bGwKCmZ1bmN0aW9uIFNhdmUtT3JpZ2luYWxWYWx1ZXMgewogICAgcGFyYW0oJHR3ZWFrS2V5LCAkdHdlYWspCiAgICBpZiAoJHNjcmlwdDp0d2Vha1VuZG9Mb2cuQ29udGFpbnNLZXkoJHR3ZWFrS2V5KSkgeyByZXR1cm4gfQogICAgJHVuZG9FbnRyeSA9IEB7IEtleSA9ICR0d2Vha0tleTsgUmVnaXN0cnkgPSBAKCk7IFNlcnZpY2VzID0gQCgpOyBTY3JpcHRzID0gQCgpIH0KICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAicmVnaXN0cnkiKSB7CiAgICAgICAgZm9yZWFjaCAoJHJlZyBpbiAkdHdlYWsucmVnaXN0cnkpIHsKICAgICAgICAgICAgJGN1cnJlbnRWYWx1ZSA9ICRudWxsCiAgICAgICAgICAgIGlmICgkcmVnLnBhdGggLWFuZCAoVGVzdC1QYXRoICRyZWcucGF0aCkpIHsKICAgICAgICAgICAgICAgIHRyeSB7ICRjdXJyZW50VmFsdWUgPSAoR2V0LUl0ZW1Qcm9wZXJ0eSAkcmVnLnBhdGggLU5hbWUgJHJlZy5uYW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS4kKCRyZWcubmFtZSkgfSBjYXRjaCB7IFdyaXRlLUxvZyAiUmVnaXN0cnkgcmVhZCBmYWlsZWQgZm9yIHVuZG86ICRfIiAiV2FybiIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICR1bmRvRW50cnkuUmVnaXN0cnkgKz0gQHsgUGF0aCA9ICRyZWcucGF0aDsgTmFtZSA9ICRyZWcubmFtZTsgT3JpZ2luYWxWYWx1ZSA9ICRjdXJyZW50VmFsdWU7IFR5cGUgPSAkcmVnLnR5cGUgfQogICAgICAgIH0KICAgIH0KICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAic2VydmljZXMiKSB7CiAgICAgICAgZm9yZWFjaCAoJHN2YyBpbiAkdHdlYWsuc2VydmljZXMpIHsKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRzdmNPYmogPSBHZXQtU2VydmljZSAkc3ZjLm5hbWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgICAgIGlmICgkc3ZjT2JqKSB7CiAgICAgICAgICAgICAgICAgICAgJHVuZG9FbnRyeS5TZXJ2aWNlcyArPSBAeyBOYW1lID0gJHN2Yy5uYW1lOyBPcmlnaW5hbFN0YXR1cyA9ICRzdmNPYmouU3RhdHVzOyBPcmlnaW5hbFN0YXJ0dXAgPSAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1NlcnZpY2UgLUZpbHRlciAiTmFtZT0nJCgkc3ZjLm5hbWUpJyIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLlN0YXJ0TW9kZSB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJTZXJ2aWNlIGNhcHR1cmUgZmFpbGVkOiAkXyIgIldhcm4iIH0KICAgICAgICB9CiAgICB9CiAgICBpZiAoJHR3ZWFrLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgInVuZG9TY3JpcHQiKSB7ICR1bmRvRW50cnkuU2NyaXB0cyArPSAkdHdlYWsudW5kb1NjcmlwdCB9CiAgICAkc2NyaXB0OnR3ZWFrVW5kb0xvZ1skdHdlYWtLZXldID0gJHVuZG9FbnRyeQp9CgpmdW5jdGlvbiBOZXctU3lzdGVtUmVzdG9yZVBvaW50IHsKICAgIHBhcmFtKFtzdHJpbmddJERlc2NyaXB0aW9uID0gIkhrc1V0aWwgVHdlYWtzIikKICAgIHRyeSB7CiAgICAgICAgQ2hlY2twb2ludC1Db21wdXRlciAtRGVzY3JpcHRpb24gJERlc2NyaXB0aW9uIC1SZXN0b3JlUG9pbnRUeXBlIE1PRElGWV9TRVRUSU5HUyAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgICRzY3JpcHQ6bGFzdFJlc3RvcmVQb2ludCA9IEdldC1EYXRlCiAgICAgICAgV3JpdGUtTG9nICJSZXN0b3JlIHBvaW50IGNyZWF0ZWQ6ICREZXNjcmlwdGlvbiIgIlN1Y2Nlc3MiCiAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJSZXN0b3JlIHBvaW50IHNraXBwZWQgKHNlcnZpY2Ugbm90IGF2YWlsYWJsZSk6ICRfIiAiV2FybiIgfQp9CgpmdW5jdGlvbiBJbnZva2UtVW5kb1R3ZWFrcyB7CiAgICBpZiAoJHNjcmlwdDp0d2Vha1VuZG9Mb2cuQ291bnQgLWVxIDApIHsgV3JpdGUtTG9nICJObyB0d2Vha3MgdG8gdW5kby4iICJXYXJuIjsgcmV0dXJuIH0KCiAgICAkc2IgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlN0YWNrUGFuZWw7ICRzYi5PcmllbnRhdGlvbiA9ICJWZXJ0aWNhbCIKICAgICRzYi5DaGlsZHJlbi5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrIC1Qcm9wZXJ0eSBAeyBUZXh0ID0gIkNob29zZSB1bmRvIG1ldGhvZDoiOyBNYXJnaW4gPSAiMCwwLDAsMTAiOyBGb250V2VpZ2h0ID0gIkJvbGQiIH0pKSB8IE91dC1OdWxsCiAgICAkcmJMb2cgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlJhZGlvQnV0dG9uIC1Qcm9wZXJ0eSBAeyBDb250ZW50ID0gIlVuZG8gdmlhIExvZyAocmVnaXN0cnkgKyBzZXJ2aWNlcykiOyBJc0NoZWNrZWQgPSAkdHJ1ZTsgTWFyZ2luID0gIjAsMCwwLDUiIH0KICAgICRyYlJlc3RvcmUgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlJhZGlvQnV0dG9uIC1Qcm9wZXJ0eSBAeyBDb250ZW50ID0gIlN5c3RlbSBSZXN0b3JlIChyb2xsIGJhY2sgdG8gbGFzdCByZXN0b3JlIHBvaW50KSI7IE1hcmdpbiA9ICIwLDAsMCw1IiB9CiAgICBpZiAoLW5vdCAoR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgeyAkcmJSZXN0b3JlLklzRW5hYmxlZCA9ICRmYWxzZTsgJHJiUmVzdG9yZS5Db250ZW50ICs9ICIgKG5vbmUgYXZhaWxhYmxlKSIgfQogICAgJHNiLkNoaWxkcmVuLkFkZCgkcmJMb2cpIHwgT3V0LU51bGw7ICRzYi5DaGlsZHJlbi5BZGQoJHJiUmVzdG9yZSkgfCBPdXQtTnVsbAoKICAgICR3ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5XaW5kb3cgLVByb3BlcnR5IEB7IFRpdGxlID0gIlVuZG8gVHdlYWtzIjsgQ29udGVudCA9ICRzYjsgV2lkdGggPSA0MjA7IEhlaWdodCA9IDE4MDsgV2luZG93U3RhcnR1cExvY2F0aW9uID0gIkNlbnRlck93bmVyIjsgT3duZXIgPSAkd2luZG93OyBTaG93SW5UYXNrYmFyID0gJGZhbHNlIH0KICAgICRidG5QYW5lbCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuU3RhY2tQYW5lbCAtUHJvcGVydHkgQHsgT3JpZW50YXRpb24gPSAiSG9yaXpvbnRhbCI7IEhvcml6b250YWxBbGlnbm1lbnQgPSAiUmlnaHQiOyBNYXJnaW4gPSAiMCwxNSwwLDAiIH0KICAgICRva0J0biA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuQnV0dG9uIC1Qcm9wZXJ0eSBAeyBDb250ZW50ID0gIk9LIjsgV2lkdGggPSA4MDsgSGVpZ2h0ID0gMjg7IE1hcmdpbiA9ICIwLDAsMTAsMCI7IElzRGVmYXVsdCA9ICR0cnVlIH0KICAgICRjYW5jZWxCdG4gPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkJ1dHRvbiAtUHJvcGVydHkgQHsgQ29udGVudCA9ICJDYW5jZWwiOyBXaWR0aCA9IDgwOyBIZWlnaHQgPSAyODsgSXNDYW5jZWwgPSAkdHJ1ZSB9CiAgICAkYnRuUGFuZWwuQ2hpbGRyZW4uQWRkKCRva0J0bikgfCBPdXQtTnVsbDsgJGJ0blBhbmVsLkNoaWxkcmVuLkFkZCgkY2FuY2VsQnRuKSB8IE91dC1OdWxsCiAgICAkc2IuQ2hpbGRyZW4uQWRkKCRidG5QYW5lbCkgfCBPdXQtTnVsbAogICAgJHJlc3VsdCA9ICRmYWxzZQogICAgJG9rQnRuLkFkZF9DbGljayh7ICRyZXN1bHQgPSAkdHJ1ZTsgJHcuQ2xvc2UoKSB9KQogICAgJGNhbmNlbEJ0bi5BZGRfQ2xpY2soeyAkdy5DbG9zZSgpIH0pCiAgICAkdy5TaG93RGlhbG9nKCkgfCBPdXQtTnVsbAogICAgaWYgKC1ub3QgJHJlc3VsdCkgeyByZXR1cm4gfQoKICAgIGlmICgkcmJSZXN0b3JlLklzQ2hlY2tlZCkgewogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRycCA9IEdldC1Db21wdXRlclJlc3RvcmVQb2ludCB8IFNvcnQtT2JqZWN0IENyZWF0aW9uVGltZSAtRGVzY2VuZGluZyB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgaWYgKCRycCkgeyBXcml0ZS1Mb2cgIlN0YXJ0aW5nIHN5c3RlbSByZXN0b3JlIHRvICQoJHJwLkRlc2NyaXB0aW9uKS4uLiIgIkhlYWRlciI7IFNob3ctSW5mbyAiU3lzdGVtIFJlc3RvcmUiICJZb3VyIGNvbXB1dGVyIHdpbGwgcmVzdGFydCB0byBjb21wbGV0ZSB0aGUgc3lzdGVtIHJlc3RvcmUuIjsgUmVzdG9yZS1Db21wdXRlciAtUmVzdG9yZVBvaW50ICRycC5TZXF1ZW5jZU51bWJlciAtQ29uZmlybTokZmFsc2UgfQogICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlN5c3RlbSByZXN0b3JlIGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgICAgIHJldHVybgogICAgfQoKICAgIFdyaXRlLUxvZyAiVW5kb2luZyBsYXN0IHR3ZWFrcyB2aWEgbG9nLi4uIiAiSGVhZGVyIgogICAgJHR3ZWFrTmFtZXMgPSAkc2NyaXB0OnR3ZWFrVW5kb0xvZy5LZXlzIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5SZXBsYWNlKCJXUEZUd2Vha3MiLCAiIikgLXJlcGxhY2UgIihbYS16XSkoW0EtWl0pIiwgJyQxICQyJyB9CiAgICAkbXNnID0gIlVuZG8gdGhlIGZvbGxvd2luZyB0d2Vha3M/YG5gbiIgKyAoJHR3ZWFrTmFtZXMgLWpvaW4gImBuIikKICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIlVuZG8gdmlhIExvZyIgJG1zZykpIHsgcmV0dXJuIH0KICAgIGZvcmVhY2ggKCRrZXkgaW4gJHNjcmlwdDp0d2Vha1VuZG9Mb2cuS2V5cykgewogICAgICAgICRlbnRyeSA9ICRzY3JpcHQ6dHdlYWtVbmRvTG9nWyRrZXldCiAgICAgICAgV3JpdGUtTG9nICJVbmRvaW5nOiAkKCRlbnRyeS5LZXkpIiAiSW5mbyIKICAgICAgICBmb3JlYWNoICgkc3ZjIGluICRlbnRyeS5TZXJ2aWNlcykgewogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgaWYgKCRzdmMuT3JpZ2luYWxTdGFydHVwIC1hbmQgJHN2Yy5PcmlnaW5hbFN0YXJ0dXAgLW5lICJEaXNhYmxlZCIpIHsgJHN0YXJ0VHlwZSA9ICRzdmMuT3JpZ2luYWxTdGFydHVwOyBpZiAoJHN0YXJ0VHlwZSAtZXEgIkF1dG8iKSB7ICRzdGFydFR5cGUgPSAiQXV0b21hdGljIiB9OyBTZXQtU2VydmljZSAkc3ZjLk5hbWUgLVN0YXJ0dXBUeXBlICRzdGFydFR5cGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICAgICAgICAgaWYgKCRzdmMuT3JpZ2luYWxTdGF0dXMgLWFuZCAkc3ZjLk9yaWdpbmFsU3RhdHVzIC1uZSAiU3RvcHBlZCIpIHsgU3RhcnQtU2VydmljZSAkc3ZjLk5hbWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJTZXJ2aWNlICQoJHN2Yy5OYW1lKSByZXN0b3JlZC4iICJTdWNjZXNzIgogICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJTZXJ2aWNlIHVuZG8gZmFpbGVkOiAkXyIgIkVycm9yIiB9CiAgICAgICAgfQogICAgICAgIGZvcmVhY2ggKCRyZWcgaW4gJGVudHJ5LlJlZ2lzdHJ5KSB7CiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICBpZiAoIShUZXN0LVBhdGggJHJlZy5QYXRoKSkgeyBOZXctSXRlbSAkcmVnLlBhdGggLUZvcmNlIHwgT3V0LU51bGwgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcmVnLk9yaWdpbmFsVmFsdWUpIHsgU2V0LUl0ZW1Qcm9wZXJ0eSAkcmVnLlBhdGggLU5hbWUgJHJlZy5OYW1lIC1WYWx1ZSAkcmVnLk9yaWdpbmFsVmFsdWUgLVR5cGUgJHJlZy5UeXBlIC1Gb3JjZSB9CiAgICAgICAgICAgICAgICBlbHNlIHsgUmVtb3ZlLUl0ZW1Qcm9wZXJ0eSAkcmVnLlBhdGggLU5hbWUgJHJlZy5OYW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICAgICAgICAgIFdyaXRlLUxvZyAiUmVnaXN0cnkgJCgkcmVnLk5hbWUpIHJlc3RvcmVkLiIgIlN1Y2Nlc3MiCiAgICAgICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlJlZ2lzdHJ5IHVuZG8gZmFpbGVkOiAkXyIgIkVycm9yIiB9CiAgICAgICAgfQogICAgICAgIGZvcmVhY2ggKCRzY3JpcHRCbG9jayBpbiAkZW50cnkuU2NyaXB0cykgewogICAgICAgICAgICB0cnkgeyAmIChbc2NyaXB0YmxvY2tdOjpDcmVhdGUoJHNjcmlwdEJsb2NrKSk7IFdyaXRlLUxvZyAiVW5kbyBzY3JpcHQgZXhlY3V0ZWQuIiAiU3VjY2VzcyIgfSBjYXRjaCB7IFdyaXRlLUxvZyAiVW5kbyBzY3JpcHQgZmFpbGVkOiAkXyIgIkVycm9yIiB9CiAgICAgICAgfQogICAgfQogICAgJHNjcmlwdDp0d2Vha1VuZG9Mb2cgPSBAe30KICAgIFdyaXRlLUxvZyAiQWxsIHR3ZWFrcyB1bmRvbmUuIiAiSGVhZGVyIgp9CgppZiAoJGNvbnRyb2xzWyJCdG5SdW5Ud2Vha3MiXSkgewogICAgJGNvbnRyb2xzWyJCdG5SdW5Ud2Vha3MiXS5BZGRfQ2xpY2soewogICAgICAgICRzZWxlY3RlZCA9ICR0d2Vha0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0KICAgICAgICBpZiAoJHNlbGVjdGVkLkNvdW50IC1lcSAwKSB7IFdyaXRlLUxvZyAiTm8gdHdlYWtzIHNlbGVjdGVkLiIgIldhcm4iOyByZXR1cm4gfQogICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIlJ1biBUd2Vha3MiICJBcHBseSAkKCRzZWxlY3RlZC5Db3VudCkgdHdlYWsocyk/YG5gbkEgc3lzdGVtIHJlc3RvcmUgcG9pbnQgd2lsbCBiZSBjcmVhdGVkIGZpcnN0LiIpKSB7IHJldHVybiB9CiAgICAgICAgV3JpdGUtTG9nICJDcmVhdGluZyByZXN0b3JlIHBvaW50Li4uIiAiSW5mbyIKICAgICAgICBOZXctU3lzdGVtUmVzdG9yZVBvaW50CiAgICAgICAgV3JpdGUtTG9nICJSdW5uaW5nIFNlbGVjdGVkIFR3ZWFrcy4uLiIgIkhlYWRlciIKICAgICAgICBTZXQtU3RhdHVzICJBcHBseWluZyAkKCRzZWxlY3RlZC5Db3VudCkgdHdlYWsocykuLi4iCiAgICAgICAgZm9yZWFjaCAoJGNiIGluICRzZWxlY3RlZCkgewogICAgICAgICAgICAkdHdlYWtLZXkgPSAkY2IuVGFnOyAkdHdlYWsgPSAkbnVsbAogICAgICAgICAgICBmb3JlYWNoICgkZ3JvdXBLZXkgaW4gJHR3ZWFrc0NvbmZpZy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpIHsKICAgICAgICAgICAgICAgICRncm91cCA9ICR0d2Vha3NDb25maWcuJGdyb3VwS2V5CiAgICAgICAgICAgICAgICBpZiAoJGdyb3VwLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJHR3ZWFrS2V5KSB7ICR0d2VhayA9ICRncm91cC4kdHdlYWtLZXk7IGJyZWFrIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoLW5vdCAkdHdlYWspIHsgY29udGludWUgfQogICAgICAgICAgICBXcml0ZS1Mb2cgIkFwcGx5aW5nOiAkKCR0d2Vhay5jb250ZW50KSIgIkluZm8iCiAgICAgICAgICAgIFNhdmUtT3JpZ2luYWxWYWx1ZXMgLXR3ZWFrS2V5ICR0d2Vha0tleSAtdHdlYWsgJHR3ZWFrCiAgICAgICAgICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAic2VydmljZXMiKSB7CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkc3ZjIGluICR0d2Vhay5zZXJ2aWNlcykgewogICAgICAgICAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAgICAgICAgIGlmICgkc3ZjLmFjdGlvbiAtZXEgInN0b3BfZGlzYWJsZSIpIHsgU3RvcC1TZXJ2aWNlICRzdmMubmFtZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWU7IFNldC1TZXJ2aWNlICRzdmMubmFtZSAtU3RhcnR1cFR5cGUgRGlzYWJsZWQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICAgICAgICAgICAgICAgICBpZiAoJHN2Yy5hY3Rpb24gLWVxICJzZXRfbWFudWFsIikgeyBTZXQtU2VydmljZSAkc3ZjLm5hbWUgLVN0YXJ0dXBUeXBlIE1hbnVhbCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgICAgICAgICAgICAgIFdyaXRlLUxvZyAiU2VydmljZSAkKCRzdmMubmFtZSk6ICQoJHN2Yy5hY3Rpb24pIiAiU3VjY2VzcyIKICAgICAgICAgICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJTZXJ2aWNlICQoJHN2Yy5uYW1lKSBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJHR3ZWFrLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgInJlZ2lzdHJ5IikgewogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHJlZyBpbiAkdHdlYWsucmVnaXN0cnkpIHsKICAgICAgICAgICAgICAgICAgICB0cnkgeyBpZiAoIShUZXN0LVBhdGggJHJlZy5wYXRoKSkgeyBOZXctSXRlbSAkcmVnLnBhdGggLUZvcmNlIHwgT3V0LU51bGwgfTsgU2V0LUl0ZW1Qcm9wZXJ0eSAkcmVnLnBhdGggLU5hbWUgJHJlZy5uYW1lIC1WYWx1ZSAkcmVnLnZhbHVlIC1UeXBlICRyZWcudHlwZSAtRm9yY2U7IFdyaXRlLUxvZyAiUmVnaXN0cnk6ICQoJHJlZy5uYW1lKSA9ICQoJHJlZy52YWx1ZSkiICJTdWNjZXNzIiB9IGNhdGNoIHsgV3JpdGUtTG9nICJSZWdpc3RyeSBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJHR3ZWFrLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgImFwcHhfcGFja2FnZXMiKSB7CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcGtnIGluICR0d2Vhay5hcHB4X3BhY2thZ2VzKSB7CiAgICAgICAgICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICAgICAgICAgR2V0LUFwcHhQYWNrYWdlIC1OYW1lICRwa2cgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBSZW1vdmUtQXBweFBhY2thZ2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgICAgICAgICAgICAgR2V0LUFwcHhQcm92aXNpb25lZFBhY2thZ2UgLU9ubGluZSB8IFdoZXJlLU9iamVjdCB7ICRfLkRpc3BsYXlOYW1lIC1saWtlICRwa2cgfSB8IFJlbW92ZS1BcHB4UHJvdmlzaW9uZWRQYWNrYWdlIC1PbmxpbmUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgICAgICAgICAgICAgV3JpdGUtTG9nICJSZW1vdmVkOiAkcGtnIiAiU3VjY2VzcyIKICAgICAgICAgICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJTa2lwOiAkcGtnYG4kXyIgIldhcm4iIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJHR3ZWFrLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgInNjcmlwdCIpIHsKICAgICAgICAgICAgICAgIHRyeSB7ICYgKFtzY3JpcHRibG9ja106OkNyZWF0ZSgkdHdlYWsuc2NyaXB0KSk7IFdyaXRlLUxvZyAiU2NyaXB0IGV4ZWN1dGVkLiIgIlN1Y2Nlc3MiIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlNjcmlwdCBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJHR3ZWFrLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgImluZm8iKSB7IFdyaXRlLUxvZyAkdHdlYWsuaW5mbyAiV2FybiIgfQogICAgICAgIH0KICAgICAgICBTZXQtU3RhdHVzICJSZWFkeSIKICAgICAgICBTaG93LUluZm8gIlR3ZWFrcyBDb21wbGV0ZSIgIiQoJHNlbGVjdGVkLkNvdW50KSB0d2VhayhzKSBhcHBsaWVkLmBuYG5VbmRvIGZyb20gVHdlYWtzIHRhYi4iCiAgICAgICAgV3JpdGUtTG9nICJBbGwgc2VsZWN0ZWQgdHdlYWtzIGNvbXBsZXRlZC4iICJIZWFkZXIiCiAgICB9KQp9CgppZiAoJGNvbnRyb2xzWyJCdG5VbmRvVHdlYWtzIl0pIHsgJGNvbnRyb2xzWyJCdG5VbmRvVHdlYWtzIl0uQWRkX0NsaWNrKHsgSW52b2tlLVVuZG9Ud2Vha3MgfSkgfQo='))
$script:tweakUndoLog = @{}
$script:lastRestorePoint = $null

function Save-OriginalValues {
    param($tweakKey, $tweak)
    if ($script:tweakUndoLog.ContainsKey($tweakKey)) { return }
    $undoEntry = @{ Key = $tweakKey; Registry = @(); Services = @(); Scripts = @() }
    if ($tweak.PSObject.Properties.Name -contains "registry") {
        foreach ($reg in $tweak.registry) {
            $currentValue = $null
            if ($reg.path -and (Test-Path $reg.path)) {
                try { $currentValue = (Get-ItemProperty $reg.path -Name $reg.name -ErrorAction SilentlyContinue).$($reg.name) } catch { Write-Log "Registry read failed for undo: $_" "Warn" }
            }
            $undoEntry.Registry += @{ Path = $reg.path; Name = $reg.name; OriginalValue = $currentValue; Type = $reg.type }
        }
    }
    if ($tweak.PSObject.Properties.Name -contains "services") {
        foreach ($svc in $tweak.services) {
            try {
                $svcObj = Get-Service $svc.name -ErrorAction SilentlyContinue
                if ($svcObj) {
                    $undoEntry.Services += @{ Name = $svc.name; OriginalStatus = $svcObj.Status; OriginalStartup = (Get-CimInstance Win32_Service -Filter "Name='$($svc.name)'" -ErrorAction SilentlyContinue).StartMode }
                }
                } catch { Write-Log "Service capture failed: $_" "Warn" }
        }
    }
    if ($tweak.PSObject.Properties.Name -contains "undoScript") { $undoEntry.Scripts += $tweak.undoScript }
    $script:tweakUndoLog[$tweakKey] = $undoEntry
}

function New-SystemRestorePoint {
    param([string]$Description = "HksUtil Tweaks")
    try {
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        $script:lastRestorePoint = Get-Date
        Write-Log "Restore point created: $Description" "Success"
    } catch { Write-Log "Restore point skipped (service not available): $_" "Warn" }
}

function Invoke-UndoTweaks {
    if ($script:tweakUndoLog.Count -eq 0) { Write-Log "No tweaks to undo." "Warn"; return }

    $sb = New-Object System.Windows.Controls.StackPanel; $sb.Orientation = "Vertical"
    $sb.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text = "Choose undo method:"; Margin = "0,0,0,10"; FontWeight = "Bold" })) | Out-Null
    $rbLog = New-Object System.Windows.Controls.RadioButton -Property @{ Content = "Undo via Log (registry + services)"; IsChecked = $true; Margin = "0,0,0,5" }
    $rbRestore = New-Object System.Windows.Controls.RadioButton -Property @{ Content = "System Restore (roll back to last restore point)"; Margin = "0,0,0,5" }
    if (-not (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) { $rbRestore.IsEnabled = $false; $rbRestore.Content += " (none available)" }
    $sb.Children.Add($rbLog) | Out-Null; $sb.Children.Add($rbRestore) | Out-Null

    $w = New-Object System.Windows.Window -Property @{ Title = "Undo Tweaks"; Content = $sb; Width = 420; Height = 180; WindowStartupLocation = "CenterOwner"; Owner = $window; ShowInTaskbar = $false }
    $btnPanel = New-Object System.Windows.Controls.StackPanel -Property @{ Orientation = "Horizontal"; HorizontalAlignment = "Right"; Margin = "0,15,0,0" }
    $okBtn = New-Object System.Windows.Controls.Button -Property @{ Content = "OK"; Width = 80; Height = 28; Margin = "0,0,10,0"; IsDefault = $true }
    $cancelBtn = New-Object System.Windows.Controls.Button -Property @{ Content = "Cancel"; Width = 80; Height = 28; IsCancel = $true }
    $btnPanel.Children.Add($okBtn) | Out-Null; $btnPanel.Children.Add($cancelBtn) | Out-Null
    $sb.Children.Add($btnPanel) | Out-Null
    $result = $false
    $okBtn.Add_Click({ $result = $true; $w.Close() })
    $cancelBtn.Add_Click({ $w.Close() })
    $w.ShowDialog() | Out-Null
    if (-not $result) { return }

    if ($rbRestore.IsChecked) {
        try {
            $rp = Get-ComputerRestorePoint | Sort-Object CreationTime -Descending | Select-Object -First 1
            if ($rp) { Write-Log "Starting system restore to $($rp.Description)..." "Header"; Show-Info "System Restore" "Your computer will restart to complete the system restore."; Restore-Computer -RestorePoint $rp.SequenceNumber -Confirm:$false }
        } catch { Write-Log "System restore failed: $_" "Error" }
        return
    }

    Write-Log "Undoing last tweaks via log..." "Header"
    $tweakNames = $script:tweakUndoLog.Keys | ForEach-Object { $_.Replace("WPFTweaks", "") -replace "([a-z])([A-Z])", '$1 $2' }
    $msg = "Undo the following tweaks?`n`n" + ($tweakNames -join "`n")
    if (-not (Show-Confirm "Undo via Log" $msg)) { return }
    foreach ($key in $script:tweakUndoLog.Keys) {
        $entry = $script:tweakUndoLog[$key]
        Write-Log "Undoing: $($entry.Key)" "Info"
        foreach ($svc in $entry.Services) {
            try {
                if ($svc.OriginalStartup -and $svc.OriginalStartup -ne "Disabled") { $startType = $svc.OriginalStartup; if ($startType -eq "Auto") { $startType = "Automatic" }; Set-Service $svc.Name -StartupType $startType -ErrorAction SilentlyContinue }
                if ($svc.OriginalStatus -and $svc.OriginalStatus -ne "Stopped") { Start-Service $svc.Name -ErrorAction SilentlyContinue }
                Write-Log "Service $($svc.Name) restored." "Success"
            } catch { Write-Log "Service undo failed: $_" "Error" }
        }
        foreach ($reg in $entry.Registry) {
            try {
                if (!(Test-Path $reg.Path)) { New-Item $reg.Path -Force | Out-Null }
                if ($null -ne $reg.OriginalValue) { Set-ItemProperty $reg.Path -Name $reg.Name -Value $reg.OriginalValue -Type $reg.Type -Force }
                else { Remove-ItemProperty $reg.Path -Name $reg.Name -ErrorAction SilentlyContinue }
                Write-Log "Registry $($reg.Name) restored." "Success"
            } catch { Write-Log "Registry undo failed: $_" "Error" }
        }
        foreach ($scriptBlock in $entry.Scripts) {
            try { & ([scriptblock]::Create($scriptBlock)); Write-Log "Undo script executed." "Success" } catch { Write-Log "Undo script failed: $_" "Error" }
        }
    }
    $script:tweakUndoLog = @{}
    Write-Log "All tweaks undone." "Header"
}

if ($controls["BtnRunTweaks"]) {
    $controls["BtnRunTweaks"].Add_Click({
        $selected = $tweakCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No tweaks selected." "Warn"; return }
        if (-not (Show-Confirm "Run Tweaks" "Apply $($selected.Count) tweak(s)?`n`nA system restore point will be created first.")) { return }
        Write-Log "Creating restore point..." "Info"
        New-SystemRestorePoint
        Write-Log "Running Selected Tweaks..." "Header"
        Set-Status "Applying $($selected.Count) tweak(s)..."
        foreach ($cb in $selected) {
            $tweakKey = $cb.Tag; $tweak = $null
            foreach ($groupKey in $tweaksConfig.PSObject.Properties.Name) {
                $group = $tweaksConfig.$groupKey
                if ($group.PSObject.Properties.Name -contains $tweakKey) { $tweak = $group.$tweakKey; break }
            }
            if (-not $tweak) { continue }
            Write-Log "Applying: $($tweak.content)" "Info"
            Save-OriginalValues -tweakKey $tweakKey -tweak $tweak
            if ($tweak.PSObject.Properties.Name -contains "services") {
                foreach ($svc in $tweak.services) {
                    try {
                        if ($svc.action -eq "stop_disable") { Stop-Service $svc.name -Force -ErrorAction SilentlyContinue; Set-Service $svc.name -StartupType Disabled -ErrorAction SilentlyContinue }
                        if ($svc.action -eq "set_manual") { Set-Service $svc.name -StartupType Manual -ErrorAction SilentlyContinue }
                        Write-Log "Service $($svc.name): $($svc.action)" "Success"
                    } catch { Write-Log "Service $($svc.name) failed: $_" "Error" }
                }
            }
            if ($tweak.PSObject.Properties.Name -contains "registry") {
                foreach ($reg in $tweak.registry) {
                    try { if (!(Test-Path $reg.path)) { New-Item $reg.path -Force | Out-Null }; Set-ItemProperty $reg.path -Name $reg.name -Value $reg.value -Type $reg.type -Force; Write-Log "Registry: $($reg.name) = $($reg.value)" "Success" } catch { Write-Log "Registry failed: $_" "Error" }
                }
            }
            if ($tweak.PSObject.Properties.Name -contains "appx_packages") {
                foreach ($pkg in $tweak.appx_packages) {
                    try {
                        Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
                        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pkg } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                        Write-Log "Removed: $pkg" "Success"
                    } catch { Write-Log "Skip: $pkg`n$_" "Warn" }
                }
            }
            if ($tweak.PSObject.Properties.Name -contains "script") {
                try { & ([scriptblock]::Create($tweak.script)); Write-Log "Script executed." "Success" } catch { Write-Log "Script failed: $_" "Error" }
            }
            if ($tweak.PSObject.Properties.Name -contains "info") { Write-Log $tweak.info "Warn" }
        }
        Set-Status "Ready"
        Show-Info "Tweaks Complete" "$($selected.Count) tweak(s) applied.`n`nUndo from Tweaks tab."
        Write-Log "All selected tweaks completed." "Header"
    })
}

if ($controls["BtnUndoTweaks"]) { $controls["BtnUndoTweaks"].Add_Click({ Invoke-UndoTweaks }) }

$script:__mod_search = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZnVuY3Rpb24gQXBwbHktRmlsdGVycyB7CiAgICBXcml0ZS1Mb2cgIkFwcGx5aW5nIHNlYXJjaCBmaWx0ZXJzLi4uIiAiSW5mbyIKICAgICRmaWx0ZXIgPSBpZiAoJGNvbnRyb2xzWyJTZWFyY2hCb3giXSkgeyAkY29udHJvbHNbIlNlYXJjaEJveCJdLlRleHQuVG9Mb3dlcigpIH0gZWxzZSB7ICIiIH0KICAgICRzaG93SW5zdGFsbGVkID0gJGNvbnRyb2xzWyJDaGtTaG93SW5zdGFsbGVkIl0gLWFuZCAkY29udHJvbHNbIkNoa1Nob3dJbnN0YWxsZWQiXS5Jc0NoZWNrZWQKICAgIGZvcmVhY2ggKCRjYiBpbiAkYXBwQ2hlY2tib3hlcykgewogICAgICAgICRpc1Zpc2libGUgPSAkdHJ1ZQogICAgICAgIGlmICgkc2hvd0luc3RhbGxlZCkgewogICAgICAgICAgICAkaWQgPSBpZiAoJGNiLlRhZyAtbmUgJG51bGwpIHsgJGNiLlRhZy5Ub1N0cmluZygpIH0gZWxzZSB7ICIiIH0KICAgICAgICAgICAgJGlzVmlzaWJsZSA9ICRpc1Zpc2libGUgLWFuZCAkc2NyaXB0Omluc3RhbGxlZEFwcElkcy5Db250YWluc0tleSgkaWQpCiAgICAgICAgfQogICAgICAgIGlmICgkZmlsdGVyKSB7CiAgICAgICAgICAgICR0ZXh0ID0gaWYgKCRjYi5UYWcgLW5lICRudWxsKSB7ICRjYi5UYWcuVG9TdHJpbmcoKS5Ub0xvd2VyKCkgfSBlbHNlIHsgIiIgfQogICAgICAgICAgICAkY29udGVudCA9IGlmICgkY2IuQ29udGVudCAtbmUgJG51bGwpIHsgJGNiLkNvbnRlbnQuVG9TdHJpbmcoKS5Ub0xvd2VyKCkgfSBlbHNlIHsgIiIgfQogICAgICAgICAgICAkaXNWaXNpYmxlID0gJGlzVmlzaWJsZSAtYW5kICgkdGV4dC5Db250YWlucygkZmlsdGVyKSAtb3IgJGNvbnRlbnQuQ29udGFpbnMoJGZpbHRlcikpCiAgICAgICAgfQogICAgICAgIHRyeSB7ICRjYi5WaXNpYmlsaXR5ID0gaWYgKCRpc1Zpc2libGUpIHsgIlZpc2libGUiIH0gZWxzZSB7ICJDb2xsYXBzZWQiIH0gfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmlsdGVyIHZpc2liaWxpdHkgZmFpbGVkOiAkXyIgIldhcm4iIH0KICAgIH0KICAgIGZvcmVhY2ggKCRwYW5lbE5hbWUgaW4gQCgiVHdlYWtzUGFuZWwxIiwiVHdlYWtzUGFuZWwyIiwiVHdlYWtzUGFuZWwzIikpIHsKICAgICAgICBpZiAoLW5vdCAkY29udHJvbHNbJHBhbmVsTmFtZV0pIHsgY29udGludWUgfQogICAgICAgIGZvcmVhY2ggKCRjYiBpbiAkY29udHJvbHNbJHBhbmVsTmFtZV0uQ2hpbGRyZW4pIHsKICAgICAgICAgICAgaWYgKCRjYiAtaXNub3QgW1N5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkNoZWNrQm94XSkgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRpc1Zpc2libGUgPSAkdHJ1ZQogICAgICAgICAgICBpZiAoJGZpbHRlcikgewogICAgICAgICAgICAgICAgJHRleHQgPSBpZiAoJGNiLlRhZyAtbmUgJG51bGwpIHsgJGNiLlRhZy5Ub1N0cmluZygpLlRvTG93ZXIoKSB9IGVsc2UgeyAiIiB9CiAgICAgICAgICAgICAgICAkY29udGVudCA9IGlmICgkY2IuQ29udGVudCAtbmUgJG51bGwpIHsgJGNiLkNvbnRlbnQuVG9TdHJpbmcoKS5Ub0xvd2VyKCkgfSBlbHNlIHsgIiIgfQogICAgICAgICAgICAgICAgJGlzVmlzaWJsZSA9ICRpc1Zpc2libGUgLWFuZCAoJHRleHQuQ29udGFpbnMoJGZpbHRlcikgLW9yICRjb250ZW50LkNvbnRhaW5zKCRmaWx0ZXIpKQogICAgICAgICAgICB9CiAgICAgICAgICAgIHRyeSB7ICRjYi5WaXNpYmlsaXR5ID0gaWYgKCRpc1Zpc2libGUpIHsgIlZpc2libGUiIH0gZWxzZSB7ICJDb2xsYXBzZWQiIH0gfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmlsdGVyIHZpc2liaWxpdHkgZmFpbGVkOiAkXyIgIldhcm4iIH0KICAgICAgICB9CiAgICB9CiAgICBpZiAoJGNvbnRyb2xzWyJTZWFyY2hIaW50Il0pIHsgJGNvbnRyb2xzWyJTZWFyY2hIaW50Il0uVmlzaWJpbGl0eSA9IGlmICgkZmlsdGVyKSB7ICJDb2xsYXBzZWQiIH0gZWxzZSB7ICJWaXNpYmxlIiB9IH0KICAgIFdyaXRlLUxvZyAiRmlsdGVycyBhcHBsaWVkLiIgIlN1Y2Nlc3MiCn0KCmlmICgkY29udHJvbHNbIlNlYXJjaEJveCJdKSB7CiAgICAkY29udHJvbHNbIlNlYXJjaEJveCJdLkFkZF9UZXh0Q2hhbmdlZCh7CiAgICAgICAgQXBwbHktRmlsdGVycwogICAgfSkKfQo='))
function Apply-Filters {
    Write-Log "Applying search filters..." "Info"
    $filter = if ($controls["SearchBox"]) { $controls["SearchBox"].Text.ToLower() } else { "" }
    $showInstalled = $controls["ChkShowInstalled"] -and $controls["ChkShowInstalled"].IsChecked
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
        try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { Write-Log "Filter visibility failed: $_" "Warn" }
    }
    foreach ($panelName in @("TweaksPanel1","TweaksPanel2","TweaksPanel3")) {
        if (-not $controls[$panelName]) { continue }
        foreach ($cb in $controls[$panelName].Children) {
            if ($cb -isnot [System.Windows.Controls.CheckBox]) { continue }
            $isVisible = $true
            if ($filter) {
                $text = if ($cb.Tag -ne $null) { $cb.Tag.ToString().ToLower() } else { "" }
                $content = if ($cb.Content -ne $null) { $cb.Content.ToString().ToLower() } else { "" }
                $isVisible = $isVisible -and ($text.Contains($filter) -or $content.Contains($filter))
            }
            try { $cb.Visibility = if ($isVisible) { "Visible" } else { "Collapsed" } } catch { Write-Log "Filter visibility failed: $_" "Warn" }
        }
    }
    if ($controls["SearchHint"]) { $controls["SearchHint"].Visibility = if ($filter) { "Collapsed" } else { "Visible" } }
    Write-Log "Filters applied." "Success"
}

if ($controls["SearchBox"]) {
    $controls["SearchBox"].Add_TextChanged({
        Apply-Filters
    })
}

$script:__mod_toolbar = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aWYgKCRjb250cm9sc1siQnRuVG9vbGJhckNsb3NlIl0pIHsKICAgICRjb250cm9sc1siQnRuVG9vbGJhckNsb3NlIl0uQWRkX0NsaWNrKHsgJHdpbmRvdy5DbG9zZSgpIH0pCn0KCmlmICgkY29udHJvbHNbIkJ0blRvb2xiYXJNaW5pbWl6ZSJdKSB7CiAgICAkY29udHJvbHNbIkJ0blRvb2xiYXJNaW5pbWl6ZSJdLkFkZF9DbGljayh7ICR3aW5kb3cuV2luZG93U3RhdGUgPSAiTWluaW1pemVkIiB9KQp9CgppZiAoJGNvbnRyb2xzWyJCdG5Ub29sYmFyTWF4aW1pemUiXSkgewogICAgJGNvbnRyb2xzWyJCdG5Ub29sYmFyTWF4aW1pemUiXS5BZGRfQ2xpY2soewogICAgICAgICR3aW5kb3cuV2luZG93U3RhdGUgPSBpZiAoJHdpbmRvdy5XaW5kb3dTdGF0ZSAtZXEgIk1heGltaXplZCIpIHsgIk5vcm1hbCIgfSBlbHNlIHsgIk1heGltaXplZCIgfQogICAgfSkKfQoKaWYgKCRjb250cm9sc1siQnRuVG9vbGJhclRoZW1lIl0pIHsKICAgICRjb250cm9sc1siQnRuVG9vbGJhclRoZW1lIl0uQWRkX0NsaWNrKHsKICAgICAgICBpZiAoJHNjcmlwdDpjdXJyZW50VGhlbWUgLWVxICJkYXJrIikgeyBBcHBseS1UaGVtZSAibGlnaHQiIH0gZWxzZSB7IEFwcGx5LVRoZW1lICJkYXJrIiB9CiAgICB9KQp9CgppZiAoJGNvbnRyb2xzWyJCdG5HZWFyRXhwb3J0Il0pIHsKICAgICRjb250cm9sc1siQnRuR2VhckV4cG9ydCJdLkFkZF9DbGljayh7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHNmZCA9IE5ldy1PYmplY3QgTWljcm9zb2Z0LldpbjMyLlNhdmVGaWxlRGlhbG9nCiAgICAgICAgICAgICRzZmQuRmlsdGVyID0gIkpTT04gQ29uZmlnICgqLmpzb24pfCouanNvbnxBbGwgRmlsZXMgKCouKil8Ki4qIgogICAgICAgICAgICAkc2ZkLlRpdGxlID0gIkV4cG9ydCBDb25maWciCiAgICAgICAgICAgICRzZmQuRmlsZU5hbWUgPSAiSGtzVXRpbC0kKFtEYXRlVGltZV06Ok5vdy5Ub1N0cmluZygneXl5eU1NZGQtSEhtbXNzJykpLmpzb24iCiAgICAgICAgICAgICRzZmQuSW5pdGlhbERpcmVjdG9yeSA9IFtFbnZpcm9ubWVudF06OkdldEZvbGRlclBhdGgoIkRlc2t0b3AiKQogICAgICAgICAgICAkcmVzdWx0ID0gJHNmZC5TaG93RGlhbG9nKCR3aW5kb3cpCiAgICAgICAgICAgIGlmICgkcmVzdWx0IC1uZSAkdHJ1ZSkgeyByZXR1cm4gfQogICAgICAgICAgICAkZGF0YSA9IEB7CiAgICAgICAgICAgICAgICBBcHBTZWxlY3Rpb25zID0gQCgkYXBwQ2hlY2tib3hlcyB8IFdoZXJlLU9iamVjdCB7ICRfLklzQ2hlY2tlZCAtZXEgJHRydWUgfSB8IEZvckVhY2gtT2JqZWN0IHsgJF8uVGFnIH0pCiAgICAgICAgICAgICAgICBUd2Vha1NlbGVjdGlvbnMgPSBAKCR0d2Vha0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0gfCBGb3JFYWNoLU9iamVjdCB7ICRfLlRhZyB9KQogICAgICAgICAgICAgICAgRmVhdHVyZVNlbGVjdGlvbnMgPSBAKCRmZWF0dXJlc0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0gfCBGb3JFYWNoLU9iamVjdCB7ICRfLlRhZyB9KQogICAgICAgICAgICB9CiAgICAgICAgICAgICRwcmVmU3RhdGUgPSBAe30KICAgICAgICAgICAgZm9yZWFjaCAoJHBrIGluICRwcmVmQ2hlY2tib3hlcy5LZXlzKSB7CiAgICAgICAgICAgICAgICBpZiAoJHByZWZDaGVja2JveGVzWyRwa10pIHsgJHByZWZTdGF0ZVskcGtdID0gKCRwcmVmQ2hlY2tib3hlc1skcGtdLklzQ2hlY2tlZCAtZXEgJHRydWUpIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAkZGF0YS5QcmVmZXJlbmNlU3RhdGVzID0gJHByZWZTdGF0ZQogICAgICAgICAgICAkanNvbiA9ICRkYXRhIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDUKICAgICAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRzZmQuRmlsZU5hbWUsICRqc29uLCBbU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nXTo6bmV3KCRmYWxzZSkpCiAgICAgICAgICAgIFdyaXRlLUxvZyAiRXhwb3J0ZWQgdG8gJCgkc2ZkLkZpbGVOYW1lKSIgIlN1Y2Nlc3MiCiAgICAgICAgICAgIFNob3ctSW5mbyAiRXhwb3J0IENvbXBsZXRlIiAiQ29uZmlnIGV4cG9ydGVkIHRvOmBuJCgkc2ZkLkZpbGVOYW1lKSIKICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJFeHBvcnQgZmFpbGVkOiAkXyIgIkVycm9yIiB9CiAgICAgICAgaWYgKCRjb250cm9sc1siQnRuVG9vbGJhclNldHRpbmdzIl0pIHsgJGNvbnRyb2xzWyJCdG5Ub29sYmFyU2V0dGluZ3MiXS5Jc0NoZWNrZWQgPSAkZmFsc2UgfQogICAgfSkKfQoKaWYgKCRjb250cm9sc1siQnRuR2VhckltcG9ydCJdKSB7CiAgICAkY29udHJvbHNbIkJ0bkdlYXJJbXBvcnQiXS5BZGRfQ2xpY2soewogICAgICAgICRvZmQgPSBOZXctT2JqZWN0IE1pY3Jvc29mdC5XaW4zMi5PcGVuRmlsZURpYWxvZwogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRvZmQuRmlsdGVyID0gIkpTT04gQ29uZmlnICgqLmpzb24pfCouanNvbnxBbGwgRmlsZXMgKCouKil8Ki4qIgogICAgICAgICAgICAkb2ZkLlRpdGxlID0gIkltcG9ydCBDb25maWciCiAgICAgICAgICAgICRvZmQuSW5pdGlhbERpcmVjdG9yeSA9IFtFbnZpcm9ubWVudF06OkdldEZvbGRlclBhdGgoIkRlc2t0b3AiKQogICAgICAgICAgICAkcmVzdWx0ID0gJG9mZC5TaG93RGlhbG9nKCR3aW5kb3cpCiAgICAgICAgICAgIGlmICgkcmVzdWx0IC1uZSAkdHJ1ZSkgeyByZXR1cm4gfQogICAgICAgICAgICAkanNvbiA9IFtTeXN0ZW0uSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRvZmQuRmlsZU5hbWUsIFtTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmddOjpuZXcoJGZhbHNlKSkKICAgICAgICAgICAgJGRhdGEgPSAkanNvbiB8IENvbnZlcnRGcm9tLUpzb24KCiAgICAgICAgICAgICMgTkVXIGZvcm1hdDogQXBwU2VsZWN0aW9ucyAoYXJyYXkgb2Ygd2luZ2V0IElEcykKICAgICAgICAgICAgaWYgKCRkYXRhLkFwcFNlbGVjdGlvbnMpIHsKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRhaWQgaW4gJGRhdGEuQXBwU2VsZWN0aW9ucykgewogICAgICAgICAgICAgICAgICAgICRjYiA9ICRhcHBDaGVja2JveGVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uVGFnIC1lcSAkYWlkIH0KICAgICAgICAgICAgICAgICAgICBpZiAoJGNiKSB7ICRjYi5Jc0NoZWNrZWQgPSAkdHJ1ZSB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgIyBPTEQgZm9ybWF0OiBDaGVja2VkQXBwcyAoYXJyYXkgb2Yge05hbWUsIENvbnRlbnR9KQogICAgICAgICAgICBpZiAoJGRhdGEuQ2hlY2tlZEFwcHMpIHsKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRhcHBFbnRyeSBpbiAkZGF0YS5DaGVja2VkQXBwcykgewogICAgICAgICAgICAgICAgICAgICRjYiA9ICRhcHBDaGVja2JveGVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uVGFnIC1lcSAkYXBwRW50cnkuTmFtZSB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRjYikgeyAkY2IuSXNDaGVja2VkID0gJHRydWUgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CgogICAgICAgICAgICAjIE5FVyBmb3JtYXQ6IFR3ZWFrU2VsZWN0aW9ucyAoYXJyYXkgb2Yga2V5cykKICAgICAgICAgICAgaWYgKCRkYXRhLlR3ZWFrU2VsZWN0aW9ucykgewogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHRrIGluICRkYXRhLlR3ZWFrU2VsZWN0aW9ucykgewogICAgICAgICAgICAgICAgICAgICRjYiA9ICR0d2Vha0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5UYWcgLWVxICR0ayB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRjYikgeyAkY2IuSXNDaGVja2VkID0gJHRydWUgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICMgT0xEIGZvcm1hdDogQ2hlY2tlZFR3ZWFrcyAoYXJyYXkgb2Yge05hbWUsIENvbnRlbnR9KQogICAgICAgICAgICBpZiAoJGRhdGEuQ2hlY2tlZFR3ZWFrcykgewogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHR3ZWFrRW50cnkgaW4gJGRhdGEuQ2hlY2tlZFR3ZWFrcykgewogICAgICAgICAgICAgICAgICAgICRjYiA9ICR0d2Vha0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5UYWcgLWVxICR0d2Vha0VudHJ5Lk5hbWUgfQogICAgICAgICAgICAgICAgICAgIGlmICgkY2IpIHsgJGNiLklzQ2hlY2tlZCA9ICR0cnVlIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQoKICAgICAgICAgICAgaWYgKCRkYXRhLkZlYXR1cmVTZWxlY3Rpb25zKSB7CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkZmsgaW4gJGRhdGEuRmVhdHVyZVNlbGVjdGlvbnMpIHsKICAgICAgICAgICAgICAgICAgICAkY2IgPSAkZmVhdHVyZXNDaGVja2JveGVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uVGFnIC1lcSAkZmsgfQogICAgICAgICAgICAgICAgICAgIGlmICgkY2IpIHsgJGNiLklzQ2hlY2tlZCA9ICR0cnVlIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQoKICAgICAgICAgICAgaWYgKCRkYXRhLlByZWZlcmVuY2VTdGF0ZXMpIHsKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwayBpbiAkZGF0YS5QcmVmZXJlbmNlU3RhdGVzLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICAgICAgICAgICAgIGlmICgkcHJlZkNoZWNrYm94ZXNbJHBrXSkgeyAkcHJlZkNoZWNrYm94ZXNbJHBrXS5Jc0NoZWNrZWQgPSAkZGF0YS5QcmVmZXJlbmNlU3RhdGVzLiRwayAtZXEgJHRydWUgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CgogICAgICAgICAgICBXcml0ZS1Mb2cgIkltcG9ydGVkIGZyb20gJCgkb2ZkLkZpbGVOYW1lKSIgIlN1Y2Nlc3MiCiAgICAgICAgICAgIFNob3ctSW5mbyAiSW1wb3J0IENvbXBsZXRlIiAiQ29uZmlndXJhdGlvbiBpbXBvcnRlZC4iCiAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiSW1wb3J0IGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgICAgIGlmICgkY29udHJvbHNbIkJ0blRvb2xiYXJTZXR0aW5ncyJdKSB7ICRjb250cm9sc1siQnRuVG9vbGJhclNldHRpbmdzIl0uSXNDaGVja2VkID0gJGZhbHNlIH0KICAgIH0pCn0KCmlmICgkY29udHJvbHNbIkJ0bkdlYXJBYm91dCJdKSB7CiAgICAkY29udHJvbHNbIkJ0bkdlYXJBYm91dCJdLkFkZF9DbGljayh7CiAgICAgICAgU2hvdy1JbmZvICJBYm91dCBIa3NVdGlsIHYyLjAiICJIa3NVdGlsIHYyLjAgLSBXaW5kb3dzIE9wdGltaXplcmBuYG5BIFdpbmRvd3MgdXRpbGl0eSBmb3IgYXBwbGljYXRpb24gbWFuYWdlbWVudCwgc3lzdGVtIHR3ZWFrcywgRE5TIGNvbmZpZ3VyYXRpb24sIGFuZCBtb3JlLmBuYG5CdWlsdCB3aXRoIFBvd2VyU2hlbGwgYW5kIFdQRi4iCiAgICAgICAgaWYgKCRjb250cm9sc1siQnRuVG9vbGJhclNldHRpbmdzIl0pIHsgJGNvbnRyb2xzWyJCdG5Ub29sYmFyU2V0dGluZ3MiXS5Jc0NoZWNrZWQgPSAkZmFsc2UgfQogICAgfSkKfQoKaWYgKCRjb250cm9sc1siQnRuR2VhckRvY3MiXSkgewogICAgJGNvbnRyb2xzWyJCdG5HZWFyRG9jcyJdLkFkZF9DbGljayh7CiAgICAgICAgU3RhcnQtUHJvY2VzcyAiaHR0cHM6Ly9naXRodWIuY29tL2hhcnRraXRzYWsvSGtzVXRpbCIKICAgICAgICBpZiAoJGNvbnRyb2xzWyJCdG5Ub29sYmFyU2V0dGluZ3MiXSkgeyAkY29udHJvbHNbIkJ0blRvb2xiYXJTZXR0aW5ncyJdLklzQ2hlY2tlZCA9ICRmYWxzZSB9CiAgICB9KQp9CgppZiAoJGNvbnRyb2xzWyJCdG5HZWFyU3BvbnNvcnMiXSkgewogICAgJGNvbnRyb2xzWyJCdG5HZWFyU3BvbnNvcnMiXS5BZGRfQ2xpY2soewogICAgICAgIFNob3ctSW5mbyAiU3BvbnNvcnMiICJIa3NVdGlsIGlzIGFuIG9wZW4tc291cmNlIHByb2plY3QuYG5gbklmIHlvdSBmaW5kIHRoaXMgdG9vbCB1c2VmdWwsIGNvbnNpZGVyIHN1cHBvcnRpbmcgdGhlIHByb2plY3QuIgogICAgICAgIGlmICgkY29udHJvbHNbIkJ0blRvb2xiYXJTZXR0aW5ncyJdKSB7ICRjb250cm9sc1siQnRuVG9vbGJhclNldHRpbmdzIl0uSXNDaGVja2VkID0gJGZhbHNlIH0KICAgIH0pCn0K'))
if ($controls["BtnToolbarClose"]) {
    $controls["BtnToolbarClose"].Add_Click({ $window.Close() })
}

if ($controls["BtnToolbarMinimize"]) {
    $controls["BtnToolbarMinimize"].Add_Click({ $window.WindowState = "Minimized" })
}

if ($controls["BtnToolbarMaximize"]) {
    $controls["BtnToolbarMaximize"].Add_Click({
        $window.WindowState = if ($window.WindowState -eq "Maximized") { "Normal" } else { "Maximized" }
    })
}

if ($controls["BtnToolbarTheme"]) {
    $controls["BtnToolbarTheme"].Add_Click({
        if ($script:currentTheme -eq "dark") { Apply-Theme "light" } else { Apply-Theme "dark" }
    })
}

if ($controls["BtnGearExport"]) {
    $controls["BtnGearExport"].Add_Click({
        try {
            $sfd = New-Object Microsoft.Win32.SaveFileDialog
            $sfd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $sfd.Title = "Export Config"
            $sfd.FileName = "HksUtil-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).json"
            $sfd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $sfd.ShowDialog($window)
            if ($result -ne $true) { return }
            $data = @{
                AppSelections = @($appCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
                TweakSelections = @($tweakCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
                FeatureSelections = @($featuresCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
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
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearImport"]) {
    $controls["BtnGearImport"].Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        try {
            $ofd.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
            $ofd.Title = "Import Config"
            $ofd.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $result = $ofd.ShowDialog($window)
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

            # NEW format: TweakSelections (array of keys)
            if ($data.TweakSelections) {
                foreach ($tk in $data.TweakSelections) {
                    $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tk }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }
            # OLD format: CheckedTweaks (array of {Name, Content})
            if ($data.CheckedTweaks) {
                foreach ($tweakEntry in $data.CheckedTweaks) {
                    $cb = $tweakCheckboxes | Where-Object { $_.Tag -eq $tweakEntry.Name }
                    if ($cb) { $cb.IsChecked = $true }
                }
            }

            if ($data.FeatureSelections) {
                foreach ($fk in $data.FeatureSelections) {
                    $cb = $featuresCheckboxes | Where-Object { $_.Tag -eq $fk }
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
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearAbout"]) {
    $controls["BtnGearAbout"].Add_Click({
        Show-Info "About HksUtil v2.0" "HksUtil v2.0 - Windows Optimizer`n`nA Windows utility for application management, system tweaks, DNS configuration, and more.`n`nBuilt with PowerShell and WPF."
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearDocs"]) {
    $controls["BtnGearDocs"].Add_Click({
        Start-Process "https://github.com/hartkitsak/HksUtil"
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($controls["BtnGearSponsors"]) {
    $controls["BtnGearSponsors"].Add_Click({
        Show-Info "Sponsors" "HksUtil is an open-source project.`n`nIf you find this tool useful, consider supporting the project."
        if ($controls["BtnToolbarSettings"]) { $controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

$script:__mod_dns = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpkbnNOYW1lcyA9IEAoKQokc2NyaXB0OmRuc1JhZGlvQnV0dG9ucyA9IEB7fQoKaWYgKCRjb250cm9sc1siRG5zUmFkaW9QYW5lbCJdIC1hbmQgJGRuc0NvbmZpZykgewogICAgJHNjcmlwdDpkbnNOYW1lcyA9IEAoJGRuc0NvbmZpZy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpCiAgICAkc2NyaXB0OmRuc1JhZGlvQnV0dG9ucyA9IEB7fQogICAgJGlzRmlyc3QgPSAkdHJ1ZQogICAgZm9yZWFjaCAoJGRuc05hbWUgaW4gJHNjcmlwdDpkbnNOYW1lcykgewogICAgICAgICRkbnMgPSAkZG5zQ29uZmlnLiRkbnNOYW1lCiAgICAgICAgaWYgKC1ub3QgJGRucykgeyBjb250aW51ZSB9CiAgICAgICAgJHJiID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5SYWRpb0J1dHRvbgogICAgICAgICRyYi5UYWcgPSAkZG5zTmFtZTsgJHJiLlN0eWxlID0gR2V0LVdwZlJlc291cmNlICJEbnNDYXJkU3R5bGUiOyAkcmIuR3JvdXBOYW1lID0gIkRuc1Byb3ZpZGVyIgogICAgICAgICRzcCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuU3RhY2tQYW5lbDsgJHNwLk9yaWVudGF0aW9uID0gIkhvcml6b250YWwiOyAkc3AuVmVydGljYWxBbGlnbm1lbnQgPSAiQ2VudGVyIgogICAgICAgICRuYW1lVGIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9jazsgJG5hbWVUYi5UZXh0ID0gIiRkbnNOYW1lIC0gJCgkZG5zLmRlc2NyaXB0aW9uKSI7ICRuYW1lVGIuRm9udFNpemUgPSAxMjsgJG5hbWVUYi5Gb250V2VpZ2h0ID0gIlNlbWlCb2xkIjsgJG5hbWVUYi5WZXJ0aWNhbEFsaWdubWVudCA9ICJDZW50ZXIiOyAkbmFtZVRiLlNldFJlc291cmNlUmVmZXJlbmNlKFtTeXN0ZW0uV2luZG93cy5Db250cm9scy5UZXh0QmxvY2tdOjpGb3JlZ3JvdW5kUHJvcGVydHksICJwYWdlVGl0bGVDb2xvciIpCiAgICAgICAgJHNwLkNoaWxkcmVuLkFkZCgkbmFtZVRiKSB8IE91dC1OdWxsCiAgICAgICAgJGlwVGIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9jazsgJGlwRGlzcGxheSA9IGlmICgkZG5zLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgImlwdjQiIC1hbmQgJGRucy5pcHY0LkNvdW50IC1ndCAwKSB7ICRkbnMuaXB2NCAtam9pbiAiLCAiIH0gZWxzZSB7ICJBdXRvIChESENQKSIgfTsgJGlwVGIuVGV4dCA9ICIgICRpcERpc3BsYXkiOyAkaXBUYi5Gb250U2l6ZSA9IDEwOyAkaXBUYi5Gb250RmFtaWx5ID0gIkNvbnNvbGFzIjsgJGlwVGIuVmVydGljYWxBbGlnbm1lbnQgPSAiQ2VudGVyIjsgJGlwVGIuU2V0UmVzb3VyY2VSZWZlcmVuY2UoW1N5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9ja106OkZvcmVncm91bmRQcm9wZXJ0eSwgInRleHRNdXRlZCIpCiAgICAgICAgJHNwLkNoaWxkcmVuLkFkZCgkaXBUYikgfCBPdXQtTnVsbAogICAgICAgICRyYi5Db250ZW50ID0gJHNwCiAgICAgICAgJHJiLkFkZF9DaGVja2VkKHsgV3JpdGUtTG9nICJETlMgc2VsZWN0ZWQ6ICQoJHRoaXMuVGFnKSIgIkluZm8iIH0pCiAgICAgICAgJG51bGwgPSAkY29udHJvbHNbIkRuc1JhZGlvUGFuZWwiXS5DaGlsZHJlbi5BZGQoJHJiKQogICAgICAgICRzY3JpcHQ6ZG5zUmFkaW9CdXR0b25zWyRkbnNOYW1lXSA9ICRyYgogICAgICAgIGlmICgkaXNGaXJzdCkgeyAkcmIuSXNDaGVja2VkID0gJHRydWU7ICRpc0ZpcnN0ID0gJGZhbHNlIH0KICAgIH0KICAgIFdyaXRlLUxvZyAiQnVpbHQgJCgkc2NyaXB0OmRuc05hbWVzLkNvdW50KSBETlMgcmFkaW8gYnV0dG9ucy4iICJTdWNjZXNzIgp9CgppZiAoJGNvbnRyb2xzWyJCdG5BcHBseURucyJdKSB7CiAgICAkY29udHJvbHNbIkJ0bkFwcGx5RG5zIl0uQWRkX0NsaWNrKHsKICAgICAgICAkc2VsZWN0ZWRSYiA9ICRzY3JpcHQ6ZG5zUmFkaW9CdXR0b25zLlZhbHVlcyB8IFdoZXJlLU9iamVjdCB7ICRfLklzQ2hlY2tlZCAtZXEgJHRydWUgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICBpZiAoLW5vdCAkc2VsZWN0ZWRSYikgeyBXcml0ZS1Mb2cgIk5vIEROUyBwcm92aWRlciBzZWxlY3RlZC4iICJXYXJuIjsgcmV0dXJuIH0KICAgICAgICAkZG5zTmFtZSA9ICRzZWxlY3RlZFJiLlRhZwogICAgICAgICRkbnMgPSAkZG5zQ29uZmlnLiRkbnNOYW1lCiAgICAgICAgJGlwdjQgPSBpZiAoJGRucy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJpcHY0IikgeyAkZG5zLmlwdjQgfSBlbHNlIHsgQCgpIH0KICAgICAgICBpZiAoJGRuc05hbWUgLWVxICJEZWZhdWx0X0RIQ1AiKSB7CiAgICAgICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIlJlc2V0IEROUyIgIlJlc2V0IEROUyB0byBkZWZhdWx0IERIQ1Agb24gYWxsIGFkYXB0ZXJzPyIpKSB7IHJldHVybiB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUmVzZXR0aW5nIEROUyB0byBESENQLi4uIiAiSW5mbyIKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRhZGFwdGVycyA9IEdldC1OZXRBZGFwdGVyIC1QaHlzaWNhbCB8IFdoZXJlLU9iamVjdCB7ICRfLlN0YXR1cyAtZXEgJ1VwJyB9CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkYWRhcHRlcnMpIHsgV3JpdGUtTG9nICJObyBhY3RpdmUgbmV0d29yayBhZGFwdGVyIGZvdW5kLiIgIkVycm9yIjsgcmV0dXJuIH0KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRhZGFwdGVyIGluICRhZGFwdGVycykgeyBTZXQtRG5zQ2xpZW50U2VydmVyQWRkcmVzcyAtSW50ZXJmYWNlSW5kZXggJGFkYXB0ZXIuaWZJbmRleCAtUmVzZXRTZXJ2ZXJBZGRyZXNzZXMgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJETlMgcmVzZXQgdG8gREhDUCBvbiAkKCRhZGFwdGVycy5Db3VudCkgYWRhcHRlcihzKS4iICJTdWNjZXNzIgogICAgICAgICAgICAgICAgU2hvdy1JbmZvICJETlMgUmVzZXQiICJETlMgaGFzIGJlZW4gcmVzZXQgdG8gREhDUC4iCiAgICAgICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkZhaWxlZCB0byByZXNldCBETlM6ICRfIiAiRXJyb3IiIH0KICAgICAgICAgICAgcmV0dXJuCiAgICAgICAgfQogICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIkFwcGx5IEROUyIgIlNldCBETlMgdG8gJGRuc05hbWU/YG5gbklQdjQ6ICQoJGlwdjQgLWpvaW4gJywgJykiKSApIHsgcmV0dXJuIH0KICAgICAgICBXcml0ZS1Mb2cgIlNldHRpbmcgRE5TIHRvICRkbnNOYW1lLi4uIiAiSW5mbyIKICAgICAgICB0cnkgewogICAgICAgICAgICAkYWRhcHRlcnMgPSBHZXQtTmV0QWRhcHRlciAtUGh5c2ljYWwgfCBXaGVyZS1PYmplY3QgeyAkXy5TdGF0dXMgLWVxICdVcCcgfQogICAgICAgICAgICBpZiAoLW5vdCAkYWRhcHRlcnMpIHsgV3JpdGUtTG9nICJObyBhY3RpdmUgbmV0d29yayBhZGFwdGVyIGZvdW5kLiIgIkVycm9yIjsgcmV0dXJuIH0KICAgICAgICAgICAgJGlwdjYgPSBpZiAoJGRucy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJpcHY2IikgeyAkZG5zLmlwdjYgfSBlbHNlIHsgQCgpIH0KICAgICAgICAgICAgZm9yZWFjaCAoJGFkYXB0ZXIgaW4gJGFkYXB0ZXJzKSB7CiAgICAgICAgICAgICAgICBTZXQtRG5zQ2xpZW50U2VydmVyQWRkcmVzcyAtSW50ZXJmYWNlSW5kZXggJGFkYXB0ZXIuaWZJbmRleCAtU2VydmVyQWRkcmVzc2VzICgkaXB2NCArICRpcHY2KQogICAgICAgICAgICB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiRE5TIHNldCB0byAkZG5zTmFtZSBvbiAkKCRhZGFwdGVycy5Db3VudCkgYWRhcHRlcihzKS4iICJTdWNjZXNzIgogICAgICAgICAgICBTaG93LUluZm8gIkROUyBBcHBsaWVkIiAiRE5TIGhhcyBiZWVuIHNldCB0byAkZG5zTmFtZS5gbmBuSVB2NDogJCgkaXB2NCAtam9pbiAnLCAnKSIKICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgV3JpdGUtTG9nICJGYWlsZWQgdG8gc2V0IEROUzogJF8iICJFcnJvciIKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRhZGFwdGVycyA9IEdldC1OZXRBZGFwdGVyIC1QaHlzaWNhbCB8IFdoZXJlLU9iamVjdCB7ICRfLlN0YXR1cyAtZXEgJ1VwJyB9CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkYWRhcHRlcnMpIHsgV3JpdGUtTG9nICJObyBhY3RpdmUgYWRhcHRlciBmb3IgbmV0c2guIiAiRXJyb3IiOyByZXR1cm4gfQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGFkYXB0ZXIgaW4gJGFkYXB0ZXJzKSB7CiAgICAgICAgICAgICAgICAgICAgJGlmTmFtZSA9ICRhZGFwdGVyLk5hbWUKICAgICAgICAgICAgICAgICAgICBpZiAoJGlwdjQuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICAgICAgICAgbmV0c2ggaW50ZXJmYWNlIGlwIHNldCBkbnMgIiRpZk5hbWUiIHN0YXRpYyAkKCRpcHY0WzBdKQogICAgICAgICAgICAgICAgICAgICAgICBmb3IgKCRpID0gMTsgJGkgLWx0ICRpcHY0LkNvdW50OyAkaSsrKSB7IG5ldHNoIGludGVyZmFjZSBpcCBhZGQgZG5zICIkaWZOYW1lIiAkKCRpcHY0WyRpXSkgaW5kZXg9JCgkaSsxKSB9CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJETlMgc2V0IHZpYSBuZXRzaCBmYWxsYmFjay4iICJTdWNjZXNzIgogICAgICAgICAgICAgICAgU2hvdy1JbmZvICJETlMgQXBwbGllZCIgIkROUyBzZXQgdmlhIG5ldHNoLmBuJGRuc05hbWUgKCQoJGlwdjQgLWpvaW4gJywgJykpIgogICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJuZXRzaCBmYWxsYmFjayBhbHNvIGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgICAgIH0KICAgIH0pCn0K'))
$script:dnsNames = @()
$script:dnsRadioButtons = @{}

if ($controls["DnsRadioPanel"] -and $dnsConfig) {
    $script:dnsNames = @($dnsConfig.PSObject.Properties.Name)
    $script:dnsRadioButtons = @{}
    $isFirst = $true
    foreach ($dnsName in $script:dnsNames) {
        $dns = $dnsConfig.$dnsName
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
        $null = $controls["DnsRadioPanel"].Children.Add($rb)
        $script:dnsRadioButtons[$dnsName] = $rb
        if ($isFirst) { $rb.IsChecked = $true; $isFirst = $false }
    }
    Write-Log "Built $($script:dnsNames.Count) DNS radio buttons." "Success"
}

if ($controls["BtnApplyDns"]) {
    $controls["BtnApplyDns"].Add_Click({
        $selectedRb = $script:dnsRadioButtons.Values | Where-Object { $_.IsChecked -eq $true } | Select-Object -First 1
        if (-not $selectedRb) { Write-Log "No DNS provider selected." "Warn"; return }
        $dnsName = $selectedRb.Tag
        $dns = $dnsConfig.$dnsName
        $ipv4 = if ($dns.PSObject.Properties.Name -contains "ipv4") { $dns.ipv4 } else { @() }
        if ($dnsName -eq "Default_DHCP") {
            if (-not (Show-Confirm "Reset DNS" "Reset DNS to default DHCP on all adapters?")) { return }
            Write-Log "Resetting DNS to DHCP..." "Info"
            try {
                $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
                if (-not $adapters) { Write-Log "No active network adapter found." "Error"; return }
                foreach ($adapter in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses }
                Write-Log "DNS reset to DHCP on $($adapters.Count) adapter(s)." "Success"
                Show-Info "DNS Reset" "DNS has been reset to DHCP."
            } catch { Write-Log "Failed to reset DNS: $_" "Error" }
            return
        }
        if (-not (Show-Confirm "Apply DNS" "Set DNS to $dnsName?`n`nIPv4: $($ipv4 -join ', ')") ) { return }
        Write-Log "Setting DNS to $dnsName..." "Info"
        try {
            $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
            if (-not $adapters) { Write-Log "No active network adapter found." "Error"; return }
            $ipv6 = if ($dns.PSObject.Properties.Name -contains "ipv6") { $dns.ipv6 } else { @() }
            foreach ($adapter in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ($ipv4 + $ipv6)
            }
            Write-Log "DNS set to $dnsName on $($adapters.Count) adapter(s)." "Success"
            Show-Info "DNS Applied" "DNS has been set to $dnsName.`n`nIPv4: $($ipv4 -join ', ')"
        } catch {
            Write-Log "Failed to set DNS: $_" "Error"
            try {
                $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
                if (-not $adapters) { Write-Log "No active adapter for netsh." "Error"; return }
                foreach ($adapter in $adapters) {
                    $ifName = $adapter.Name
                    if ($ipv4.Count -gt 0) {
                        netsh interface ip set dns "$ifName" static $($ipv4[0])
                        for ($i = 1; $i -lt $ipv4.Count; $i++) { netsh interface ip add dns "$ifName" $($ipv4[$i]) index=$($i+1) }
                    }
                }
                Write-Log "DNS set via netsh fallback." "Success"
                Show-Info "DNS Applied" "DNS set via netsh.`n$dnsName ($($ipv4 -join ', '))"
            } catch { Write-Log "netsh fallback also failed: $_" "Error" }
        }
    })
}

$script:__mod_terminal = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aWYgKCRjb250cm9sc1siQnRuVGVybWluYWxEb3RmaWxlcyJdKSB7CiAgICAkY29udHJvbHNbIkJ0blRlcm1pbmFsRG90ZmlsZXMiXS5BZGRfQ2xpY2soewogICAgICAgIFdyaXRlLUxvZyAiSW5zdGFsbGluZyBOb3ZhIHByb2ZpbGUuLi4iICJJbmZvIgogICAgICAgIHRyeSB7CiAgICAgICAgICAgICR0bXAgPSAiJGVudjpURU1QXG5vdmEtaW5zdGFsbC5wczEiCiAgICAgICAgICAgIEludm9rZS1XZWJSZXF1ZXN0IC1VcmkgImh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9oYXJ0a2l0c2FrL25vdmEvbWFzdGVyL2luc3RhbGwucHMxIiAtT3V0RmlsZSAkdG1wIC1Vc2VCYXNpY1BhcnNpbmcKICAgICAgICAgICAgJiAkdG1wCiAgICAgICAgICAgIFJlbW92ZS1JdGVtICR0bXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIFdyaXRlLUxvZyAiTm92YSBpbnN0YWxsIGNvbXBsZXRlLiIgIlN1Y2Nlc3MiCiAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiTm92YSBpbnN0YWxsIGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgfSkKfQoKaWYgKCRjb250cm9sc1siQnRuVW5pbnN0YWxsVGVybWluYWwiXSkgewogICAgJGNvbnRyb2xzWyJCdG5Vbmluc3RhbGxUZXJtaW5hbCJdLkFkZF9DbGljayh7CiAgICAgICAgV3JpdGUtTG9nICJVbmluc3RhbGxpbmcgTm92YSBwcm9maWxlLi4uIiAiSW5mbyIKICAgICAgICB0cnkgewogICAgICAgICAgICAkdG1wID0gIiRlbnY6VEVNUFxub3ZhLXVuaW5zdGFsbC5wczEiCiAgICAgICAgICAgIEludm9rZS1XZWJSZXF1ZXN0IC1VcmkgImh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9oYXJ0a2l0c2FrL25vdmEvbWFzdGVyL3VuaW5zdGFsbC5wczEiIC1PdXRGaWxlICR0bXAgLVVzZUJhc2ljUGFyc2luZwogICAgICAgICAgICAmICR0bXAKICAgICAgICAgICAgUmVtb3ZlLUl0ZW0gJHRtcCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgV3JpdGUtTG9nICJOb3ZhIHVuaW5zdGFsbCBjb21wbGV0ZS4iICJTdWNjZXNzIgogICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIk5vdmEgdW5pbnN0YWxsIGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgfSkKfQo='))
if ($controls["BtnTerminalDotfiles"]) {
    $controls["BtnTerminalDotfiles"].Add_Click({
        Write-Log "Installing Nova profile..." "Info"
        try {
            $tmp = "$env:TEMP\nova-install.ps1"
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hartkitsak/nova/master/install.ps1" -OutFile $tmp -UseBasicParsing
            & $tmp
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Log "Nova install complete." "Success"
        } catch { Write-Log "Nova install failed: $_" "Error" }
    })
}

if ($controls["BtnUninstallTerminal"]) {
    $controls["BtnUninstallTerminal"].Add_Click({
        Write-Log "Uninstalling Nova profile..." "Info"
        try {
            $tmp = "$env:TEMP\nova-uninstall.ps1"
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hartkitsak/nova/master/uninstall.ps1" -OutFile $tmp -UseBasicParsing
            & $tmp
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Log "Nova uninstall complete." "Success"
        } catch { Write-Log "Nova uninstall failed: $_" "Error" }
    })
}

$script:__mod_utility = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpkZXNrdG9wU2hvcnRjdXRQYXRoID0gSm9pbi1QYXRoIChbRW52aXJvbm1lbnRdOjpHZXRGb2xkZXJQYXRoKCJEZXNrdG9wIikpICJIa3NVdGlsLmxuayIKCmlmICgkY29udHJvbHNbIkJ0bkNyZWF0ZVNob3J0Y3V0Il0pIHsKICAgICRjb250cm9sc1siQnRuQ3JlYXRlU2hvcnRjdXQiXS5BZGRfQ2xpY2soewogICAgICAgICRsbmtQYXRoID0gJHNjcmlwdDpkZXNrdG9wU2hvcnRjdXRQYXRoCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkbG5rUGF0aCkgeyBpZiAoLW5vdCAoU2hvdy1Db25maXJtICJPdmVyd3JpdGU/IiAiU2hvcnRjdXQgZXhpc3RzLiBPdmVyd3JpdGU/IikpIHsgcmV0dXJuIH0gfQogICAgICAgIHRyeSB7CiAgICAgICAgICAgICR3c2hlbGwgPSBOZXctT2JqZWN0IC1Db21PYmplY3QgV1NjcmlwdC5TaGVsbAogICAgICAgICAgICAkc2hvcnRjdXQgPSAkd3NoZWxsLkNyZWF0ZVNob3J0Y3V0KCRsbmtQYXRoKQogICAgICAgICAgICAkcHdzaFBhdGggPSAoR2V0LUNvbW1hbmQgcG93ZXJzaGVsbC5leGUpLlNvdXJjZQogICAgICAgICAgICAkc2hvcnRjdXQuVGFyZ2V0UGF0aCA9ICRwd3NoUGF0aAogICAgICAgICAgICAkc2hvcnRjdXQuQXJndW1lbnRzID0gIi1FeGVjdXRpb25Qb2xpY3kgUmVtb3RlU2lnbmVkIC1Ob1Byb2ZpbGUgLUZpbGUgYCIkKCRzY3JpcHQ6YXBwUm9vdClcYXBwLnBzMWAiIgogICAgICAgICAgICAkc2hvcnRjdXQuRGVzY3JpcHRpb24gPSAiSGtzVXRpbCB2Mi4wIC0gV2luZG93cyBPcHRpbWl6ZXIiCiAgICAgICAgICAgICRzaG9ydGN1dC5JY29uTG9jYXRpb24gPSAiJChbRW52aXJvbm1lbnRdOjpTeXN0ZW1EaXJlY3RvcnkpXHNoZWxsMzIuZGxsLCAxIgogICAgICAgICAgICAkc2hvcnRjdXQuU2F2ZSgpCiAgICAgICAgICAgIFdyaXRlLUxvZyAiRGVza3RvcCBzaG9ydGN1dCBjcmVhdGVkLiIgIlN1Y2Nlc3MiCiAgICAgICAgICAgIFNob3ctSW5mbyAiU2hvcnRjdXQgQ3JlYXRlZCIgIkRlc2t0b3Agc2hvcnRjdXQgY3JlYXRlZC5gbiRsbmtQYXRoIgogICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlNob3J0Y3V0IGNyZWF0aW9uIGZhaWxlZDogJF8iICJFcnJvciI7IFNob3ctSW5mbyAiU2hvcnRjdXQgRmFpbGVkIiAiRXJyb3I6ICRfIiB9CiAgICAgICAgZmluYWxseSB7IGlmICgkd3NoZWxsKSB7IFtTeXN0ZW0uUnVudGltZS5JbnRlcm9wc2VydmljZXMuTWFyc2hhbF06OlJlbGVhc2VDb21PYmplY3QoJHdzaGVsbCkgfCBPdXQtTnVsbCB9IH0KICAgIH0pCn0K'))
$script:desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"

if ($controls["BtnCreateShortcut"]) {
    $controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = $script:desktopShortcutPath
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $pwshPath = (Get-Command powershell.exe).Source
            $shortcut.TargetPath = $pwshPath
            $shortcut.Arguments = "-ExecutionPolicy RemoteSigned -NoProfile -File `"$($script:appRoot)\app.ps1`""
            $shortcut.Description = "HksUtil v2.0 - Windows Optimizer"
            $shortcut.IconLocation = "$([Environment]::SystemDirectory)\shell32.dll, 1"
            $shortcut.Save()
            Write-Log "Desktop shortcut created." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}

$script:__mod_build = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JGFwcENoZWNrYm94ZXMgPSBAKCkKJHR3ZWFrQ2hlY2tib3hlcyA9IEAoKQokZmVhdHVyZXNDaGVja2JveGVzID0gQCgpCiRwcmVmQ2hlY2tib3hlcyA9IEB7fQokYXBwUGFuZWxzID0gQCgpCiRzY3JpcHQ6Y2F0ZWdvcnlJdGVtcyA9IEB7fQokc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkID0gQHt9CgojIC0tLSBCdWlsZCBBcHBzIFVJIC0tLQokYXBwUGFuZWxJbmRleCA9IDAKaWYgKCgkY29udHJvbHNbIkFwcFBhbmVsMSJdIC1hbmQgJGNvbnRyb2xzWyJBcHBQYW5lbDIiXSAtYW5kICRjb250cm9sc1siQXBwUGFuZWwzIl0pIC1hbmQgJGFwcHNDb25maWcpIHsKICAgICRhcHBQYW5lbHMgPSBAKCRjb250cm9sc1siQXBwUGFuZWwxIl0sICRjb250cm9sc1siQXBwUGFuZWwyIl0sICRjb250cm9sc1siQXBwUGFuZWwzIl0pCiAgICBmb3JlYWNoICgkY2F0ZWdvcnkgaW4gJGFwcHNDb25maWcuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgJGNhdENvdW50ID0gKCRhcHBzQ29uZmlnLiRjYXRlZ29yeS5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpLkNvdW50CiAgICAgICAgJGhlYWRlciA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrCiAgICAgICAgJGhlYWRlci5UZXh0ID0gIi0gJCgkY2F0ZWdvcnkuVG9VcHBlcigpKSAoJGNhdENvdW50KSI7ICRoZWFkZXIuU3R5bGUgPSBHZXQtV3BmUmVzb3VyY2UgIkNhdGVnb3J5SGVhZGVyIjsgJGhlYWRlci5DdXJzb3IgPSAiSGFuZCIKICAgICAgICAkaGVhZGVyLlRhZyA9ICRjYXRlZ29yeQogICAgICAgICRhcHBQYW5lbHNbJGFwcFBhbmVsSW5kZXhdLkNoaWxkcmVuLkFkZCgkaGVhZGVyKSB8IE91dC1OdWxsCiAgICAgICAgJHNjcmlwdDpjYXRlZ29yeUl0ZW1zWyRjYXRlZ29yeV0gPSBAKCkKICAgICAgICAkaGVhZGVyLkFkZF9Nb3VzZUxlZnRCdXR0b25Eb3duKHsKICAgICAgICAgICAgJGNhdCA9ICR0aGlzLlRhZwogICAgICAgICAgICAkY29sbGFwc2VkID0gJHNjcmlwdDpjYXRlZ29yeUNvbGxhcHNlZFskY2F0XQogICAgICAgICAgICAkc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkWyRjYXRdID0gLW5vdCAkY29sbGFwc2VkCiAgICAgICAgICAgIGZvcmVhY2ggKCRpdGVtIGluICRzY3JpcHQ6Y2F0ZWdvcnlJdGVtc1skY2F0XSkgewogICAgICAgICAgICAgICAgJGl0ZW0uVmlzaWJpbGl0eSA9IGlmICgkc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkWyRjYXRdKSB7ICJDb2xsYXBzZWQiIH0gZWxzZSB7ICJWaXNpYmxlIiB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJHRoaXMuVGV4dCA9IGlmICgkc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkWyRjYXRdKSB7ICIrICQoJGNhdC5Ub1VwcGVyKCkpICgkKCRzY3JpcHQ6Y2F0ZWdvcnlJdGVtc1skY2F0XS5Db3VudCkpIiB9IGVsc2UgeyAiLSAkKCRjYXQuVG9VcHBlcigpKSAoJCgkc2NyaXB0OmNhdGVnb3J5SXRlbXNbJGNhdF0uQ291bnQpKSIgfQogICAgICAgIH0pCiAgICAgICAgZm9yZWFjaCAoJGFwcEtleSBpbiAkYXBwc0NvbmZpZy4kY2F0ZWdvcnkuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgICAgICRhcHAgPSAkYXBwc0NvbmZpZy4kY2F0ZWdvcnkuJGFwcEtleQogICAgICAgICAgICAkY2IgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkNoZWNrQm94CiAgICAgICAgICAgICRjYi5Db250ZW50ID0gJGFwcC5jb250ZW50OyAkY2IuVGFnID0gJGFwcC53aW5nZXQ7ICRjYi5TdHlsZSA9IEdldC1XcGZSZXNvdXJjZSAiVHdlYWtDaGVja0JveCIKICAgICAgICAgICAgaWYgKCRhcHAuZGVzY3JpcHRpb24pIHsgJGNiLlRvb2xUaXAgPSAiJCgkYXBwLmNvbnRlbnQpYG5gbiQoJGFwcC5kZXNjcmlwdGlvbilgbmBuSUQ6ICQoJGFwcC53aW5nZXQpIiB9CiAgICAgICAgICAgICRjYi5BZGRfQ2hlY2tlZCh7IFVwZGF0ZS1TZWxlY3RlZENvdW50IH0pCiAgICAgICAgICAgICRjYi5BZGRfVW5jaGVja2VkKHsgVXBkYXRlLVNlbGVjdGVkQ291bnQgfSkKICAgICAgICAgICAgJGNtID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5Db250ZXh0TWVudQogICAgICAgICAgICAkbWlJbnN0YWxsID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5NZW51SXRlbTsgJG1pSW5zdGFsbC5IZWFkZXIgPSAiSW5zdGFsbCI7ICRtaUluc3RhbGwuVGFnID0gJGFwcC53aW5nZXQKICAgICAgICAgICAgJG1pSW5zdGFsbC5BZGRfQ2xpY2soewogICAgICAgICAgICAgICAgJGlkID0gJHRoaXMuVGFnOyAkcGtnID0gJHNjcmlwdDpwa2dNYW5hZ2VyOyBXcml0ZS1Mb2cgIkNvbnRleHQ6IEluc3RhbGwgJGlkIHZpYSAkcGtnIiAiSW5mbyIKICAgICAgICAgICAgICAgIGlmICgtbm90IChFbnN1cmUtUGFja2FnZU1hbmFnZXIgJHBrZykpIHsgU2hvdy1JbmZvICJFcnJvciIgIkZhaWxlZCB0byBlbnN1cmUgJHBrZy4iOyByZXR1cm4gfQogICAgICAgICAgICAgICAgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiSW5zdGFsbCIgIkluc3RhbGwgJGlkIHZpYSAkcGtnPyIpKSB7IHJldHVybiB9CiAgICAgICAgICAgICAgICBTaG93LVByb2dyZXNzIC1UZXh0ICJJbnN0YWxsaW5nOiAkaWQiIC1WYWx1ZSAwLjUKICAgICAgICAgICAgICAgIHRyeSB7IGlmICgkcGtnIC1lcSAid2luZ2V0IikgeyB3aW5nZXQgaW5zdGFsbCAtLWlkPSRpZCAtLXNpbGVudCAtLWFjY2VwdC1wYWNrYWdlLWFncmVlbWVudHMgLS1hY2NlcHQtc291cmNlLWFncmVlbWVudHMgMj4mMSB8IE91dC1OdWxsIH0gZWxzZSB7IGNob2NvIGluc3RhbGwgJGlkIC15IDI+JjEgfCBPdXQtTnVsbCB9OyBXcml0ZS1Mb2cgIkluc3RhbGxlZDogJGlkIiAiU3VjY2VzcyIgfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmFpbGVkOiAkaWQiICJFcnJvciIgfQogICAgICAgICAgICAgICAgSGlkZS1Qcm9ncmVzczsgVXBkYXRlLUluc3RhbGxlZENhY2hlOyBTaG93LUluZm8gIkRvbmUiICJJbnN0YWxsIG9mICRpZCBjb21wbGV0ZWQuIgogICAgICAgICAgICB9KQogICAgICAgICAgICAkbWlVbmluc3RhbGwgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLk1lbnVJdGVtOyAkbWlVbmluc3RhbGwuSGVhZGVyID0gIlVuaW5zdGFsbCI7ICRtaVVuaW5zdGFsbC5UYWcgPSAkYXBwLndpbmdldAogICAgICAgICAgICAkbWlVbmluc3RhbGwuQWRkX0NsaWNrKHsKICAgICAgICAgICAgICAgICRpZCA9ICR0aGlzLlRhZzsgJHBrZyA9ICRzY3JpcHQ6cGtnTWFuYWdlcjsgV3JpdGUtTG9nICJDb250ZXh0OiBVbmluc3RhbGwgJGlkIHZpYSAkcGtnIiAiSW5mbyIKICAgICAgICAgICAgICAgIGlmICgtbm90IChFbnN1cmUtUGFja2FnZU1hbmFnZXIgJHBrZykpIHsgU2hvdy1JbmZvICJFcnJvciIgIkZhaWxlZCB0byBlbnN1cmUgJHBrZy4iOyByZXR1cm4gfQogICAgICAgICAgICAgICAgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiVW5pbnN0YWxsIiAiVW5pbnN0YWxsICRpZCB2aWEgJHBrZz8iKSkgeyByZXR1cm4gfQogICAgICAgICAgICAgICAgU2hvdy1Qcm9ncmVzcyAtVGV4dCAiVW5pbnN0YWxsaW5nOiAkaWQiIC1WYWx1ZSAwLjUKICAgICAgICAgICAgICAgIHRyeSB7IGlmICgkcGtnIC1lcSAid2luZ2V0IikgeyB3aW5nZXQgdW5pbnN0YWxsIC0taWQ9JGlkIC0tc2lsZW50IC0tcHVyZ2UgLS1hY2NlcHQtc291cmNlLWFncmVlbWVudHMgMj4mMSB8IE91dC1OdWxsIH0gZWxzZSB7IGNob2NvIHVuaW5zdGFsbCAkaWQgLXkgMj4mMSB8IE91dC1OdWxsIH07IFdyaXRlLUxvZyAiVW5pbnN0YWxsZWQ6ICRpZCIgIlN1Y2Nlc3MiIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkZhaWxlZDogJGlkIiAiRXJyb3IiIH0KICAgICAgICAgICAgICAgIEhpZGUtUHJvZ3Jlc3M7IFVwZGF0ZS1JbnN0YWxsZWRDYWNoZTsgU2hvdy1JbmZvICJEb25lIiAiVW5pbnN0YWxsIG9mICRpZCBjb21wbGV0ZWQuIgogICAgICAgICAgICB9KQogICAgICAgICAgICAkbWlJbmZvID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5NZW51SXRlbTsgJG1pSW5mby5IZWFkZXIgPSAiSW5mbyI7ICRtaUluZm8uVGFnID0gJGFwcAogICAgICAgICAgICAkbWlJbmZvLkFkZF9DbGljayh7ICRhID0gJHRoaXMuVGFnOyBTaG93LUluZm8gIkFwcCBJbmZvIiAiJCgkYS5jb250ZW50KWBuYG5JRDogJCgkYS53aW5nZXQpYG4kKCRhLmRlc2NyaXB0aW9uKSIgfSkKICAgICAgICAgICAgJG51bGwgPSAkY20uSXRlbXMuQWRkKCRtaUluc3RhbGwpOyAkbnVsbCA9ICRjbS5JdGVtcy5BZGQoJG1pVW5pbnN0YWxsKTsgJG51bGwgPSAkY20uSXRlbXMuQWRkKChOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlNlcGFyYXRvcikpOyAkbnVsbCA9ICRjbS5JdGVtcy5BZGQoJG1pSW5mbykKICAgICAgICAgICAgJGNiLkNvbnRleHRNZW51ID0gJGNtCiAgICAgICAgICAgICRhcHBQYW5lbHNbJGFwcFBhbmVsSW5kZXhdLkNoaWxkcmVuLkFkZCgkY2IpIHwgT3V0LU51bGwKICAgICAgICAgICAgJGFwcENoZWNrYm94ZXMgKz0gJGNiCiAgICAgICAgICAgICRzY3JpcHQ6Y2F0ZWdvcnlJdGVtc1skY2F0ZWdvcnldICs9ICRjYgogICAgICAgIH0KICAgICAgICAkYXBwUGFuZWxJbmRleCA9ICgkYXBwUGFuZWxJbmRleCArIDEpICUgMwogICAgfQogICAgZm9yZWFjaCAoJGNhdCBpbiAkc2NyaXB0OmNhdGVnb3J5SXRlbXMuS2V5cykgeyAkc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkWyRjYXRdID0gJGZhbHNlIH0KICAgIFdyaXRlLUxvZyAiQnVpbHQgJCgkYXBwQ2hlY2tib3hlcy5Db3VudCkgYXBwIGNhcmRzLiIgIlN1Y2Nlc3MiCn0KCiMgLS0tIEJ1aWxkIFByZWZlcmVuY2VzIFVJIC0tLQokcGFuZWxJbmRleCA9IDAKaWYgKCRjb250cm9sc1siUHJlZnNQYW5lbDEiXSAtYW5kICRjb250cm9sc1siUHJlZnNQYW5lbDIiXSAtYW5kICRjb250cm9sc1siUHJlZnNQYW5lbDMiXSAtYW5kICRwcmVmc0NvbmZpZykgewogICAgJHByZWZQYW5lbHMgPSBAKCRjb250cm9sc1siUHJlZnNQYW5lbDEiXSwgJGNvbnRyb2xzWyJQcmVmc1BhbmVsMiJdLCAkY29udHJvbHNbIlByZWZzUGFuZWwzIl0pCiAgICBmb3JlYWNoICgkcHJlZktleSBpbiAkcHJlZnNDb25maWcuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgJHByZWYgPSAkcHJlZnNDb25maWcuJHByZWZLZXkKICAgICAgICAkY2IgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkNoZWNrQm94CiAgICAgICAgJGNiLkNvbnRlbnQgPSAkcHJlZi5jb250ZW50OyAkY2IuVGFnID0gJHByZWZLZXk7ICRjYi5TdHlsZSA9IEdldC1XcGZSZXNvdXJjZSAiVG9nZ2xlU3dpdGNoIgogICAgICAgIGlmICgkcHJlZi5kZXNjcmlwdGlvbikgeyAkY2IuVG9vbFRpcCA9ICRwcmVmLmRlc2NyaXB0aW9uIH0KICAgICAgICAkY3VycmVudFN0YXRlID0gJG51bGwKICAgICAgICAkaGFzUmVnaXN0cnlPbiA9ICRwcmVmLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgInJlZ2lzdHJ5X29uIiAtYW5kICRwcmVmLnJlZ2lzdHJ5X29uIC1hbmQgJHByZWYucmVnaXN0cnlfb24uQ291bnQgLWd0IDAKICAgICAgICBpZiAoJGhhc1JlZ2lzdHJ5T24pIHsKICAgICAgICAgICAgJGZpcnN0UmVnID0gJHByZWYucmVnaXN0cnlfb25bMF0KICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkZmlyc3RSZWcucGF0aCkgeyB0cnkgeyAkY3VycmVudFN0YXRlID0gKEdldC1JdGVtUHJvcGVydHkgJGZpcnN0UmVnLnBhdGggLU5hbWUgJGZpcnN0UmVnLm5hbWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLiQoJGZpcnN0UmVnLm5hbWUpIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlJlZ2lzdHJ5IHJlYWQgZmFpbGVkOiAkXyIgIldhcm4iIH0gfQogICAgICAgIH0KICAgICAgICAkY2IuSXNDaGVja2VkID0gaWYgKCRoYXNSZWdpc3RyeU9uKSB7ICRjdXJyZW50U3RhdGUgLWVxICRwcmVmLnJlZ2lzdHJ5X29uWzBdLnZhbHVlIH0gZWxzZSB7ICRmYWxzZSB9CiAgICAgICAgJGNiLkFkZF9DaGVja2VkKHsKICAgICAgICAgICAgJHBrID0gJHRoaXMuVGFnOyAkcCA9ICRwcmVmc0NvbmZpZy4kcGsKICAgICAgICAgICAgaWYgKC1ub3QgJHApIHsgcmV0dXJuIH0KICAgICAgICAgICAgaWYgKCRwLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgInJlZ2lzdHJ5X29uIikgeyBmb3JlYWNoICgkciBpbiAkcC5yZWdpc3RyeV9vbikgeyB0cnkgeyBpZiAoIShUZXN0LVBhdGggJHIucGF0aCkpIHsgTmV3LUl0ZW0gJHIucGF0aCAtRm9yY2UgfCBPdXQtTnVsbCB9OyAkdCA9IGlmICgkci50eXBlKSB7ICRyLnR5cGUgfSBlbHNlIHsgIlN0cmluZyIgfTsgU2V0LUl0ZW1Qcm9wZXJ0eSAkci5wYXRoIC1OYW1lICRyLm5hbWUgLVZhbHVlICRyLnZhbHVlIC1UeXBlICR0IC1Gb3JjZSB9IGNhdGNoIHsgV3JpdGUtTG9nICJSZWdpc3RyeSB3cml0ZSBmYWlsZWQ6ICQoJHIucGF0aCkgJCgkci5uYW1lKSIgIldhcm4iIH0gfSB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUHJlZiBPTjogJCgkcC5jb250ZW50KSIgIlN1Y2Nlc3MiCiAgICAgICAgfSkKICAgICAgICAkY2IuQWRkX1VuY2hlY2tlZCh7CiAgICAgICAgICAgICRwayA9ICR0aGlzLlRhZzsgJHAgPSAkcHJlZnNDb25maWcuJHBrCiAgICAgICAgICAgIGlmICgtbm90ICRwKSB7IHJldHVybiB9CiAgICAgICAgICAgIGlmICgkcC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJyZWdpc3RyeV9vZmYiKSB7IGZvcmVhY2ggKCRyIGluICRwLnJlZ2lzdHJ5X29mZikgeyB0cnkgeyBpZiAoIShUZXN0LVBhdGggJHIucGF0aCkpIHsgTmV3LUl0ZW0gJHIucGF0aCAtRm9yY2UgfCBPdXQtTnVsbCB9OyAkdCA9IGlmICgkci50eXBlKSB7ICRyLnR5cGUgfSBlbHNlIHsgIlN0cmluZyIgfTsgU2V0LUl0ZW1Qcm9wZXJ0eSAkci5wYXRoIC1OYW1lICRyLm5hbWUgLVZhbHVlICRyLnZhbHVlIC1UeXBlICR0IC1Gb3JjZSB9IGNhdGNoIHsgV3JpdGUtTG9nICJSZWdpc3RyeSB3cml0ZSBmYWlsZWQ6ICQoJHIucGF0aCkgJCgkci5uYW1lKSIgIldhcm4iIH0gfSB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUHJlZiBPRkY6ICQoJHAuY29udGVudCkiICJXYXJuIgogICAgICAgIH0pCiAgICAgICAgJHByZWZQYW5lbHNbJHBhbmVsSW5kZXhdLkNoaWxkcmVuLkFkZCgkY2IpIHwgT3V0LU51bGwKICAgICAgICAkcHJlZkNoZWNrYm94ZXNbJHByZWZLZXldID0gJGNiCiAgICAgICAgJHBhbmVsSW5kZXggPSAoJHBhbmVsSW5kZXggKyAxKSAlIDMKICAgIH0KICAgIFdyaXRlLUxvZyAiQnVpbHQgJCgkcHJlZkNoZWNrYm94ZXMuQ291bnQpIHByZWZlcmVuY2UgdG9nZ2xlcy4iICJTdWNjZXNzIgp9CgojIC0tLSBCdWlsZCBUd2Vha3MgVUkgLS0tCiRwYW5lbEluZGV4ID0gMAppZiAoJGNvbnRyb2xzWyJUd2Vha3NQYW5lbDEiXSAtYW5kICRjb250cm9sc1siVHdlYWtzUGFuZWwyIl0gLWFuZCAkY29udHJvbHNbIlR3ZWFrc1BhbmVsMyJdIC1hbmQgJHR3ZWFrc0NvbmZpZykgewogICAgJHBhbmVscyA9IEAoJGNvbnRyb2xzWyJUd2Vha3NQYW5lbDEiXSwgJGNvbnRyb2xzWyJUd2Vha3NQYW5lbDIiXSwgJGNvbnRyb2xzWyJUd2Vha3NQYW5lbDMiXSkKICAgIGZvcmVhY2ggKCRncm91cEtleSBpbiAkdHdlYWtzQ29uZmlnLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICRncm91cCA9ICR0d2Vha3NDb25maWcuJGdyb3VwS2V5CiAgICAgICAgJGhlYWRlciA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrOyAkaGVhZGVyLlRleHQgPSAkZ3JvdXBLZXk7ICRoZWFkZXIuRm9udFNpemUgPSAxNjsgJGhlYWRlci5Gb250V2VpZ2h0ID0gIkJvbGQiCiAgICAgICAgJGhlYWRlci5TZXRSZXNvdXJjZVJlZmVyZW5jZShbU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrXTo6Rm9yZWdyb3VuZFByb3BlcnR5LCAiY2F0ZWdvcnlIZWFkZXJDb2xvciIpOyAkaGVhZGVyLk1hcmdpbiA9ICIwLDAsMCwxMCIKICAgICAgICAkcGFuZWxzWyRwYW5lbEluZGV4XS5DaGlsZHJlbi5BZGQoJGhlYWRlcikgfCBPdXQtTnVsbAogICAgICAgIGZvcmVhY2ggKCR0d2Vha0tleSBpbiAkZ3JvdXAuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgICAgICR0d2VhayA9ICRncm91cC4kdHdlYWtLZXkKICAgICAgICAgICAgJGNiID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5DaGVja0JveDsgJGNiLkNvbnRlbnQgPSAkdHdlYWsuY29udGVudDsgJGNiLlRhZyA9ICR0d2Vha0tleTsgJGNiLlN0eWxlID0gR2V0LVdwZlJlc291cmNlICJUd2Vha0NoZWNrQm94IgogICAgICAgICAgICBpZiAoJHR3ZWFrLmRlc2NyaXB0aW9uKSB7ICRjYi5Ub29sVGlwID0gJHR3ZWFrLmRlc2NyaXB0aW9uIH0KICAgICAgICAgICAgJHBhbmVsc1skcGFuZWxJbmRleF0uQ2hpbGRyZW4uQWRkKCRjYikgfCBPdXQtTnVsbAogICAgICAgICAgICAkdHdlYWtDaGVja2JveGVzICs9ICRjYgogICAgICAgIH0KICAgICAgICAkcGFuZWxJbmRleCA9ICgkcGFuZWxJbmRleCArIDEpICUgMwogICAgfQogICAgV3JpdGUtTG9nICJCdWlsdCAkKCR0d2Vha0NoZWNrYm94ZXMuQ291bnQpIHR3ZWFrIGNoZWNrYm94ZXMuIiAiU3VjY2VzcyIKfQoKIyAtLS0gQnVpbGQgRmVhdHVyZXMgJiBGaXhlcyBVSSAtLS0KJHBhbmVsSW5kZXggPSAwCmlmICgkY29udHJvbHNbIkZlYXR1cmVzUGFuZWwxIl0gLWFuZCAkY29udHJvbHNbIkZlYXR1cmVzUGFuZWwyIl0gLWFuZCAkY29udHJvbHNbIkZlYXR1cmVzUGFuZWwzIl0gLWFuZCAkZmVhdHVyZXNDb25maWcgLWFuZCAkZmVhdHVyZXNDb25maWcuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiRmVhdHVyZXMiKSB7CiAgICAkZmVhdFBhbmVscyA9IEAoJGNvbnRyb2xzWyJGZWF0dXJlc1BhbmVsMSJdLCAkY29udHJvbHNbIkZlYXR1cmVzUGFuZWwyIl0sICRjb250cm9sc1siRmVhdHVyZXNQYW5lbDMiXSkKICAgIGZvcmVhY2ggKCRmZWF0S2V5IGluICRmZWF0dXJlc0NvbmZpZy5GZWF0dXJlcy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpIHsKICAgICAgICAkZmVhdCA9ICRmZWF0dXJlc0NvbmZpZy5GZWF0dXJlcy4kZmVhdEtleQogICAgICAgICRjYiA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuQ2hlY2tCb3g7ICRjYi5Db250ZW50ID0gJGZlYXQuY29udGVudDsgJGNiLlRhZyA9ICRmZWF0S2V5OyAkY2IuU3R5bGUgPSBHZXQtV3BmUmVzb3VyY2UgIlR3ZWFrQ2hlY2tCb3giCiAgICAgICAgaWYgKCRmZWF0LmRlc2NyaXB0aW9uKSB7ICRjYi5Ub29sVGlwID0gJGZlYXQuZGVzY3JpcHRpb24gfQogICAgICAgICRmZWF0UGFuZWxzWyRwYW5lbEluZGV4XS5DaGlsZHJlbi5BZGQoJGNiKSB8IE91dC1OdWxsCiAgICAgICAgJGZlYXR1cmVzQ2hlY2tib3hlcyArPSAkY2IKICAgICAgICAkcGFuZWxJbmRleCA9ICgkcGFuZWxJbmRleCArIDEpICUgMwogICAgfQogICAgV3JpdGUtTG9nICJCdWlsdCAkKCRmZWF0dXJlc0NoZWNrYm94ZXMuQ291bnQpIGZlYXR1cmUgY2hlY2tib3hlcy4iICJTdWNjZXNzIgp9CmlmICgkY29udHJvbHNbIkZpeGVzV3JhcFBhbmVsIl0gLWFuZCAkZmVhdHVyZXNDb25maWcgLWFuZCAkZmVhdHVyZXNDb25maWcuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiRml4ZXMiKSB7CiAgICBmb3JlYWNoICgkZml4S2V5IGluICRmZWF0dXJlc0NvbmZpZy5GaXhlcy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpIHsKICAgICAgICAkZml4ID0gJGZlYXR1cmVzQ29uZmlnLkZpeGVzLiRmaXhLZXkKICAgICAgICAkYnRuID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5CdXR0b247ICRidG4uU3R5bGUgPSBHZXQtV3BmUmVzb3VyY2UgIkZlYXR1cmVDYXJkIjsgJGJ0bi5Db250ZW50ID0gJGZpeC5jb250ZW50OyAkYnRuLlRvb2xUaXAgPSAkZml4LmRlc2NyaXB0aW9uOyAkYnRuLlRhZyA9ICRmaXgKICAgICAgICAkYnRuLkFkZF9DbGljayh7CiAgICAgICAgICAgICRmID0gJHRoaXMuVGFnCiAgICAgICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIlJ1biBGaXgiICJFeGVjdXRlOiAkKCRmLmNvbnRlbnQpPyIpKSB7IHJldHVybiB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUnVubmluZyBmaXg6ICQoJGYuY29udGVudCkiICJIZWFkZXIiCiAgICAgICAgICAgIHRyeSB7ICYgKFtzY3JpcHRibG9ja106OkNyZWF0ZSgkZi5zY3JpcHQpKTsgV3JpdGUtTG9nICJGaXggY29tcGxldGVkOiAkKCRmLmNvbnRlbnQpIiAiU3VjY2VzcyI7IFNob3ctSW5mbyAiRml4IENvbXBsZXRlIiAiJCgkZi5jb250ZW50KWBuYG5Db21wbGV0ZWQgc3VjY2Vzc2Z1bGx5LiIgfSBjYXRjaCB7IFdyaXRlLUxvZyAiRml4IGZhaWxlZDogJF8iICJFcnJvciI7IFNob3ctSW5mbyAiRml4IEZhaWxlZCIgIiQoJGYuY29udGVudClgbmBuRXJyb3I6ICRfIiB9CiAgICAgICAgfSkKICAgICAgICAkY29udHJvbHNbIkZpeGVzV3JhcFBhbmVsIl0uQ2hpbGRyZW4uQWRkKCRidG4pIHwgT3V0LU51bGwKICAgIH0KICAgIFdyaXRlLUxvZyAiQnVpbHQgJCgkZmVhdHVyZXNDb25maWcuRml4ZXMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lLkNvdW50KSBmaXggYnV0dG9ucy4iICJTdWNjZXNzIgp9CgojIC0tLSBCdWlsZCBMZWdhY3kgV2luZG93cyBQYW5lbHMgVUkgLS0tCiRsZWdhY3lQYW5lbHMgPSBAKAogICAgQHsgTmFtZSA9ICJDb21wdXRlciBNYW5hZ2VtZW50IjsgRGVzYyA9ICJNYW5hZ2UgZGlza3MsIHNlcnZpY2VzLCBldmVudCB2aWV3ZXIsIGFuZCBtb3JlIjsgQ29tbWFuZCA9ICJjb21wbWdtdC5tc2MiIH0sCiAgICBAeyBOYW1lID0gIkNvbnRyb2wgUGFuZWwiOyBEZXNjID0gIkNsYXNzaWMgV2luZG93cyBDb250cm9sIFBhbmVsIjsgQ29tbWFuZCA9ICJjb250cm9sIiB9LAogICAgQHsgTmFtZSA9ICJEZXZpY2UgTWFuYWdlciI7IERlc2MgPSAiVmlldyBhbmQgdXBkYXRlIGhhcmR3YXJlIGRldmljZXMgYW5kIGRyaXZlcnMiOyBDb21tYW5kID0gImRldm1nbXQubXNjIiB9LAogICAgQHsgTmFtZSA9ICJEaXNrIE1hbmFnZW1lbnQiOyBEZXNjID0gIk1hbmFnZSBkaXNrIHBhcnRpdGlvbnMsIHZvbHVtZXMsIGFuZCBkcml2ZXMiOyBDb21tYW5kID0gImRpc2ttZ210Lm1zYyIgfSwKICAgIEB7IE5hbWUgPSAiRXZlbnQgVmlld2VyIjsgRGVzYyA9ICJWaWV3IHN5c3RlbSBsb2dzIGFuZCBhcHBsaWNhdGlvbiBldmVudHMiOyBDb21tYW5kID0gImV2ZW50dndyLm1zYyIgfSwKICAgIEB7IE5hbWUgPSAiTmV0d29yayBDb25uZWN0aW9ucyI7IERlc2MgPSAiTWFuYWdlIG5ldHdvcmsgYWRhcHRlcnMgYW5kIGNvbm5lY3Rpb25zIjsgQ29tbWFuZCA9ICJuY3BhLmNwbCIgfSwKICAgIEB7IE5hbWUgPSAiUG93ZXIgUGFuZWwiOyBEZXNjID0gIkNvbmZpZ3VyZSBwb3dlciBwbGFucyBhbmQgYmF0dGVyeSBzZXR0aW5ncyI7IENvbW1hbmQgPSAicG93ZXJjZmcuY3BsIiB9LAogICAgQHsgTmFtZSA9ICJQcmludGVyIFBhbmVsIjsgRGVzYyA9ICJNYW5hZ2UgcHJpbnRlcnMgYW5kIHByaW50IHF1ZXVlcyI7IENvbW1hbmQgPSAiY29udHJvbCBwcmludGVycyIgfSwKICAgIEB7IE5hbWUgPSAiUmVnaW9uIjsgRGVzYyA9ICJTZXQgcmVnaW9uYWwgZm9ybWF0LCBsYW5ndWFnZSwgYW5kIGxvY2F0aW9uIjsgQ29tbWFuZCA9ICJpbnRsLmNwbCIgfSwKICAgIEB7IE5hbWUgPSAiUmVnaXN0cnkgRWRpdG9yIjsgRGVzYyA9ICJWaWV3IGFuZCBlZGl0IFdpbmRvd3MgcmVnaXN0cnkgZW50cmllcyI7IENvbW1hbmQgPSAicmVnZWRpdCIgfSwKICAgIEB7IE5hbWUgPSAiU2VydmljZXMiOyBEZXNjID0gIk1hbmFnZSBXaW5kb3dzIHNlcnZpY2VzIGFuZCB0aGVpciBzdGFydHVwIHR5cGVzIjsgQ29tbWFuZCA9ICJzZXJ2aWNlcy5tc2MiIH0sCiAgICBAeyBOYW1lID0gIlNvdW5kIFNldHRpbmdzIjsgRGVzYyA9ICJDb25maWd1cmUgYXVkaW8gZGV2aWNlcyBhbmQgc291bmQgZWZmZWN0cyI7IENvbW1hbmQgPSAibW1zeXMuY3BsIiB9LAogICAgQHsgTmFtZSA9ICJTeXN0ZW0gUHJvcGVydGllcyI7IERlc2MgPSAiVmlldyBzeXN0ZW0gaW5mbywgcGVyZm9ybWFuY2UsIHJlbW90ZSBzZXR0aW5ncyI7IENvbW1hbmQgPSAic3lzZG0uY3BsIiB9LAogICAgQHsgTmFtZSA9ICJUYXNrIFNjaGVkdWxlciI7IERlc2MgPSAiU2NoZWR1bGUgYXV0b21hdGVkIHRhc2tzIGFuZCB0cmlnZ2VycyI7IENvbW1hbmQgPSAidGFza3NjaGQubXNjIiB9LAogICAgQHsgTmFtZSA9ICJUaW1lIGFuZCBEYXRlIjsgRGVzYyA9ICJTZXQgZGF0ZSwgdGltZSwgYW5kIHRpbWV6b25lIjsgQ29tbWFuZCA9ICJ0aW1lZGF0ZS5jcGwiIH0sCiAgICBAeyBOYW1lID0gIldpbmRvd3MgUmVzdG9yZSI7IERlc2MgPSAiU3lzdGVtIFJlc3RvcmUgLSBjcmVhdGUgb3IgcmVzdG9yZSByZXN0b3JlIHBvaW50cyI7IENvbW1hbmQgPSAicnN0cnVpLmV4ZSIgfQopCgppZiAoJGNvbnRyb2xzWyJMZWdhY3lQYW5lbDEiXSAtYW5kICRjb250cm9sc1siTGVnYWN5UGFuZWwyIl0gLWFuZCAkY29udHJvbHNbIkxlZ2FjeVBhbmVsMyJdKSB7CiAgICAkbGVnYWN5UGFuZWxzQXJyID0gQCgkY29udHJvbHNbIkxlZ2FjeVBhbmVsMSJdLCAkY29udHJvbHNbIkxlZ2FjeVBhbmVsMiJdLCAkY29udHJvbHNbIkxlZ2FjeVBhbmVsMyJdKQogICAgJHBhbmVsSW5kZXggPSAwCiAgICBmb3JlYWNoICgkcGFuZWwgaW4gJGxlZ2FjeVBhbmVscykgewogICAgICAgICRidG4gPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkJ1dHRvbjsgJGJ0bi5TdHlsZSA9IEdldC1XcGZSZXNvdXJjZSAiRmVhdHVyZUNhcmQiOyAkYnRuLlRvb2xUaXAgPSAiJCgkcGFuZWwuTmFtZSlgbiQoJHBhbmVsLkRlc2MpYG5gbkxhdW5jaDogJCgkcGFuZWwuQ29tbWFuZCkiOyAkYnRuLlRhZyA9ICRwYW5lbC5Db21tYW5kOyAkYnRuLkhvcml6b250YWxBbGlnbm1lbnQgPSAiU3RyZXRjaCIKICAgICAgICAkc3AgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlN0YWNrUGFuZWw7ICRzcC5PcmllbnRhdGlvbiA9ICJIb3Jpem9udGFsIgogICAgICAgICR0ZXh0U3AgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlN0YWNrUGFuZWw7ICR0ZXh0U3AuT3JpZW50YXRpb24gPSAiVmVydGljYWwiOyAkdGV4dFNwLlZlcnRpY2FsQWxpZ25tZW50ID0gIkNlbnRlciIKICAgICAgICAkbmFtZVRiID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5UZXh0QmxvY2s7ICRuYW1lVGIuVGV4dCA9ICRwYW5lbC5OYW1lOyAkbmFtZVRiLkZvbnRTaXplID0gMTQ7ICRuYW1lVGIuRm9udFdlaWdodCA9ICJTZW1pQm9sZCI7ICRuYW1lVGIuU2V0UmVzb3VyY2VSZWZlcmVuY2UoW1N5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9ja106OkZvcmVncm91bmRQcm9wZXJ0eSwgInBhZ2VUaXRsZUNvbG9yIik7ICR0ZXh0U3AuQ2hpbGRyZW4uQWRkKCRuYW1lVGIpIHwgT3V0LU51bGwKICAgICAgICAkZGVzY1RiID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5UZXh0QmxvY2s7ICRkZXNjVGIuVGV4dCA9ICRwYW5lbC5EZXNjOyAkZGVzY1RiLkZvbnRTaXplID0gMTE7ICRkZXNjVGIuU2V0UmVzb3VyY2VSZWZlcmVuY2UoW1N5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9ja106OkZvcmVncm91bmRQcm9wZXJ0eSwgInRleHRNdXRlZCIpOyAkZGVzY1RiLlRleHRXcmFwcGluZyA9ICJXcmFwIjsgJHRleHRTcC5DaGlsZHJlbi5BZGQoJGRlc2NUYikgfCBPdXQtTnVsbAogICAgICAgICRzcC5DaGlsZHJlbi5BZGQoJHRleHRTcCkgfCBPdXQtTnVsbDsgJGJ0bi5Db250ZW50ID0gJHNwCiAgICAgICAgJGJ0bi5BZGRfQ2xpY2soewogICAgICAgICAgICAkY21kID0gJHRoaXMuVGFnOyBXcml0ZS1Mb2cgIkxhdW5jaGluZzogJGNtZCIgIkluZm8iCiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAkcGFydHMgPSAkY21kIC1zcGxpdCAnICcsIDIKICAgICAgICAgICAgICAgICRleGUgPSAkcGFydHNbMF07ICRhcmdzID0gaWYgKCRwYXJ0cy5Db3VudCAtZ3QgMSkgeyAkcGFydHNbMV0gfSBlbHNlIHsgJG51bGwgfQogICAgICAgICAgICAgICAgaWYgKCRhcmdzKSB7IFN0YXJ0LVByb2Nlc3MgJGV4ZSAtQXJndW1lbnRMaXN0ICRhcmdzIC1FcnJvckFjdGlvbiBTdG9wIH0gZWxzZSB7IFN0YXJ0LVByb2Nlc3MgJGV4ZSAtRXJyb3JBY3Rpb24gU3RvcCB9CiAgICAgICAgICAgICAgICBXcml0ZS1Mb2cgIkxhdW5jaGVkOiAkY21kIiAiU3VjY2VzcyIKICAgICAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmFpbGVkIHRvIGxhdW5jaCAke2NtZH06ICRfIiAiRXJyb3IiOyBTaG93LUluZm8gIkVycm9yIiAiRmFpbGVkIHRvIGxhdW5jaCAkY21kYG5gbiRfIiB9CiAgICAgICAgfSkKICAgICAgICAkbGVnYWN5UGFuZWxzQXJyWyRwYW5lbEluZGV4XS5DaGlsZHJlbi5BZGQoJGJ0bikgfCBPdXQtTnVsbAogICAgICAgICRwYW5lbEluZGV4ID0gKCRwYW5lbEluZGV4ICsgMSkgJSAzCiAgICB9CiAgICBXcml0ZS1Mb2cgIkJ1aWx0ICQoJGxlZ2FjeVBhbmVscy5Db3VudCkgbGVnYWN5IHBhbmVsIGJ1dHRvbnMuIiAiU3VjY2VzcyIKfQo='))
$appCheckboxes = @()
$tweakCheckboxes = @()
$featuresCheckboxes = @()
$prefCheckboxes = @{}
$appPanels = @()
$script:categoryItems = @{}
$script:categoryCollapsed = @{}

# --- Build Apps UI ---
$appPanelIndex = 0
if (($controls["AppPanel1"] -and $controls["AppPanel2"] -and $controls["AppPanel3"]) -and $appsConfig) {
    $appPanels = @($controls["AppPanel1"], $controls["AppPanel2"], $controls["AppPanel3"])
    foreach ($category in $appsConfig.PSObject.Properties.Name) {
        $catCount = ($appsConfig.$category.PSObject.Properties.Name).Count
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = "- $($category.ToUpper()) ($catCount)"; $header.Style = Get-WpfResource "CategoryHeader"; $header.Cursor = "Hand"
        $header.Tag = $category
        $appPanels[$appPanelIndex].Children.Add($header) | Out-Null
        $script:categoryItems[$category] = @()
        $header.Add_MouseLeftButtonDown({
            $cat = $this.Tag
            $collapsed = $script:categoryCollapsed[$cat]
            $script:categoryCollapsed[$cat] = -not $collapsed
            foreach ($item in $script:categoryItems[$cat]) {
                $item.Visibility = if ($script:categoryCollapsed[$cat]) { "Collapsed" } else { "Visible" }
            }
            $this.Text = if ($script:categoryCollapsed[$cat]) { "+ $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" } else { "- $($cat.ToUpper()) ($($script:categoryItems[$cat].Count))" }
        })
        foreach ($appKey in $appsConfig.$category.PSObject.Properties.Name) {
            $app = $appsConfig.$category.$appKey
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $app.content; $cb.Tag = $app.winget; $cb.Style = Get-WpfResource "TweakCheckBox"
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
            $appPanels[$appPanelIndex].Children.Add($cb) | Out-Null
            $appCheckboxes += $cb
            $script:categoryItems[$category] += $cb
        }
        $appPanelIndex = ($appPanelIndex + 1) % 3
    }
    foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false }
    Write-Log "Built $($appCheckboxes.Count) app cards." "Success"
}

# --- Build Preferences UI ---
$panelIndex = 0
if ($controls["PrefsPanel1"] -and $controls["PrefsPanel2"] -and $controls["PrefsPanel3"] -and $prefsConfig) {
    $prefPanels = @($controls["PrefsPanel1"], $controls["PrefsPanel2"], $controls["PrefsPanel3"])
    foreach ($prefKey in $prefsConfig.PSObject.Properties.Name) {
        $pref = $prefsConfig.$prefKey
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $pref.content; $cb.Tag = $prefKey; $cb.Style = Get-WpfResource "ToggleSwitch"
        if ($pref.description) { $cb.ToolTip = $pref.description }
        $currentState = $null
        $hasRegistryOn = $pref.PSObject.Properties.Name -contains "registry_on" -and $pref.registry_on -and $pref.registry_on.Count -gt 0
        if ($hasRegistryOn) {
            $firstReg = $pref.registry_on[0]
            if (Test-Path $firstReg.path) { try { $currentState = (Get-ItemProperty $firstReg.path -Name $firstReg.name -ErrorAction SilentlyContinue).$($firstReg.name) } catch { Write-Log "Registry read failed: $_" "Warn" } }
        }
        $cb.IsChecked = if ($hasRegistryOn) { $currentState -eq $pref.registry_on[0].value } else { $false }
        $cb.Add_Checked({
            $pk = $this.Tag; $p = $prefsConfig.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_on") { foreach ($r in $p.registry_on) { try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; $t = if ($r.type) { $r.type } else { "String" }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Type $t -Force } catch { Write-Log "Registry write failed: $($r.path) $($r.name)" "Warn" } } }
            Write-Log "Pref ON: $($p.content)" "Success"
        })
        $cb.Add_Unchecked({
            $pk = $this.Tag; $p = $prefsConfig.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_off") { foreach ($r in $p.registry_off) { try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; $t = if ($r.type) { $r.type } else { "String" }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Type $t -Force } catch { Write-Log "Registry write failed: $($r.path) $($r.name)" "Warn" } } }
            Write-Log "Pref OFF: $($p.content)" "Warn"
        })
        $prefPanels[$panelIndex].Children.Add($cb) | Out-Null
        $prefCheckboxes[$prefKey] = $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($prefCheckboxes.Count) preference toggles." "Success"
}

# --- Build Tweaks UI ---
$panelIndex = 0
if ($controls["TweaksPanel1"] -and $controls["TweaksPanel2"] -and $controls["TweaksPanel3"] -and $tweaksConfig) {
    $panels = @($controls["TweaksPanel1"], $controls["TweaksPanel2"], $controls["TweaksPanel3"])
    foreach ($groupKey in $tweaksConfig.PSObject.Properties.Name) {
        $group = $tweaksConfig.$groupKey
        $header = New-Object System.Windows.Controls.TextBlock; $header.Text = $groupKey; $header.FontSize = 16; $header.FontWeight = "Bold"
        $header.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "categoryHeaderColor"); $header.Margin = "0,0,0,10"
        $panels[$panelIndex].Children.Add($header) | Out-Null
        foreach ($tweakKey in $group.PSObject.Properties.Name) {
            $tweak = $group.$tweakKey
            $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $tweak.content; $cb.Tag = $tweakKey; $cb.Style = Get-WpfResource "TweakCheckBox"
            if ($tweak.description) { $cb.ToolTip = $tweak.description }
            $panels[$panelIndex].Children.Add($cb) | Out-Null
            $tweakCheckboxes += $cb
        }
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($tweakCheckboxes.Count) tweak checkboxes." "Success"
}

# --- Build Features & Fixes UI ---
$panelIndex = 0
if ($controls["FeaturesPanel1"] -and $controls["FeaturesPanel2"] -and $controls["FeaturesPanel3"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Features") {
    $featPanels = @($controls["FeaturesPanel1"], $controls["FeaturesPanel2"], $controls["FeaturesPanel3"])
    foreach ($featKey in $featuresConfig.Features.PSObject.Properties.Name) {
        $feat = $featuresConfig.Features.$featKey
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $feat.content; $cb.Tag = $featKey; $cb.Style = Get-WpfResource "TweakCheckBox"
        if ($feat.description) { $cb.ToolTip = $feat.description }
        $featPanels[$panelIndex].Children.Add($cb) | Out-Null
        $featuresCheckboxes += $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($featuresCheckboxes.Count) feature checkboxes." "Success"
}
if ($controls["FixesWrapPanel"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Fixes") {
    foreach ($fixKey in $featuresConfig.Fixes.PSObject.Properties.Name) {
        $fix = $featuresConfig.Fixes.$fixKey
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "FeatureCard"; $btn.Content = $fix.content; $btn.ToolTip = $fix.description; $btn.Tag = $fix
        $btn.Add_Click({
            $f = $this.Tag
            if (-not (Show-Confirm "Run Fix" "Execute: $($f.content)?")) { return }
            Write-Log "Running fix: $($f.content)" "Header"
            try { & ([scriptblock]::Create($f.script)); Write-Log "Fix completed: $($f.content)" "Success"; Show-Info "Fix Complete" "$($f.content)`n`nCompleted successfully." } catch { Write-Log "Fix failed: $_" "Error"; Show-Info "Fix Failed" "$($f.content)`n`nError: $_" }
        })
        $controls["FixesWrapPanel"].Children.Add($btn) | Out-Null
    }
    Write-Log "Built $($featuresConfig.Fixes.PSObject.Properties.Name.Count) fix buttons." "Success"
}

# --- Build Legacy Windows Panels UI ---
$legacyPanels = @(
    @{ Name = "Computer Management"; Desc = "Manage disks, services, event viewer, and more"; Command = "compmgmt.msc" },
    @{ Name = "Control Panel"; Desc = "Classic Windows Control Panel"; Command = "control" },
    @{ Name = "Device Manager"; Desc = "View and update hardware devices and drivers"; Command = "devmgmt.msc" },
    @{ Name = "Disk Management"; Desc = "Manage disk partitions, volumes, and drives"; Command = "diskmgmt.msc" },
    @{ Name = "Event Viewer"; Desc = "View system logs and application events"; Command = "eventvwr.msc" },
    @{ Name = "Network Connections"; Desc = "Manage network adapters and connections"; Command = "ncpa.cpl" },
    @{ Name = "Power Panel"; Desc = "Configure power plans and battery settings"; Command = "powercfg.cpl" },
    @{ Name = "Printer Panel"; Desc = "Manage printers and print queues"; Command = "control printers" },
    @{ Name = "Region"; Desc = "Set regional format, language, and location"; Command = "intl.cpl" },
    @{ Name = "Registry Editor"; Desc = "View and edit Windows registry entries"; Command = "regedit" },
    @{ Name = "Services"; Desc = "Manage Windows services and their startup types"; Command = "services.msc" },
    @{ Name = "Sound Settings"; Desc = "Configure audio devices and sound effects"; Command = "mmsys.cpl" },
    @{ Name = "System Properties"; Desc = "View system info, performance, remote settings"; Command = "sysdm.cpl" },
    @{ Name = "Task Scheduler"; Desc = "Schedule automated tasks and triggers"; Command = "taskschd.msc" },
    @{ Name = "Time and Date"; Desc = "Set date, time, and timezone"; Command = "timedate.cpl" },
    @{ Name = "Windows Restore"; Desc = "System Restore - create or restore restore points"; Command = "rstrui.exe" }
)

if ($controls["LegacyPanel1"] -and $controls["LegacyPanel2"] -and $controls["LegacyPanel3"]) {
    $legacyPanelsArr = @($controls["LegacyPanel1"], $controls["LegacyPanel2"], $controls["LegacyPanel3"])
    $panelIndex = 0
    foreach ($panel in $legacyPanels) {
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "FeatureCard"; $btn.ToolTip = "$($panel.Name)`n$($panel.Desc)`n`nLaunch: $($panel.Command)"; $btn.Tag = $panel.Command; $btn.HorizontalAlignment = "Stretch"
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
        $textSp = New-Object System.Windows.Controls.StackPanel; $textSp.Orientation = "Vertical"; $textSp.VerticalAlignment = "Center"
        $nameTb = New-Object System.Windows.Controls.TextBlock; $nameTb.Text = $panel.Name; $nameTb.FontSize = 14; $nameTb.FontWeight = "SemiBold"; $nameTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "pageTitleColor"); $textSp.Children.Add($nameTb) | Out-Null
        $descTb = New-Object System.Windows.Controls.TextBlock; $descTb.Text = $panel.Desc; $descTb.FontSize = 11; $descTb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "textMuted"); $descTb.TextWrapping = "Wrap"; $textSp.Children.Add($descTb) | Out-Null
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
        $legacyPanelsArr[$panelIndex].Children.Add($btn) | Out-Null
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($legacyPanels.Count) legacy panel buttons." "Success"
}

$script:__mod_install = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpwa2dNYW5hZ2VyID0gIndpbmdldCIKCmZ1bmN0aW9uIEVuc3VyZS1QYWNrYWdlTWFuYWdlciB7CiAgICBwYXJhbShbc3RyaW5nXSRQa2cpCiAgICBpZiAoR2V0LUNvbW1hbmQgJFBrZyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkgeyByZXR1cm4gJHRydWUgfQogICAgV3JpdGUtTG9nICIkUGtnIG5vdCBmb3VuZC4gSW5zdGFsbGluZy4uLiIgIkluZm8iCiAgICB0cnkgewogICAgICAgIGlmICgkUGtnIC1lcSAid2luZ2V0IikgewogICAgICAgICAgICAkdXJsID0gImh0dHBzOi8vZ2l0aHViLmNvbS9taWNyb3NvZnQvd2luZ2V0LWNsaS9yZWxlYXNlcy9sYXRlc3QvZG93bmxvYWQvTWljcm9zb2Z0LkRlc2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgogICAgICAgICAgICAkb3V0ID0gIiRlbnY6VEVNUFxBcHBJbnN0YWxsZXIubXNpeGJ1bmRsZSIKICAgICAgICAgICAgSW52b2tlLVdlYlJlcXVlc3QgLVVyaSAkdXJsIC1PdXRGaWxlICRvdXQgLVVzZUJhc2ljUGFyc2luZwogICAgICAgICAgICBBZGQtQXBweFBhY2thZ2UgLVBhdGggJG91dCAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgICAgICBSZW1vdmUtSXRlbSAkb3V0IC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIH0gZWxzZWlmICgkUGtnIC1lcSAiY2hvY28iKSB7CiAgICAgICAgICAgICRjaG9jb1BhdGggPSAiJGVudjpQUk9HUkFNREFUQVxjaG9jb2xhdGV5XGNob2NvLmV4ZSIKICAgICAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkY2hvY29QYXRoKSkgewogICAgICAgICAgICAgICAgU2V0LUV4ZWN1dGlvblBvbGljeSBCeXBhc3MgLVNjb3BlIFByb2Nlc3MgLUZvcmNlCiAgICAgICAgICAgICAgICBbU3lzdGVtLk5ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6U2VjdXJpdHlQcm90b2NvbCA9IFtTeXN0ZW0uTmV0LlNlcnZpY2VQb2ludE1hbmFnZXJdOjpTZWN1cml0eVByb3RvY29sIC1ib3IgMzA3MgogICAgICAgICAgICAgICAgJHRtcCA9ICIkZW52OlRFTVBcY2hvY28taW5zdGFsbC5wczEiCiAgICAgICAgICAgICAgICBJbnZva2UtV2ViUmVxdWVzdCAtVXJpICdodHRwczovL2NvbW11bml0eS5jaG9jb2xhdGV5Lm9yZy9pbnN0YWxsLnBzMScgLU91dEZpbGUgJHRtcCAtVXNlQmFzaWNQYXJzaW5nCiAgICAgICAgICAgICAgICAmICR0bXAKICAgICAgICAgICAgICAgIFJlbW92ZS1JdGVtICR0bXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgaWYgKEdldC1Db21tYW5kICRQa2cgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIHsgV3JpdGUtTG9nICIkUGtnIGluc3RhbGxlZC4iICJTdWNjZXNzIjsgcmV0dXJuICR0cnVlIH0KICAgICAgICBXcml0ZS1Mb2cgIiRQa2cgaW5zdGFsbCBjb21wbGV0ZWQgYnV0IGNvbW1hbmQgbm90IGZvdW5kLiIgIldhcm4iOyByZXR1cm4gJGZhbHNlCiAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICIkUGtnIGluc3RhbGwgZmFpbGVkOiAkXyIgIkVycm9yIjsgcmV0dXJuICRmYWxzZSB9Cn0KCmlmICgkY29udHJvbHNbIkJ0bkluc3RhbGwiXSkgewogICAgJGNvbnRyb2xzWyJCdG5JbnN0YWxsIl0uQWRkX0NsaWNrKHsKICAgICAgICAkc2VsZWN0ZWQgPSAkYXBwQ2hlY2tib3hlcyB8IFdoZXJlLU9iamVjdCB7ICRfLklzQ2hlY2tlZCAtZXEgJHRydWUgfQogICAgICAgIGlmICgkc2VsZWN0ZWQuQ291bnQgLWVxIDApIHsgV3JpdGUtTG9nICJObyBhcHBzIHNlbGVjdGVkLiIgIldhcm4iOyByZXR1cm4gfQogICAgICAgICRwa2cgPSAkc2NyaXB0OnBrZ01hbmFnZXIKICAgICAgICBpZiAoLW5vdCAoRW5zdXJlLVBhY2thZ2VNYW5hZ2VyICRwa2cpKSB7IFNob3ctSW5mbyAiRXJyb3IiICJGYWlsZWQgdG8gZW5zdXJlICRwa2cuIjsgcmV0dXJuIH0KICAgICAgICBpZiAoLW5vdCAoU2hvdy1Db25maXJtICJJbnN0YWxsIEFwcHMiICJJbnN0YWxsICQoJHNlbGVjdGVkLkNvdW50KSBhcHBsaWNhdGlvbihzKSB2aWEgJHBrZz8iKSkgeyByZXR1cm4gfQogICAgICAgIFdyaXRlLUxvZyAiU3RhcnRpbmcgaW5zdGFsbGF0aW9uIHZpYSAkcGtnLi4uIiAiSGVhZGVyIgogICAgICAgIFNldC1TdGF0dXMgIkluc3RhbGxpbmcgJCgkc2VsZWN0ZWQuQ291bnQpIGFwcChzKSB2aWEgJHBrZy4uLiIKICAgICAgICBTaG93LVByb2dyZXNzIC1UZXh0ICJQcmVwYXJpbmcgaW5zdGFsbGF0aW9uLi4uIiAtVmFsdWUgMC4wNQogICAgICAgICRjb3VudCA9IDAKICAgICAgICBmb3JlYWNoICgkY2IgaW4gJHNlbGVjdGVkKSB7CiAgICAgICAgICAgICRpZCA9ICRjYi5UYWc7ICRjb3VudCsrCiAgICAgICAgICAgICRwZXJjZW50ID0gW21hdGhdOjpNYXgoMC4wNSwgW21hdGhdOjpNaW4oMC45NSwgKCRjb3VudCAvICRzZWxlY3RlZC5Db3VudCkgKiAwLjkpKQogICAgICAgICAgICBXcml0ZS1Mb2cgIkluc3RhbGxpbmcgJGlkLi4uIiAiSW5mbyI7IFNldC1TdGF0dXMgIkluc3RhbGxpbmcgJGlkLi4uIgogICAgICAgICAgICBTaG93LVByb2dyZXNzIC1UZXh0ICJJbnN0YWxsaW5nOiAkaWQgKCRjb3VudC8kKCRzZWxlY3RlZC5Db3VudCkpIiAtVmFsdWUgJHBlcmNlbnQKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgIGlmICgkcGtnIC1lcSAid2luZ2V0IikgeyB3aW5nZXQgaW5zdGFsbCAtLWlkPSRpZCAtLXNpbGVudCAtLWFjY2VwdC1wYWNrYWdlLWFncmVlbWVudHMgLS1hY2NlcHQtc291cmNlLWFncmVlbWVudHMgMj4mMSB8IE91dC1OdWxsIH0KICAgICAgICAgICAgICAgIGVsc2UgeyBjaG9jbyBpbnN0YWxsICRpZCAteSAyPiYxIHwgT3V0LU51bGwgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJEb25lOiAkaWQiICJTdWNjZXNzIgogICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJGYWlsZWQ6ICRpZGA6ICRfIiAiRXJyb3IiIH0KICAgICAgICB9CiAgICAgICAgVXBkYXRlLUluc3RhbGxlZENhY2hlCiAgICAgICAgaWYgKCRjb250cm9sc1siQ2hrU2hvd0luc3RhbGxlZCJdKSB7IEFwcGx5LUZpbHRlcnMgfQogICAgICAgIEhpZGUtUHJvZ3Jlc3M7IFNldC1TdGF0dXMgIlJlYWR5IgogICAgICAgIFNob3ctSW5mbyAiSW5zdGFsbGF0aW9uIENvbXBsZXRlIiAiJCgkc2VsZWN0ZWQuQ291bnQpIGFwcGxpY2F0aW9uKHMpIGluc3RhbGxlZCB2aWEgJHBrZy4iCiAgICAgICAgV3JpdGUtTG9nICJJbnN0YWxsYXRpb24gY29tcGxldGUuIiAiSGVhZGVyIgogICAgICAgIFNldC1Qcm9ncmVzc1Rhc2tiYXIgLXN0YXRlICJOb3JtYWwiIC12YWx1ZSAxCiAgICB9KQp9CgppZiAoJGNvbnRyb2xzWyJCdG5Vbmluc3RhbGwiXSkgewogICAgJGNvbnRyb2xzWyJCdG5Vbmluc3RhbGwiXS5BZGRfQ2xpY2soewogICAgICAgICRzZWxlY3RlZCA9ICRhcHBDaGVja2JveGVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSXNDaGVja2VkIC1lcSAkdHJ1ZSB9CiAgICAgICAgaWYgKCRzZWxlY3RlZC5Db3VudCAtZXEgMCkgeyBXcml0ZS1Mb2cgIk5vIGFwcHMgc2VsZWN0ZWQuIiAiV2FybiI7IHJldHVybiB9CiAgICAgICAgJHBrZyA9ICRzY3JpcHQ6cGtnTWFuYWdlcgogICAgICAgIGlmICgtbm90IChFbnN1cmUtUGFja2FnZU1hbmFnZXIgJHBrZykpIHsgU2hvdy1JbmZvICJFcnJvciIgIkZhaWxlZCB0byBlbnN1cmUgJHBrZy4iOyByZXR1cm4gfQogICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIlVuaW5zdGFsbCBBcHBzIiAiVW5pbnN0YWxsICQoJHNlbGVjdGVkLkNvdW50KSBhcHBsaWNhdGlvbihzKSBhbmQgZGVlcCBjbGVhbiBsZWZ0b3ZlcnMgdmlhICRwa2c/YG5gblRoaXMgY2Fubm90IGJlIHVuZG9uZSEiKSkgeyByZXR1cm4gfQogICAgICAgIFdyaXRlLUxvZyAiU3RhcnRpbmcgdW5pbnN0YWxsYXRpb24gdmlhICRwa2cuLi4iICJIZWFkZXIiCiAgICAgICAgU2V0LVN0YXR1cyAiVW5pbnN0YWxsaW5nICQoJHNlbGVjdGVkLkNvdW50KSBhcHAocykgdmlhICRwa2cuLi4iCiAgICAgICAgU2hvdy1Qcm9ncmVzcyAtVGV4dCAiUHJlcGFyaW5nIHVuaW5zdGFsbGF0aW9uLi4uIiAtVmFsdWUgMC4wNQogICAgICAgICRjb3VudCA9IDAKICAgICAgICBmb3JlYWNoICgkY2IgaW4gJHNlbGVjdGVkKSB7CiAgICAgICAgICAgICRpZCA9ICRjYi5UYWc7ICRjb3VudCsrCiAgICAgICAgICAgICRwZXJjZW50ID0gW21hdGhdOjpNYXgoMC4wNSwgW21hdGhdOjpNaW4oMC45NSwgKCRjb3VudCAvICRzZWxlY3RlZC5Db3VudCkgKiAwLjkpKQogICAgICAgICAgICBXcml0ZS1Mb2cgIlVuaW5zdGFsbGluZyAkaWQuLi4iICJJbmZvIjsgU2V0LVN0YXR1cyAiVW5pbnN0YWxsaW5nICRpZC4uLiIKICAgICAgICAgICAgU2hvdy1Qcm9ncmVzcyAtVGV4dCAiVW5pbnN0YWxsaW5nOiAkaWQgKCRjb3VudC8kKCRzZWxlY3RlZC5Db3VudCkpIiAtVmFsdWUgJHBlcmNlbnQKICAgICAgICAgICAgJG9rID0gJHRydWUKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgIGlmICgkcGtnIC1lcSAid2luZ2V0IikgeyB3aW5nZXQgdW5pbnN0YWxsIC0taWQ9JGlkIC0tc2lsZW50IC0tcHVyZ2UgLS1hY2NlcHQtc291cmNlLWFncmVlbWVudHMgMj4mMSB8IE91dC1OdWxsIH0KICAgICAgICAgICAgICAgIGVsc2UgeyBjaG9jbyB1bmluc3RhbGwgJGlkIC15IDI+JjEgfCBPdXQtTnVsbCB9CiAgICAgICAgICAgICAgICBXcml0ZS1Mb2cgIkRvbmU6ICRpZCIgIlN1Y2Nlc3MiCiAgICAgICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkZhaWxlZDogJGlkYDogJF8iICJFcnJvciI7ICRvayA9ICRmYWxzZSB9CiAgICAgICAgICAgIGlmICgkb2sgLWFuZCAkcGtnIC1lcSAid2luZ2V0IikgewogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJEZWVwIENsZWFuaW5nICRpZC4uLiIgIkluZm8iOyBTZXQtU3RhdHVzICJDbGVhbmluZyAkaWQgbGVmdG92ZXJzLi4uIgogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHRlcm0gaW4gKCRpZCAtc3BsaXQgJ1wuJykgfCBXaGVyZS1PYmplY3QgeyAkXy5MZW5ndGggLWd0IDQgfSkgewogICAgICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRiYXNlUGF0aCBpbiBAKCRlbnY6QVBQREFUQSwgJGVudjpMT0NBTEFQUERBVEEsICRlbnY6UFJPR1JBTURBVEEpKSB7CiAgICAgICAgICAgICAgICAgICAgICAgIEdldC1DaGlsZEl0ZW0gLVBhdGggJGJhc2VQYXRoIC1EaXJlY3RvcnkgLUZpbHRlciAiKiR0ZXJtKiIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgLURlcHRoIDIgfCBGb3JFYWNoLU9iamVjdCB7IHRyeSB7IFJlbW92ZS1JdGVtICRfLkZ1bGxOYW1lIC1SZWN1cnNlIC1Gb3JjZTsgV3JpdGUtTG9nICJEZWxldGVkOiAkKCRfLkZ1bGxOYW1lKSIgIlN1Y2Nlc3MiIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkNsZWFudXAgZGlyIGZhaWxlZDogJCgkXy5GdWxsTmFtZSkiICJXYXJuIiB9IH0KICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgZm9yZWFjaCAoJHJlZ1BhdGggaW4gQCgiSEtDVTpcU29mdHdhcmUiLCAiSEtMTTpcU09GVFdBUkVcV09XNjQzMk5vZGUiKSkgewogICAgICAgICAgICAgICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRyZWdQYXRoKSB7IEdldC1DaGlsZEl0ZW0gLVBhdGggJHJlZ1BhdGggLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgLURlcHRoIDEgfCBXaGVyZS1PYmplY3QgeyAkXy5OYW1lLkNvbnRhaW5zKCR0ZXJtKSB9IHwgRm9yRWFjaC1PYmplY3QgeyB0cnkgeyBSZW1vdmUtSXRlbSAkXy5QU1BhdGggLVJlY3Vyc2UgLUZvcmNlOyBXcml0ZS1Mb2cgIkRlbGV0ZWQgUmVnOiAkKCRfLk5hbWUpIiAiU3VjY2VzcyIgfSBjYXRjaCB7IFdyaXRlLUxvZyAiQ2xlYW51cCByZWcgZmFpbGVkOiAkKCRfLk5hbWUpIiAiV2FybiIgfSB9IH0KICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgVXBkYXRlLUluc3RhbGxlZENhY2hlCiAgICAgICAgaWYgKCRjb250cm9sc1siQ2hrU2hvd0luc3RhbGxlZCJdKSB7IEFwcGx5LUZpbHRlcnMgfQogICAgICAgIEhpZGUtUHJvZ3Jlc3M7IFNldC1TdGF0dXMgIlJlYWR5IgogICAgICAgIFNob3ctSW5mbyAiVW5pbnN0YWxsIENvbXBsZXRlIiAiJCgkc2VsZWN0ZWQuQ291bnQpIGFwcGxpY2F0aW9uKHMpIHVuaW5zdGFsbGVkIHZpYSAkcGtnLiIKICAgICAgICBXcml0ZS1Mb2cgIlVuaW5zdGFsbGF0aW9uIGNvbXBsZXRlLiIgIkhlYWRlciIKICAgIH0pCn0KCmlmICgkY29udHJvbHNbIlBrZ1dpbkdldCJdKSB7ICRjb250cm9sc1siUGtnV2luR2V0Il0uQWRkX0NoZWNrZWQoeyAkc2NyaXB0OnBrZ01hbmFnZXIgPSAid2luZ2V0IjsgV3JpdGUtTG9nICJQYWNrYWdlIG1hbmFnZXI6IFdpbkdldCIgIkluZm8iIH0pIH0KaWYgKCRjb250cm9sc1siUGtnQ2hvY28iXSkgeyAkY29udHJvbHNbIlBrZ0Nob2NvIl0uQWRkX0NoZWNrZWQoeyAkc2NyaXB0OnBrZ01hbmFnZXIgPSAiY2hvY28iOyBXcml0ZS1Mb2cgIlBhY2thZ2UgbWFuYWdlcjogQ2hvY29sYXRleSIgIkluZm8iIH0pIH0K'))
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
                        Get-ChildItem -Path $basePath -Directory -Filter "*$term*" -ErrorAction SilentlyContinue -Depth 2 | ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force; Write-Log "Deleted: $($_.FullName)" "Success" } catch { Write-Log "Cleanup dir failed: $($_.FullName)" "Warn" } }
                    }
                    foreach ($regPath in @("HKCU:\Software", "HKLM:\SOFTWARE\WOW6432Node")) {
                        if (Test-Path $regPath) { Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue -Depth 1 | Where-Object { $_.Name.Contains($term) } | ForEach-Object { try { Remove-Item $_.PSPath -Recurse -Force; Write-Log "Deleted Reg: $($_.Name)" "Success" } catch { Write-Log "Cleanup reg failed: $($_.Name)" "Warn" } } }
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

$script:__mod_features = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aWYgKCRjb250cm9sc1siQnRuUnVuRmVhdHVyZXMiXSAtYW5kICRmZWF0dXJlc0NvbmZpZyAtYW5kICRmZWF0dXJlc0NvbmZpZy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJGZWF0dXJlcyIpIHsKICAgICRjb250cm9sc1siQnRuUnVuRmVhdHVyZXMiXS5BZGRfQ2xpY2soewogICAgICAgICRzZWxlY3RlZCA9ICRmZWF0dXJlc0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0KICAgICAgICBpZiAoJHNlbGVjdGVkLkNvdW50IC1lcSAwKSB7IFdyaXRlLUxvZyAiTm8gZmVhdHVyZXMgc2VsZWN0ZWQuIiAiV2FybiI7IHJldHVybiB9CiAgICAgICAgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiUnVuIEZlYXR1cmVzIiAiQXBwbHkgJCgkc2VsZWN0ZWQuQ291bnQpIHNlbGVjdGVkIGZlYXR1cmUocyk/IikpIHsgcmV0dXJuIH0KICAgICAgICBXcml0ZS1Mb2cgIlJ1bm5pbmcgU2VsZWN0ZWQgRmVhdHVyZXMuLi4iICJIZWFkZXIiCiAgICAgICAgU2V0LVN0YXR1cyAiUnVubmluZyAkKCRzZWxlY3RlZC5Db3VudCkgZmVhdHVyZShzKS4uLiIKICAgICAgICBmb3JlYWNoICgkY2IgaW4gJHNlbGVjdGVkKSB7CiAgICAgICAgICAgICRmZWF0S2V5ID0gJGNiLlRhZwogICAgICAgICAgICAkZmVhdCA9ICRmZWF0dXJlc0NvbmZpZy5GZWF0dXJlcy4kZmVhdEtleQogICAgICAgICAgICBpZiAoLW5vdCAkZmVhdCkgeyBjb250aW51ZSB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUnVubmluZzogJCgkZmVhdC5jb250ZW50KSIgIkluZm8iCiAgICAgICAgICAgIHRyeSB7ICYgKFtzY3JpcHRibG9ja106OkNyZWF0ZSgkZmVhdC5zY3JpcHQpKTsgV3JpdGUtTG9nICJGZWF0dXJlIGNvbXBsZXRlZDogJCgkZmVhdC5jb250ZW50KSIgIlN1Y2Nlc3MiIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkZlYXR1cmUgZmFpbGVkOiAkKCRmZWF0LmNvbnRlbnQpOiAkXyIgIkVycm9yIiB9CiAgICAgICAgfQogICAgICAgIFNldC1TdGF0dXMgIlJlYWR5IgogICAgICAgIFNob3ctSW5mbyAiRmVhdHVyZXMgQ29tcGxldGUiICIkKCRzZWxlY3RlZC5Db3VudCkgZmVhdHVyZShzKSBhcHBsaWVkLiIKICAgICAgICBXcml0ZS1Mb2cgIkFsbCBzZWxlY3RlZCBmZWF0dXJlcyBjb21wbGV0ZWQuIiAiSGVhZGVyIgogICAgfSkKfQo='))
if ($controls["BtnRunFeatures"] -and $featuresConfig -and $featuresConfig.PSObject.Properties.Name -contains "Features") {
    $controls["BtnRunFeatures"].Add_Click({
        $selected = $featuresCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No features selected." "Warn"; return }
        if (-not (Show-Confirm "Run Features" "Apply $($selected.Count) selected feature(s)?")) { return }
        Write-Log "Running Selected Features..." "Header"
        Set-Status "Running $($selected.Count) feature(s)..."
        foreach ($cb in $selected) {
            $featKey = $cb.Tag
            $feat = $featuresConfig.Features.$featKey
            if (-not $feat) { continue }
            Write-Log "Running: $($feat.content)" "Info"
            try { & ([scriptblock]::Create($feat.script)); Write-Log "Feature completed: $($feat.content)" "Success" } catch { Write-Log "Feature failed: $($feat.content): $_" "Error" }
        }
        Set-Status "Ready"
        Show-Info "Features Complete" "$($selected.Count) feature(s) applied."
        Write-Log "All selected features completed." "Header"
    })
}

$script:embedded_features = @'
{
  "Features": {
    "dotnet": { "content": ".NET Framework (2, 3, 4)", "description": "Enable .NET Framework 3.5 and 4.8", "script": "Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs -All -NoRestart" },
    "hyperv": { "content": "Hyper-V", "description": "Enable Hyper-V virtualization", "script": "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart" },
    "f8_boot_enable": { "content": "Legacy F8 Boot Recovery - Enable", "description": "Enable legacy F8 boot menu", "script": "bcdedit /set {default} bootmenupolicy legacy" },
    "f8_boot_disable": { "content": "Legacy F8 Boot Recovery - Disable", "description": "Disable legacy F8 boot menu", "script": "bcdedit /set {default} bootmenupolicy standard" },
    "legacy_media": { "content": "Legacy Media Components (WMP, DirectPlay)", "description": "Enable Windows Media Player and DirectPlay", "script": "Enable-WindowsOptionalFeature -Online -FeatureName 'WindowsMediaPlayer' -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName 'DirectPlay' -All -NoRestart" },
    "nfs": { "content": "Network File System (NFS)", "description": "Enable Services for NFS", "script": "Enable-WindowsOptionalFeature -Online -FeatureName 'ServicesForNFS-ClientOnly' -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName 'ClientForNFS-Infrastructure' -All -NoRestart" },
    "registry_backup": { "content": "Registry Backup (Daily Task 12:30am)", "description": "Schedule daily registry backup task", "script": "schtasks /create /tn 'Registry Backup' /tr 'regedit /e C:\\Windows\\System32\\config\\RegBack\\registry_backup.reg' /sc daily /st 00:30 /f" },
    "sandbox": { "content": "Windows Sandbox", "description": "Enable Windows Sandbox", "script": "Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All -NoRestart" },
    "wsl": { "content": "Windows Subsystem for Linux (WSL)", "description": "Enable WSL2 and Virtual Machine Platform", "script": "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart" }
  },
  "Fixes": {
    "autologon": { "content": "AutoLogon - Run", "description": "Open the Autologon configuration tool", "script": "Start-Process 'https://live.sysinternals.com/Autologon.exe'" },
    "reset_network": { "content": "Network - Reset", "description": "Reset TCP/IP, Winsock, flush DNS", "script": "netsh winsock reset; netsh int ip reset; ipconfig /release; ipconfig /renew; ipconfig /flushdns" },
    "ntp_server": { "content": "NTP Server - Enable", "description": "Sync time with pool.ntp.org", "script": "w32tm /config /manualpeerlist:'pool.ntp.org' /syncfromflags:manual /reliable:yes /update; w32tm /resync" },
    "sfc_scan": { "content": "System Corruption Scan - Run", "description": "Run SFC scan to check system files", "script": "sfc /scannow" },
    "system_repair": { "content": "System Repair - Full (SFC + DISM)", "description": "Run SFC and DISM repair", "script": "sfc /scannow; dism /online /cleanup-image /restorehealth" },
    "update_repair": { "content": "Windows Update - Full Repair", "description": "Complete Windows Update component repair", "script": "Stop-Service wuauserv,cryptSvc,bits,msiserver -Force; Ren -Path \"$env:SystemRoot\\SoftwareDistribution\" -NewName 'SoftwareDistribution.old' -ErrorAction SilentlyContinue; Ren -Path \"$env:SystemRoot\\System32\\catroot2\" -NewName 'catroot2.old' -ErrorAction SilentlyContinue; netsh winsock reset; Start-Service wuauserv,cryptSvc,bits,msiserver" },
    "reset_wu": { "content": "Windows Update - Reset", "description": "Reset Windows Update components", "script": "Stop-Service wuauserv,cryptSvc,bits,msiserver -Force; Ren -Path \"$env:SystemRoot\\SoftwareDistribution\" -NewName 'SoftwareDistribution.old' -ErrorAction SilentlyContinue; Ren -Path \"$env:SystemRoot\\System32\\catroot2\" -NewName 'catroot2.old' -ErrorAction SilentlyContinue; Start-Service wuauserv,cryptSvc,bits,msiserver" },
    "reinstall_winget": { "content": "WinGet - Reinstall", "description": "Reinstall WinGet package manager", "script": "Get-AppxPackage Microsoft.DesktopAppInstaller | Remove-AppxPackage; start 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1'" }
  }
}

'@ | ConvertFrom-Json
$script:embedded_themes = @'
{
  "dark": {
    "windowBackground": "#1C1C1E", "headerBackground": "#242426", "headerBorder": "#3A3A3C",
    "footerBackground": "#242426", "footerBorder": "#3A3A3C",
    "cardBackground": "#2C2C2E", "cardForeground": "#D4CEBC", "cardBorder": "#48484A",
    "accentColor": "#4D9DE0", "accentHover": "#3A87C8",
    "pageTitleColor": "#E8E0CC", "categoryHeaderColor": "#4D9DE0", "textMuted": "#8E8E93",
    "textBoxBackground": "#2C2C2E", "textBoxForeground": "#D4CEBC", "textBoxBorder": "#48484A",
    "dangerColor": "#C0392B", "dangerHover": "#962D22",
    "selectedBorder": "#4D9DE0", "selectedBackground": "#162840",
    "hoverBackground": "#262628", "secondaryBackground": "#242426", "secondaryHover": "#262628"
  },
  "light": {
    "windowBackground": "#F4F8FC", "headerBackground": "#FFFFFF", "headerBorder": "#C4D9ED",
    "footerBackground": "#FFFFFF", "footerBorder": "#C4D9ED",
    "cardBackground": "#FFFFFF", "cardForeground": "#1A2733", "cardBorder": "#BDD3E8",
    "accentColor": "#4D9DE0", "accentHover": "#3A87C8",
    "pageTitleColor": "#1A2733", "categoryHeaderColor": "#4D9DE0", "textMuted": "#7A96AE",
    "textBoxBackground": "#FFFFFF", "textBoxForeground": "#1A2733", "textBoxBorder": "#BDD3E8",
    "dangerColor": "#C0392B", "dangerHover": "#962D22",
    "selectedBorder": "#4D9DE0", "selectedBackground": "#E0EEFA",
    "hoverBackground": "#EBF3FA", "secondaryBackground": "#FFFFFF", "secondaryHover": "#EBF3FA"
  }
}

'@ | ConvertFrom-Json
$script:embedded_meta = @'
{
  "version": "2.3"
}

'@ | ConvertFrom-Json
$script:embedded_apps = @'
{
  "Browsers": {
    "brave": { "content": "Brave", "winget": "Brave.Brave", "description": "Privacy-first browser with built-in ad blocker" },
    "firefox": { "content": "Firefox", "winget": "Mozilla.Firefox", "description": "Privacy-focused web browser" },
    "tor": { "content": "Tor Browser", "winget": "TorProject.TorBrowser", "description": "Anonymous web browsing via Tor network" }
  },
  "Security & Privacy": {
    "mullvad": { "content": "Mullvad VPN", "winget": "Mullvad.MullvadVPN", "description": "Privacy-focused VPN service" },
    "protonvpn": { "content": "ProtonVPN", "winget": "Proton.ProtonVPN", "description": "Secure VPN with no-logs policy" },
    "malwarebytes": { "content": "Malwarebytes", "winget": "Malwarebytes.Malwarebytes", "description": "On-demand malware scanner and remover" },
    "veracrypt": { "content": "VeraCrypt", "winget": "IDRIX.VeraCrypt", "description": "Disk encryption software for files and partitions" }
  },
  "Development": {
    "vscode": { "content": "VS Code", "winget": "Microsoft.VisualStudioCode", "description": "Lightweight source code editor" },
    "github_desktop": { "content": "GitHub Desktop", "winget": "GitHub.GitHubDesktop", "description": "GUI for Git and GitHub" },
    "docker": { "content": "Docker Desktop", "winget": "Docker.DockerDesktop", "description": "Container platform for dev and test" },
    "dbeaver": { "content": "DBeaver", "winget": "DBeaver.DBeaver", "description": "Universal database manager" },
    "bruno": { "content": "Bruno", "winget": "Bruno.Bruno", "description": "Offline-first API testing client" },
    "git": { "content": "Git", "winget": "Git.Git", "description": "Distributed version control system" },
    "nodejs": { "content": "Node.js LTS", "winget": "OpenJS.NodeJS.LTS", "description": "JavaScript runtime built on Chrome's V8 engine" },
    "python": { "content": "Python 3.12", "winget": "Python.Python.3.12", "description": "High-level programming language" },
    "windows_terminal": { "content": "Windows Terminal", "winget": "Microsoft.WindowsTerminal", "description": "Modern terminal application for Windows" },
    "powershell": { "content": "PowerShell 7", "winget": "Microsoft.PowerShell", "description": "Cross-platform shell and scripting language" },
    "ohmyposh": { "content": "Oh My Posh", "winget": "JanDeDobbeleer.OhMyPosh", "description": "Prompt theme engine for any shell" }
  },
  "Media & Creative": {
    "gimp": { "content": "GIMP", "winget": "GIMP.GIMP", "description": "Free and open-source image editor" },
    "krita": { "content": "Krita", "winget": "Krita.Krita", "description": "Professional digital painting tool" },
    "inkscape": { "content": "Inkscape", "winget": "Inkscape.Inkscape", "description": "Vector graphics editor" },
    "kdenlive": { "content": "Kdenlive", "winget": "KDE.Kdenlive", "description": "Free and open-source video editor" },
    "obs": { "content": "OBS Studio", "winget": "OBSProject.OBSStudio", "description": "Video recording and live streaming software" },
    "audacity": { "content": "Audacity", "winget": "Audacity.Audacity", "description": "Multi-track audio recorder and editor" },
    "mpchc": { "content": "MPC-HC", "winget": "clsid2.mpc-hc", "description": "Lightweight media player" },
    "vlc": { "content": "VLC", "winget": "VideoLAN.VLC", "description": "Free and open source multimedia player" },
    "foobar2000": { "content": "foobar2000", "winget": "PeterPawlowski.foobar2000", "description": "Advanced audio player" },
    "ytdlp": { "content": "yt-dlp", "winget": "yt-dlp.yt-dlp", "description": "Command-line video downloader" },
    "sharex": { "content": "ShareX", "winget": "ShareX.ShareX", "description": "Screen capture and file sharing tool" }
  },
  "Utilities": {
    "powertoys": { "content": "PowerToys", "winget": "Microsoft.PowerToys", "description": "System utilities: FancyZones, PowerRename, Run, etc." },
    "everything": { "content": "Everything", "winget": "voidtools.Everything", "description": "Lightning-fast file search engine" },
    "ditto": { "content": "Ditto", "winget": "Ditto.Ditto", "description": "Clipboard manager with search history" },
    "hwinfo": { "content": "HWiNFO64", "winget": "REALiX.HWiNFO", "description": "Comprehensive hardware monitoring tool" },
    "syncthing": { "content": "Syncthing", "winget": "Syncthing.Syncthing", "description": "P2P file sync between devices" },
    "7zip_zs": { "content": "7-Zip ZS", "winget": "mcmilk.7zip-zstd", "description": "File archiver with Zstandard support" },
    "revo": { "content": "Revo Uninstaller", "winget": "RevoUninstaller.RevoUninstaller", "description": "Advanced uninstaller tool" },
    "bitwarden": { "content": "Bitwarden", "winget": "Bitwarden.Bitwarden", "description": "Open source password manager" },
    "motrix": { "content": "Motrix", "winget": "Motrix.Motrix", "description": "Full-featured download manager" },
    "mobaxterm": { "content": "MobaXterm", "winget": "Mobatek.MobaXterm", "description": "Enhanced terminal with X11 server" }
  },
  "Productivity": {
    "obsidian": { "content": "Obsidian", "winget": "Obsidian.Obsidian", "description": "Local-first note-taking app with Markdown" },
    "sumatra": { "content": "Sumatra PDF", "winget": "SumatraPDF.SumatraPDF", "description": "Lightweight PDF and ebook reader" },
    "notion": { "content": "Notion", "winget": "Notion.Notion", "description": "All-in-one workspace for notes and tasks" }
  }
}

'@ | ConvertFrom-Json
$script:embedded_preferences = @'
{
  "bsod_verbose": { "content": "BSoD Verbose Mode", "description": "Show detailed error on Blue Screen of Death.", "registry_on": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\CrashControl","name":"DisplayParameters","value":1}], "registry_off": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\CrashControl","name":"DisplayParameters","value":0}] },
  "login_acrylic": { "content": "Logon Screen Acrylic Blur", "description": "Enable acrylic blur on login screen.", "registry_on": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"DisableAcrylicBackgroundOnLogon","value":0}], "registry_off": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"DisableAcrylicBackgroundOnLogon","value":1}] },
  "login_verbose": { "content": "Logon Verbose Mode", "description": "Display detailed startup/shutdown messages.", "registry_on": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System","name":"VerboseStatus","value":1}], "registry_off": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System","name":"VerboseStatus","value":0}] },
  "mouse_acceleration": { "content": "Mouse Acceleration", "description": "Toggle mouse pointer precision.", "registry_on": [{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseSpeed","value":"1"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold1","value":"6"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold2","value":"10"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseSpeed","value":"0"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold1","value":"0"},{"path":"HKCU:\\Control Panel\\Mouse","name":"MouseThreshold2","value":"0"}] },
  "numlock_on": { "content": "Num Lock on Startup", "description": "Enable Num Lock automatically at startup.", "registry_on": [{"path":"HKCU:\\Control Panel\\Keyboard","name":"InitialKeyboardIndicators","value":"2"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Keyboard","name":"InitialKeyboardIndicators","value":"0"}] },
  "scrollbars_visible": { "content": "Scrollbars Always Visible", "description": "Force scrollbars to always be visible.", "registry_on": [{"path":"HKCU:\\Control Panel\\Accessibility","name":"DynamicScrollbars","value":"0"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Accessibility","name":"DynamicScrollbars","value":"1"}] },
  "bing_search": { "content": "Start Menu Bing Search", "description": "Disable Bing search suggestions.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"DisableSearchBoxSuggestions","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"DisableSearchBoxSuggestions","value":0}] },
  "start_recommendations": { "content": "Start Menu Recommendations", "description": "Hide recommended section in Start menu.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"HideRecommendedSection","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer","name":"HideRecommendedSection","value":0}] },
  "sticky_keys": { "content": "Sticky Keys", "description": "Disable Sticky Keys accessibility feature.", "registry_on": [{"path":"HKCU:\\Control Panel\\Accessibility\\StickyKeys","name":"Flags","value":"506"}], "registry_off": [{"path":"HKCU:\\Control Panel\\Accessibility\\StickyKeys","name":"Flags","value":"510"}] },
  "taskbar_center": { "content": "Taskbar Centered Icons", "description": "Center taskbar icons (Windows 11 style).", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"TaskbarAl","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"TaskbarAl","value":0}] },
  "taskbar_search": { "content": "Taskbar Search Icon", "description": "Show search icon only on taskbar.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Search","name":"SearchboxTaskbarMode","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Search","name":"SearchboxTaskbarMode","value":0}] },
  "taskbar_taskview": { "content": "Taskbar Task View Icon", "description": "Show/hide Task View button.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowTaskViewButton","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowTaskViewButton","value":0}] },
  "cross_device": { "content": "Cross-Device Resume", "description": "Allow cross-device activity sync.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CDP","name":"RomeSdk","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CDP","name":"RomeSdk","value":0}] },
  "dark_theme": { "content": "Dark Theme for Windows", "description": "Enable Windows dark theme.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"AppsUseLightTheme","value":0},{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"SystemUsesLightTheme","value":0}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"AppsUseLightTheme","value":1},{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize","name":"SystemUsesLightTheme","value":1}] },
  "file_extensions": { "content": "File Explorer File Extensions", "description": "Show file extensions.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"HideFileExt","value":0}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"HideFileExt","value":1}] },
  "hidden_files": { "content": "File Explorer Hidden Files", "description": "Show hidden files and folders.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"Hidden","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"Hidden","value":2}] },
  "mpo": { "content": "Multiplane Overlay", "description": "Enable/disable MPO. Disabling can fix GPU issues.", "registry_on": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm","name":"OverlayTestMode","value":5}], "registry_off": [{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm","name":"OverlayTestMode","value":0}] },
  "s0_standby": { "content": "S0 Sleep Network Connectivity", "description": "Keep network connectivity during Modern Standby.", "registry_on": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power","name":"NetworkConnectivityInStandby","value":1}], "registry_off": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power","name":"NetworkConnectivityInStandby","value":0}] },
  "s3_sleep": { "content": "S3 Sleep", "description": "Enable traditional S3 sleep state.", "registry_on": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power","name":"PlatformAoAcOverride","value":0}], "registry_off": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power","name":"PlatformAoAcOverride","value":1}] },
  "battery_percent": { "content": "System Tray Battery Percentage", "description": "Show battery percentage in system tray.", "registry_on": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowBatteryPercentage","value":1}], "registry_off": [{"path":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"ShowBatteryPercentage","value":0}] }
}

'@ | ConvertFrom-Json
$script:embedded_tweaks = @'
{
  "Performance": {
    "disable_sysmain": { "content": "Disable SysMain (Superfetch)", "description": "Reduces disk usage and RAM consumption", "services": [{"name": "SysMain", "action": "stop_disable"}] },
    "disable_search_index": { "content": "Disable Search Indexing", "description": "Reduces CPU and disk usage from Windows Search", "services": [{"name": "WSearch", "action": "stop_disable"}] },
    "high_perf_power": { "content": "High Performance Power Plan", "description": "Sets power plan to high performance", "script": "powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" },
    "visual_perf": {
      "content": "Visual Effects - Set to Best Performance", "description": "Sets the system preferences to performance.",
      "registry": [
        {"path": "HKCU:\\Control Panel\\Desktop", "name": "DragFullWindows", "value": "0", "type": "String"},
        {"path": "HKCU:\\Control Panel\\Desktop", "name": "MenuShowDelay", "value": "200", "type": "String"},
        {"path": "HKCU:\\Control Panel\\Desktop\\WindowMetrics", "name": "MinAnimate", "value": "0", "type": "String"},
        {"path": "HKCU:\\Control Panel\\Keyboard", "name": "KeyboardDelay", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "ListviewAlphaSelect", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "ListviewShadow", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "TaskbarAnimations", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects", "name": "VisualFXSetting", "value": 3, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\DWM", "name": "EnableAeroPeek", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "TaskbarMn", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced", "name": "ShowTaskViewButton", "value": 0, "type": "DWord"},
        {"path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search", "name": "SearchboxTaskbarMode", "value": 0, "type": "DWord"}
      ],
      "script": "Set-ItemProperty -Path \"HKCU:\\Control Panel\\Desktop\" -Name \"UserPreferencesMask\" -Type Binary -Value ([byte[]](144,18,3,128,16,0,0,0))",
      "undoScript": "Remove-ItemProperty -Path \"HKCU:\\Control Panel\\Desktop\" -Name \"UserPreferencesMask\""
    }
  },
  "Privacy": {
    "disable_telemetry": { "content": "Disable Telemetry", "description": "Disables Windows telemetry and data collection", "registry": [{"path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection", "name": "AllowTelemetry", "value": 0, "type": "DWord"}] },
    "disable_activity_history": { "content": "Disable Activity History", "description": "Stops Windows from tracking your activity", "registry": [{"path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System", "name": "EnableActivityFeed", "value": 0, "type": "DWord"}] },
    "disable_location": { "content": "Disable Location Tracking", "description": "Disables location services", "registry": [{"path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\LocationAndSensors", "name": "DisableLocation", "value": 1, "type": "DWord"}] }
  },
  "Essential Tweaks": {
    "WPFTweaksActivity": { "content": "Activity History - Disable", "description": "Erases recent docs, clipboard, and run history.", "registry": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"EnableActivityFeed","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"PublishUserActivities","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"UploadUserActivities","value":0,"type":"DWord"}] },
    "WPFTweaksConsumerFeatures": { "content": "ConsumerFeatures - Disable", "description": "Disables automatic installation of games/third-party apps from Windows Store.", "registry": [{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent","name":"DisableWindowsConsumerFeatures","value":1,"type":"DWord"}] },
    "WPFTweaksDiskCleanup": { "content": "Disk Cleanup - Run", "description": "Runs Disk Cleanup on Drive C: and removes old Windows Updates.", "script": "cleanmgr.exe /d C: /VERYLOWDISK\nDism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase" },
    "WPFTweaksDisableExplorerAutoDiscovery": { "content": "File Explorer Automatic Folder Discovery - Disable", "description": "Windows Explorer automatically tries to guess the type of the folder based on its contents, slowing down browsing.", "script": "`$bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"\n`$bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"\nRemove-Item -Path `$bags -Recurse -Force\nRemove-Item -Path `$bagMRU -Recurse -Force\n`$allFolders = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\\AllFolders\\Shell\"\nif (!(Test-Path `$allFolders)) { New-Item -Path `$allFolders -Force }\nNew-ItemProperty -Path `$allFolders -Name \"FolderType\" -Value \"NotSpecified\" -PropertyType String -Force", "undoScript": "`$bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"\n`$bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"\nRemove-Item -Path `$bags -Recurse -Force\nRemove-Item -Path `$bagMRU -Recurse -Force" },
    "WPFTweaksLocation": { "content": "Location Tracking - Disable", "description": "Disables Location Tracking.", "services": [{"name":"lfsvc","action":"stop_disable"}], "registry": [{"path":"HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location","name":"Value","value":"Deny","type":"String"},{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Sensor\\Overrides\\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}","name":"SensorPermissionState","value":0,"type":"DWord"},{"path":"HKLM:\\SYSTEM\\Maps","name":"AutoUpdateEnabled","value":0,"type":"DWord"}] },
    "WPFTweaksServices": { "content": "Services - Set to Manual", "description": "Sets non-essential services to Manual startup.", "services": [{"name":"CscService","action":"stop_disable"},{"name":"DiagTrack","action":"stop_disable"},{"name":"MapsBroker","action":"set_manual"},{"name":"StorSvc","action":"set_manual"},{"name":"SharedAccess","action":"stop_disable"}], "script": "`$Memory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB\nSet-ItemProperty -Path \"HKLM:\\SYSTEM\\CurrentControlSet\\Control\" -Name SvcHostSplitThresholdInKB -Value `$Memory" },
    "WPFTweaksTelemetry": { "content": "Telemetry - Disable", "description": "Disables Microsoft Telemetry.", "registry": [{"path":"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo","name":"Enabled","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Privacy","name":"TailoredExperiencesWithDiagnosticDataEnabled","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Speech_OneCore\\Settings\\OnlineSpeechPrivacy","name":"HasAccepted","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Input\\TIPC","name":"Enabled","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\InputPersonalization","name":"RestrictImplicitInkCollection","value":1,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\InputPersonalization","name":"RestrictImplicitTextCollection","value":1,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\InputPersonalization\\TrainedDataStore","name":"HarvestContacts","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Personalization\\Settings","name":"AcceptedPrivacyPolicy","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\DataCollection","name":"AllowTelemetry","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced","name":"Start_TrackProgs","value":0,"type":"DWord"},{"path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System","name":"PublishUserActivities","value":0,"type":"DWord"},{"path":"HKCU:\\Software\\Microsoft\\Siuf\\Rules","name":"NumberOfSIUFInPeriod","value":0,"type":"DWord"}], "script": "Set-MpPreference -SubmitSamplesConsent 2\nSet-Service -Name diagtrack -StartupType Disabled\nSet-Service -Name wermgr -StartupType Disabled\nRemove-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Siuf\\Rules\" -Name PeriodInNanoSeconds", "undoScript": "Set-MpPreference -SubmitSamplesConsent 1\nSet-Service -Name diagtrack -StartupType Automatic\nSet-Service -Name wermgr -StartupType Automatic\nNew-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Siuf\\Rules\" -Name PeriodInNanoSeconds -Value 1 -PropertyType DWord" },
    "WPFTweaksDeleteTempFiles": { "content": "Temporary Files - Remove", "description": "Erases TEMP Folders.", "script": "Remove-Item -Path \"`$Env:Temp\\*\" -Recurse -Force\nRemove-Item -Path \"`$Env:SystemRoot\\Temp\\*\" -Recurse -Force" },
    "WPFTweaksDeBloat": { "content": "Unwanted Pre-Installed Apps - Remove", "description": "Removes Windows pre-installed applications.", "appx_packages": ["Microsoft.WindowsFeedbackHub","Microsoft.BingNews","Microsoft.BingSearch","Microsoft.BingWeather","Clipchamp.Clipchamp","Microsoft.Todos","Microsoft.PowerAutomateDesktop","Microsoft.MicrosoftSolitaireCollection","Microsoft.WindowsSoundRecorder","Microsoft.MicrosoftStickyNotes","Microsoft.Windows.DevHome","Microsoft.Paint","Microsoft.OutlookForWindows","Microsoft.WindowsAlarms","Microsoft.StartExperiencesApp","Microsoft.GetHelp","Microsoft.ZuneMusic","MicrosoftCorporationII.QuickAssist","MSTeams"], "script": "`$TeamsPath = \"`$Env:LocalAppData\\Microsoft\\Teams\\Update.exe\"\nif (Test-Path `$TeamsPath) { Start-Process `$TeamsPath -ArgumentList -uninstall -wait; Remove-Item `$TeamsPath -Recurse -Force }" },
    "WPFTweaksWidget": { "content": "Widgets - Remove", "description": "Removes taskbar widgets.", "script": "Get-Process *Widget* | Stop-Process\nGet-AppxPackage Microsoft.WidgetsPlatformRuntime -AllUsers | Remove-AppxPackage -AllUsers\nGet-AppxPackage MicrosoftWindows.Client.WebExperience -AllUsers | Remove-AppxPackage -AllUsers" },
    "WPFTweaksWPBT": { "content": "Windows Platform Binary Table (WPBT) - Disable", "description": "Prevents vendors from executing code at boot without consent.", "registry": [{"path":"HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager","name":"DisableWpbtExecution","value":1,"type":"DWord"}] }
  }
}

'@ | ConvertFrom-Json
$script:embedded_dns = @'
{
  "Default_DHCP": { "description": "Default DHCP (reset to auto)" },
  "Google": { "description": "Google Public DNS", "ipv4": ["8.8.8.8","8.8.4.4"], "ipv6": ["2001:4860:4860::8888","2001:4860:4860::8844"] },
  "Cloudflare": { "description": "Cloudflare DNS (1.1.1.1)", "ipv4": ["1.1.1.1","1.0.0.1"], "ipv6": ["2606:4700:4700::1111","2606:4700:4700::1001"] },
  "Cloudflare_Malware": { "description": "Cloudflare Malware Protection", "ipv4": ["1.1.1.2","1.0.0.2"], "ipv6": ["2606:4700:4700::1112","2606:4700:4700::1002"] },
  "Cloudflare_Malware_Adult": { "description": "Cloudflare Malware & Adult Protection", "ipv4": ["1.1.1.3","1.0.0.3"], "ipv6": ["2606:4700:4700::1113","2606:4700:4700::1003"] },
  "Open_DNS": { "description": "Cisco OpenDNS", "ipv4": ["208.67.222.222","208.67.220.220"], "ipv6": ["2620:119:35::35","2620:119:53::53"] },
  "Quad9": { "description": "Quad9 Security DNS", "ipv4": ["9.9.9.9","149.112.112.112"], "ipv6": ["2620:fe::fe","2620:fe::9"] },
  "AdGuard_Ads_Trackers": { "description": "AdGuard DNS (Ads & Trackers)", "ipv4": ["94.140.14.14","94.140.15.15"], "ipv6": ["2a10:50c0::ad1:ff","2a10:50c0::ad2:ff"] },
  "AdGuard_Ads_Trackers_Malware_Adult": { "description": "AdGuard DNS (Ads, Trackers, Malware, Adult)", "ipv4": ["94.140.14.15","94.140.15.16"], "ipv6": ["2a10:50c0::bad1:ff","2a10:50c0::bad2:ff"] }
}

'@ | ConvertFrom-Json
$script:metaConfig = if ($script:embedded_meta) { $script:embedded_meta } else { @{} }
$script:appsConfig = if ($script:embedded_apps) { $script:embedded_apps } else { @{} }
$script:tweaksConfig = if ($script:embedded_tweaks) { $script:embedded_tweaks } else { @{} }
$script:dnsConfig = if ($script:embedded_dns) { $script:embedded_dns } else { @{} }
$script:prefsConfig = if ($script:embedded_preferences) { $script:embedded_preferences } else { @{} }
$script:featuresConfig = if ($script:embedded_features) { $script:embedded_features } else { @{} }
$script:themesConfig = if ($script:embedded_themes) { $script:embedded_themes } else { @{} }
$script:embeddedXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
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
                <Setter Property="Padding" Value="8,6"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="180"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="CheckBox">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <TextBlock Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" HorizontalAlignment="Left" TextWrapping="Wrap" MaxWidth="500"/>
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
                <Setter Property="Padding" Value="8,6"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource textBoxBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="200"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="CheckBox">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center"/>
                                </StackPanel>
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
            <Style x:Key="PresetCard" TargetType="Button">
                <Setter Property="Margin" Value="8"/>
                <Setter Property="Padding" Value="15,12"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="180"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource hoverBackground}"/>
                                    <Setter Property="BorderBrush" Value="{DynamicResource accentColor}"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="FeatureCard" TargetType="Button">
                <Setter Property="Margin" Value="5"/>
                <Setter Property="Padding" Value="14,12"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="MinWidth" Value="280"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="TextBlock.FontSize" Value="13"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
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
            <Style x:Key="DnsCardStyle" TargetType="RadioButton">
                <Setter Property="Margin" Value="4,5"/>
                <Setter Property="Background" Value="{DynamicResource cardBackground}"/>
                <Setter Property="Foreground" Value="{DynamicResource cardForeground}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource cardBorder}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="HorizontalAlignment" Value="Stretch"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="RadioButton">
                            <Border x:Name="RootBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="10,8">
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
            <Style x:Key="ActionBtnOutline" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource accentColor}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource accentColor}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource accentColor}"/>
                                    <Setter Property="Foreground" Value="White"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style x:Key="DangerBtnOutline" TargetType="Button">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="{DynamicResource dangerColor}"/>
                <Setter Property="BorderBrush" Value="{DynamicResource dangerColor}"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="Padding" Value="16,10"/>
                <Setter Property="Margin" Value="4"/>
                <Setter Property="FontSize" Value="13"/>
                <Setter Property="Cursor" Value="Hand"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter Property="Background" Value="{DynamicResource dangerColor}"/>
                                    <Setter Property="Foreground" Value="White"/>
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
                    <TextBlock Text="v2.0" FontSize="10" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="6,2,0,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Grid.Column="1" Margin="24,0,0,0">
                    <Button x:Name="NavInstall" Content="Install" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavTweaks" Content="Tweaks" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavFeatures" Content="Features" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavPreferences" Content="Preferences" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavLegacy" Content="Legacy" Style="{StaticResource TopNavButtonStyle}"/>
                    <Button x:Name="NavSettings" Content="Settings" Style="{StaticResource TopNavButtonStyle}"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Grid.Column="2" Margin="0,0,12,0">
                    <Button x:Name="BtnToolbarTheme" Content="&#xE706;" Style="{StaticResource ToolbarIconBtn}" ToolTip="Toggle Theme"/>
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
                    <TextBlock x:Name="TitleInstall" Text="Install Applications" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescInstall" Text="Search and manage application installations via WinGet or Chocolatey." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="0" CornerRadius="8" Padding="16" Margin="0,0,0,15">
                        <StackPanel Orientation="Horizontal">
                            <Grid Width="260">
                                <TextBox x:Name="SearchBox" Padding="8,5" Background="{DynamicResource textBoxBackground}" Foreground="{DynamicResource textBoxForeground}" BorderBrush="{DynamicResource textBoxBorder}" BorderThickness="1"/>
                                <TextBlock x:Name="SearchHint" Text="Search apps..." Foreground="{DynamicResource textMuted}" Margin="8,5,0,0" IsHitTestVisible="False" Visibility="Visible"/>
                            </Grid>
                            <Button x:Name="BtnClearSearch" Content="X" Width="28" Height="28" Margin="5,0,0,0" Background="{DynamicResource hoverBackground}" Foreground="{DynamicResource textMuted}" BorderBrush="{DynamicResource textBoxBorder}" BorderThickness="1" FontSize="12" Cursor="Hand" FontWeight="Bold"/>
                            <CheckBox x:Name="ChkShowInstalled" Content="Installed" Foreground="{DynamicResource cardForeground}" Margin="10,0,0,0" VerticalAlignment="Center"/>
                            <TextBlock x:Name="LabelPkgMgr" Text="Package Manager" FontWeight="SemiBold" Foreground="{DynamicResource textMuted}" VerticalAlignment="Center" Margin="12,0,8,0"/>
                            <RadioButton x:Name="PkgWinGet" Content="WinGet" Foreground="{DynamicResource accentColor}" FontWeight="Bold" IsChecked="True" GroupName="PkgMgr" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <RadioButton x:Name="PkgChoco" Content="Choco" Foreground="{DynamicResource cardForeground}" FontWeight="SemiBold" GroupName="PkgMgr" VerticalAlignment="Center"/>
                        </StackPanel>
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
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="AppPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="AppPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="AppPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageTweaks" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleTweaks" Text="System Tweaks" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescTweaks" Text="Select tweaks to apply. You can undo them later." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="TweaksPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="TweaksPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="TweaksPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                    <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                        <Button x:Name="BtnRunTweaks" Content="Apply Selected Tweaks" Style="{StaticResource ActionBtn}"/>
                        <Button x:Name="BtnUndoTweaks" Content="Undo All Tweaks" Style="{StaticResource DangerBtn}"/>
                    </StackPanel>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageFeatures" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleFeatures" Text="Features &amp; Fixes" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescFeatures" Text="Enable Windows features and run system fixes." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <TextBlock x:Name="FeaturesSectionHeader" Text="Windows Features" Style="{StaticResource CategoryHeader}" Margin="0,0,0,10"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="FeaturesPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="FeaturesPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="FeaturesPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                    <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                        <Button x:Name="BtnRunFeatures" Content="Run Features" Style="{StaticResource ActionBtn}"/>
                    </StackPanel>
                    <TextBlock x:Name="FixesSectionHeader" Text="Fixes" Style="{StaticResource CategoryHeader}" Margin="0,25,0,10"/>
                    <Border Background="{DynamicResource cardBackground}" BorderBrush="{DynamicResource cardBorder}" BorderThickness="0" CornerRadius="8" Padding="16">
                        <WrapPanel x:Name="FixesWrapPanel"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PagePreferences" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitlePreferences" Text="Preferences" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescPreferences" Text="Toggle Windows settings and behavior preferences." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="PrefsPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="PrefsPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="PrefsPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
                </StackPanel>
            </ScrollViewer>
            <ScrollViewer x:Name="PageLegacy" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="20">
                    <TextBlock x:Name="TitleLegacy" Text="Legacy Windows Panels" FontSize="22" FontWeight="Bold" Foreground="{DynamicResource pageTitleColor}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="DescLegacy" Text="Quick access to classic Windows control panels and system tools." Foreground="{DynamicResource textMuted}" FontSize="12" Margin="0,0,0,20"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel x:Name="LegacyPanel1" Grid.Column="0" Margin="0,0,5,0"/>
                        <StackPanel x:Name="LegacyPanel2" Grid.Column="1" Margin="2.5,0"/>
                        <StackPanel x:Name="LegacyPanel3" Grid.Column="2" Margin="5,0,0,0"/>
                    </Grid>
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
                                    <Button x:Name="BtnTerminalDotfiles" Content="Install Nova Profile" Style="{StaticResource ActionBtn}" HorizontalAlignment="Left" Width="220"/>
                                    <Button x:Name="BtnUninstallTerminal" Content="Uninstall Nova Profile" Style="{StaticResource DangerBtn}" HorizontalAlignment="Left" Width="220"/>
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
if ($Verbose) { $script:logLevel = "Info" }
$script:appRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Show-HksUtilLogo
Write-Log "Starting HksUtil v$script:hksVersion..." "Header"

if ($Export) {
    $sel = @{ CheckedApps = @(); CheckedTweaks = @() }
    try {
        $selJson = $sel | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($Export, $selJson, [System.Text.UTF8Encoding]::new($false))
        Write-Log "Exported to $Export" "Success"
    } catch { Write-Log "Export failed: $_" "Error" }
}

if ($NoUI) {
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
                    }
                }
            Write-Log "Headless apply complete." "Success"
        } catch { Write-Log "Headless apply failed: $_" "Error" }
    } else { Write-Log "NoUI mode: use -Config <path> -Apply to apply." "Warn" }
    pause; exit
}

try {
    $xamlContent = $script:embeddedXaml -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }

$controls = @{}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { $controls[$_.Name] = $window.FindName($_.Name) }
foreach ($k in @($controls.Keys)) { if (-not $controls[$k]) { $controls.Remove($k) } }

Apply-Theme "dark"
if ($controls["TitleText"]) { $controls["TitleText"].Add_MouseLeftButtonDown({ $window.DragMove() }) }

$script:__modOrder = @("logger","core","theme","navigation","tweaks","search","toolbar","dns","terminal","utility","build","install","features")
foreach ($_m in $script:__modOrder) {
    $_var = "__mod_$_m"
    $_code = Get-Variable $_var -ValueOnly -ErrorAction SilentlyContinue
    if ($_code) { . ([ScriptBlock]::Create($_code)) }
}

if ($controls["BtnClearSearch"]) { $controls["BtnClearSearch"].Add_Click({ if ($controls["SearchBox"]) { $controls["SearchBox"].Text = ""; $controls["SearchBox"].Focus() } }) }
if ($controls["BtnSelectAll"]) { $controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" }) }
if ($controls["BtnClearSelection"]) { $controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" }) }
if ($controls["BtnCollapseAll"]) {
    $controls["BtnCollapseAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $true; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Collapsed" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($controls["BtnExpandAll"]) {
    $controls["BtnExpandAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Visible" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($controls["ChkShowInstalled"]) {
    $controls["ChkShowInstalled"].Add_Checked({ Write-Log "Filtering to installed apps..." "Info"; if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }; Apply-Filters })
    $controls["ChkShowInstalled"].Add_Unchecked({ Apply-Filters })
}

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
            if ($importJson.PreferenceStates) { foreach ($pk in $importJson.PreferenceStates.PSObject.Properties.Name) { if ($prefCheckboxes[$pk]) { $prefCheckboxes[$pk].IsChecked = $importJson.PreferenceStates.$pk -eq $true } } }
            Update-SelectedCount; Write-Log "Config loaded from $Config" "Success"
        }
    } catch { Write-Log "Config load failed: $_" "Error" }
}

try { $window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"