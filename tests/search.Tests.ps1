$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Resolve-Path "$here\.."

Describe "Update-SelectedCount" {
    BeforeAll {
        $sync = [Hashtable]::Synchronized(@{})
        $ctrl = New-Object PSObject; $ctrl | Add-Member NoteProperty Text ""
        $sb = New-Object PSObject; $sb | Add-Member NoteProperty Text ""; $sb | Add-Member ScriptMethod Add_TextChanged { param($h) }
        $chk = New-Object PSObject; $chk | Add-Member NoteProperty IsChecked $false; $chk | Add-Member ScriptMethod Add_Checked { param($h) }; $chk | Add-Member ScriptMethod Add_Unchecked { param($h) }
        $ep = New-Object PSObject; $ep | Add-Member NoteProperty Count 0
        $sync.controls = @{ LblSelectedCount = $ctrl; SearchBox = $sb; ChkShowInstalled = $chk; AppPanel1 = $ep; AppPanel2 = $ep; AppPanel3 = $ep }
        $script:window = New-Object PSObject; $window | Add-Member NoteProperty Dispatcher $null
        $script:installedAppIds = @{}
        $script:appCheckboxes = @()
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\search.ps1"
    }

    It "shows count of selected checkboxes" {
        $cb1 = New-Object PSObject; $cb1 | Add-Member NoteProperty IsChecked $true
        $cb2 = New-Object PSObject; $cb2 | Add-Member NoteProperty IsChecked $false
        $cb3 = New-Object PSObject; $cb3 | Add-Member NoteProperty IsChecked $true
        $script:appCheckboxes = @($cb1, $cb2, $cb3)
        Update-SelectedCount
        $sync.controls["LblSelectedCount"].Text | Should Be "Selected Apps: 2"
    }

    It "shows 0 when none selected" {
        $cb1 = New-Object PSObject; $cb1 | Add-Member NoteProperty IsChecked $false
        $cb2 = New-Object PSObject; $cb2 | Add-Member NoteProperty IsChecked $false
        $script:appCheckboxes = @($cb1, $cb2)
        Update-SelectedCount
        $sync.controls["LblSelectedCount"].Text | Should Be "Selected Apps: 0"
    }

    It "does not throw when LblSelectedCount missing" {
        $sync.controls["LblSelectedCount"] = $null
        $script:appCheckboxes = @()
        { Update-SelectedCount } | Should Not Throw
    }
}

Describe "Apply-Filters" {
    BeforeAll {
        $sync = [Hashtable]::Synchronized(@{})
        $sb = New-Object PSObject; $sb | Add-Member NoteProperty Text ""; $sb | Add-Member ScriptMethod Add_TextChanged { param($h) }
        $chk = New-Object PSObject; $chk | Add-Member NoteProperty IsChecked $false; $chk | Add-Member ScriptMethod Add_Checked { param($h) }; $chk | Add-Member ScriptMethod Add_Unchecked { param($h) }
        $ep = New-Object PSObject; $ep | Add-Member NoteProperty Count 0
        $sync.controls = @{ SearchBox = $sb; ChkShowInstalled = $chk; AppPanel1 = $ep; AppPanel2 = $ep; AppPanel3 = $ep }
        $script:window = New-Object PSObject; $window | Add-Member NoteProperty Dispatcher $null
        $script:installedAppIds = @{ "AppA" = $true }
        $script:appCheckboxes = @()
        . "$moduleRoot\modules\logger.ps1"
        . "$moduleRoot\modules\search.ps1"
    }

    It "shows all when no search or installed filter" {
        $cb1 = New-Object PSObject; $cb1 | Add-Member NoteProperty Content "AppA"; $cb1 | Add-Member NoteProperty Tag "AppA"; $cb1 | Add-Member NoteProperty Visibility "Visible"
        $cb2 = New-Object PSObject; $cb2 | Add-Member NoteProperty Content "AppB"; $cb2 | Add-Member NoteProperty Tag "AppB"; $cb2 | Add-Member NoteProperty Visibility "Visible"
        $script:appCheckboxes = @($cb1, $cb2)
        $sync.controls["SearchBox"].Text = ""
        $sync.controls["ChkShowInstalled"].IsChecked = $false
        Apply-Filters
        $cb1.Visibility | Should Be "Visible"
        $cb2.Visibility | Should Be "Visible"
    }

    It "filters by search text" {
        $cb1 = New-Object PSObject; $cb1 | Add-Member NoteProperty Content "AppA"; $cb1 | Add-Member NoteProperty Tag "AppA"; $cb1 | Add-Member NoteProperty Visibility "Visible"
        $cb2 = New-Object PSObject; $cb2 | Add-Member NoteProperty Content "AppB"; $cb2 | Add-Member NoteProperty Tag "AppB"; $cb2 | Add-Member NoteProperty Visibility "Visible"
        $script:appCheckboxes = @($cb1, $cb2)
        $sync.controls["SearchBox"].Text = "appa"
        $sync.controls["ChkShowInstalled"].IsChecked = $false
        Apply-Filters
        $cb1.Visibility | Should Be "Visible"
        $cb2.Visibility | Should Be "Collapsed"
    }
}
