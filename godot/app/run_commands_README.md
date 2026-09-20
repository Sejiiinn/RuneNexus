# Godot 런·성장 명령

역할: 독립 세션의 메모리 상태·명령 계약. 2026-09-21. 기존 Android Flutter 앱의 로비·저장·서버 경제를 대체한 것으로 해석하지 않는다.

`growth_rules.gd`가 기존 progression 및 장착 모듈 입력으로 비용·스탯·코어/방어 설정을 계산한다. 영구 강화(룬), 연구 시작·취소·시간완료, 코어 배분/장착, 소유 모듈 장착을 처리한다. 다이아 구매·모듈 뽑기·분해·서버 재화 변경은 거절한다.

`run_commands.gd`는 상태를 복사해 명령을 적용하고 `{ok,state,commands,error}`를 반환한다. 실패 시 입력 상태·재고·골드는 바뀌지 않는다. 호출자는 성공 상태를 채택하고 `commands`를 기존 NativeCombatRuntime으로 보낸다. 강화·장착 갱신은 진행 중인 사격 쿨다운/조준/피해 기록을 보존한다. 특성 선택 때만 원래 Dart가 초기화하던 연속 공격 상태를 `resetTraitState`로 초기화한다.

- `initial_state(progression,stage)`는 실제 시작 골드·조각을 적용한다. stage는 0부터 시작한다.
- `apply(state,{kind:...,id:...})`의 kind는 build/level/link/sell/equipGem/removeGem/primaryTrait/secondaryTrait/targetPriority/runUpgrade/purchaseGemChoice/chooseRewardGem/chooseRewardShards다. build는 type/x/y, 슬롯은 0부터 시작하는 `slot`, 선택 종류는 `type`을 받는다.
- `quotes(state,id)`, `build_cost(state,type)`, `run_upgrade_quote(state,type)`로 비용을 표시한다. `refresh(state)`는 일반 성장 변화 후 전투 설정을 갱신한다.
- `award_kill(state,enemy)`는 실제 적 정의의 골드·보스 보너스와 소수 골드 지갑을 적용한다. 다이아는 서버 잔액에 지급하지 않고 `pendingEconomyDiamonds`에 누적한다.
- `complete_wave(state,waveId)`는 골드·조각·5웨이브 젬 선택 및 마지막 성공 단계를 처리한다. 선택지가 뜬 동안 phase=reward로 전투를 멈춘다. 다음 웨이브 설정은 현재 콘텐츠 로더를 사용한다.
- `growth_rules.execute(progression,command)`는 로컬 성장 명령을 처리한다. 저장·네트워크 I/O를 수행하지 않는다. 연구 시간은 명시적인 `nowMillis`, 성장 효과는 현재 코어 배분·장착·런 업그레이드·전장 종류 수로 계산한다.

`session/run_session.gd`는 scene epoch와 이벤트 ID로 중복 반영을 막는다. 이벤트에 대응하는 메모리 상태를 반영한 뒤에만 ACK한다. 새 저장 경로는 아직 제공하지 않으며 `session_checkpoint.gd`는 실제 콘텐츠 세션의 Save/Load를 계속 거절한다. 기존 고정 fixture의 저장 재시작 검사도 유지한다.

단일 원본은 기존 Dart 정의와 실제 API다. 실행용 `content/growth_content.json` 및 실제 상태 결과 fixture의 생성 명령은 [추출 안내](../../tool/content/README.md)를 따른다. Godot 실행에는 Dart가 필요 없고 데이터 재생성·Dart 비교에는 Flutter SDK가 남아 있다.

검증: `verify_run_commands.gd`, `verify_growth_rules.gd`는 저장소 `godot/` 경로에서 실행한다. 실제 장면 통합은 자산이 준비된 `build/godot/project`에서 `verify_run_session.gd`를 실행한다. 자세한 결과·제한은 [검증 기록](../../docs/analysis/godot_run_growth_20260921/README.md)을 따른다.
