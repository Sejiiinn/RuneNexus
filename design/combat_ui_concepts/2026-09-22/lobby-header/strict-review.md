# 로비 상단 독립 검증

2026-09-22. **PASS — 로비 상단의 긴 띠 제거·타이틀/자원 분리 범위.** 구현 코드를 수정하지 않고 소스 diff, 최종 실제 화면, 검사 하네스·로그를 확인하고 부족했던 실제 hit 입력만 별도 검증했다. Git index/commit은 조작하지 않았다.

- 소스 변화는 별도 back 행 제거와 `_header` 재구성에 한정된다. 전체 폭의 배경 띠가 없어졌으며 왼쪽 로비 이동+아이콘/타이틀 묶음과 오른쪽 금속 자원 패널이 분리됐다. 본문, 홈 렌더, 하단 탭 코드는 보존된다.
- 320/440 화면의 실제 캡처를 직접 확인했다. 강화·연구·코어·포탑·스테이지 각 화면에서 정보 누락·그룹 겹침·새 가로 잘림이 없다. [320 강화](320-강화-normal.png), [320 코어](320-코어-normal.png), [320 연구](320-연구-normal.png), [320 포탑 긴 수치](320-포탑-long.png), [440 스테이지](440-스테이지-normal.png).
- [320 긴 자원](320-강화-long.png), [440 긴 자원](440-연구-long.png)은18자리 숫자를 그대로 표시한다. 작은 폭에서 왼쪽 묶음만 두 행이 되며 자원과 겹치지 않는다. 스테이지는 기존 퀘스트 아이콘38×38과 로고 높이44를 유지한다. [320 스테이지 긴 수치](320-스테이지-long.png)에서도 로고 전체가 표시되며 폭에 맞춰 작아진다.
- 기본 headless/visual 하네스는320/440×5페이지×일반/18자리 조합의 경계·자원 폭·그룹 분리와 footer/back/quest 연결을 검사한다. [header-test.log](header-test.log), [visual-test.log](visual-test.log) PASS. 이 하네스의 `pressed.emit`는 실제 입력이라고 간주하지 않았다.
- 부족했던 입력은 [별도 독립 하네스](strict_input.gd)로 보강했다. 기존 격리 프로젝트에서 실제 viewport `InputEventMouseMotion`/`InputEventMouseButton` press/release를 주입했다. 320 긴 수치/440 기본 수치에서 퀘스트 진입, 로비 이동 버튼 왼쪽 안쪽2px 클릭, 강화 화면의 로비 버튼 중앙 클릭이 동작했다. 퀘스트 열기로 progression은 바뀌지 않았고 이동 후 실제 홈이 생성됐다. [strict-input.log](strict-input.log) PASS. 모달닫기는 다음 입력 검사를 위한 준비 동작으로 실제 `close_modal()` API를 사용했다.
- 기존 [로비 smoke 회귀](lobby-regression.log)는8페이지·구매/잠금·코어 모달·홈 상태를 통과했다. 같은 회귀를 반복하지 않고 결과와 검사 범위를 확인했다.

검증환경: Godot4.7.2 / macOS Apple M4 / OpenGL Compatibility, `build/godot/lobby-header-review`, 별도 `RuneNexus-lobby-header-review` userdir. 독립 하네스는 저장을 사용하지 않는 FakeApp progression을 사용하며 사용자 플레이 저장을 읽거나 쓰지 않았다. 최신 소스와 격리본 SHA가 일치한다: `lobby.gd` = `1e4cbbddcee4123abfea0367aa0c9970a57d5d72deb61faf215aa7414cb50fa7`, `verify_lobby_header.gd` = `13b1948aa7d88ff521bcc030ed0f8893cc2378a2621c196c273eff6d1f5940eb`.

최종 실행 로그에 오류·경고는 없다. 초기 독립 하네스의 잘못된 `close_back` 호출은 하네스에서 수정했으며 제품 코드 결함으로 분류하지 않았다. Android 실제 터치·안전영역은 미검증이며 이번 PASS 범위에 포함하지 않는다. 미해결 데스크톱 결함 없음.
