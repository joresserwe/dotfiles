#!/usr/bin/env bash
# wezterm-watch.sh
#
# WSL → Windows file change bridge for WezTerm config auto-reload.
#
# Background: WezTerm on Windows watches its entry config
# (%USERPROFILE%\.wezterm.lua) for changes via Win32 file change
# notifications. The entry file is a stub that dofile()s the real
# config inside WSL via a \\wsl.localhost UNC path. The 9P protocol
# powering \\wsl.localhost does NOT propagate inotify events to
# Windows, so editing the real config in WSL never triggers a reload.
#
# This script runs inside WSL, watches the real wezterm config file
# with inotifywait, and `touch`es the Windows-side stub on every
# change — which Windows DOES notice, causing WezTerm to reload.
#
# Idempotent: refuses to start a second instance.

set -euo pipefail

# Only meaningful inside WSL.
[[ -n "${WSL_DISTRO_NAME:-}" ]] || { echo "wezterm-watch: not WSL, exiting" >&2; exit 0; }

command -v inotifywait >/dev/null 2>&1 || {
  echo "wezterm-watch: inotifywait not installed (apt install inotify-tools)" >&2
  exit 1
}
command -v cmd.exe >/dev/null 2>&1 || {
  echo "wezterm-watch: cmd.exe not on PATH" >&2
  exit 1
}

# Locate the Windows stub at %USERPROFILE%\.wezterm.lua via wslpath.
win_userprofile="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
[[ -n "$win_userprofile" ]] || { echo "wezterm-watch: could not resolve %USERPROFILE%" >&2; exit 1; }
stub_path="$(wslpath "$win_userprofile")/.wezterm.lua"
[[ -f "$stub_path" ]] || { echo "wezterm-watch: stub not found at $stub_path" >&2; exit 1; }

# Single-instance lock so .zshrc auto-start is safe to call repeatedly.
lock_file="${XDG_RUNTIME_DIR:-/tmp}/wezterm-watch.lock"
exec 9>"$lock_file"
flock -n 9 || { echo "wezterm-watch: already running" >&2; exit 0; }

dotfiles_path="${DOTFILES_PATH:-$HOME/.config/.dotfiles}"
watch_dir="$dotfiles_path/wezterm"

echo "wezterm-watch: watching $watch_dir → touching $stub_path"

# Watch the wezterm config dir; on any .lua change, touch the Windows stub.
# close_write covers normal saves; move/create cover atomic-rename editors (vim/nvim).
inotifywait -m -q -e close_write,move,create \
  --format '%f' "$watch_dir" \
| while read -r filename; do
    case "$filename" in
      *.lua)
        touch "$stub_path"
        ;;
    esac
  done
