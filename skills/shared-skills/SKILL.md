---
name: shared-skills
description: Maintain dotfiles-owned rules and skills shared by Claude Code, Codex, and Antigravity, including multi-way synchronization and safe, verifiable symlinks.
---

# 공유 스킬 관리

dotfiles가 소유한 개인 스킬이나 Claude·Codex·Antigravity의 공통 기본 규칙을 추가·수정·삭제·연결할 때 사용한다.

- 공통 스킬 원본은 저장소의 `skills/<name>/`에 둔다. `claude/skills/<name>`, `codex/skills/<name>`, `antigravity/skills/<name>`는 모두 `../../skills/<name>`를 가리키는 상대 디렉터리 심볼릭 링크로 만든다. `SKILL.md`에는 짧은 frontmatter와 필요한 지침만 둔다.
- 한 에이전트 설정에서 시작한 공통 변경은 나머지 두 에이전트 설정에도 같은 작업에서 반영한다. 원본 수정은 공유 링크로 반영하고, 추가·삭제·이름 변경은 세 쪽 링크와 관련 참조까지 갱신한다.
- 기본 규칙은 `claude/CLAUDE.md`, `codex/AGENTS.md`, `antigravity/AGENTS.md`를 함께 읽고, 변경한 공통 규칙의 의미를 세 곳에 맞춘다. 모델 라우팅·도구·권한·플러그인 등 제품 전용 설정은 복제하지 않는다. 스킬 본문에는 기본 규칙을 반복하지 않는다.
- 전역 경로는 `${CLAUDE_CONFIG_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/claude}`, `${CODEX_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/codex}`, `${ANTIGRAVITY_CONFIG_DIR:-$HOME/.gemini/config}`를 확인한다. 이 저장소의 기본 설치에서는 Claude의 `skills`가 `claude/skills`를, Codex의 각 `skills/<name>`이 `codex/skills/<name>`를, Antigravity의 각 `skills/<name>`이 `antigravity/skills/<name>`를 가리킨다. 전역 skills가 실제 디렉터리인 환경에서는 각 관리 스킬만 개별 링크한다.
- 기존 설치 경로를 유지한다. macOS의 `install.sh`와 WinOS의 `install.linux.sh`는 Claude skills 디렉터리를 연결하고 `codex/install.sh` 및 `install_antigravity`(`lib/common.sh`)를 호출한다. Codex와 Antigravity 설치기는 각각 `codex/skills/*`와 `antigravity/skills/*`를 순회하므로 공통 스킬의 상대 링크를 세 쪽에 추가하면 두 OS의 설치 대상에 포함된다. 설정 전체 동기화가 필요하지 않으면 스킬 링크만 갱신한다.
- 연결 전 대상이 없거나 이미 올바른 링크인지 확인한다. 기존 일반 파일·실제 디렉터리·무관한 링크를 덮어쓰지 않는다. 삭제할 링크는 저장소 소유 여부를 확인한다. `.system`, `synced`, 플러그인 캐시와 사용자 스킬은 보존한다.
- 수정 묶음이 끝나면 사용 가능한 `quick_validate.py`로 변경한 스킬만 한 번 검증한다. 검증기가 없으면 frontmatter의 `name`·`description`과 참조를 직접 확인하고 제한을 보고한다. 세 저장소 경로 및 전역 경로에서 `SKILL.md`가 같은 원본으로 해석되는지 확인한다. 설치 방식을 바꿨다면 임시 홈에서 설치와 재실행을 검증한다.
