# 피해 방식별 훈련 아이콘

2026-10-18 제작. 기존 강화의 은색·청록·굵은 남색 윤곽을 이어받은 3종이다. 내장 ImageGen으로 각각 생성했고 알파를 보존하여 게임용 경로에 복사했다. 생성 프롬프트는 `prompts.json`에 그대로 보관한다.

| 훈련 | 게임용 최종 PNG | 표현 |
| --- | --- | --- |
| 타격 훈련 | `assets/images/upgrades/direct_damage_training.png` | 화살촉과 단일 명중 표시 |
| 범위 타격 훈련 | `assets/images/upgrades/splash_damage_training.png` | 방사형 타격과 충격파 고리 |
| 지속 피해 훈련 | `assets/images/upgrades/damage_over_time_training.png` | 모래시계와 화상 |

게임에서는 기존 아이콘 소켓·강화 카드·스테이지 보상 구조를 사용한다. 게임 import의 최대 크기는 각 256px이고 제작 원본 PNG는 그대로 유지한다. 타격·범위·지속 훈련의 효과·해금·비용은 `docs/gameplay_balance_reference.md`와 `docs/damage_calculation_rules.md`를 따른다.
