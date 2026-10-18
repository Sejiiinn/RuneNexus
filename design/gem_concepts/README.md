# 현재 젬 이미지 기준

2026-10-17 승인된 보석·금속 장식 개편본을 기존 공용 경로에 적용한다. 기존 14종 가운데 13종을 교체했고, `armorPiercing`(장갑 관통)은 기존 이미지를 유지한다. 별도로 승인한 마젠타 관통 젬은 향후 신규 젬이며 이번 교체 대상에 포함하지 않는다. 보존용 초기 원본을 새 시안의 디테일 기준으로 사용하지 않는다.

| 용도 | 경로 |
| --- | --- |
| 실제 게임 적용본 | [`assets/images/gems/simplified/`](../../assets/images/gems/simplified/) — 128×128 RGBA PNG 14종 |
| 현재 제작 원본·재생성 방법 | [승인 개편 원본](approved-20261017/source/), [128px 재생성](approved-20261017/build_runtime.py), [채택 매핑·해시](approved-20261017/manifest.json) |
| 이전 단순화 원본 | [2026-10-09 작업](../gem_simplification/2026-10-09/README.md) — 기존 기록과 원본 보존 |
| 관통 젬 시안 | [piercing-p3](piercing-20261015/piercing-p3.png)(금 테두리 보석 + 화살), [piercing-i](piercing-20261015/piercing-i.png)(크리스탈이 돌 고리를 꿰뚫음), [프롬프트](piercing-20261015/prompt.txt) — Codex 생성, 게임 미적용 |
| 젬 개편 시안 | [물리 피해 증폭 Y1](revamp-20261015/physical-y1.png), [설계 규칙](revamp-20261015/README.md) — 게임 미적용 |
| 재사용 가능한 미채택 형태 후보 | [중화기 A–G](heavy-weapon-alternatives/README.md), [H–P](heavy-weapon-round3/README.md), [보조 젬 참고 후보](heavy-weapon-poe/README.md), [기둥 결합 후보](heavy-weapon-columns/README.md) — 현행 적용·디테일 기준과 구분 |
| 재사용 가능한 배경 제거 도구 | [prepare_transparency.py](production/prepare_transparency.py)와 같은 폴더의 5개 `*-opaque.png` 입력 |
| 보존 전용 초기 원본·대체 시안 | [레거시 안내](../legacy/README.md), [당시 제작 기록](../legacy/design/gem_concepts/README.md) |

## 게임 연결

[`app_ui_source()`](../../scripts/prepare_godot_project.py)는 기존 `gems/{id}.png` 식별자를 실제 `simplified/` 파일에 연결한다. 게임 내 `res://assets/app/gems/{id}.png` 경로와 보상·인벤토리·소켓 공용 에셋 사용은 유지한다.

보존용 최상위 PNG 14개는 `design/legacy/assets/images/gems/`로 이동했다. 기존 원본과 과거 채택 기록은 그대로 보존한다. 최초 젬뿐 아니라 대체된 중간 시안도 보존 전용이면 레거시에 둔다. 미채택이라도 다른 젬에 활용할 수 있는 독립적인 형태 후보는 활성 작업 경로에 유지한다.

## 재사용 도구

`production/prepare_transparency.py`는 외부 연결 무채색 배경을 분리하는 도구다. 기존 입력 5개(`aimSpeed`, `chain`, `explosion`, `multipleProjectiles`, `physicalDamage`)를 함께 유지한다. 이 입력은 도구 재사용을 위한 자료이며 현재 젬의 스타일 기준은 위 단순화 원본이다. 과거 추출 결과와 비교 화면은 레거시 제작 기록에 보존한다.
