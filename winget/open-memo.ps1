# The target path travels via %TEMP%\open-memo-target.txt, never argv:
# wt strips quotes from pass-through tokens and wsl.exe -e word-splits
# them, so a Windows path with spaces cannot survive either hop.
param([string]$Target)

$relay = Join-Path $env:TEMP 'open-memo-target.txt'
if ($Target) {
  if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) { exit 1 }
  [IO.File]::WriteAllText($relay, $Target, (New-Object System.Text.UTF8Encoding($false)))
} else {
  Remove-Item $relay -ErrorAction SilentlyContinue
}

$where = & wsl.exe -d Ubuntu --cd ~ -e .local/bin/memo-target 0
if ($LASTEXITCODE -eq 0) {
  $title = if ($where -match '^tmux\s*$') { 'Terminal' } else { 'memo-pad' }
  (New-Object -ComObject WScript.Shell).AppActivate($title) | Out-Null
  exit 0
}

$wtExe = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
Start-Process -FilePath $wtExe -ArgumentList @(
  '-w', 'new', '-f',
  'nt', '-p', 'Terminal', '--title', 'memo-pad',
  'wsl.exe', '-d', 'Ubuntu', '--cd', '~', '-e', '.local/bin/memo-run'
)

if ($Target) {
  & wsl.exe -d Ubuntu --cd ~ -e .local/bin/memo-target 100 | Out-Null
}
