# 문서 지도

역할: 작업별 참조 진입점과 문서 갱신 규칙. 정리: 2026-09-09.
모든 문서를 읽는 목록이 아니다. 아래에서 작업에 맞는 기준 문서와 필요한 절만 선택한다.

## 작업별 진입점

| 작업 | 먼저 읽을 문서 | 필요한 경우 추가 참조 |
| --- | --- | --- |
| 프로젝트 이해 | [프로젝트 소개](../README.md), [구현 현황](implementation_status.md) | [백엔드 구조](backend_architecture.md) |
| 다음 작업 선택 | [남은 작업과 우선순위](next_work_priorities.md) | 해당 기능의 설계·현재 코드 |
| UI·시각 에셋 수정 | [DESIGNS.md](../DESIGNS.md) | 해당 화면의 design/ 기록, [인앱 검증](../.agents/in_app_test_guide.md) |
| 전투 수치·피해 효과 | [데미지 계층 규칙](damage_calculation_rules.md), [밸런스 기준](gameplay_balance_reference.md) | 해당 데이터 정의·테스트 |
| 코어·성장 | [코어 트리 현행 기준](core_passive_tree_implementation_plan.md) | [장기 코어 방향](nexus_core_design.md), [모듈](turret_module_design.md), [성장 후보](long_term_progression_direction.md) |
| 계정·인증·온라인 저장 | [백엔드 구조](backend_architecture.md) | [저장 동기화](multi_device_save_sync_design.md), [닉네임](account_nickname_policy.md) |
| 서버 경제 | [서버 권위 경제 계약](server_authoritative_economy_design.md) | [저장 동기화](multi_device_save_sync_design.md) |
| 배포·마이그레이션 | [배포 인계](deployment_status.md) | [API 운영 절차](self_hosted_api_deployment.md), [APK 배포](android_apk_distribution.md), 해당 workflow |
| 로컬 실행·검증 | [AGENTS.md 공통 검증](../AGENTS.md#flutter-공통-검증), [인앱 진입점](../.agents/in_app_test_guide.md) | [Windows 차이](../.agents/windows_flutter_guide.md), [DB 실행](local_postgresql_setup.md) |
| 커밋·실행 권한 | [권한 기준](../.agents/sandbox_command_guide.md), [커밋 절차](git_commit_workflow.md) | 현재 세션의 실행 정책 |

## 문서 역할과 권위

- **현행 기준**: 현재 채택한 동작·제약을 기술한다. 세부 값과 구현 사실은 관련 코드·테스트로 확인한다. 구현이 다르다는 이유만으로 제품 결정을 자동 변경하지 않는다.
- **현황**: 구현과 검증의 마지막 확인 기록이다. 운영 상태는 [배포 인계](deployment_status.md)로 분리하며 필요할 때 실제 환경을 확인한다.
- **제안·백로그**: 아직 승인·구현되지 않은 후보다. 파일이 존재한다는 이유로 실행하거나 현재 기능이라고 보고하지 않는다.
- **역사 기록**: [개발 이력](development_history.md), [초기 MVP](mvp_work_plan.md), archive/의 원본과 대체된 시안이다. 결정 이유를 조사할 때만 읽으며 당시 명령·승인 조건은 현재 작업 지시가 아니다.
- 기능별 문서 안에서 현행 본문을 먼저 제공한다. 변경된 규칙을 뒤에 예외로 덧붙여 독자가 합성하게 하지 않는다.
- 표지의 날짜만으로 전체 문서의 최신성을 보장하지 않는다. 부분 점검이면 점검한 범위와 남은 미검증 범위를 명시한다.

## 나머지 기능·설계 자료

- 콘텐츠 설계: [챕터 2](chapter2_wave_enemy_design.md), [챕터 3](chapter3_forge_design.md), [젬 파편·특성](gem_shard_trait_design.md), [포탑 공격 명령](turret_target_priority_design.md).
- 현행 기능과 이전 설계를 함께 확인할 자료: [리더보드](leaderboard_design.md), [인게임 UX 변경 범위](in_game_ux_improvement_design.md).
- 과거·후속 검토: [긴급 매각 계획](emergency_sale_upgrade_plan.md), [구 코어 슬롯](core_passive_slot_ui_design.md). 현재 구현 여부는 [구현 현황](implementation_status.md)과 해당 코드에서 확인한다.
- 정식 출시 전 제거 대상: [카카오 진행 이전](legacy_local_save_transfer.md).

## 변경과 함께 갱신할 범위

| 변경 | 갱신할 기록 |
| --- | --- |
| 승인된 UI 방향 변경 | DESIGNS.md의 해당 결정과 관련 design/ 기준 자료 |
| 기능·API·저장 계약 변경 | 해당 기능의 현행 본문; 필요할 때 구현 현황의 요약 |
| 백로그 항목 구현 완료 | next_work_priorities.md에서 미완료 항목 제거 또는 완료 문서 링크로 교체 |
| 배포 선행 조건 발생 / 배포 완료 | deployment_status.md의 미배포 항목 / 검증 이력 |
| 도구·실행 절차 변경 | .agents의 해당 진입점; 다른 문서에는 절차 복제 대신 링크 |

동작에 영향 없는 국소 리팩터링·포맷 변경은 문서 갱신을 강제하지 않는다. 문서만 바꿀 때는 링크·내용·diff를 검사하며 게임 빌드나 시각 검증을 추가하지 않는다.

새 현행 문서는 역할·확인 날짜/커밋·적용 범위·관련 구현/테스트·대체 문서만 간단히 적는다. 수치·전체 테스트 개수·배포 버전을 여러 문서에 복제하지 않는다. 원본을 옮길 때 기존 링크를 유지하거나 새 위치로 연결하고, 과거 지시는 역사 인용으로 보존한다.
