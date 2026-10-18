# 챕터 3 부유 철골 잔해

2026-10-19. [외곽 설비 받침·부유 잔해 시안](../../environment_concepts/outrigger-floating/README.md) 중 부러진 I형 철골만 먼저 Blender로 만든 제작 원본과 게임 경량본이다. 게임 배치 결정은 [전장·지형·효과](../../../../docs/design_decisions/battlefield.md#챕터-3-스테이지-1115)를 따른다.

## 구성

- [편집 원본](floating-girders.blend): `girder_long_torn`, `girder_bent_ripped`, `girder_twisted_stub`와 소량용 `girder_wide_flange_stub`, `debris_torn_plate` 독립 루트(라이브러리, X=12 열). `REVIEW layout`은 검수용 배치이며 라이브러리가 아니다.
- [제작 스크립트](build_girders.py): `Blender --background --python build_girders.py -- --render`. 타일 원본(`../../tiles/chapter3-thick-tiles.blend`)의 재질을 복사해 쓰고 원본은 바꾸지 않는다.
- [형상 수치](geometry-check.json): 루트별 크기·삼각형 수(평가 후 3.5~4.2k).

| 루트 | 형태 |
| --- | --- |
| `girder_long_torn` | 길이 약 0.95타일. 한쪽은 볼트 4개 끝판, 반대쪽은 대각선으로 찢긴 단면과 위아래로 벌어진 플랜지 끝, 웨브의 실제 관통 볼트 구멍 2개 |
| `girder_bent_ripped` | 약 0.65타일. 양 끝이 찢기고 충격으로 24° 휨 |
| `girder_twisted_stub` | 약 0.43타일. 양 끝이 찢기고 28° 비틀림 |
| `girder_wide_flange_stub` | 소량용. 약 0.5타일 길이·폭 0.25·높이 0.24의 두꺼운 H형 토막. 웨브 보강판 4장, 양 끝이 찢기고 10° 비틀림 |
| `debris_torn_plate` | 소량용. 시안의 두꺼운 찢긴 철판(약 0.58×0.48, 두께 0.09). 불규칙 윤곽·계단형 홈·위면 볼트 2개·아래 용접 턱, 세 변이 찢긴 열선. 길 타일의 따뜻한 회색 주철 재질 |

공통 단면: 높이 0.17 · 플랜지 폭 0.112 · 플랜지 두께 0.022 · 웨브 두께 0.017(1 = 타일 한 칸). 원점은 철골 중심이며 부착 계약이 없다(떠다니는 소품). 본체는 건설칸 상판의 청흑 흑연 철, 끝판은 짙은 단조 철, 마모 모서리·볼트는 타일과 같은 재질을 쓴다. 찢긴 단면만 `Torn steel | cooling heat`(어두운 철 + 노이즈 마스크의 가는 주황 열선, 발광 1.1)로 국소 열기를 준다. 휨·비틀림은 메시에 반영했고, 베벨·가중 법선은 수정자로 남겨 편집할 수 있다.

## 검수

- [게임 시점 렌더](review-game-angle.png): Godot 용광로 고정 시점(카메라 (5,20,13) → Blender (5,-13,20), 직교)과 게임 태양 방향 `(-48,-125,0)`을 옮겼다. 하늘·주변광은 카메라에 보이지 않는 중립 주변광으로 대신했다. 실제 길·건설 타일 두 칸을 축척 기준으로 두었다.
- [3/4 근접 렌더](review-studio.png): 라이브러리 세 종류의 단면·휨·비틀림 확인용.
- Blender 렌더 기준 판정: 시안의 부러진 I형 철골 형태와 어두운 철·국소 주황 단면 인상을 충족한다. 게임 거리에서 잘 보이도록 게임 배치는 1.45~1.85배로 키운다. Android 실기기 외형은 아직 확인하지 않았다.

## 게임 경량본

- `build_girders.py -- --game`은 같은 시드·윤곽·손상으로 베벨 1단·휨 분할 8·구멍 10각·리벳 8각의 [경량 원본](floating-girders-game.blend)을 만든다. [형상 수치](geometry-check-game.json).
- [`export_girders.py`](export_girders.py)는 기존 [소품 경량 내보내기](../../environment_props/optimized-game-distance/export_optimized.py)의 원시 채널 베이크를 따라 512 PBR 5채널(`girders-*.png`)과 공용 재질 하나로 [GLB](chapter3-floating-girders.glb)를 만들고 재가져오기 위치 오차를 검사한다. [내보내기 기록](export-check.json).
- 게임 파일: `assets/images/stage1_3d/environment/chapter3_floating_girders.glb`(1,686,908바이트).

| 루트 | 원본 삼각형 | 경량 삼각형 |
| --- | ---: | ---: |
| `girder_long_torn` | 3,756 | 1,936 |
| `girder_bent_ripped` | 4,240 | 1,640 |
| `girder_twisted_stub` | 3,548 | 1,324 |
| `girder_wide_flange_stub` | 3,804 | 1,428 |
| `debris_torn_plate` | 1,368 | 600 |

게임 배치는 [`chapter_three_debris.gd`](../../../../godot/environment/chapter_three_debris.gd)가 맵 데이터로 정하며, 기본 3종 3~7개에 소량용 2종을 1개(기본 6개 이상이면 2개) 더해 맵당 최대 9개(약 14k 삼각형)다. 실기기 FPS·APK 크기 변화는 측정하지 않았다.

## 다음 단계

나머지 부유 잔해(철판 조각·슬래그·볼트)와 외곽 설비 받침은 별도 작업이다.
