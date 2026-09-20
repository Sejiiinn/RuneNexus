# Flame 제거 전 기준 테스트 원본

`0241ef6`의 실행 원본을 역사 기록으로 보존한다. 현재 제품은 Godot이 전투와 전장을 담당하므로 이 파일은 실행 대상이 아니다. 단순 패키지 삭제 뒤 컴파일 오류를 숨기는 skip이 아니라, 제거된 구현의 검증을 해당 생산자로 옮겼다.

전투 회귀는 `godot/verify_legacy_combat_regressions.gd`, `verify_native_combat.gd`, `verify_native_enemy.gd`, `verify_native_wave_core.gd`, `verify_native_core_defense.gd`와 Flutter native 통합 검사에서 수행한다. 각 책임과 남는 Dart 검사: [대응표](../../analysis/flame_removal_20260920/legacy_test_coverage.md), [테스트 이관 목록](../../../tool/flame_removal_test_migration.md).

삭제된 2D Canvas/이미지 캐시/Flame 트리 복귀 테스트는 더 이상 제품 계약이 아니다. 실제 Godot effect/diamond/linked effect 검사와 Flutter DTO·ACK·generation·입력·저장 검사를 유지한다. 게임 상태와 전투가 없는 화면 이미지만 생성하던 과거 도구도 함께 보존한다.
