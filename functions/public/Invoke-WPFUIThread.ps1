function Invoke-WPFUIThread {
    param([scriptblock]$ScriptBlock)

    if ($sync.noUI) { return }
    $sync.window.Dispatcher.Invoke([action]$ScriptBlock)
}
