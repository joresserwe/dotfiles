---
name: agy-permissions
description: Add, remove, or update Antigravity CLI (agy) permission rules (unsandboxed, command, read_file, write_file) in dotfiles and machine-local settings.json. Trigger immediately when the user pastes an Antigravity permission prompt ("Requesting permission for:", "Allow sandbox bypass for command execution?") or asks to allow/ask/deny a command or sandbox bypass.
---

# Antigravity 권한 규칙 관리

Antigravity CLI(`agy`)의 권한 프롬프트를 붙여넣거나 `unsandboxed`/`command`/`read_file`/`write_file` 규칙 추가·제거를 요청받으면 즉시 적용한다. 이 스킬은 Antigravity 전용(`antigravity/skills/agy-permissions/`)이다.

## 규칙 매핑

- `Allow sandbox bypass for command execution?` 프롬프트 또는 샌드박스 우회 요청 → `permissions.allow`에 `"unsandboxed(<prefix>)"` 추가
- 일반 명령/경로/URL 요청 → `command(...)`, `read_file(...)`, `write_file(...)`, `read_url(...)`, `execute_url(...)`, `mcp(...)`
- 명령은 불필요한 인자·플래그를 떼고 재사용 가능한 prefix(예: `git fetch`, `docker compose`)로 정리한다. 사용자가 명시한 경우에만 `regex:`나 와일드카드(`*`)를 쓴다.
- `permissions.ask`·`permissions.deny`에 있는 위험 명령(`rm`, `sudo`, `git push`, `git reset --hard`, `git clean`, `dd`, `mkfs` 등)이나 민감 경로와 충돌하면 먼저 알리고 확인을 받는다.

## 적용 절차

1. **dotfiles 원본 수정**: `${DOTFILES_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/.dotfiles}/antigravity/settings.json`
   - 각 배열(`allow`/`ask`/`deny`) 안에서 알파벳 순서를 유지하고 중복을 제거한다.
   - 홈 경로는 이식성을 위해 `~/` 형태를 유지한다(예: `read_file(~/Workspace)`).
   - `unsandboxed`/`command`에 사용자명이 들어간 절대 경로(`/home/<user>/...`, `/mnt/c/Users/<user>/...`)가 나오면 dotfiles에는 `regex:`(`[^/]+`)로 일반화해 넣고, 머신 고유 사용자명을 하드코딩하지 않는다.
2. **로컬 활성 설정 동시 반영**: `~/.gemini/antigravity-cli/settings.json`
   - `agy`가 이 파일을 atomic replace로 덮어쓰므로 심볼릭 링크가 아니라 별도 파일이다.
   - `gcp`, `model`, `runningLightSpeed`, `trustedWorkspaces` 등 머신 로컬 키는 건드리지 않고 해당 권한 항목만 동일하게 반영한다.
   - `read_file`/`write_file`의 `~/`는 `$HOME/` 절대 경로로 확장한다.
3. **검증**: 두 파일의 JSON 문법을 `jq empty`로 확인한다.
4. **보고**: 추가·변경된 규칙과 수정된 두 파일 경로를 간결하게 알린다.
