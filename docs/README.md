# 문서 지도

역할: 작업별 기준 문서 진입점. 정리: 2026-09-21.
모든 문서를 읽는 목록이 아니다. 아래에서 작업에 맞는 기준 문서와 필요한 절만 선택한다.

## 작업별 진입점

| 작업 | 먼저 읽을 문서 | 필요한 경우 추가 참조 |
| --- | --- | --- |
| 프로젝트 이해 | [프로젝트 소개](../README.md), [구현 현황](implementation_status.md) | [백엔드 구조](backend_architecture.md) |
| 다음 작업 선택 | [남은 작업과 우선순위](next_work_priorities.md) | 해당 기능의 설계·현재 코드 |
| Flutter 제거·Godot 단일 앱 전환 | [Godot 단일 앱 전환 상태](godot_unified_app_roadmap.md) | [현행 전투 책임](godot_combat_migration_boundaries.md), [1단계 구현 검증](analysis/flutter_host_removal_20260921/README.md), [2단계 저장 기반](analysis/godot_save_foundation_20260921/README.md) |
| UI·시각 에셋 수정 | [DESIGNS.md](../DESIGNS.md) | 해당 화면의 design/ 기록, [인앱 검증](../.agents/in_app_test_guide.md) |
| 독립 Godot UI 복원 | [게임 UI 보존·정리 기준과 상태별 차이](godot_ui_restoration_baseline.md), [메인 로비 복구](analysis/godot_lobby_restore_20260921/README.md), [인게임 HUD 복구](analysis/godot_hud_restore_20260921/README.md), [로비 하위 화면 복구](analysis/godot_subpages_restore_20260921/README.md) | [수명주기·기능 연결 기록 및 UI 상태 정정](analysis/godot_app_ui_20260921/README.md) |
| Blender → Godot 이관 | [현행 제작·이관 기준](stage1_native_material_workflow.md) | [기존 원본·명령 요약](../design/stage1_3d/blender_workspace/README.md#수정부터-게임-반영까지); 과거 실험은 원인 조사 때만 참조 |
| 성능 개선·대량 표시·CPU/GPU 작업 분배 | [최적화 지침](performance_optimization_guidelines.md) | 해당 기능의 코드·측정 기록, [인앱 검증](../.agents/in_app_test_guide.md), [APK 용량 점검](android_apk_distribution.md#용량-점검) |
| 전투 수치·피해 효과 | [데미지 계층 규칙](damage_calculation_rules.md), [밸런스 기준](gameplay_balance_reference.md) | 해당 데이터 정의·테스트 |
| 코어·성장 | [코어 트리 현행 기준](core_passive_tree_implementation_plan.md) | [장기 코어 방향](nexus_core_design.md), [모듈](turret_module_design.md), [성장 후보](long_term_progression_direction.md) |
| 계정·인증·온라인 저장 | [백엔드 구조](backend_architecture.md) | [저장 동기화](multi_device_save_sync_design.md), [닉네임](account_nickname_policy.md) |
| 서버 경제 | [서버 권위 경제 계약](server_authoritative_economy_design.md) | [저장 동기화](multi_device_save_sync_design.md) |
| 배포·마이그레이션 | [배포 인계](deployment_status.md), [파이프라인 지도·개선안](deployment_pipeline.md) | [API 운영 절차](self_hosted_api_deployment.md), [APK 배포](android_apk_distribution.md), 해당 workflow |
| 로컬 실행·검증 | [AGENTS.md 변경 대상별 검증](../AGENTS.md#변경-대상별-검증), [인앱 진입점](../.agents/in_app_test_guide.md) | [DB 실행](local_postgresql_setup.md) |
| 커밋·실행 권한 | [권한 기준](../.agents/sandbox_command_guide.md), [커밋 절차](git_commit_workflow.md) | 현재 세션의 실행 정책 |

## 문서 역할과 권위

역할별 원본과 갱신·병합·보관 규칙은 [문서 작성·유지 지침](documentation_guide.md)을 따른다. 지도에는 진행 상태·수치·테스트 결과를 복제하지 않는다.

- 현재 기능의 범위: [구현 현황](implementation_status.md).
- Godot 전환의 단계별 상태·남은 조건: [실행 로드맵](godot_unified_app_roadmap.md).
- 후속 후보: [백로그](next_work_priorities.md). 제안은 승인된 요구와 구분한다.
- 배포 사실과 미배포 항목: [배포 인계](deployment_status.md).

## 나머지 기능·설계 자료

[기능·검증 기록 찾아보기](reference_index.md)에서 상세 기능 문서와 날짜별 실험을 찾는다. 역사 자료는 당시 판단의 근거이며 현재 작업 지시가 아니다.

## 변경과 함께 갱신할 범위

[문서 작성·유지 지침의 갱신 표](documentation_guide.md#변경과-함께-갱신할-범위)에 따라 해당 원본을 수정한다. 문서만 수정하면 링크·내용·diff를 확인하며 게임 빌드나 시각 검증은 추가하지 않는다.
