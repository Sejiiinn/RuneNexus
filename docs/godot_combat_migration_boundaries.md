# Godot 전투 이관과 검증 경계

역할: 현행 Godot 전투·앱·Android 경계. 2026-09-24에 소스 책임을 대조했다. 실행·실기기·배포의 완료 상태는 [이관 로드맵](godot_unified_app_roadmap.md)과 [배포 현황](deployment_status.md)을 따른다.

## 현재 상태

Android 스테이지 1~15의 전투·런·저장·UI 소스는 Godot 앱에 있다. 활성 Android 호스트는 `android-godot-only/` 하나다. 이전 Flutter/Dart 원본은 [보관본](archive/flutter_reference_20260924.tar.gz)에 있으며 현재 실행·검사 경로가 아니다. 현재 콘텐츠는 스테이지 1~15이며 16 이후의 별도 2D 콘텐츠는 없다.

웹 배포 경로는 폐기했다. Android 외 플랫폼 지원 범위는 [이관 로드맵](godot_unified_app_roadmap.md)을 따른다. Android 소스 이관을 실제 공개 배포나 기존 설치 인계 검증으로 간주하지 않는다.

정식 Android 진입은 `--app`이고 수동 전투·세션 검증에는 `--session`을 사용한다. 두 경로는 같은 Godot 전투·콘텐츠 소스를 공유하지만 세션 수명주기와 저장 위치를 구분한다. 이전 독립 개발 경로의 v2 Save/Load·Exit 저장 검증은 [당시 기록](analysis/godot_content_save_20260921/README.md)에 남아 있다.

## 책임 경계

| 책임 | 현행 구현 |
| --- | --- |
| 적 이동·상태·내구도·도착 | [적 상태](../godot/combat/native_enemy_state.gd) |
| 타깃·조준·발사·탄환·저항·특성·지속 피해 | [전투 런타임](../godot/combat/native_combat_runtime.gd), [피해 계산](../godot/combat/attack_calculation.gd) |
| 웨이브 생성·완료, 코어 주기·활성화 | [웨이브](../godot/combat/native_wave_state.gd), [코어 스킬](../godot/combat/native_core_skill_state.gd) |
| 코어 HP·방어·긴급 방어·회복·패배 | [코어 방어](../godot/combat/native_core_defense_state.gd) |
| 콘텐츠·런·성장·로컬 저장 | [콘텐츠 로더](../godot/content/README.md), [Godot 명령](../godot/app/run_commands_README.md), [앱 저장 계약](../godot/app/README.md) |
| 계정·온라인 저장·경제·업데이트 | [Godot 앱 서비스](../godot/services/app_services.gd)와 서비스별 모듈; 기존 API·저장 계약 유지 |
| Google Credential Manager·암호화 세션·APK 다운로드/설치·기기 경로 | [Android 플랫폼 플러그인](../android-godot-only/README.md) |
| 전투·효과 시간, 전장 터치·카메라, 전체 화면 경고 | Godot 세션·입력 계층 |
| 화면 배치·초기 로딩 연결 | [앱 수명주기](../godot/app/app_lifecycle.gd), Godot 로비·HUD |

전투 규칙과 데미지 계층은 Godot 전투·콘텐츠가 소유한다. Android 플러그인에는 게임 규칙을 두지 않는다. 수치 기준은 [데미지 규칙](damage_calculation_rules.md)을 따른다.

## 실행·저장 계약

초기 bootstrap의 실제 ACK 뒤에만 전투를 진행한다. 명령은 epoch·sequence 순서로 처리하고 같은 명령의 재전송을 중복 실행하지 않는다. 전투 프로토콜 버전 1이 없거나 초기화에 실패하면 오류와 재시도를 표시하고 전투를 정지한다. 2D 전투로 자동 복귀하지 않는다.

적 갱신 → 생성 → 코어 스킬 → 완료의 순서를 유지한다. 코어 도착은 Godot 전투에서 방어·HP를 즉시 계산한다. 패배가 확정되면 같은 배치의 추가 생성·코어 공격·웨이브 완료 보상을 차단한다. 앱은 확정된 방어 스냅샷과 coreDefeated 이벤트로 HUD·종료 연출을 갱신한다.

매 명령 배치에서 전체 저장 JSON을 만들지 않는다. ACK된 상태를 앱 도메인에 반영하고 실제 저장 요청 때 직렬화한다. 이벤트 처리 도중에는 저장을 모았다가 상태 반영 뒤 확정한다. 보상·온라인 경제 API·저장 스키마는 유지한다.

메뉴 이탈·재시도는 마지막 확정 상태로 새 epoch를 만든다. 진행 중 웨이브는 기존 저장과 같이 정지 상태로 복원하며 이전 세대 응답은 폐기한다. 기존 스키마에 없는 진행 중 탄환은 새로 저장하지 않는다. 준비 단계의 명시적 HP 변경만 복원 명령을 사용하며 일반 설정 갱신으로 전투 HP를 되돌리지 않는다.

Godot 앱은 확정한 도메인 상태와 ACK된 전투 스냅샷을 함께 저장하고, 실제 콘텐츠·성장·장착 설정을 재구성해 정지 상태로 복원한다. v2에 없는 탄환·코어 주기 시계를 추가하지 않으며 대기 중인 적의 무작위 값은 콘텐츠 규칙으로 다시 생성한다. 처치·보스·웨이브·런 강화 퀘스트, KST 일·주 초기화, 플레이 시간과 런 종료 룬·코어·최고 라운드·클리어·해금을 연결한다. 이벤트는 진행에 반영한 뒤 ACK하며, stable run UUID와 `claimedEventIds` 종료 마커로 중복 정산을 방지한다. 런 종료 v2 체크포인트와 영속 보상 Outbox를 먼저 기록한 뒤 Stage/재시도로 이동한다. 쓰기 실패 시 전환을 차단한다. 게스트 큐는 로컬에 격리하고 계정으로 자동 재바인딩하지 않으며, 서버 다이아·모듈권을 로컬에서 확정하지 않는다. Save/Load·Exit 저장 실패 시 현재 세션을 유지한다. 계정 정산 호출의 과거 검증 범위는 [당시 기록](analysis/godot_rewards_quests_20260921/README.md)을 따른다.

## 검증과 남은 범위

[네이티브 회귀 실행기](../scripts/run_godot_native_regressions.py)는 저장·경제·보상·입력과 전투 검증 스크립트를 임시 Godot 프로젝트에서 실행한다. [Flame 제거 검사 대응표](analysis/flame_removal_20260920/legacy_test_coverage.md)와 [보관본](archive/flame_reference_tests_20260920/README.md)은 과거 Dart 검사의 대응·제외 범위를 기록한다.

Godot 순수 계산·전투 회귀 통과는 실기기 성능 완료를 뜻하지 않는다. 프레임 시간·발열·메모리는 같은 장치·빌드·전투 조건에서 별도로 측정한다. 기존 Android 연결 결과는 [당시 검증 기록](analysis/flame_removal_20260920/README.md)에 남아 있으며 새 Godot 단일 앱의 기기 결과로 재사용하지 않는다.

이전 단계의 수치 비교·Android 연결·웨이브 이관 이력은 [과거 진행 기록](archive/godot_combat_migration_before_removal_20260920.md), [웨이브 이관 검증](analysis/native_wave_core_20260920/README.md), [이전 FPS 측정](analysis/fps_20260920/README.md)을 참고한다.
