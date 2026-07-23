# The target path travels via %TEMP%\open-yazi-target.txt, never argv:
# wt strips quotes from pass-through tokens and wsl.exe -e word-splits
# them, so a Windows path with spaces cannot survive either hop
# (observed: --cd C:\Program Files -> Wsl/ERROR_FILE_NOT_FOUND).
param([string]$Target)

# Split-Path -LiteralPath -Parent dies with AmbiguousParameterSet under
# PowerShell 5.1.
$dir = $Target
if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    $dir = [IO.Path]::GetDirectoryName($Target)
}
if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { exit 1 }

[IO.File]::WriteAllText((Join-Path $env:TEMP 'open-yazi-target.txt'), $dir,
    (New-Object System.Text.UTF8Encoding($false)))

$wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
Start-Process -FilePath $wt -ArgumentList @(
    '-w', 'new', '-f',
    'nt', '-p', 'Terminal',
    'wsl.exe', '-d', 'Ubuntu', '--cd', '~', '-e', '.local/bin/yazi-target'
)
