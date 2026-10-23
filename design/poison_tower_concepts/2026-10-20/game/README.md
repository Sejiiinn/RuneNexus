# 독액 박격포 게임용 모델

사용자가 고른 A안 품질 재구성(`venom-mortar-quality-rev5.blend`, 외장 SSD `poison-mortar-quality-20261021`)을 게임 거리용으로 가볍게 만들어 `assets/images/stage1_3d/turrets/poison.glb`에 넣었다. 범위는 모델 준비뿐이다. 독 포탑 전투·해금·HUD·저장 구조는 [독 포탑 설계](../../../../docs/poison_elemental_infusion_design.md) 기준으로 아직 구현하지 않았다.

- [경량화 스크립트](build_game.py)와 [부품별 기록](optimization-manifest.json): rev5 제작 스크립트를 다시 실행한다. 원주 분할(128→48, 96·64→24 등), 구 분할, 관 단면, 베벨 단계(3→1)만 낮춘다. Decimate는 쓰지 않았다. 삼각형은 80,860개에서 15,080개로 줄었다. rev5 표면까지의 최대 거리는 경량본→원본 2.0mm, 원본→경량본 3.5mm다.
- 독액 탱크는 사용자 요청(2026-10-22·23)에 따라 rev5보다 30% 크게 하고, 포탑 중심 쪽으로 옮겨(`TANK_Y` 0.218→0.19) 뒤로 8° 기울였다(`TANK_TILT`). 포신 뒤끝이 탱크 아래 앞쪽에 붙는다. 받침대·급액관·배액관은 옮긴 탱크에 맞춰 다시 만들었다. 그래서 rev5와의 표면 거리 값에는 탱크 이동분이 포함된다.
- rev5 기초부 두 부품에 결함이 있었다. 회전축 중심 극점에 베벨이 걸리면서 NaN 정점 3,072개가 생겼다. 게임본에서는 극점을 반지름 2mm 고리로 바꿨고, 이 구멍은 위 부품에 가려 보이지 않는다.
- [베이크·내보내기 스크립트](export_game.py)와 [검사 기록](export-check.json):
  - 금속 4종은 1024 색·거칠기·노멀 아틀라스 한 벌로 공유한다. 화염 포탑과 같은 방식이다.
  - 저폴리에서는 Pointiness 모서리 마모가 면 전체로 번진다. 그래서 마모 강도를 0.5에서 0.15로 낮췄다.
  - 유리·독액은 Godot에 투과(transmission)가 없어서 알파 블렌드 재질로 바꿨다.
  - GLB는 3메시, 이미지 3장, 약 3.0MB다.
- 계층은 기존 포탑 규약을 따른다: `turret_root` → `turret_head`(회전) → `turret_barrel`(반동) → `muzzle`. 축척은 1.0이다.

검증: 정식 준비 경로(`prepare_godot_project.py`와 import)로 가져온 뒤, 실제 `BattlefieldUnits` 생성 경로로 화염·대포 포탑 옆에 배치해 Godot 렌더러에서 확인했다. [고정 시점](review/runtime-angled.png), [드론 시점](review/runtime-drone.png), [근접](review/runtime-close.png) 캡처가 있다. 근접 캡처는 별도 카메라로 찍었다. 재현 스크립트는 [capture_poison.gd](review/capture_poison.gd)다. Android 실기기·FPS는 측정하지 않았다. 전투 유형이 없어서 발사 효과는 일반 포탑의 기본 섬광·연기 경로에 머문다.

재생성: 저장소 루트에서 아래를 차례로 실행한다.

```sh
cd design/poison_tower_concepts/2026-10-20/game
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python build_game.py
/Applications/Blender.app/Contents/MacOS/Blender -b venom-mortar-game.blend --factory-startup --python export_game.py -- --install
```

건설 버튼 아이콘(`assets/images/ui/hud/turrets_3d/poison.png`)은 설치한 게임 모델을 라이트닝 포탑과 같은 고정 HUD 카메라로 렌더한다. 결과 범위는 [`hud-icon-verification.json`](hud-icon-verification.json)에 남긴다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python design/poison_tower_concepts/2026-10-20/game/render_hud_icon.py
```
