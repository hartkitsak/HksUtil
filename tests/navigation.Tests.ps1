$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path "$here\.."

Describe "Navigation" {
    BeforeAll {
        function New-NavBtn {
            $b = New-Object PSObject; $b | Add-Member NoteProperty Tag $null
            $b | Add-Member ScriptMethod SetResourceReference { param($a, $b) }
            $b | Add-Member ScriptMethod ClearValue { param($a) }
            $b | Add-Member ScriptMethod Add_Click { param($h) }
            $b | Add-Member NoteProperty IsEnabled $true
            $b
        }
        function New-Page { $p = New-Object PSObject; $p | Add-Member NoteProperty Visibility "Collapsed"; $p }
        $script:controls = @{}
        foreach ($name in @("Install","Tweaks","Features","Preferences","Legacy","Settings")) {
            $controls["Nav$name"] = New-NavBtn
            $controls["Page$name"] = New-Page
        }
        $script:window = New-Object PSObject; $window | Add-Member ScriptMethod Add_KeyDown { param($handler) }
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\navigation.ps1"
    }

    It "defines Switch-Page" {
        (Get-Command Switch-Page -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
    }

    It "defines pages hashtable" {
        $pages.Count | Should Be 6
    }

    It "defines navButtons hashtable" {
        $navButtons.Count | Should Be 6
    }

    It "nav buttons have Tag set" {
        $controls["NavInstall"].Tag | Should Be "Install"
        $controls["NavTweaks"].Tag | Should Be "Tweaks"
    }
}
