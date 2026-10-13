#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WSL_DISTRO_NAME:-}" ]] || ! command -v powershell.exe >/dev/null 2>&1; then
  echo "compact-vhd: not running under WSL (or no powershell.exe interop)" >&2
  exit 1
fi

resurrect_save="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/tmux-resurrect/scripts/save.sh"
if tmux has-session 2>/dev/null && [[ -x "$resurrect_save" ]]; then
  "$resurrect_save" quiet || true
fi

powershell.exe -NoProfile -Command "
  \$f = Join-Path \$env:USERPROFILE '.dotfiles\\winget\\wsl-compact.ps1'
  if (-not (Test-Path -LiteralPath \$f)) { Write-Error \"not found: \$f\"; exit 1 }
  Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -Distro {1}' -f \$f, '$WSL_DISTRO_NAME')
"
