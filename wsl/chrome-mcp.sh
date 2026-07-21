#!/usr/bin/env bash
# Runs chrome-devtools-mcp as a Windows process (WSL interop) because WSL NAT
# cannot reach the Windows loopback where the browser's CDP port listens.
set -euo pipefail

url='http://127.0.0.1:9222'

# </dev/null keeps the interop relay from swallowing MCP stdin meant for node.
if ! /mnt/c/Windows/System32/curl.exe -sf --max-time 3 "${url}/json/version" >/dev/null </dev/null; then
  echo "chrome-mcp: no CDP endpoint at ${url} — run 'chrome-debug' first" >&2
  exit 1
fi

exec /mnt/c/nvm4w/nodejs/node.exe 'C:/nvm4w/nodejs/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js' --browser-url "$url"
