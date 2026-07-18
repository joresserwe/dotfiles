# Repairs wezterm windows whose real frame drifted from glazewm's tile
# bounds after a cross-DPI move (glzr-io/glazewm#661): wezterm answers
# WM_DPICHANGED with its own SetWindowPos AFTER glazewm has tiled it,
# leaving the window overflowing its monitor (high→low DPI) or far smaller
# than its tile (low→high DPI). glazewm's own model keeps the correct
# bounds throughout (verified live), so model-vs-frame mismatch is the
# detector and a single wm-redraw is the repair — both directions heal.
#
# Daemon (default): polls for 30s after launch (at logon, windows managed
# during glazewm's own startup emit no events a later subscriber can see,
# and wezterm's DPI resize lands seconds late under cold-start load), then
# polls for 4s after each move-class event (the errant resize can trail
# the event by seconds). Checks are no-ops when frames match, so bursts
# never re-tile a healthy layout. Launched from glazewm's
# startup_commands; exits when glazewm does (the sub pipe closes).
#
# -Once (wired to config_reload_commands): a config reload re-tiles every
# window yet emits no WM event at all — verified live on 3.10.1, `sub -e
# all` stays silent across wm-reload-config even when the file content
# changed — so the daemon cannot see reloads.
param([switch]$Once)

$ErrorActionPreference = 'SilentlyContinue'
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiFix {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L; public int T; public int R; public int B; }
}
"@
# Per-monitor DPI awareness so DwmGetWindowAttribute returns physical
# pixels; without it Windows hands this script virtualized coordinates that
# never compare cleanly against glazewm's physical-pixel model.
[DpiFix]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

function Test-Missize {
  $wins = (& $gw query windows 2>$null | ConvertFrom-Json).data.windows
  foreach ($w in $wins) {
    if ($w.processName -ne 'wezterm-gui') { continue }
    if ($w.state.type -ne 'tiling') { continue }
    if ($w.displayState -notin 'shown', 'showing') { continue }
    $r = New-Object DpiFix+RECT
    # DWMWA_EXTENDED_FRAME_BOUNDS: the visual frame, excluding the drop
    # shadow that GetWindowRect would count as a permanent mismatch.
    if ([DpiFix]::DwmGetWindowAttribute([IntPtr][long]$w.handle, 9, [ref]$r, 16) -ne 0) { continue }
    $tol = 5
    if ([math]::Abs($r.L - $w.x) -gt $tol -or
        [math]::Abs($r.T - $w.y) -gt $tol -or
        [math]::Abs(($r.R - $r.L) - $w.width) -gt $tol -or
        [math]::Abs(($r.B - $r.T) - $w.height) -gt $tol) {
      return $true
    }
  }
  return $false
}

function Repair-Once {
  if (Test-Missize) {
    & $gw command wm-redraw | Out-Null
  }
}

function Repair-Burst($durationMs, $intervalMs) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $durationMs) {
    Start-Sleep -Milliseconds $intervalMs
    Repair-Once
  }
}

if ($Once) {
  Repair-Burst 8000 250
  exit 0
}

# Single instance per session.
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\glazewm-fix-dpi-missize', [ref]$created)
if (-not $created) { exit 0 }

Repair-Burst 30000 500
& $gw sub --events focused_container_moved window_managed monitor_updated workspace_activated focus_changed 2>$null |
  ForEach-Object {
    if ($_ -match '"eventType":"focus_changed"') {
      Repair-Once
    } else {
      Repair-Burst 4000 200
    }
  }
