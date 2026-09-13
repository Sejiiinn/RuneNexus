# 포탑 레벨 배지 atlas 원본과 재생성

기존 `lib/game/rendering/turret_level_renderer.dart`의 `TurretLevelRenderer.drawBadge`를 Flutter engine Canvas에서 그대로 호출한 Lv.1~Lv.10 투명 PNG다. 프레임·날개·문장·별·텍스트 그림자·glow를 같은 코드로 그린다. 도형을 별도로 재해석하지 않는다. 생성기는 `tool/export_turret_level_badges.dart`다.

## 좌표 계약

- 최종 게임 파일: `assets/images/stage1_3d/ui/turret_levels.png`, 2,560×144 RGBA PNG, 74,311 bytes.
- 가로 10프레임, 각 256×144. `frame = level - 1`, 원본 영역 `(frame*256, 0, 256, 144)`.
- 모든 프레임의 **배지 중심은 `(128,72)`**. `drawBadge`가 입력 tile 중심에서 아래로 이동하는 `+0.3 tile`을 호출 시 상쇄했다. Sprite에 이 오프셋을 다시 더하지 않는다. 기단 위치 결정은 런타임 담당이다.
- 1 tile = 256 texture pixels. 프레임 전체 크기는 `1.0×0.5625 tile`; 화면 스케일은 투영된 tile pixels / 256이다. 개별 레벨의 배지 폭·날개 폭 차이는 원래 renderer 값으로 보존한다.
- `RuneNexusGame._designTileSize = 48`을 논리 크기로 사용하고 `Canvas.scale(256/48)`로 고해상도화했다. tileSize256를 renderer에 직접 주지 않으므로 고정 pixel 선 두께와 text shadow의 상대 비율이 유지된다. 실제 게임 `_tileSize`는 화면에 따라 가변이므로 이 atlas는 논리 기준48의 표본이다.
- 생성 시 각 프레임의 알파 경계가 최소 8px 안쪽에 있는지 검사한다. 최종 전체 경계는 좌우 최소28px, 상단20px, 하단32px 여백을 남겨 날개·glow·문장이 잘리지 않는다. 각 프레임 밖은 투명하며 인접 프레임 그림이 닿지 않는다.

실제 알파 bounds는 오른쪽/아래 exclusive 기준이다.

| 레벨 | 프레임 안 알파 bounds |
| --- | --- |
| 1 | 61,41 → 195,108 |
| 2~4 | 55,32 → 201,109 |
| 5~7 | 38,32 → 218,110 |
| 8~9 | 33,30 → 223,111 |
| 10 | 28,20 → 228,112 |

## 재생성

`flutter test`의 기본 Ahem 사각 글꼴로 제작하면 안 된다. Android 기본 계열 Roboto를 임시 파일로 받고, 생성기에서 명시 family `BadgeRoboto`로 로드한다. `TurretLevelRenderer(fontFamily: 'BadgeRoboto')`의 선택적 인자만 사용하며 실제 앱 호출은 기본 null을 유지한다. w900은 원래 renderer의 TextStyle 값이다. 텍스트 shadow도 `debugDisableShadows=false`로 활성화한다.

사용한 폰트는 Google Fonts Roboto variable의 고정 커밋이다. 원본: [Google Fonts Roboto](https://github.com/google/fonts/tree/6183fc0d26361f6ddfd6f6b7a736e1467c6d8a43/ofl/roboto). 폰트 파일 자체는 게임에 추가하지 않는다.

```sh
curl -L 'https://raw.githubusercontent.com/google/fonts/6183fc0d26361f6ddfd6f6b7a736e1467c6d8a43/ofl/roboto/Roboto%5Bwdth,wght%5D.ttf' -o /tmp/RuneNexus-Roboto.ttf
shasum -a 256 /tmp/RuneNexus-Roboto.ttf
scripts/in_app_server_macos.sh flutter test tool/export_turret_level_badges.dart --dart-define=BADGE_FONT_PATH=/tmp/RuneNexus-Roboto.ttf --reporter expanded --no-pub
```

폰트 SHA256: `d7598e12c5dbef095ff8272cfc55da0250bd07fbdecbac8a530b9b277872a134`.

생성기는 마지막에 좌표·프레임·알파 bounds·파일 크기 metadata를 출력한다. 최종 PNG를 직접 열어 Lv.1~Lv.10의 글자, 날개, 상단 문장/별, 투명 여백을 확인했다. 이 atlas 확인은 Godot 게임 적용 화면이나 시점 전환 검증을 대신하지 않는다.

## 본게임 적용

Godot의 같은 렌더 프레임에 실제 고정 받침 하단을 따라 배치한다. 레벨·철거·카메라 동기화는 `godot/verify_turret_labels.gd`, Flutter 표시 전환·복귀는 `test/godot_battlefield_view_test.dart`에서 검사한다. 로컬 Android 검수 자료는 `verification/`에 보관한다.
