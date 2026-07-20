# Swap the CONTENTS of the focused monitor's displayed workspace with the
# adjacent monitor's displayed one — f13+ctrl+[ / ].
#
# The workspace-to-monitor assignment (1-3 | 4-6 | ...) never changes; only
# the windows trade places, so it reads as "the two screens swapped" without
# re-homing any workspace (the move-workspace trap this family of bindings
# used to fall into). With 3+ monitors it pairs with the monitor in the
# pressed direction, so a "rotate" is just pressing it at each boundary.
#
# Focus stays on the CURRENT monitor — after the swap it shows the other
# workspace's windows, which matches the "my screen now has the other
# content" mental model. Floats that land across a DPI boundary get fixed
# by the recenter pass at the end.

param([Parameter(Mandatory)][ValidateSet('left','right')][string]$Direction)

$ErrorActionPreference = 'SilentlyContinue'

# PS 5.1 decodes native stdout via the console codepage while glazewm emits
# UTF-8 — without this, a Korean window title mis-decodes into invalid JSON
# and every query below parses to $null.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'

function Get-WindowIds($node) {
  if ($node.type -eq 'window') { $node.id; return }
  foreach ($c in $node.children) { Get-WindowIds $c }
}

$mons = @((& $gw query monitors 2>$null | ConvertFrom-Json).data.monitors | Sort-Object x)
$curIdx = $null
for ($i = 0; $i -lt $mons.Count; $i++) {
  if ($mons[$i].children | Where-Object { $_.type -eq 'workspace' -and $_.hasFocus }) { $curIdx = $i }
}
if ($null -eq $curIdx) { exit 0 }
$adjIdx = if ($Direction -eq 'left') { $curIdx - 1 } else { $curIdx + 1 }
if ($adjIdx -lt 0 -or $adjIdx -ge $mons.Count) { exit 0 }

$wsCur = $mons[$curIdx].children | Where-Object { $_.type -eq 'workspace' -and $_.isDisplayed } | Select-Object -First 1
$wsAdj = $mons[$adjIdx].children | Where-Object { $_.type -eq 'workspace' -and $_.isDisplayed } | Select-Object -First 1
if (-not $wsCur -or -not $wsAdj) { exit 0 }

$curWins = @(Get-WindowIds $wsCur)
$adjWins = @(Get-WindowIds $wsAdj)

foreach ($id in $curWins) { & $gw command --id $id move --workspace $wsAdj.name | Out-Null }
foreach ($id in $adjWins) { & $gw command --id $id move --workspace $wsCur.name | Out-Null }

# Stay on the current monitor, now showing the swapped-in windows.
& $gw command focus --workspace $wsCur.name | Out-Null

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'recenter-floating.ps1')
