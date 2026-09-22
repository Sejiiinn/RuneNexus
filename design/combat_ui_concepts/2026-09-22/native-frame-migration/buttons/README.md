# 전투 버튼 잔여 그라데이션 정리

2026-09-22. 전투에 남은 `GameButton.appearance` 호출을 조사해 두 곳만 바꿨다.

- `battle_theme.gd`: `create(combat_native := false)`의 명시적 전투 경로는 승인된 `CombatSecondary` Theme의 StyleBoxTexture 상태를 기본 Button 스타일로 재사용한다. `create()` 기본 호출은 그대로 기존 gradient를 반환해 이 테마를 공유하는 로비 외형을 보존한다. 전투 HUD의 호출은 `BattleTheme.create(true)`여야 한다(해당 파일 담당자가 통합).
- `battle_rewards.gd`: 파편 대안 버튼에 남아 있던 수동 gradient 상태를 `Components.apply`로 연결했다. 승인된 녹색 normal/선택 bar와 젬 속성별 카드·배경은 보존한다. hover/pressed/disabled는 승인 금속 버튼 상태를 사용한다.
- `combat_component_theme.gd`, `game_button.gd`, 로비, quiet 단색 버튼·체력바·선은 변경하지 않았다. 새 에셋·manifest 변경이 없다.

검증: 기존 프로젝트를 APFS 독립 복사한 `build/godot/frame-buttons-review`, 사용자 경로 `RuneNexus-Frame-Buttons-Review`로 격리했다. 공용 prepare/editor는 실행하지 않았다. 실제 Godot 4.7.2 Metal Forward Mobile에서 320/440 화면을 확인했다. [하네스](capture.gd), [실행 로그](capture.log).

- [320 normal](reward-normal-320.png), [320 hover](reward-hover-320.png), [320 선택](reward-selected-320.png), [440 hover](reward-hover-440.png): 녹색 파편 상태·원래 카드 보존, hover 금속 프레임·텍스트 잘림 없음.
- [320 스테이지 메뉴](stage-menu-320.png), [440 메뉴](stage-menu-440.png): 승인 모달·역할별 금속 버튼 유지.
- 실제 viewport 마우스 press/release로 파편 선택→파편 받기를 수행하고 보유 파편 증가·보상 phase 종료를 확인했다. 테마 경계도 `create()`의 GradientBox / `create(true)`의 StyleBoxTexture로 검사했다.
- [보상 회귀](verify_battle_rewards.gd.log), [HUD 회귀](verify_battle_hud.gd.log) PASS. 실제 실행과 회귀 로그 오류·경고 없음.

분담 검증 PASS. 최종 통합 화면은 부모 담당이며 이 기록은 다른 분담 프레임 변경의 통합 검증을 대신하지 않는다. Android 실기기 미검증, APK 빌드 없음.
