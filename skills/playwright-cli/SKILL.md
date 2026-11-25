---
name: playwright-cli
description: Automate browser interactions, UI debugging, console inspection, and HTTP network request/response analysis from the CLI in background (headless) or foreground (visible browser / CDP) mode. Trigger whenever testing web UI, inspecting DOM snapshots or screenshots, reading browser console errors, or debugging network requests, headers, payloads, or route mocks.
---

# CLI Browser Debugging (`playwright-cli` / `playwright-win`)

## Mode Selection

- **Background (headless, default — macOS & WSL2)**: use `playwright-cli`
  ```bash
  playwright-cli -s=app open http://127.0.0.1:3000
  ```
- **Foreground (visible browser) or Existing Browser CDP**:
  - **macOS (`darwin*`)**:
    ```bash
    playwright-cli -s=ui open http://localhost:3000 --headed --browser=chrome
    playwright-cli attach --cdp=http://127.0.0.1:9222
    ```
  - **WSL2 (`WSL_DISTRO_NAME` set)**: WSL lacks a visible desktop display (`DISPLAY=:99` is headless Xvfb) and WSL NAT cannot reach Windows loopback `127.0.0.1:9222`. Use `playwright-win` (runs Windows `@playwright/cli` via interop):
    ```bash
    playwright-win -s=ui open http://localhost:3000 --headed --browser=chrome
    playwright-win attach --cdp=http://127.0.0.1:9222
    ```
    - Reach WSL dev servers from Windows Chrome via `http://localhost:<port>` (ensure Windows does not already have a separate process occupying that port).
    - Chrome 136+ blocks `--remote-debugging-port` on the default profile: attach either to `chrome-debug` (`--cdp=http://127.0.0.1:9222`) or enable `chrome://inspect/#remote-debugging` in Chrome and run `playwright-win attach --cdp=chrome`.
    - `playwright-win` automatically converts WSL paths (`/tmp/...`, `/home/...`) passed to `--filename`, `--config`, `--profile`, `--path`, `state-save`, `state-load`, `video-start`, and `upload`. For heavy foreground video/trace recording, prefer a Windows path (e.g., `C:/Temp/demo.webm`) or headless `playwright-cli` to avoid 9P I/O overhead.

## Workflow Rules

- Invoke `playwright-cli` or `playwright-win` directly as single commands without shell redirections or wrapper chains.
- Isolate sessions with `-s=<name>`. Always finish `open` sessions with `close` and `attach` sessions with `detach` (keeps the user's browser open).
- Ephemeral snapshots and console logs default to `$XDG_CACHE_HOME/playwright-cli` (`~/.cache/playwright-cli`), keeping repository working trees clean without extra `--config` flags.

## Core Commands

### Navigation & DOM Interaction
```bash
playwright-cli -s=app open https://example.com
playwright-cli -s=app goto https://example.com/login
playwright-cli -s=app snapshot
playwright-cli -s=app snapshot --depth=4
playwright-cli -s=app snapshot --boxes
playwright-cli -s=app find "Submit"
playwright-cli -s=app find --regex "/error|failed/i"
playwright-cli -s=app fill e5 "user@example.com"
playwright-cli -s=app click e6
playwright-cli -s=app press Enter
playwright-cli -s=app select e9 "value"
playwright-cli -s=app eval "() => window.location.href"
playwright-cli -s=app eval "el => getComputedStyle(el).display" e6
playwright-cli -s=app resize 1440 900
```

### Visual Inspection
```bash
playwright-cli -s=app screenshot --filename=/tmp/page.png
playwright-cli -s=app screenshot e6 --filename=/tmp/element.png
playwright-cli -s=app screenshot --full-page --filename=/tmp/full.png
```

### Console & Runtime Debugging
```bash
playwright-cli -s=app console
playwright-cli -s=app console error
playwright-cli -s=app console --all
playwright-cli -s=app tracing-start
playwright-cli -s=app tracing-stop
```

### Network Inspection & Mocking
```bash
playwright-cli -s=app requests
playwright-cli -s=app requests --filter="/api/"
playwright-cli -s=app requests --static
playwright-cli -s=app request 2
playwright-cli -s=app request-headers 2
playwright-cli -s=app request-body 2
playwright-cli -s=app response-headers 2
playwright-cli -s=app response-body 2
playwright-cli -s=app route "**/api/items" --status=200 --content-type=application/json --body='{"ok":true}'
playwright-cli -s=app route-list
playwright-cli -s=app unroute
playwright-cli -s=app network-state-set offline
playwright-cli -s=app network-state-set online
```

### Sessions & Storage State
```bash
playwright-cli list
playwright-cli -s=app state-save /tmp/auth.json
playwright-cli -s=app state-load /tmp/auth.json
playwright-cli -s=app cookie-list
playwright-cli -s=app localstorage-list
playwright-cli -s=app close
playwright-cli detach
playwright-cli close-all
```
