$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path "$here\.."

Describe "Tweaks" {
    BeforeAll {
        $btn = New-Object PSObject; $btn | Add-Member ScriptMethod Add_Click { param($h) }
        $btn2 = New-Object PSObject; $btn2 | Add-Member ScriptMethod Add_Click { param($h) }
        $script:controls = @{ BtnRunTweaks = $btn; BtnUndoTweaks = $btn2 }
        $script:tweakCheckboxes = @()
        $script:tweakUndoLog = @{}
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\tweaks.ps1"
    }

    It "Save-OriginalValues stores registry entries from config" {
        $tweak = @{ registry = @( @{ path = "HKCU:\Software\Test"; name = "Value1"; type = "String" } ) }
        $script:tweakUndoLog = @{}
        Mock Test-Path { $true } -ModuleName ""
        Mock Get-ItemProperty { New-Object PSObject | Add-Member -PassThru NoteProperty Value1 "originalData" }
        Save-OriginalValues -tweakKey "WPFTweakTest" -tweak $tweak
        $script:tweakUndoLog.ContainsKey("WPFTweakTest") | Should Be $true
    }

    It "Save-OriginalValues skips duplicates" {
        $tweak = @{ }
        Save-OriginalValues -tweakKey "WPFTweakTest" -tweak $tweak
        $script:tweakUndoLog.Count | Should Be 1
    }

    It "Save-OriginalValues handles empty tweak" {
        $tweak = @{ info = "Just info" }
        Save-OriginalValues -tweakKey "WPFTweakInfo" -tweak $tweak
        $script:tweakUndoLog["WPFTweakInfo"].Registry.Count | Should Be 0
        $script:tweakUndoLog["WPFTweakInfo"].Services.Count | Should Be 0
    }

    It "Invoke-UndoTweaks does nothing when empty" {
        $script:tweakUndoLog = @{}
        { Invoke-UndoTweaks } | Should Not Throw
    }
}
