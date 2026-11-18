# glazewm positions windows with SWP_ASYNCWINDOWPOS. A DPI-unaware window
# moved from the 192-DPI monitor to the 120-DPI one comes out of that call
# straddling both monitors at the wrong size (PADS Designer: 2540x1388 tile ->
# 4014x1598 starting on the other monitor), and wm-redraw re-issues the same
# call into the same wrong rect. A synchronous SetWindowPos from a
# per-monitor-aware caller lands it correctly.

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DpiFix {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  [DllImport("user32.dll")] static extern IntPtr GetWindowDpiAwarenessContext(IntPtr h);
  [DllImport("user32.dll")] static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);

  const uint SWP_NOZORDER = 0x4, SWP_NOACTIVATE = 0x10, SWP_NOOWNERZORDER = 0x200;

  public static bool IsUnaware(IntPtr h) {
    int a = GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(h));
    return a == 0 || a == 1;
  }

  public static bool IsResponsive(IntPtr h) {
    IntPtr r;
    return SendMessageTimeout(h, 0, IntPtr.Zero, IntPtr.Zero, 0x2, 500, out r) != IntPtr.Zero;
  }

  public static RECT Frame(IntPtr h) {
    RECT r;
    if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) GetWindowRect(h, out r);
    return r;
  }

  public static void Place(IntPtr h, int x, int y, int w, int hh) {
    const uint f = SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER;
    // The invisible resize-border margins scale with the window's DPI, so
    // they can only be measured once the first pass has put it on the
    // target monitor.
    SetWindowPos(h, IntPtr.Zero, x, y, w, hh, f);
    RECT outer; GetWindowRect(h, out outer);
    RECT vis = Frame(h);
    SetWindowPos(h, IntPtr.Zero,
      x - (vis.L - outer.L), y - (vis.T - outer.T),
      w + (vis.L - outer.L) + (outer.R - vis.R),
      hh + (vis.T - outer.T) + (outer.B - vis.B), f);
  }
}
'@
[DpiFix]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

function Get-Windows($node, $ws) {
  if ($node.type -eq 'workspace') { $ws = $node }
  if ($node.type -eq 'window') {
    if ($node.state.type -in 'tiling', 'floating', 'fullscreen') { [pscustomobject]@{ W = $node; Ws = $ws } }
    return
  }
  foreach ($c in $node.children) { Get-Windows $c $ws }
}

function Get-Spilled {
  $mons = (& $gw query monitors 2>$null | ConvertFrom-Json).data.monitors
  foreach ($mon in $mons) {
    foreach ($e in @(Get-Windows $mon $null)) {
      $h = [IntPtr][long]$e.W.handle
      if (-not [DpiFix]::IsUnaware($h)) { continue }
      $f = [DpiFix]::Frame($h)
      $tol = 8
      $fw = $f.R - $f.L; $fh = $f.B - $f.T
      $st = $e.W.state.type
      $spill = if ($st -eq 'floating') {
        $fw -gt $mon.width -or $fh -gt $mon.height
      } else {
        $f.L -lt $mon.x - $tol -or $f.T -lt $mon.y - $tol -or
        $f.R -gt $mon.x + $mon.width + $tol -or $f.B -gt $mon.y + $mon.height + $tol
      }
      if (-not $spill) { continue }
      $key = "$($f.L),$($f.T),$($f.R),$($f.B)"
      $maxW = [int]($e.Ws.width * 0.9); $maxH = [int]($e.Ws.height * 0.9)
      if ($st -eq 'floating') {
        $t = [math]::Min($fw, $maxW), [math]::Min($fh, $maxH)
        [pscustomobject]@{ H = $h; Id = $e.W.id; T = $t; Key = $key }
        continue
      }
      if ($st -eq 'fullscreen' -and $e.W.prevState.type -eq 'floating') {
        $p = $e.W.floatingPlacement
        $pw = $p.right - $p.left; $ph = $p.bottom - $p.top
        $via = $mons | Where-Object { $_.id -ne $mon.id } | ForEach-Object { $_.children } |
          Where-Object { $_.type -eq 'workspace' -and $_.isDisplayed -and $_.width -ge $pw -and $_.height -ge $ph } |
          Select-Object -First 1
        $t = [math]::Min($pw, $maxW), [math]::Min($ph, $maxH)
        [pscustomobject]@{ H = $h; Id = $e.W.id; T = $t; Key = $key; Home = $e.Ws.name; Via = $via.name }
        continue
      }
      # The spill itself covers the workspace, so glazewm flips the window
      # to fullscreen, and a monitor-sized target spills it again. A rect
      # inside the workspace makes glazewm restore it and re-tile with
      # shadow borders measured at the new DPI.
      $t = if ($st -eq 'fullscreen') {
        ($e.Ws.x + 4), ($e.Ws.y + 4), ($e.Ws.width - 8), ($e.Ws.height - 8)
      } else {
        $e.W.x, $e.W.y, $e.W.width, $e.W.height
      }
      [pscustomobject]@{ H = $h; T = $t; Key = $key }
    }
  }
}

function Wait-Settled($h) {
  $last = ''; $same = 0
  for ($i = 0; $i -lt 30 -and $same -lt 3; $i++) {
    Start-Sleep -Milliseconds 100
    $f = [DpiFix]::Frame($h)
    $k = "$($f.L),$($f.T),$($f.R),$($f.B)"
    if ($k -eq $last) { $same++ } else { $same = 0; $last = $k }
  }
}

function Repair-Spilled {
  $seen = @{}; $tries = @{}
  $deadline = (Get-Date).AddSeconds(120)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 400
    $spilled = @(Get-Spilled)
    if (-not $spilled) { return }
    foreach ($s in $spilled) {
      $id = [long]$s.H
      # glazewm's own async moves may still be queued behind a busy UI
      # thread; acting before they run gets overwritten, so wait for the
      # rect to hold still across two polls. SetWindowPos would also block
      # until that thread pumps (PADS stalls ~20s loading a project).
      if ($seen[$id] -eq $s.Key -and $tries[$id] -lt 3 -and [DpiFix]::IsResponsive($s.H)) {
        $size = '--width', "$($s.T[0])px", '--height', "$($s.T[1])px"
        if (-not $s.Id) {
          [DpiFix]::Place($s.H, $s.T[0], $s.T[1], $s.T[2], $s.T[3])
        } elseif (-not $s.Home) {
          & $gw command --id $s.Id size @size | Out-Null
          & $gw command --id $s.Id position --centered | Out-Null
        } elseif (-not $tries[$id]) {
          & $gw command --id $s.Id set-floating --centered @size | Out-Null
        } elseif ($s.Via) {
          # set-floating drops its size arguments for a float that was
          # resized by hand and restores the oversized placement, which
          # balloons back to fullscreen within ~50ms; size is ignored while
          # fullscreen. Both hold on a monitor the placement fits.
          & $gw command --id $s.Id move --workspace $s.Via | Out-Null
          Wait-Settled $s.H
          & $gw command --id $s.Id set-floating | Out-Null
          Wait-Settled $s.H
          & $gw command --id $s.Id size @size | Out-Null
          Wait-Settled $s.H
          & $gw command --id $s.Id move --workspace $s.Home | Out-Null
        }
        $tries[$id] = [int]$tries[$id] + 1
      }
      $seen[$id] = $s.Key
    }
    if (-not @($spilled | Where-Object { $tries[[long]$_.H] -lt 3 })) { return }
  }
}

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\glazewm-dpi-unaware-watch', [ref]$created)
if (-not $created) { exit 0 }

Repair-Spilled
& $gw sub --events window_managed focused_container_moved workspace_updated 2>$null |
  ForEach-Object { Repair-Spilled }
