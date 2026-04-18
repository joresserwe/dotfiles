# Restart Zebar on Hyper+C.
#
# Zebar has no hot-reload for widget HTML/CSS and occasionally accumulates
# ghost systray icons from apps that crash/reload without sending NIM_DELETE
# (winkey.ahk's #SingleInstance Force relaunch loop is the common trigger).
# A full process restart is the only reliable way to clear those and to pick
# up widget edits from the dotfiles.
#
# Step 1 also re-syncs the widget pack from the WSL dotfiles UNC root. The
# install script copies (not symlinks) zebar assets because zebar's FS watcher
# is unreliable over UNC; without this sync step, edits to bar.html / styles.css
# in the WSL repo would never reach the live mac-bar/ dir, and the user would
# Hyper+C in vain. If WSL is offline / DOTFILES_UNC unset, we skip silently
# and just restart whatever's already on disk.
#
# INTEGRITY GOTCHA: glazewm runs at High integrity but its shell-exec spawns
# powershell at Medium (intentional drop). That Medium powershell can only
# kill a Medium-integrity zebar. If zebar was ever launched from a High
# context (e.g., manually from an elevated terminal, or from a WSL session
# whose root powershell happened to be elevated), Stop-Process here will
# fail with "Access denied", a stale High zebar will keep running, and a
# new Medium zebar will start and immediately exit (single-instance).
# Symptoms: Hyper+C does nothing visible. Fix: kill the stale zebar from
# an equally elevated context, then let the next Hyper+C start a fresh one.

if ($env:DOTFILES_UNC) {
  $src = "$env:DOTFILES_UNC\zebar"
  $dst = "$env:USERPROFILE\.glzr\zebar"
  if (Test-Path $src) {
    New-Item -ItemType Directory -Force -Path "$dst\mac-bar" | Out-Null
    Copy-Item -Force "$src\zpack.json","$src\bar.html","$src\styles.css" "$dst\mac-bar\" -ErrorAction SilentlyContinue
    Copy-Item -Force "$src\settings.json" "$dst\settings.json" -ErrorAction SilentlyContinue
  }
}

$ZebarExe = 'C:\Program Files\glzr.io\Zebar\zebar.exe'

Get-Process zebar -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400
Start-Process -WindowStyle Hidden -FilePath $ZebarExe -ArgumentList 'startup'
