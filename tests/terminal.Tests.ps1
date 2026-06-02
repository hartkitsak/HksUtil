$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path "$here\.."

Describe "Terminal" {
    BeforeAll {
        . "$moduleRoot\modules\logger.ps1"
        $script:controls = @{}
        . "$moduleRoot\modules\terminal.ps1"
        Mock -CommandName Start-Process
        Mock -CommandName Show-Confirm -MockWith { $true }
    }

    It "Invoke-TerminalAction defined" {
        (Get-Command Invoke-TerminalAction -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
    }

    It "launches winget install process" {
        Invoke-TerminalAction "winget install vlc"
        Assert-MockCalled -CommandName Start-Process -Times 1
    }

    It "launches choco uninstall process" {
        Invoke-TerminalAction "choco uninstall vlc"
        Assert-MockCalled -CommandName Start-Process -Times 2
    }
}
