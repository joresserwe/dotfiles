# glazewm migrates workspaces off a removed monitor but never moves them
# back when the monitor returns. Exits when glazewm does (the sub pipe
# closes).

$ErrorActionPreference = 'SilentlyContinue'

$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
$rehome = Join-Path $PSScriptRoot 'rehome-workspaces.ps1'

& $gw sub --events monitor_added monitor_removed 2>$null | ForEach-Object {
    # RDP fullscreen/windowed switches emit add/remove in bursts, hence the
    # settle delay.
    Start-Sleep -Milliseconds 2500
    & $rehome
}
