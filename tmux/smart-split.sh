#!/usr/bin/env bash
# tmux smart split: 넓으면 세로 분할, 좁으면 가로 분할 (셀 종횡비 2.2x 보정)
# Usage: smart-split.sh [--pane-id %N] [-- command args...]
#   tmux.conf:  bind Enter run-shell "~/.config/tmux/smart-split.sh"
#   nvim:       vim.fn.system("~/.config/tmux/smart-split.sh -- nvim file.lua")

PANE_ID=""
PERCENT=""
CMD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pane-id) PANE_ID="$2"; shift 2 ;;
    --percent) PERCENT="$2"; shift 2 ;;
    --) shift; CMD_ARGS=("$@"); break ;;
    *) shift ;;
  esac
done

TARGET="${PANE_ID:+-t $PANE_ID}"
WIDTH=$(tmux display -p ${TARGET:+$TARGET} '#{pane_width}')
HEIGHT=$(tmux display -p ${TARGET:+$TARGET} '#{pane_height}')

if [ "$WIDTH" -gt "$(( HEIGHT * 22 / 10 ))" ]; then
  DIR="-h"
else
  DIR="-v"
fi

tmux split-window $DIR ${PERCENT:+-l ${PERCENT}%} -P -F '#{pane_id}' \
  -c "#{pane_current_path}" ${TARGET:+$TARGET} "${CMD_ARGS[@]}"
