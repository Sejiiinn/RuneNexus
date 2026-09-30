# 실제 콘텐츠 설정

역할: Godot 전투 콘텐츠 계약. 2026-09-24에 체크인 JSON과 SDK 독립 검사 경로를 확인했다. `game_content.json`과 `growth_content.json`이 현재 수정 원본이며, 빌드 준비는 이 파일을 그대로 복사한다. 이전 Dart 생성기의 수치를 변경하려면 JSON·관련 fixture를 함께 수정하고 [콘텐츠 검사](../../tool/content/README.md)를 실행한다.

`content_catalog.gd`는 `save_json.gd`의 타입 보존 JSON 파서를 사용한다. 스테이지·웨이브·적·포탑 정의와 생성 스폰 순서를 보존하고, 기존 `native_combat_runtime.gd` 및 `turret_stat_calculation.gd`에 입력을 조립한다. 정의 수치나 피해 공식을 별도로 작성하지 않는다. `stage()`의 `map.theme`은 renderer가 요구하는 `tileTheme` 별칭이다.

## 값 계약

- `stage(index)` / `wave(stage_index, round_index, first_enemy_id, inputs)`: 인덱스는 0부터 시작한다. 콘텐츠 ID/round는 원본 값을 유지한다. spawn ID는 first_enemy_id부터 순서대로 부여한다.
- `inputs.tileSize` 기본 `1.0`, `inputs.origin` 기본 `[0.0,0.0]`. 원본 48px 기준을 `tileSize/48`로 변환한다. 경로는 타일 중심 좌표로 조립한다. 이동 speed는 원본 px/s로 유지하고 runtime의 boardDistanceScale에서 변환한다. 반경·presentationSize·포탑 range/projectileSpeed·lightningChainJumpRange의 실제 단위를 구분한다.
- `inputs.initialDelay`는 초 단위이며 기본은 포탈 알림 + 추가 대기 시간이다. 앱 세션은 현재 배속을 곱해서 전달한다. `inputs.spawnValues`는 queue와 같은 길이의 `{laneOffsetRatio,visualPhase,diamondReward}` 배열이다. 생략하면 명시적인 영점 입력이다. `random_spawn_values()`는 콘텐츠에 기록된 확률/종류별 진폭으로 이 배열을 만든다. 과거 Dart RNG와 동일 seed 결과를 보장하지 않으며 명시 값으로 비교한다.
- `turret(type, inputs)`는 native `statInput`을 반환한다. `inputs.statInput`에는 `level`, `gems`, `primaryTrait`, `secondaryTrait`, `moduleEffect`, 일반 성장/코어 보정 배율 등의 **이미 결정된 값**을 전달한다. definition과 boardDistanceScale의 덮어쓰기는 거절한다. moduleEffect는 기존 전체 필드 dictionary 계약이다. 성장 구매·장착 가능 여부·재화·보상 처리는 여기서 수행하지 않는다.
- `turret_stats()`와 전투 런타임은 `Stats.shared_stats_at()`의 동일한 기본 스탯 결과를 재사용한다. 정의·젬·모듈·성장·레벨 등 전체 입력을 대조하며 미리보기 레벨은 별도 입력이다. 거리 단위 및 일시 코어·연쇄 정리 배율만 기존 연산 순서로 적용한다. 반환값은 호출자 소유이며 공유 캐시는 최대 256개다. 원 `Stats.stats_at()`는 캐시 없는 수치 비교 경로로 유지한다. [공유 계산 검증](../../design/combat_ui_concepts/2026-09-23/turret-stats-ux/incremental-update/shared-stats/README.md).
- `bootstrap(stage_index, inputs)`는 원본 기본 defense 설정을 사용하며 `inputs.defenseConfig`로 이미 결정된 성장 값을 받는다. 로더는 `inputs.coreConfig`가 없으면 공격 코어를 생성하지 않는다. `inputs.coreConfig`를 전달할 수 있지만 선택/성장 해석과 매 라운드 normalMaxHp 갱신 책임은 호출자에게 있다. 현재 독립 세션은 Godot 성장 도메인의 `core_config()` 결과를 bootstrap과 매 라운드에 전달한다. 최종 본게임 코어 선택 UI는 후속 범위다.

## 확장 진행과 고정 ID

2026-09-30에 본게임 콘텐츠를 25개 맵·1,000라운드로 연결했다. 기존 15개 맵의 좌표·600웨이브 출현 구성·최초 보상을 보존하며, 신규 10개 맵은 승인된 [챕터 1 설계](../../design/chapter1_map_expansion/README.md)와 [챕터 2 설계](../../design/chapter2_map_expansion/README.md)의 좌표·출현 큐를 사용한다. `scripts/apply_stage_expansion.py`는 신규 맵 정의를 연결하고 전체 25개 맵의 내구도를 진행 순번 기준으로 재생성한다.

| 표시 | 고정 ID | 진행 순번 |
| --- | --- | --- |
| 1-1~1-5 | 1~5 | 1~5 |
| 1-6~1-10 | 16~20 | 6~10 |
| 2-1~2-5 | 6~10 | 11~15 |
| 2-6~2-10 | 21~25 | 16~20 |
| 3-1~3-5 | 11~15 | 21~25 |

`game_content.stages`의 배열은 고정 ID 순서를 유지한다. 기존 활성 런의 0 기반 `stage`와 저장 `stageNumber`는 같은 맵을 계속 가리킨다. 화면의 챕터·단계 표기와 다음 맵 이동·해금은 `stage_progression.gd`의 별도 진행 순서를 사용한다. 적 HP·보호막·방어구는 기존·신규 맵 모두 논리 진행 순번으로 계산하며, 라운드 배율·기본 적 정의는 유지한다. [내구도 산식](../../docs/gameplay_balance_reference.md#적-체력-보정)의 스테이지 입력에 고정 ID를 사용하지 않는다. 룬 보상은 기존 맵의 값을 보존하고 신규 맵에만 논리 진행 순번을 적용한다.

진행 중 런을 복원할 때 이미 출현한 적의 최대·현재 HP와 현재 보호막·방어구는 저장값을 유지한다. v2가 저장하지 않는 최대 보호막·방어구는 현재 콘텐츠에서 가져오는 기존 복원 계약을 유지하며, 이 최대값을 사용하는 재생·방어구 감쇄도 현재 기준을 따른다. 유형·남은 지연만 보관하는 미출현 적과 다음 웨이브는 현재 콘텐츠의 내구도를 사용한다. 저장 스키마와 진행 기록을 바꾸거나 저장된 손상 상태를 새 배율로 소급 환산하지 않는다.

[성장 해금 배분](../../design/stage_expansion_progression/README.md)은 실제 구매·연구·포탑·젬·코어·슬롯 조건에 연결된다. 라이트닝은 2-2(고정 ID 7) 클리어, 연구 슬롯 2 구매 자격은 2-10(고정 ID 25) 클리어다. 슬롯은 기존 600다이아 구매를 유지한다. 구 저장의 레벨 0 해금 자격과 기존 맵 접근은 `progressionVersion`, `unlockedStageIds`, `grandfatherUnlocks`로 보존하며 저장 스키마 v2는 유지한다. 이관·클라우드 경계는 [앱 저장 계약](../app/README.md)을 따른다.

서버 정산도 같은 고정 ID를 사용한다. `stage:11:first_clear`의 모듈권 5장과 수령 영수증은 3-1에 그대로 둔다. 순위 DB는 012 마이그레이션의 `stage_progression_ordinal()`로 비교하며 기록의 ID·달성 시각은 바꾸지 않는다. 서버 코드와 012 마이그레이션은 로컬 격리 DB에서 검사하며 운영 적용은 별도 배포다.

`verify_stage_expansion.gd`는 신규 400웨이브 입력·25맵의 순차 해금·클리어·기존 권한·구 성장 이관·런 복원을 검사한다. 전체 25맵의 실제 40라운드 플레이 체감과 Android 실기기·운영 계정 검증은 이 자동 검사로 판정하지 않는다.

## 선택적 전송 기믹

`map.teleportPairs`는 `[{"color":"blue","entrance":[col,row],"exit":[col,row]}]` 형태다. 파랑·주황을 각 한 쌍까지 허용하며, 두 끝점은 `tiles[row*columns+col] == "path"`인 맵 안 통로 타일이며 원본 경로에 각각 한 번만 등장해야 한다. `spawn`·`core`·건설칸에는 배치하지 않는다. IN은 OUT보다 앞서야 하고 모든 끝점은 서로 달라야 한다. 잘못된 메타데이터는 콘텐츠 로딩·bootstrap 검증에서 명시적으로 거부한다. 기존 15개 맵은 유지하고 신규 1-7·1-10·2-7·2-8·2-10에 배치한다.

포탈 사이의 길을 끊는 맵에서는 중간 통로 타일과 경로 좌표를 함께 제거하고, `path`에서 IN 바로 다음에 OUT을 둔다. 상하좌우로 인접하지 않은 경로 연결은 등록된 IN→OUT 도약에만 허용한다. 단절을 숨긴 연속 통로나 빈 공간을 걷는 경로를 만들지 않는다. [챕터 1 추가 맵 설계](../../design/chapter1_map_expansion/README.md)는 이 계약으로 두 맵을 구성한다.

콘텐츠는 이를 bootstrap의 `{color,entranceIndex,exitIndex}` 배열로 변환한다. 적이 IN waypoint에 도착하면 같은색 OUT 중심으로 즉시 이동하고 다음 waypoint를 향한다. 프레임당 한 waypoint 이동과 초과 이동량 버림, 상태 효과 갱신 순서는 기존과 같다. 콘텐츠 배치는 통로 타일에 한정한다. 타일 종류를 받지 않는 내부 bootstrap 인덱스 실행기는 범용 경계 처리를 유지하지만 콘텐츠에서 스폰·코어 배치를 허용한다는 뜻은 아니다. 원본 경로의 OUT 누적거리로 `distanceTravelled`를 갱신하므로 기존 우선순위와 v2 저장·복원 계약을 사용하며 저장 필드를 추가하지 않는다. HP·상태·적 ID는 유지한다.

전송 이벤트 `kind=teleport`의 `fromX/fromY/x/y`는 origin과 tileSize가 적용된 **logical board pixels**다. 적 presentation row의 기존 0~13 필드는 유지하고 전송 맵에서만 index 14에 `{teleportSerial:int}`를 추가한다. 이 일련번호는 렌더러의 이동·회전 보간 초기화 용도이며 저장하지 않는다. 투사체는 기존처럼 자신의 궤적과 이동 완료 후 적 중심을 검사하므로 IN~OUT 구간을 적의 충돌 궤적으로 취급하지 않는다.

`verify_teleport_gimmick.gd`는 메모리 안의 격리 맵으로 입력 거부·양색 이동·상태 유지·큰 dt·정지/배속·충돌·v2 출구 복원을 검사한다. 선택 실행은 `python3 scripts/run_godot_native_regressions.py verify_teleport_gimmick.gd`를 사용한다.

## 검증과 범위

`verify_content_catalog.gd`는 전체 25개 스테이지·1,000웨이브·19,398스폰의 ID/순서/지연/내구도/정수 및 실수 타입을 검사한다. `scripts/verify_godot_content.py`는 체크인 JSON의 구조·참조와 전체 진행 순번의 내구도 산식을 SDK 없이 확인한다. 과거 실제 컴포넌트에서 생성한 128개 적 구성과 12개 포탑 구성 fixture는 역사적 비교 입력으로 보존한다. 적 fixture의 비교 복사본에만 승인된 내구도 배율을 적용하며, 이동·상태·메타데이터와 포탑 fixture는 그대로 대조한다.

각 챕터 첫/마지막 스테이지의 실제 마지막 웨이브를 런타임에서 진행해 보스·경로 도착·코어 피해·웨이브 종료를 검사하고, 실제 화살포탑 공격도 확인한다. 검사에서 코어 HP만 명시적으로 높여 모든 적 도착을 관찰하며 적 스탯은 변경하지 않는다. 도착한 적은 경제 이벤트 ACK 전까지 남는 기존 계약을 유지한다.

```sh
python3 scripts/verify_godot_content.py
GODOT_BIN=/path/to/godot
"$GODOT_BIN" --headless --path godot --script res://verify_content_catalog.gd
GODOT_BIN=/path/to/godot python3 scripts/run_godot_native_regressions.py
```

최종 화면은 Android 앱에서 별도로 확인한다. 이 모듈은 콘텐츠 설정 경로다. 런·성장 명령은 [앱 도메인](../app/run_commands_README.md), 저장·서비스 연결은 [앱 저장 안내](../app/README.md)를 따른다. headless 검사는 기기 인증·저장 인계·배포 검증을 대체하지 않는다.
