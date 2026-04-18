# Reload winkey.ahk with self-healing behavior on Hyper+C (or physical
# Ctrl+Alt+LWin+C, which bypasses AHK entirely — handy when the hook is dead).
#
# Paths:
#   AHK process absent         → Start-Process fresh from the Startup folder.
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

$AhkExe     = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$ScriptPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\winkey.ahk"
$SignalFile = "$env:TEMP\winkey-reload.signal"

# Re-sync winkey.ahk from the WSL dotfiles UNC root before triggering reload.
# install.linux.sh copies (not symlinks) the script into the Startup folder
# because Startup can't follow UNC paths; without this sync step, edits in
# the WSL repo wouldn't reach the live $ScriptPath and the reload signal
# would just re-run the stale copy. If WSL is offline / DOTFILES_UNC unset,
# we skip silently.
if ($env:DOTFILES_UNC) {
  $src = "$env:DOTFILES_UNC\winget\winkey.ahk"
  if (Test-Path $src) {
    Copy-Item -Force $src $ScriptPath -ErrorAction SilentlyContinue
  }
}

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
