param(
    [string]$RepoPath = $env:DOTFILES_UNC,
    [string]$MirrorPath = $(if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' })
)

$ErrorActionPreference = 'Continue'

if (-not $RepoPath) { $RepoPath = [Environment]::GetEnvironmentVariable('DOTFILES_UNC', 'User') }
if (-not $RepoPath -or -not (Test-Path -LiteralPath $RepoPath)) { exit 0 }

function Capture-Snapshot([string]$LivePath, [string[]]$Excluded, [string]$SnapName) {
    if (-not (Test-Path -LiteralPath $LivePath)) { return }
    $s = Get-Content -LiteralPath $LivePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($k in $Excluded) { $s.PSObject.Properties.Remove($k) }
    $filtered = $s | ConvertTo-Json -Depth 15

    $appliedPath = Join-Path $MirrorPath ('flow.applied\{0}' -f $SnapName)
    if ((Test-Path -LiteralPath $appliedPath) -and
        ((Get-Content -LiteralPath $appliedPath -Raw -Encoding UTF8) -eq $filtered)) { return }

    $snapPath = Join-Path (Join-Path $RepoPath 'flowlauncher') $SnapName
    if ((Test-Path -LiteralPath $snapPath) -and
        ((Get-Content -LiteralPath $snapPath -Raw -Encoding UTF8) -eq $filtered)) { return }

    New-Item -ItemType Directory -Force (Split-Path $snapPath) | Out-Null
    [IO.File]::WriteAllText($snapPath, $filtered, (New-Object System.Text.UTF8Encoding($false)))
}

$excluded = @(
    'ActivateTimes', 'FirstLaunch', 'ReleaseNotesVersion',
    'WindowLeft', 'WindowTop',
    'SettingWindowLeft', 'SettingWindowTop', 'SettingWindowWidth',
    'SettingWindowHeight', 'SettingWindowState',
    'PreviousDpiX', 'PreviousDpiY', 'PreviousScreenWidth', 'PreviousScreenHeight',
    'CustomExplorerList', 'CustomExplorerIndex',
    'Proxy'
)
Capture-Snapshot (Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json') `
    $excluded 'Settings.snapshot.json'

$pluginExcluded = @{
    'Flow.Launcher.Plugin.Program' = @('LastIndexTime')
    'Flow.Launcher.Plugin.Shell'   = @('CommandHistory')
}
$pluginRoot = Join-Path $env:APPDATA 'FlowLauncher\Settings\Plugins'
if (Test-Path -LiteralPath $pluginRoot) {
    foreach ($dir in Get-ChildItem -LiteralPath $pluginRoot -Directory) {
        $ex = $pluginExcluded[$dir.Name]
        if (-not $ex) { $ex = @() }
        Capture-Snapshot (Join-Path $dir.FullName 'Settings.json') $ex ('plugins\{0}.json' -f $dir.Name)
    }
}
