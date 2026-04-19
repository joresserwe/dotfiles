# Picks a tacky-borders theme deterministically from today's date and copies
# it to the live config.yaml. Invoked by:
#   - Scheduled Task (AtLogOn + Daily 00:05) for automatic daily rotation
#   - `tacky-rotate now` zsh command for manual "apply today" after config edits
#
# Deterministic: yyyymmdd as integer mod N(themes) so every wake-up on the
# same date lands on the same theme. Theme list is read from
# %USERPROFILE%\.config\tacky-borders\themes\*.yaml and sorted by filename,
# so rotation order only changes when themes are added/removed.
$ErrorActionPreference = 'Stop'

# Config home — set by install.linux.sh via setx as a User env var; points at
# the WSL dotfiles tacky-borders dir. tacky-borders itself reads the same var.
# Fallback to the legacy default path for any context where the var is missing.
$cfg_home  = if ($env:TACKY_BORDERS_CONFIG_HOME) { $env:TACKY_BORDERS_CONFIG_HOME } `
             else { Join-Path $env:USERPROFILE '.config\tacky-borders' }
$themes_dir = Join-Path $cfg_home 'themes'
$live       = Join-Path $cfg_home 'config.yaml'

if (-not (Test-Path $themes_dir)) { Write-Error "themes dir missing: $themes_dir"; exit 1 }

$themes = Get-ChildItem -Path $themes_dir -Filter '*.yaml' | Sort-Object Name
if ($themes.Count -eq 0) { Write-Error "no themes found in $themes_dir"; exit 1 }

$seed = [int](Get-Date -Format 'yyyyMMdd')
$pick = $themes[$seed % $themes.Count]

# Atomic replace: Copy-Item holds an exclusive write lock on the destination
# from open to close — a reader hitting the destination mid-copy would see a
# locked/partial handle. Staging to .tmp then File.Replace does an NTFS
# rename-over so the destination inode swaps atomically. The retry loop is
# for the rare case where tacky-borders is mid-startup and holds a brief
# read handle (watcher is dead on our symlinked-to-UNC dir, but startup still
# opens the file).
$tmp = "$live.tmp"
Copy-Item -Force $pick.FullName $tmp
if (Test-Path $live) {
  $swapped = $false
  for ($i = 0; $i -lt 10; $i++) {
    try { [System.IO.File]::Replace($tmp, $live, $null); $swapped = $true; break }
    catch { Start-Sleep -Milliseconds 30 }
  }
  if (-not $swapped) { [System.IO.File]::Replace($tmp, $live, $null) }
} else {
  Move-Item -Force $tmp $live
}

# Restart tacky-borders so it picks up the new config. Watcher on the symlink
# target's UNC root is dead (ReadDirectoryChangesW doesn't fire over WSL 9P),
# so explicit restart is the only way. Harmless if tacky-borders isn't running
# yet (AtLogOn trigger with 30s delay can fire before tacky's own task).
Start-ScheduledTask -TaskName 'tacky-borders' -ErrorAction SilentlyContinue

Write-Output ("tacky-rotate: {0} -> {1}" -f (Get-Date -Format 'yyyy-MM-dd'), $pick.BaseName)
