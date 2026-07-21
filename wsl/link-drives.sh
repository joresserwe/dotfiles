#!/usr/bin/env bash
# wsl/link-drives.sh — expose every Windows drive (local + mapped network) as
# a symlink under ~/Drives (override with DRIVES_DIR).
#
# WSL automounts only FIXED local drives at boot; network drives mapped in
# Windows (e.g. Z:) never appear under /mnt on their own. This script asks
# Windows for the live drive-letter list, drvfs-mounts any letter that isn't
# mounted yet, then (re)builds the symlinks. Re-run it after mapping a new
# network drive — it plants a ~/Drives/refresh.sh symlink to itself so the
# refresh action lives right next to the drive links.
set -euo pipefail

if [[ -z "${WSL_DISTRO_NAME:-}" ]] || ! command -v powershell.exe >/dev/null 2>&1; then
  echo "link-drives: not running under WSL (or no powershell.exe interop)" >&2
  exit 0
fi

DRIVES_DIR="${DRIVES_DIR:-$HOME/Drives}"
mkdir -p "$DRIVES_DIR"

# Self-link as ~/Drives/refresh.sh. Prefer the canonical WSL clone path so
# the link survives even when this run came from another checkout (/mnt/c).
self="$(realpath "${BASH_SOURCE[0]}")"
canonical="${XDG_CONFIG_HOME:-$HOME/.config}/.dotfiles/wsl/link-drives.sh"
[[ -f "$canonical" ]] && self="$canonical"
ln -sfn "$self" "$DRIVES_DIR/refresh.sh"

# Single-letter FileSystem drives as Windows sees them (C, D, ... + network
# maps). Mapped network drives are per-user, and interop PowerShell runs as
# the same Windows user, so they show up here.
letters="$(powershell.exe -NoProfile -Command \
  "(Get-PSDrive -PSProvider FileSystem | Where-Object { \$_.Name.Length -eq 1 }).Name" \
  2>/dev/null | tr -d '\r' | tr '[:upper:]' '[:lower:]')"

if [[ -z "$letters" ]]; then
  echo "link-drives: could not enumerate Windows drives" >&2
  exit 1
fi

linked=()
for letter in $letters; do
  mnt="/mnt/$letter"
  if ! mountpoint -q "$mnt" 2>/dev/null; then
    # Not automounted (network drive, or hot-plugged after boot) → drvfs.
    # sudo -n: fail instead of hanging on a password prompt when run headless.
    if ! { sudo -n mkdir -p "$mnt" && sudo -n mount -t drvfs "${letter^^}:" "$mnt"; } 2>/dev/null; then
      echo "link-drives: skip ${letter^^}: (drvfs mount failed — drive empty or unreachable?)" >&2
      continue
    fi
    # Manual drvfs mounts vanish on WSL restart, hence the fstab line.
    if ! grep -q "^${letter^^}: " /etc/fstab 2>/dev/null; then
      printf '%s: %s drvfs defaults,noatime,uid=%s,gid=%s,nofail 0 0\n' \
        "${letter^^}" "$mnt" "$(id -u)" "$(id -g)" \
        | sudo -n tee -a /etc/fstab >/dev/null 2>&1 \
        || echo "link-drives: could not persist ${letter^^}: in /etc/fstab" >&2
    fi
  fi
  ln -sfn "$mnt" "$DRIVES_DIR/${letter^^}"
  linked+=("${letter^^}")
done

profile_raw="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
if [[ -n "$profile_raw" ]]; then
  profile_wsl="$(wslpath "$profile_raw")"
  ln -sfn "$profile_wsl" "$DRIVES_DIR/UserProfile"
  ln -sfn "$profile_wsl/Downloads" "$DRIVES_DIR/Downloads"
  ln -sfn "$profile_wsl/AppData" "$DRIVES_DIR/AppData"
  linked+=(UserProfile Downloads AppData)
else
  echo "link-drives: could not resolve %USERPROFILE% — profile links skipped" >&2
fi

# Prune links for drives Windows no longer has. Only touch single-letter
# symlinks pointing into /mnt — anything else in the dir is user-owned.
for link in "$DRIVES_DIR"/*; do
  [[ -L "$link" ]] || continue
  name="$(basename "$link")"
  [[ "$name" =~ ^[A-Za-z]$ ]] || continue
  [[ "$(readlink "$link")" == /mnt/* ]] || continue
  if ! grep -qiw "$name" <<<"$letters"; then
    rm -f "$link"
    echo "link-drives: pruned $name (no longer present in Windows)"
  fi
done

echo "link-drives: ${linked[*]:-none} -> $DRIVES_DIR"
