# 문서 지도

역할: 작업별 참조 진입점과 문서 갱신 규칙. 정리: 2026-09-09.
모든 문서를 읽는 목록이 아니다. 아래에서 작업에 맞는 기준 문서와 필요한 절만 선택한다.

## 작업별 진입점

| 작업 | 먼저 읽을 문서 | 필요한 경우 추가 참조 |
| --- | --- | --- |
| 프로젝트 이해 | [프로젝트 소개](../README.md), [구현 현황](implementation_status.md) | [백엔드 구조](backend_architecture.md) |
| 다음 작업 선택 | [남은 작업과 우선순위](next_work_priorities.md) | 해당 기능의 설계·현재 코드 |
| UI·시각 에셋 수정 | [DESIGNS.md](../DESIGNS.md) | 해당 화면의 design/ 기록, [인앱 검증](../.agents/in_app_test_guide.md) |
| Blender → Godot 이관 | [현행 제작·이관 기준](stage1_native_material_workflow.md) | [기존 원본·명령 요약](../design/stage1_3d/blender_workspace/README.md#수정부터-게임-반영까지); 과거 실험은 원인 조사 때만 참조 |
| 성능 개선·대량 표시·CPU/GPU 작업 분배 | [최적화 지침](performance_optimization_guidelines.md) | 해당 기능의 코드·측정 기록, [인앱 검증](../.agents/in_app_test_guide.md), [APK 용량 점검](android_apk_distribution.md#용량-점검) |
| 전투 수치·피해 효과 | [데미지 계층 규칙](damage_calculation_rules.md), [밸런스 기준](gameplay_balance_reference.md) | 해당 데이터 정의·테스트 |
| 코어·성장 | [코어 트리 현행 기준](core_passive_tree_implementation_plan.md) | [장기 코어 방향](nexus_core_design.md), [모듈](turret_module_design.md), [성장 후보](long_term_progression_direction.md) |
| 계정·인증·온라인 저장 | [백엔드 구조](backend_architecture.md) | [저장 동기화](multi_device_save_sync_design.md), [닉네임](account_nickname_policy.md) |
| 서버 경제 | [서버 권위 경제 계약](server_authoritative_economy_design.md) | [저장 동기화](multi_device_save_sync_design.md) |
| 배포·마이그레이션 | [배포 인계](deployment_status.md), [파이프라인 지도·개선안](deployment_pipeline.md) | [API 운영 절차](self_hosted_api_deployment.md), [APK 배포](android_apk_distribution.md), 해당 workflow |
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

- 강화·연구 밸런스 검토: [개편 전 감사](analysis/growth_balance_20260919.md). 최종 적용 규칙은 [밸런스 기준](gameplay_balance_reference.md#영구-업그레이드)을 따른다.

- 화염 지연 최적화: [입자 종료 처리·ARM64 에뮬레이터 합성 호환](analysis/godot_validation_20260915/flame_latency_optimization.md) — 그래픽 유지, 통합 갱신 개선과 실기기 미측정 범위.
- 선택 이관·화염 MultiMesh 후 FPS: [동일 조건 60초 재측정](analysis/selection_multimesh_fps_20260919/README.md) — 대포 45.24 / 화염 29.93 갱신/초. 화염 성능 개선 미확인, 실기기·GPU 시간 미측정.
- 화염 잔여 성능 조사: [중복 운동 계산 감소와 효과별 비용 분리](analysis/godot_validation_20260916/README.md) — 외형 유지, 작은 CPU 절감과 전체 FPS 개선 미확인 범위.

- Godot 전체 이관 전 60 FPS 검증: [Android 에뮬레이터 비교와 이관 승인 보류](analysis/godot_validation_20260915/README.md) — 현행 전장 에셋을 재사용한 최소 전투, 실제 표시 FPS, 검증 한계와 실기기 미측정 범위.

- 현행 Godot 성능 1차 진단: [2장 타일 작업량·프레임 전달 후보](analysis/godot_performance_20260913.md) — 현재 코드와 Android 에뮬레이터의 비전투 렌더 통계. 테스터 실기기 병목 확정과 구분한다.
- Godot 최적화 전후 비교: [중복 처리·타일 렌더 작업과 남은 지연](analysis/godot_optimization_20260913.md) — release 에뮬레이터 A/B. Godot 렌더 FPS 개선과 Flutter raster 악화·긴 스파이크를 함께 기록하며 전체 앱·실기기 개선 확정과 구분한다.

- 대포 폭발 수명 이관: [생성 이벤트와 기존 3D 폭발 연결](../design/stage1_3d/presentation_migration/blast_lifecycle/README.md) — 개별 수명·공용 시계·적용 확인·기존 GPU 표현 유지.
- 착탄 수명 이관: [non-blast 착탄 생성 이벤트](../design/stage1_3d/presentation_migration/impact_lifecycle/README.md) — 별도 지원 확인·2D 복원·반복 갱신/전송 감소.
- 정적 맵 전송 최적화: [적용 확인 후 맵 생략·복구](../design/stage1_3d/presentation_migration/map_transport/README.md) — 전송량·직렬화 CPU 측정, 맵 변경·재진입 계약.
- 표시 전용 효과 수명 이관: [피해 숫자·사망 파편·젬 장착](../design/stage1_3d/presentation_migration/native_lifecycle/README.md) — Godot 생성 이벤트·공용 전투 시계, Flame 갱신 및 반복 전송 감소.

- Flame 제거를 위한 전투 이관: [단위·의존 순서·검증 경계](godot_combat_migration_boundaries.md) — Android 전투·코어 방어 이관, Flame 런타임 제거와 저장·재시도 계약. 다른 플랫폼 연결은 미완료.
- 전장 표시 현행 구조: [Godot 표시 통합 구현과 검증](godot_presentation_migration_plan.md) — labels·selection·effects의 표시 소유권, 적용 확인·이벤트 큐 계약, 단계별 구현 상태와 남은 검증. [실제 적용·검증 기록](../design/stage1_3d/presentation_migration/README.md). 실기기 p95/p99·발열 성능은 미검증이다.

- 스테이지 1 질감·이펙트 개선: [밝기 보존·표면 재질·입체 효과 설계](stage1_surface_effects.md), [제작 원본과 적용 기록](../design/stage1_3d/surface_effects/README.md).

- 스테이지 1~10 3D 전장: [현행 제작·이관 기준](stage1_native_material_workflow.md) — 원본·내장 PBR·공용 반사와 기존 실행 경로, [본게임 연결·실행](stage1_3d_preview.md), [챕터 2 균열 타일·환경 3종](../design/chapter2_3d/README.md), [Godot 연결 테스트 APK](../design/stage1_3d/godot_preview/README.md), [Blender 현행 원본·작업 허브](../design/stage1_3d/blender_workspace/README.md), [S26 Ultra APK 성능 분석·개선 후보](analysis/s26_ultra_cannon_performance_20260911.md).
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
