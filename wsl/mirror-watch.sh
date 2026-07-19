#!/usr/bin/env bash
set -u

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
DOTFILES_PATH="${DOTFILES_PATH:-$XDG_CONFIG_HOME/.dotfiles}"

grep -qi microsoft /proc/version 2>/dev/null || exit 0
mkdir -p "$XDG_STATE_HOME/dotfiles"

watch_dirs=()
for d in glazewm zebar winget claude surfingkeys tacky-borders; do
  watch_dirs+=("$DOTFILES_PATH/$d")
done
watch_dirs+=("$XDG_STATE_HOME/dotfiles")

"$DOTFILES_PATH/wsl/sync-mirror.sh" || true

inotifywait -m -r -q -e modify,create,delete,move,close_write --format '%w' "${watch_dirs[@]}" |
while read -r _; do
  while read -r -t 1 _; do :; done
  "$DOTFILES_PATH/wsl/sync-mirror.sh" || true
done
