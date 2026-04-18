# Touches tacky-borders' live config.yaml mtime so the in-app watcher
# (watch_config_changes) fires Config::reload() + reload_borders(), which
# fully tears down and recreates every border. This works around the v1.4.1
# bug where render_backend can drop to None after sleep/wake or display
# changes and isn't recreated on its own (issue #72, fix in 047b440 unreleased).
# Invoked from the Hyper+C reload chain via reload.vbs.
#
# Before touching, re-sync from the WSL dotfiles UNC root so edits in WSL
# take effect on Hyper+C without a manual `tacky-theme` re-apply:
#   - themes/*.yaml refreshed wholesale (new themes appear in `tacky-theme`)
#   - active theme content re-copied into live config.yaml. The active theme
#     is identified by the `# Theme: <name>` marker that every theme file
#     carries on its first line (see tacky-borders/themes/*.yaml).
# If WSL is offline / DOTFILES_UNC unset, we skip the sync and just touch
# whatever's on disk (existing reload semantics preserved).
$cfg = Join-Path $env:USERPROFILE '.config\tacky-borders\config.yaml'

if ($env:DOTFILES_UNC) {
  $themeSrcDir = "$env:DOTFILES_UNC\tacky-borders\themes"
  $themeDstDir = Join-Path $env:USERPROFILE '.config\tacky-borders\themes'
  if (Test-Path $themeSrcDir) {
    New-Item -ItemType Directory -Force -Path $themeDstDir | Out-Null
    Copy-Item -Force "$themeSrcDir\*.yaml" $themeDstDir -ErrorAction SilentlyContinue
    if (Test-Path $cfg) {
      $marker = Get-Content $cfg -TotalCount 1 -ErrorAction SilentlyContinue
      if ($marker -match '^#\s*Theme:\s*([A-Za-z0-9_-]+)') {
        $activeSrc = Join-Path $themeSrcDir "$($Matches[1]).yaml"
        if (Test-Path $activeSrc) {
          Copy-Item -Force $activeSrc $cfg -ErrorAction SilentlyContinue
        }
      }
    }
  }
}

if (Test-Path $cfg) { (Get-Item $cfg).LastWriteTime = Get-Date }
