# 실제 콘텐츠 설정

역할: Godot 전투 콘텐츠 계약. 2026-09-24에 체크인 JSON과 SDK 독립 검사 경로를 확인했다. `game_content.json`과 `growth_content.json`이 현재 수정 원본이며, 빌드 준비는 이 파일을 그대로 복사한다. 이전 Dart 생성기의 수치를 변경하려면 JSON·관련 fixture를 함께 수정하고 [콘텐츠 검사](../../tool/content/README.md)를 실행한다.

`content_catalog.gd`는 `save_json.gd`의 타입 보존 JSON 파서를 사용한다. 스테이지·웨이브·적·포탑 정의와 생성 스폰 순서를 보존하고, 기존 `native_combat_runtime.gd` 및 `turret_stat_calculation.gd`에 입력을 조립한다. 정의 수치나 피해 공식을 별도로 작성하지 않는다. `stage()`의 `map.theme`은 renderer가 요구하는 `tileTheme` 별칭이다.

## 값 계약

- `stage(index)` / `wave(stage_index, round_index, first_enemy_id, inputs)`: 인덱스는 0부터 시작한다. 콘텐츠 ID/round는 원본 값을 유지한다. spawn ID는 first_enemy_id부터 순서대로 부여한다.
- `inputs.tileSize` 기본 `1.0`, `inputs.origin` 기본 `[0.0,0.0]`. 원본 48px 기준을 `tileSize/48`로 변환한다. 경로는 타일 중심 좌표로 조립한다. 이동 speed는 원본 px/s로 유지하고 runtime의 boardDistanceScale에서 변환한다. 반경·presentationSize·포탑 range/projectileSpeed·lightningChainJumpRange의 실제 단위를 구분한다.
- `inputs.initialDelay`는 초 단위이며 기본은 포탈 알림 + 추가 대기 시간이다. 앱 세션은 현재 배속을 곱해서 전달한다. `inputs.spawnValues`는 queue와 같은 길이의 `{laneOffsetRatio,visualPhase,diamondReward}` 배열이다. 생략하면 명시적인 영점 입력이다. `random_spawn_values()`는 콘텐츠에 기록된 확률/종류별 진폭으로 이 배열을 만든다. 과거 Dart RNG와 동일 seed 결과를 보장하지 않으며 명시 값으로 비교한다.
- `turret(type, inputs)`는 native `statInput`을 반환한다. `inputs.statInput`에는 `level`, `gems`, `primaryTrait`, `secondaryTrait`, `moduleEffect`, 일반 성장/코어 보정 배율 등의 **이미 결정된 값**을 전달한다. definition과 boardDistanceScale의 덮어쓰기는 거절한다. moduleEffect는 기존 전체 필드 dictionary 계약이다. 성장 구매·장착 가능 여부·재화·보상 처리는 여기서 수행하지 않는다.
- `bootstrap(stage_index, inputs)`는 원본 기본 defense 설정을 사용하며 `inputs.defenseConfig`로 이미 결정된 성장 값을 받는다. 로더는 `inputs.coreConfig`가 없으면 공격 코어를 생성하지 않는다. `inputs.coreConfig`를 전달할 수 있지만 선택/성장 해석과 매 라운드 normalMaxHp 갱신 책임은 호출자에게 있다. 현재 독립 세션은 Godot 성장 도메인의 `core_config()` 결과를 bootstrap과 매 라운드에 전달한다. 최종 본게임 코어 선택 UI는 후속 범위다.

## 검증과 범위

`verify_content_catalog.gd`는 전체 15 스테이지·600 웨이브·11,083 스폰의 ID/순서/지연/내구도/정수 및 실수 타입을 검사한다. `scripts/verify_godot_content.py`는 체크인 JSON의 구조·참조와 fixture 정합성을 SDK 없이 확인한다. 과거 실제 컴포넌트에서 생성한 128개 적 구성과 12개 포탑 구성 fixture는 역사적 비교 입력으로 보존되며, 현재 Godot 로더·계산 결과와 대조한다.

각 챕터 첫/마지막 스테이지의 실제 마지막 웨이브를 런타임에서 진행해 보스·경로 도착·코어 피해·웨이브 종료를 검사하고, 실제 화살포탑 공격도 확인한다. 검사에서 코어 HP만 명시적으로 높여 모든 적 도착을 관찰하며 적 스탯은 변경하지 않는다. 도착한 적은 경제 이벤트 ACK 전까지 남는 기존 계약을 유지한다.

```sh
python3 scripts/verify_godot_content.py
GODOT_BIN=/path/to/godot
"$GODOT_BIN" --headless --path godot --script res://verify_content_catalog.gd
GODOT_BIN=/path/to/godot python3 scripts/run_godot_native_regressions.py
```

최종 화면은 Android 앱에서 별도로 확인한다. 이 모듈은 콘텐츠 설정 경로다. 런·성장 명령은 [앱 도메인](../app/run_commands_README.md), 저장·서비스 연결은 [앱 저장 안내](../app/README.md)를 따른다. headless 검사는 기기 인증·저장 인계·배포 검증을 대체하지 않는다.
