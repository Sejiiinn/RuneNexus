# Godot 콘텐츠 생성

`game_content_export.dart`는 기존 Dart 정의와 실제 컴포넌트의 전투 설정 직렬화를 호출하는 임시 생성기다. 양쪽에서 수치를 수동 수정하지 않는다.

- 원본: `lib/data/definitions/game_stage_*`, `game_enemy_data.dart`, `game_turret_data.dart`, `lib/domain/enemy/enemy_scaling.dart`, `lib/domain/combat/content_spawn_defaults.dart`, `diamond_carrier_rules.dart`.
- 조립 원본: `WaveSpawner.start/toSaveData`, `EnemyComponent.nativeCombatState`, `TurretComponent.nativeCombatConfiguration`. 포탑 계산 기대값은 기존 Dart `TurretStatCalculation`을 호출한다.
- 실행용 생성물: `godot/content/game_content.json`.
- 비교용 생성물: `test/fixtures/game_content_cases.json`.

저장소 루트에서 재생성:

```sh
UPDATE_GODOT_CONTENT=1 WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/godot_content_export_test.dart
```

재생성 없이 동등성 확인:

```sh
WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/godot_content_export_test.dart
```

정의의 Flutter 색상 타입 때문에 생성기는 Flutter 테스트 런너가 필요하다. 생성된 Godot 실행과 프로젝트 준비는 Dart를 실행하지 않는다. 정적 정의의 최종 Godot 원본 이전과 생성 도구의 Flutter/Dart 의존 제거는 후속 작업이다.

## 입력과 단위

전체 15 스테이지, 600 웨이브, 11,083개 스폰의 타입·순서·초 단위 지연을 기존 `WaveSpawner`로 생성한다. 각 웨이브에 8종 적의 스테이지/라운드 성장 계산 결과를 저장한다. 지도 타일 좌표는 정수, `tiles`는 행 우선 평탄 배열이다. 적/포탑 기본 템플릿은 48픽셀 타일, `boardDistanceScale=1.0` 기준이다. Godot은 선택한 타일 크기로 좌표와 거리만 변환하고 속도 정의·피해·초 단위는 보존한다.

128개 적 비교 사례는 1·6·11·15 스테이지의 1·40 라운드, 1/48 타일 크기, 모든 적을 실제 컴포넌트로 조립한다. 차선·시각 위상·다이아 보상도 0 이외 값을 포함한다. 12개 포탑 사례는 6종 기본값과 성장·젬 입력을 기존 계산기에 넣은 결과다.

실행 중 성장/장착 입력은 기존 `TurretStatInput`의 definition 이외 필드(레벨, 젬, 특성, 모듈 효과, 일반 성장·코어·피해 배율 등)다. 이 생성기는 구매·장착 검증·재화 소유권을 이전하지 않는다. `boardDistanceScale`과 이미 거리 단위를 반영한 `lightningChainJumpRange`는 전장 크기를 함께 반영해야 한다.

스폰 난수는 입력으로 명시한다. 차선은 `(roll * 2 - 1) * laneOffsetAmplitudes[type]`, 시각 위상은 `[0,1)` 값이다. 다이아 보상은 기존 `DiamondCarrierRules`의 확률 구간을 사용하며 보스에는 주지 않는다. 기본 포탈 지연은 `portalAlertDuration + postPortalAlertSpawnDelay`; 본게임에서 배속을 적용한 최종 `initialDelay`를 입력으로 넘긴다. 큐 원본은 초기 지연 0으로 생성한다.

검사는 파일 내용뿐 아니라 JSON 왕복 후 정수/실수 타입을 비교한다. Godot 로더와 실제 설정 비교 검사는 `godot/verify_content_catalog.gd` 및 콘텐츠 로더 모듈 안내를 따른다.

## 성장 정의와 상태 명령 기준값

`growth_export.dart`는 `RunProgression`, `TurretActionController`, 실제 `TurretComponent`를 호출해 `godot/content/growth_content.json`과 `test/fixtures/growth_*cases.json`을 생성한다. 영구강화·연구 비용은 각 레벨의 실제 getter 결과이며, 젬 호환·특성 목록·슬롯 비용·런 업그레이드 효과도 Dart 정의에서 가져온다. 코어 노드 및 모듈 정의는 `tool/godot_growth_core_export.dart`가 같은 출력에 추가한다. 생성물의 수치를 직접 수정하지 않는다.

```sh
UPDATE_GODOT_GROWTH=1 WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/godot_growth_export_test.dart
```

환경값을 생략하면 재생성 없이 최신 여부를 검사한다. 300개 포탑 명령 사례는 성공/거절, 비용, 투자금 기반 판매, 젬 반환 및 빈 슬롯, 장착 후 실제 `statInput`을 포함한다. 132개 일반 성장 사례는 영구강화와 연구 시작의 실제 전후 저장 형태·파생값을 비교한다. `growth_game_fixture.dart`는 별도로 메모리 전용 `MemorySaveRepository`를 주입한 실제 `RuneNexusGame.onLoad`로 건설·런 업그레이드의 전후 상태와 스탯을 추출한다. 사용자 저장·네트워크에는 접근하지 않는다. 기본·모듈 및 코어 성장·재화 부족 입력에서 성공, 중복 건설, 최대 레벨, phase 거절을 검증한다. 기본 `coreConfig`도 실제 네이티브 bootstrap에서 추출한다.

골드·조각·투자금·비용·레벨은 정수이며 연구 시간은 밀리초, 비율과 전투 스탯은 실수다. `levelUpCosts`는 현재 레벨 1부터, `linkUpgradeCosts`는 목표 슬롯 2부터, 연구·영구강화 `costs`와 런 업그레이드 `effects`는 현재 레벨 0부터 시작한다. `equippedGemSlots`의 `null`은 빈 위치이며 제거하거나 압축하지 않는다.
