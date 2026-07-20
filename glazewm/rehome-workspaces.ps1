# Rehome every workspace to its bound monitor — hyper+w.
#
# Mapping mirrors generate-config.ps1's bind_to_monitor: ws 1-3 -> monitor 0,
# 4-6 -> monitor 1, 7-9 -> monitor 2 (glazewm monitor list order). glazewm
# honors bind_to_monitor only at workspace creation; f13+shift+[ / ] (or any
# move-workspace) permanently re-homes one and there is no built-in reset,
# so an accidental press leaves layouts like [1] | [2,3,4,5,6] behind.
#
# Strategy: repeatedly find a misplaced workspace, focus it, and nudge it
# one monitor toward home (monitors assumed side by side, sorted by x).

$ErrorActionPreference = 'SilentlyContinue'

# PS 5.1 decodes native stdout via the console codepage while glazewm emits
# UTF-8 — without this, a Korean window title mis-decodes into invalid JSON
# and every query below parses to $null.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
$wsPerMon = 3

$orig = (& $gw query focused 2>$null | ConvertFrom-Json).data.focused

for ($pass = 0; $pass -lt 12; $pass++) {
  $mons = (& $gw query monitors 2>$null | ConvertFrom-Json).data.monitors |
    Sort-Object x
  $fix = $null
  for ($mi = 0; $mi -lt $mons.Count; $mi++) {
    foreach ($ws in $mons[$mi].children) {
      if ($ws.type -ne 'workspace') { continue }
      $target = [math]::Floor(([int]$ws.name - 1) / $wsPerMon)
      if ($target -ge $mons.Count) { $target = $mons.Count - 1 }
      if ($target -ne $mi) {
        $fix = @{ name = $ws.name; dir = if ($target -lt $mi) { 'left' } else { 'right' } }
        break
      }
    }
    if ($fix) { break }
  }
  if (-not $fix) { break }
  & $gw command focus --workspace $fix.name | Out-Null
  Start-Sleep -Milliseconds 300
  & $gw command move-workspace --direction $fix.dir | Out-Null
  Start-Sleep -Milliseconds 300
}

# Return focus to where the user was.
if ($orig -and $orig.type -eq 'window') {
  & $gw command focus --container-id $orig.id | Out-Null
}
