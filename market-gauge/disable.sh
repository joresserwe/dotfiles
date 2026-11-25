#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"

if [ -f "$key" ] && [ ! -f "$here/key.age" ]; then
  echo "market gauge: key.age is missing, run market-gauge/set-password.sh first" >&2
  exit 1
fi
read -rp "Turn the market gauge off on this PC? [y/N] " answer
[[ "$answer" == [yY]* ]] || exit 0

if [ -d /run/systemd/system ]; then
  units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  for unit in market-gauge market-gauge-live market-quotes; do
    systemctl --user disable --now "$unit.timer" >/dev/null 2>&1 || true
    systemctl --user stop "$unit.service" >/dev/null 2>&1 || true
    rm -f "$units/$unit.service" "$units/$unit.timer"
  done
  systemctl --user daemon-reload
fi
rm -f "$key"
mirror="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/mirror-path" 2>/dev/null || true)"
if [ -n "$mirror" ]; then
  rm -f "$mirror"/zebar/mac-bar/{market,quotes,quotes-hist}.json
fi
echo "market gauge: off (press Hyper+C to refresh the bar; unlock.sh turns it back on)"
