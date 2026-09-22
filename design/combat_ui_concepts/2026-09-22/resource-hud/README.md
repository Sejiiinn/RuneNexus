# 상단 ResourceHUD 테두리 정리

2026-09-22. 상단 정보창의 기존 금속 사선 모서리·레일을 보존하면서 외곽 fringe와 프레임 렌더 경로만 정리했다. 자원·전투력·체력·웨이브·다음 적·예상 보상·홈 버튼의 배치와 정보는 변경하지 않았다.

## 적용

- 제작 원본은 `assets/images/ui/components/panel_frame.png`(1504×640)이며 원본 파일은 그대로다. GIMP에서 376×160으로 축소하고 금속 레일 밖 불투명 잔여 픽셀을 알파로 정리한 `assets/images/ui/hud/resource_panel.png`를 추가했다. [재현 스크립트](production/prepare_frame.py).
- `battle_hud.gd`의 상단 `ResourceHUD`만 전용 `Theme` 변형과 `StyleBoxTexture`로 연결했다. 고정 모서리 14px와 콘텐츠 여백 8px를 분리했다. 이 창의 수동 9영역 `RenderingServer` 그리기를 제거했으며 기존 `lobby_frame.gd`, 공용 `HudChrome.panel()`·모달·로비·하단 스타일은 수정하지 않았다.
- 상단 외곽 위치·크기는 320에서 (8,8)/304×94, 440에서 (8,8)/424×94로 수정 전후 동일하다.

## 검증

Godot 4.7.2, macOS Metal Forward Mobile, Apple M4. 기존 격리 프로젝트 `build/godot/hud-review-v4`, 사용자 저장 `RuneNexus-HUD-review-v4`에서 스테이지 1 준비 상태를 직접 실행했다. 골드 3000·파편 100·포탑 없음, 320×760 및 440×900 조건이다. [환경·원본/파생 에셋·소스 해시](verification.json), [실행 하네스](capture.gd).

- 화면: [이전 320](before-top-320.png) → [수정 320](after-top-320.png), [이전 440](before-top-440.png) → [수정 440](after-top-440.png). 정보 잘림·겹침 없이 기존 배치를 유지하고 외곽 알파와 금속 레일을 확인했다.
- 모서리 원본 픽셀 캡처: [이전 좌상](before-tl-440.png) / [수정 좌상](after-tl-440.png), [이전 우상](before-tr-440.png) / [수정 우상](after-tr-440.png), [이전 좌하](before-bl-440.png) / [수정 좌하](after-bl-440.png), [이전 우하](before-br-440.png) / [수정 우하](after-br-440.png). 320 폭의 네 모서리도 같은 폴더에 보관한다.
- [HUD 회귀 PASS](hud-test.log): ResourceHUD의 Theme 변형·StyleBoxTexture·원본 경로·고정 코너14/여백8 확인, 기존 정보의 작은 화면 가독성·HUD 기능 회귀. [직접 실행 로그](after.log).
- 실제 마우스 이벤트를 홈 버튼 중심에 입력해 [스테이지 메뉴 열림](after-home-440.png)을 확인했다. [입력 로그](home.log). 메뉴 종료·다른 화면 이동을 실행하지 않았으며 본 검증은 홈 입력 수신과 기존 메뉴 열림까지다.
- 최초 after 실행에서 동시 작업으로 추가된 `hud_turret_panel.gd`, `hud_gem_panel.gd`, `hud_build_panel.gd`, `hud_menu_panel.gd`가 격리 프로젝트에 없어 중단됐다. 해당 원본을 수정하지 않고 복사한 뒤 동일 검증을 완료했다. 완료 시 이 네 파일과 `battle_hud.gd`, manifest, 회귀 스크립트는 검사 복사본과 원본 해시가 같았다. 이전 캡처는 이 외부 리팩터 전이며 상단 비교 조건·정보·크기는 동일하다.
- Android 실기기·APK 검증은 수행하지 않았다. 독립 strict 재판정은 별도 담당자가 진행한다.
