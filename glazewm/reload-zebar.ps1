# Restart Zebar on Hyper+C.
#
# Zebar has no file watcher (verified against v3.3.1 source; notify crate is
# not a dependency), so a full process restart is the only way to pick up
# widget edits. Restart also clears accumulated ghost systray icons from
# apps that crash/reload without sending NIM_DELETE — winkey.ahk's
# #SingleInstance Force relaunch loop being the common trigger.
#
# Config is read directly from the WSL dotfiles UNC root via `--config-dir`
# (Zebar CLI flag added in v3.3.x, accepts any PathBuf including UNC). No
# local copy under ~\.glzr\zebar — the dotfiles repo is source of truth.
#
# INTEGRITY GOTCHA: glazewm runs at Medium integrity (Startup-folder launch
# via Explorer), its shell-exec spawns powershell at Medium, and this script
# can therefore only kill a Medium-integrity zebar. If zebar was ever started
# from a High-integrity shell (e.g. wezterm-inside-WSL whose integrity was
# inherited through the GlazeWM-managed launch chain), Stop-Process fails
# with "Access denied", Start-Process below spawns a Medium replacement that
# hits the single-instance mutex and exits immediately, and the High stale
# zebar keeps running — Hyper+C does nothing visible. Fix: kill the stale
# zebar from an equally elevated context once, then let the next Hyper+C
# spawn a clean Medium one.
#
# Wait-Process after Stop-Process: Stop-Process signals WM_CLOSE and returns
# immediately; Zebar's tauri-plugin-single-instance mutex is released only
# after the old process fully tears down. Starting a new zebar too early
# hits the mutex and the new instance silently exits, even in the non-UIPI
# case.

$ZebarExe  = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
$ConfigDir = "$env:DOTFILES_UNC\zebar"

$existing = Get-Process zebar -ErrorAction SilentlyContinue
if ($existing) {
  $existing | Stop-Process -Force -ErrorAction SilentlyContinue
  $existing | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
}
Start-Process -WindowStyle Hidden -FilePath $ZebarExe -ArgumentList 'startup', '--config-dir', $ConfigDir
