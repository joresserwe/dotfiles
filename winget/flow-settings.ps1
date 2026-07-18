$flow = Join-Path $env:LOCALAPPDATA 'FlowLauncher\Flow.Launcher.exe'
if (-not (Test-Path $flow)) { exit 0 }

$settingsPath = Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json'
if (-not (Test-Path $settingsPath)) {
    Write-Host 'flow-settings: Settings.json missing — launch Flow Launcher once, then re-run'
    exit 0
}

# Flow flushes its in-memory settings over this file on exit (observed
# 2026-07-18: keys patched while it ran were lost), so stop it first.
$proc = Get-Process Flow.Launcher -ErrorAction SilentlyContinue
if ($proc) {
    $proc | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$s = Get-Content $settingsPath -Raw | ConvertFrom-Json

$snapPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'flowlauncher\Settings.snapshot.json'
if (Test-Path -LiteralPath $snapPath) {
    $snapRaw = Get-Content -LiteralPath $snapPath -Raw
    $snap = $snapRaw | ConvertFrom-Json
    foreach ($p in $snap.PSObject.Properties) {
        $s | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
    }
    $mirror = if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' }
    $appliedDir = Join-Path $mirror 'flow.applied'
    New-Item -ItemType Directory -Force $appliedDir | Out-Null
    [IO.File]::WriteAllText((Join-Path $appliedDir 'Settings.snapshot.json'), $snapRaw,
        (New-Object System.Text.UTF8Encoding($false)))
}

$configdir = Join-Path $env:APPDATA 'wsltty'
# %f / %d are Flow-side placeholders, substituted with the Windows path when
# Flow invokes the file manager.
$argFmt = '--WSL="Ubuntu" --configdir="{0}" /bin/zsh -lc "yazi \"$(wslpath ''{1}'')\""'
$yazi = [PSCustomObject]@{
    Name              = 'yazi (wsltty)'
    Path              = Join-Path $env:LOCALAPPDATA 'wsltty\bin\mintty.exe'
    FileArgument      = $argFmt -f $configdir, '%f'
    DirectoryArgument = $argFmt -f $configdir, '%d'
    Editable          = $true
}
$list = @($s.CustomExplorerList | Where-Object { $_.Name -ne $yazi.Name }) + $yazi
$s | Add-Member -NotePropertyName 'CustomExplorerList' -NotePropertyValue $list -Force
$s | Add-Member -NotePropertyName 'CustomExplorerIndex' -NotePropertyValue ($list.Count - 1) -Force

$s | ConvertTo-Json -Depth 15 | Out-File $settingsPath -Encoding UTF8

Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
    -Name 'Flow-Launcher' -Value "`"$flow`""

if ($proc) { Start-Process $flow }
Write-Host 'flow-settings: applied'
