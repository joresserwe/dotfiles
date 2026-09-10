---
name: shared-skills
description: Maintain dotfiles-owned shared Codex skills and AGENTS instructions with safe, verifiable symlinks.
---

# 공유 스킬 관리

dotfiles가 소유한 개인 스킬이나 공통 `AGENTS.md`를 추가·수정·연결할 때 사용한다.

- 원본은 저장소의 `codex/skills/<name>/`와 `codex/AGENTS.md`에 둔다. 스킬은 `SKILL.md`의 짧은 frontmatter와 필요한 지침만 포함하며, 별도 README나 UI 파일은 실제 필요가 있을 때만 만든다.
- 전역 스킬은 각 원본 디렉터리를 `~/.agents/skills/<name>`에 개별 심볼릭 링크한다. 같은 스킬을 `~/.codex/skills`에 중복 링크하지 않는다.
- 공통 지침은 `codex/AGENTS.md`를 `~/.codex/AGENTS.md`와 `~/.local/share/codex/AGENTS.md`에서 사용하도록 연결한다.
- 연결 전 대상이 없거나 이미 올바른 링크인지 `readlink`·`realpath`로 확인한다. 기존 일반 파일이나 다른 대상을 자동으로 덮어쓰지 말고 보존하거나 중단한다.
- 스킬 수정 묶음이 끝난 뒤 변경된 스킬에만 `quick_validate.py`를 한 번 실행하고, 링크가 원본을 가리키는지 확인한다. 스킬 본문에는 공통 AGENTS 규칙을 반복하지 않는다.
