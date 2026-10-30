#!/usr/bin/env bash
set -euo pipefail

# Windows created before the terminal answers tmux's CSI 14t query keep the
# 16x32 default cell size until a real resize while they are the current
# window. Toggling status within a single command coalesces into no resize,
# hence the pause between the sets.

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-sync-cell-size.lock"
flock 9

client_cell() {
  local cell
  for _ in $(seq 30); do
    cell="$(tmux display -p -c "$1" '#{client_cell_width}x#{client_cell_height}' 2>/dev/null)" || return 1
    if [[ "$cell" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]; then
      echo "$cell"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

toggle=0
while read -r client session window; do
  cell="$(client_cell "$client")" || continue
  while read -r id size; do
    [ "$size" = "$cell" ] || tmux set -w -t "$id" @cell_stale 1
  done < <(tmux list-windows -t "$session" -F '#{window_id} #{window_cell_width}x#{window_cell_height}')
  if [ "$(tmux show -wv -t "$window" @cell_stale 2>/dev/null)" = 1 ]; then
    tmux set -wu -t "$window" @cell_stale
    toggle=1
  fi
done < <(tmux list-clients -F '#{client_name} #{session_id} #{window_id}')

[ "$toggle" = 1 ] || exit 0
status="$(tmux show -gv status)"
if [ "$status" = off ]; then toggled=on; else toggled=off; fi
tmux set -g status "$toggled"
sleep 0.2
tmux set -g status "$status"
