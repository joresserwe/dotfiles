#!/usr/bin/env bash
set -euo pipefail

find_win_node() {
  local cand
  for cand in \
    "$(command -v node.exe 2>/dev/null || true)" \
    "/mnt/c/Program Files/nodejs/node.exe" \
    "/mnt/c/nvm4w/nodejs/node.exe" \
    /mnt/c/Users/*/scoop/apps/nodejs-lts/current/node.exe \
    /mnt/c/Users/*/scoop/apps/nodejs/current/node.exe; do
    if [[ -n "$cand" && -x "$cand" ]]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

find_cli_pkg() {
  local node_dir="$1"
  local cand
  for cand in \
    "${node_dir}/bin/node_modules/@playwright/cli" \
    "${node_dir}/node_modules/@playwright/cli" \
    /mnt/c/Users/*/AppData/Roaming/npm/node_modules/@playwright/cli \
    /mnt/c/Users/*/scoop/persist/nodejs-lts/bin/node_modules/@playwright/cli \
    /mnt/c/Users/*/scoop/persist/nodejs/bin/node_modules/@playwright/cli; do
    if [[ -f "${cand}/package.json" ]]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

install_win_cli() {
  local node_dir="$1" npm_cmd="${1}/npm.cmd"
  [[ -f "$npm_cmd" ]] || return 1
  (
    cd /mnt/c/Windows
    /mnt/c/Windows/System32/cmd.exe /d /c "$(wslpath -w "$npm_cmd")" install -g @playwright/cli </dev/null >&2
  )
}

to_win_path() {
  local p="$1" dir base win_dir
  [[ "$p" == /* ]] || { printf '%s\n' "$p"; return 0; }
  if wslpath -w "$p" 2>/dev/null; then
    return 0
  fi
  dir="$(dirname "$p")"
  base="$(basename "$p")"
  if win_dir="$(wslpath -w "$dir" 2>/dev/null)"; then
    printf '%s\\%s\n' "${win_dir%\\}" "$base"
    return 0
  fi
  printf '%s\n' "$p"
}

node_exe="$(find_win_node)" || {
  echo "playwright-win: Windows node.exe not found — install OpenJS.NodeJS.LTS (winget) or nodejs-lts (scoop)" >&2
  exit 1
}

node_dir="$(dirname "$node_exe")"
pkg_dir="$(find_cli_pkg "$node_dir")" || {
  echo "playwright-win: installing @playwright/cli on Windows..." >&2
  install_win_cli "$node_dir" || true
  pkg_dir="$(find_cli_pkg "$node_dir")" || {
    echo "playwright-win: @playwright/cli not found on Windows — run 'npm install -g @playwright/cli' on Windows" >&2
    exit 1
  }
}

rel_bin="$(jq -r '(.bin["playwright-cli"] // .bin // empty)' "${pkg_dir}/package.json")"
if [[ -z "$rel_bin" || ! -f "${pkg_dir}/${rel_bin#./}" ]]; then
  echo "playwright-win: could not resolve bin entry in ${pkg_dir}/package.json" >&2
  exit 1
fi

subcmd=""
translated=()
expect_path=0
for arg in "$@"; do
  if (( expect_path )); then
    translated+=("$(to_win_path "$arg")")
    expect_path=0
    continue
  fi
  case "$arg" in
    --filename=*|--config=*|--profile=*|--path=*)
      flag="${arg%%=*}"
      val="${arg#*=}"
      translated+=("${flag}=$(to_win_path "$val")")
      ;;
    --filename|--config|--profile|--path)
      translated+=("$arg")
      expect_path=1
      ;;
    -*)
      translated+=("$arg")
      ;;
    *)
      if [[ -z "$subcmd" ]]; then
        subcmd="$arg"
        translated+=("$arg")
      elif [[ "$subcmd" == "state-save" || "$subcmd" == "state-load" || "$subcmd" == "video-start" || "$subcmd" == "upload" ]] && [[ "$arg" == /* ]]; then
        translated+=("$(to_win_path "$arg")")
      else
        translated+=("$arg")
      fi
      ;;
  esac
done

default_out_dir="${XDG_CACHE_HOME:-$HOME/.cache}/playwright-cli"
out_dir="${PLAYWRIGHT_WIN_OUTPUT_DIR:-$default_out_dir}"
mkdir -p "$out_dir"
if [[ "$subcmd" == "open" || "$subcmd" == "attach" ]]; then
  find "$default_out_dir" -mindepth 1 -mtime +3 -delete 2>/dev/null || true
fi

unset PLAYWRIGHT_MCP_CONFIG PLAYWRIGHT_BROWSERS_PATH
export PLAYWRIGHT_MCP_OUTPUT_DIR="$out_dir"
export PLAYWRIGHT_MCP_ALLOW_UNRESTRICTED_FILE_ACCESS=1
export NO_UPDATE_NOTIFIER=1
export WSLENV="${WSLENV:+$WSLENV:}PLAYWRIGHT_MCP_OUTPUT_DIR/p:PLAYWRIGHT_MCP_ALLOW_UNRESTRICTED_FILE_ACCESS:NO_UPDATE_NOTIFIER"

win_entry="$(wslpath -w "${pkg_dir}/${rel_bin#./}")"
exec "$node_exe" "$win_entry" "${translated[@]}" </dev/null
