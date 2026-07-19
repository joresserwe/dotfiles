#!/usr/bin/env bash
# Keep the synced dir list in lockstep with winget/sync-windows.ps1
# (the Hyper+C robocopy counterpart).
set -uo pipefail

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
DOTFILES_PATH="${DOTFILES_PATH:-$XDG_CONFIG_HOME/.dotfiles}"

grep -qi microsoft /proc/version 2>/dev/null || exit 0

# Mirror path is cached because systemd services lack WSL_INTEROP and cannot
# run cmd.exe to resolve %USERPROFILE%; rsync onto /mnt/c needs no interop.
state_dir="$XDG_STATE_HOME/dotfiles"
mkdir -p "$state_dir"
mirror="$(cat "$state_dir/mirror-path" 2>/dev/null || true)"
if [ -z "$mirror" ] || [ ! -d "$(dirname "$mirror")" ]; then
  up="$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  [ -n "$up" ] || exit 0
  mirror="$(wslpath "$up")/.dotfiles"
  printf '%s' "$mirror" > "$state_dir/mirror-path"
fi
mkdir -p "$mirror"

status=0
# rsync without perms/owner flags — drvfs rejects chmod/chown metadata.
for d in glazewm winget claude surfingkeys; do
  rsync -rlt --delete "$DOTFILES_PATH/$d/" "$mirror/$d/" || status=1
done

# profile.js is regenerated from WSL-side state that the Windows-side sync
# cannot read — both syncs must exclude it from deletion.
rsync -rlt --delete --exclude 'mac-bar/profile.js' \
  "$DOTFILES_PATH/zebar/" "$mirror/zebar/" || status=1
profile="$(cat "$state_dir/profile" 2>/dev/null || true)"
case "$profile" in
  light|full)
    printf 'window.DOTFILES_PROFILE = "%s";\n' "$profile" \
      > "$mirror/zebar/mac-bar/profile.js"
    ;;
esac

# tacky-borders/config.yaml is mirror-owned runtime state (rotate.ps1 and the
# zsh tacky-theme helper write it) — the sync must neither overwrite nor
# delete it.
rsync -rlt --delete --exclude 'config.yaml' \
  "$DOTFILES_PATH/tacky-borders/" "$mirror/tacky-borders/" || status=1
if [ ! -f "$mirror/tacky-borders/config.yaml" ]; then
  cp "$DOTFILES_PATH/tacky-borders/themes/violet-pink.yaml" \
     "$mirror/tacky-borders/config.yaml" || status=1
fi

{
  date -Is
  git -C "$DOTFILES_PATH" describe --always --dirty 2>/dev/null || true
} > "$mirror/.sync-stamp"

exit "$status"
