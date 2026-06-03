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
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }
    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
    } else {
        Start-Process $powershellCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$scriptCmd`"" -Verb RunAs
    }
    exit
}

$sync = [Hashtable]::Synchronized(@{})
$sync.version = "26.06.03"
$sync.noUI = $Noui
$sync.configs = @{}
$sync.controls = @{}
$sync.ProcessRunning = $false
$sync.selectedApps = [System.Collections.Generic.List[string]]::new()
$sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
$sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()

$maxthreads = [int]$env:NUMBER_OF_PROCESSORS
$hashVars = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'sync', $sync, $null
$initialState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$initialState.Variables.Add($hashVars)
$sync.runspace = [runspacefactory]::CreateRunspacePool(1, $maxthreads, $initialState, $Host)
$sync.runspace.Open()

$script:__fn_Invoke_WPFRunspace = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZnVuY3Rpb24gSW52b2tlLVdQRlJ1bnNwYWNlIHsKICAgIHBhcmFtKAogICAgICAgIFtzY3JpcHRibG9ja10kU2NyaXB0QmxvY2ssCiAgICAgICAgW2FycmF5XSRBcmd1bWVudExpc3QsCiAgICAgICAgW2FycmF5XSRQYXJhbWV0ZXJMaXN0CiAgICApCgogICAgJHBzID0gW3Bvd2Vyc2hlbGxdOjpDcmVhdGUoKQogICAgJHBzLkFkZFNjcmlwdCgkU2NyaXB0QmxvY2spCiAgICBpZiAoJEFyZ3VtZW50TGlzdCkgeyAkcHMuQWRkQXJndW1lbnQoJEFyZ3VtZW50TGlzdCkgfQogICAgZm9yZWFjaCAoJHBhcmFtIGluICRQYXJhbWV0ZXJMaXN0KSB7CiAgICAgICAgJHBzLkFkZFBhcmFtZXRlcigkcGFyYW1bMF0sICRwYXJhbVsxXSkKICAgIH0KICAgICRwcy5SdW5zcGFjZVBvb2wgPSAkc3luYy5ydW5zcGFjZQoKICAgICRoYW5kbGUgPSAkcHMuQmVnaW5JbnZva2UoKQogICAgaWYgKCRoYW5kbGUuSXNDb21wbGV0ZWQpIHsKICAgICAgICAkcHMuRW5kSW52b2tlKCRoYW5kbGUpCiAgICAgICAgJHBzLkRpc3Bvc2UoKQogICAgfQogICAgcmV0dXJuICRoYW5kbGUKfQo='))
function Invoke-WPFRunspace {
    param(
        [scriptblock]$ScriptBlock,
        [array]$ArgumentList,
        [array]$ParameterList
    )

    $ps = [powershell]::Create()
    $ps.AddScript($ScriptBlock)
    if ($ArgumentList) { $ps.AddArgument($ArgumentList) }
    foreach ($param in $ParameterList) {
        $ps.AddParameter($param[0], $param[1])
    }
    $ps.RunspacePool = $sync.runspace

    $handle = $ps.BeginInvoke()
    if ($handle.IsCompleted) {
        $ps.EndInvoke($handle)
        $ps.Dispose()
    }
    return $handle
}

$script:__fn_Invoke_WPFUIThread = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZnVuY3Rpb24gSW52b2tlLVdQRlVJVGhyZWFkIHsKICAgIHBhcmFtKFtzY3JpcHRibG9ja10kU2NyaXB0QmxvY2spCgogICAgaWYgKCRzeW5jLm5vVUkpIHsgcmV0dXJuIH0KICAgICRzeW5jLndpbmRvdy5EaXNwYXRjaGVyLkludm9rZShbYWN0aW9uXSRTY3JpcHRCbG9jaykKfQo='))
function Invoke-WPFUIThread {
    param([scriptblock]$ScriptBlock)

    if ($sync.noUI) { return }
    $sync.window.Dispatcher.Invoke([action]$ScriptBlock)
}

$script:__mod_logger = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHN5bmMubG9nTGV2ZWwgPSAiU3VjY2VzcyIKCmZ1bmN0aW9uIFNob3ctSGtzVXRpbExvZ28gewogICAgV3JpdGUtSG9zdCBAIgpISCAgIEhIIEtLICAgS0sgIFNTU1NTUyAgVVUgICBVVSBUVFRUVFQgSUlJSUlJIExMCkhIICAgSEggS0sgIEtLICBTUyAgICAgICBVVSAgIFVVICAgVFQgICAgIElJICAgTEwKSEhISEhISCBLS0tLSyAgICBTU1NTU1MgIFVVICAgVVUgICBUVCAgICAgSUkgICBMTApISCAgIEhIIEtLICBLSyAgICAgICBTUyAgVVUgICBVVSAgIFRUICAgICBJSSAgIExMCkhIICAgSEggS0sgICBLSyAgU1NTU1NTICAgVVVVVVUgICAgVFQgICBJSUlJSUkgTExMTAoiQCAtRm9yZWdyb3VuZENvbG9yIEN5YW4KICAgIFdyaXRlLUhvc3QgIiAgPT09PT09PT09PT09PT09PT09PT09PT09IiAtRm9yZWdyb3VuZENvbG9yIEN5YW4KICAgIFdyaXRlLUhvc3QgIiAgICBIa3NVdGlsIHYyLjAiIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbgogICAgV3JpdGUtSG9zdCAiICAgIFdpbmRvd3MgT3B0aW1pemVyIiAtRm9yZWdyb3VuZENvbG9yIEN5YW4KICAgIFdyaXRlLUhvc3QgIiAgPT09PT09PT09PT09PT09PT09PT09PT09IiAtRm9yZWdyb3VuZENvbG9yIEN5YW4KfQoKZnVuY3Rpb24gV3JpdGUtTG9nIHsKICAgIHBhcmFtKFtzdHJpbmddJE1lc3NhZ2UsIFtzdHJpbmddJFR5cGUgPSAiSW5mbyIpCiAgICBpZiAoJFR5cGUgLWVxICJIZWFkZXIiKSB7CiAgICAgICAgV3JpdGUtSG9zdCAiYG4gICRNZXNzYWdlIiAtRm9yZWdyb3VuZENvbG9yIEN5YW4KICAgICAgICBpZiAoJHNjcmlwdDpsb2dMaW5lcykgeyAkc2NyaXB0OmxvZ0xpbmVzLkFkZCgiICAkTWVzc2FnZSIpIH0KICAgICAgICByZXR1cm4KICAgIH0KICAgICRsZXZlbCA9IHN3aXRjaCAoJFR5cGUpIHsKICAgICAgICAiSW5mbyIgICAgeyAiSU5GTyIgfQogICAgICAgICJTdWNjZXNzIiB7ICJPSyIgfQogICAgICAgICJFcnJvciIgICB7ICJGQUlMIiB9CiAgICAgICAgIldhcm4iICAgIHsgIldBUk4iIH0KICAgICAgICAiQ21kIiAgICAgeyAiPiIgfQogICAgfQogICAgJGNvbG9yID0gc3dpdGNoICgkVHlwZSkgewogICAgICAgICJJbmZvIiAgICB7ICJEYXJrR3JheSIgfQogICAgICAgICJTdWNjZXNzIiB7ICJHcmVlbiIgfQogICAgICAgICJFcnJvciIgICB7ICJSZWQiIH0KICAgICAgICAiV2FybiIgICAgeyAiWWVsbG93IiB9CiAgICAgICAgIkNtZCIgICAgIHsgIkN5YW4iIH0KICAgIH0KICAgIGlmICgkc2NyaXB0OmxvZ0xpbmVzKSB7ICRzY3JpcHQ6bG9nTGluZXMuQWRkKCIkbGV2ZWwgJE1lc3NhZ2UiKSB9CiAgICBpZiAoJFR5cGUgLWVxICJJbmZvIiAtYW5kICRzeW5jLmxvZ0xldmVsIC1uZSAiSW5mbyIpIHsgcmV0dXJuIH0KICAgIFdyaXRlLUhvc3QgKCIgIHswLC01fSB7MX0iIC1mICRsZXZlbCwgJE1lc3NhZ2UpIC1Gb3JlZ3JvdW5kQ29sb3IgJGNvbG9yCn0KCmZ1bmN0aW9uIFNob3ctQ29uZmlybSB7CiAgICBwYXJhbShbc3RyaW5nXSRUaXRsZSwgW3N0cmluZ10kTWVzc2FnZSkKICAgICRyZXN1bHQgPSBbU3lzdGVtLldpbmRvd3MuTWVzc2FnZUJveF06OlNob3coJE1lc3NhZ2UsICRUaXRsZSwgW1N5c3RlbS5XaW5kb3dzLk1lc3NhZ2VCb3hCdXR0b25dOjpZZXNObywgW1N5c3RlbS5XaW5kb3dzLk1lc3NhZ2VCb3hJbWFnZV06OlF1ZXN0aW9uKQogICAgcmV0dXJuICRyZXN1bHQgLWVxIFtTeXN0ZW0uV2luZG93cy5NZXNzYWdlQm94UmVzdWx0XTo6WWVzCn0KCmZ1bmN0aW9uIFNob3ctSW5mbyB7CiAgICBwYXJhbShbc3RyaW5nXSRUaXRsZSwgW3N0cmluZ10kTWVzc2FnZSkKICAgIFtTeXN0ZW0uV2luZG93cy5NZXNzYWdlQm94XTo6U2hvdygkTWVzc2FnZSwgJFRpdGxlLCBbU3lzdGVtLldpbmRvd3MuTWVzc2FnZUJveEJ1dHRvbl06Ok9LLCBbU3lzdGVtLldpbmRvd3MuTWVzc2FnZUJveEltYWdlXTo6SW5mb3JtYXRpb24pIHwgT3V0LU51bGwKfQoKZnVuY3Rpb24gU2V0LVN0YXR1cyB7CiAgICBwYXJhbShbc3RyaW5nXSRUZXh0KQogICAgaWYgKCRzeW5jLmNvbnRyb2xzWyJTdGF0dXNUZXh0Il0pIHsgJHN5bmMuY29udHJvbHNbIlN0YXR1c1RleHQiXS5UZXh0ID0gJFRleHQgfQp9CgpmdW5jdGlvbiBVcGRhdGUtU2VsZWN0ZWRDb3VudCB7CiAgICAkY291bnQgPSAoJGFwcENoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0pLkNvdW50CiAgICBpZiAoJHN5bmMuY29udHJvbHNbIkxibFNlbGVjdGVkQ291bnQiXSkgeyAkc3luYy5jb250cm9sc1siTGJsU2VsZWN0ZWRDb3VudCJdLlRleHQgPSAiU2VsZWN0ZWQgQXBwczogJGNvdW50IiB9Cn0K'))
$sync.logLevel = "Success"

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
    if ($Type -eq "Info" -and $sync.logLevel -ne "Info") { return }
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
    if ($sync.controls["StatusText"]) { $sync.controls["StatusText"].Text = $Text }
}

function Update-SelectedCount {
    $count = ($appCheckboxes | Where-Object { $_.IsChecked -eq $true }).Count
    if ($sync.controls["LblSelectedCount"]) { $sync.controls["LblSelectedCount"].Text = "Selected Apps: $count" }
}

$script:__mod_core = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDppbnN0YWxsZWRBcHBJZHMgPSBAe30KCiRzeW5jLnZlcnNpb24gPSAiMi4wIgokc3luYy5jb25maWdzID0gQHt9CiRzeW5jLlByb2Nlc3NSdW5uaW5nID0gJGZhbHNlCiRzeW5jLnNlbGVjdGVkQXBwcyA9IFtTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ11dOjpuZXcoKQokc3luYy5zZWxlY3RlZFR3ZWFrcyA9IFtTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ11dOjpuZXcoKQokc3luYy5zZWxlY3RlZEZlYXR1cmVzID0gW1N5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXV06Om5ldygpCiRzeW5jLmN1cnJlbnRUYWIgPSAiSW5zdGFsbCIKCiRzY3JpcHQ6bG9nTGluZXMgPSBbU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddXTo6bmV3KCkKCmZ1bmN0aW9uIEdldC1XcGZSZXNvdXJjZSB7IHBhcmFtKCRLZXkpIHRyeSB7ICRzeW5jLndpbmRvdy5GaW5kUmVzb3VyY2UoJEtleSkgfSBjYXRjaCB7IFdyaXRlLUxvZyAiTWlzc2luZyBzdHlsZTogJEtleSIgIldhcm4iOyAkbnVsbCB9IH0KCmZ1bmN0aW9uIEludm9rZS1XUEZVSVRocmVhZCB7CiAgICBwYXJhbShbU2NyaXB0QmxvY2tdJFNjcmlwdEJsb2NrKQogICAgaWYgKCRzeW5jLndpbmRvdyAtYW5kICRzeW5jLndpbmRvdy5EaXNwYXRjaGVyIC1hbmQgISRzeW5jLndpbmRvdy5EaXNwYXRjaGVyLkNoZWNrQWNjZXNzKCkpIHsKICAgICAgICAkc3luYy53aW5kb3cuRGlzcGF0Y2hlci5JbnZva2UoW0FjdGlvbl17ICYgJFNjcmlwdEJsb2NrIH0sICJOb3JtYWwiKQogICAgfSBlbHNlIHsKICAgICAgICAmICRTY3JpcHRCbG9jawogICAgfQp9CgpmdW5jdGlvbiBTaG93LVByb2dyZXNzIHsKICAgIHBhcmFtKFtzdHJpbmddJFRleHQsIFtzdHJpbmddJFN1YlRleHQgPSAiIiwgW2RvdWJsZV0kVmFsdWUgPSAtMSkKICAgIGlmICgkc3luYy5ub1VJKSB7IFdyaXRlLUxvZyAiWyRUZXh0XSAkU3ViVGV4dCIgIkluZm8iOyByZXR1cm4gfQogICAgaWYgKCRzeW5jLmNvbnRyb2xzWyJQcm9ncmVzc092ZXJsYXkiXSkgewogICAgICAgIEludm9rZS1XUEZVSVRocmVhZCB7CiAgICAgICAgICAgIGlmICgkc3luYy5jb250cm9sc1siUHJvZ3Jlc3NUZXh0Il0pIHsgJHN5bmMuY29udHJvbHNbIlByb2dyZXNzVGV4dCJdLlRleHQgPSAkVGV4dCB9CiAgICAgICAgICAgIGlmICgkc3luYy5jb250cm9sc1siUHJvZ3Jlc3NTdWJUZXh0Il0pIHsgJHN5bmMuY29udHJvbHNbIlByb2dyZXNzU3ViVGV4dCJdLlRleHQgPSAkU3ViVGV4dCB9CiAgICAgICAgICAgIGlmICgkc3luYy5jb250cm9sc1siUHJvZ3Jlc3NCYXIiXSkgewogICAgICAgICAgICAgICAgaWYgKCRWYWx1ZSAtZ2UgMCkgeyAkc3luYy5jb250cm9sc1siUHJvZ3Jlc3NCYXIiXS5WYWx1ZSA9ICRWYWx1ZTsgJHN5bmMuY29udHJvbHNbIlByb2dyZXNzQmFyIl0uSXNJbmRldGVybWluYXRlID0gJGZhbHNlIH0KICAgICAgICAgICAgICAgIGVsc2UgeyAkc3luYy5jb250cm9sc1siUHJvZ3Jlc3NCYXIiXS5Jc0luZGV0ZXJtaW5hdGUgPSAkdHJ1ZSB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRzeW5jLmNvbnRyb2xzWyJQcm9ncmVzc092ZXJsYXkiXSkgeyAkc3luYy5jb250cm9sc1siUHJvZ3Jlc3NPdmVybGF5Il0uVmlzaWJpbGl0eSA9ICJWaXNpYmxlIiB9CiAgICAgICAgfQogICAgfQogICAgaWYgKC1ub3QgJHN5bmMubm9VSSkgeyBTZXQtUHJvZ3Jlc3NUYXNrYmFyIC1zdGF0ZSAiTm9ybWFsIiAtdmFsdWUgKFttYXRoXTo6TWF4KDAuMDEsICRWYWx1ZSkpIH0KfQoKZnVuY3Rpb24gSGlkZS1Qcm9ncmVzcyB7CiAgICBpZiAoJHN5bmMubm9VSSkgeyByZXR1cm4gfQogICAgaWYgKCRzeW5jLmNvbnRyb2xzWyJQcm9ncmVzc092ZXJsYXkiXSkgewogICAgICAgIEludm9rZS1XUEZVSVRocmVhZCB7ICRzeW5jLmNvbnRyb2xzWyJQcm9ncmVzc092ZXJsYXkiXS5WaXNpYmlsaXR5ID0gIkNvbGxhcHNlZCIgfQogICAgfQogICAgU2V0LVByb2dyZXNzVGFza2JhciAtc3RhdGUgIk5vbmUiCn0KCmZ1bmN0aW9uIFNldC1Qcm9ncmVzc1Rhc2tiYXIgewogICAgcGFyYW0oW3N0cmluZ10kc3RhdGUgPSAiTm9uZSIsIFtkb3VibGVdJHZhbHVlID0gMCkKICAgIGlmICgkc3luYy5ub1VJKSB7IHJldHVybiB9CiAgICB0cnkgewogICAgICAgIGlmICgtbm90ICRzeW5jLndpbmRvdykgeyByZXR1cm4gfQogICAgICAgICR0YXNrYmFyID0gJHN5bmMud2luZG93LlRhc2tiYXJJdGVtSW5mbwogICAgICAgIGlmICgtbm90ICR0YXNrYmFyKSB7CiAgICAgICAgICAgICR0YXNrYmFyID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5TaGVsbC5UYXNrYmFySXRlbUluZm8KICAgICAgICAgICAgJHN5bmMud2luZG93LlRhc2tiYXJJdGVtSW5mbyA9ICR0YXNrYmFyCiAgICAgICAgfQogICAgICAgIHN3aXRjaCAoJHN0YXRlKSB7CiAgICAgICAgICAgICJOb25lIiB7ICR0YXNrYmFyLlByb2dyZXNzU3RhdGUgPSBbU3lzdGVtLldpbmRvd3MuU2hlbGwuVGFza2Jhckl0ZW1Qcm9ncmVzc1N0YXRlXTo6Tm9uZSB9CiAgICAgICAgICAgICJOb3JtYWwiIHsgJHRhc2tiYXIuUHJvZ3Jlc3NTdGF0ZSA9IFtTeXN0ZW0uV2luZG93cy5TaGVsbC5UYXNrYmFySXRlbVByb2dyZXNzU3RhdGVdOjpOb3JtYWw7ICR0YXNrYmFyLlByb2dyZXNzVmFsdWUgPSAkdmFsdWUgfQogICAgICAgICAgICAiRXJyb3IiIHsgJHRhc2tiYXIuUHJvZ3Jlc3NTdGF0ZSA9IFtTeXN0ZW0uV2luZG93cy5TaGVsbC5UYXNrYmFySXRlbVByb2dyZXNzU3RhdGVdOjpFcnJvciB9CiAgICAgICAgICAgICJJbmRldGVybWluYXRlIiB7ICR0YXNrYmFyLlByb2dyZXNzU3RhdGUgPSBbU3lzdGVtLldpbmRvd3MuU2hlbGwuVGFza2Jhckl0ZW1Qcm9ncmVzc1N0YXRlXTo6SW5kZXRlcm1pbmF0ZSB9CiAgICAgICAgfQogICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiVGFza2JhciBwcm9ncmVzcyBmYWlsZWQ6ICRfIiAiV2FybiIgfQp9CgpmdW5jdGlvbiBVcGRhdGUtSW5zdGFsbGVkQ2FjaGUgewogICAgV3JpdGUtTG9nICJVcGRhdGluZyBpbnN0YWxsZWQgYXBwcyBjYWNoZS4uLiIgIkluZm8iCiAgICAkc2NyaXB0Omluc3RhbGxlZEFwcElkcyA9IEB7fQogICAgaWYgKC1ub3QgKEdldC1Db21tYW5kIHdpbmdldCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsgV3JpdGUtTG9nICJ3aW5nZXQgbm90IGF2YWlsYWJsZS4iICJXYXJuIjsgcmV0dXJuIH0KICAgIHRyeSB7CiAgICAgICAgJGxpbmVzID0gd2luZ2V0IGxpc3QgLS1hY2NlcHQtc291cmNlLWFncmVlbWVudHMgMj4mMSB8IFdoZXJlLU9iamVjdCB7ICRfIC1tYXRjaCAnXltcd1wtXC5dK1xzKycgfQogICAgICAgICRpbnN0YWxsZWRJZHMgPSBAe30KICAgICAgICBmb3JlYWNoICgkbGluZSBpbiAkbGluZXMpIHsKICAgICAgICAgICAgaWYgKCRsaW5lIC1tYXRjaCAnXihbXHdcLVwuXSspXHMrJykgeyAkaW5zdGFsbGVkSWRzWyRtYXRjaGVzWzFdLlRvTG93ZXIoKV0gPSAkdHJ1ZSB9CiAgICAgICAgfQogICAgICAgIGZvcmVhY2ggKCRjYXQgaW4gJHN5bmMuY29uZmlncy5hcHBzLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICAgICBmb3JlYWNoICgkYXBwS2V5IGluICRzeW5jLmNvbmZpZ3MuYXBwcy4kY2F0LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICAgICAgICAgJGlkID0gJHN5bmMuY29uZmlncy5hcHBzLiRjYXQuJGFwcEtleS53aW5nZXQKICAgICAgICAgICAgICAgIGlmICgkaWQgLWFuZCAkaW5zdGFsbGVkSWRzLkNvbnRhaW5zS2V5KCRpZC5Ub0xvd2VyKCkpKSB7CiAgICAgICAgICAgICAgICAgICAgJHNjcmlwdDppbnN0YWxsZWRBcHBJZHNbJGlkXSA9ICR0cnVlCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJJbnN0YWxsZWQgY2FjaGUgdXBkYXRlIGZhaWxlZDogJF8iICJXYXJuIiB9CiAgICBXcml0ZS1Mb2cgIkluc3RhbGxlZCBjYWNoZTogJCgkc2NyaXB0Omluc3RhbGxlZEFwcElkcy5Db3VudCkgYXBwcyIgIlN1Y2Nlc3MiCn0KCg=='))
$script:installedAppIds = @{}

$sync.version = "2.0"
$sync.configs = @{}
$sync.ProcessRunning = $false
$sync.selectedApps = [System.Collections.Generic.List[string]]::new()
$sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
$sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()
$sync.currentTab = "Install"

$script:logLines = [System.Collections.Generic.List[string]]::new()

function Get-WpfResource { param($Key) try { $sync.window.FindResource($Key) } catch { Write-Log "Missing style: $Key" "Warn"; $null } }

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
    if ($sync.noUI) { Write-Log "[$Text] $SubText" "Info"; return }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread {
            if ($sync.controls["ProgressText"]) { $sync.controls["ProgressText"].Text = $Text }
            if ($sync.controls["ProgressSubText"]) { $sync.controls["ProgressSubText"].Text = $SubText }
            if ($sync.controls["ProgressBar"]) {
                if ($Value -ge 0) { $sync.controls["ProgressBar"].Value = $Value; $sync.controls["ProgressBar"].IsIndeterminate = $false }
                else { $sync.controls["ProgressBar"].IsIndeterminate = $true }
            }
            if ($sync.controls["ProgressOverlay"]) { $sync.controls["ProgressOverlay"].Visibility = "Visible" }
        }
    }
    if (-not $sync.noUI) { Set-ProgressTaskbar -state "Normal" -value ([math]::Max(0.01, $Value)) }
}

function Hide-Progress {
    if ($sync.noUI) { return }
    if ($sync.controls["ProgressOverlay"]) {
        Invoke-WPFUIThread { $sync.controls["ProgressOverlay"].Visibility = "Collapsed" }
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
        foreach ($cat in $sync.configs.apps.PSObject.Properties.Name) {
            foreach ($appKey in $sync.configs.apps.$cat.PSObject.Properties.Name) {
                $id = $sync.configs.apps.$cat.$appKey.winget
                if ($id -and $installedIds.ContainsKey($id.ToLower())) {
                    $script:installedAppIds[$id] = $true
                }
            }
        }
    } catch { Write-Log "Installed cache update failed: $_" "Warn" }
    Write-Log "Installed cache: $($script:installedAppIds.Count) apps" "Success"
}


$script:__mod_theme = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpjdXJyZW50VGhlbWUgPSAiZGFyayIKCmZ1bmN0aW9uIEFwcGx5LVRoZW1lIHsKICAgIHBhcmFtKCRUaGVtZU5hbWUpCiAgICAka2V5ID0gJFRoZW1lTmFtZS5Ub0xvd2VyKCkKICAgIGlmICgtbm90ICRzeW5jLmNvbmZpZ3MudGhlbWVzIC1vciAtbm90ICRzeW5jLmNvbmZpZ3MudGhlbWVzLiRrZXkpIHsKICAgICAgICBXcml0ZS1Mb2cgIlRoZW1lICckVGhlbWVOYW1lJyBub3QgZm91bmQgaW4gdGhlbWVzIGNvbmZpZy4iICJXYXJuIgogICAgICAgIHJldHVybgogICAgfQogICAgdHJ5IHsKICAgICAgICAkY29sb3JzID0gJHN5bmMuY29uZmlncy50aGVtZXMuJGtleQogICAgICAgICRjb252ZXJ0ZXIgPSBbU3lzdGVtLldpbmRvd3MuTWVkaWEuQnJ1c2hDb252ZXJ0ZXJdOjpuZXcoKQogICAgICAgICRuZXdEaWN0ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5SZXNvdXJjZURpY3Rpb25hcnkKCiAgICAgICAgZm9yZWFjaCAoJHByb3AgaW4gJGNvbG9ycy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpIHsKICAgICAgICAgICAgJGJydXNoID0gJGNvbnZlcnRlci5Db252ZXJ0RnJvbSgkY29sb3JzLiRwcm9wKQogICAgICAgICAgICAkbmV3RGljdC5BZGQoJHByb3AsICRicnVzaCkKICAgICAgICB9CiAgICAgICAgaWYgKCRjb252ZXJ0ZXIgLWFuZCAkY29udmVydGVyLkdldFR5cGUoKS5HZXRNZXRob2QoJ0Rpc3Bvc2UnKSkgeyAkY29udmVydGVyLkRpc3Bvc2UoKSB9CgogICAgICAgICRzY3JpcHQ6Y3VycmVudFRoZW1lID0gJFRoZW1lTmFtZQogICAgICAgIFdyaXRlLUxvZyAiVGhlbWU6ICRUaGVtZU5hbWUiICJTdWNjZXNzIgoKICAgICAgICBpZiAoW1N5c3RlbS5XaW5kb3dzLkFwcGxpY2F0aW9uXTo6Q3VycmVudCkgewogICAgICAgICAgICAkYXBwUmVzb3VyY2VzID0gW1N5c3RlbS5XaW5kb3dzLkFwcGxpY2F0aW9uXTo6Q3VycmVudC5SZXNvdXJjZXMKICAgICAgICAgICAgJGV4aXN0aW5nVGhlbWUgPSBAKCRhcHBSZXNvdXJjZXMuTWVyZ2VkRGljdGlvbmFyaWVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uU291cmNlIC1lcSAkbnVsbCAtYW5kICRfLkNvdW50IC1ndCAwIC1hbmQgLW5vdCAkXy5Db250YWlucygiVG9vbEJhckJ1dHRvbkJhc2VTdHlsZSIpIH0pCiAgICAgICAgICAgIGZvcmVhY2ggKCRkaWN0IGluICRleGlzdGluZ1RoZW1lKSB7ICRhcHBSZXNvdXJjZXMuTWVyZ2VkRGljdGlvbmFyaWVzLlJlbW92ZSgkZGljdCkgfQogICAgICAgICAgICAkYXBwUmVzb3VyY2VzLk1lcmdlZERpY3Rpb25hcmllcy5BZGQoJG5ld0RpY3QpCiAgICAgICAgfSBlbHNlaWYgKCRzeW5jLndpbmRvdykgewogICAgICAgICAgICAkZXhpc3RpbmdUaGVtZSA9IEAoJHN5bmMud2luZG93LlJlc291cmNlcy5NZXJnZWREaWN0aW9uYXJpZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Tb3VyY2UgLWVxICRudWxsIH0pCiAgICAgICAgICAgIGZvcmVhY2ggKCRkaWN0IGluICRleGlzdGluZ1RoZW1lKSB7ICRzeW5jLndpbmRvdy5SZXNvdXJjZXMuTWVyZ2VkRGljdGlvbmFyaWVzLlJlbW92ZSgkZGljdCkgfQogICAgICAgICAgICAkc3luYy53aW5kb3cuUmVzb3VyY2VzLk1lcmdlZERpY3Rpb25hcmllcy5BZGQoJG5ld0RpY3QpCiAgICAgICAgfQoKICAgICAgICBpZiAoJHN5bmMud2luZG93IC1hbmQgJGNvbG9ycy53aW5kb3dCYWNrZ3JvdW5kKSB7CiAgICAgICAgICAgICRzeW5jLndpbmRvdy5CYWNrZ3JvdW5kID0gJGNvbnZlcnRlci5Db252ZXJ0RnJvbSgkY29sb3JzLndpbmRvd0JhY2tncm91bmQpCiAgICAgICAgfQogICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiVGhlbWUgYXBwbHkgZmFpbGVkOiAkXyIgIkVycm9yIiB9Cn0K'))
$script:currentTheme = "dark"

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

$script:__mod_navigation = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpwYWdlcyA9IEB7fQokc2NyaXB0Om5hdkJ1dHRvbnMgPSBAe30KJHNjcmlwdDpuYXZOYW1lcyA9IEAoIkluc3RhbGwiLCAiVHdlYWtzIiwgIkZlYXR1cmVzIiwgIlByZWZlcmVuY2VzIiwgIkxlZ2FjeSIsICJTZXR0aW5ncyIpCgpmdW5jdGlvbiBTaG93LU5hdlBhbmVsIHsKICAgIHBhcmFtKCROYW1lKQogICAgZm9yZWFjaCAoJG90aGVyIGluICRuYXZOYW1lcykgewogICAgICAgIGlmICgkc3luYy5jb250cm9sc1siUGFnZSRvdGhlciJdKSB7ICRzeW5jLmNvbnRyb2xzWyJQYWdlJG90aGVyIl0uVmlzaWJpbGl0eSA9ICJDb2xsYXBzZWQiIH0KICAgIH0KICAgIGlmICgkc3luYy5jb250cm9sc1siUGFnZSROYW1lIl0pIHsgJHN5bmMuY29udHJvbHNbIlBhZ2UkTmFtZSJdLlZpc2liaWxpdHkgPSAiVmlzaWJsZSI7ICRzeW5jLmN1cnJlbnRUYWIgPSAkTmFtZTsgV3JpdGUtTG9nICJTd2l0Y2hlZCB0bzogJE5hbWUiICJJbmZvIiB9Cn0KCmZ1bmN0aW9uIFN3aXRjaC1QYWdlIHsgcGFyYW0oJE5hbWUpOyBTaG93LU5hdlBhbmVsICROYW1lIH0KCmlmICgkc3luYy5jb250cm9scy5Db3VudCkgewogICAgZm9yZWFjaCAoJG4gaW4gJG5hdk5hbWVzKSB7CiAgICAgICAgaWYgKCRzeW5jLmNvbnRyb2xzWyJQYWdlJG4iXSkgeyAkcGFnZXNbJG5dID0gJHN5bmMuY29udHJvbHNbIlBhZ2UkbiJdIH0KICAgICAgICBpZiAoJHN5bmMuY29udHJvbHNbIk5hdiRuIl0pIHsgJG5hdkJ1dHRvbnNbJG5dID0gJHN5bmMuY29udHJvbHNbIk5hdiRuIl0gfQogICAgfQogICAgZm9yZWFjaCAoJG5hdk5hbWUgaW4gJG5hdk5hbWVzKSB7CiAgICAgICAgJGJ0bk5hbWUgPSAiTmF2JG5hdk5hbWUiCiAgICAgICAgJGJ0biA9ICRzeW5jLmNvbnRyb2xzWyRidG5OYW1lXQogICAgICAgIGlmICgkYnRuKSB7CiAgICAgICAgICAgICRidG4uVGFnID0gJG5hdk5hbWUKICAgICAgICAgICAgJGJ0bi5BZGRfQ2xpY2soeyBTaG93LU5hdlBhbmVsICR0aGlzLlRhZyB9KQogICAgICAgICAgICBpZiAoJGJ0bi5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJJc0VuYWJsZWQiKSB7ICRidG4uSXNFbmFibGVkID0gJHRydWUgfQogICAgICAgICAgICBXcml0ZS1Mb2cgIk5hdmlnYXRpb246ICRidG5OYW1lIHdpcmVkLiIgIlN1Y2Nlc3MiCiAgICAgICAgfQogICAgfQogICAgaWYgKCRzeW5jLndpbmRvdykgeyAkc3luYy53aW5kb3cuQWRkX0tleURvd24oewogICAgICAgIHBhcmFtKCRzZW5kZXIsICRlKQogICAgICAgICAgICBpZiAoJGUuS2V5IC1lcSAiRXNjYXBlIiAtYW5kICRzeW5jLmNvbnRyb2xzWyJTZWFyY2hCb3giXSkgewogICAgICAgICAgICAgICAgJHN5bmMuY29udHJvbHNbIlNlYXJjaEJveCJdLlRleHQgPSAiIgogICAgICAgICAgICAgICAgU2hvdy1OYXZQYW5lbCAkbmF2TmFtZXNbMF0KICAgICAgICAgICAgICAgICRlLkhhbmRsZWQgPSAkdHJ1ZQogICAgICAgICAgICB9CiAgICAgICAgfSkKICAgIH0KfQo='))
$script:pages = @{}
$script:navButtons = @{}
$script:navNames = @("Install", "Tweaks", "Features", "Preferences", "Legacy", "Settings")

function Show-NavPanel {
    param($Name)
    foreach ($other in $navNames) {
        if ($sync.controls["Page$other"]) { $sync.controls["Page$other"].Visibility = "Collapsed" }
    }
    if ($sync.controls["Page$Name"]) { $sync.controls["Page$Name"].Visibility = "Visible"; $sync.currentTab = $Name; Write-Log "Switched to: $Name" "Info" }
}

function Switch-Page { param($Name); Show-NavPanel $Name }

if ($sync.controls.Count) {
    foreach ($n in $navNames) {
        if ($sync.controls["Page$n"]) { $pages[$n] = $sync.controls["Page$n"] }
        if ($sync.controls["Nav$n"]) { $navButtons[$n] = $sync.controls["Nav$n"] }
    }
    foreach ($navName in $navNames) {
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
            if ($e.Key -eq "Escape" -and $sync.controls["SearchBox"]) {
                $sync.controls["SearchBox"].Text = ""
                Show-NavPanel $navNames[0]
                $e.Handled = $true
            }
        })
    }
}

$script:__mod_tweaks = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDp0d2Vha1VuZG9Mb2cgPSBAe30KJHNjcmlwdDpsYXN0UmVzdG9yZVBvaW50ID0gJG51bGwKCmZ1bmN0aW9uIFNhdmUtT3JpZ2luYWxWYWx1ZXMgewogICAgcGFyYW0oJHR3ZWFrS2V5LCAkdHdlYWspCiAgICBpZiAoJHNjcmlwdDp0d2Vha1VuZG9Mb2cuQ29udGFpbnNLZXkoJHR3ZWFrS2V5KSkgeyByZXR1cm4gfQogICAgJHVuZG9FbnRyeSA9IEB7IEtleSA9ICR0d2Vha0tleTsgUmVnaXN0cnkgPSBAKCk7IFNlcnZpY2VzID0gQCgpOyBTY3JpcHRzID0gQCgpIH0KICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAicmVnaXN0cnkiKSB7CiAgICAgICAgZm9yZWFjaCAoJHJlZyBpbiAkdHdlYWsucmVnaXN0cnkpIHsKICAgICAgICAgICAgJGN1cnJlbnRWYWx1ZSA9ICRudWxsCiAgICAgICAgICAgIGlmICgkcmVnLnBhdGggLWFuZCAoVGVzdC1QYXRoICRyZWcucGF0aCkpIHsKICAgICAgICAgICAgICAgIHRyeSB7ICRjdXJyZW50VmFsdWUgPSAoR2V0LUl0ZW1Qcm9wZXJ0eSAkcmVnLnBhdGggLU5hbWUgJHJlZy5uYW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS4kKCRyZWcubmFtZSkgfSBjYXRjaCB7IFdyaXRlLUxvZyAiUmVnaXN0cnkgcmVhZCBmYWlsZWQgZm9yIHVuZG86ICRfIiAiV2FybiIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICR1bmRvRW50cnkuUmVnaXN0cnkgKz0gQHsgUGF0aCA9ICRyZWcucGF0aDsgTmFtZSA9ICRyZWcubmFtZTsgT3JpZ2luYWxWYWx1ZSA9ICRjdXJyZW50VmFsdWU7IFR5cGUgPSAkcmVnLnR5cGUgfQogICAgICAgIH0KICAgIH0KICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAic2VydmljZXMiKSB7CiAgICAgICAgZm9yZWFjaCAoJHN2YyBpbiAkdHdlYWsuc2VydmljZXMpIHsKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRzdmNPYmogPSBHZXQtU2VydmljZSAkc3ZjLm5hbWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgICAgIGlmICgkc3ZjT2JqKSB7CiAgICAgICAgICAgICAgICAgICAgJHVuZG9FbnRyeS5TZXJ2aWNlcyArPSBAeyBOYW1lID0gJHN2Yy5uYW1lOyBPcmlnaW5hbFN0YXR1cyA9ICRzdmNPYmouU3RhdHVzOyBPcmlnaW5hbFN0YXJ0dXAgPSAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1NlcnZpY2UgLUZpbHRlciAiTmFtZT0nJCgkc3ZjLm5hbWUpJyIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLlN0YXJ0TW9kZSB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJTZXJ2aWNlIGNhcHR1cmUgZmFpbGVkOiAkXyIgIldhcm4iIH0KICAgICAgICB9CiAgICB9CiAgICBpZiAoJHR3ZWFrLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgInVuZG9TY3JpcHQiKSB7ICR1bmRvRW50cnkuU2NyaXB0cyArPSAkdHdlYWsudW5kb1NjcmlwdCB9CiAgICAkc2NyaXB0OnR3ZWFrVW5kb0xvZ1skdHdlYWtLZXldID0gJHVuZG9FbnRyeQp9CgpmdW5jdGlvbiBOZXctU3lzdGVtUmVzdG9yZVBvaW50IHsKICAgIHBhcmFtKFtzdHJpbmddJERlc2NyaXB0aW9uID0gIkhrc1V0aWwgVHdlYWtzIikKICAgIHRyeSB7CiAgICAgICAgQ2hlY2twb2ludC1Db21wdXRlciAtRGVzY3JpcHRpb24gJERlc2NyaXB0aW9uIC1SZXN0b3JlUG9pbnRUeXBlIE1PRElGWV9TRVRUSU5HUyAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgICRzY3JpcHQ6bGFzdFJlc3RvcmVQb2ludCA9IEdldC1EYXRlCiAgICAgICAgV3JpdGUtTG9nICJSZXN0b3JlIHBvaW50IGNyZWF0ZWQ6ICREZXNjcmlwdGlvbiIgIlN1Y2Nlc3MiCiAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJSZXN0b3JlIHBvaW50IHNraXBwZWQgKHNlcnZpY2Ugbm90IGF2YWlsYWJsZSk6ICRfIiAiV2FybiIgfQp9CgpmdW5jdGlvbiBJbnZva2UtVW5kb1R3ZWFrcyB7CiAgICBpZiAoJHNjcmlwdDp0d2Vha1VuZG9Mb2cuQ291bnQgLWVxIDApIHsgV3JpdGUtTG9nICJObyB0d2Vha3MgdG8gdW5kby4iICJXYXJuIjsgcmV0dXJuIH0KCiAgICAkc2IgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlN0YWNrUGFuZWw7ICRzYi5PcmllbnRhdGlvbiA9ICJWZXJ0aWNhbCIKICAgICRzYi5DaGlsZHJlbi5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrIC1Qcm9wZXJ0eSBAeyBUZXh0ID0gIkNob29zZSB1bmRvIG1ldGhvZDoiOyBNYXJnaW4gPSAiMCwwLDAsMTAiOyBGb250V2VpZ2h0ID0gIkJvbGQiIH0pKSB8IE91dC1OdWxsCiAgICAkcmJMb2cgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlJhZGlvQnV0dG9uIC1Qcm9wZXJ0eSBAeyBDb250ZW50ID0gIlVuZG8gdmlhIExvZyAocmVnaXN0cnkgKyBzZXJ2aWNlcykiOyBJc0NoZWNrZWQgPSAkdHJ1ZTsgTWFyZ2luID0gIjAsMCwwLDUiIH0KICAgICRyYlJlc3RvcmUgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlJhZGlvQnV0dG9uIC1Qcm9wZXJ0eSBAeyBDb250ZW50ID0gIlN5c3RlbSBSZXN0b3JlIChyb2xsIGJhY2sgdG8gbGFzdCByZXN0b3JlIHBvaW50KSI7IE1hcmdpbiA9ICIwLDAsMCw1IiB9CiAgICBpZiAoLW5vdCAoR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgeyAkcmJSZXN0b3JlLklzRW5hYmxlZCA9ICRmYWxzZTsgJHJiUmVzdG9yZS5Db250ZW50ICs9ICIgKG5vbmUgYXZhaWxhYmxlKSIgfQogICAgJHNiLkNoaWxkcmVuLkFkZCgkcmJMb2cpIHwgT3V0LU51bGw7ICRzYi5DaGlsZHJlbi5BZGQoJHJiUmVzdG9yZSkgfCBPdXQtTnVsbAoKICAgICR3ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5XaW5kb3cgLVByb3BlcnR5IEB7IFRpdGxlID0gIlVuZG8gVHdlYWtzIjsgQ29udGVudCA9ICRzYjsgV2lkdGggPSA0MjA7IEhlaWdodCA9IDE4MDsgV2luZG93U3RhcnR1cExvY2F0aW9uID0gIkNlbnRlck93bmVyIjsgT3duZXIgPSAkc3luYy53aW5kb3c7IFNob3dJblRhc2tiYXIgPSAkZmFsc2UgfQogICAgJGJ0blBhbmVsID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5TdGFja1BhbmVsIC1Qcm9wZXJ0eSBAeyBPcmllbnRhdGlvbiA9ICJIb3Jpem9udGFsIjsgSG9yaXpvbnRhbEFsaWdubWVudCA9ICJSaWdodCI7IE1hcmdpbiA9ICIwLDE1LDAsMCIgfQogICAgJG9rQnRuID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5CdXR0b24gLVByb3BlcnR5IEB7IENvbnRlbnQgPSAiT0siOyBXaWR0aCA9IDgwOyBIZWlnaHQgPSAyODsgTWFyZ2luID0gIjAsMCwxMCwwIjsgSXNEZWZhdWx0ID0gJHRydWUgfQogICAgJGNhbmNlbEJ0biA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuQnV0dG9uIC1Qcm9wZXJ0eSBAeyBDb250ZW50ID0gIkNhbmNlbCI7IFdpZHRoID0gODA7IEhlaWdodCA9IDI4OyBJc0NhbmNlbCA9ICR0cnVlIH0KICAgICRidG5QYW5lbC5DaGlsZHJlbi5BZGQoJG9rQnRuKSB8IE91dC1OdWxsOyAkYnRuUGFuZWwuQ2hpbGRyZW4uQWRkKCRjYW5jZWxCdG4pIHwgT3V0LU51bGwKICAgICRzYi5DaGlsZHJlbi5BZGQoJGJ0blBhbmVsKSB8IE91dC1OdWxsCiAgICAkcmVzdWx0ID0gJGZhbHNlCiAgICAkb2tCdG4uQWRkX0NsaWNrKHsgJHJlc3VsdCA9ICR0cnVlOyAkdy5DbG9zZSgpIH0pCiAgICAkY2FuY2VsQnRuLkFkZF9DbGljayh7ICR3LkNsb3NlKCkgfSkKICAgICR3LlNob3dEaWFsb2coKSB8IE91dC1OdWxsCiAgICBpZiAoLW5vdCAkcmVzdWx0KSB7IHJldHVybiB9CgogICAgaWYgKCRyYlJlc3RvcmUuSXNDaGVja2VkKSB7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHJwID0gR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IHwgU29ydC1PYmplY3QgQ3JlYXRpb25UaW1lIC1EZXNjZW5kaW5nIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICBpZiAoJHJwKSB7IFdyaXRlLUxvZyAiU3RhcnRpbmcgc3lzdGVtIHJlc3RvcmUgdG8gJCgkcnAuRGVzY3JpcHRpb24pLi4uIiAiSGVhZGVyIjsgU2hvdy1JbmZvICJTeXN0ZW0gUmVzdG9yZSIgIllvdXIgY29tcHV0ZXIgd2lsbCByZXN0YXJ0IHRvIGNvbXBsZXRlIHRoZSBzeXN0ZW0gcmVzdG9yZS4iOyBSZXN0b3JlLUNvbXB1dGVyIC1SZXN0b3JlUG9pbnQgJHJwLlNlcXVlbmNlTnVtYmVyIC1Db25maXJtOiRmYWxzZSB9CiAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiU3lzdGVtIHJlc3RvcmUgZmFpbGVkOiAkXyIgIkVycm9yIiB9CiAgICAgICAgcmV0dXJuCiAgICB9CgogICAgV3JpdGUtTG9nICJVbmRvaW5nIGxhc3QgdHdlYWtzIHZpYSBsb2cuLi4iICJIZWFkZXIiCiAgICAkdHdlYWtOYW1lcyA9ICRzY3JpcHQ6dHdlYWtVbmRvTG9nLktleXMgfCBGb3JFYWNoLU9iamVjdCB7ICRfLlJlcGxhY2UoIldQRlR3ZWFrcyIsICIiKSAtcmVwbGFjZSAiKFthLXpdKShbQS1aXSkiLCAnJDEgJDInIH0KICAgICRtc2cgPSAiVW5kbyB0aGUgZm9sbG93aW5nIHR3ZWFrcz9gbmBuIiArICgkdHdlYWtOYW1lcyAtam9pbiAiYG4iKQogICAgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiVW5kbyB2aWEgTG9nIiAkbXNnKSkgeyByZXR1cm4gfQogICAgZm9yZWFjaCAoJGtleSBpbiAkc2NyaXB0OnR3ZWFrVW5kb0xvZy5LZXlzKSB7CiAgICAgICAgJGVudHJ5ID0gJHNjcmlwdDp0d2Vha1VuZG9Mb2dbJGtleV0KICAgICAgICBXcml0ZS1Mb2cgIlVuZG9pbmc6ICQoJGVudHJ5LktleSkiICJJbmZvIgogICAgICAgIGZvcmVhY2ggKCRzdmMgaW4gJGVudHJ5LlNlcnZpY2VzKSB7CiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICBpZiAoJHN2Yy5PcmlnaW5hbFN0YXJ0dXAgLWFuZCAkc3ZjLk9yaWdpbmFsU3RhcnR1cCAtbmUgIkRpc2FibGVkIikgeyAkc3RhcnRUeXBlID0gJHN2Yy5PcmlnaW5hbFN0YXJ0dXA7IGlmICgkc3RhcnRUeXBlIC1lcSAiQXV0byIpIHsgJHN0YXJ0VHlwZSA9ICJBdXRvbWF0aWMiIH07IFNldC1TZXJ2aWNlICRzdmMuTmFtZSAtU3RhcnR1cFR5cGUgJHN0YXJ0VHlwZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgICAgICBpZiAoJHN2Yy5PcmlnaW5hbFN0YXR1cyAtYW5kICRzdmMuT3JpZ2luYWxTdGF0dXMgLW5lICJTdG9wcGVkIikgeyBTdGFydC1TZXJ2aWNlICRzdmMuTmFtZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgICAgICBXcml0ZS1Mb2cgIlNlcnZpY2UgJCgkc3ZjLk5hbWUpIHJlc3RvcmVkLiIgIlN1Y2Nlc3MiCiAgICAgICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlNlcnZpY2UgdW5kbyBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgICAgICB9CiAgICAgICAgZm9yZWFjaCAoJHJlZyBpbiAkZW50cnkuUmVnaXN0cnkpIHsKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgIGlmICghKFRlc3QtUGF0aCAkcmVnLlBhdGgpKSB7IE5ldy1JdGVtICRyZWcuUGF0aCAtRm9yY2UgfCBPdXQtTnVsbCB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyZWcuT3JpZ2luYWxWYWx1ZSkgeyBTZXQtSXRlbVByb3BlcnR5ICRyZWcuUGF0aCAtTmFtZSAkcmVnLk5hbWUgLVZhbHVlICRyZWcuT3JpZ2luYWxWYWx1ZSAtVHlwZSAkcmVnLlR5cGUgLUZvcmNlIH0KICAgICAgICAgICAgICAgIGVsc2UgeyBSZW1vdmUtSXRlbVByb3BlcnR5ICRyZWcuUGF0aCAtTmFtZSAkcmVnLk5hbWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJSZWdpc3RyeSAkKCRyZWcuTmFtZSkgcmVzdG9yZWQuIiAiU3VjY2VzcyIKICAgICAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiUmVnaXN0cnkgdW5kbyBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgICAgICB9CiAgICAgICAgZm9yZWFjaCAoJHNjcmlwdEJsb2NrIGluICRlbnRyeS5TY3JpcHRzKSB7CiAgICAgICAgICAgIHRyeSB7ICYgKFtzY3JpcHRibG9ja106OkNyZWF0ZSgkc2NyaXB0QmxvY2spKTsgV3JpdGUtTG9nICJVbmRvIHNjcmlwdCBleGVjdXRlZC4iICJTdWNjZXNzIiB9IGNhdGNoIHsgV3JpdGUtTG9nICJVbmRvIHNjcmlwdCBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgICAgICB9CiAgICB9CiAgICAkc2NyaXB0OnR3ZWFrVW5kb0xvZyA9IEB7fQogICAgV3JpdGUtTG9nICJBbGwgdHdlYWtzIHVuZG9uZS4iICJIZWFkZXIiCn0KCmlmICgkc3luYy5jb250cm9sc1siQnRuUnVuVHdlYWtzIl0pIHsKICAgICRzeW5jLmNvbnRyb2xzWyJCdG5SdW5Ud2Vha3MiXS5BZGRfQ2xpY2soewogICAgICAgICRzZWxlY3RlZCA9ICR0d2Vha0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0KICAgICAgICBpZiAoJHNlbGVjdGVkLkNvdW50IC1lcSAwKSB7IFdyaXRlLUxvZyAiTm8gdHdlYWtzIHNlbGVjdGVkLiIgIldhcm4iOyByZXR1cm4gfQogICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIlJ1biBUd2Vha3MiICJBcHBseSAkKCRzZWxlY3RlZC5Db3VudCkgdHdlYWsocyk/YG5gbkEgc3lzdGVtIHJlc3RvcmUgcG9pbnQgd2lsbCBiZSBjcmVhdGVkIGZpcnN0LiIpKSB7IHJldHVybiB9CiAgICAgICAgV3JpdGUtTG9nICJDcmVhdGluZyByZXN0b3JlIHBvaW50Li4uIiAiSW5mbyIKICAgICAgICBOZXctU3lzdGVtUmVzdG9yZVBvaW50CiAgICAgICAgV3JpdGUtTG9nICJSdW5uaW5nIFNlbGVjdGVkIFR3ZWFrcy4uLiIgIkhlYWRlciIKICAgICAgICBTZXQtU3RhdHVzICJBcHBseWluZyAkKCRzZWxlY3RlZC5Db3VudCkgdHdlYWsocykuLi4iCiAgICAgICAgZm9yZWFjaCAoJGNiIGluICRzZWxlY3RlZCkgewogICAgICAgICAgICAkdHdlYWtLZXkgPSAkY2IuVGFnOyAkdHdlYWsgPSAkbnVsbAogICAgICAgICAgICBmb3JlYWNoICgkZ3JvdXBLZXkgaW4gJHN5bmMuY29uZmlncy50d2Vha3MuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgICAgICAgICAkZ3JvdXAgPSAkc3luYy5jb25maWdzLnR3ZWFrcy4kZ3JvdXBLZXkKICAgICAgICAgICAgICAgIGlmICgkZ3JvdXAuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAkdHdlYWtLZXkpIHsgJHR3ZWFrID0gJGdyb3VwLiR0d2Vha0tleTsgYnJlYWsgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgtbm90ICR0d2VhaykgeyBjb250aW51ZSB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiQXBwbHlpbmc6ICQoJHR3ZWFrLmNvbnRlbnQpIiAiSW5mbyIKICAgICAgICAgICAgU2F2ZS1PcmlnaW5hbFZhbHVlcyAtdHdlYWtLZXkgJHR3ZWFrS2V5IC10d2VhayAkdHdlYWsKICAgICAgICAgICAgaWYgKCR0d2Vhay5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJzZXJ2aWNlcyIpIHsKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRzdmMgaW4gJHR3ZWFrLnNlcnZpY2VzKSB7CiAgICAgICAgICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICAgICAgICAgaWYgKCRzdmMuYWN0aW9uIC1lcSAic3RvcF9kaXNhYmxlIikgeyBTdG9wLVNlcnZpY2UgJHN2Yy5uYW1lIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgU2V0LVNlcnZpY2UgJHN2Yy5uYW1lIC1TdGFydHVwVHlwZSBEaXNhYmxlZCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgICAgICAgICAgICAgIGlmICgkc3ZjLmFjdGlvbiAtZXEgInNldF9tYW51YWwiKSB7IFNldC1TZXJ2aWNlICRzdmMubmFtZSAtU3RhcnR1cFR5cGUgTWFudWFsIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICAgICAgICAgICAgICAgICAgV3JpdGUtTG9nICJTZXJ2aWNlICQoJHN2Yy5uYW1lKTogJCgkc3ZjLmFjdGlvbikiICJTdWNjZXNzIgogICAgICAgICAgICAgICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlNlcnZpY2UgJCgkc3ZjLm5hbWUpIGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAicmVnaXN0cnkiKSB7CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcmVnIGluICR0d2Vhay5yZWdpc3RyeSkgewogICAgICAgICAgICAgICAgICAgIHRyeSB7IGlmICghKFRlc3QtUGF0aCAkcmVnLnBhdGgpKSB7IE5ldy1JdGVtICRyZWcucGF0aCAtRm9yY2UgfCBPdXQtTnVsbCB9OyBTZXQtSXRlbVByb3BlcnR5ICRyZWcucGF0aCAtTmFtZSAkcmVnLm5hbWUgLVZhbHVlICRyZWcudmFsdWUgLVR5cGUgJHJlZy50eXBlIC1Gb3JjZTsgV3JpdGUtTG9nICJSZWdpc3RyeTogJCgkcmVnLm5hbWUpID0gJCgkcmVnLnZhbHVlKSIgIlN1Y2Nlc3MiIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlJlZ2lzdHJ5IGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiYXBweF9wYWNrYWdlcyIpIHsKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwa2cgaW4gJHR3ZWFrLmFwcHhfcGFja2FnZXMpIHsKICAgICAgICAgICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICAgICBHZXQtQXBweFBhY2thZ2UgLU5hbWUgJHBrZyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFJlbW92ZS1BcHB4UGFja2FnZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICAgICAgICAgICAgICBHZXQtQXBweFByb3Zpc2lvbmVkUGFja2FnZSAtT25saW5lIHwgV2hlcmUtT2JqZWN0IHsgJF8uRGlzcGxheU5hbWUgLWxpa2UgJHBrZyB9IHwgUmVtb3ZlLUFwcHhQcm92aXNpb25lZFBhY2thZ2UgLU9ubGluZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICAgICAgICAgICAgICBXcml0ZS1Mb2cgIlJlbW92ZWQ6ICRwa2ciICJTdWNjZXNzIgogICAgICAgICAgICAgICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIlNraXA6ICRwa2dgbiRfIiAiV2FybiIgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAic2NyaXB0IikgewogICAgICAgICAgICAgICAgdHJ5IHsgJiAoW3NjcmlwdGJsb2NrXTo6Q3JlYXRlKCR0d2Vhay5zY3JpcHQpKTsgV3JpdGUtTG9nICJTY3JpcHQgZXhlY3V0ZWQuIiAiU3VjY2VzcyIgfSBjYXRjaCB7IFdyaXRlLUxvZyAiU2NyaXB0IGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkdHdlYWsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiaW5mbyIpIHsgV3JpdGUtTG9nICR0d2Vhay5pbmZvICJXYXJuIiB9CiAgICAgICAgfQogICAgICAgIFNldC1TdGF0dXMgIlJlYWR5IgogICAgICAgIFNob3ctSW5mbyAiVHdlYWtzIENvbXBsZXRlIiAiJCgkc2VsZWN0ZWQuQ291bnQpIHR3ZWFrKHMpIGFwcGxpZWQuYG5gblVuZG8gZnJvbSBUd2Vha3MgdGFiLiIKICAgICAgICBXcml0ZS1Mb2cgIkFsbCBzZWxlY3RlZCB0d2Vha3MgY29tcGxldGVkLiIgIkhlYWRlciIKICAgIH0pCn0KCmlmICgkc3luYy5jb250cm9sc1siQnRuVW5kb1R3ZWFrcyJdKSB7ICRzeW5jLmNvbnRyb2xzWyJCdG5VbmRvVHdlYWtzIl0uQWRkX0NsaWNrKHsgSW52b2tlLVVuZG9Ud2Vha3MgfSkgfQo='))
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

    $w = New-Object System.Windows.Window -Property @{ Title = "Undo Tweaks"; Content = $sb; Width = 420; Height = 180; WindowStartupLocation = "CenterOwner"; Owner = $sync.window; ShowInTaskbar = $false }
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

if ($sync.controls["BtnRunTweaks"]) {
    $sync.controls["BtnRunTweaks"].Add_Click({
        $selected = $tweakCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No tweaks selected." "Warn"; return }
        if (-not (Show-Confirm "Run Tweaks" "Apply $($selected.Count) tweak(s)?`n`nA system restore point will be created first.")) { return }
        Write-Log "Creating restore point..." "Info"
        New-SystemRestorePoint
        Write-Log "Running Selected Tweaks..." "Header"
        Set-Status "Applying $($selected.Count) tweak(s)..."
        foreach ($cb in $selected) {
            $tweakKey = $cb.Tag; $tweak = $null
            foreach ($groupKey in $sync.configs.tweaks.PSObject.Properties.Name) {
                $group = $sync.configs.tweaks.$groupKey
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

if ($sync.controls["BtnUndoTweaks"]) { $sync.controls["BtnUndoTweaks"].Add_Click({ Invoke-UndoTweaks }) }

$script:__mod_search = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('ZnVuY3Rpb24gQXBwbHktRmlsdGVycyB7CiAgICBXcml0ZS1Mb2cgIkFwcGx5aW5nIHNlYXJjaCBmaWx0ZXJzLi4uIiAiSW5mbyIKICAgICRmaWx0ZXIgPSBpZiAoJHN5bmMuY29udHJvbHNbIlNlYXJjaEJveCJdKSB7ICRzeW5jLmNvbnRyb2xzWyJTZWFyY2hCb3giXS5UZXh0LlRvTG93ZXIoKSB9IGVsc2UgeyAiIiB9CiAgICAkc2hvd0luc3RhbGxlZCA9ICRzeW5jLmNvbnRyb2xzWyJDaGtTaG93SW5zdGFsbGVkIl0gLWFuZCAkc3luYy5jb250cm9sc1siQ2hrU2hvd0luc3RhbGxlZCJdLklzQ2hlY2tlZAogICAgZm9yZWFjaCAoJGNiIGluICRhcHBDaGVja2JveGVzKSB7CiAgICAgICAgJGlzVmlzaWJsZSA9ICR0cnVlCiAgICAgICAgaWYgKCRzaG93SW5zdGFsbGVkKSB7CiAgICAgICAgICAgICRpZCA9IGlmICgkY2IuVGFnIC1uZSAkbnVsbCkgeyAkY2IuVGFnLlRvU3RyaW5nKCkgfSBlbHNlIHsgIiIgfQogICAgICAgICAgICAkaXNWaXNpYmxlID0gJGlzVmlzaWJsZSAtYW5kICRzY3JpcHQ6aW5zdGFsbGVkQXBwSWRzLkNvbnRhaW5zS2V5KCRpZCkKICAgICAgICB9CiAgICAgICAgaWYgKCRmaWx0ZXIpIHsKICAgICAgICAgICAgJHRleHQgPSBpZiAoJGNiLlRhZyAtbmUgJG51bGwpIHsgJGNiLlRhZy5Ub1N0cmluZygpLlRvTG93ZXIoKSB9IGVsc2UgeyAiIiB9CiAgICAgICAgICAgICRjb250ZW50ID0gaWYgKCRjYi5Db250ZW50IC1uZSAkbnVsbCkgeyAkY2IuQ29udGVudC5Ub1N0cmluZygpLlRvTG93ZXIoKSB9IGVsc2UgeyAiIiB9CiAgICAgICAgICAgICRpc1Zpc2libGUgPSAkaXNWaXNpYmxlIC1hbmQgKCR0ZXh0LkNvbnRhaW5zKCRmaWx0ZXIpIC1vciAkY29udGVudC5Db250YWlucygkZmlsdGVyKSkKICAgICAgICB9CiAgICAgICAgdHJ5IHsgJGNiLlZpc2liaWxpdHkgPSBpZiAoJGlzVmlzaWJsZSkgeyAiVmlzaWJsZSIgfSBlbHNlIHsgIkNvbGxhcHNlZCIgfSB9IGNhdGNoIHsgV3JpdGUtTG9nICJGaWx0ZXIgdmlzaWJpbGl0eSBmYWlsZWQ6ICRfIiAiV2FybiIgfQogICAgfQogICAgZm9yZWFjaCAoJHBhbmVsTmFtZSBpbiBAKCJUd2Vha3NQYW5lbDEiLCJUd2Vha3NQYW5lbDIiLCJUd2Vha3NQYW5lbDMiKSkgewogICAgICAgIGlmICgtbm90ICRzeW5jLmNvbnRyb2xzWyRwYW5lbE5hbWVdKSB7IGNvbnRpbnVlIH0KICAgICAgICBmb3JlYWNoICgkY2IgaW4gJHN5bmMuY29udHJvbHNbJHBhbmVsTmFtZV0uQ2hpbGRyZW4pIHsKICAgICAgICAgICAgaWYgKCRjYiAtaXNub3QgW1N5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkNoZWNrQm94XSkgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRpc1Zpc2libGUgPSAkdHJ1ZQogICAgICAgICAgICBpZiAoJGZpbHRlcikgewogICAgICAgICAgICAgICAgJHRleHQgPSBpZiAoJGNiLlRhZyAtbmUgJG51bGwpIHsgJGNiLlRhZy5Ub1N0cmluZygpLlRvTG93ZXIoKSB9IGVsc2UgeyAiIiB9CiAgICAgICAgICAgICAgICAkY29udGVudCA9IGlmICgkY2IuQ29udGVudCAtbmUgJG51bGwpIHsgJGNiLkNvbnRlbnQuVG9TdHJpbmcoKS5Ub0xvd2VyKCkgfSBlbHNlIHsgIiIgfQogICAgICAgICAgICAgICAgJGlzVmlzaWJsZSA9ICRpc1Zpc2libGUgLWFuZCAoJHRleHQuQ29udGFpbnMoJGZpbHRlcikgLW9yICRjb250ZW50LkNvbnRhaW5zKCRmaWx0ZXIpKQogICAgICAgICAgICB9CiAgICAgICAgICAgIHRyeSB7ICRjYi5WaXNpYmlsaXR5ID0gaWYgKCRpc1Zpc2libGUpIHsgIlZpc2libGUiIH0gZWxzZSB7ICJDb2xsYXBzZWQiIH0gfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmlsdGVyIHZpc2liaWxpdHkgZmFpbGVkOiAkXyIgIldhcm4iIH0KICAgICAgICB9CiAgICB9CiAgICBpZiAoJHN5bmMuY29udHJvbHNbIlNlYXJjaEhpbnQiXSkgeyAkc3luYy5jb250cm9sc1siU2VhcmNoSGludCJdLlZpc2liaWxpdHkgPSBpZiAoJGZpbHRlcikgeyAiQ29sbGFwc2VkIiB9IGVsc2UgeyAiVmlzaWJsZSIgfSB9CiAgICBXcml0ZS1Mb2cgIkZpbHRlcnMgYXBwbGllZC4iICJTdWNjZXNzIgp9CgppZiAoJHN5bmMuY29udHJvbHNbIlNlYXJjaEJveCJdKSB7CiAgICAkc3luYy5jb250cm9sc1siU2VhcmNoQm94Il0uQWRkX1RleHRDaGFuZ2VkKHsKICAgICAgICBBcHBseS1GaWx0ZXJzCiAgICB9KQp9Cg=='))
function Apply-Filters {
    Write-Log "Applying search filters..." "Info"
    $filter = if ($sync.controls["SearchBox"]) { $sync.controls["SearchBox"].Text.ToLower() } else { "" }
    $showInstalled = $sync.controls["ChkShowInstalled"] -and $sync.controls["ChkShowInstalled"].IsChecked
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
        if (-not $sync.controls[$panelName]) { continue }
        foreach ($cb in $sync.controls[$panelName].Children) {
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
    if ($sync.controls["SearchHint"]) { $sync.controls["SearchHint"].Visibility = if ($filter) { "Collapsed" } else { "Visible" } }
    Write-Log "Filters applied." "Success"
}

if ($sync.controls["SearchBox"]) {
    $sync.controls["SearchBox"].Add_TextChanged({
        Apply-Filters
    })
}

$script:__mod_toolbar = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aWYgKCRzeW5jLmNvbnRyb2xzWyJCdG5Ub29sYmFyQ2xvc2UiXSkgewogICAgJHN5bmMuY29udHJvbHNbIkJ0blRvb2xiYXJDbG9zZSJdLkFkZF9DbGljayh7ICRzeW5jLndpbmRvdy5DbG9zZSgpIH0pCn0KCmlmICgkc3luYy5jb250cm9sc1siQnRuVG9vbGJhck1pbmltaXplIl0pIHsKICAgICRzeW5jLmNvbnRyb2xzWyJCdG5Ub29sYmFyTWluaW1pemUiXS5BZGRfQ2xpY2soeyAkc3luYy53aW5kb3cuV2luZG93U3RhdGUgPSAiTWluaW1pemVkIiB9KQp9CgppZiAoJHN5bmMuY29udHJvbHNbIkJ0blRvb2xiYXJNYXhpbWl6ZSJdKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuVG9vbGJhck1heGltaXplIl0uQWRkX0NsaWNrKHsKICAgICAgICAkc3luYy53aW5kb3cuV2luZG93U3RhdGUgPSBpZiAoJHN5bmMud2luZG93LldpbmRvd1N0YXRlIC1lcSAiTWF4aW1pemVkIikgeyAiTm9ybWFsIiB9IGVsc2UgeyAiTWF4aW1pemVkIiB9CiAgICB9KQp9CgppZiAoJHN5bmMuY29udHJvbHNbIkJ0blRvb2xiYXJUaGVtZSJdKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuVG9vbGJhclRoZW1lIl0uQWRkX0NsaWNrKHsKICAgICAgICBpZiAoJHNjcmlwdDpjdXJyZW50VGhlbWUgLWVxICJkYXJrIikgeyBBcHBseS1UaGVtZSAibGlnaHQiIH0gZWxzZSB7IEFwcGx5LVRoZW1lICJkYXJrIiB9CiAgICB9KQp9CgppZiAoJHN5bmMuY29udHJvbHNbIkJ0bkdlYXJFeHBvcnQiXSkgewogICAgJHN5bmMuY29udHJvbHNbIkJ0bkdlYXJFeHBvcnQiXS5BZGRfQ2xpY2soewogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRzZmQgPSBOZXctT2JqZWN0IE1pY3Jvc29mdC5XaW4zMi5TYXZlRmlsZURpYWxvZwogICAgICAgICAgICAkc2ZkLkZpbHRlciA9ICJKU09OIENvbmZpZyAoKi5qc29uKXwqLmpzb258QWxsIEZpbGVzICgqLiopfCouKiIKICAgICAgICAgICAgJHNmZC5UaXRsZSA9ICJFeHBvcnQgQ29uZmlnIgogICAgICAgICAgICAkc2ZkLkZpbGVOYW1lID0gIkhrc1V0aWwtJChbRGF0ZVRpbWVdOjpOb3cuVG9TdHJpbmcoJ3l5eXlNTWRkLUhIbW1zcycpKS5qc29uIgogICAgICAgICAgICAkc2ZkLkluaXRpYWxEaXJlY3RvcnkgPSBbRW52aXJvbm1lbnRdOjpHZXRGb2xkZXJQYXRoKCJEZXNrdG9wIikKICAgICAgICAgICAgJHJlc3VsdCA9ICRzZmQuU2hvd0RpYWxvZygkc3luYy53aW5kb3cpCiAgICAgICAgICAgIGlmICgkcmVzdWx0IC1uZSAkdHJ1ZSkgeyByZXR1cm4gfQogICAgICAgICAgICAkZGF0YSA9IEB7CiAgICAgICAgICAgICAgICBBcHBTZWxlY3Rpb25zID0gQCgkYXBwQ2hlY2tib3hlcyB8IFdoZXJlLU9iamVjdCB7ICRfLklzQ2hlY2tlZCAtZXEgJHRydWUgfSB8IEZvckVhY2gtT2JqZWN0IHsgJF8uVGFnIH0pCiAgICAgICAgICAgICAgICBUd2Vha1NlbGVjdGlvbnMgPSBAKCR0d2Vha0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0gfCBGb3JFYWNoLU9iamVjdCB7ICRfLlRhZyB9KQogICAgICAgICAgICAgICAgRmVhdHVyZVNlbGVjdGlvbnMgPSBAKCRmZWF0dXJlc0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0gfCBGb3JFYWNoLU9iamVjdCB7ICRfLlRhZyB9KQogICAgICAgICAgICB9CiAgICAgICAgICAgICRwcmVmU3RhdGUgPSBAe30KICAgICAgICAgICAgZm9yZWFjaCAoJHBrIGluICRwcmVmQ2hlY2tib3hlcy5LZXlzKSB7CiAgICAgICAgICAgICAgICBpZiAoJHByZWZDaGVja2JveGVzWyRwa10pIHsgJHByZWZTdGF0ZVskcGtdID0gKCRwcmVmQ2hlY2tib3hlc1skcGtdLklzQ2hlY2tlZCAtZXEgJHRydWUpIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAkZGF0YS5QcmVmZXJlbmNlU3RhdGVzID0gJHByZWZTdGF0ZQogICAgICAgICAgICAkanNvbiA9ICRkYXRhIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDUKICAgICAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRzZmQuRmlsZU5hbWUsICRqc29uLCBbU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nXTo6bmV3KCRmYWxzZSkpCiAgICAgICAgICAgIFdyaXRlLUxvZyAiRXhwb3J0ZWQgdG8gJCgkc2ZkLkZpbGVOYW1lKSIgIlN1Y2Nlc3MiCiAgICAgICAgICAgIFNob3ctSW5mbyAiRXhwb3J0IENvbXBsZXRlIiAiQ29uZmlnIGV4cG9ydGVkIHRvOmBuJCgkc2ZkLkZpbGVOYW1lKSIKICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJFeHBvcnQgZmFpbGVkOiAkXyIgIkVycm9yIiB9CiAgICAgICAgaWYgKCRzeW5jLmNvbnRyb2xzWyJCdG5Ub29sYmFyU2V0dGluZ3MiXSkgeyAkc3luYy5jb250cm9sc1siQnRuVG9vbGJhclNldHRpbmdzIl0uSXNDaGVja2VkID0gJGZhbHNlIH0KICAgIH0pCn0KCmlmICgkc3luYy5jb250cm9sc1siQnRuR2VhckltcG9ydCJdKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuR2VhckltcG9ydCJdLkFkZF9DbGljayh7CiAgICAgICAgJG9mZCA9IE5ldy1PYmplY3QgTWljcm9zb2Z0LldpbjMyLk9wZW5GaWxlRGlhbG9nCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJG9mZC5GaWx0ZXIgPSAiSlNPTiBDb25maWcgKCouanNvbil8Ki5qc29ufEFsbCBGaWxlcyAoKi4qKXwqLioiCiAgICAgICAgICAgICRvZmQuVGl0bGUgPSAiSW1wb3J0IENvbmZpZyIKICAgICAgICAgICAgJG9mZC5Jbml0aWFsRGlyZWN0b3J5ID0gW0Vudmlyb25tZW50XTo6R2V0Rm9sZGVyUGF0aCgiRGVza3RvcCIpCiAgICAgICAgICAgICRyZXN1bHQgPSAkb2ZkLlNob3dEaWFsb2coJHN5bmMud2luZG93KQogICAgICAgICAgICBpZiAoJHJlc3VsdCAtbmUgJHRydWUpIHsgcmV0dXJuIH0KICAgICAgICAgICAgJGpzb24gPSBbU3lzdGVtLklPLkZpbGVdOjpSZWFkQWxsVGV4dCgkb2ZkLkZpbGVOYW1lLCBbU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nXTo6bmV3KCRmYWxzZSkpCiAgICAgICAgICAgICRkYXRhID0gJGpzb24gfCBDb252ZXJ0RnJvbS1Kc29uCgogICAgICAgICAgICAjIE5FVyBmb3JtYXQ6IEFwcFNlbGVjdGlvbnMgKGFycmF5IG9mIHdpbmdldCBJRHMpCiAgICAgICAgICAgIGlmICgkZGF0YS5BcHBTZWxlY3Rpb25zKSB7CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkYWlkIGluICRkYXRhLkFwcFNlbGVjdGlvbnMpIHsKICAgICAgICAgICAgICAgICAgICAkY2IgPSAkYXBwQ2hlY2tib3hlcyB8IFdoZXJlLU9iamVjdCB7ICRfLlRhZyAtZXEgJGFpZCB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRjYikgeyAkY2IuSXNDaGVja2VkID0gJHRydWUgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICMgT0xEIGZvcm1hdDogQ2hlY2tlZEFwcHMgKGFycmF5IG9mIHtOYW1lLCBDb250ZW50fSkKICAgICAgICAgICAgaWYgKCRkYXRhLkNoZWNrZWRBcHBzKSB7CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkYXBwRW50cnkgaW4gJGRhdGEuQ2hlY2tlZEFwcHMpIHsKICAgICAgICAgICAgICAgICAgICAkY2IgPSAkYXBwQ2hlY2tib3hlcyB8IFdoZXJlLU9iamVjdCB7ICRfLlRhZyAtZXEgJGFwcEVudHJ5Lk5hbWUgfQogICAgICAgICAgICAgICAgICAgIGlmICgkY2IpIHsgJGNiLklzQ2hlY2tlZCA9ICR0cnVlIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQoKICAgICAgICAgICAgIyBORVcgZm9ybWF0OiBUd2Vha1NlbGVjdGlvbnMgKGFycmF5IG9mIGtleXMpCiAgICAgICAgICAgIGlmICgkZGF0YS5Ud2Vha1NlbGVjdGlvbnMpIHsKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCR0ayBpbiAkZGF0YS5Ud2Vha1NlbGVjdGlvbnMpIHsKICAgICAgICAgICAgICAgICAgICAkY2IgPSAkdHdlYWtDaGVja2JveGVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uVGFnIC1lcSAkdGsgfQogICAgICAgICAgICAgICAgICAgIGlmICgkY2IpIHsgJGNiLklzQ2hlY2tlZCA9ICR0cnVlIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAjIE9MRCBmb3JtYXQ6IENoZWNrZWRUd2Vha3MgKGFycmF5IG9mIHtOYW1lLCBDb250ZW50fSkKICAgICAgICAgICAgaWYgKCRkYXRhLkNoZWNrZWRUd2Vha3MpIHsKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCR0d2Vha0VudHJ5IGluICRkYXRhLkNoZWNrZWRUd2Vha3MpIHsKICAgICAgICAgICAgICAgICAgICAkY2IgPSAkdHdlYWtDaGVja2JveGVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uVGFnIC1lcSAkdHdlYWtFbnRyeS5OYW1lIH0KICAgICAgICAgICAgICAgICAgICBpZiAoJGNiKSB7ICRjYi5Jc0NoZWNrZWQgPSAkdHJ1ZSB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KCiAgICAgICAgICAgIGlmICgkZGF0YS5GZWF0dXJlU2VsZWN0aW9ucykgewogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGZrIGluICRkYXRhLkZlYXR1cmVTZWxlY3Rpb25zKSB7CiAgICAgICAgICAgICAgICAgICAgJGNiID0gJGZlYXR1cmVzQ2hlY2tib3hlcyB8IFdoZXJlLU9iamVjdCB7ICRfLlRhZyAtZXEgJGZrIH0KICAgICAgICAgICAgICAgICAgICBpZiAoJGNiKSB7ICRjYi5Jc0NoZWNrZWQgPSAkdHJ1ZSB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KCiAgICAgICAgICAgIGlmICgkZGF0YS5QcmVmZXJlbmNlU3RhdGVzKSB7CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcGsgaW4gJGRhdGEuUHJlZmVyZW5jZVN0YXRlcy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpIHsKICAgICAgICAgICAgICAgICAgICBpZiAoJHByZWZDaGVja2JveGVzWyRwa10pIHsgJHByZWZDaGVja2JveGVzWyRwa10uSXNDaGVja2VkID0gJGRhdGEuUHJlZmVyZW5jZVN0YXRlcy4kcGsgLWVxICR0cnVlIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQoKICAgICAgICAgICAgV3JpdGUtTG9nICJJbXBvcnRlZCBmcm9tICQoJG9mZC5GaWxlTmFtZSkiICJTdWNjZXNzIgogICAgICAgICAgICBTaG93LUluZm8gIkltcG9ydCBDb21wbGV0ZSIgIkNvbmZpZ3VyYXRpb24gaW1wb3J0ZWQuIgogICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkltcG9ydCBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgICAgICBpZiAoJHN5bmMuY29udHJvbHNbIkJ0blRvb2xiYXJTZXR0aW5ncyJdKSB7ICRzeW5jLmNvbnRyb2xzWyJCdG5Ub29sYmFyU2V0dGluZ3MiXS5Jc0NoZWNrZWQgPSAkZmFsc2UgfQogICAgfSkKfQoKaWYgKCRzeW5jLmNvbnRyb2xzWyJCdG5HZWFyQWJvdXQiXSkgewogICAgJHN5bmMuY29udHJvbHNbIkJ0bkdlYXJBYm91dCJdLkFkZF9DbGljayh7CiAgICAgICAgU2hvdy1JbmZvICJBYm91dCBIa3NVdGlsIHYyLjAiICJIa3NVdGlsIHYyLjAgLSBXaW5kb3dzIE9wdGltaXplcmBuYG5BIFdpbmRvd3MgdXRpbGl0eSBmb3IgYXBwbGljYXRpb24gbWFuYWdlbWVudCwgc3lzdGVtIHR3ZWFrcywgRE5TIGNvbmZpZ3VyYXRpb24sIGFuZCBtb3JlLmBuYG5CdWlsdCB3aXRoIFBvd2VyU2hlbGwgYW5kIFdQRi4iCiAgICAgICAgaWYgKCRzeW5jLmNvbnRyb2xzWyJCdG5Ub29sYmFyU2V0dGluZ3MiXSkgeyAkc3luYy5jb250cm9sc1siQnRuVG9vbGJhclNldHRpbmdzIl0uSXNDaGVja2VkID0gJGZhbHNlIH0KICAgIH0pCn0KCmlmICgkc3luYy5jb250cm9sc1siQnRuR2VhckRvY3MiXSkgewogICAgJHN5bmMuY29udHJvbHNbIkJ0bkdlYXJEb2NzIl0uQWRkX0NsaWNrKHsKICAgICAgICBTdGFydC1Qcm9jZXNzICJodHRwczovL2dpdGh1Yi5jb20vaGFydGtpdHNhay9Ia3NVdGlsIgogICAgICAgIGlmICgkc3luYy5jb250cm9sc1siQnRuVG9vbGJhclNldHRpbmdzIl0pIHsgJHN5bmMuY29udHJvbHNbIkJ0blRvb2xiYXJTZXR0aW5ncyJdLklzQ2hlY2tlZCA9ICRmYWxzZSB9CiAgICB9KQp9CgppZiAoJHN5bmMuY29udHJvbHNbIkJ0bkdlYXJTcG9uc29ycyJdKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuR2VhclNwb25zb3JzIl0uQWRkX0NsaWNrKHsKICAgICAgICBTaG93LUluZm8gIlNwb25zb3JzIiAiSGtzVXRpbCBpcyBhbiBvcGVuLXNvdXJjZSBwcm9qZWN0LmBuYG5JZiB5b3UgZmluZCB0aGlzIHRvb2wgdXNlZnVsLCBjb25zaWRlciBzdXBwb3J0aW5nIHRoZSBwcm9qZWN0LiIKICAgICAgICBpZiAoJHN5bmMuY29udHJvbHNbIkJ0blRvb2xiYXJTZXR0aW5ncyJdKSB7ICRzeW5jLmNvbnRyb2xzWyJCdG5Ub29sYmFyU2V0dGluZ3MiXS5Jc0NoZWNrZWQgPSAkZmFsc2UgfQogICAgfSkKfQo='))
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

if ($sync.controls["BtnToolbarTheme"]) {
    $sync.controls["BtnToolbarTheme"].Add_Click({
        if ($script:currentTheme -eq "dark") { Apply-Theme "light" } else { Apply-Theme "dark" }
    })
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
        if ($sync.controls["BtnToolbarSettings"]) { $sync.controls["BtnToolbarSettings"].IsChecked = $false }
    })
}

if ($sync.controls["BtnGearAbout"]) {
    $sync.controls["BtnGearAbout"].Add_Click({
        Show-Info "About HksUtil v2.0" "HksUtil v2.0 - Windows Optimizer`n`nA Windows utility for application management, system tweaks, DNS configuration, and more.`n`nBuilt with PowerShell and WPF."
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

$script:__mod_dns = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpkbnNOYW1lcyA9IEAoKQokc2NyaXB0OmRuc1JhZGlvQnV0dG9ucyA9IEB7fQoKaWYgKCRzeW5jLmNvbnRyb2xzWyJEbnNSYWRpb1BhbmVsIl0gLWFuZCAkc3luYy5jb25maWdzLmRucykgewogICAgJHNjcmlwdDpkbnNOYW1lcyA9IEAoJHN5bmMuY29uZmlncy5kbnMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKQogICAgJHNjcmlwdDpkbnNSYWRpb0J1dHRvbnMgPSBAe30KICAgICRpc0ZpcnN0ID0gJHRydWUKICAgIGZvcmVhY2ggKCRkbnNOYW1lIGluICRzY3JpcHQ6ZG5zTmFtZXMpIHsKICAgICAgICAkZG5zID0gJHN5bmMuY29uZmlncy5kbnMuJGRuc05hbWUKICAgICAgICBpZiAoLW5vdCAkZG5zKSB7IGNvbnRpbnVlIH0KICAgICAgICAkcmIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlJhZGlvQnV0dG9uCiAgICAgICAgJHJiLlRhZyA9ICRkbnNOYW1lOyAkcmIuU3R5bGUgPSBHZXQtV3BmUmVzb3VyY2UgIkRuc0NhcmRTdHlsZSI7ICRyYi5Hcm91cE5hbWUgPSAiRG5zUHJvdmlkZXIiCiAgICAgICAgJHNwID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5TdGFja1BhbmVsOyAkc3AuT3JpZW50YXRpb24gPSAiSG9yaXpvbnRhbCI7ICRzcC5WZXJ0aWNhbEFsaWdubWVudCA9ICJDZW50ZXIiCiAgICAgICAgJG5hbWVUYiA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrOyAkbmFtZVRiLlRleHQgPSAiJGRuc05hbWUgLSAkKCRkbnMuZGVzY3JpcHRpb24pIjsgJG5hbWVUYi5Gb250U2l6ZSA9IDEyOyAkbmFtZVRiLkZvbnRXZWlnaHQgPSAiU2VtaUJvbGQiOyAkbmFtZVRiLlZlcnRpY2FsQWxpZ25tZW50ID0gIkNlbnRlciI7ICRuYW1lVGIuU2V0UmVzb3VyY2VSZWZlcmVuY2UoW1N5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9ja106OkZvcmVncm91bmRQcm9wZXJ0eSwgInBhZ2VUaXRsZUNvbG9yIikKICAgICAgICAkc3AuQ2hpbGRyZW4uQWRkKCRuYW1lVGIpIHwgT3V0LU51bGwKICAgICAgICAkaXBUYiA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrOyAkaXBEaXNwbGF5ID0gaWYgKCRkbnMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiaXB2NCIgLWFuZCAkZG5zLmlwdjQuQ291bnQgLWd0IDApIHsgJGRucy5pcHY0IC1qb2luICIsICIgfSBlbHNlIHsgIkF1dG8gKERIQ1ApIiB9OyAkaXBUYi5UZXh0ID0gIiAgJGlwRGlzcGxheSI7ICRpcFRiLkZvbnRTaXplID0gMTA7ICRpcFRiLkZvbnRGYW1pbHkgPSAiQ29uc29sYXMiOyAkaXBUYi5WZXJ0aWNhbEFsaWdubWVudCA9ICJDZW50ZXIiOyAkaXBUYi5TZXRSZXNvdXJjZVJlZmVyZW5jZShbU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrXTo6Rm9yZWdyb3VuZFByb3BlcnR5LCAidGV4dE11dGVkIikKICAgICAgICAkc3AuQ2hpbGRyZW4uQWRkKCRpcFRiKSB8IE91dC1OdWxsCiAgICAgICAgJHJiLkNvbnRlbnQgPSAkc3AKICAgICAgICAkcmIuQWRkX0NoZWNrZWQoeyBXcml0ZS1Mb2cgIkROUyBzZWxlY3RlZDogJCgkdGhpcy5UYWcpIiAiSW5mbyIgfSkKICAgICAgICAkbnVsbCA9ICRzeW5jLmNvbnRyb2xzWyJEbnNSYWRpb1BhbmVsIl0uQ2hpbGRyZW4uQWRkKCRyYikKICAgICAgICAkc2NyaXB0OmRuc1JhZGlvQnV0dG9uc1skZG5zTmFtZV0gPSAkcmIKICAgICAgICBpZiAoJGlzRmlyc3QpIHsgJHJiLklzQ2hlY2tlZCA9ICR0cnVlOyAkaXNGaXJzdCA9ICRmYWxzZSB9CiAgICB9CiAgICBXcml0ZS1Mb2cgIkJ1aWx0ICQoJHNjcmlwdDpkbnNOYW1lcy5Db3VudCkgRE5TIHJhZGlvIGJ1dHRvbnMuIiAiU3VjY2VzcyIKfQoKaWYgKCRzeW5jLmNvbnRyb2xzWyJCdG5BcHBseURucyJdKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuQXBwbHlEbnMiXS5BZGRfQ2xpY2soewogICAgICAgICRzZWxlY3RlZFJiID0gJHNjcmlwdDpkbnNSYWRpb0J1dHRvbnMuVmFsdWVzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSXNDaGVja2VkIC1lcSAkdHJ1ZSB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgIGlmICgtbm90ICRzZWxlY3RlZFJiKSB7IFdyaXRlLUxvZyAiTm8gRE5TIHByb3ZpZGVyIHNlbGVjdGVkLiIgIldhcm4iOyByZXR1cm4gfQogICAgICAgICRkbnNOYW1lID0gJHNlbGVjdGVkUmIuVGFnCiAgICAgICAgJGRucyA9ICRzeW5jLmNvbmZpZ3MuZG5zLiRkbnNOYW1lCiAgICAgICAgJGlwdjQgPSBpZiAoJGRucy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJpcHY0IikgeyAkZG5zLmlwdjQgfSBlbHNlIHsgQCgpIH0KICAgICAgICBpZiAoJGRuc05hbWUgLWVxICJEZWZhdWx0X0RIQ1AiKSB7CiAgICAgICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIlJlc2V0IEROUyIgIlJlc2V0IEROUyB0byBkZWZhdWx0IERIQ1Agb24gYWxsIGFkYXB0ZXJzPyIpKSB7IHJldHVybiB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUmVzZXR0aW5nIEROUyB0byBESENQLi4uIiAiSW5mbyIKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRhZGFwdGVycyA9IEdldC1OZXRBZGFwdGVyIC1QaHlzaWNhbCB8IFdoZXJlLU9iamVjdCB7ICRfLlN0YXR1cyAtZXEgJ1VwJyB9CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkYWRhcHRlcnMpIHsgV3JpdGUtTG9nICJObyBhY3RpdmUgbmV0d29yayBhZGFwdGVyIGZvdW5kLiIgIkVycm9yIjsgcmV0dXJuIH0KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRhZGFwdGVyIGluICRhZGFwdGVycykgeyBTZXQtRG5zQ2xpZW50U2VydmVyQWRkcmVzcyAtSW50ZXJmYWNlSW5kZXggJGFkYXB0ZXIuaWZJbmRleCAtUmVzZXRTZXJ2ZXJBZGRyZXNzZXMgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJETlMgcmVzZXQgdG8gREhDUCBvbiAkKCRhZGFwdGVycy5Db3VudCkgYWRhcHRlcihzKS4iICJTdWNjZXNzIgogICAgICAgICAgICAgICAgU2hvdy1JbmZvICJETlMgUmVzZXQiICJETlMgaGFzIGJlZW4gcmVzZXQgdG8gREhDUC4iCiAgICAgICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkZhaWxlZCB0byByZXNldCBETlM6ICRfIiAiRXJyb3IiIH0KICAgICAgICAgICAgcmV0dXJuCiAgICAgICAgfQogICAgICAgIGlmICgtbm90IChTaG93LUNvbmZpcm0gIkFwcGx5IEROUyIgIlNldCBETlMgdG8gJGRuc05hbWU/YG5gbklQdjQ6ICQoJGlwdjQgLWpvaW4gJywgJykiKSApIHsgcmV0dXJuIH0KICAgICAgICBXcml0ZS1Mb2cgIlNldHRpbmcgRE5TIHRvICRkbnNOYW1lLi4uIiAiSW5mbyIKICAgICAgICB0cnkgewogICAgICAgICAgICAkYWRhcHRlcnMgPSBHZXQtTmV0QWRhcHRlciAtUGh5c2ljYWwgfCBXaGVyZS1PYmplY3QgeyAkXy5TdGF0dXMgLWVxICdVcCcgfQogICAgICAgICAgICBpZiAoLW5vdCAkYWRhcHRlcnMpIHsgV3JpdGUtTG9nICJObyBhY3RpdmUgbmV0d29yayBhZGFwdGVyIGZvdW5kLiIgIkVycm9yIjsgcmV0dXJuIH0KICAgICAgICAgICAgJGlwdjYgPSBpZiAoJGRucy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICJpcHY2IikgeyAkZG5zLmlwdjYgfSBlbHNlIHsgQCgpIH0KICAgICAgICAgICAgZm9yZWFjaCAoJGFkYXB0ZXIgaW4gJGFkYXB0ZXJzKSB7CiAgICAgICAgICAgICAgICBTZXQtRG5zQ2xpZW50U2VydmVyQWRkcmVzcyAtSW50ZXJmYWNlSW5kZXggJGFkYXB0ZXIuaWZJbmRleCAtU2VydmVyQWRkcmVzc2VzICgkaXB2NCArICRpcHY2KQogICAgICAgICAgICB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiRE5TIHNldCB0byAkZG5zTmFtZSBvbiAkKCRhZGFwdGVycy5Db3VudCkgYWRhcHRlcihzKS4iICJTdWNjZXNzIgogICAgICAgICAgICBTaG93LUluZm8gIkROUyBBcHBsaWVkIiAiRE5TIGhhcyBiZWVuIHNldCB0byAkZG5zTmFtZS5gbmBuSVB2NDogJCgkaXB2NCAtam9pbiAnLCAnKSIKICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgV3JpdGUtTG9nICJGYWlsZWQgdG8gc2V0IEROUzogJF8iICJFcnJvciIKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRhZGFwdGVycyA9IEdldC1OZXRBZGFwdGVyIC1QaHlzaWNhbCB8IFdoZXJlLU9iamVjdCB7ICRfLlN0YXR1cyAtZXEgJ1VwJyB9CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkYWRhcHRlcnMpIHsgV3JpdGUtTG9nICJObyBhY3RpdmUgYWRhcHRlciBmb3IgbmV0c2guIiAiRXJyb3IiOyByZXR1cm4gfQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGFkYXB0ZXIgaW4gJGFkYXB0ZXJzKSB7CiAgICAgICAgICAgICAgICAgICAgJGlmTmFtZSA9ICRhZGFwdGVyLk5hbWUKICAgICAgICAgICAgICAgICAgICBpZiAoJGlwdjQuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICAgICAgICAgbmV0c2ggaW50ZXJmYWNlIGlwIHNldCBkbnMgIiRpZk5hbWUiIHN0YXRpYyAkKCRpcHY0WzBdKQogICAgICAgICAgICAgICAgICAgICAgICBmb3IgKCRpID0gMTsgJGkgLWx0ICRpcHY0LkNvdW50OyAkaSsrKSB7IG5ldHNoIGludGVyZmFjZSBpcCBhZGQgZG5zICIkaWZOYW1lIiAkKCRpcHY0WyRpXSkgaW5kZXg9JCgkaSsxKSB9CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJETlMgc2V0IHZpYSBuZXRzaCBmYWxsYmFjay4iICJTdWNjZXNzIgogICAgICAgICAgICAgICAgU2hvdy1JbmZvICJETlMgQXBwbGllZCIgIkROUyBzZXQgdmlhIG5ldHNoLmBuJGRuc05hbWUgKCQoJGlwdjQgLWpvaW4gJywgJykpIgogICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJuZXRzaCBmYWxsYmFjayBhbHNvIGZhaWxlZDogJF8iICJFcnJvciIgfQogICAgICAgIH0KICAgIH0pCn0K'))
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

$script:__mod_terminal = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aWYgKCRzeW5jLmNvbnRyb2xzWyJCdG5UZXJtaW5hbERvdGZpbGVzIl0pIHsKICAgICRzeW5jLmNvbnRyb2xzWyJCdG5UZXJtaW5hbERvdGZpbGVzIl0uQWRkX0NsaWNrKHsKICAgICAgICBXcml0ZS1Mb2cgIkluc3RhbGxpbmcgTm92YSBwcm9maWxlLi4uIiAiSW5mbyIKICAgICAgICB0cnkgewogICAgICAgICAgICAkdG1wID0gIiRlbnY6VEVNUFxub3ZhLWluc3RhbGwucHMxIgogICAgICAgICAgICBJbnZva2UtV2ViUmVxdWVzdCAtVXJpICJodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vaGFydGtpdHNhay9ub3ZhL21hc3Rlci9pbnN0YWxsLnBzMSIgLU91dEZpbGUgJHRtcCAtVXNlQmFzaWNQYXJzaW5nCiAgICAgICAgICAgICYgJHRtcAogICAgICAgICAgICBSZW1vdmUtSXRlbSAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICBXcml0ZS1Mb2cgIk5vdmEgaW5zdGFsbCBjb21wbGV0ZS4iICJTdWNjZXNzIgogICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIk5vdmEgaW5zdGFsbCBmYWlsZWQ6ICRfIiAiRXJyb3IiIH0KICAgIH0pCn0KCmlmICgkc3luYy5jb250cm9sc1siQnRuVW5pbnN0YWxsVGVybWluYWwiXSkgewogICAgJHN5bmMuY29udHJvbHNbIkJ0blVuaW5zdGFsbFRlcm1pbmFsIl0uQWRkX0NsaWNrKHsKICAgICAgICBXcml0ZS1Mb2cgIlVuaW5zdGFsbGluZyBOb3ZhIHByb2ZpbGUuLi4iICJJbmZvIgogICAgICAgIHRyeSB7CiAgICAgICAgICAgICR0bXAgPSAiJGVudjpURU1QXG5vdmEtdW5pbnN0YWxsLnBzMSIKICAgICAgICAgICAgSW52b2tlLVdlYlJlcXVlc3QgLVVyaSAiaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2hhcnRraXRzYWsvbm92YS9tYXN0ZXIvdW5pbnN0YWxsLnBzMSIgLU91dEZpbGUgJHRtcCAtVXNlQmFzaWNQYXJzaW5nCiAgICAgICAgICAgICYgJHRtcAogICAgICAgICAgICBSZW1vdmUtSXRlbSAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICBXcml0ZS1Mb2cgIk5vdmEgdW5pbnN0YWxsIGNvbXBsZXRlLiIgIlN1Y2Nlc3MiCiAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiTm92YSB1bmluc3RhbGwgZmFpbGVkOiAkXyIgIkVycm9yIiB9CiAgICB9KQp9Cg=='))
if ($sync.controls["BtnTerminalDotfiles"]) {
    $sync.controls["BtnTerminalDotfiles"].Add_Click({
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

if ($sync.controls["BtnUninstallTerminal"]) {
    $sync.controls["BtnUninstallTerminal"].Add_Click({
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

$script:__mod_utility = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpkZXNrdG9wU2hvcnRjdXRQYXRoID0gSm9pbi1QYXRoIChbRW52aXJvbm1lbnRdOjpHZXRGb2xkZXJQYXRoKCJEZXNrdG9wIikpICJIa3NVdGlsLmxuayIKCmlmICgkc3luYy5jb250cm9sc1siQnRuQ3JlYXRlU2hvcnRjdXQiXSkgewogICAgJHN5bmMuY29udHJvbHNbIkJ0bkNyZWF0ZVNob3J0Y3V0Il0uQWRkX0NsaWNrKHsKICAgICAgICAkbG5rUGF0aCA9ICRzY3JpcHQ6ZGVza3RvcFNob3J0Y3V0UGF0aAogICAgICAgIGlmIChUZXN0LVBhdGggJGxua1BhdGgpIHsgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiT3ZlcndyaXRlPyIgIlNob3J0Y3V0IGV4aXN0cy4gT3ZlcndyaXRlPyIpKSB7IHJldHVybiB9IH0KICAgICAgICB0cnkgewogICAgICAgICAgICAkd3NoZWxsID0gTmV3LU9iamVjdCAtQ29tT2JqZWN0IFdTY3JpcHQuU2hlbGwKICAgICAgICAgICAgJHNob3J0Y3V0ID0gJHdzaGVsbC5DcmVhdGVTaG9ydGN1dCgkbG5rUGF0aCkKICAgICAgICAgICAgJHB3c2hQYXRoID0gKEdldC1Db21tYW5kIHBvd2Vyc2hlbGwuZXhlKS5Tb3VyY2UKICAgICAgICAgICAgJHNob3J0Y3V0LlRhcmdldFBhdGggPSAkcHdzaFBhdGgKICAgICAgICAgICAgJHNob3J0Y3V0LkFyZ3VtZW50cyA9ICItRXhlY3V0aW9uUG9saWN5IFJlbW90ZVNpZ25lZCAtTm9Qcm9maWxlIC1GaWxlIGAiJCgkc3luYy5hcHBSb290KVxhcHAucHMxYCIiCiAgICAgICAgICAgICRzaG9ydGN1dC5EZXNjcmlwdGlvbiA9ICJIa3NVdGlsIHYyLjAgLSBXaW5kb3dzIE9wdGltaXplciIKICAgICAgICAgICAgJHNob3J0Y3V0Lkljb25Mb2NhdGlvbiA9ICIkKFtFbnZpcm9ubWVudF06OlN5c3RlbURpcmVjdG9yeSlcc2hlbGwzMi5kbGwsIDEiCiAgICAgICAgICAgICRzaG9ydGN1dC5TYXZlKCkKICAgICAgICAgICAgV3JpdGUtTG9nICJEZXNrdG9wIHNob3J0Y3V0IGNyZWF0ZWQuIiAiU3VjY2VzcyIKICAgICAgICAgICAgU2hvdy1JbmZvICJTaG9ydGN1dCBDcmVhdGVkIiAiRGVza3RvcCBzaG9ydGN1dCBjcmVhdGVkLmBuJGxua1BhdGgiCiAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiU2hvcnRjdXQgY3JlYXRpb24gZmFpbGVkOiAkXyIgIkVycm9yIjsgU2hvdy1JbmZvICJTaG9ydGN1dCBGYWlsZWQiICJFcnJvcjogJF8iIH0KICAgICAgICBmaW5hbGx5IHsgaWYgKCR3c2hlbGwpIHsgW1N5c3RlbS5SdW50aW1lLkludGVyb3BzZXJ2aWNlcy5NYXJzaGFsXTo6UmVsZWFzZUNvbU9iamVjdCgkd3NoZWxsKSB8IE91dC1OdWxsIH0gfQogICAgfSkKfQo='))
$script:desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "HksUtil.lnk"

if ($sync.controls["BtnCreateShortcut"]) {
    $sync.controls["BtnCreateShortcut"].Add_Click({
        $lnkPath = $script:desktopShortcutPath
        if (Test-Path $lnkPath) { if (-not (Show-Confirm "Overwrite?" "Shortcut exists. Overwrite?")) { return } }
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $shortcut = $wshell.CreateShortcut($lnkPath)
            $pwshPath = (Get-Command powershell.exe).Source
            $shortcut.TargetPath = $pwshPath
            $shortcut.Arguments = "-ExecutionPolicy RemoteSigned -NoProfile -File `"$($sync.appRoot)\app.ps1`""
            $shortcut.Description = "HksUtil v2.0 - Windows Optimizer"
            $shortcut.IconLocation = "$([Environment]::SystemDirectory)\shell32.dll, 1"
            $shortcut.Save()
            Write-Log "Desktop shortcut created." "Success"
            Show-Info "Shortcut Created" "Desktop shortcut created.`n$lnkPath"
        } catch { Write-Log "Shortcut creation failed: $_" "Error"; Show-Info "Shortcut Failed" "Error: $_" }
        finally { if ($wshell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null } }
    })
}

$script:__mod_build = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JGFwcENoZWNrYm94ZXMgPSBAKCkKJHR3ZWFrQ2hlY2tib3hlcyA9IEAoKQokZmVhdHVyZXNDaGVja2JveGVzID0gQCgpCiRwcmVmQ2hlY2tib3hlcyA9IEB7fQokYXBwUGFuZWxzID0gQCgpCiRzY3JpcHQ6Y2F0ZWdvcnlJdGVtcyA9IEB7fQokc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkID0gQHt9CgojIC0tLSBCdWlsZCBBcHBzIFVJIC0tLQokYXBwUGFuZWxJbmRleCA9IDAKaWYgKCgkc3luYy5jb250cm9sc1siQXBwUGFuZWwxIl0gLWFuZCAkc3luYy5jb250cm9sc1siQXBwUGFuZWwyIl0gLWFuZCAkc3luYy5jb250cm9sc1siQXBwUGFuZWwzIl0pIC1hbmQgJHN5bmMuY29uZmlncy5hcHBzKSB7CiAgICAkYXBwUGFuZWxzID0gQCgkc3luYy5jb250cm9sc1siQXBwUGFuZWwxIl0sICRzeW5jLmNvbnRyb2xzWyJBcHBQYW5lbDIiXSwgJHN5bmMuY29udHJvbHNbIkFwcFBhbmVsMyJdKQogICAgZm9yZWFjaCAoJGNhdGVnb3J5IGluICRzeW5jLmNvbmZpZ3MuYXBwcy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpIHsKICAgICAgICAkY2F0Q291bnQgPSAoJHN5bmMuY29uZmlncy5hcHBzLiRjYXRlZ29yeS5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUpLkNvdW50CiAgICAgICAgJGhlYWRlciA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrCiAgICAgICAgJGhlYWRlci5UZXh0ID0gIi0gJCgkY2F0ZWdvcnkuVG9VcHBlcigpKSAoJGNhdENvdW50KSI7ICRoZWFkZXIuU3R5bGUgPSBHZXQtV3BmUmVzb3VyY2UgIkNhdGVnb3J5SGVhZGVyIjsgJGhlYWRlci5DdXJzb3IgPSAiSGFuZCIKICAgICAgICAkaGVhZGVyLlRhZyA9ICRjYXRlZ29yeQogICAgICAgICRhcHBQYW5lbHNbJGFwcFBhbmVsSW5kZXhdLkNoaWxkcmVuLkFkZCgkaGVhZGVyKSB8IE91dC1OdWxsCiAgICAgICAgJHNjcmlwdDpjYXRlZ29yeUl0ZW1zWyRjYXRlZ29yeV0gPSBAKCkKICAgICAgICAkaGVhZGVyLkFkZF9Nb3VzZUxlZnRCdXR0b25Eb3duKHsKICAgICAgICAgICAgJGNhdCA9ICR0aGlzLlRhZwogICAgICAgICAgICAkY29sbGFwc2VkID0gJHNjcmlwdDpjYXRlZ29yeUNvbGxhcHNlZFskY2F0XQogICAgICAgICAgICAkc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkWyRjYXRdID0gLW5vdCAkY29sbGFwc2VkCiAgICAgICAgICAgIGZvcmVhY2ggKCRpdGVtIGluICRzY3JpcHQ6Y2F0ZWdvcnlJdGVtc1skY2F0XSkgewogICAgICAgICAgICAgICAgJGl0ZW0uVmlzaWJpbGl0eSA9IGlmICgkc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkWyRjYXRdKSB7ICJDb2xsYXBzZWQiIH0gZWxzZSB7ICJWaXNpYmxlIiB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJHRoaXMuVGV4dCA9IGlmICgkc2NyaXB0OmNhdGVnb3J5Q29sbGFwc2VkWyRjYXRdKSB7ICIrICQoJGNhdC5Ub1VwcGVyKCkpICgkKCRzY3JpcHQ6Y2F0ZWdvcnlJdGVtc1skY2F0XS5Db3VudCkpIiB9IGVsc2UgeyAiLSAkKCRjYXQuVG9VcHBlcigpKSAoJCgkc2NyaXB0OmNhdGVnb3J5SXRlbXNbJGNhdF0uQ291bnQpKSIgfQogICAgICAgIH0pCiAgICAgICAgZm9yZWFjaCAoJGFwcEtleSBpbiAkc3luYy5jb25maWdzLmFwcHMuJGNhdGVnb3J5LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICAgICAkYXBwID0gJHN5bmMuY29uZmlncy5hcHBzLiRjYXRlZ29yeS4kYXBwS2V5CiAgICAgICAgICAgICRjYiA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuQ2hlY2tCb3gKICAgICAgICAgICAgJGNiLkNvbnRlbnQgPSAkYXBwLmNvbnRlbnQ7ICRjYi5UYWcgPSAkYXBwLndpbmdldDsgJGNiLlN0eWxlID0gR2V0LVdwZlJlc291cmNlICJUd2Vha0NoZWNrQm94IgogICAgICAgICAgICBpZiAoJGFwcC5kZXNjcmlwdGlvbikgeyAkY2IuVG9vbFRpcCA9ICIkKCRhcHAuY29udGVudClgbmBuJCgkYXBwLmRlc2NyaXB0aW9uKWBuYG5JRDogJCgkYXBwLndpbmdldCkiIH0KICAgICAgICAgICAgJGNiLkFkZF9DaGVja2VkKHsgVXBkYXRlLVNlbGVjdGVkQ291bnQgfSkKICAgICAgICAgICAgJGNiLkFkZF9VbmNoZWNrZWQoeyBVcGRhdGUtU2VsZWN0ZWRDb3VudCB9KQogICAgICAgICAgICAkY20gPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkNvbnRleHRNZW51CiAgICAgICAgICAgICRtaUluc3RhbGwgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLk1lbnVJdGVtOyAkbWlJbnN0YWxsLkhlYWRlciA9ICJJbnN0YWxsIjsgJG1pSW5zdGFsbC5UYWcgPSAkYXBwLndpbmdldAogICAgICAgICAgICAkbWlJbnN0YWxsLkFkZF9DbGljayh7CiAgICAgICAgICAgICAgICAkaWQgPSAkdGhpcy5UYWc7ICRwa2cgPSAkc2NyaXB0OnBrZ01hbmFnZXI7IFdyaXRlLUxvZyAiQ29udGV4dDogSW5zdGFsbCAkaWQgdmlhICRwa2ciICJJbmZvIgogICAgICAgICAgICAgICAgaWYgKC1ub3QgKEVuc3VyZS1QYWNrYWdlTWFuYWdlciAkcGtnKSkgeyBTaG93LUluZm8gIkVycm9yIiAiRmFpbGVkIHRvIGVuc3VyZSAkcGtnLiI7IHJldHVybiB9CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAoU2hvdy1Db25maXJtICJJbnN0YWxsIiAiSW5zdGFsbCAkaWQgdmlhICRwa2c/IikpIHsgcmV0dXJuIH0KICAgICAgICAgICAgICAgIFNob3ctUHJvZ3Jlc3MgLVRleHQgIkluc3RhbGxpbmc6ICRpZCIgLVZhbHVlIDAuNQogICAgICAgICAgICAgICAgdHJ5IHsgaWYgKCRwa2cgLWVxICJ3aW5nZXQiKSB7IHdpbmdldCBpbnN0YWxsIC0taWQ9JGlkIC0tc2lsZW50IC0tYWNjZXB0LXBhY2thZ2UtYWdyZWVtZW50cyAtLWFjY2VwdC1zb3VyY2UtYWdyZWVtZW50cyAyPiYxIHwgT3V0LU51bGwgfSBlbHNlIHsgY2hvY28gaW5zdGFsbCAkaWQgLXkgMj4mMSB8IE91dC1OdWxsIH07IFdyaXRlLUxvZyAiSW5zdGFsbGVkOiAkaWQiICJTdWNjZXNzIiB9IGNhdGNoIHsgV3JpdGUtTG9nICJGYWlsZWQ6ICRpZCIgIkVycm9yIiB9CiAgICAgICAgICAgICAgICBIaWRlLVByb2dyZXNzOyBVcGRhdGUtSW5zdGFsbGVkQ2FjaGU7IFNob3ctSW5mbyAiRG9uZSIgIkluc3RhbGwgb2YgJGlkIGNvbXBsZXRlZC4iCiAgICAgICAgICAgIH0pCiAgICAgICAgICAgICRtaVVuaW5zdGFsbCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuTWVudUl0ZW07ICRtaVVuaW5zdGFsbC5IZWFkZXIgPSAiVW5pbnN0YWxsIjsgJG1pVW5pbnN0YWxsLlRhZyA9ICRhcHAud2luZ2V0CiAgICAgICAgICAgICRtaVVuaW5zdGFsbC5BZGRfQ2xpY2soewogICAgICAgICAgICAgICAgJGlkID0gJHRoaXMuVGFnOyAkcGtnID0gJHNjcmlwdDpwa2dNYW5hZ2VyOyBXcml0ZS1Mb2cgIkNvbnRleHQ6IFVuaW5zdGFsbCAkaWQgdmlhICRwa2ciICJJbmZvIgogICAgICAgICAgICAgICAgaWYgKC1ub3QgKEVuc3VyZS1QYWNrYWdlTWFuYWdlciAkcGtnKSkgeyBTaG93LUluZm8gIkVycm9yIiAiRmFpbGVkIHRvIGVuc3VyZSAkcGtnLiI7IHJldHVybiB9CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAoU2hvdy1Db25maXJtICJVbmluc3RhbGwiICJVbmluc3RhbGwgJGlkIHZpYSAkcGtnPyIpKSB7IHJldHVybiB9CiAgICAgICAgICAgICAgICBTaG93LVByb2dyZXNzIC1UZXh0ICJVbmluc3RhbGxpbmc6ICRpZCIgLVZhbHVlIDAuNQogICAgICAgICAgICAgICAgdHJ5IHsgaWYgKCRwa2cgLWVxICJ3aW5nZXQiKSB7IHdpbmdldCB1bmluc3RhbGwgLS1pZD0kaWQgLS1zaWxlbnQgLS1wdXJnZSAtLWFjY2VwdC1zb3VyY2UtYWdyZWVtZW50cyAyPiYxIHwgT3V0LU51bGwgfSBlbHNlIHsgY2hvY28gdW5pbnN0YWxsICRpZCAteSAyPiYxIHwgT3V0LU51bGwgfTsgV3JpdGUtTG9nICJVbmluc3RhbGxlZDogJGlkIiAiU3VjY2VzcyIgfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmFpbGVkOiAkaWQiICJFcnJvciIgfQogICAgICAgICAgICAgICAgSGlkZS1Qcm9ncmVzczsgVXBkYXRlLUluc3RhbGxlZENhY2hlOyBTaG93LUluZm8gIkRvbmUiICJVbmluc3RhbGwgb2YgJGlkIGNvbXBsZXRlZC4iCiAgICAgICAgICAgIH0pCiAgICAgICAgICAgICRtaUluZm8gPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLk1lbnVJdGVtOyAkbWlJbmZvLkhlYWRlciA9ICJJbmZvIjsgJG1pSW5mby5UYWcgPSAkYXBwCiAgICAgICAgICAgICRtaUluZm8uQWRkX0NsaWNrKHsgJGEgPSAkdGhpcy5UYWc7IFNob3ctSW5mbyAiQXBwIEluZm8iICIkKCRhLmNvbnRlbnQpYG5gbklEOiAkKCRhLndpbmdldClgbiQoJGEuZGVzY3JpcHRpb24pIiB9KQogICAgICAgICAgICAkbnVsbCA9ICRjbS5JdGVtcy5BZGQoJG1pSW5zdGFsbCk7ICRudWxsID0gJGNtLkl0ZW1zLkFkZCgkbWlVbmluc3RhbGwpOyAkbnVsbCA9ICRjbS5JdGVtcy5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuU2VwYXJhdG9yKSk7ICRudWxsID0gJGNtLkl0ZW1zLkFkZCgkbWlJbmZvKQogICAgICAgICAgICAkY2IuQ29udGV4dE1lbnUgPSAkY20KICAgICAgICAgICAgJGFwcFBhbmVsc1skYXBwUGFuZWxJbmRleF0uQ2hpbGRyZW4uQWRkKCRjYikgfCBPdXQtTnVsbAogICAgICAgICAgICAkYXBwQ2hlY2tib3hlcyArPSAkY2IKICAgICAgICAgICAgJHNjcmlwdDpjYXRlZ29yeUl0ZW1zWyRjYXRlZ29yeV0gKz0gJGNiCiAgICAgICAgfQogICAgICAgICRhcHBQYW5lbEluZGV4ID0gKCRhcHBQYW5lbEluZGV4ICsgMSkgJSAzCiAgICB9CiAgICBmb3JlYWNoICgkY2F0IGluICRzY3JpcHQ6Y2F0ZWdvcnlJdGVtcy5LZXlzKSB7ICRzY3JpcHQ6Y2F0ZWdvcnlDb2xsYXBzZWRbJGNhdF0gPSAkZmFsc2UgfQogICAgV3JpdGUtTG9nICJCdWlsdCAkKCRhcHBDaGVja2JveGVzLkNvdW50KSBhcHAgY2FyZHMuIiAiU3VjY2VzcyIKfQoKIyAtLS0gQnVpbGQgUHJlZmVyZW5jZXMgVUkgLS0tCiRwYW5lbEluZGV4ID0gMAppZiAoJHN5bmMuY29udHJvbHNbIlByZWZzUGFuZWwxIl0gLWFuZCAkc3luYy5jb250cm9sc1siUHJlZnNQYW5lbDIiXSAtYW5kICRzeW5jLmNvbnRyb2xzWyJQcmVmc1BhbmVsMyJdIC1hbmQgJHN5bmMuY29uZmlncy5wcmVmZXJlbmNlcykgewogICAgJHByZWZQYW5lbHMgPSBAKCRzeW5jLmNvbnRyb2xzWyJQcmVmc1BhbmVsMSJdLCAkc3luYy5jb250cm9sc1siUHJlZnNQYW5lbDIiXSwgJHN5bmMuY29udHJvbHNbIlByZWZzUGFuZWwzIl0pCiAgICBmb3JlYWNoICgkcHJlZktleSBpbiAkc3luYy5jb25maWdzLnByZWZlcmVuY2VzLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICRwcmVmID0gJHN5bmMuY29uZmlncy5wcmVmZXJlbmNlcy4kcHJlZktleQogICAgICAgICRjYiA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuQ2hlY2tCb3gKICAgICAgICAkY2IuQ29udGVudCA9ICRwcmVmLmNvbnRlbnQ7ICRjYi5UYWcgPSAkcHJlZktleTsgJGNiLlN0eWxlID0gR2V0LVdwZlJlc291cmNlICJUb2dnbGVTd2l0Y2giCiAgICAgICAgaWYgKCRwcmVmLmRlc2NyaXB0aW9uKSB7ICRjYi5Ub29sVGlwID0gJHByZWYuZGVzY3JpcHRpb24gfQogICAgICAgICRjdXJyZW50U3RhdGUgPSAkbnVsbAogICAgICAgICRoYXNSZWdpc3RyeU9uID0gJHByZWYuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAicmVnaXN0cnlfb24iIC1hbmQgJHByZWYucmVnaXN0cnlfb24gLWFuZCAkcHJlZi5yZWdpc3RyeV9vbi5Db3VudCAtZ3QgMAogICAgICAgIGlmICgkaGFzUmVnaXN0cnlPbikgewogICAgICAgICAgICAkZmlyc3RSZWcgPSAkcHJlZi5yZWdpc3RyeV9vblswXQogICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRmaXJzdFJlZy5wYXRoKSB7IHRyeSB7ICRjdXJyZW50U3RhdGUgPSAoR2V0LUl0ZW1Qcm9wZXJ0eSAkZmlyc3RSZWcucGF0aCAtTmFtZSAkZmlyc3RSZWcubmFtZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuJCgkZmlyc3RSZWcubmFtZSkgfSBjYXRjaCB7IFdyaXRlLUxvZyAiUmVnaXN0cnkgcmVhZCBmYWlsZWQ6ICRfIiAiV2FybiIgfSB9CiAgICAgICAgfQogICAgICAgICRjYi5Jc0NoZWNrZWQgPSBpZiAoJGhhc1JlZ2lzdHJ5T24pIHsgJGN1cnJlbnRTdGF0ZSAtZXEgJHByZWYucmVnaXN0cnlfb25bMF0udmFsdWUgfSBlbHNlIHsgJGZhbHNlIH0KICAgICAgICAkY2IuQWRkX0NoZWNrZWQoewogICAgICAgICAgICAkcGsgPSAkdGhpcy5UYWc7ICRwID0gJHN5bmMuY29uZmlncy5wcmVmZXJlbmNlcy4kcGsKICAgICAgICAgICAgaWYgKC1ub3QgJHApIHsgcmV0dXJuIH0KICAgICAgICAgICAgaWYgKCRwLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgInJlZ2lzdHJ5X29uIikgeyBmb3JlYWNoICgkciBpbiAkcC5yZWdpc3RyeV9vbikgeyB0cnkgeyBpZiAoIShUZXN0LVBhdGggJHIucGF0aCkpIHsgTmV3LUl0ZW0gJHIucGF0aCAtRm9yY2UgfCBPdXQtTnVsbCB9OyAkdCA9IGlmICgkci50eXBlKSB7ICRyLnR5cGUgfSBlbHNlIHsgIlN0cmluZyIgfTsgU2V0LUl0ZW1Qcm9wZXJ0eSAkci5wYXRoIC1OYW1lICRyLm5hbWUgLVZhbHVlICRyLnZhbHVlIC1UeXBlICR0IC1Gb3JjZSB9IGNhdGNoIHsgV3JpdGUtTG9nICJSZWdpc3RyeSB3cml0ZSBmYWlsZWQ6ICQoJHIucGF0aCkgJCgkci5uYW1lKSIgIldhcm4iIH0gfSB9CiAgICAgICAgICAgIFdyaXRlLUxvZyAiUHJlZiBPTjogJCgkcC5jb250ZW50KSIgIlN1Y2Nlc3MiCiAgICAgICAgfSkKICAgICAgICAkY2IuQWRkX1VuY2hlY2tlZCh7CiAgICAgICAgICAgICRwayA9ICR0aGlzLlRhZzsgJHAgPSAkc3luYy5jb25maWdzLnByZWZlcmVuY2VzLiRwawogICAgICAgICAgICBpZiAoLW5vdCAkcCkgeyByZXR1cm4gfQogICAgICAgICAgICBpZiAoJHAuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAicmVnaXN0cnlfb2ZmIikgeyBmb3JlYWNoICgkciBpbiAkcC5yZWdpc3RyeV9vZmYpIHsgdHJ5IHsgaWYgKCEoVGVzdC1QYXRoICRyLnBhdGgpKSB7IE5ldy1JdGVtICRyLnBhdGggLUZvcmNlIHwgT3V0LU51bGwgfTsgJHQgPSBpZiAoJHIudHlwZSkgeyAkci50eXBlIH0gZWxzZSB7ICJTdHJpbmciIH07IFNldC1JdGVtUHJvcGVydHkgJHIucGF0aCAtTmFtZSAkci5uYW1lIC1WYWx1ZSAkci52YWx1ZSAtVHlwZSAkdCAtRm9yY2UgfSBjYXRjaCB7IFdyaXRlLUxvZyAiUmVnaXN0cnkgd3JpdGUgZmFpbGVkOiAkKCRyLnBhdGgpICQoJHIubmFtZSkiICJXYXJuIiB9IH0gfQogICAgICAgICAgICBXcml0ZS1Mb2cgIlByZWYgT0ZGOiAkKCRwLmNvbnRlbnQpIiAiV2FybiIKICAgICAgICB9KQogICAgICAgICRwcmVmUGFuZWxzWyRwYW5lbEluZGV4XS5DaGlsZHJlbi5BZGQoJGNiKSB8IE91dC1OdWxsCiAgICAgICAgJHByZWZDaGVja2JveGVzWyRwcmVmS2V5XSA9ICRjYgogICAgICAgICRwYW5lbEluZGV4ID0gKCRwYW5lbEluZGV4ICsgMSkgJSAzCiAgICB9CiAgICBXcml0ZS1Mb2cgIkJ1aWx0ICQoJHByZWZDaGVja2JveGVzLkNvdW50KSBwcmVmZXJlbmNlIHRvZ2dsZXMuIiAiU3VjY2VzcyIKfQoKIyAtLS0gQnVpbGQgVHdlYWtzIFVJIC0tLQokcGFuZWxJbmRleCA9IDAKaWYgKCRzeW5jLmNvbnRyb2xzWyJUd2Vha3NQYW5lbDEiXSAtYW5kICRzeW5jLmNvbnRyb2xzWyJUd2Vha3NQYW5lbDIiXSAtYW5kICRzeW5jLmNvbnRyb2xzWyJUd2Vha3NQYW5lbDMiXSAtYW5kICRzeW5jLmNvbmZpZ3MudHdlYWtzKSB7CiAgICAkcGFuZWxzID0gQCgkc3luYy5jb250cm9sc1siVHdlYWtzUGFuZWwxIl0sICRzeW5jLmNvbnRyb2xzWyJUd2Vha3NQYW5lbDIiXSwgJHN5bmMuY29udHJvbHNbIlR3ZWFrc1BhbmVsMyJdKQogICAgZm9yZWFjaCAoJGdyb3VwS2V5IGluICRzeW5jLmNvbmZpZ3MudHdlYWtzLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICRncm91cCA9ICRzeW5jLmNvbmZpZ3MudHdlYWtzLiRncm91cEtleQogICAgICAgICRoZWFkZXIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9jazsgJGhlYWRlci5UZXh0ID0gJGdyb3VwS2V5OyAkaGVhZGVyLkZvbnRTaXplID0gMTY7ICRoZWFkZXIuRm9udFdlaWdodCA9ICJCb2xkIgogICAgICAgICRoZWFkZXIuU2V0UmVzb3VyY2VSZWZlcmVuY2UoW1N5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9ja106OkZvcmVncm91bmRQcm9wZXJ0eSwgImNhdGVnb3J5SGVhZGVyQ29sb3IiKTsgJGhlYWRlci5NYXJnaW4gPSAiMCwwLDAsMTAiCiAgICAgICAgJHBhbmVsc1skcGFuZWxJbmRleF0uQ2hpbGRyZW4uQWRkKCRoZWFkZXIpIHwgT3V0LU51bGwKICAgICAgICBmb3JlYWNoICgkdHdlYWtLZXkgaW4gJGdyb3VwLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSkgewogICAgICAgICAgICAkdHdlYWsgPSAkZ3JvdXAuJHR3ZWFrS2V5CiAgICAgICAgICAgICRjYiA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuQ2hlY2tCb3g7ICRjYi5Db250ZW50ID0gJHR3ZWFrLmNvbnRlbnQ7ICRjYi5UYWcgPSAkdHdlYWtLZXk7ICRjYi5TdHlsZSA9IEdldC1XcGZSZXNvdXJjZSAiVHdlYWtDaGVja0JveCIKICAgICAgICAgICAgaWYgKCR0d2Vhay5kZXNjcmlwdGlvbikgeyAkY2IuVG9vbFRpcCA9ICR0d2Vhay5kZXNjcmlwdGlvbiB9CiAgICAgICAgICAgICRwYW5lbHNbJHBhbmVsSW5kZXhdLkNoaWxkcmVuLkFkZCgkY2IpIHwgT3V0LU51bGwKICAgICAgICAgICAgJHR3ZWFrQ2hlY2tib3hlcyArPSAkY2IKICAgICAgICB9CiAgICAgICAgJHBhbmVsSW5kZXggPSAoJHBhbmVsSW5kZXggKyAxKSAlIDMKICAgIH0KICAgIFdyaXRlLUxvZyAiQnVpbHQgJCgkdHdlYWtDaGVja2JveGVzLkNvdW50KSB0d2VhayBjaGVja2JveGVzLiIgIlN1Y2Nlc3MiCn0KCiMgLS0tIEJ1aWxkIEZlYXR1cmVzICYgRml4ZXMgVUkgLS0tCiRwYW5lbEluZGV4ID0gMAppZiAoJHN5bmMuY29udHJvbHNbIkZlYXR1cmVzUGFuZWwxIl0gLWFuZCAkc3luYy5jb250cm9sc1siRmVhdHVyZXNQYW5lbDIiXSAtYW5kICRzeW5jLmNvbnRyb2xzWyJGZWF0dXJlc1BhbmVsMyJdIC1hbmQgJHN5bmMuY29uZmlncy5mZWF0dXJlcyAtYW5kICRzeW5jLmNvbmZpZ3MuZmVhdHVyZXMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiRmVhdHVyZXMiKSB7CiAgICAkZmVhdFBhbmVscyA9IEAoJHN5bmMuY29udHJvbHNbIkZlYXR1cmVzUGFuZWwxIl0sICRzeW5jLmNvbnRyb2xzWyJGZWF0dXJlc1BhbmVsMiJdLCAkc3luYy5jb250cm9sc1siRmVhdHVyZXNQYW5lbDMiXSkKICAgIGZvcmVhY2ggKCRmZWF0S2V5IGluICRzeW5jLmNvbmZpZ3MuZmVhdHVyZXMuRmVhdHVyZXMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgJGZlYXQgPSAkc3luYy5jb25maWdzLmZlYXR1cmVzLkZlYXR1cmVzLiRmZWF0S2V5CiAgICAgICAgJGNiID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Db250cm9scy5DaGVja0JveDsgJGNiLkNvbnRlbnQgPSAkZmVhdC5jb250ZW50OyAkY2IuVGFnID0gJGZlYXRLZXk7ICRjYi5TdHlsZSA9IEdldC1XcGZSZXNvdXJjZSAiVHdlYWtDaGVja0JveCIKICAgICAgICBpZiAoJGZlYXQuZGVzY3JpcHRpb24pIHsgJGNiLlRvb2xUaXAgPSAkZmVhdC5kZXNjcmlwdGlvbiB9CiAgICAgICAgJGZlYXRQYW5lbHNbJHBhbmVsSW5kZXhdLkNoaWxkcmVuLkFkZCgkY2IpIHwgT3V0LU51bGwKICAgICAgICAkZmVhdHVyZXNDaGVja2JveGVzICs9ICRjYgogICAgICAgICRwYW5lbEluZGV4ID0gKCRwYW5lbEluZGV4ICsgMSkgJSAzCiAgICB9CiAgICBXcml0ZS1Mb2cgIkJ1aWx0ICQoJGZlYXR1cmVzQ2hlY2tib3hlcy5Db3VudCkgZmVhdHVyZSBjaGVja2JveGVzLiIgIlN1Y2Nlc3MiCn0KaWYgKCRzeW5jLmNvbnRyb2xzWyJGaXhlc1dyYXBQYW5lbCJdIC1hbmQgJHN5bmMuY29uZmlncy5mZWF0dXJlcyAtYW5kICRzeW5jLmNvbmZpZ3MuZmVhdHVyZXMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiRml4ZXMiKSB7CiAgICBmb3JlYWNoICgkZml4S2V5IGluICRzeW5jLmNvbmZpZ3MuZmVhdHVyZXMuRml4ZXMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lKSB7CiAgICAgICAgJGZpeCA9ICRzeW5jLmNvbmZpZ3MuZmVhdHVyZXMuRml4ZXMuJGZpeEtleQogICAgICAgICRidG4gPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLkJ1dHRvbjsgJGJ0bi5TdHlsZSA9IEdldC1XcGZSZXNvdXJjZSAiRmVhdHVyZUNhcmQiOyAkYnRuLkNvbnRlbnQgPSAkZml4LmNvbnRlbnQ7ICRidG4uVG9vbFRpcCA9ICRmaXguZGVzY3JpcHRpb247ICRidG4uVGFnID0gJGZpeAogICAgICAgICRidG4uQWRkX0NsaWNrKHsKICAgICAgICAgICAgJGYgPSAkdGhpcy5UYWcKICAgICAgICAgICAgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiUnVuIEZpeCIgIkV4ZWN1dGU6ICQoJGYuY29udGVudCk/IikpIHsgcmV0dXJuIH0KICAgICAgICAgICAgV3JpdGUtTG9nICJSdW5uaW5nIGZpeDogJCgkZi5jb250ZW50KSIgIkhlYWRlciIKICAgICAgICAgICAgdHJ5IHsgJiAoW3NjcmlwdGJsb2NrXTo6Q3JlYXRlKCRmLnNjcmlwdCkpOyBXcml0ZS1Mb2cgIkZpeCBjb21wbGV0ZWQ6ICQoJGYuY29udGVudCkiICJTdWNjZXNzIjsgU2hvdy1JbmZvICJGaXggQ29tcGxldGUiICIkKCRmLmNvbnRlbnQpYG5gbkNvbXBsZXRlZCBzdWNjZXNzZnVsbHkuIiB9IGNhdGNoIHsgV3JpdGUtTG9nICJGaXggZmFpbGVkOiAkXyIgIkVycm9yIjsgU2hvdy1JbmZvICJGaXggRmFpbGVkIiAiJCgkZi5jb250ZW50KWBuYG5FcnJvcjogJF8iIH0KICAgICAgICB9KQogICAgICAgICRzeW5jLmNvbnRyb2xzWyJGaXhlc1dyYXBQYW5lbCJdLkNoaWxkcmVuLkFkZCgkYnRuKSB8IE91dC1OdWxsCiAgICB9CiAgICBXcml0ZS1Mb2cgIkJ1aWx0ICQoJHN5bmMuY29uZmlncy5mZWF0dXJlcy5GaXhlcy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUuQ291bnQpIGZpeCBidXR0b25zLiIgIlN1Y2Nlc3MiCn0KCiMgLS0tIEJ1aWxkIExlZ2FjeSBXaW5kb3dzIFBhbmVscyBVSSAtLS0KJGxlZ2FjeVBhbmVscyA9IEAoCiAgICBAeyBOYW1lID0gIkNvbXB1dGVyIE1hbmFnZW1lbnQiOyBEZXNjID0gIk1hbmFnZSBkaXNrcywgc2VydmljZXMsIGV2ZW50IHZpZXdlciwgYW5kIG1vcmUiOyBDb21tYW5kID0gImNvbXBtZ210Lm1zYyIgfSwKICAgIEB7IE5hbWUgPSAiQ29udHJvbCBQYW5lbCI7IERlc2MgPSAiQ2xhc3NpYyBXaW5kb3dzIENvbnRyb2wgUGFuZWwiOyBDb21tYW5kID0gImNvbnRyb2wiIH0sCiAgICBAeyBOYW1lID0gIkRldmljZSBNYW5hZ2VyIjsgRGVzYyA9ICJWaWV3IGFuZCB1cGRhdGUgaGFyZHdhcmUgZGV2aWNlcyBhbmQgZHJpdmVycyI7IENvbW1hbmQgPSAiZGV2bWdtdC5tc2MiIH0sCiAgICBAeyBOYW1lID0gIkRpc2sgTWFuYWdlbWVudCI7IERlc2MgPSAiTWFuYWdlIGRpc2sgcGFydGl0aW9ucywgdm9sdW1lcywgYW5kIGRyaXZlcyI7IENvbW1hbmQgPSAiZGlza21nbXQubXNjIiB9LAogICAgQHsgTmFtZSA9ICJFdmVudCBWaWV3ZXIiOyBEZXNjID0gIlZpZXcgc3lzdGVtIGxvZ3MgYW5kIGFwcGxpY2F0aW9uIGV2ZW50cyI7IENvbW1hbmQgPSAiZXZlbnR2d3IubXNjIiB9LAogICAgQHsgTmFtZSA9ICJOZXR3b3JrIENvbm5lY3Rpb25zIjsgRGVzYyA9ICJNYW5hZ2UgbmV0d29yayBhZGFwdGVycyBhbmQgY29ubmVjdGlvbnMiOyBDb21tYW5kID0gIm5jcGEuY3BsIiB9LAogICAgQHsgTmFtZSA9ICJQb3dlciBQYW5lbCI7IERlc2MgPSAiQ29uZmlndXJlIHBvd2VyIHBsYW5zIGFuZCBiYXR0ZXJ5IHNldHRpbmdzIjsgQ29tbWFuZCA9ICJwb3dlcmNmZy5jcGwiIH0sCiAgICBAeyBOYW1lID0gIlByaW50ZXIgUGFuZWwiOyBEZXNjID0gIk1hbmFnZSBwcmludGVycyBhbmQgcHJpbnQgcXVldWVzIjsgQ29tbWFuZCA9ICJjb250cm9sIHByaW50ZXJzIiB9LAogICAgQHsgTmFtZSA9ICJSZWdpb24iOyBEZXNjID0gIlNldCByZWdpb25hbCBmb3JtYXQsIGxhbmd1YWdlLCBhbmQgbG9jYXRpb24iOyBDb21tYW5kID0gImludGwuY3BsIiB9LAogICAgQHsgTmFtZSA9ICJSZWdpc3RyeSBFZGl0b3IiOyBEZXNjID0gIlZpZXcgYW5kIGVkaXQgV2luZG93cyByZWdpc3RyeSBlbnRyaWVzIjsgQ29tbWFuZCA9ICJyZWdlZGl0IiB9LAogICAgQHsgTmFtZSA9ICJTZXJ2aWNlcyI7IERlc2MgPSAiTWFuYWdlIFdpbmRvd3Mgc2VydmljZXMgYW5kIHRoZWlyIHN0YXJ0dXAgdHlwZXMiOyBDb21tYW5kID0gInNlcnZpY2VzLm1zYyIgfSwKICAgIEB7IE5hbWUgPSAiU291bmQgU2V0dGluZ3MiOyBEZXNjID0gIkNvbmZpZ3VyZSBhdWRpbyBkZXZpY2VzIGFuZCBzb3VuZCBlZmZlY3RzIjsgQ29tbWFuZCA9ICJtbXN5cy5jcGwiIH0sCiAgICBAeyBOYW1lID0gIlN5c3RlbSBQcm9wZXJ0aWVzIjsgRGVzYyA9ICJWaWV3IHN5c3RlbSBpbmZvLCBwZXJmb3JtYW5jZSwgcmVtb3RlIHNldHRpbmdzIjsgQ29tbWFuZCA9ICJzeXNkbS5jcGwiIH0sCiAgICBAeyBOYW1lID0gIlRhc2sgU2NoZWR1bGVyIjsgRGVzYyA9ICJTY2hlZHVsZSBhdXRvbWF0ZWQgdGFza3MgYW5kIHRyaWdnZXJzIjsgQ29tbWFuZCA9ICJ0YXNrc2NoZC5tc2MiIH0sCiAgICBAeyBOYW1lID0gIlRpbWUgYW5kIERhdGUiOyBEZXNjID0gIlNldCBkYXRlLCB0aW1lLCBhbmQgdGltZXpvbmUiOyBDb21tYW5kID0gInRpbWVkYXRlLmNwbCIgfSwKICAgIEB7IE5hbWUgPSAiV2luZG93cyBSZXN0b3JlIjsgRGVzYyA9ICJTeXN0ZW0gUmVzdG9yZSAtIGNyZWF0ZSBvciByZXN0b3JlIHJlc3RvcmUgcG9pbnRzIjsgQ29tbWFuZCA9ICJyc3RydWkuZXhlIiB9CikKCmlmICgkc3luYy5jb250cm9sc1siTGVnYWN5UGFuZWwxIl0gLWFuZCAkc3luYy5jb250cm9sc1siTGVnYWN5UGFuZWwyIl0gLWFuZCAkc3luYy5jb250cm9sc1siTGVnYWN5UGFuZWwzIl0pIHsKICAgICRsZWdhY3lQYW5lbHNBcnIgPSBAKCRzeW5jLmNvbnRyb2xzWyJMZWdhY3lQYW5lbDEiXSwgJHN5bmMuY29udHJvbHNbIkxlZ2FjeVBhbmVsMiJdLCAkc3luYy5jb250cm9sc1siTGVnYWN5UGFuZWwzIl0pCiAgICAkcGFuZWxJbmRleCA9IDAKICAgIGZvcmVhY2ggKCRwYW5lbCBpbiAkbGVnYWN5UGFuZWxzKSB7CiAgICAgICAgJGJ0biA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuQnV0dG9uOyAkYnRuLlN0eWxlID0gR2V0LVdwZlJlc291cmNlICJGZWF0dXJlQ2FyZCI7ICRidG4uVG9vbFRpcCA9ICIkKCRwYW5lbC5OYW1lKWBuJCgkcGFuZWwuRGVzYylgbmBuTGF1bmNoOiAkKCRwYW5lbC5Db21tYW5kKSI7ICRidG4uVGFnID0gJHBhbmVsLkNvbW1hbmQ7ICRidG4uSG9yaXpvbnRhbEFsaWdubWVudCA9ICJTdHJldGNoIgogICAgICAgICRzcCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuU3RhY2tQYW5lbDsgJHNwLk9yaWVudGF0aW9uID0gIkhvcml6b250YWwiCiAgICAgICAgJHRleHRTcCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuU3RhY2tQYW5lbDsgJHRleHRTcC5PcmllbnRhdGlvbiA9ICJWZXJ0aWNhbCI7ICR0ZXh0U3AuVmVydGljYWxBbGlnbm1lbnQgPSAiQ2VudGVyIgogICAgICAgICRuYW1lVGIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9jazsgJG5hbWVUYi5UZXh0ID0gJHBhbmVsLk5hbWU7ICRuYW1lVGIuRm9udFNpemUgPSAxNDsgJG5hbWVUYi5Gb250V2VpZ2h0ID0gIlNlbWlCb2xkIjsgJG5hbWVUYi5TZXRSZXNvdXJjZVJlZmVyZW5jZShbU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrXTo6Rm9yZWdyb3VuZFByb3BlcnR5LCAicGFnZVRpdGxlQ29sb3IiKTsgJHRleHRTcC5DaGlsZHJlbi5BZGQoJG5hbWVUYikgfCBPdXQtTnVsbAogICAgICAgICRkZXNjVGIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkNvbnRyb2xzLlRleHRCbG9jazsgJGRlc2NUYi5UZXh0ID0gJHBhbmVsLkRlc2M7ICRkZXNjVGIuRm9udFNpemUgPSAxMTsgJGRlc2NUYi5TZXRSZXNvdXJjZVJlZmVyZW5jZShbU3lzdGVtLldpbmRvd3MuQ29udHJvbHMuVGV4dEJsb2NrXTo6Rm9yZWdyb3VuZFByb3BlcnR5LCAidGV4dE11dGVkIik7ICRkZXNjVGIuVGV4dFdyYXBwaW5nID0gIldyYXAiOyAkdGV4dFNwLkNoaWxkcmVuLkFkZCgkZGVzY1RiKSB8IE91dC1OdWxsCiAgICAgICAgJHNwLkNoaWxkcmVuLkFkZCgkdGV4dFNwKSB8IE91dC1OdWxsOyAkYnRuLkNvbnRlbnQgPSAkc3AKICAgICAgICAkYnRuLkFkZF9DbGljayh7CiAgICAgICAgICAgICRjbWQgPSAkdGhpcy5UYWc7IFdyaXRlLUxvZyAiTGF1bmNoaW5nOiAkY21kIiAiSW5mbyIKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRwYXJ0cyA9ICRjbWQgLXNwbGl0ICcgJywgMgogICAgICAgICAgICAgICAgJGV4ZSA9ICRwYXJ0c1swXTsgJGFyZ3MgPSBpZiAoJHBhcnRzLkNvdW50IC1ndCAxKSB7ICRwYXJ0c1sxXSB9IGVsc2UgeyAkbnVsbCB9CiAgICAgICAgICAgICAgICBpZiAoJGFyZ3MpIHsgU3RhcnQtUHJvY2VzcyAkZXhlIC1Bcmd1bWVudExpc3QgJGFyZ3MgLUVycm9yQWN0aW9uIFN0b3AgfSBlbHNlIHsgU3RhcnQtUHJvY2VzcyAkZXhlIC1FcnJvckFjdGlvbiBTdG9wIH0KICAgICAgICAgICAgICAgIFdyaXRlLUxvZyAiTGF1bmNoZWQ6ICRjbWQiICJTdWNjZXNzIgogICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJGYWlsZWQgdG8gbGF1bmNoICR7Y21kfTogJF8iICJFcnJvciI7IFNob3ctSW5mbyAiRXJyb3IiICJGYWlsZWQgdG8gbGF1bmNoICRjbWRgbmBuJF8iIH0KICAgICAgICB9KQogICAgICAgICRsZWdhY3lQYW5lbHNBcnJbJHBhbmVsSW5kZXhdLkNoaWxkcmVuLkFkZCgkYnRuKSB8IE91dC1OdWxsCiAgICAgICAgJHBhbmVsSW5kZXggPSAoJHBhbmVsSW5kZXggKyAxKSAlIDMKICAgIH0KICAgIFdyaXRlLUxvZyAiQnVpbHQgJCgkbGVnYWN5UGFuZWxzLkNvdW50KSBsZWdhY3kgcGFuZWwgYnV0dG9ucy4iICJTdWNjZXNzIgp9Cg=='))
$appCheckboxes = @()
$tweakCheckboxes = @()
$featuresCheckboxes = @()
$prefCheckboxes = @{}
$appPanels = @()
$script:categoryItems = @{}
$script:categoryCollapsed = @{}

# --- Build Apps UI ---
$appPanelIndex = 0
if (($sync.controls["AppPanel1"] -and $sync.controls["AppPanel2"] -and $sync.controls["AppPanel3"]) -and $sync.configs.apps) {
    $appPanels = @($sync.controls["AppPanel1"], $sync.controls["AppPanel2"], $sync.controls["AppPanel3"])
    foreach ($category in $sync.configs.apps.PSObject.Properties.Name) {
        $catCount = ($sync.configs.apps.$category.PSObject.Properties.Name).Count
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
        foreach ($appKey in $sync.configs.apps.$category.PSObject.Properties.Name) {
            $app = $sync.configs.apps.$category.$appKey
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
if ($sync.controls["PrefsPanel1"] -and $sync.controls["PrefsPanel2"] -and $sync.controls["PrefsPanel3"] -and $sync.configs.preferences) {
    $prefPanels = @($sync.controls["PrefsPanel1"], $sync.controls["PrefsPanel2"], $sync.controls["PrefsPanel3"])
    foreach ($prefKey in $sync.configs.preferences.PSObject.Properties.Name) {
        $pref = $sync.configs.preferences.$prefKey
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
            $pk = $this.Tag; $p = $sync.configs.preferences.$pk
            if (-not $p) { return }
            if ($p.PSObject.Properties.Name -contains "registry_on") { foreach ($r in $p.registry_on) { try { if (!(Test-Path $r.path)) { New-Item $r.path -Force | Out-Null }; $t = if ($r.type) { $r.type } else { "String" }; Set-ItemProperty $r.path -Name $r.name -Value $r.value -Type $t -Force } catch { Write-Log "Registry write failed: $($r.path) $($r.name)" "Warn" } } }
            Write-Log "Pref ON: $($p.content)" "Success"
        })
        $cb.Add_Unchecked({
            $pk = $this.Tag; $p = $sync.configs.preferences.$pk
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
if ($sync.controls["TweaksPanel1"] -and $sync.controls["TweaksPanel2"] -and $sync.controls["TweaksPanel3"] -and $sync.configs.tweaks) {
    $panels = @($sync.controls["TweaksPanel1"], $sync.controls["TweaksPanel2"], $sync.controls["TweaksPanel3"])
    foreach ($groupKey in $sync.configs.tweaks.PSObject.Properties.Name) {
        $group = $sync.configs.tweaks.$groupKey
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
if ($sync.controls["FeaturesPanel1"] -and $sync.controls["FeaturesPanel2"] -and $sync.controls["FeaturesPanel3"] -and $sync.configs.features -and $sync.configs.features.PSObject.Properties.Name -contains "Features") {
    $featPanels = @($sync.controls["FeaturesPanel1"], $sync.controls["FeaturesPanel2"], $sync.controls["FeaturesPanel3"])
    foreach ($featKey in $sync.configs.features.Features.PSObject.Properties.Name) {
        $feat = $sync.configs.features.Features.$featKey
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = $feat.content; $cb.Tag = $featKey; $cb.Style = Get-WpfResource "TweakCheckBox"
        if ($feat.description) { $cb.ToolTip = $feat.description }
        $featPanels[$panelIndex].Children.Add($cb) | Out-Null
        $featuresCheckboxes += $cb
        $panelIndex = ($panelIndex + 1) % 3
    }
    Write-Log "Built $($featuresCheckboxes.Count) feature checkboxes." "Success"
}
if ($sync.controls["FixesWrapPanel"] -and $sync.configs.features -and $sync.configs.features.PSObject.Properties.Name -contains "Fixes") {
    foreach ($fixKey in $sync.configs.features.Fixes.PSObject.Properties.Name) {
        $fix = $sync.configs.features.Fixes.$fixKey
        $btn = New-Object System.Windows.Controls.Button; $btn.Style = Get-WpfResource "FeatureCard"; $btn.Content = $fix.content; $btn.ToolTip = $fix.description; $btn.Tag = $fix
        $btn.Add_Click({
            $f = $this.Tag
            if (-not (Show-Confirm "Run Fix" "Execute: $($f.content)?")) { return }
            Write-Log "Running fix: $($f.content)" "Header"
            try { & ([scriptblock]::Create($f.script)); Write-Log "Fix completed: $($f.content)" "Success"; Show-Info "Fix Complete" "$($f.content)`n`nCompleted successfully." } catch { Write-Log "Fix failed: $_" "Error"; Show-Info "Fix Failed" "$($f.content)`n`nError: $_" }
        })
        $sync.controls["FixesWrapPanel"].Children.Add($btn) | Out-Null
    }
    Write-Log "Built $($sync.configs.features.Fixes.PSObject.Properties.Name.Count) fix buttons." "Success"
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

if ($sync.controls["LegacyPanel1"] -and $sync.controls["LegacyPanel2"] -and $sync.controls["LegacyPanel3"]) {
    $legacyPanelsArr = @($sync.controls["LegacyPanel1"], $sync.controls["LegacyPanel2"], $sync.controls["LegacyPanel3"])
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

$script:__mod_install = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('JHNjcmlwdDpwa2dNYW5hZ2VyID0gIndpbmdldCIKCmZ1bmN0aW9uIEVuc3VyZS1QYWNrYWdlTWFuYWdlciB7CiAgICBwYXJhbShbc3RyaW5nXSRQa2cpCiAgICBpZiAoR2V0LUNvbW1hbmQgJFBrZyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkgeyByZXR1cm4gJHRydWUgfQogICAgV3JpdGUtTG9nICIkUGtnIG5vdCBmb3VuZC4gSW5zdGFsbGluZy4uLiIgIkluZm8iCiAgICB0cnkgewogICAgICAgIGlmICgkUGtnIC1lcSAid2luZ2V0IikgewogICAgICAgICAgICAkdXJsID0gImh0dHBzOi8vZ2l0aHViLmNvbS9taWNyb3NvZnQvd2luZ2V0LWNsaS9yZWxlYXNlcy9sYXRlc3QvZG93bmxvYWQvTWljcm9zb2Z0LkRlc2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgogICAgICAgICAgICAkb3V0ID0gIiRlbnY6VEVNUFxBcHBJbnN0YWxsZXIubXNpeGJ1bmRsZSIKICAgICAgICAgICAgSW52b2tlLVdlYlJlcXVlc3QgLVVyaSAkdXJsIC1PdXRGaWxlICRvdXQgLVVzZUJhc2ljUGFyc2luZwogICAgICAgICAgICBBZGQtQXBweFBhY2thZ2UgLVBhdGggJG91dCAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgICAgICBSZW1vdmUtSXRlbSAkb3V0IC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIH0gZWxzZWlmICgkUGtnIC1lcSAiY2hvY28iKSB7CiAgICAgICAgICAgICRjaG9jb1BhdGggPSAiJGVudjpQUk9HUkFNREFUQVxjaG9jb2xhdGV5XGNob2NvLmV4ZSIKICAgICAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkY2hvY29QYXRoKSkgewogICAgICAgICAgICAgICAgU2V0LUV4ZWN1dGlvblBvbGljeSBCeXBhc3MgLVNjb3BlIFByb2Nlc3MgLUZvcmNlCiAgICAgICAgICAgICAgICBbU3lzdGVtLk5ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6U2VjdXJpdHlQcm90b2NvbCA9IFtTeXN0ZW0uTmV0LlNlcnZpY2VQb2ludE1hbmFnZXJdOjpTZWN1cml0eVByb3RvY29sIC1ib3IgMzA3MgogICAgICAgICAgICAgICAgJHRtcCA9ICIkZW52OlRFTVBcY2hvY28taW5zdGFsbC5wczEiCiAgICAgICAgICAgICAgICBJbnZva2UtV2ViUmVxdWVzdCAtVXJpICdodHRwczovL2NvbW11bml0eS5jaG9jb2xhdGV5Lm9yZy9pbnN0YWxsLnBzMScgLU91dEZpbGUgJHRtcCAtVXNlQmFzaWNQYXJzaW5nCiAgICAgICAgICAgICAgICAmICR0bXAKICAgICAgICAgICAgICAgIFJlbW92ZS1JdGVtICR0bXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgaWYgKEdldC1Db21tYW5kICRQa2cgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIHsgV3JpdGUtTG9nICIkUGtnIGluc3RhbGxlZC4iICJTdWNjZXNzIjsgcmV0dXJuICR0cnVlIH0KICAgICAgICBXcml0ZS1Mb2cgIiRQa2cgaW5zdGFsbCBjb21wbGV0ZWQgYnV0IGNvbW1hbmQgbm90IGZvdW5kLiIgIldhcm4iOyByZXR1cm4gJGZhbHNlCiAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICIkUGtnIGluc3RhbGwgZmFpbGVkOiAkXyIgIkVycm9yIjsgcmV0dXJuICRmYWxzZSB9Cn0KCmlmICgkc3luYy5jb250cm9sc1siQnRuSW5zdGFsbCJdKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuSW5zdGFsbCJdLkFkZF9DbGljayh7CiAgICAgICAgJHNlbGVjdGVkID0gJGFwcENoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0KICAgICAgICBpZiAoJHNlbGVjdGVkLkNvdW50IC1lcSAwKSB7IFdyaXRlLUxvZyAiTm8gYXBwcyBzZWxlY3RlZC4iICJXYXJuIjsgcmV0dXJuIH0KICAgICAgICAkcGtnID0gJHNjcmlwdDpwa2dNYW5hZ2VyCiAgICAgICAgaWYgKC1ub3QgKEVuc3VyZS1QYWNrYWdlTWFuYWdlciAkcGtnKSkgeyBTaG93LUluZm8gIkVycm9yIiAiRmFpbGVkIHRvIGVuc3VyZSAkcGtnLiI7IHJldHVybiB9CiAgICAgICAgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiSW5zdGFsbCBBcHBzIiAiSW5zdGFsbCAkKCRzZWxlY3RlZC5Db3VudCkgYXBwbGljYXRpb24ocykgdmlhICRwa2c/IikpIHsgcmV0dXJuIH0KICAgICAgICBXcml0ZS1Mb2cgIlN0YXJ0aW5nIGluc3RhbGxhdGlvbiB2aWEgJHBrZy4uLiIgIkhlYWRlciIKICAgICAgICBTZXQtU3RhdHVzICJJbnN0YWxsaW5nICQoJHNlbGVjdGVkLkNvdW50KSBhcHAocykgdmlhICRwa2cuLi4iCiAgICAgICAgU2hvdy1Qcm9ncmVzcyAtVGV4dCAiUHJlcGFyaW5nIGluc3RhbGxhdGlvbi4uLiIgLVZhbHVlIDAuMDUKICAgICAgICAkY291bnQgPSAwCiAgICAgICAgZm9yZWFjaCAoJGNiIGluICRzZWxlY3RlZCkgewogICAgICAgICAgICAkaWQgPSAkY2IuVGFnOyAkY291bnQrKwogICAgICAgICAgICAkcGVyY2VudCA9IFttYXRoXTo6TWF4KDAuMDUsIFttYXRoXTo6TWluKDAuOTUsICgkY291bnQgLyAkc2VsZWN0ZWQuQ291bnQpICogMC45KSkKICAgICAgICAgICAgV3JpdGUtTG9nICJJbnN0YWxsaW5nICRpZC4uLiIgIkluZm8iOyBTZXQtU3RhdHVzICJJbnN0YWxsaW5nICRpZC4uLiIKICAgICAgICAgICAgU2hvdy1Qcm9ncmVzcyAtVGV4dCAiSW5zdGFsbGluZzogJGlkICgkY291bnQvJCgkc2VsZWN0ZWQuQ291bnQpKSIgLVZhbHVlICRwZXJjZW50CiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICBpZiAoJHBrZyAtZXEgIndpbmdldCIpIHsgd2luZ2V0IGluc3RhbGwgLS1pZD0kaWQgLS1zaWxlbnQgLS1hY2NlcHQtcGFja2FnZS1hZ3JlZW1lbnRzIC0tYWNjZXB0LXNvdXJjZS1hZ3JlZW1lbnRzIDI+JjEgfCBPdXQtTnVsbCB9CiAgICAgICAgICAgICAgICBlbHNlIHsgY2hvY28gaW5zdGFsbCAkaWQgLXkgMj4mMSB8IE91dC1OdWxsIH0KICAgICAgICAgICAgICAgIFdyaXRlLUxvZyAiRG9uZTogJGlkIiAiU3VjY2VzcyIKICAgICAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmFpbGVkOiAkaWRgOiAkXyIgIkVycm9yIiB9CiAgICAgICAgfQogICAgICAgIFVwZGF0ZS1JbnN0YWxsZWRDYWNoZQogICAgICAgIGlmICgkc3luYy5jb250cm9sc1siQ2hrU2hvd0luc3RhbGxlZCJdKSB7IEFwcGx5LUZpbHRlcnMgfQogICAgICAgIEhpZGUtUHJvZ3Jlc3M7IFNldC1TdGF0dXMgIlJlYWR5IgogICAgICAgIFNob3ctSW5mbyAiSW5zdGFsbGF0aW9uIENvbXBsZXRlIiAiJCgkc2VsZWN0ZWQuQ291bnQpIGFwcGxpY2F0aW9uKHMpIGluc3RhbGxlZCB2aWEgJHBrZy4iCiAgICAgICAgV3JpdGUtTG9nICJJbnN0YWxsYXRpb24gY29tcGxldGUuIiAiSGVhZGVyIgogICAgICAgIFNldC1Qcm9ncmVzc1Rhc2tiYXIgLXN0YXRlICJOb3JtYWwiIC12YWx1ZSAxCiAgICB9KQp9CgppZiAoJHN5bmMuY29udHJvbHNbIkJ0blVuaW5zdGFsbCJdKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuVW5pbnN0YWxsIl0uQWRkX0NsaWNrKHsKICAgICAgICAkc2VsZWN0ZWQgPSAkYXBwQ2hlY2tib3hlcyB8IFdoZXJlLU9iamVjdCB7ICRfLklzQ2hlY2tlZCAtZXEgJHRydWUgfQogICAgICAgIGlmICgkc2VsZWN0ZWQuQ291bnQgLWVxIDApIHsgV3JpdGUtTG9nICJObyBhcHBzIHNlbGVjdGVkLiIgIldhcm4iOyByZXR1cm4gfQogICAgICAgICRwa2cgPSAkc2NyaXB0OnBrZ01hbmFnZXIKICAgICAgICBpZiAoLW5vdCAoRW5zdXJlLVBhY2thZ2VNYW5hZ2VyICRwa2cpKSB7IFNob3ctSW5mbyAiRXJyb3IiICJGYWlsZWQgdG8gZW5zdXJlICRwa2cuIjsgcmV0dXJuIH0KICAgICAgICBpZiAoLW5vdCAoU2hvdy1Db25maXJtICJVbmluc3RhbGwgQXBwcyIgIlVuaW5zdGFsbCAkKCRzZWxlY3RlZC5Db3VudCkgYXBwbGljYXRpb24ocykgYW5kIGRlZXAgY2xlYW4gbGVmdG92ZXJzIHZpYSAkcGtnP2BuYG5UaGlzIGNhbm5vdCBiZSB1bmRvbmUhIikpIHsgcmV0dXJuIH0KICAgICAgICBXcml0ZS1Mb2cgIlN0YXJ0aW5nIHVuaW5zdGFsbGF0aW9uIHZpYSAkcGtnLi4uIiAiSGVhZGVyIgogICAgICAgIFNldC1TdGF0dXMgIlVuaW5zdGFsbGluZyAkKCRzZWxlY3RlZC5Db3VudCkgYXBwKHMpIHZpYSAkcGtnLi4uIgogICAgICAgIFNob3ctUHJvZ3Jlc3MgLVRleHQgIlByZXBhcmluZyB1bmluc3RhbGxhdGlvbi4uLiIgLVZhbHVlIDAuMDUKICAgICAgICAkY291bnQgPSAwCiAgICAgICAgZm9yZWFjaCAoJGNiIGluICRzZWxlY3RlZCkgewogICAgICAgICAgICAkaWQgPSAkY2IuVGFnOyAkY291bnQrKwogICAgICAgICAgICAkcGVyY2VudCA9IFttYXRoXTo6TWF4KDAuMDUsIFttYXRoXTo6TWluKDAuOTUsICgkY291bnQgLyAkc2VsZWN0ZWQuQ291bnQpICogMC45KSkKICAgICAgICAgICAgV3JpdGUtTG9nICJVbmluc3RhbGxpbmcgJGlkLi4uIiAiSW5mbyI7IFNldC1TdGF0dXMgIlVuaW5zdGFsbGluZyAkaWQuLi4iCiAgICAgICAgICAgIFNob3ctUHJvZ3Jlc3MgLVRleHQgIlVuaW5zdGFsbGluZzogJGlkICgkY291bnQvJCgkc2VsZWN0ZWQuQ291bnQpKSIgLVZhbHVlICRwZXJjZW50CiAgICAgICAgICAgICRvayA9ICR0cnVlCiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICBpZiAoJHBrZyAtZXEgIndpbmdldCIpIHsgd2luZ2V0IHVuaW5zdGFsbCAtLWlkPSRpZCAtLXNpbGVudCAtLXB1cmdlIC0tYWNjZXB0LXNvdXJjZS1hZ3JlZW1lbnRzIDI+JjEgfCBPdXQtTnVsbCB9CiAgICAgICAgICAgICAgICBlbHNlIHsgY2hvY28gdW5pbnN0YWxsICRpZCAteSAyPiYxIHwgT3V0LU51bGwgfQogICAgICAgICAgICAgICAgV3JpdGUtTG9nICJEb25lOiAkaWQiICJTdWNjZXNzIgogICAgICAgICAgICB9IGNhdGNoIHsgV3JpdGUtTG9nICJGYWlsZWQ6ICRpZGA6ICRfIiAiRXJyb3IiOyAkb2sgPSAkZmFsc2UgfQogICAgICAgICAgICBpZiAoJG9rIC1hbmQgJHBrZyAtZXEgIndpbmdldCIpIHsKICAgICAgICAgICAgICAgIFdyaXRlLUxvZyAiRGVlcCBDbGVhbmluZyAkaWQuLi4iICJJbmZvIjsgU2V0LVN0YXR1cyAiQ2xlYW5pbmcgJGlkIGxlZnRvdmVycy4uLiIKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCR0ZXJtIGluICgkaWQgLXNwbGl0ICdcLicpIHwgV2hlcmUtT2JqZWN0IHsgJF8uTGVuZ3RoIC1ndCA0IH0pIHsKICAgICAgICAgICAgICAgICAgICBmb3JlYWNoICgkYmFzZVBhdGggaW4gQCgkZW52OkFQUERBVEEsICRlbnY6TE9DQUxBUFBEQVRBLCAkZW52OlBST0dSQU1EQVRBKSkgewogICAgICAgICAgICAgICAgICAgICAgICBHZXQtQ2hpbGRJdGVtIC1QYXRoICRiYXNlUGF0aCAtRGlyZWN0b3J5IC1GaWx0ZXIgIiokdGVybSoiIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIC1EZXB0aCAyIHwgRm9yRWFjaC1PYmplY3QgeyB0cnkgeyBSZW1vdmUtSXRlbSAkXy5GdWxsTmFtZSAtUmVjdXJzZSAtRm9yY2U7IFdyaXRlLUxvZyAiRGVsZXRlZDogJCgkXy5GdWxsTmFtZSkiICJTdWNjZXNzIiB9IGNhdGNoIHsgV3JpdGUtTG9nICJDbGVhbnVwIGRpciBmYWlsZWQ6ICQoJF8uRnVsbE5hbWUpIiAiV2FybiIgfSB9CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRyZWdQYXRoIGluIEAoIkhLQ1U6XFNvZnR3YXJlIiwgIkhLTE06XFNPRlRXQVJFXFdPVzY0MzJOb2RlIikpIHsKICAgICAgICAgICAgICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkcmVnUGF0aCkgeyBHZXQtQ2hpbGRJdGVtIC1QYXRoICRyZWdQYXRoIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIC1EZXB0aCAxIHwgV2hlcmUtT2JqZWN0IHsgJF8uTmFtZS5Db250YWlucygkdGVybSkgfSB8IEZvckVhY2gtT2JqZWN0IHsgdHJ5IHsgUmVtb3ZlLUl0ZW0gJF8uUFNQYXRoIC1SZWN1cnNlIC1Gb3JjZTsgV3JpdGUtTG9nICJEZWxldGVkIFJlZzogJCgkXy5OYW1lKSIgIlN1Y2Nlc3MiIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIkNsZWFudXAgcmVnIGZhaWxlZDogJCgkXy5OYW1lKSIgIldhcm4iIH0gfSB9CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIFVwZGF0ZS1JbnN0YWxsZWRDYWNoZQogICAgICAgIGlmICgkc3luYy5jb250cm9sc1siQ2hrU2hvd0luc3RhbGxlZCJdKSB7IEFwcGx5LUZpbHRlcnMgfQogICAgICAgIEhpZGUtUHJvZ3Jlc3M7IFNldC1TdGF0dXMgIlJlYWR5IgogICAgICAgIFNob3ctSW5mbyAiVW5pbnN0YWxsIENvbXBsZXRlIiAiJCgkc2VsZWN0ZWQuQ291bnQpIGFwcGxpY2F0aW9uKHMpIHVuaW5zdGFsbGVkIHZpYSAkcGtnLiIKICAgICAgICBXcml0ZS1Mb2cgIlVuaW5zdGFsbGF0aW9uIGNvbXBsZXRlLiIgIkhlYWRlciIKICAgIH0pCn0KCmlmICgkc3luYy5jb250cm9sc1siUGtnV2luR2V0Il0pIHsgJHN5bmMuY29udHJvbHNbIlBrZ1dpbkdldCJdLkFkZF9DaGVja2VkKHsgJHNjcmlwdDpwa2dNYW5hZ2VyID0gIndpbmdldCI7IFdyaXRlLUxvZyAiUGFja2FnZSBtYW5hZ2VyOiBXaW5HZXQiICJJbmZvIiB9KSB9CmlmICgkc3luYy5jb250cm9sc1siUGtnQ2hvY28iXSkgeyAkc3luYy5jb250cm9sc1siUGtnQ2hvY28iXS5BZGRfQ2hlY2tlZCh7ICRzY3JpcHQ6cGtnTWFuYWdlciA9ICJjaG9jbyI7IFdyaXRlLUxvZyAiUGFja2FnZSBtYW5hZ2VyOiBDaG9jb2xhdGV5IiAiSW5mbyIgfSkgfQo='))
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
        if ($sync.controls["ChkShowInstalled"]) { Apply-Filters }
        Hide-Progress; Set-Status "Ready"
        Show-Info "Installation Complete" "$($selected.Count) application(s) installed via $pkg."
        Write-Log "Installation complete." "Header"
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
        if ($sync.controls["ChkShowInstalled"]) { Apply-Filters }
        Hide-Progress; Set-Status "Ready"
        Show-Info "Uninstall Complete" "$($selected.Count) application(s) uninstalled via $pkg."
        Write-Log "Uninstallation complete." "Header"
    })
}

if ($sync.controls["PkgWinGet"]) { $sync.controls["PkgWinGet"].Add_Checked({ $script:pkgManager = "winget"; Write-Log "Package manager: WinGet" "Info" }) }
if ($sync.controls["PkgChoco"]) { $sync.controls["PkgChoco"].Add_Checked({ $script:pkgManager = "choco"; Write-Log "Package manager: Chocolatey" "Info" }) }

$script:__mod_features = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aWYgKCRzeW5jLmNvbnRyb2xzWyJCdG5SdW5GZWF0dXJlcyJdIC1hbmQgJHN5bmMuY29uZmlncy5mZWF0dXJlcyAtYW5kICRzeW5jLmNvbmZpZ3MuZmVhdHVyZXMuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAiRmVhdHVyZXMiKSB7CiAgICAkc3luYy5jb250cm9sc1siQnRuUnVuRmVhdHVyZXMiXS5BZGRfQ2xpY2soewogICAgICAgICRzZWxlY3RlZCA9ICRmZWF0dXJlc0NoZWNrYm94ZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc0NoZWNrZWQgLWVxICR0cnVlIH0KICAgICAgICBpZiAoJHNlbGVjdGVkLkNvdW50IC1lcSAwKSB7IFdyaXRlLUxvZyAiTm8gZmVhdHVyZXMgc2VsZWN0ZWQuIiAiV2FybiI7IHJldHVybiB9CiAgICAgICAgaWYgKC1ub3QgKFNob3ctQ29uZmlybSAiUnVuIEZlYXR1cmVzIiAiQXBwbHkgJCgkc2VsZWN0ZWQuQ291bnQpIHNlbGVjdGVkIGZlYXR1cmUocyk/IikpIHsgcmV0dXJuIH0KICAgICAgICBXcml0ZS1Mb2cgIlJ1bm5pbmcgU2VsZWN0ZWQgRmVhdHVyZXMuLi4iICJIZWFkZXIiCiAgICAgICAgU2V0LVN0YXR1cyAiUnVubmluZyAkKCRzZWxlY3RlZC5Db3VudCkgZmVhdHVyZShzKS4uLiIKICAgICAgICBmb3JlYWNoICgkY2IgaW4gJHNlbGVjdGVkKSB7CiAgICAgICAgICAgICRmZWF0S2V5ID0gJGNiLlRhZwogICAgICAgICAgICAkZmVhdCA9ICRzeW5jLmNvbmZpZ3MuZmVhdHVyZXMuRmVhdHVyZXMuJGZlYXRLZXkKICAgICAgICAgICAgaWYgKC1ub3QgJGZlYXQpIHsgY29udGludWUgfQogICAgICAgICAgICBXcml0ZS1Mb2cgIlJ1bm5pbmc6ICQoJGZlYXQuY29udGVudCkiICJJbmZvIgogICAgICAgICAgICB0cnkgeyAmIChbc2NyaXB0YmxvY2tdOjpDcmVhdGUoJGZlYXQuc2NyaXB0KSk7IFdyaXRlLUxvZyAiRmVhdHVyZSBjb21wbGV0ZWQ6ICQoJGZlYXQuY29udGVudCkiICJTdWNjZXNzIiB9IGNhdGNoIHsgV3JpdGUtTG9nICJGZWF0dXJlIGZhaWxlZDogJCgkZmVhdC5jb250ZW50KTogJF8iICJFcnJvciIgfQogICAgICAgIH0KICAgICAgICBTZXQtU3RhdHVzICJSZWFkeSIKICAgICAgICBTaG93LUluZm8gIkZlYXR1cmVzIENvbXBsZXRlIiAiJCgkc2VsZWN0ZWQuQ291bnQpIGZlYXR1cmUocykgYXBwbGllZC4iCiAgICAgICAgV3JpdGUtTG9nICJBbGwgc2VsZWN0ZWQgZmVhdHVyZXMgY29tcGxldGVkLiIgIkhlYWRlciIKICAgIH0pCn0K'))
if ($sync.controls["BtnRunFeatures"] -and $sync.configs.features -and $sync.configs.features.PSObject.Properties.Name -contains "Features") {
    $sync.controls["BtnRunFeatures"].Add_Click({
        $selected = $featuresCheckboxes | Where-Object { $_.IsChecked -eq $true }
        if ($selected.Count -eq 0) { Write-Log "No features selected." "Warn"; return }
        if (-not (Show-Confirm "Run Features" "Apply $($selected.Count) selected feature(s)?")) { return }
        Write-Log "Running Selected Features..." "Header"
        Set-Status "Running $($selected.Count) feature(s)..."
        foreach ($cb in $selected) {
            $featKey = $cb.Tag
            $feat = $sync.configs.features.Features.$featKey
            if (-not $feat) { continue }
            Write-Log "Running: $($feat.content)" "Info"
            try { & ([scriptblock]::Create($feat.script)); Write-Log "Feature completed: $($feat.content)" "Success" } catch { Write-Log "Feature failed: $($feat.content): $_" "Error" }
        }
        Set-Status "Ready"
        Show-Info "Features Complete" "$($selected.Count) feature(s) applied."
        Write-Log "All selected features completed." "Header"
    })
}

$sync.configs.features = @'
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
$sync.configs.themes = @'
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
$sync.configs.meta = @'
{
  "version": "2.3"
}

'@ | ConvertFrom-Json
$sync.configs.apps = @'
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
$sync.configs.preferences = @'
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
$sync.configs.tweaks = @'
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
$sync.configs.dns = @'
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
if ($Verbose) { $sync.logLevel = "Info" }
$sync.appRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Show-HksUtilLogo
Write-Log "Starting HksUtil v$($sync.version)..." "Header"

if ($Export) {
    $sel = @{ CheckedApps = @(); CheckedTweaks = @() }
    try {
        $selJson = $sel | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($Export, $selJson, [System.Text.UTF8Encoding]::new($false))
        Write-Log "Exported to $Export" "Success"
    } catch { Write-Log "Export failed: $_" "Error" }
}

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
                }
            }
            Write-Log "Headless apply complete." "Success"
        } catch { Write-Log "Headless apply failed: $_" "Error" }
    } else { Write-Log "NoUI mode: use -Config <path> -Apply to apply." "Warn" }
    $sync.runspace.Dispose(); $sync.runspace.Close(); pause; exit
}

try {
    $xamlContent = $script:embeddedXaml -replace 'x:Name="([^"]+)"', 'Name="$1"'
    [xml]$xaml = $xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $sync.window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
} catch { Write-Log "FATAL ERROR loading UI: $_" "Error"; pause; exit }

$sync.controls = @{}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { $sync.controls[$_.Name] = $sync.window.FindName($_.Name) }
foreach ($k in @($sync.controls.Keys)) { if (-not $sync.controls[$k]) { $sync.controls.Remove($k) } }

Apply-Theme "dark"
if ($sync.controls["TitleText"]) { $sync.controls["TitleText"].Add_MouseLeftButtonDown({ $sync.window.DragMove() }) }

# Re-execute modules with populated controls
$script:__modOrder = @("logger","core","theme","navigation","tweaks","search","toolbar","dns","terminal","utility","build","install","features")
foreach ($_m in $script:__modOrder) {
    $_var = "__mod_$_m"
    $_code = Get-Variable $_var -ValueOnly -ErrorAction SilentlyContinue
    if ($_code) { . ([ScriptBlock]::Create($_code)) }
}

if ($sync.controls["BtnClearSearch"]) { $sync.controls["BtnClearSearch"].Add_Click({ if ($sync.controls["SearchBox"]) { $sync.controls["SearchBox"].Text = ""; $sync.controls["SearchBox"].Focus() } }) }
if ($sync.controls["BtnSelectAll"]) { $sync.controls["BtnSelectAll"].Add_Click({ foreach ($cb in $appCheckboxes) { if ($cb.Visibility -eq "Visible") { $cb.IsChecked = $true } }; Update-SelectedCount; Write-Log "All visible apps selected." "Info" }) }
if ($sync.controls["BtnClearSelection"]) { $sync.controls["BtnClearSelection"].Add_Click({ foreach ($cb in $appCheckboxes) { $cb.IsChecked = $false }; Update-SelectedCount; Write-Log "Selection cleared." "Info" }) }
if ($sync.controls["BtnCollapseAll"]) {
    $sync.controls["BtnCollapseAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $true; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Collapsed" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "+ $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($sync.controls["BtnExpandAll"]) {
    $sync.controls["BtnExpandAll"].Add_Click({
        foreach ($cat in $script:categoryItems.Keys) { $script:categoryCollapsed[$cat] = $false; foreach ($item in $script:categoryItems[$cat]) { $item.Visibility = "Visible" } }
        foreach ($panel in @($appPanels)) { foreach ($child in $panel.Children) { if ($child -is [System.Windows.Controls.TextBlock] -and $script:categoryItems.ContainsKey($child.Tag)) { $child.Text = "- $($child.Tag.ToUpper()) ($($script:categoryItems[$child.Tag].Count))" } } }
    })
}
if ($sync.controls["ChkShowInstalled"]) {
    $sync.controls["ChkShowInstalled"].Add_Checked({ Write-Log "Filtering to installed apps..." "Info"; if ($script:installedAppIds.Count -eq 0) { Update-InstalledCache }; Apply-Filters })
    $sync.controls["ChkShowInstalled"].Add_Unchecked({ Apply-Filters })
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

$sync.window.Add_Closing({
    $sync.runspace.Dispose()
    $sync.runspace.Close()
    [System.GC]::Collect()
})

try { $sync.window.ShowDialog() | Out-Null } catch { Write-Log "UI Runtime Error: $_" "Error"; pause }
Write-Log "HksUtil Closed." "Header"