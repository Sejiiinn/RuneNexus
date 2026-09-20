# Flame 전투 테스트 대체 대응표

2026-09-20. 기대값은 삭제 전 Dart 테스트의 고정 assertions 및 기존 `test/fixtures/turret_stat_calculation.json`에서 가져왔다. 새 Godot 계산 결과를 기대값으로 생성하지 않았다. 원본은 Git `0241ef6:test/<파일>`에서 재확인할 수 있다.

`godot/verify_legacy_combat_regressions.gd`는 **7,346 checks PASS**. 이 수에는 스탯 fixture 각 필드 검사가 포함되며 7,346개 독립 시나리오나 전 범위 동등성을 의미하지 않는다.

| 기존 테스트 | 기존 Godot 검사 | 추가 Godot 검사 및 기대값 근거 |
|---|---|---|
| slow_effect_test.dart | native_enemy_state의 slow 갱신/만료 | `_slow`: 강약 적용 순서, 개별 만료, 약한 재적용이 강한 지속시간을 늘리지 않음, 저장 왕복, 잘못된 배율 무시 |
| enemy_path_cache_test.dart | native_enemy_state 이동/저장 | `_path`: 코너 19.2, fade 48×.55, 오프셋 5.76, 중복/퇴화 경로, 리사이즈 상대거리 보존, 무효 교체, 수직 차선 |
| frost_critical_test.dart | native runtime 냉기 피해 smoke | `_frost`: 치명0/1의 HP 996/993.4, 둔화 .8/1초 독립, 범위 밖 제외, 대상 수와 무관한 1회 RNG, 발사 snapshot 1.8 재굴림 방지 |
| multiple_projectiles_test.dart | native runtime fan smoke | `_multi`: 고정 .5 피해/±10도, 3·5발 동일 큰 적 HP850/750, 공격 snapshot 공유/명중이력 독립, 3개 연쇄 HP850/925/925, 생산자 변경 불변, magic 치명+폭발+연쇄+화상 HP/DPS 원본 숫자 |
| projectile_chain_test.dart | native segment collision | `_projectiles`: 목록순서가 아닌 최초 몸체, 원둘레 충돌점, 제외 집합 복사, 중간 적 충돌, 최대20 이동, 비유도/이동한 대상, 110 이내 최근접 생존 후보 |
| global_attack_rules_test.dart | native runtime 6종 smoke | `_global_attacks`: 중복 폭발 피해 배열, cannon 치명 직격/광역, fire chain 화상, arrow 2점프/불변 snapshot, lightning 광역 피해 대상도 연쇄 후보 유지 |
| turret_trait_test.dart | 고정 stat fixtures | `_traits`: overheat1.02/1.04/1.3/reset, suppressive 5회 .2/2초, compressed1.35, fracture HP970/985 공격 한정, frostCrack HP996→991.4, exposed .15, finishing 합산내구도, cleanup3초, focused1.3, lightning recovery. 정적 수치는 `_area` 고정 fixtures 전필드 대조 |
| global_gem_area_rules_test.dart | stat fixtures/range projection | `_area`: 34×1.25=42.5, cannon42×1.45=60.9, frost76→95/광역0/안팎 판정, chain 타입별4/2/0 |

전투 판정과 별개인 trait 레벨3/7 잠금·구매·선택 호환성, 잘못된 저장 선택 제거, 보석 장착 자격·반환 인벤토리는 Dart 테스트에 남긴다. Flutter Canvas 전용 range-ring 검사는 폐기된 renderer를 실행하지 않으며 Godot selection/range projection 검사가 표시 책임을 맡는다. 냉기 테스트의 피해량·공유 치명은 검사하지만 원본 feedback 문자열 모든 조합의 전수 동등성까지 주장하지 않는다.

## 보상 효과

`verify_diamond_event.gd`: 새 diamond 이벤트 수신, 실제 아이콘 리소스, `+3` 텍스트, 24×scale px/sec 상승, 정확한1.05초 만료, pause/retry 중복 방지, 입력 DTO 불변, 지연전달 1회 표시, scene generation 취소 PASS. `verify_battlefield_effects.gd`의 기존 변환·camera·아이콘·전체 효과 검사도 PASS.

## 재현

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path godot --script verify_legacy_combat_regressions.gd
# prepare_godot_project 경로로 ui 리소스를 준비/import한 프로젝트에서:
Godot --headless --path <prepared-project> --script verify_diamond_event.gd
Godot --headless --path <prepared-project> --script verify_battlefield_effects.gd
```

이번 UI 검사는 빌드 입력과 격리된 `/tmp/rune-diamond-native-test`에 현재 ui 소스와 실제 `assets/images/stage1_3d/ui/{Roboto-VF.ttf,death_silhouettes.png}`, `assets/fonts/NotoSansKR-VF.ttf`, `assets/images/diamond_currency.png`를 복사/import하여 실행했다. 저장소 `godot/`에는 패킹용 리소스가 없으므로 그 경로로 UI 검사를 바로 실행하면 리소스 부재가 발생한다.

로그: `legacy-combat-regressions.log`, `diamond-event.log`, `battlefield-effects.log` (이 문서와 같은 디렉터리). 실제 화면/빌드는 부모 통합 담당이며 이 작업에서 반복하지 않았다.

## Dart 잔존 책임 검사 전환

`test/helpers/turret_stat_fixture.dart`는 제거된 hit/kill 실행으로 cleanup을 만들지 않고 `applyNativeCombatState({'cleanup':3})`로 미러 입력을 받는다. `turret_stat_calculation_test.dart`의 만료 검사 역시 native cleanup=0 응답을 적용하고 발사 snapshot 불변을 유지한다. 실제3초 만료는 Godot `_traits`가 검사한다.

`turret_trait_test.dart`는 선택 레벨·잠금·지원 목록·스탯·저장복원을 유지하고 native hit/timer 블록을 위 대응표로 옮겼다. `global_gem_area_rules_test.dart`는 Canvas render 호출만 제거했으며 실제 보석 장착 제한과 두 번 복원시 단1개 반환 검사를 유지한다.

`combat_resolver_calculation_test.dart`는 삭제된 CombatResolver 대신 domain AttackCalculation을 사용한다. 독립된 기존 저항 곱셈 oracle과6종 실제 발사 snapshot을 Godot 계산 실행과 대조한다. 상태 미러 초기 취약값은 native 저장 snapshot으로 주입하고, 실제 상태 적용은 Godot `_frost`/`_multi`/`_traits`가 담당한다. 기존318개 고정 스탯fixture도 Dart/Godot 양쪽 대조를 유지한다.

관련4개 테스트 파일363 tests PASS. 위4개+helper 대상 Dart analyze: No issues found. 로그 `dart-replacement-tests.log`, `dart-replacement-analysis.log`.


## game_balance 전투 블록 추가

`_balance`가 원본 타깃 우선순위5종, 사거리 몸체±.1 경계, armor54의 실제피해2.324572/잔여51.675428, 관통 overflow, poison2스택6피해/최대4스택, ignition burst, 직접/DoT 처치 화상 전이, 실제HP만 통계귀속, 환급→재건설 귀속0을 검사한다. 번개 .069/.002/.07 순차지연 및 .299/.002 충전, currentAmplification 후속만 .7, 원본 별도 광역 배열 HP976/988/988/994도 검사한다. 기존 `_traits`의 lightningRecovery는 미사용2회 분모1.3·경과시간 차감·현재 cooldown보다 늘리지 않음을 검사한다.

원본 2D visual bob의 `sin(time*3.7)*2.1` 화면 이동은 현행 Godot3D actor 자체 애니메이션으로 대체된 표시 책임이며 숫자 동등성을 주장하지 않는다. `_path`는 전투좌표·차선5.76·수직방향 차선만 확인한다. 이 차이는 production 변경 없이 통합 담당에게 알렸다.

## game_balance 삭제28블록 이름별 연결

원본 보관은 `/tmp/rune-flame-removal-reference/game_balance_archived_blocks.json`이며 장기근거는 Git `0241ef6:test/game_balance_test.dart`이다. mixed 저장/경제 검사는 Dart에 남겼다.

| 삭제된 테스트 이름 | 대체 검사 |
|---|---|
| turret refund stops later burn credit to a rebuilt turret | _balance: refund/rebuild attribution0 |
| projectile hit keeps launch gem profile after in-combat replacement | _multi / _global_attacks: immutable launch snapshot |
| enemy visual bob is suppressed while moving vertically | _path: vertical lane offset; 원본2D bob 수치 제외 |
| enemy lane offset changes only visual path position | _path: lane5.76/logical position; 원본2D sin bob 제외 |
| poison stacks as long low damage over time | _balance: poison2×3=6, cap4 |
| burn damage is credited to its source turret | _balance: actual10 damage source stat |
| chain ignition transfers when direct fire damage kills a burning enemy | _balance: direct kill transfers new stronger burn |
| chain ignition transfers a killing burn to a nearby enemy | _balance: lethal DoT10→target6 |
| ignition burst deals direct damage against an existing source burn | _balance: existing10DPS×2×.3 burst plus fixture16 |
| chain hit from fire turret applies scaled burn | _multi / _global_attacks: chain .5 scaled burn |
| explosion gem splashes initial and subsequent lightning hits | _balance 마지막4위치 HP976/988/988/994 |
| lightning recovery shortens the current reload from unused jumps | _traits: unused2 /1.3, elapsed/min constraint |
| current amplification only improves follow-up lightning damage | _balance: initial24 unchanged/followup24×.7 |
| chain lightning charges before the first strike | _balance: .299/.002 charge |
| chain lightning hits sequential targets with delayed jumps | _balance: .069/.002/.07 and attributed24+24 |
| sniper rejects chain gem and does not create follow-up attacks | _area: sniper chainCount0; Dart global_gem_area eligibility 유지 |
| sniper instant hit applies critical direct damage without projectile | verify_native_combat_runtime._exact_checks: sniper aim completed critical instantHP |
| frost turret damages and slows enemies in its centered area | _frost / _area: centered HP/slow/inside-outside |
| burn damage uses only the strongest active burn instance | verify_native_enemy_state: strongest burn independently expires |
| shield overflow spills into armor and broken shield does not regen | verify_native_enemy_state: shield break, regen prevention, durability overflow |
| armor piercing ignores reduction without bypassing armor layer | _balance: armor piercing7 then50 overflowHP93 |
| armor 54 reduces machine gun base damage before hp | _balance: armor54 damage2.324572/remaining51.675428 |
| armor mitigates damage before hp and weakens as it breaks | verify_native_enemy_state: mitigation/overflow/armor bypass |
| enemy damage returns actual hp loss | _balance: lethal sourceHP5 yields credited5; native_enemy_state actualDamage |
| burn deals short duration damage over time | verify_native_enemy_state: short burn clips own lifetime |
| turret range check includes rough enemy body radius | _balance: body radius inner/outer .1 |
| turret target priority selects the configured combat target | _balance: five priorities exact target IDs |
| enemy movement speed scales with board tile size | verify_native_enemy_state: movement boardDistanceScale; _path normalized resize |

## Flutter 기본 검사 연결

`test/godot_native_regression_test.dart`가 5개 source-only Godot 스크립트(legacy, combat runtime, wave/core, defense, enemy state)를 실행한다. `GODOT_BIN` 또는 기존 macOS 번들 실행파일을 사용하며 없으면 명시적 skip. 임시 프로젝트에 현재 source와 고정fixtures만 복사하여 빌드/editor 캐시를 공유하지 않는다. 각 프로세스20초 제한 후 kill, 종료코드0, PASS 또는 enemy JSON failures빈배열, parser/runtime ERROR 없음 모두 확인한다. Flutter 테스트 자체30초 제한.
