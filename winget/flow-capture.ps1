param(
    [string]$RepoPath = $env:DOTFILES_UNC,
    [string]$MirrorPath = $(if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' })
)

$ErrorActionPreference = 'Continue'

$livePath = Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json'
if (-not (Test-Path -LiteralPath $livePath)) { exit 0 }
if (-not $RepoPath) { $RepoPath = [Environment]::GetEnvironmentVariable('DOTFILES_UNC', 'User') }
if (-not $RepoPath -or -not (Test-Path -LiteralPath $RepoPath)) { exit 0 }

$excluded = @(
    'ActivateTimes', 'FirstLaunch', 'ReleaseNotesVersion',
    'WindowLeft', 'WindowTop',
    'SettingWindowLeft', 'SettingWindowTop', 'SettingWindowWidth',
    'SettingWindowHeight', 'SettingWindowState',
    'PreviousDpiX', 'PreviousDpiY', 'PreviousScreenWidth', 'PreviousScreenHeight',
    'CustomExplorerList', 'CustomExplorerIndex',
    'Proxy'
)

$s = Get-Content -LiteralPath $livePath -Raw | ConvertFrom-Json
foreach ($k in $excluded) { $s.PSObject.Properties.Remove($k) }
$filtered = $s | ConvertTo-Json -Depth 15

$appliedPath = Join-Path $MirrorPath 'flow.applied\Settings.snapshot.json'
if ((Test-Path -LiteralPath $appliedPath) -and
    ((Get-Content -LiteralPath $appliedPath -Raw) -eq $filtered)) { exit 0 }

$snapDir = Join-Path $RepoPath 'flowlauncher'
$snapPath = Join-Path $snapDir 'Settings.snapshot.json'
if ((Test-Path -LiteralPath $snapPath) -and
    ((Get-Content -LiteralPath $snapPath -Raw) -eq $filtered)) { exit 0 }

New-Item -ItemType Directory -Force $snapDir | Out-Null
[IO.File]::WriteAllText($snapPath, $filtered, (New-Object System.Text.UTF8Encoding($false)))
