# Zebar has no file watcher (verified against v3.3.1 source; notify crate is
# not a dependency), so a full process restart is the only way to pick up
# widget edits. Restart also clears accumulated ghost systray icons from
# apps that crash/reload without sending NIM_DELETE — winkey.ahk's
# #SingleInstance Force relaunch loop being the common trigger.
#
# Config is read from the local dotfiles mirror (%DOTFILES_WIN%\zebar) via
# `--config-dir` (Zebar CLI flag added in v3.3.x). The mirror is refreshed
# from the WSL clone by winget/sync-windows.ps1 (Hyper+C chain), so logon
# and reload never depend on \\wsl.localhost being up.
#
# INTEGRITY: zebar must run at Medium. Its systray provider registers a
# topmost `Shell_TrayWnd` spy window without a UIPI message filter, so an
# elevated zebar makes Shell_NotifyIcon fail with ERROR_ACCESS_DENIED for
# every Medium app: their tray icons never register, and Call of Duty's
# bootstrapper exits -2 on its failed NIM_ADD. glazewm is elevated, so this
# script runs High and a direct Start-Process would inherit High; the
# 'zebar-launch' task (RunLevel=Limited) starts zebar at Medium.
#
# Wait-Process after Stop-Process: Stop-Process signals WM_CLOSE and returns
# immediately; Zebar's tauri-plugin-single-instance mutex is released only
# after the old process fully tears down. Starting a new zebar too early
# hits the mutex and the new instance silently exits.

$ZebarExe  = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
$ConfigDir = if ($env:DOTFILES_WIN) { "$env:DOTFILES_WIN\zebar" }
             else { Join-Path $env:USERPROFILE '.dotfiles\zebar' }

$existing = Get-Process zebar -ErrorAction SilentlyContinue
if ($existing) {
  $existing | Stop-Process -Force -ErrorAction SilentlyContinue
  $existing | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
}

& schtasks.exe /run /tn zebar-launch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Start-Process -WindowStyle Hidden -FilePath $ZebarExe -ArgumentList 'startup', '--config-dir', $ConfigDir
}
