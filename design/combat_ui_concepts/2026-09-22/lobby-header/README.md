# 로비 메뉴 상단 분리

2026-09-22. 사용자 요청에 따라 스테이지·코어·강화·연구·포탑의 긴 상단 배경띠를 제거하고 로비 이동과 제목을 묶고 자원을 분리했다. [현행 디자인 기준](../../../../DESIGNS.md)의 메뉴 탭 상단 행을 따른다.

## 구현

- `godot/ui/lobby.gd`: 상단 12px 안쪽에서 왼쪽 로비 이동·기존 아이콘/제목과 오른쪽 자원 프레임을 분리했다. 화면 끝까지 이어지는 배경띠·밑줄과 로비 이동 전용 행은 제거했다.
- 기본 320/440px에서는 로비 이동·제목이 같은 행이다. 320px에서 18자리 잔액처럼 공간이 부족할 때만 왼쪽 그룹 안에서 두 행으로 배치한다. 숫자를 축약하거나 잘라내지 않는다.
- 표준 Margin/HBox/Grid/VBoxContainer와 기존 `row_frame.png`의 native StyleBoxTexture를 사용한다. 새 이미지 없음. 기존 폰트·자원 아이콘·제목·스테이지 로고·퀘스트 진입을 유지한다. 로비 이동은 최소 42×36, 스테이지 퀘스트는 기존 38×38 터치 크기다.
- 홈 화면·본문·하단 탭·저장 및 게임 로직은 변경하지 않았다.

## 확인

Godot 4.7.2 공식 / macOS Apple M4 / OpenGL Compatibility. `build/godot/lobby-header-review`와 별도 `RuneNexus-lobby-header-review` 사용자 경로를 사용했다. 사용자 저장과 공유 편집 프로젝트를 수정하지 않았다.

- `godot/verify_lobby_header.gd`: 320/440px, 다섯 페이지, 일반/18자리 잔액에서 상단 화면 경계·제목/지갑 겹침 없음·숫자 너비·복귀 버튼 크기 PASS. 하단 연구 탭→로비 복귀와 스테이지 퀘스트의 pressed 신호 입력 PASS. 로그: [렌더 실행](visual-test.log), [headless 검사](header-test.log).
- 기존 `verify_lobby.gd`: 8페이지·잠금/구매/코어창·홈·작은 화면·모달 복귀/이벤트 PASS. [로그](lobby-regression.log).
- 대표 실제 앱 화면을 직접 확인했다. [320 강화](320-강화-normal.png), [320 스테이지](320-스테이지-normal.png), [440 포탑](440-포탑-normal.png), [320 긴 자원/코어](320-코어-long.png), [440 긴 자원/코어](440-코어-long.png). 폴더의 전체 캡처는 `너비-페이지-normal/long.png` 형식이다. 테스트 progression을 주입한 실제 Lobby 화면이며 시안이 아니다.
- 입력 소스·기존 자원 프레임 해시: [input-sha256.txt](input-sha256.txt). 변경 전 상단 코드는 `lobby.before.gd`에 보존했다.

pressed 신호 검사는 포인터 hit 경로를 대신하지 않는다. 실제 포인터 입력 보강은 독립 검수 결과로 구분한다. Android 실기기 검증은 수행하지 않았다.
