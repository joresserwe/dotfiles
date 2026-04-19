# Reload winkey.ahk with self-healing behavior on Hyper+C (or physical
# Ctrl+Alt+LWin+C, which bypasses AHK entirely — handy when the hook is dead).
#
# Paths:
#   AHK process absent         → Start-Process fresh from the UNC script path.
#   AHK process present        → touch %TEMP%\winkey-reload.signal; winkey.ahk's
#                                500ms poller deletes the file and calls Reload()
#                                (avoids #SingleInstance Force's "Could not close
#                                the previous script" dialog, which pops when the
#                                old instance is mid-hotkey).
#   Signal not consumed in 800ms → AHK exists but is unresponsive (zombie hook
#                                  from a bad cold boot); force-kill and fresh.
#
# Start-Process is used for fresh launches because AHK spawned by a plain
# non-interactive parent (e.g. Task Scheduler) couldn't install its keyboard
# hook — going through Start-Process from a user-shell context worked.
#
# $ScriptPath is the WSL-dotfiles UNC path — the .ahk is not copied locally.
# AHK reads it over UNC just fine and the dotfiles repo stays the single
# source of truth (no "did I forget to re-sync?" failure mode on edits).

$AhkExe     = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$ScriptPath = "$env:DOTFILES_UNC\winget\winkey.ahk"
$SignalFile = "$env:TEMP\winkey-reload.signal"

function Start-Winkey {
  Start-Process -WindowStyle Hidden -FilePath $AhkExe -ArgumentList "`"$ScriptPath`""
}

$ahk = Get-Process AutoHotkey64 -ErrorAction SilentlyContinue

if (-not $ahk) {
  Start-Winkey
  return
}

New-Item -ItemType File -Path $SignalFile -Force | Out-Null
Start-Sleep -Milliseconds 800

if (Test-Path $SignalFile) {
  $ahk | Stop-Process -Force -ErrorAction SilentlyContinue
  Remove-Item $SignalFile -Force -ErrorAction SilentlyContinue
  Start-Winkey
}
