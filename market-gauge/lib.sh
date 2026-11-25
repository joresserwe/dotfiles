# shellcheck shell=bash
app="${XDG_DATA_HOME:-$HOME/.local/share}/market-gauge/app"
key="${XDG_CONFIG_HOME:-$HOME/.config}/market-gauge/key"
marks="${XDG_STATE_HOME:-$HOME/.local/state}/market-gauge"

need_age() {
  command -v age >/dev/null || { echo "market gauge: age is not installed (brew install age)" >&2; exit 1; }
}

confirm() {
  local answer
  while read -rt 0.1; do :; done
  while true; do
    read -rp "$1 [y/n] " answer || return 1
    case "$answer" in
      [yY]* | ㅛ*) return 0 ;;
      [nN]* | ㅜ*) return 1 ;;
    esac
  done
}

app_tar() {
  tar -C "$app" --exclude=__pycache__ --exclude='*.tmp' --sort=name --mtime=@0 \
    --owner=0 --group=0 --numeric-owner --mode='u=rwX,go=rX' -cf - .
}

app_hash() { app_tar | sha256sum | cut -d' ' -f1; }
archive_hash() { sha256sum "$here/app.tar.age" | cut -d' ' -f1; }
recorded() { cat "$marks/$1.sha256" 2>/dev/null || true; }

record() {
  mkdir -p "$marks"
  archive_hash >"$marks/archive.sha256"
  app_hash >"$marks/app.sha256"
}
