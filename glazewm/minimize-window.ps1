# f13+shift+m — minimize the focused window, remembering the order so
# f13+shift+z (restore-window.ps1) can bring windows back most-recent-first.
# The stack lives in %TEMP%; windows minimized by other means (app buttons)
# aren't on it, but restore-window.ps1 falls back to any minimized window
# on the focused workspace.

$ErrorActionPreference = 'SilentlyContinue'
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
$stack = Join-Path $env:TEMP 'glazewm-minimize-stack.txt'

$f = (& $gw query focused 2>$null | ConvertFrom-Json).data.focused
if (-not $f -or $f.type -ne 'window') { exit 0 }

Add-Content -Path $stack -Value $f.id
& $gw command --id $f.id set-minimized | Out-Null
