#!/usr/bin/env bash
# Runs chrome-devtools-mcp as a Windows process (WSL interop) because WSL NAT
# cannot reach Windows loopback where Chrome/Comet CDP (9222) listens.
# Starts cleanly even when no browser is listening on 9222; CDP connects lazily
# on the first tool call once `chrome-debug` or `comet-debug` is running.
set -euo pipefail

url="${CHROME_MCP_URL:-http://127.0.0.1:9222}"

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

find_mcp_pkg() {
  local node_dir="$1"
  local cand
  for cand in \
    "${node_dir}/bin/node_modules/chrome-devtools-mcp" \
    "${node_dir}/node_modules/chrome-devtools-mcp" \
    /mnt/c/Users/*/AppData/Roaming/npm/node_modules/chrome-devtools-mcp \
    /mnt/c/Users/*/scoop/persist/nodejs-lts/bin/node_modules/chrome-devtools-mcp \
    /mnt/c/Users/*/scoop/persist/nodejs/bin/node_modules/chrome-devtools-mcp; do
    if [[ -f "${cand}/package.json" ]]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

node_exe="$(find_win_node)" || {
  echo "chrome-mcp: Windows node.exe not found — install OpenJS.NodeJS.LTS (winget) or nodejs-lts (scoop)" >&2
  exit 1
}

pkg_dir="$(find_mcp_pkg "$(dirname "$node_exe")")" || {
  echo "chrome-mcp: chrome-devtools-mcp not found on Windows — run 'npm install -g chrome-devtools-mcp'" >&2
  exit 1
}

# Resolve bin entry from package.json so upstream layout changes do not break launch.
rel_bin="$(jq -r '(.bin["chrome-devtools-mcp"] // .bin // empty)' "${pkg_dir}/package.json")"
if [[ -z "$rel_bin" || ! -f "${pkg_dir}/${rel_bin#./}" ]]; then
  echo "chrome-mcp: could not resolve bin entry in ${pkg_dir}/package.json" >&2
  exit 1
fi

win_entry="$(wslpath -w "${pkg_dir}/${rel_bin#./}")"
exec "$node_exe" "$win_entry" --browser-url "$url"
