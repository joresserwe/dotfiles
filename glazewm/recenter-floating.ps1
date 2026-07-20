# Re-anchor floating windows that ended up outside their monitor after a
# cross-monitor move (chained onto f13+shift+hjkl, f13+shift+[ / ], and the
# generated f13+shift+1~9 sends).
#
# glazewm keeps floating windows' ABSOLUTE coordinates when they or their
# workspace cross monitors, leaving them straddling the boundary or parked
# on the wrong monitor entirely — and mis-sized on top when the DPIs differ
# (192 vs 120 here). position --centered re-anchors the window inside its
# actual monitor, which also makes the app rerun WM_DPICHANGED against sane
# bounds and fixes the size.
#
# Guard: only windows NOT fully inside their workspace's monitor are
# touched, so intra-monitor floating placement always survives — this is
# safe to chain after every move binding as a no-op in the common case.

$ErrorActionPreference = 'SilentlyContinue'

# PS 5.1 decodes native stdout via the console codepage while glazewm emits
# UTF-8 — without this, a Korean window title mis-decodes into invalid JSON
# and every query below parses to $null.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'

Start-Sleep -Milliseconds 400  # let the move finish placing the tree

function Get-FloatingWindows($node) {
  if ($node.type -eq 'window') {
    if ($node.state.type -eq 'floating') { $node }
    return
  }
  foreach ($c in $node.children) { Get-FloatingWindows $c }
}

$mons = (& $gw query monitors 2>$null | ConvertFrom-Json).data.monitors
foreach ($mon in $mons) {
  foreach ($ws in $mon.children) {
    if ($ws.type -ne 'workspace') { continue }
    foreach ($w in @(Get-FloatingWindows $ws)) {
      $inside = ($w.x -ge $mon.x) -and ($w.y -ge $mon.y) -and
                (($w.x + $w.width)  -le ($mon.x + $mon.width)) -and
                (($w.y + $w.height) -le ($mon.y + $mon.height))
      if (-not $inside) {
        & $gw command --id $w.id position --centered | Out-Null
      }
    }
  }
}
