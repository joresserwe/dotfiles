#!/bin/sh
set -eu
state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-settings.local.json"

case "${1:-}" in
clean)
  input="$(cat)"
  local_keys="$(printf '%s\n' "$input" | jq '{model, effortLevel, modelSettings} | with_entries(select(.value != null))')"
  if [ "$local_keys" != "{}" ] && [ "$local_keys" != "$(cat "$state" 2>/dev/null || true)" ]; then
    mkdir -p "${state%/*}"
    printf '%s\n' "$local_keys" >"$state.$$"
    mv "$state.$$" "$state"
  fi
  printf '%s\n' "$input" | jq --indent 2 'del(.model, .effortLevel, .modelSettings)'
  ;;
smudge)
  if [ -s "$state" ]; then
    jq --indent 2 --slurpfile local "$state" '. + $local[0]'
  else
    cat
  fi
  ;;
*) exit 1 ;;
esac
