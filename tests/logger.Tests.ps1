$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path "$here\.."

Describe "Show-HksUtilLogo" {
    BeforeAll {
        $sync = [Hashtable]::Synchronized(@{})
        . "$moduleRoot\modules\logger.ps1"
    }

    It "runs without error" {
        { Show-HksUtilLogo } | Should Not Throw
    }
}

Describe "Write-Log" {
    BeforeAll {
        $sync = [Hashtable]::Synchronized(@{})
        . "$moduleRoot\modules\logger.ps1"
    }

    It "does not throw for any type" {
        { Write-Log "test" "Info" } | Should Not Throw
        { Write-Log "test" "Success" } | Should Not Throw
        { Write-Log "test" "Error" } | Should Not Throw
        { Write-Log "test" "Warn" } | Should Not Throw
        { Write-Log "test" "Cmd" } | Should Not Throw
        { Write-Log "test" "Header" } | Should Not Throw
    }
}

Describe "Show-Confirm / Show-Info / Set-Status" {
    BeforeAll {
        $sync = [Hashtable]::Synchronized(@{})
        . "$moduleRoot\modules\logger.ps1"
        Mock -CommandName Show-Confirm -MockWith { $true }
        Mock -CommandName Show-Info
    }

    It "Show-Confirm returns mocked true" {
        Show-Confirm "T" "M" | Should Be $true
    }

    It "Show-Info runs without error" {
        { Show-Info "T" "M" } | Should Not Throw
    }

    It "Set-Status updates text when control exists" {
        $mockCtrl = New-Object PSObject
        $mockCtrl | Add-Member -MemberType NoteProperty -Name Text -Value ""
        $sync.controls = @{ StatusText = $mockCtrl }
        Set-Status "Ready"
        $sync.controls["StatusText"].Text | Should Be "Ready"
    }

    It "Set-Status does nothing when StatusText missing" {
        $sync.controls = @{}
        { Set-Status "test" } | Should Not Throw
    }
}
