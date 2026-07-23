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

$repo = Split-Path $PSScriptRoot -Parent

$plugins = @(
    [PSCustomObject]@{
        Name    = 'Volume Controller'
        Version = '1.0.0'
        Url     = 'https://github.com/z1nc0r3/Flow.Launcher.Plugin.VolumeController/releases/download/v1.0.0/VolumeController-1.0.0.zip'
    }
)
foreach ($p in $plugins) {
    $dest = Join-Path $env:APPDATA ('FlowLauncher\Plugins\{0}-{1}' -f $p.Name, $p.Version)
    if (Test-Path -LiteralPath $dest) { continue }
    $zip = Join-Path $env:TEMP ('flow-plugin-{0}.zip' -f $p.Version)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest $p.Url -OutFile $zip
        Expand-Archive $zip $dest -Force
        Write-Host ('flow-settings: installed plugin {0} {1}' -f $p.Name, $p.Version)
    } catch {
        Write-Host ('flow-settings: plugin {0} failed — {1}' -f $p.Name, $_.Exception.Message)
    } finally {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }
}

$themeSrc = Join-Path $repo 'flowlauncher\Themes'
if (Test-Path -LiteralPath $themeSrc) {
    $themeDst = Join-Path $env:APPDATA 'FlowLauncher\Themes'
    New-Item -ItemType Directory -Force $themeDst | Out-Null
    Copy-Item (Join-Path $themeSrc '*.xaml') $themeDst -Force
}

$s = Get-Content $settingsPath -Raw | ConvertFrom-Json

$mirror = if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' }

$snapPath = Join-Path $repo 'flowlauncher\Settings.snapshot.json'
if (Test-Path -LiteralPath $snapPath) {
    $snapRaw = Get-Content -LiteralPath $snapPath -Raw
    $snap = $snapRaw | ConvertFrom-Json
    foreach ($p in $snap.PSObject.Properties) {
        $s | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
    }
    $appliedDir = Join-Path $mirror 'flow.applied'
    New-Item -ItemType Directory -Force $appliedDir | Out-Null
    [IO.File]::WriteAllText((Join-Path $appliedDir 'Settings.snapshot.json'), $snapRaw,
        (New-Object System.Text.UTF8Encoding($false)))
}

# %f / %d are Flow-side placeholders, substituted with the Windows path when
# Flow invokes the file manager.
$runHidden = Join-Path $mirror 'winget\run-hidden.vbs'
$yaziShim  = Join-Path $mirror 'winget\open-yazi.ps1'
$yazi = [PSCustomObject]@{
    Name              = 'yazi'
    Path              = Join-Path $env:WINDIR 'System32\wscript.exe'
    FileArgument      = ('"{0}" "{1}" "%f"' -f $runHidden, $yaziShim)
    DirectoryArgument = ('"{0}" "{1}" "%d"' -f $runHidden, $yaziShim)
    Editable          = $true
}
$list = @($s.CustomExplorerList | Where-Object { $_.Name -ne $yazi.Name -and $_.Name -ne 'yazi (wsltty)' }) + $yazi
$s | Add-Member -NotePropertyName 'CustomExplorerList' -NotePropertyValue $list -Force
$s | Add-Member -NotePropertyName 'CustomExplorerIndex' -NotePropertyValue ($list.Count - 1) -Force

$s | ConvertTo-Json -Depth 15 | Out-File $settingsPath -Encoding UTF8

Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
    -Name 'Flow-Launcher' -Value "`"$flow`""

if ($proc) { Start-Process $flow }
Write-Host 'flow-settings: applied'
