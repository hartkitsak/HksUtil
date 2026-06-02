$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path "$here\.."

Describe "Invoke-WPFUIThread" {
    BeforeAll {
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\core.ps1"
    }

    It "runs scriptblock directly when no dispatcher" {
        $script:coreResult = $null
        Invoke-WPFUIThread { $script:coreResult = "done" }
        $script:coreResult | Should Be "done"
    }

    It "runs scriptblock when dispatcher needs invoke" {
        $script:window = New-Object PSObject
        $dispatcher = New-Object PSObject
        $dispatcher | Add-Member -MemberType ScriptMethod -Name CheckAccess -Value { return $false }
        $dispatcher | Add-Member -MemberType ScriptMethod -Name Invoke -Value { param($action, $prio) $action.Invoke() }
        $window | Add-Member -MemberType NoteProperty -Name Dispatcher -Value $dispatcher
        $script:coreResult = $null
        Invoke-WPFUIThread { $script:coreResult = "done" }
        $script:coreResult | Should Be "done"
    }
}

Describe "Show-Progress / Hide-Progress" {
    BeforeAll {
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\core.ps1"
        Mock -CommandName Set-ProgressTaskbar
        $script:window = $null
    }

    It "shows overlay with text" {
        $po = New-Object PSObject; $po | Add-Member NoteProperty Visibility "Collapsed"
        $pt = New-Object PSObject; $pt | Add-Member NoteProperty Text ""
        $pst = New-Object PSObject; $pst | Add-Member NoteProperty Text ""
        $pb = New-Object PSObject; $pb | Add-Member NoteProperty Value 0.0; $pb | Add-Member NoteProperty IsIndeterminate $false
        $script:controls = @{ ProgressOverlay = $po; ProgressText = $pt; ProgressSubText = $pst; ProgressBar = $pb }
        Show-Progress "Installing..." "Sub" 0.5
        $controls["ProgressOverlay"].Visibility | Should Be "Visible"
        $controls["ProgressText"].Text | Should Be "Installing..."
    }

    It "hides overlay" {
        $po = New-Object PSObject; $po | Add-Member NoteProperty Visibility "Visible"
        $script:controls = @{ ProgressOverlay = $po }
        Hide-Progress
        $controls["ProgressOverlay"].Visibility | Should Be "Collapsed"
    }

    It "does nothing when overlay missing" {
        $script:controls = @{}
        { Show-Progress "test" } | Should Not Throw
        { Hide-Progress } | Should Not Throw
    }
}

Describe "Set-ProgressTaskbar" {
    BeforeAll {
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\core.ps1"
    }

    It "does not throw when window is null" {
        $script:window = $null
        { Set-ProgressTaskbar -state "None" } | Should Not Throw
    }
}

Describe "Update-InstalledCache" {
    BeforeAll {
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\core.ps1"
        Mock -CommandName Get-Command -MockWith { $null }
    }

    It "warns when winget not available" {
        Update-InstalledCache
        $script:installedAppIds.Count | Should Be 0
    }
}
