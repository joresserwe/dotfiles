# F11 — toggle "show desktop" via the shell's own MinimizeAll / — the same
# key macOS uses for Show Desktop. (Not f13+<shift+>d: winkey.ahk's
# `~F13 & d` cycle combo fires on every modifier variant of F13+d.)
# UndoMinimizeALL. This is exactly what native Win+D did before the kernel
# remap removed the Win key (and DisabledHotkeys blocked D as a leftover),
# so restore brings every window back precisely as it was.
# Toggle state lives in a temp flag file; if the user restores windows by
# hand the flag can desync for one press (harmless no-op), then re-syncs.

$ErrorActionPreference = 'SilentlyContinue'
$flag = Join-Path $env:TEMP 'glazewm-show-desktop.flag'
$shell = New-Object -ComObject Shell.Application

if (Test-Path $flag) {
  $shell.UndoMinimizeALL()
  Remove-Item $flag -Force
} else {
  $shell.MinimizeAll()
  New-Item -ItemType File -Path $flag -Force | Out-Null
}
