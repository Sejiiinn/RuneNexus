# 전투 HUD 프레임의 표준 렌더 전환

2026-09-22. 시작·재개 버튼, 하단 포탑 선택/탭 도크, 자동 시작 방식 팝업의 수동 이미지 렌더를 표준 `StyleBoxTexture`와 `Theme` 변형으로 전환했다. 기존 금속 원본·화면 배치·도크 가장자리 접합을 유지한다.

## 변경

- `HudChrome.install()`이 `HudPrimary`, `HudDock`, `HudTabs`, `HudPopup` 변형을 등록하고 해당 컨트롤에 연결한다. 시작·재개의 normal/hover/pressed/disabled/focus 상태와 기존 색조를 유지한다.
- 시작 버튼과 팝업은 별도 담당이 `StyleBoxTexture` 파생으로 바꾼 공용 `lobby_frame.gd`를 사용한다. 시작 버튼의 원본 `lobby_primary_button.png`는 3배 논리 크기 300×56, 모서리 12/14px, 콘텐츠 좌우12/상하0을 그대로 유지한다. 팝업은 panel 원본·14px 모서리·10px 콘텐츠 여백을 유지한다.
- 도크는 원본 `panel_frame.png`의 내부와 상단 금속 레일을 합친 **단일 완성 PNG** `ui/hud/dock_panel.png`를 사용한다. `StyleBoxTexture`의 상단 고정 마진4px, 좌우·하단0, 선택부 여백5/탭 여백4로 화면 가장자리에 이어진다. 런타임 수동 그리기나 PNG 조각 조립은 없다.
- 기존 `quiet` 단색 스타일, ResourceHUD, 포탑 전용 액션은 유지한다. 전투 기본 테마는 버튼 담당이 제공한 `BattleTheme.create(true)`를 사용한다. 전투·저장 계약은 변경하지 않았다.

## 도크 제작

원본은 `assets/images/ui/components/panel_frame.png`이며 변경하지 않았다. 내부 `(56,56,1392,528)`을 348×132로 축소하고 위에 원본 상단 레일을 4px 높이로 합쳤다. 단순 면적 축소에서 발생한 밝기 차이를 확인한 뒤 기존 GPU의 56→4px 선형 샘플 중심 y=7/21/35/49에 해당하는 두 행을 한 행으로 축소했다. 최종 이미지는 네 레일 행과 내부가 합쳐진 PNG 한 장이다.

[편집 원본 XCF](production/dock-panel.xcf), [GIMP 재현 스크립트](production/prepare_dock.py), [원본 좌표·에셋 해시](production/dock.json). 현재 세션에 호출 가능한 GIMP MCP 도구가 없고 기존 연결 복구 실패 기록이 있어, 기존 GUI·미저장 문서를 보존한 별도 GIMP Python batch를 사용했다. [제작 로그](production/gimp.log).

## 검증

Godot 4.7.2 macOS Metal Forward Mobile, Apple M4. 독립 프로젝트 `build/godot/frame-hud-review`와 사용자 저장 `RuneNexus-Frame-HUD-review`에서 실행했다. 공용 프로젝트 prepare와 편집기 조작은 하지 않았다. [환경·소스/에셋 해시](verification.json), [하네스](capture.gd).

- 320: [이전](before-picker-320.png) → [최종](after-picker-320.png), [이전 팝업](before-popup-320.png) → [최종 팝업](after-popup-320.png).
- 440: [이전](before-picker-440.png) → [최종](after-picker-440.png), [이전 팝업](before-popup-440.png) → [최종 팝업](after-popup-440.png), [이전 재개](before-resume-440.png) → [최종 재개](after-resume-440.png).
- 수정 전후 도크 높이170px, 좌우 화면 접합, 시작 버튼76×36과 위치가 동일하다. 시작 버튼 영역은 두 폭 모두 픽셀 차이0. 최종 도크 전체 채널 평균 차이는 약0.12/255, 상단 레일은 약0.17/255이며 최대 차이는320에서2/255, 440에서3/255다. 구조·배치·금속 형태를 실제 화면에서 확인했다. [동일 영역 픽셀 비교](pixel-comparison.json), [이전 로그](before.log), [최종 로그](after.log).
- [전용 native 구조 검사 PASS](native-test.log): 시작/팝업/도크의 StyleBoxTexture, 고정 모서리·별도 콘텐츠 여백, 버튼 상태색, Theme 연결, 320/440 도크·시작 버튼 크기와 가장자리 접합. 진입점 `godot/verify_hud_native_frames.gd`.
- [기존 HUD 회귀 PASS](hud-test.log): 건설·강화·특성·소켓·장착·런 강화·보상 및 좁은 화면 검사. 구조 검사가 통과한 뒤 최종 레일 샘플링만 보정했으므로 해당 PNG의 실제 화면과 해시만 다시 확인했다.
- 마지막 소스는 공용 `lobby_frame.gd`, `battle_theme.gd`, `battle_rewards.gd`, `game_button.gd`의 병행 변경을 포함해 검사 복사본과 해시가 일치한다. 이 작업의 원본 코드 소유 변경은 `hud_chrome.gd`, `battle_hud.gd`, 신규 `verify_hud_native_frames.gd`다. manifest 항목은 부모가 통합했다.
- Android 실제 기기·APK 검증은 수행하지 않았다.
