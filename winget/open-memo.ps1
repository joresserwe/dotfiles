param([string]$Target)

$fileArg = @()
if ($Target) {
  if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) { exit 1 }
  # A single UTF-8 base64 token survives both wt and wsl argument parsing.
  $fileArg = @([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Target)))
}

$wslExe = Join-Path $env:SystemRoot 'System32\wsl.exe'
$where = & $wslExe -d Ubuntu --cd ~ -e .local/bin/memo-target @fileArg
if ($LASTEXITCODE -eq 0) {
  $title = if ($where -match '^tmux\s*$') { 'Terminal' } else { 'memo-pad' }
  (New-Object -ComObject WScript.Shell).AppActivate($title) | Out-Null
  exit 0
}

$wtExe = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
$wtArgs = @(
  '-w', 'new', '-f',
  'nt', '-p', 'Ubuntu', '--title', 'memo-pad', '--suppressApplicationTitle',
  '--colorScheme', '"Catppuccin Mocha"',
  ('"{0}"' -f $wslExe), '-d', 'Ubuntu', '--cd', '~', '-e', '.local/bin/memo-target', '--start'
)
Start-Process -FilePath $wtExe -ArgumentList ($wtArgs + $fileArg)
