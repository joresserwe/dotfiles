# Deterministic tile <-> float toggle, bound to f13+space.
#
# glazewm's built-in toggle-floating restores the window's PREVIOUS state,
# so a window with fullscreen history bounces floating<->fullscreen forever
# and can never reach the tile layout from f13+space. This makes the pair
# explicit and history-free:
#   floating            -> set-tiling
#   tiling / fullscreen -> set-floating --centered
# Fullscreen itself stays f13+m's job entirely.

$ErrorActionPreference = 'SilentlyContinue'

# PS 5.1 decodes native stdout via the console codepage while glazewm emits
# UTF-8 — without this, a Korean window title mis-decodes into invalid JSON
# and every query below parses to $null.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$glazewm = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'

# Float-locked processes: for apps float-ruled in config.yaml that f13+space
# must never flip into the tile layout (they still respond to move /
# workspace / monitor commands, unlike `ignore`).
$floatLocked = @()

$res = & $glazewm query focused 2>$null | ConvertFrom-Json
if (-not $res -or -not $res.success) { exit 0 }
$focused = $res.data.focused
if ($focused.type -ne 'window') { exit 0 }
if ($floatLocked -contains $focused.processName) { exit 0 }

if ($focused.state.type -eq 'floating') {
  & $glazewm command --id $focused.id set-tiling | Out-Null
} else {
  & $glazewm command --id $focused.id set-floating --centered | Out-Null
}
