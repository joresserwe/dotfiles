# f13+z — focus the previously focused WINDOW (back-and-forth), replacing
# the recent-workspace toggle this key carried over from the mac config.
# On the mac side alt-z is workspace-back-and-forth, but with one main
# window per workspace that always FELT like "previous window" — this is
# the superset: same-workspace window flips work too, and a window on
# another workspace switches there automatically (focus --container-id).
#
# History comes from the state-border daemon (tacky-borders/state-border.ps1),
# which already subscribes to focus_changed and writes the previous window's
# container id to %TEMP%\glazewm-prev-window.txt.

$ErrorActionPreference = 'SilentlyContinue'
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
$histFile = Join-Path $env:TEMP 'glazewm-prev-window.txt'

if (-not (Test-Path $histFile)) { exit 0 }
$prevId = (Get-Content $histFile -First 1).Trim()
if (-not $prevId) { exit 0 }

$win = (& $gw query windows 2>$null | ConvertFrom-Json).data.windows |
  Where-Object { $_.id -eq $prevId } | Select-Object -First 1
if (-not $win) { exit 0 }

if ($win.state.type -eq 'minimized') {
  & $gw command --id $win.id toggle-minimized | Out-Null
}
& $gw command focus --container-id $win.id | Out-Null
