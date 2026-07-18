# Refreshes the Windows-local dotfiles mirror from the WSL clone.
#
# Windows-side consumers (glazewm template + helper scripts, zebar pack,
# tacky-borders themes/launch.vbs/rotate.ps1, winkey.ahk, wezterm.lua) all
# read from the LOCAL mirror at %DOTFILES_WIN% (default %USERPROFILE%\.dotfiles).
# The WSL clone stays the single source of truth; this script is the only
# runtime consumer of the \\wsl.localhost UNC (%DOTFILES_UNC%), and it only
# runs when WSL is up — first step of the Hyper+C reload chain, plus once
# from install.linux.sh. Nothing dereferences UNC at logon anymore.
#
# Why: at logon the WSL VM is not up, so every UNC access fails — observed
# 2026-07-15 cold boot: glazewm crashed (0xc0000409), zebar never started,
# tacky-borders ran configless. A local mirror makes logon self-contained.
#
# tacky-borders/config.yaml is runtime state OWNED BY THE MIRROR (written by
# rotate.ps1 and the zsh tacky-theme helper) — excluded from /MIR so a sync
# can neither clobber nor delete it.

$ErrorActionPreference = 'Continue'
$src = $env:DOTFILES_UNC
$dst = if ($env:DOTFILES_WIN) { $env:DOTFILES_WIN } else { Join-Path $env:USERPROFILE '.dotfiles' }

if (-not $src -or -not (Test-Path -LiteralPath $src)) {
  exit 0  # WSL down or var unset — keep serving the existing mirror
}

foreach ($d in 'glazewm', 'zebar', 'winget', 'wezterm', 'claude', 'surfingkeys') {
  robocopy "$src\$d" "$dst\$d" /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
}
robocopy "$src\tacky-borders" "$dst\tacky-borders" /MIR /XF config.yaml /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null

# First-run bootstrap for the tacky runtime config.
$tackyCfg = Join-Path $dst 'tacky-borders\config.yaml'
if (-not (Test-Path $tackyCfg)) {
  Copy-Item (Join-Path $dst 'tacky-borders\themes\violet-pink.yaml') $tackyCfg -ErrorAction SilentlyContinue
}

# ShareX settings flow the OPPOSITE direction to everything above: the live
# files in %LOCALAPPDATA%\ShareX (HKCU PersonalPath, winget/registry.ps1)
# are rewritten by ShareX itself, so the repo's sharex/ snapshot is pulled
# from them — changes surface as git diff in the WSL clone, committed by hand.
# UploadersConfig.json is excluded: it can hold upload tokens; repo is public.
#
# Capture ONLY real edits: skip when live matches the pristine copy
# install.linux.sh left in the mirror (sharex.applied). Without this guard a
# machine whose live config predates a `git pull` clobbers the freshly pulled
# snapshot with stale state on the next Hyper+C. No applied copy (pre-upgrade
# machine) → fall through and capture, matching the old behavior.
foreach ($f in 'ApplicationConfig.json', 'HotkeysConfig.json') {
  $live    = Join-Path $env:LOCALAPPDATA "ShareX\$f"
  $applied = Join-Path $dst "sharex.applied\$f"
  if (-not (Test-Path -LiteralPath $live)) { continue }
  if ((Test-Path -LiteralPath $applied) -and
      (Get-FileHash -LiteralPath $applied).Hash -eq (Get-FileHash -LiteralPath $live).Hash) { continue }
  Copy-Item -LiteralPath $live (Join-Path $src "sharex\$f") -ErrorAction SilentlyContinue
}

exit 0  # robocopy exit codes 1-7 are success variants; don't propagate them
