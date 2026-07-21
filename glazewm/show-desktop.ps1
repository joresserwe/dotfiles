$ErrorActionPreference = 'SilentlyContinue'
$state = Join-Path $env:TEMP 'glazewm-show-desktop.state'

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class ShowDesk {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int idx);
  [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int val, int size);
  delegate bool EnumProc(IntPtr h, IntPtr lp);

  public static List<long> Candidates() {
    var list = new List<long>();
    EnumWindows((h, lp) => {
      if (!IsWindowVisible(h) || IsIconic(h)) return true;
      if (GetWindow(h, 4) != IntPtr.Zero) return true;          // 4 = GW_OWNER
      if ((GetWindowLong(h, -20) & 0x80) != 0) return true;     // GWL_EXSTYLE & WS_EX_TOOLWINDOW
      int cloaked; DwmGetWindowAttribute(h, 14, out cloaked, 4); // 14 = DWMWA_CLOAKED
      if (cloaked != 0) return true;
      var sb = new StringBuilder(64); GetClassName(h, sb, 64);
      var cls = sb.ToString();
      if (cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd") return true;
      list.Add(h.ToInt64());
      return true;
    }, IntPtr.Zero);
    return list;
  }
}
"@

if (Test-Path $state) {
  foreach ($h in Get-Content $state) {
    [ShowDesk]::ShowWindow([IntPtr][long]$h, 9) | Out-Null     # 9 = SW_RESTORE
  }
  Remove-Item $state -Force
} else {
  $minimized = @()
  foreach ($h in [ShowDesk]::Candidates()) {
    if ([ShowDesk]::ShowWindow([IntPtr]$h, 6)) { $minimized += $h }  # 6 = SW_MINIMIZE
  }
  Set-Content -Path $state -Value $minimized
}
