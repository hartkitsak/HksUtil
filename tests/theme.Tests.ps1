$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path "$here\.."

Describe "Theme" {
    BeforeAll {
        $script:appRoot = $moduleRoot
        $sync = [Hashtable]::Synchronized(@{})
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\theme.ps1"
        Mock -CommandName Write-Log
    }

    It "Apply-Theme defined" {
        (Get-Command Apply-Theme -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
    }

    It "currentTheme defaults to Dark" {
        $script:currentTheme | Should Be "dark"
    }

    It "appRoot is set" {
        $script:appRoot | Should Not BeNullOrEmpty
        $script:appRoot | Should Be $moduleRoot
    }
}
