# Syncs tacky-borders' border_offset with the focused window's glazewm state:
#   fullscreen -> -5 (border fully inside the window; a 5px-wide border can
#                     never bleed onto the neighboring monitor)
#   otherwise  -> -1 (classic look: border fills part of the tile gap)
#
# tacky-borders' file watcher hot-reloads the live config on write (the
# config lives on the NTFS mirror since the UNC days ended), so flips are
# instant — no process restart, no flicker. Only the ACTIVE window's border
# is visible (inactive_color alpha 0 in every theme), so this global flip
# effectively styles just the focused window.
#
# Two entry modes:
#   -Once  : single sync. Wired into the f13+m binding right after
#            toggle-fullscreen — glazewm emits no event on state changes, so
#            the binding itself triggers the sync.
#   daemon : (default) `glazewm sub -e focus_changed` loop — covers focusing
#            away from / back to a fullscreen window. Launched from glazewm's
#            startup_commands; exits when glazewm does (the sub pipe closes).
param([switch]$Once)

$ErrorActionPreference = 'SilentlyContinue'
$glazewm = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
$cfgHome = if ($env:TACKY_BORDERS_CONFIG_HOME) { $env:TACKY_BORDERS_CONFIG_HOME }
           else { Join-Path $env:USERPROFILE '.dotfiles\tacky-borders' }
$cfg = Join-Path $cfgHome 'config.yaml'

# Focus history for f13+z ("previous window", glazewm/focus-prev.ps1): this
# daemon already wakes on every focus_changed, so it doubles as the tracker.
$script:histFile = Join-Path $env:TEMP 'glazewm-prev-window.txt'
$script:lastFocusId = $null

function Sync-BorderState {
  $res = & $glazewm query focused 2>$null | ConvertFrom-Json
  if (-not $res -or -not $res.success) { return }
  $f = $res.data.focused

  if ($f.type -eq 'window' -and $f.id -ne $script:lastFocusId) {
    if ($script:lastFocusId) { Set-Content $script:histFile $script:lastFocusId }
    $script:lastFocusId = $f.id
  }

  # Flag for winkey.ahk's floating-nav hotkeys: glazewm's focus --direction
  # is a no-op when the FOCUSED window is floating (verified live), so AHK
  # takes over f13+hjkl only while this flag exists.
  $flag = Join-Path $env:TEMP 'glazewm-float-focus.flag'
  if ($f.type -eq 'window' -and $f.state.type -eq 'floating') {
    if (-not (Test-Path $flag)) { New-Item -ItemType File -Path $flag -Force | Out-Null }
  } elseif (Test-Path $flag) {
    Remove-Item $flag -Force
  }

  if (-not (Test-Path $cfg)) { return }
  $offset = if ($f.state.type -eq 'fullscreen') { -5 } else { -1 }
  $text = [IO.File]::ReadAllText($cfg)
  $new = ([regex]'border_offset:\s*-?\d+').Replace($text, "border_offset: $offset", 1)
  if ($new -ne $text) { [IO.File]::WriteAllText($cfg, $new) }
}

if ($Once) {
  Start-Sleep -Milliseconds 250  # let toggle-fullscreen apply before querying
  Sync-BorderState
  exit 0
}

# Daemon mode — single instance per session.
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\tacky-state-border', [ref]$created)
if (-not $created) { exit 0 }

Sync-BorderState
& $glazewm sub --events focus_changed 2>$null | ForEach-Object { Sync-BorderState }
