# lib/common.sh — shared functions for install.sh (macOS) and install.linux.sh (WSL/Ubuntu).
# This file is SOURCED, never executed. No top-level side effects. Mode 644.

# Refuse direct execution.
if [ "${BASH_SOURCE[0]:-${(%):-%x}}" = "${0}" ]; then
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
