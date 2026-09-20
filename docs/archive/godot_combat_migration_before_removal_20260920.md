> 역사 기록: Flame 제거 전의 단계별 진행 기록이며 현행 구현 기준이 아니다. 구현과 검증 수치는 기록 당시 기준이다.

# Godot 전투 이관 단위와 검증 경계

역할: Flame 완전 제거를 위한 구현 순서·검증 경계와 부분 진행 상태. 작성: 2026-09-19, 부분 갱신: 2026-09-20. **전투 엔진 전체 이관은 완료되지 않았다.** 현행 표시 구현은 [표시 소유권 문서](../godot_presentation_migration_plan.md), 피해 계산의 기준은 [데미지 계층 규칙](../damage_calculation_rules.md)을 따른다.

## 진행 방식과 계산 이관 범위

전체 Dart 전투 구조를 먼저 리팩터링하지 않는다. 이관할 계산의 입력·출력만 분리하고 Godot 구현과 같은 입력으로 비교한 뒤, 연결된 전투 단위가 준비되면 실제 처리 책임을 전환한다. 비교 구현은 런타임에서 매 공격마다 호출하는 브리지가 아니며 피해·처치·보상을 중복 실행하지 않는다.

첫 묶음은 1단계 중 명중의 계열·태그 저항, 취약, 피해 배율 계산과 화상·둔화·냉기 균열의 적용 입력 계산이다. 기존 발사 스냅샷에 반영된 포탑·젬·연구 수치를 사용한다. 이번 타격의 피해를 확정한 뒤 상태를 적용하는 순서와 지속피해에서 타격 치명타·직접 명중 특성 배율을 제외하는 계약을 유지한다.

순수 계산은 [AttackCalculation](../../lib/domain/combat/attack_calculation.dart), 기존 컴포넌트와의 연결은 CombatResolver (`../../lib/game/systems/combat_resolver.dart`, 당시 경로), Godot 대응 계산은 [attack_calculation.gd](../../godot/combat/attack_calculation.gd)에 둔다. 첫 묶음에서는 비교 실행용이었고 세 번째 묶음부터 본게임의 전투 생산자에 연결했다.

실제 전투 소유권 전환 전에는 기존 업데이트·표시 브리지·저장 경로를 유지하며, FPS 개선을 완료 기준으로 주장하지 않는다. 계산 이관과 전투 소유권 이관의 상태는 아래 묶음별 기록을 따른다.

### 첫 묶음 검증 기록 — 2026-09-20

- [고정 기대값](../../test/fixtures/combat_calculation.json) 24개를 [비교 실행 도구](../../tool/verify_combat_calculation.dart)로 Dart와 Godot headless에서 실행했다. 저항 상한 직전/경계/초과·음수 취약·계열별 감소·태그 중복 제거·화상과 둔화의 분기를 포함한다. 수치는 절대/상대 `1e-10`, 효과 순서·필드·불리언은 정확히 비교한다.
- [실제 발사 스냅샷 검사](../../test/combat_resolver_calculation_test.dart)는 포탑 6종의 레벨 보정과 화염/냉각의 젬·특성을 포함해 분리 전 공식, 실제 Resolver, 순수 Dart와 Godot 결과를 비교한다. 발사 뒤 포탑 레벨 변경이 기존 스냅샷 피해를 바꾸지 않는지와 상태 적용 뒤 후속 피해도 확인한다. 모든 연구/젬/특성 조합의 Godot 이관 완료를 뜻하지 않는다.
- 전체 `flutter test`: 936개 통과, 12개 건너뜀. 기존 저장·전투 회귀를 포함한다. `flutter analyze`는 지적 사항 없이 통과했고, Godot 실제 스냅샷 비교 테스트의 단독 실행도 통과했다. 추가 비교 실행은 게임 에셋이나 열린 Godot 편집기를 건드리지 않는 임시 프로젝트를 사용한다.
- 이번 검증은 수치 계산·기존 동작 회귀 범위다. Android 본게임 실행, 실제 전투 소유권 전환, 실기기 FPS·메모리·발열은 검증하지 않았다. 순수 계산 비교 통과를 다음 단계의 Android 검증 통과로 대신하지 않는다.

macOS 재현 명령은 저장소 루트에서 `WORK_DIR="$PWD" scripts/in_app_server_macos.sh dart run tool/verify_combat_calculation.dart`다. 첫 인자로 Godot 실행 파일 경로를 지정할 수 있다. 실제 스냅샷 검사는 `WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/combat_resolver_calculation_test.dart`를 사용하며 기본 위치에 Godot이 없으면 `GODOT_BIN`으로 지정한다.

### 두 번째 묶음 — 포탑 스탯·발사 스냅샷

레벨·장착 젬·선택 특성과 앱이 제공하는 모듈/연구/코어 보정값에서 피해·사거리·공격속도·조준시간·치명타·탄속·효과 범위·지속피해·둔화·연쇄 수치를 계산하는 부분을 이관한다. 발사 시점의 입력을 고정하고 이후 강화·젬·보정값 변경이 이미 발사한 공격에 소급되지 않도록 한다.

두 번째 묶음 당시에는 연구·모듈 인벤토리와 코어 스킬의 활성 상태를 앱에서 입력으로 제공하고, 특성 스택·타깃·발사 시점·난수 생성은 기존 전투에 남겼다. 이후 실제 전투 연결 범위는 세 번째·네 번째 묶음을 따른다. 저장 모델·보상·경제 API는 변경하지 않는다.

[TurretStatCalculation](../../lib/domain/combat/turret_stat_calculation.dart)은 [읽기 전용 입력과 발사 시 고정 입력](../../lib/domain/combat/turret_stat_input.dart)을 사용한다. 실제 포탑 getter는 최신 앱 보정값을 읽는 어댑터에 연결하고, 발사 시에는 불변 입력을 한 번 캡처해 기존 `TurretAttackSnapshot` 필드로 옮긴다. 일반 getter에서 스탯 전체를 계산하거나 젬 집합을 매번 복제하지 않는다. [Godot 대응 계산](../../godot/combat/turret_stat_calculation.gd)은 두 번째 묶음에서는 비교용이었고, 세 번째 묶음에서 실제 전투에 연결했다.

비교 기준은 수정 전 실제 `TurretComponent`에서 추출한 [고정 출력 282개](../../test/fixtures/turret_stat_calculation.json)와 [치명타 확률 경계 36개](../../test/fixtures/turret_stat_critical_boundaries.json)다. 포탑 6종·레벨 1/3/7/10·레벨 범위 밖 미리보기·장착 가능한 젬·특성 조합·앱 보정값·보드 배율과 상한/하한을 포함한다. 연구 진행도나 모듈 인벤토리 자체를 Godot에 이관한 검사는 아니며, 앱이 제공한 보정값을 사용하는 수치 생산 경계를 검증한다.

원본 커밋·소스와 고정 출력의 SHA-256은 [기준값 출처](../../test/fixtures/turret_stat_calculation.provenance.md)에 기록했다. 새 계산기로 기대값을 다시 생성하지 않는다.

`WORK_DIR="$PWD" scripts/in_app_server_macos.sh dart run tool/verify_turret_stat_calculation.dart`로 고정 출력과 Dart/Godot headless 계산을 비교한다. 첫 인자로 Godot 실행 파일 경로를 지정할 수 있다. 318개 모두 수치 허용 오차 `1e-10` 이내로 일치했다. [실제 컴포넌트 검사](../../test/turret_stat_calculation_test.dart)는 같은 기준값에 연결 경로를 비교하고, 레벨·젬·모듈/연구 보정·보드 크기 변경 뒤 현재 값 갱신과 기존 발사 스냅샷 유지, 연쇄 정리 만료, 불변 입력과 호출자가 정한 치명타 값 보존을 확인한다.

2026-09-20 검증: 전체 `flutter test` 1,263개 통과·12개 건너뜀, `flutter analyze` 지적 없음, `git diff --check` 및 변경 문서 링크 검사 통과. 새 테스트는 327개이며 기존 검사와 별도로 합산하지 않는다.

두 번째 묶음의 수치 비교만으로 Android 본게임이나 실기기 성능 검증을 대신하지 않는다. 실제 전투 연결과 검증은 이후 묶음에 별도로 기록한다.

### 세 번째 묶음 — Android 3D 실제 전투 소유권

[전투 런타임](../../godot/combat/native_combat_runtime.gd)과 [적 상태](../../godot/combat/native_enemy_state.gd)를 본게임에 연결한다. 지원되는 Android 3D 전장에서 적 이동·상태이상·내구도, 포탑 타깃·조준·발사, 탄환 충돌·관통·연쇄·광역 피해의 생산자는 Godot이다. 같은 전투의 Flame Enemy/Turret/Projectile/번개 충전·연쇄 갱신은 중지하며, 표시 프레임의 적·포탑·탄환 좌표 전송도 생략한다. 앞의 두 묶음에 기록된 비교 전용 상태는 각 묶음 완료 당시의 기록이다.

[앱 연결](../../lib/game/game_native_combat.dart)과 [명령 스트림](../../lib/domain/combat/native_combat_protocol.dart)은 장면 세대·명령 번호·응답 번호·이벤트 번호를 사용한다. 전투 명령은 오래된 표시 프레임을 버리는 슬롯과 분리한다. 응답 전에는 같은 명령을 재전송하고 Godot은 중복 실행하지 않는다. 원래 각 프레임의 dt와 명령 순서를 유지하며, 불확실한 전송 실패는 전투를 정지시킨다. 실패 시 Flame 피해 판정을 자동으로 다시 켜지 않는다.

세 번째 묶음에서는 웨이브 생성·코어 스킬 타이머·보상·경제·앱 UI를 Dart에 유지하고 코어 스킬의 실제 적 피해만 명령으로 전달했다. 웨이브·코어 주기의 후속 이관은 아래 네 번째 묶음에 기록한다. 기존 저장 모델에 맞는 스냅샷 미러는 과도기 연결이며, 엔진 간 상태 전달의 최종 최적화나 Flame 의존성 제거 완료를 뜻하지 않는다. 미지원 스테이지·플랫폼의 기존 2D 전투도 남아 있다.

자동 검증: Flutter 전체 1,268개 통과·12개 건너뜀, 분석 지적 없음. 이후 재진입 결함 수정의 관련 7개 검사도 통과했다. Godot 적 상태 45개 검사와 포탑 설정 273개의 실행 검사, 정확 피해·발사 간격·조준·저항·번개 지연·처치 한 번·중복 명령·dt 보존 검사를 통과했다. 273개는 공격이 실행되는지의 검사이며 전체 프레임 단위 Dart/Godot 동등성 검사로 해석하지 않는다. [실행 기록](../analysis/native_combat_20260920/README.md)에 Android 실제 결과와 검증 한계를 기록한다.

메뉴 이탈 뒤 새 화면에 재진입하면 마지막 확정 ACK의 전투 저장 상태로 미러·생성 큐를 복원하고 새 세대의 초기 상태 인수를 시작한다. 진행 중 웨이브는 기존 저장 복원과 같이 정지 상태로 돌아온다. 이전 세대의 미확정 명령·응답을 이어서 실행하지 않는다. 저장 스키마에 원래 없는 진행 중 탄환은 새로 저장하지 않는다.

매 명령 배치의 저장 JSON 생성과 상태 미러 비용은 남아 있다. CPU/GPU 또는 전체 FPS 개선은 별도 동등 조건 측정 전에는 주장하지 않는다.

### 네 번째 묶음 — 웨이브·코어 주기·완료 판정

Android 3D 전투에서 웨이브의 실제 적 생성 시점, 코어 스킬의 쿨다운·활성화·지연 틱, 적과 생성 대기열이 모두 소진됐는지의 판단을 Godot으로 이관한다. 앱은 웨이브 시작 시 기존 데이터로 정적 생성 계획·적 설정을 준비하고, 완료 결과에 따른 보상·경제·화면 전환을 담당한다. 기존 2D 경로는 기존 컨트롤러를 사용한다.

개체 갱신 → 생성 → 코어 스킬 → 완료 순서를 보존한다. 코어 도착으로 인한 방어·패배 결과가 확정되기 전에 클리어 보상을 실행하지 않는다. 생성 대기열의 남은 지연과 코어 누적 통계는 기존 저장 형식에 반영하며, 저장 복원의 코어 주기 초기화·웨이브 정지 의미를 유지한다.

검증: Flutter 전체 1,275개 통과·12개 건너뜀, 분석 지적 없음. 실제 Dart 타이머 기준 Godot 검사 683개와 기존 포탑 273개 구성 회귀 검사가 통과했다. Android에서는 4배속 23웨이브의 생성·코어 발동·완료 및 24웨이브 준비 상태 저장을 한 번 확인했다. 사용자 요청에 따라 실화면은 대표 흐름 1회·최종 캡처 1장으로 제한했다. [검증 범위·실행 기록](../analysis/native_wave_core_20260920/README.md).

## 현재 결합과 이관 순서

기존 2D에서는 `RuneNexusGame.update`가 Flame 컴포넌트를 갱신한 뒤 웨이브 생성·코어 스킬·웨이브 종료를 처리한다. Android 3D 전투 인수 후에는 대응 갱신을 생략하고 Godot이 같은 순서로 처리한다. 앱은 코어 도착에 따른 HP·방어·패배 결과와 완료 후 보상 처리를 맡는다. 전투 시계는 정지·보상·로딩·배속·코어 파괴 감속에 영향을 받고, 시각 시계는 별도다. Godot으로 옮길 때 물리 tick을 도입하거나 처리 순서를 바꾸는 일은 단순 엔진 교체와 분리해 검증한다.

| 순서 | 이관 단위와 현재 근거 | 선행 조건과 완료 기준 |
| --- | --- | --- |
| 1 | 공격 입력·수치 규칙: `domain/combat/attack_calculation.dart`, `domain/combat/turret_stat_calculation.dart`, `systems/combat_resolver.dart`, `TurretAttackSnapshot` | 명중 피해·상태 적용 입력과 포탑 스탯·발사 수치의 순수 계산을 분리하고 Godot 비교 구현을 추가했다. 앱의 보정값 생산과 적별 특성 발동 상태·난수·전투 소유권 전환은 남아 있다. 실제 전투 이관 전체 완료로 간주하지 않는다. |
| 2 | 적 상태·이동·상태 효과: `components/enemy_component.dart` | 논리 좌표·경로 진행·HP/장갑/보호막·지속 피해·사망·코어 도달 순서의 일치를 확인한다. 적 ID와 생성/제거 수명을 확정해야 타깃과 탄환을 연결할 수 있다. |
| 3 | 포탑 타깃·발사와 명중: `components/turret_component.dart`, `projectile_component.dart`, `systems/combat_execution_controller.dart`, `sequential_lightning_chain_component.dart` | 공격 쿨다운·타깃 우선순위·발사 스냅샷·선분 충돌·관통/연쇄/광역·지연 타격을 함께 검증한다. 직접 명중과 연쇄의 특성 발동 차이, 죽거나 철거된 대상, 동시 처치와 사거리 끝을 포함한다. 기존 표시 이벤트의 생산자를 Godot으로 교체하고 매 프레임 탄환 동기화를 제거한다. |
| 4 | 웨이브·코어 스킬·전투 종료: `systems/wave_spawner.dart`, `core_combat_skill_controller.dart`, `rune_nexus_game.dart` | 생성 큐의 남은 지연, 배속/일시정지, 코어 피격·패배·웨이브 종료와 보상 전환을 한 전투 소유자가 결정한다. 한 프레임에 여러 적이 생성/사망하는 경우와 마지막 적 처치 직후를 확인한다. |
| 5 | 실행 상태 저장·복원과 앱 연결: `systems/game_save_adapter.dart`, `game_restore_controller.dart`, `data/save/game_save_data.dart` | 기존 저장 스키마·맵 서명·진행 중 웨이브·포탑/젬·적·생성 큐를 기존 의미로 변환한다. 복원 대기 상태에서 자동으로 전투가 진행되지 않아야 한다. 온라인 저장·경제 API의 계약과 중복 지급 방지를 보존한다. |
| 6 | Flame 런타임과 의존성 제거 | 모든 지원 스테이지·플랫폼의 전장/입력 대체를 끝낸 뒤 Component/Vector2 등 타입 의존성, GameWidget 및 2D fallback을 제거한다. Flutter UI·계정·서버 통신의 존치 여부는 Flame 제거와 별개다. |

1→2→3→4가 전투 의존 순서다. 저장 계약은 1단계부터 입력·출력 설계에 반영하고 각 단계에서 복원 검사를 수행하며, 5단계에서 최종 생산자를 교체한다. 전체 완료 때까지 별도의 장기 수명 Flame 전투 프레임워크를 새로 만들지 않는다.

## 엔진과 앱 사이의 계약

다음은 후속 구현의 계약 기준이며 현재 브리지에 모두 구현되어 있다는 뜻은 아니다.

- 앱 → 전투: 건설·철거·업그레이드·젬 장착·웨이브 시작·배속·정지/재개 명령. 실행 순서와 중복 거절용 ID, 전투 세대를 포함하고 적용 결과를 반환한다. 명령이 승인된 시점의 자원/대상을 검증한다.
- 전투 → 앱: HUD에 필요한 변경 상태와 처치·코어 피해·웨이브 종료·보상 결과. 화면 매 프레임 전량 좌표를 앱으로 왕복시키지 않는다. Godot이 소유한 이동·표시는 Godot에서 완결한다.
- 저장: Godot 내부 노드나 표시 DTO를 저장하지 않는다. 기존 저장 모델에 맞는 일관된 전투 스냅샷을 세대·적용 명령 경계에서 추출한다. 진행 중 공격의 저장 여부 등 기존 스키마에 없는 항목은 임의로 추가하거나 보장하지 않는다.
- 소유권 전환: 한 전투에서 피해·처치·재화 지급을 실행하는 엔진은 하나다. 비교용 Godot 실행은 저장/보상/API 부작용을 내지 않는다. 부분 이관 중에는 읽기 전용 결과 비교 또는 명확히 분리한 단위의 소유권을 사용하며, ACK 실패로 양쪽 판정을 동시에 켜지 않는다.
- 재연결: 장면 재생성으로 전투 명령·보상·피해가 재실행되지 않아야 한다. 오래된 세대 응답은 폐기한다. 현재 표시 fallback과 전투 소유권 복귀는 다른 계약으로 취급한다.

## 단계별 검증과 통과 조건

기존 Dart 테스트를 정답 사례의 출발점으로 사용하고 같은 입력과 dt 순서를 Godot에서 실행해 비교한다. 난수 입력·생성 순서·ID를 기록해 재현 가능하게 하되, 새 고정 timestep이나 다른 타깃 정렬을 이관에 몰래 도입하지 않는다. 정수·열거값·이벤트 횟수는 일치해야 하며 부동소수 허용 오차는 해당 수치별로 정하고 경계 판정 결과의 차이를 숨기지 않는다.

| 검증 단위 | 기존 기준 테스트 | Godot 이관 때 추가할 비교 |
| --- | --- | --- |
| 공격·젬·특성 | `global_attack_rules_test.dart`, `global_gem_area_rules_test.dart`, `turret_trait_test.dart` | 동일 공격 스냅샷의 피해 계층·특성 발동·효과 적용 결과 |
| 이동·탄환·연쇄 | `enemy_path_cache_test.dart`, `projectile_chain_test.dart`, `multiple_projectiles_test.dart` | 동일 dt 시퀀스의 위치·타깃 ID·충돌 순서·실제 피해·사망 이벤트 |
| 코어·런 진행 | `core_combat_skill_controller_test.dart`, `run_progression_core_test.dart`, `gem_reward_targeting_test.dart` | 정지/배속/보상/패배 전환, 중복 실행 없는 보상 |
| 저장·앱 연결 | `game_save_data_test.dart`, `game_online_save_integration_test.dart`, `local_save_coordinator_test.dart` | 기존 저장→새 엔진 복원→재저장, 종료/복귀·재연결·지연 응답 |

각 단계는 관련 회귀 검사와 Android 본게임의 대표 상태를 통과한 뒤 소유권을 전환한다. 최종 제거에는 전체 Flutter 검사, Godot 판정 비교, 지원 플랫폼/스테이지 실행, 저장 호환성, APK 용량 점검이 필요하다. 현재 표는 비교 구현의 완료 목록이 아니다.

성능은 같은 전투·화면·빌드·장치에서 전후 비교한다. Flame update/브리지 bytes·인코딩 CPU, Godot CPU·GPU, 전체 표시 FPS와 p95/p99를 구분한다. 기존 디버그 barrage는 preparation 상태에서 HUD publish 주기가 실제 wave와 다를 수 있으므로 본전투와 동등한 측정 조건인지 먼저 확인한다. 과거 에뮬레이터 FPS는 이관 후 실기기 성능 통과를 보장하지 않는다.
