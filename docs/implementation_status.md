# Rune Nexus 구현 현황

역할: 기능을 찾기 위한 구현 범위 요약과 계약 안내. Godot 전환 상태는 [실행 로드맵](godot_unified_app_roadmap.md#3-단계와-의존-관계), 공개 버전·운영 검증은 [배포 인계](deployment_status.md), 기술적 마무리 조건은 [구현·검증 체크리스트](implementation_checklist.md)가 원본이다. 사용자의 큰 개발 계획은 [TODO](TODO.md)에 별도로 둔다.

구현 요약 기준: 2026-09-21. 문서 역할·TODO 연결 정리: 2026-10-10 KST. 아래는 기존 구현 기록의 요약이며 이번 문서 정리에서 기능 전체를 다시 실행·검증하지 않았다. 과거 수치·세부 항목·테스트 건수는 [기존 상세 목록](archive/implementation_status_20260921.md)에 보존한다. 수치·API·동작 변경 전 해당 계약과 코드를 확인한다.

## Godot 전환 현황

실행 경로별 책임과 단계별 완료·미완료는 [Godot 전환 상태](godot_unified_app_roadmap.md#3-단계와-의존-관계)를 따른다. Godot 단일 앱이 기본 실행 경로이며 `--session`은 개발 검증용이다. Android 최종 검증과 공개 배포는 별도로 판정한다.

## 최근 반영된 기능

날짜순 변경 이력을 이 문서에 누적하지 않는다. 디자인 변경은 [디자인 기준](../DESIGNS.md), 닉네임은 [정책](account_nickname_policy.md), 리더보드는 [현행 규칙](leaderboard_design.md), 배포별 변경은 [배포 인계](deployment_status.md)를 따른다.

## 요약

기존 앱에는 전투·젬/링크·런 성장, 스테이지 선택/해금, 룬 성장·연구·코어·모듈, 저장/복구와 계정 서비스가 구현되어 있다. 이 목록은 모든 플랫폼의 제품 동등성이나 실제 계정 E2E 완료 판정이 아니다. 엔진 전환 완료 여부는 로드맵에서 별도로 판단한다.

## 실행 및 검증 상태

[배포 인계](deployment_status.md)의 버전별 결과와 로드맵 각 단계의 검증 기록을 따른다. 이전 전체 테스트 통과 건수를 현재 검증 결과로 재사용하지 않는다. 2026-09-05 인증 세션 검증 이력은 [보관본](archive/implementation_status_20260921.md#실행-및-검증-상태)에 있다. 현행 Godot 검사·앱 빌드의 결과와 미확인 항목은 로드맵에서 연결한 전환 검증 기록을 따른다.

## 구현된 항목

아래 소제목은 기존 링크를 유지하기 위한 기능별 진입점이다. 실제 상태를 바꿀 때 상세 계약과 검증 근거를 먼저 갱신한다.

### 앱/화면 구조

로비·성장 메뉴·전투 HUD·결과 화면이 있다. 화면별 외형·조작 기준은 [DESIGNS](../DESIGNS.md), Godot 대응 범위는 [UI 복원 기준](godot_ui_restoration_baseline.md)을 따른다.

### 계정/인증/온라인 저장 기반

Go API·PostgreSQL의 Google 인증·영속 세션·온라인 저장·서버 권위 경제와 Godot 클라이언트가 구현되어 있다. 계정별 저장 격리·writer generation·exact Outbox·원격 우선 복구는 [저장 계약](multi_device_save_sync_design.md), 재화·모듈·보상 명령은 [경제 계약](server_authoritative_economy_design.md), 구성은 [백엔드](backend_architecture.md)를 따른다. 서비스 통합 검증과 공개 E2E는 로드맵의 상태를 따른다.

### 스테이지/진행

챕터·스테이지별 웨이브, 클리어·다음 스테이지 해금·기록·보상 기반이 있다. 세부 콘텐츠·해금·보상 수치는 [밸런스 참조](gameplay_balance_reference.md)를 따른다.

### 전투 기본 루프

맵·경로 이동, 포탑 공격, 내구도 계위, 웨이브·코어·종료 판정을 구현했다. 엔진 책임은 [전투 경계](godot_combat_migration_boundaries.md), 피해·저항 계산은 [데미지 규칙](damage_calculation_rules.md), 코어는 [현행 트리 참조](core_passive_tree_implementation_plan.md)를 따른다.

### 콘텐츠 데이터

파랑·주황 전송 포탈 기믹의 선택적 연결·이동·저장 계약과 맵 배치 상태는 [콘텐츠 계약](../godot/content/README.md#선택적-전송-기믹)을 따른다. 모델·효과의 제작 원본과 게임 이관 확인 범위는 [포탈 제작 안내](../design/teleport_device_concepts/2026-09-30/production/README.md)에 둔다.

포탑·적·젬·웨이브의 종류와 수치는 [밸런스 참조](gameplay_balance_reference.md)에 둔다. 독립 Godot 콘텐츠의 원본·생성물 관계는 [콘텐츠 이관 기록](analysis/godot_content_migration_20260921/README.md)을 따른다.

### 젬/포탑 성장

젬 보상·인벤토리·장착/교체, 링크 확장, 포탑 레벨·공격 명령·특성이 있다. 수치는 [밸런스 참조](gameplay_balance_reference.md), 특성 계약은 [젬 파편·특성](gem_shard_trait_design.md), UI 기준은 [DESIGNS](../DESIGNS.md)를 따른다.

### 젬 효과 세부

효과·태그 제한·해금은 [밸런스 참조](gameplay_balance_reference.md), 피해 적용 순서는 [데미지 규칙](damage_calculation_rules.md)에서 관리한다.

### 환불

포탑 환불·장착 젬 반환·확인 흐름이 있다. 환급률과 자원별 반환 규칙은 [밸런스 참조](gameplay_balance_reference.md)와 [특성 설계](gem_shard_trait_design.md)를 따른다.

### 저장/복구

v2 로컬 저장, legacy v1 이전, guest/account 슬롯, 원자적 교체·백업과 체크포인트 복구가 있다. 로컬·원격 계약은 [저장 설계](multi_device_save_sync_design.md), Godot codec·저장소 계약은 [앱 모듈](../godot/app/README.md)을 따른다. 기존 설치 데이터 인계의 완료 여부는 전환 로드맵에서 관리한다.

### 영구 성장

룬 기반 강화·시간 기반 연구·코어 투자와 저장이 있다. 현재 수치·조건은 [밸런스 참조](gameplay_balance_reference.md)와 [코어 참조](core_passive_tree_implementation_plan.md)를 따른다.

### 포탑 모듈

선택 포탑 대상 뽑기, 부위별 장착/해제·분해·인벤토리가 있다. 세부 규칙은 [모듈 설계](turret_module_design.md), 서버 확정 범위는 [경제 계약](server_authoritative_economy_design.md)을 따른다.

### 런 한정 업그레이드

런별 피해·골드 관련 강화와 저장이 있다. 효과·비용·해금은 [밸런스 참조](gameplay_balance_reference.md)에서 관리한다.

### 결과/메뉴

성공/실패 결과, 기록·획득 보상, 재도전·스테이지 선택·다음 스테이지 행동이 있다. 화면 기준은 [DESIGNS](../DESIGNS.md), Godot 조작 동등성은 [복원 기준](godot_ui_restoration_baseline.md)을 따른다.

### 테스트

기능별 자동 검사와 플랫폼 검증은 해당 변경·배포 기록에 결과·환경·미검증 범위를 남긴다. 실행 방법은 [인앱 검증](../.agents/in_app_test_guide.md), 과거 테스트 항목은 [보관본](archive/implementation_status_20260921.md#테스트)을 참고한다.

## 구현과 남은 검증의 구분

[단계별 상태](godot_unified_app_roadmap.md#3-단계와-의존-관계)는 Godot 구현/검증 사실을, [구현·검증 체크리스트](implementation_checklist.md)는 근거가 있는 기술적 미완료 조건을 관리한다. 실제 기기·계정 검증이 남았다는 이유로 이미 구현한 기능을 미구현으로 표시하지 않는다. 과거의 PGS·identity·신규 성장 제안은 채택 여부를 확인하지 않고 다음 작업으로 올리지 않는다.

## 남은 작업의 우선순위

사용자가 앞으로 하고 싶은 큰 작업과 그 우선순위는 [개발 계획 TODO](TODO.md)에, 구현 담당자가 마무리할 버그·검증·배포 조건은 [구현·검증 체크리스트](implementation_checklist.md)에 둔다. 최신 사용자 요청이 우선하며 기술적 필요를 사용자의 개발 계획으로 대신 정하지 않는다.
