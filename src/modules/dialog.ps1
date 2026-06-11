function New-DialogWindow {
    param([string]$Title, [string]$Message, [string]$DialogType = "Info")
    if ($sync.noUI) { return $null }
    $win = New-Object System.Windows.Window
    $win.Title = $Title
    $win.Width = 440; $win.Height = 220
    $win.SizeToContent = "Height"
    $win.WindowStartupLocation = "CenterOwner"
    $win.Owner = $sync.window
    $win.WindowStyle = "None"
    $win.ResizeMode = "NoResize"
    $win.AllowsTransparency = $true
    $win.Background = "#00000000"
    $win.Topmost = $true
    $border = New-Object System.Windows.Controls.Border
    $border.Background = $null
    $border.BorderBrush = $null
    $border.BorderThickness = "0"
    $border.CornerRadius = "10"
    $border.UseLayoutRounding = $true
    $outerBorder = New-Object System.Windows.Controls.Border
    $outerBorder.Background = $sync.window.FindResource("cardBackground")
    $outerBorder.BorderBrush = $sync.window.FindResource("cardBorder")
    $outerBorder.BorderThickness = "1"
    $outerBorder.CornerRadius = "10"
    $outerBorder.Padding = "24,20"
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Orientation = "Vertical"
    $titleTb = New-Object System.Windows.Controls.TextBlock
    $titleTb.Text = $Title
    $titleTb.FontSize = 18
    $titleTb.FontWeight = "Bold"
    $titleTb.Foreground = $sync.window.FindResource("pageTitleColor")
    $titleTb.Margin = "0,0,0,6"
    $stack.Children.Add($titleTb) | Out-Null
    $msgTb = New-Object System.Windows.Controls.TextBlock
    $msgTb.Text = $Message
    $msgTb.FontSize = 13
    $msgTb.Foreground = $sync.window.FindResource("cardForeground")
    $msgTb.TextWrapping = "Wrap"
    $msgTb.Margin = "0,0,0,20"
    $stack.Children.Add($msgTb) | Out-Null
    $btnStack = New-Object System.Windows.Controls.StackPanel
    $btnStack.Orientation = "Horizontal"
    $btnStack.HorizontalAlignment = "Right"
    if ($DialogType -eq "Confirm") {
        $yesBtn = New-Object System.Windows.Controls.Button
        $yesBtn.Content = "Yes"
        $yesBtn.Width = 80
        $yesBtn.Height = 32
        $yesBtn.Margin = "0,0,8,0"
        $yesBtn.Cursor = "Hand"
        $yesBtn.Style = $sync.window.FindResource("ActionBtn")
        $yesBtn.Add_Click({ $win.DialogResult = $true; $win.Close() })
        $btnStack.Children.Add($yesBtn) | Out-Null
        $noBtn = New-Object System.Windows.Controls.Button
        $noBtn.Content = "No"
        $noBtn.Width = 80
        $noBtn.Height = 32
        $noBtn.Cursor = "Hand"
        $noBtn.Style = $sync.window.FindResource("SecondaryBtn")
        $noBtn.Add_Click({ $win.DialogResult = $false; $win.Close() })
        $btnStack.Children.Add($noBtn) | Out-Null
    } else {
        $okBtn = New-Object System.Windows.Controls.Button
        $okBtn.Content = "OK"
        $okBtn.Width = 80
        $okBtn.Height = 32
        $okBtn.Cursor = "Hand"
        $okBtn.Style = $sync.window.FindResource("ActionBtn")
        $okBtn.Add_Click({ $win.DialogResult = $true; $win.Close() })
        $btnStack.Children.Add($okBtn) | Out-Null
    }
    $stack.Children.Add($btnStack) | Out-Null
    $border.Child = $stack
    $outerBorder.Child = $border
    $win.Content = $outerBorder
    $effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $effect.BlurRadius = 20
    $effect.Opacity = 0.4
    $effect.ShadowDepth = 0
    $effect.Color = [System.Windows.Media.Colors]::Black
    $outerBorder.Effect = $effect
    $win.Opacity = 0
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
    $anim.From = 0; $anim.To = 1; $anim.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
    $win.BeginAnimation([System.Windows.Window]::OpacityProperty, $anim)
    return $win
}

function Show-Confirm {
    param([string]$Title, [string]$Message)
    if ($sync.noUI) { return $true }
    $win = New-DialogWindow -Title $Title -Message $Message -DialogType "Confirm"
    if (-not $win) { return $true }
    return $win.ShowDialog()
}

function Show-Info {
    param([string]$Title, [string]$Message)
    if ($sync.noUI) { return }
    $win = New-DialogWindow -Title $Title -Message $Message -DialogType "Info"
    if (-not $win) { return }
    $null = $win.ShowDialog()
}
