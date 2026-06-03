<#
.NOTES
    Author  : hartkitsak
    GitHub  : https://github.com/hartkitsak/HksUtil
    Version : #{replaceme}
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
$sync.version = "#{replaceme}"
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
