# The target path travels via %TEMP%\open-memo-target.txt, never argv:
# wt strips quotes from pass-through tokens and wsl.exe -e word-splits
# them, so a Windows path with spaces cannot survive either hop.
param([string]$Target)

$relay = Join-Path $env:TEMP 'open-memo-target.txt'
$haveFile = $false
if ($Target) {
  if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) { exit 1 }
  [IO.File]::WriteAllText($relay, $Target, (New-Object System.Text.UTF8Encoding($false)))
  $haveFile = $true
} else {
  Remove-Item $relay -ErrorAction SilentlyContinue
}

$delivered = $false
if ($haveFile) {
  & wsl.exe -d Ubuntu --cd ~ -e .local/bin/memo-target 0
  $delivered = ($LASTEXITCODE -eq 0)
}

$focused = (New-Object -ComObject WScript.Shell).AppActivate('memo-pad')

if (-not $focused) {
  $wtExe = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
  Start-Process -FilePath $wtExe -ArgumentList @(
    '-w', 'new', '-f',
    'nt', '-p', 'Terminal',
    'wsl.exe', '-d', 'Ubuntu', '--cd', '~', '-e', '.local/bin/memo-run'
  )
}

if ($haveFile -and -not $delivered) {
  & wsl.exe -d Ubuntu --cd ~ -e .local/bin/memo-target 100
}
