---
name: implement
description: Apply an explicitly requested code, configuration, script, or test change with scoped inspection and targeted validation.
---

# 구현

사용자가 구현·수정·생성 작업을 명시적으로 요청했을 때 사용한다.

- 요청과 적용 범위를 먼저 확정하고, `rg`와 필요한 파일의 focused read로 현재 동작과 관련 규칙을 확인한다.
- 기존 무관 변경을 보존하면서 가장 작은 일관된 변경을 적용한다. 요청하지 않은 리팩터링이나 외부 쓰기를 추가하지 않는다.
- 각 파일·패치 직후 검증을 반복하지 말고, 의미 있는 수정 묶음이나 작업 마무리 시 필요한 테스트·린트·명령을 최소 범위로 모아 한 번 실행한다. 실패사항을 모아서 수정한 뒤 실패·영향 범위만 재검증한다. 사용자가 명시했거나 다음 구현을 막는 오류 원인 확인에 필요한 좁은 중간 검증은 허용하며, 완료 전 필요한 검증은 유지한다.
- 최종 보고에는 변경 파일, 달라진 동작, 실행한 검증과 남은 제한만 간결하게 적는다.
