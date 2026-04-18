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

$themes_dir = Join-Path $env:USERPROFILE '.config\tacky-borders\themes'
$live = Join-Path $env:USERPROFILE '.config\tacky-borders\config.yaml'

if (-not (Test-Path $themes_dir)) { Write-Error "themes dir missing: $themes_dir"; exit 1 }

$themes = Get-ChildItem -Path $themes_dir -Filter '*.yaml' | Sort-Object Name
if ($themes.Count -eq 0) { Write-Error "no themes found in $themes_dir"; exit 1 }

$seed = [int](Get-Date -Format 'yyyyMMdd')
$pick = $themes[$seed % $themes.Count]

Copy-Item -Path $pick.FullName -Destination $live -Force
Write-Output ("tacky-rotate: {0} -> {1}" -f (Get-Date -Format 'yyyy-MM-dd'), $pick.BaseName)
