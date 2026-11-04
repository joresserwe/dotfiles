#!/usr/bin/env bash
# Bridges chrome-devtools-mcp (running in WSL) to the Windows-side Comet
# browser. Comet must be listening on CDP port 9222 (`comet-debug` alias),
# reached through a Windows portproxy on 9223 because WSL NAT mode cannot
# reach the Windows loopback. One-time elevated Windows setup:
#   netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=9223 connectaddress=127.0.0.1 connectport=9222
set -euo pipefail

export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"

win_host="$(ip route show default | awk '{print $3}')"
url="http://${win_host}:9223"

if ! curl -sf --max-time 3 "${url}/json/version" >/dev/null; then
  echo "comet-mcp: no CDP endpoint at ${url} — start Comet with 'comet-debug' (see header for one-time Windows setup)" >&2
  echo "comet-mcp: the one-time setup also needs, elevated: New-NetFirewallRule -Name WSL_Comet_CDP_9223 -DisplayName WSL_Comet_CDP_9223 -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9223 -InterfaceAlias 'vEthernet (WSL*'" >&2
  exit 1
fi

exec npx -y chrome-devtools-mcp@1.12.0 --browser-url "$url"
