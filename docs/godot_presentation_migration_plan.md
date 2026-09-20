# Godot 전장 표시와 앱 연결

역할: 현행 표시 책임·전송·복구 계약. 갱신: 2026-09-20.

Android 스테이지 1~15는 Godot이 전장과 실제 전투를 담당한다. Flame 런타임과 2D fallback은 제거했다. 다른 플랫폼의 Godot 연결은 미완료이며 지원 범위 결정이 남아 있다. [전투 책임·저장 경계](godot_combat_migration_boundaries.md)를 함께 따른다.

## 표시 책임

| 표시 | 생산·표시 책임 |
| --- | --- |
| 지형·포탈·코어·적·포탑·탄환·착탄 | Godot 전투 상태와 기존 3D 장면·효과 |
| 적 내구도·상태·번개 충전·연쇄·코어 스킬·HP 변화 | Godot이 실제 전투 상태에서 생성 |
| 사거리·건설 미리보기·선택·젬 교체 대상 | Flutter의 선택 DTO를 Godot 카메라로 표시 |
| 포탑 레벨·레벨 오라·젬 고리 | Godot 표시·시계, 앱의 레벨/젬 설정 |
| 앱이 지급한 다이아·젬 장착·앱 안내 숫자 | Flutter 생성 이벤트를 Godot에서 표시 |
| 로비·HUD·보상 카드·패널·화면 전체 피격 경고 | Flutter |

EnemyComponent와 TurretComponent는 앱의 저장·설정·HUD 모델만 남긴다. 피해 숫자·사망·탄환 등 Flame 표시 컴포넌트는 없다. 실제 적·포탑·탄환 좌표를 표시 프레임으로 계속 보내지 않으며 Godot이 전투 상태에서 장면을 갱신한다. 승인된 GLB·재질·VFX·풀과 GPU 표현은 유지한다.

## 준비·입력·복구

[NativeGameHost](../lib/ui/hud/native_game_host.dart)는 배치·터치·화면 경고를 담당하고 [GodotBattlefieldView](../lib/ui/hud/godot_battlefield_view.dart)는 Android 장면과 전송을 연결한다. 준비 완료 신호만으로 전투를 진행하지 않고 전투 프로토콜 1과 초기 ACK를 확인한다. 표시 계약 버전 2의 epoch·viewport revision·크기·sequence를 검증한 투영만 건설/선택 입력에 사용한다.

이전 화면 응답·리사이즈 전 투영·미제출 sequence는 거절한다. Godot 소수 직렬화 오차만 1e-6 미만으로 허용한다. 같은 sequence의 새 카메라 투영은 허용한다. 장면 초기화는 최신 표시 프레임에 덮이지 않으며 소유권 변경 때 큐·투영·캐시를 정리한다.

오류·미지원 전투 버전은 전투 정지와 재시도/메인 화면을 표시한다. 실패한 화면의 응답이 새 화면을 덮지 않게 하며 마지막 확정 저장 상태로 새 epoch를 시작한다. 2D로 자동 복귀하지 않는다.

## 반복 전송과 시계

정적 맵은 mapRevision의 실제 적용 확인 전까지 재전송하고 이후 생략한다. 새 장면·맵 변경·mapRequired 복구 요청에는 전체 맵을 보낸다. 복구 메타데이터만으로 로딩이나 표시 적용을 인정하지 않는다.

선택 상태도 revision ACK 전까지 재전송하고 동일 상태의 반복 전송을 생략한다. 선택·레벨·젬·사거리·viewport 변경에는 revision을 갱신한다. 고리와 레벨 오라의 위상은 Godot에서 계산하며 선택 변경·새 포탑·재진입 상태를 보존한다.

앱 생성 효과는 유한 이벤트 큐로 전송하고 실제 적용 sequence를 확인한 뒤 반복을 끝낸다. 정지·보상·로딩에는 전투 효과 시계가 멈추고 배속·코어 파괴 감속을 따른다. 카메라 시간은 별도로 유지한다. 다이아 획득은 기존 상승 속도를 유지한다. 전투가 생성하는 명중·사망·코어 효과는 Godot 내부에서 생성한다.

## 검증 기록

[이번 제거 검증](analysis/flame_removal_20260920/README.md), [기존 검사 대응표](analysis/flame_removal_20260920/legacy_test_coverage.md), [단계별 표시 이관 기록](archive/godot_presentation_before_flame_removal_20260920.md)을 참고한다. 과거 기록의 Flame fallback 설명은 당시 구현이며 현재 지원 경로가 아니다. 전체 FPS·p95/p99·발열 개선은 동일 조건 측정 없이 주장하지 않는다.
