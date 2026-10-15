# Flame 테스트 이관 대응표

2026-09-20. 테스트 삭제·skip 여부는 이 표로 결정하지 않는다. 원본은
`/tmp/rune-flame-removal-reference`와 git 기준 소스에서 추출하고, Godot 담당의
fixture/headless 동등성 근거를 확인한 뒤 원본 테스트의 교체를 확정한다.

## 완료한 기계적 전환

- test/tool의 Flame 직접 import를 vector_math 직접 import로 변경.
- GameWidget → NativeGameHost, TapDown/UpEvent renderingTrace →
  onBoardTapDown/Up(Vector2).
- 적·포탑 collection 조회는 game.enemies/game.turrets 사용.
- gem_reward_targeting_test의 scenegraph render probe는 native 카메라에 전달하는
  zoom/offset 불변성 검사로 전환. 저장·보상·교체·입력 테스트는 유지.
- design의 현행 Android preview 두 진입점도 NativeGameHost로 변경.

## 기존 Dart 시뮬레이터 대신 Godot sequence fixture가 필요한 검사

| 원본 테스트 | 유지해야 하는 동작/대응 |
|---|---|
| slow_effect_test.dart | 독립 둔화 수명, 재적용, 저장 복원; verify_native_enemy_state.gd 및 JSON trace |
| enemy_path_cache_test.dart | 저장/resize 경로 복원은 plain 모델 테스트 유지; dt 이동과 lane/bob는 Godot 경로/시각 검사 |
| frost_critical_test.dart | 광역당 치명 한 번, 공유 snapshot, 둔화에 crit 미적용 |
| multiple_projectiles_test.dart | 수량+2, 전체탄50%, fan, 독립충돌, 후속 폭발/화상 단일 감폭; 순수 스탯 부분 유지 |
| projectile_chain_test.dart | 이동 swept collision, 거리한계, launch방향, 제외집합·다음대상 |
| global_attack_rules_test.dart | 연쇄/폭발 후속 처리; AttackRules 상수·순수 계산 부분 유지 |
| combat_resolver_calculation_test.dart | 적 상태를 사용하는 전체 실행은 Godot; attack_calculation JSON golden 대조 유지 |
| turret_trait_test.dart | registerDirectHitTraits/handleEnemyKilled/update 기반 중첩·cleanup·취약은 Godot; 구매제약·스탯·저장은 유지 |
| global_gem_area_rules_test.dart | 직접 실행/렌더 부분만 Godot; 범위·젬 장착/호환·스탯 테스트 유지 |
| game_balance_test.dart | live fire/receiveDamage/상태이상/children effect 검사를 fixture로 분리; 경제·진행·장착·UI·저장 섹션 유지 |
| run_progression_core_test.dart | 실제 core/도착 동작은 native_wave_core_timing.json과 native_wave_game_test; passive 수치·UI·저장 유지 |
| diamond_carrier_test.dart | effect component 존재 대신 native event/시각 검증; 확률경계·보상·저장·도착 무보상 유지 |

## 제거된 전장 renderer/scenegraph 검사

- enemy_renderer_test.dart, grid_component_test.dart: Godot 스테이지/적/상태 표시 검사.
- damage_number_image_cache_test.dart, impact_effect_component_test.dart:
  Godot damage/impact 표시·pool/lifecycle 검사.
- projectile_trail_test.dart: 삭제된 2D fallback 복귀의 할당검사는 더 이상 제품 계약이
  아님. Godot projectile 시각/수명 검사를 근거로 폐기 판단.
- battlefield_effects_test.dart, battlefield_effect_events_test.dart,
  battlefield_effect_integration_test.dart, stage1_projectile_visual_test.dart:
  Component 변환/되돌리기 부분은 폐기 대상, DTO 프로토콜·ACK·수명·stage 전환
  부분은 native transport/Godot 검사로 보존해야 한다.
- stage1/chapter_one/chapter_two_battlefield_presentation_test의 Canvas render 및
  processLifecycleEvents는 native frame/projection/input 검증으로 전환한다.

## 도구

- tool/gem_combat_render_test.dart는 과거 Dart combat+Canvas 이미지 생성기라
  NativeGameHost 명칭 변경만으로 재실행할 수 없다. headless Godot 결과·실게임
  native 캡처로 대체 필요.
- tool/gem_reward_game_render_test.dart는 HUD/보상 시안 목적을 유지하되 삭제된
  game.render 배경은 Godot 캡처를 사용해야 한다.
- design/stage1_3d/presentation_migration/*_lifecycle/measure_work.dart 다섯 개는
  과거 Flame callback 제거 전후 CPU 측정 원본이다. 현행 실행 도구로 간주하지
  말고 기록 보존 또는 Godot 프로파일 대체 여부를 별도 결정한다.

## 완료 기준

테스트 수 자체 대신 원본 assertion→새 fixture/테스트 매핑을 확인한다.
핵심 sequence는 dt별 hp/shield/armor/status/path/events 및 보상 exact-once를
비교하고, native protocol·save·HUD 테스트는 독립적으로 계속 실행한다.

## 완료: DTO 효과·표시 수명 전환

2026-09-20, 관련 10개 파일 53 tests 통과 (`/tmp/native-presentation-tests.log`).

- battlefield_effect_events_test: cancellation/generation, 오래된 ACK, bounded
  capacity, coalesced expiry, 사망효과 보존·만료의 기존 assertion 유지.
  제거된 DamageNumberComponent 운동 비교는 0241ef6의 discrete 식을 독립
  기준으로 고정하고 실제 queue retainedAge/retainedSquared 입력과 비교한다.
- battlefield_effects_test: game.emitBattlefieldEffect 직접 호출로 타일 좌표,
  색·문구·motion·피드백, charge 읽기의 무부작용, 6종 impact, 독립 lifetime,
  stale scene/sequence ACK, immutable linked geometry를 검증한다.
- native_selection_animation_test: attach 시 clock origin을 기록하는 plain
  포탑으로 배속·pause·transport flag·새 포탑 phase 계약 유지. update 없음.
- stage1/chapter1~3: 삭제된 mount/render/Component 사용 제거. 건설·저장·지도·
  투영·stage 교체·짧은 효과의 미확인 전송 유지. 적 status는 native snapshot을
  plain mirror에 적용하고 다음 native payload의 상태 불변성을 검사한다.
- godot_presentation_lifecycle_test 및 selection transport/DTO 검사는 그대로
  실행해 scene ownership, resize generation, 늦은 ACK, return lifecycle 유지.

Flutter frame의 enemies/turrets 및 enemy labels는 Godot의 authoritative
runtime에서 생성하므로 기존 Flutter actor 배열/2D background alpha assertion은
더 이상 제품 계약이 아니다. 테스트는 빈 actor 배열을 명시적으로 검사하고
건설 위치는 selection DTO, 적 정보는 nativeCombatState payload로 검증한다.
실제 actor rows/status labels와 화면 표시는 기존 Godot native runtime·scene
headless 검증 및 최종 인게임 확인의 책임이다. Flutter actor fallback을
테스트 통과용으로 되살리지 않았다. Stage16은 현재 미정의인 native frame
거부 경계만 유지하며 2D 전장이 존재한다는 주장은 제거했다.
