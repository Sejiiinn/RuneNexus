# 네이티브 프레임 독립 구조 감사

2026-09-22. **최종 PASS — 네이티브 프레임 구조와 데스크톱 외형 보존 범위**. 다른 구현 담당자의 코드를 변경하지 않고 현재 소스, 실제 사용 경로, 원본 제작 기록, 전후 실행 이미지·검증 로그를 조사했다. 버튼 분담 구현은 부모가 별도로 검토하므로 여기서는 타 담당 프레임 전환에 집중했다.

## 독립 구조 판정

- `lobby_frame.gd`는 실제 `StyleBoxTexture` 상속이다. 기존 수동 `_draw`·RenderingServer 9분할 루프는 없다. `hud_chrome.gd`의 `DockFrame._draw`도 제거됐으며 새 도크는 완성 PNG 하나와 `StyleBoxTexture`를 사용한다. 이 세 파일(`battle_hud.gd` 포함)에 Control.scale로 외형을 우회하는 경로가 없다.
- 로비 프레임은 기존 6종 `CENTERS` 좌표를 유지한다. ImageTexture에 논리 크기(1/4, 전투 primary 1/3)를 설정할 뿐 이미지 데이터를 다시 샘플링하지 않는다. 원본 Texture RID는 변경하지 않는다. 고정 코너 texture margin과 각 사용처의 content margin은 독립적이다.
- `(master instance id, source_scale)`별 캐시가 논리 ImageTexture 하나를 공유한다. Button 상태별 스타일은 각각 새 인스턴스여서 modulation/콘텐츠 여백을 바꿔도 다른 상태를 바꾸지 않는다. 현재 로비·HUD 소비자에서 Frame 자체를 복제한 뒤 source 속성을 변경하는 경로는 없다. 원본 전체 이미지의 메모리 복사본이 생기므로 이 변경을 GPU 메모리 절감이나 성능 실측 개선으로 주장하지 않는다.
- `source_center`가 빈 경로는 원본 전체 stretch, 누락 경로는 1×1 단색 texture fallback을 사용한다. 실제 호출의 배율은 4와3이며 잘못된0/음수 배율의 신규 사용처는 없다. 기존 범위 밖 입력을 지원하는 새 계약으로 해석하지 않았다.
- HUD는 전용 Theme의 HudPrimary/HudDock/HudTabs/HudPopup 변형을 실제 start/detail/tabs/popup에 연결한다. primary 기존 (12,14) 코너·76×36 버튼, popup 14px 코너/10px 콘텐츠, 도크 top4px와 좌우·하단0px 경계가 보존된다. ResourceHUD와 quiet 단색 컨트롤·체력바·선은 별도 경로를 유지한다.
- `battle_theme.create(true)`는 전투 전용이고 로비의 기존 `create()`는 기본 legacy 스타일을 유지한다. box() 기반 로비 collection 보조표현은 변경되지 않았다.
- 원본 `panel_frame.png` SHA와 도크 제작 기록의 원본 SHA가 일치한다. manifest에 `ui/hud/dock_panel.png`는1회 등록되며 중복항목0이다. 도크는 기존 interior(56,56,1392,528)와 직선 상단rail(56,0,1392,56)에서 제작돼 떠 있는 모서리를 새로 넣지 않는다.

## 직접 확인한 시각 근거

- [HUD 이전320](hud/before-picker-320.png)/[이후320](hud/after-picker-320.png), [이후440](hud/after-picker-440.png), [팝업320](hud/after-popup-320.png), [재개440](hud/after-resume-440.png)를 직접 열어 배치·금속형태·텍스트·좌우하단 도크 연결을 확인했다. primary 원형과 팝업 정보가 유지되며 신규 잘림이 보이지 않는다.
- [로비 강화320](lobby/after-320-강화.png)와 로비 전후 비교 자료를 확인했다. 금속 모서리·청록 내부와 정보배치가 유지된다. [픽셀 비교](lobby/pixel-comparison.log)는 퀘스트 완전동일, 기타 화면 최대1~4/255의 미세한 샘플링 차이를 기록한다. 320 보유모듈의 기존 세로 줄바꿈은 전후 공통이며 이번 전환의 신규 결함으로 판정하지 않는다.
- 도크 상단rail의 초기 downsample 차이(평균 약15/255)는 제작 담당자가 원본 bilinear 샘플과 맞춰 국소 보정했다. 갱신된320/440 picker·440 popup·440 resume를 다시 직접 열어 레일 밝기·두께·edge 연결과 내용 보존을 확인했다. 최종 [정량 비교](hud/pixel-comparison.json)는 rail 평균0.168/0.178, 최대2/3(255기준), 전체 dock 평균0.116/0.118, primary 픽셀 차이0이다. 미세한 샘플링 오차를 허용한 외형 보존 PASS이며 픽셀 완전동일이라고 주장하지 않는다. 최종도크 SHA는 `63230f6195100068e6eadac7de06bcc245fa994f5f79188c0633a871be575185`다.

## 다른 담당의 실행 근거와 범위

로비 `frame-test.log`/`growth-test.log`/`collection-test.log`, HUD `native-test.log`/`hud-test.log`의 PASS를 읽고 검증 코드의 검사 범위를 확인했다. 같은 회귀를 독립감사 명목으로 반복 실행하지 않았다. 부모도 HUD/로비 대표 화면을 별도로 확인했다고 보고했다. 본 감사의 직접 수행은 구조·사용경로·제작 원본/manifest·해시 및 위 이미지 시각 확인이다. 실행 입력 비교는 [strict-inputs.json](strict-inputs.json)에 기록했다.

Android 실제 기기·성능·배포는 이 감사의 PASS 대상이 아니다.

최종 결과: 미해결 구조·시각 결함 없음. 회귀 실행의 통과 근거와 독립감사의 직접 확인 범위를 구분했으며, 다른 담당 파일을 수정하지 않았다.
