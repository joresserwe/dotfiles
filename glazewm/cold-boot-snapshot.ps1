# Cold-boot diagnostic snapshot. Registered as a Scheduled Task that fires
# AtLogon; self-samples at T+0/+30/+60/+120s to capture the progression of
# Startup-folder firing, AHK/GlazeWM health, UNC reachability, and registry
# state across the first 2 minutes of a user session.
#
# Output appended to %TEMP%\cold-boot-state.log. Do not put this on UNC —
# Scheduled Task launches at logon, WSL VM is not yet up, UNC is unreachable.
# Script path must be LOCAL.

$log = Join-Path $env:TEMP 'cold-boot-state.log'
$uncProbe = '\\wsl.localhost\Ubuntu\home\cyan\.config\.dotfiles\winget\winkey.ahk'

function Write-Snapshot {
  param([string]$Label)
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  $uptime = [int](New-TimeSpan -Start $boot -End (Get-Date)).TotalSeconds
  "=== $Label @ $ts (boot=$boot, +${uptime}s) ===" | Add-Content $log
  foreach ($name in @('AutoHotkey64','glazewm','zebar','tacky-borders','explorer')) {
    $p = Get-CimInstance Win32_Process -Filter "Name='$name.exe'" -EA SilentlyContinue
    if ($p) {
      foreach ($x in $p) {
        "  $name PID=$($x.ProcessId) Started=$($x.CreationDate)" | Add-Content $log
      }
    } else {
      "  $name NOT_RUNNING" | Add-Content $log
    }
  }
  # UNC reachability
  try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $len = (Get-Item $uncProbe -EA Stop).Length
    $sw.Stop()
    "  UNC_OK bytes=$len elapsed=$($sw.ElapsedMilliseconds)ms" | Add-Content $log
  } catch {
    "  UNC_FAIL: $($_.Exception.Message)" | Add-Content $log
  }
  # Registry sanity
  try {
    $k = Get-Item 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -EA Stop
    "  DisabledHotkeys=$($k.GetValue('DisabledHotkeys')) [$($k.GetValueKind('DisabledHotkeys'))]" | Add-Content $log
  } catch {
    "  DisabledHotkeys=MISSING" | Add-Content $log
  }
  try {
    $k2 = Get-Item 'HKCU:\Control Panel\Desktop' -EA Stop
    "  LowLevelHooksTimeout=$($k2.GetValue('LowLevelHooksTimeout'))" | Add-Content $log
  } catch {}
  # Env var (GlazeWM shell-exec depends on this)
  "  DOTFILES_UNC='$env:DOTFILES_UNC'" | Add-Content $log
  "" | Add-Content $log
}

# Mark a fresh session for easy visual separation in the log.
"`n########## COLD-BOOT SESSION START $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ##########" | Add-Content $log

Write-Snapshot -Label 'T+0'
Start-Sleep 30
Write-Snapshot -Label 'T+30'
Start-Sleep 30
Write-Snapshot -Label 'T+60'
Start-Sleep 60
Write-Snapshot -Label 'T+120'

# List Startup-folder contents once at end so we know what WAS supposed to fire.
"--- Startup folder ---" | Add-Content $log
Get-ChildItem (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') -EA SilentlyContinue |
  ForEach-Object { "  $($_.Name) mtime=$($_.LastWriteTime)" | Add-Content $log }
"" | Add-Content $log
