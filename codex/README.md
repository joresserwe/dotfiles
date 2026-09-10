# Codex 설정

기본 작업 모델은 `gpt-5.6-luna` + `xhigh`다. 분석·계획·조사는 `gpt-5.6-terra` + `xhigh`, 어려운 진단·아키텍처·리뷰는 `gpt-5.6-sol` + `high`를 사용한다. Astra는 사용자가 명시한 자문용 읽기 전용 작업에서만 `-p astra-readonly`로 선택한다.

기본 TUI는 Catppuccin Mocha 테마와 `model-with-reasoning`, 브랜치, 남은 컨텍스트, 사용량 한도를 간결한 footer에 표시한다. 이 지침과 프로필은 라우팅 의도를 제공하며, 선택한 프로필 밖의 모델·도구 권한을 운영체제 수준에서 강제한다고 약속하지 않는다. Astra CLI 보호는 `astra-readonly` 프로필의 `read-only` sandbox, `approval_policy = "never"`, `agents.enabled = false`에 한정된다.

프로필을 직접 실행할 때는 다음처럼 쓴다.

```sh
codex -p luna
codex -p terra
codex -p sol
codex -p astra-readonly
```

모델 이름을 지시문에 적는 것만으로 현재 부모 세션의 모델이 바뀌지는 않는다. 실제 라우팅이 불가능한 환경에서는 `-p` 명령을 사용한다. `codex/config.toml`은 저장소가 관리하는 기본값 템플릿이다. 설정 병합에는 Python 3.11 이상(`tomllib`)이 필요하다. `bash codex/install.sh`를 다시 실행하면 두 Codex 설정 루트에 유효 설정을 동기화하며, 기존 프로젝트 신뢰·로컬 TUI 항목 같은 머신별 값은 보존한다.

Codex는 레거시 기본 루트 `~/.codex`와 XDG 데이터 루트 `${XDG_DATA_HOME:-$HOME/.local/share}/codex`를 함께 준비한다. `config.toml`은 머신별 값을 보존하기 위해 유효 설정을 생성하고, 프로필·공통 `AGENTS.md`·커스텀 스킬·hook은 개별 심볼릭 링크한다. 인증·세션과 시스템 스킬이 있는 디렉터리 전체는 교체하지 않는다. 커스텀 스킬은 `$implement`, `$review`, `$shared-skills`, `$commit`처럼 호출한다.

`PostToolUse`의 `apply_patch` hook은 추가된 주석 줄만 보고 `AGENTS.md`의 주석 규칙을 짧게 환기한다. 저장소 전체 diff·테스트·모델 호출을 하지 않고, 주석이 없으면 조용히 종료한다. hook은 advisory라서 주석을 삭제하거나 쓰기를 차단하지 않는다. 처음 실행할 때 native hook 신뢰를 요청하면 정확한 로컬 hook 경로와 내용을 확인한 뒤 일반 `/hooks` UI에서 신뢰한다. 우회 플래그로 신뢰하지 않는다.
