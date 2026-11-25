#!/bin/sh
cat >/dev/null 2>&1 || true
dotfiles="${DOTFILES_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/.dotfiles}"
sh "$dotfiles/claude/hooks/tmux-status.sh" "${1:-}"
if [ "${1:-}" = "done" ]; then
  printf '{"decision":"stop"}\n'
else
  printf '{}\n'
fi
