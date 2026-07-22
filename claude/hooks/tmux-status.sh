#!/bin/sh
[ -n "${TMUX_PANE:-}" ] || exit 0

case "${1:-}" in
working) badge="#[fg=#1e66f5]…" ;;
done) badge="#[fg=#40a02b]✔" ;;
attention) badge="#[fg=#d20f39]●" ;;
clear)
  tmux set -wu -t "$TMUX_PANE" @cc_state 2>/dev/null
  exit 0
  ;;
*) exit 0 ;;
esac

tmux set -w -t "$TMUX_PANE" @cc_state "$badge" 2>/dev/null || true
