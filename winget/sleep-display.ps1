Add-Type -Namespace Win32 -Name Display -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam,
    uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@

# SC_MONITORPOWER that lands while the launching key is still down is undone by
# its key-up event and the panel comes straight back on.
Start-Sleep -Milliseconds 700

$HWND_BROADCAST   = [IntPtr]0xFFFF
$WM_SYSCOMMAND    = 0x0112
$SC_MONITORPOWER  = [IntPtr]0xF170
$POWER_OFF        = [IntPtr]2
$SMTO_ABORTIFHUNG = 0x0002

# A broadcast blocks on every top-level window that stops pumping messages, and
# run-hidden.vbs detaches this process, so an untimed send strands a PowerShell
# that nothing reaps.
$discard = [IntPtr]::Zero
[void][Win32.Display]::SendMessageTimeout(
    $HWND_BROADCAST, $WM_SYSCOMMAND, $SC_MONITORPOWER, $POWER_OFF,
    $SMTO_ABORTIFHUNG, 2000, [ref]$discard)
