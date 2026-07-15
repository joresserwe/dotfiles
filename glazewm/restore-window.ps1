# f13+shift+z — restore the most recently minimized window (repeat to pop
# the stack written by minimize-window.ps1). Falls back to any minimized
# window on the focused workspace when the stack is empty or stale (windows
# minimized via their own UI never enter the stack).

$ErrorActionPreference = 'SilentlyContinue'
$gw = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
$stack = Join-Path $env:TEMP 'glazewm-minimize-stack.txt'

$wins = (& $gw query windows 2>$null | ConvertFrom-Json).data.windows
$minimized = @($wins | Where-Object { $_.state.type -eq 'minimized' })
if (-not $minimized) { Clear-Content $stack -ErrorAction SilentlyContinue; exit 0 }

$target = $null
if (Test-Path $stack) {
  $ids = @(Get-Content $stack | Where-Object { $_ })
  for ($i = $ids.Count - 1; $i -ge 0; $i--) {
    $hit = $minimized | Where-Object { $_.id -eq $ids[$i] } | Select-Object -First 1
    if ($hit) { $target = $hit; $ids = $ids[0..($i - 1)]; break }
  }
  if ($target) {
    if ($i -le 0) { Clear-Content $stack } else { Set-Content $stack ($ids -join "`n") }
  }
}

if (-not $target) {
  # Fallback: most recent minimized window on the focused workspace.
  $ws = (& $gw query workspaces 2>$null | ConvertFrom-Json).data.workspaces |
    Where-Object { $_.hasFocus } | Select-Object -First 1
  foreach ($id in $ws.childFocusOrder) {
    $hit = $minimized | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if ($hit) { $target = $hit; break }
  }
  if (-not $target) { $target = $minimized[0] }
}

& $gw command --id $target.id toggle-minimized | Out-Null
& $gw command focus --container-id $target.id | Out-Null
