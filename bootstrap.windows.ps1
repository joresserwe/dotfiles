# bootstrap.windows.ps1 — one-shot Windows-side bootstrap for a fresh PC.
# Runs BEFORE WSL exists, so it covers exactly what install.linux.sh cannot:
#   1. WSL platform (optional features + Store package + Ubuntu distro queue)
#   2. Fonts for the terminal font fallback chain (per-user, always latest release)
#   3. winget/registry.ps1 under elevation (HKLM Scancode Map needs admin)
# Everything else stays in install.linux.sh — run that inside Ubuntu after the
# reboot, from a terminal launched as Administrator (the RunLevel=Highest
# scheduled tasks and any registry re-apply inherit the interop token).
#
# Usage (any PowerShell — self-elevates via UAC):
#   irm https://raw.githubusercontent.com/joresserwe/dotfiles/master/bootstrap.windows.ps1 | iex
# or from a local clone:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.windows.ps1
#
# Idempotent — safe to re-run. -RefreshFonts forces font re-download.

param([switch]$RefreshFonts)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$RawBase = 'https://raw.githubusercontent.com/joresserwe/dotfiles/master'

# ----- Elevation -------------------------------------------------------------
# UAC elevation keeps the same user account, so $env:LOCALAPPDATA / HKCU below
# still target the invoking user's profile.
$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $flags = if ($RefreshFonts) { ' -RefreshFonts' } else { '' }
  if ($PSCommandPath) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$flags"
  } else {
    # iex-invoked: no file on disk to point RunAs at — re-fetch from the repo.
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $RawBase/bootstrap.windows.ps1 | iex`""
  }
  Write-Host 'Re-launched elevated — approve the UAC prompt. This window can be closed.'
  return
}

function Log-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Log-Done($m) { Write-Host " OK $m" -ForegroundColor Green }
function Log-Skip($m) { Write-Host " -- $m" -ForegroundColor DarkGray }

$rebootNeeded = $false
$tmp = Join-Path $env:TEMP 'dotfiles-bootstrap'
New-Item -ItemType Directory -Force $tmp | Out-Null

# ============================================================================
# Phase 1 — WSL platform
# ============================================================================
foreach ($feat in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
  # InstallState 1 = enabled, 2 = absent/disabled
  if ((Get-CimInstance Win32_OptionalFeature -Filter "Name='$feat'").InstallState -eq 1) {
    Log-Skip "feature: $feat"
    continue
  }
  Log-Step "feature: enabling $feat"
  dism.exe /online /enable-feature /featurename:$feat /all /norestart | Out-Null
  if ($LASTEXITCODE -eq 3010) { $rebootNeeded = $true }
  elseif ($LASTEXITCODE -ne 0) { throw "dism failed for ${feat} (exit $LASTEXITCODE)" }
  Log-Done "feature: $feat"
}

if (Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForLinux) {
  Log-Skip 'WSL Store package'
} else {
  Log-Step 'WSL Store package: installing via winget'
  # Pinned to the winget source: an msstore source lookup failure aborts the
  # whole install (exit 94) on Store-blocked networks.
  winget install --id Microsoft.WSL -e --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
  if ($LASTEXITCODE -ne 0) { throw "winget install Microsoft.WSL failed (exit $LASTEXITCODE)" }
  Log-Done 'WSL Store package'
}

# Queue the Ubuntu distro. Pre-reboot this only registers the intent — user
# creation happens on first `wsl -d Ubuntu` launch after the reboot.
$env:WSL_UTF8 = '1'
$distros = wsl.exe -l -q
if ($LASTEXITCODE -eq 0 -and ($distros -match 'Ubuntu')) {
  Log-Skip 'Ubuntu distro'
} else {
  wsl.exe --install -d Ubuntu --no-launch | Out-Null
  Log-Done 'Ubuntu distro: install queued'
}

# ============================================================================
# Phase 2 — Fonts (per-user: %LOCALAPPDATA% copy + HKCU registration).
# No version pinning by design — each machine takes the latest release at
# setup time; family names are what configs reference, and those are stable.
# ============================================================================
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -ItemType Directory -Force $fontDir | Out-Null
if (-not (Test-Path $fontReg)) { New-Item -Path $fontReg -Force | Out-Null }

# Win32 full names per file. The registry value name only needs to be unique
# and descriptive (enumeration reads real names from the file data); unknown
# files fall back to their basename.
$fontNames = @{
  '0xProtoNerdFont-Regular.ttf'      = '0xProto Nerd Font'
  '0xProtoNerdFont-Bold.ttf'         = '0xProto Nerd Font Bold'
  '0xProtoNerdFont-Italic.ttf'       = '0xProto Nerd Font Italic'
  '0xProtoNerdFontMono-Regular.ttf'  = '0xProto Nerd Font Mono'
  '0xProtoNerdFontMono-Bold.ttf'     = '0xProto Nerd Font Mono Bold'
  '0xProtoNerdFontMono-Italic.ttf'   = '0xProto Nerd Font Mono Italic'
  '0xProtoNerdFontPropo-Regular.ttf' = '0xProto Nerd Font Propo'
  '0xProtoNerdFontPropo-Bold.ttf'    = '0xProto Nerd Font Propo Bold'
  '0xProtoNerdFontPropo-Italic.ttf'  = '0xProto Nerd Font Propo Italic'
  'SarasaMonoK-Regular.ttf'          = 'Sarasa Mono K'
  'SarasaMonoK-Bold.ttf'             = 'Sarasa Mono K Bold'
  'SarasaMonoK-BoldItalic.ttf'       = 'Sarasa Mono K Bold Italic'
  'SarasaMonoK-Italic.ttf'           = 'Sarasa Mono K Italic'
  'SarasaMonoK-Light.ttf'            = 'Sarasa Mono K Light'
  'SarasaMonoK-LightItalic.ttf'      = 'Sarasa Mono K Light Italic'
  'SarasaMonoK-ExtraLight.ttf'       = 'Sarasa Mono K ExtraLight'
  'SarasaMonoK-ExtraLightItalic.ttf' = 'Sarasa Mono K ExtraLight Italic'
  'SarasaMonoK-SemiBold.ttf'         = 'Sarasa Mono K SemiBold'
  'SarasaMonoK-SemiBoldItalic.ttf'   = 'Sarasa Mono K SemiBold Italic'
  'codicon.ttf'                      = 'codicon'
}

function Install-Ttf([System.IO.FileInfo]$file) {
  $dest = Join-Path $fontDir $file.Name
  Copy-Item $file.FullName $dest -Force
  $name = $fontNames[$file.Name]
  if (-not $name) { $name = $file.BaseName }
  Set-ItemProperty -Path $fontReg -Name "$name (TrueType)" -Value $dest -Type String -Force
}

# A family counts as installed when its regular-weight marker entry exists and
# the file it points at is still on disk.
function Test-FontInstalled([string]$marker) {
  if ($RefreshFonts) { return $false }
  $entry = "$marker (TrueType)"
  $v = (Get-ItemProperty $fontReg -Name $entry -ErrorAction SilentlyContinue).$entry
  return [bool]($v -and (Test-Path $v))
}

# 0xProto Nerd Font — primary (Latin + Nerd Font glyphs). The `latest` asset
# URL is stable across releases.
if (Test-FontInstalled '0xProto Nerd Font') {
  Log-Skip 'fonts: 0xProto Nerd Font'
} else {
  Log-Step 'fonts: 0xProto Nerd Font (latest)'
  Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip' -OutFile "$tmp\0xProto.zip"
  Expand-Archive "$tmp\0xProto.zip" "$tmp\0xproto" -Force
  Get-ChildItem "$tmp\0xproto" -Filter *.ttf | ForEach-Object { Install-Ttf $_ }
  Log-Done 'fonts: 0xProto Nerd Font'
}

# Sarasa Mono K — CJK fallback. Asset names embed the version, so resolve the
# latest via the GitHub API. Ships as .7z only; 7zr.exe is the standalone
# console extractor (no install).
if (Test-FontInstalled 'Sarasa Mono K') {
  Log-Skip 'fonts: Sarasa Mono K'
} else {
  Log-Step 'fonts: Sarasa Mono K (latest)'
  $asset = (Invoke-RestMethod 'https://api.github.com/repos/be5invis/Sarasa-Gothic/releases/latest').assets |
    Where-Object { $_.name -like 'SarasaMonoK-TTF-*' -and $_.name -notlike '*Unhinted*' } |
    Select-Object -First 1
  if (-not $asset) { throw 'Sarasa-Gothic latest release has no SarasaMonoK-TTF asset' }
  Invoke-WebRequest $asset.browser_download_url -OutFile "$tmp\SarasaMonoK.7z"
  # 7-zip.org fails behind some TLS-inspecting proxies.
  try {
    Invoke-WebRequest 'https://github.com/ip7z/7zip/releases/latest/download/7zr.exe' -OutFile "$tmp\7zr.exe"
  } catch {
    Invoke-WebRequest 'https://www.7-zip.org/a/7zr.exe' -OutFile "$tmp\7zr.exe"
  }
  & "$tmp\7zr.exe" x "$tmp\SarasaMonoK.7z" -o"$tmp\sarasa" -y | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "7zr extraction failed (exit $LASTEXITCODE)" }
  Get-ChildItem "$tmp\sarasa" -Filter *.ttf | ForEach-Object { Install-Ttf $_ }
  Log-Done 'fonts: Sarasa Mono K'
}

# codicon — VS Code PUA glyphs used by Claude Code's TUI.
if (Test-FontInstalled 'codicon') {
  Log-Skip 'fonts: codicon'
} else {
  Log-Step 'fonts: codicon (latest)'
  Invoke-WebRequest 'https://unpkg.com/@vscode/codicons/dist/codicon.ttf' -OutFile "$tmp\codicon.ttf"
  Install-Ttf (Get-Item "$tmp\codicon.ttf")
  Log-Done 'fonts: codicon'
}

# ============================================================================
# Phase 3 — Registry tweaks. install.linux.sh re-runs this later, but only an
# elevated pass can write the HKLM Scancode Map (CapsLock→Ctrl, LWin→F13) —
# that is the part winkey.ahk and the glazewm Hyper chain depend on.
# ============================================================================
Log-Step 'registry.ps1 (keyboard remap, hotkey blocks, taskbar)'
if ($PSScriptRoot -and (Test-Path "$PSScriptRoot\winget\registry.ps1")) {
  $regScript = "$PSScriptRoot\winget\registry.ps1"
} else {
  $regScript = "$tmp\registry.ps1"
  Invoke-WebRequest "$RawBase/winget/registry.ps1" -OutFile $regScript
}
# Child process: registry.ps1 relies on non-terminating error semantics that
# this script's $ErrorActionPreference = 'Stop' would break.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $regScript
Log-Done 'registry tweaks applied'

# ============================================================================
Write-Host ''
if ($rebootNeeded) {
  Write-Warning 'Reboot required (WSL platform + Scancode Map take effect after restart).'
}
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host '  1. Reboot, then: wsl --install -d Ubuntu   (creates the Linux user)'
Write-Host '  2. In Ubuntu (terminal launched as Administrator):'
Write-Host '       git clone https://github.com/joresserwe/dotfiles ~/.config/.dotfiles'
Write-Host '       ~/.config/.dotfiles/install.linux.sh'
