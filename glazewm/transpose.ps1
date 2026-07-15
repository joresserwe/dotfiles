# f13+shift+s — transpose the focused window's split (horizontal <-> vertical).
#
# glazewm has no rotate/transpose command, and toggle-tiling-direction only
# affects where the NEXT window is inserted — verified empirically 2026-07-15:
# coordinates of an existing 2-window split are untouched by it. Also
# verified: moving a window perpendicular in a pure 2-window split just
# SWAPS the pair, it doesn't restack. The recipe that works (i3-style):
#   1. toggle-tiling-direction on the focused window — its insertion
#      direction flips perpendicular to the current split
#   2. move the OTHER window toward the focused one — it inserts INTO the
#      focused window's perpendicular container, restacking the pair
# With 1 or 3+ tiling siblings there is no clean transpose; fall back to
# the plain insertion-direction toggle.

$ErrorActionPreference = 'SilentlyContinue'
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'

$f = (& $gw query focused 2>$null | ConvertFrom-Json).data.focused
if (-not $f -or $f.type -ne 'window' -or $f.state.type -ne 'tiling') {
  & $gw command toggle-tiling-direction | Out-Null
  exit 0
}

$wins = (& $gw query windows 2>$null | ConvertFrom-Json).data.windows
$siblings = @($wins | Where-Object { $_.parentId -eq $f.parentId -and $_.state.type -eq 'tiling' })
if ($siblings.Count -ne 2) {
  & $gw command toggle-tiling-direction | Out-Null
  exit 0
}

$other = $siblings | Where-Object { $_.id -ne $f.id } | Select-Object -First 1
# Direction from the OTHER window toward the FOCUSED one.
$dir = if ([math]::Abs($f.y - $other.y) -lt 5) {
  if ($other.x -lt $f.x) { 'right' } else { 'left' }    # horizontal pair
} else {
  if ($other.y -lt $f.y) { 'down' } else { 'up' }       # vertical pair
}
& $gw command --id $f.id toggle-tiling-direction | Out-Null
& $gw command --id $other.id move --direction $dir | Out-Null
