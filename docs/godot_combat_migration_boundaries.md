# Godot 전투 이관과 검증 경계

역할: 현행 전투·앱 책임과 Flame 제거 진행 상태. 갱신: 2026-09-20.

## 현재 상태

Android 스테이지 1~15의 전투는 Godot으로 이관했다. `pubspec.yaml`의 Flame 의존성, `FlameGame`·`GameWidget`, 2D 전투·표시 컴포넌트와 Dart 명중 실행기를 제거했다. 현재 콘텐츠는 스테이지 1~15이며 16 이후의 별도 2D 콘텐츠는 없다.

**전체 플랫폼 이관은 미완료다.** Godot 앱 브리지는 Android에만 있다. 웹·iOS·PC 전투의 대체 연결 또는 지원 범위 결정이 남아 있으므로 현재 변경을 전체 플랫폼 배포 완료로 간주하지 않는다.

## 책임 경계

| 책임 | 현행 구현 |
| --- | --- |
| 적 이동·상태·내구도·도착 | [적 상태](../godot/combat/native_enemy_state.gd) |
| 타깃·조준·발사·탄환·저항·특성·지속 피해 | [전투 런타임](../godot/combat/native_combat_runtime.gd), [피해 계산](../godot/combat/attack_calculation.gd) |
| 웨이브 생성·완료, 코어 주기·활성화 | [웨이브](../godot/combat/native_wave_state.gd), [코어 스킬](../godot/combat/native_core_skill_state.gd) |
| 코어 HP·방어·긴급 방어·회복·패배 | [코어 방어](../godot/combat/native_core_defense_state.gd) |
| 정적 전투 설정·성장·경제·보상·저장·HUD | Flutter와 [앱 연결](../lib/game/game_native_combat.dart) |
| 전투·효과 시간, 전장 터치·카메라, 전체 화면 경고 | Godot 세션·입력 계층 |
| 화면 배치·초기 로딩 연결 | [NativeGameHost](../lib/ui/hud/native_game_host.dart), Flutter 프레임 공급 없음 |

Dart의 EnemyComponent/TurretComponent 이름은 기존 호출 계약을 유지하지만, 현재는 저장·설정·HUD용 데이터 모델이다. Flame 컴포넌트 트리, 적 이동, 사격, 명중 또는 2D 전장 렌더를 실행하지 않는다. Vector2는 vector_math를 직접 사용한다. 데미지 계층과 수치 기준은 [데미지 규칙](damage_calculation_rules.md)을 따른다.

## 실행·저장 계약

초기 bootstrap의 실제 ACK 뒤에만 전투 소유권을 활성화한다. 명령은 epoch·sequence 순서로 전달하고 같은 명령의 재전송을 중복 실행하지 않는다. 전투 프로토콜 버전 1이 없거나 연결이 실패하면 오류와 재시도를 표시하고 전투를 정지한다. 2D 전투로 자동 복귀하지 않는다.

적 갱신 → 생성 → 코어 스킬 → 완료의 순서를 유지한다. 코어 도착은 Godot 안에서 방어·HP를 즉시 계산한다. 도착마다 앱의 arrivalResult를 기다리던 장벽은 제거했다. 패배가 확정되면 같은 배치의 추가 생성·코어 공격·웨이브 완료 보상을 차단한다. 앱은 확정된 방어 스냅샷과 coreDefeated 이벤트로 HUD·종료 연출을 갱신한다.

매 명령 배치에서 전체 저장 JSON을 만들지 않는다. ACK 상태를 기존 저장 모델에 미러하고 실제 저장 요청 때 직렬화한다. 한 응답의 이벤트 처리 도중에는 저장을 모았다가 상태 반영 뒤 확정한다. 보상·온라인 경제 API·저장 스키마는 유지한다.

메뉴 이탈·재시도는 마지막 확정 상태로 새 epoch를 만든다. 진행 중 웨이브는 기존 저장과 같이 정지 상태로 복원하며 이전 세대 응답은 폐기한다. 기존 스키마에 없는 진행 중 탄환은 새로 저장하지 않는다. 준비 단계의 명시적 HP 변경만 복원 명령을 사용하며 일반 설정 갱신으로 전투 HP를 되돌리지 않는다.

## 검증과 남은 범위

[Flame 제거 검사 대응표](analysis/flame_removal_20260920/legacy_test_coverage.md)는 삭제된 Dart 전투 검사와 Godot 검사의 대응·제외 범위를 기록한다. 원본 검사는 [보관본](archive/flame_reference_tests_20260920/README.md)에 남긴다. 저장·경제·보상·입력 검사는 Flutter에 유지한다.

Godot의 순수 계산·실제 전투 회귀 통과는 실기기 성능 완료를 뜻하지 않는다. 프레임 시간·발열·메모리는 같은 장치·빌드·전투 조건에서 별도로 측정한다. 이 변경에서는 과도한 실화면 반복 검증을 피하고 Android 대표 흐름을 확인한다. 실제 실행 결과는 [이번 검증 기록](analysis/flame_removal_20260920/README.md)에 남긴다.

이전 단계의 수치 비교·Android 연결·웨이브 이관 이력은 [과거 진행 기록](archive/godot_combat_migration_before_removal_20260920.md), [웨이브 이관 검증](analysis/native_wave_core_20260920/README.md), [이전 FPS 측정](analysis/fps_20260920/README.md)을 참고한다.
