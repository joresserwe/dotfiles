# Second wm-redraw ~1s after a move to catch async DPI resize bugs.
# Scoped: only fires if the foreground window is in $targets, so apps that
# don't have the DPI bug aren't unnecessarily re-tiled.
# Add process names here as needed (match ProcessName from Get-Process).

$targets = @('wezterm-gui')

Start-Sleep -Seconds 1

Add-Type -Namespace U -Name W -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr GetForegroundWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint pid);
'@

$hwnd = [U.W]::GetForegroundWindow()
$procId = 0
[void][U.W]::GetWindowThreadProcessId($hwnd, [ref]$procId)
$name = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName

if ($name -and ($targets -contains $name)) {
    & "C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe" command wm-redraw | Out-Null
}
