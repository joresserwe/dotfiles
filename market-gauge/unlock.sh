#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"
need_age

if [ ! -f "$key" ]; then
  if [ ! -f "$here/key.age" ]; then
    echo "market gauge: no password set (run market-gauge/set-password.sh on a PC that has the key)"
    exit 0
  fi
  if [ ! -t 0 ]; then
    echo "market gauge: locked (run market-gauge/unlock.sh in a terminal)"
    exit 0
  fi
  mkdir -p "$(dirname "$key")"
  tmp="$(mktemp "$(dirname "$key")/key.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  until age -d "$here/key.age" >"$tmp"; do
    confirm "Try again?" || exit 1
  done
  [ "$(age-keygen -y "$tmp")" = "$(cat "$here/recipient")" ] || { echo "market gauge: key does not match" >&2; exit 1; }
  mv "$tmp" "$key"
fi

archive="$(archive_hash)"
if [ ! -d "$app" ] || [ "$(recorded archive)" != "$archive" ]; then
  if [ -d "$app" ] && [ "$(app_hash)" != "$(recorded app)" ]; then
    echo "market gauge: $app was edited on this PC, so the update was skipped (delete it to take the update)"
  else
    next="$app.next"
    rm -rf "$next"
    mkdir -p "$next"
    age -d -i "$key" "$here/app.tar.age" | tar -C "$next" -xf -
    rm -rf "$app"
    mv "$next" "$app"
    record
  fi
fi

if [ -d /run/systemd/system ]; then
  units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$units"
  for unit in market-gauge market-gauge-live market-quotes; do
    ln -sfn "$app/systemd/$unit.service" "$units/$unit.service"
    ln -sfn "$app/systemd/$unit.timer" "$units/$unit.timer"
  done
  systemctl --user daemon-reload
  systemctl --user enable --now market-gauge.timer market-gauge-live.timer market-quotes.timer >/dev/null 2>&1
  systemctl --user start --no-block market-gauge.service market-quotes.service
fi
echo "market gauge: ready"
