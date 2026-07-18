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
