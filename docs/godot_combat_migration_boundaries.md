# Godot 전투 이관 단위와 검증 경계

역할: Flame 완전 제거를 위한 후속 구현 순서와 승인 기준. 작성: 2026-09-19. **이 문서는 이관 설계이며 전투 엔진 이관 완료 기록이 아니다.** 현행 표시 구현은 [표시 소유권 문서](godot_presentation_migration_plan.md), 피해 계산의 기준은 [데미지 계층 규칙](damage_calculation_rules.md)을 따른다.

## 현재 결합과 이관 순서

현재 `RuneNexusGame.update`가 Flame 컴포넌트를 갱신한 뒤 웨이브 생성·코어 스킬·웨이브 종료를 처리한다. 전투 시계는 정지·보상·로딩·배속·코어 파괴 감속에 영향을 받고, 시각 시계는 별도다. Godot으로 옮길 때 물리 tick을 도입하거나 처리 순서를 바꾸는 일은 단순 엔진 교체와 분리해 검증한다.

| 순서 | 이관 단위와 현재 근거 | 선행 조건과 완료 기준 |
| --- | --- | --- |
| 1 | 공격 입력·수치 규칙: `domain/combat/attack_rules.dart`, `systems/combat_resolver.dart`, `TurretAttackSnapshot` | 포탑·젬·연구 보정을 적용한 발사 스냅샷, 피해 계열·태그·저항·취약·상태 규칙을 동일 입력으로 비교한다. 현재 resolver는 Enemy/Turret 컴포넌트에 결합되어 있어 순수 규칙 입력을 먼저 분리한다. |
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
