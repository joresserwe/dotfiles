# The target path travels via %TEMP%\flow-yazi-target.txt, never argv:
# wt strips quotes from pass-through tokens and wsl.exe -e word-splits
# them, so a Windows path with spaces cannot survive either hop
# (observed: --cd C:\Program Files -> Wsl/ERROR_FILE_NOT_FOUND).
param([string]$Target)

$dir = $Target
if (Test-Path -LiteralPath $Target -PathType Leaf) {
    $dir = Split-Path -LiteralPath $Target -Parent
}
if (-not (Test-Path -LiteralPath $dir)) { exit 1 }

[IO.File]::WriteAllText((Join-Path $env:TEMP 'flow-yazi-target.txt'), $dir,
    (New-Object System.Text.UTF8Encoding($false)))

$wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
Start-Process -FilePath $wt -ArgumentList @(
    '-w', 'new', '-f',
    'nt', '-p', 'Terminal',
    'wsl.exe', '-d', 'Ubuntu', '--cd', '~', '-e', '.local/bin/yazi-target'
)
