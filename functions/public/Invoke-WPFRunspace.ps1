function Invoke-WPFRunspace {
    param(
        [scriptblock]$ScriptBlock,
        [array]$ArgumentList,
        [array]$ParameterList
    )

    $ps = [powershell]::Create()
    $ps.AddScript($ScriptBlock)
    if ($ArgumentList) { $ps.AddArgument($ArgumentList) }
    foreach ($param in $ParameterList) {
        $ps.AddParameter($param[0], $param[1])
    }
    $ps.RunspacePool = $sync.runspace

    $handle = $ps.BeginInvoke()
    if ($handle.IsCompleted) {
        $ps.EndInvoke($handle)
        $ps.Dispose()
    }
    return $handle
}
