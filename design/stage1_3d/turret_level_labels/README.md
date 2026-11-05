# 포탑 레벨 배지 atlas 원본과 재생성

Lv.1~Lv.15 투명 PNG atlas다. 도형은 폐기한 Flutter `TurretLevelRenderer.drawBadge`를 옮겼고, 색과 11레벨 이후 장식은 2026-11-05 사용자가 고른 시안 A를 따른다.

- 테두리 색: 1~3 회색, 4~7 노랑, 8~10 주황, 11~15 다홍에서 빨강. 번호판은 모든 레벨에서 같은 어두운색이다.
- 장식: 1 없음, 2~4 마름모, 5~7 양옆 뾰족 장식, 8~9 큰 뾰족 장식, 10부터 별과 작게 튀어나온 깃털 날개 2장. 11~12는 Lv.10과 같은 구성에 색만 바뀌고, 13~14는 별 3개와 깃털 3장의 더 긴 날개, 15는 별 5개다.
- 방패·왕관·빛줄기처럼 장식을 쌓는 안은 사용자가 기각했다. 등급은 색으로 먼저 구분한다.
- 포탑 레벨 상한은 현재 기본 10, K5 「정예 육성」으로 11이다. 12~15 프레임은 상한 확장 검토용으로 미리 넣었고 지금은 표시되지 않는다.

## 좌표 계약

- 최종 게임 파일: `assets/images/stage1_3d/ui/turret_levels.png`, 3,840×144 RGBA PNG, 121,758 bytes.
- 가로 15프레임, 각 256×144. `frame = level - 1`, 원본 영역 `(frame*256, 0, 256, 144)`.
- 모든 프레임의 **배지 중심은 `(128,72)`**. `drawBadge`가 입력 tile 중심에서 아래로 이동하는 `+0.3 tile`을 호출 시 상쇄했다. Sprite에 이 오프셋을 다시 더하지 않는다. 기단 위치 결정은 런타임 담당이다.
- 1 tile = 256 texture pixels. 프레임 전체 크기는 `1.0×0.5625 tile`; 화면 스케일은 투영된 tile pixels / 256이다. 개별 레벨의 배지 폭·날개 폭 차이는 원래 renderer 값으로 보존한다.
- `RuneNexusGame._designTileSize = 48`을 논리 크기로 사용하고 `Canvas.scale(256/48)`로 고해상도화했다. tileSize256를 renderer에 직접 주지 않으므로 고정 pixel 선 두께와 text shadow의 상대 비율이 유지된다. 실제 게임 `_tileSize`는 화면에 따라 가변이므로 이 atlas는 논리 기준48의 표본이다.
- 게임에서 약 1/5로 줄여 그리므로 mipmap을 만들어 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`로 그린다. import 설정은 `scripts/prepare_godot_project.py`가 쓴다.
- 생성 시 각 프레임의 알파 경계가 최소 8px 안쪽에 있는지 검사한다. 최종 전체 경계는 좌우 최소13px, 상단19px, 하단32px 여백을 남겨 날개·glow·문장이 잘리지 않는다. 각 프레임 밖은 투명하며 인접 프레임 그림이 닿지 않는다.

실제 알파 bounds는 오른쪽/아래 exclusive 기준이다.

| 레벨 | 프레임 안 알파 bounds |
| --- | --- |
| 1 | 61,42 → 195,108 |
| 2~4 | 55,32 → 201,110 |
| 5~7 | 38,32 → 218,110 |
| 8~9 | 33,30 → 223,111 |
| 10~12 | 22,19 → 234,112 |
| 13~15 | 13,19 → 243,112 |

## 재생성

[생성기](generator/export_turret_level_badges.py)가 프레임을 SVG로 그리고 Godot `--headless`로 래스터화한다. 글자는 `assets/images/stage1_3d/ui/Roboto-VF.ttf`(weight 900) 윤곽을 경로로 넣는다. 게임에는 폰트를 추가하지 않는다.

```sh
python3 design/stage1_3d/turret_level_labels/generator/export_turret_level_badges.py
```

생성기는 프레임별 알파 bounds를 출력하고, 프레임 가장자리 8px 안쪽을 벗어나면 실패한다. Godot 실행 파일은 `GODOT_BIN` 또는 `scripts/run_godot_project_checks.py`의 기본 경로를 쓴다.

## 본게임 적용

Godot의 같은 렌더 프레임에 실제 고정 받침 하단을 따라 배치한다. 레벨·철거·카메라 동기화는 `godot/verify_turret_labels.gd`, Flutter 표시 전환·복귀는 `test/godot_battlefield_view_test.dart`에서 검사한다. 로컬 Android 검수 자료는 `verification/`에 보관한다.
