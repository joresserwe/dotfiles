# Logon launcher for GlazeWM — crash capture + retry.
#
# glazewm 3.10.1 sometimes aborts (0xc0000409, Rust panic→abort in ucrtbase)
# when launched right at logon, while a later manual launch of the exact same
# task always succeeds — some dependency (display/DWM/shell init) isn't ready
# yet. The old task action (`cmd /c start "" glazewm.exe`) also discarded
# stderr, so the panic message was lost every time.
#
# This wrapper: launches glazewm with stderr captured to
# %TEMP%\glazewm-stderr-<n>.log, waits, and retries with backoff if the
# process died. Appends a timeline to %TEMP%\glazewm-autostart.log so a
# failing first attempt documents its own cause.
#
# Elevation: the Scheduled Task runs this at RunLevel=Highest, so Start-Process
# (CreateProcess path — required for stderr redirect) satisfies glazewm.exe's
# requireAdministrator manifest without UAC. Direct task-action exec of the
# exe would fail with ERROR_ELEVATION_REQUIRED (0x800702E4).

$ErrorActionPreference = 'Continue'
$exe = 'C:\Program Files\glzr.io\GlazeWM\glazewm.exe'
$log = Join-Path $env:TEMP 'glazewm-autostart.log'

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') enter" | Add-Content $log

# Backoff must outlive TCP TIME_WAIT: confirmed 2026-07-15 via netstat that a
# restart right after wm-exit dies on every attempt while 127.0.0.1:6123
# TIME_WAIT pairs from the previous instance linger (glazewm binds without
# SO_REUSEADDR and panics on EADDRINUSE). TIME_WAIT is up to ~2 minutes on
# Windows, so the retries below span ~4 minutes total.
$backoff = 5, 15, 30, 60, 120

for ($i = 1; $i -le $backoff.Count + 1; $i++) {
  if (Get-Process glazewm -ErrorAction SilentlyContinue) {
    "$(Get-Date -Format 'HH:mm:ss.fff') already running — exit" | Add-Content $log
    exit 0
  }
  "$(Get-Date -Format 'HH:mm:ss.fff') attempt $i" | Add-Content $log
  $p = Start-Process $exe -WindowStyle Hidden -PassThru
  Start-Sleep -Seconds 8
  if ($p -and -not $p.HasExited) {
    "$(Get-Date -Format 'HH:mm:ss.fff') attempt $i OK (pid $($p.Id))" | Add-Content $log
    exit 0
  }
  # (glazewm.exe is a windows-subsystem binary: the Rust panic never reaches
  # stderr, so there is nothing to capture — netstat at death time is the
  # useful diagnostic.)
  $tw = (netstat -ano | Select-String ':6123.*TIME_WAIT').Count
  "$(Get-Date -Format 'HH:mm:ss.fff') attempt $i died exit=$($p.ExitCode) (6123 TIME_WAIT pairs: $tw)" | Add-Content $log
  if ($i -le $backoff.Count) { Start-Sleep -Seconds $backoff[$i - 1] }
}
"$(Get-Date -Format 'HH:mm:ss.fff') giving up after $($backoff.Count + 1) attempts" | Add-Content $log
exit 1
