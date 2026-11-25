# lib/common.sh — shared functions for install.sh (macOS) and install.linux.sh (WSL/Ubuntu).
# This file is SOURCED, never executed. No top-level side effects. Mode 644.

# Refuse direct execution.
if { [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]}" = "$0" ]; } ||
   { [ -n "${ZSH_VERSION:-}" ] && [ "$ZSH_EVAL_CONTEXT" = toplevel ]; }; then
  echo "lib/common.sh is a library; source it instead of executing." >&2
  exit 1
fi

# detect_os → echoes "darwin" or "linux"
detect_os() {
  case "$(uname -s)" in
    Darwin) echo darwin ;;
    Linux)  echo linux ;;
    *)      echo unknown ;;
  esac
}

log_step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
log_skip() { printf '    \033[2;37m-- %s\033[0m\n' "$*"; }
log_done() { printf '    \033[1;32mok\033[0m %s\n' "$*"; }
log_manual() { printf '    \033[1;33m!!\033[0m %s\n' "$*"; }

# ensure_dir path... → mkdir -p with idempotent log
ensure_dir() {
  for dir in "$@"; do
    if [ -d "$dir" ]; then
      log_skip "exists: $dir"
    else
      mkdir -p "$dir"
      log_done "created: $dir"
    fi
  done
}

# update_repo dir → ff-only pull an existing clone. Non-fatal: an installer
# re-run must survive offline machines, dirty trees, and diverged histories.
update_repo() {
  local dir="$1"
  if git -C "$dir" pull --ff-only --quiet 2>/dev/null; then
    log_done "updated: $dir"
  else
    log_skip "update skipped (offline/dirty/diverged): $dir"
  fi
}

# create_link target link_path → mkdir -p parent, then ln -sf
create_link() {
  local target_file="$1"
  local link_path="$2"
  local link_dir
  link_dir="$(dirname "$link_path")"
  [ -d "$link_dir" ] || mkdir -p "$link_dir"
  ln -sf "$target_file" "$link_path"
  log_done "link: $link_path -> $target_file"
}

configure_bitwarden() {
  local server="https://vault.bitwarden.eu"
  command -v bw >/dev/null || return 0
  if [ "$(bw config server 2>/dev/null)" = "$server" ]; then
    log_skip "bitwarden: server $server"
  elif bw status 2>/dev/null | grep -q '"status":"unauthenticated"'; then
    bw config server "$server" >/dev/null && log_done "bitwarden: server $server"
  else
    log_manual "bitwarden: logged in to another server"
  fi
}

install_codex_web_guidance() {
  local cli="$HOME/.local/bin/codex" catalogs source_url plugins
  catalogs="$("$cli" plugin marketplace list --json)" || return 1
  source_url="$(jq -r '.marketplaces[] | select(.name == "googlechrome") | .marketplaceSource.source // "local"' <<< "$catalogs")" || return 1
  case "$source_url" in
    "") "$cli" plugin marketplace add GoogleChrome/modern-web-guidance || return 1 ;;
    https://github.com/GoogleChrome/modern-web-guidance.git) ;;
    *) printf 'googlechrome already points to a different source: %s\n' "$source_url" >&2; return 1 ;;
  esac
  plugins="$("$cli" plugin list --marketplace googlechrome --json)" || return 1
  if ! jq -e 'any(.installed[]; .pluginId == "modern-web-guidance@googlechrome")' <<< "$plugins" >/dev/null; then
    "$cli" plugin add modern-web-guidance@googlechrome
  fi
}
