# Start Menu is what launcher search (Raycast, Start, Win+R) indexes — the
# .lnk files must live there, not in an arbitrary folder, for the capture
# modes to be launchable by name without launcher-side configuration.

$sharex = 'C:\Program Files\ShareX\ShareX.exe'
if (-not (Test-Path $sharex)) { exit 0 }

$dir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\ShareX Commands'
New-Item -ItemType Directory -Force $dir | Out-Null

$ws = New-Object -ComObject WScript.Shell
$commands = @{
  'Capture Region'     = '-RectangleRegion'
  'Capture Fullscreen' = '-PrintScreen'
  'Capture Window'     = '-ActiveWindow'
  'Screen Recorder'    = '-ScreenRecorder'
}
foreach ($name in $commands.Keys) {
  $lnk = $ws.CreateShortcut((Join-Path $dir "$name.lnk"))
  $lnk.TargetPath = $sharex
  $lnk.Arguments = $commands[$name]
  $lnk.IconLocation = "$sharex,0"
  $lnk.Save()
}
