---
name: review
description: Perform a requested read-only review, prioritizing actionable defects with precise file and line evidence.
---

# 리뷰

사용자가 읽기 전용 검토를 요청했을 때 사용한다.

- 요청된 범위와 변경 맥락만 확인하고 파일을 수정하거나 패치를 적용하지 않는다.
- 정확성·회귀·보안·운영 영향이 있는 결함을 우선순위 순으로 찾고, 각 발견에 파일·라인과 영향, 재현 또는 수정 방향을 붙인다.
- 추측은 사실과 구분하고, 결함이 없으면 확인한 범위와 남은 불확실성을 짧게 밝힌다.
