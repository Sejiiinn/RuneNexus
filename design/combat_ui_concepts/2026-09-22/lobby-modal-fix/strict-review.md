# 실제 로비 모달 독립 검증

2026-09-22. **최종 PASS — 실제 로비 모달의 위치·줄바꿈·하단 접근과 보상칩 가독성.** 코드·Git index를 수정하지 않고 구현 담당자의 실제 Lobby 경로 검증을 검토한 뒤 AppLifecycle까지 포함한 독립 실행으로 취약 조건을 확인했다.

## 독립 실제 앱 경로

[독립 하네스](strict_live.gd)는 `main.tscn --app`에서 실제 `res://app/app_lifecycle.gd`와 Lobby를 생성한다. FakeHost로 상세 컨텐츠만 배치하는 경로가 아니다. 격리 프로젝트 `build/godot/lobby-modal-review`, `RuneNexus-lobby-modal-review` userdata를 assert하며 사용자 live/local-play와 저장은 읽거나 수정하지 않았다.

애니메이션 ON, canvas_items+expand, `content_scale_size=(440,760)`, physical `(440,900)`, 실제 viewport `(440,900)`에서 다음을 확인했다.

- 잠김 스테이지8, 보상 스테이지11, 기록 없는 스테이지1을 실제 스테이지 행 클릭으로 열었다. [stage1](strict-real-stage1.png), [stage8](strict-real-stage8.png), [stage11](strict-real-stage11.png)을 직접 열어 확인했다.
- 기록 없음/잠김/클리어 보상/강화/연구/최초 클리어 보상이 수평 한 줄이다. 잠금 설명은 정상 문장으로 표시되고 시작/닫기가 화면 안에 들어온다.
- 입장0.4초 후와 추가0.6초 뒤 rect가 동일하다. 닫기→재진입 후 tween 도중 physical900→1100, 다시900으로 변경해도 중앙으로 재배치되고 옛 y로 돌아가지 않는다. stage1 rect는900에서(25,267,390,366),1100에서(25,367,390,366)이다.
- 실제 viewport 마우스 press/release로 닫기를 눌렀다. 잠김 stage8 시작 버튼은 무동작이고, stage1 시작은 실제 AppLifecycle에서 `in_lobby=false`, stage0, native combat active까지 확인했다. [로그](strict-live.log) PASS.

독립 실행의 모달 스크립트 오류는0이다. 복사된 검증 프로젝트의 GLB 외부참조 UID 경고38건는 텍스트 경로 fallback을 명시하며 실제 에셋 로딩·시작은 성공했다. 이를 모달 오류0과 구분해 기록한다. 부모의 사용자 test 저장/MetalMobile 경로 확인은 별도 근거이며 본 독립 실행은 OpenGL Compatibility였다.

## 다른 담당의 실행 근거

[after-test.log](after-test.log)의 실제 Lobby + animation ON320/440×stage1/8/11, 클릭, resize,320×260짧은창의 본문 scroll/고정닫기 PASS를 하네스 소스와 함께 읽었다. 같은 전체회귀는 반복하지 않았다. 기존 단순 테스트가 animation disabled/FakeHost로 놓친 조건은 이제 실제 Lobby flow에서 검사한다.

## 독립 발견 결함과 재검증

P2: [320 stage8](after-320-stage8.png)의 연구 보상 `전투 강화 비용 최적화`가 극소 글꼴로 축소되어 판독 불가다. `lobby_stages.gd`의 기존 min1px 자동축소 콜백이 원인이다. 모달 bounds/caption 한줄만 확인하면 통과하지만 긴 보상 이름의 가독성은 통과하지 못한다. 구현 담당자에게 즉시 전달했다. 이후 보상칩의 축소 콜백을 제거하고 원래10px를 고정하며 자연문자폭에 맞춰3→2→1열로 배치하도록 국소 수정했다.

Android 기기/터치/배포는 이 검증 범위에 포함하지 않는다.


최종 보정된 [320 stage8 보상](rewards-320-stage8.png), [440 stage8 보상](rewards-440-stage8.png), [짧은 창 스크롤](rewards-short-scroll.png)을 다시 직접 열어 판정했다. `전투 강화 비용 최적화`가320/440 모두10px로 전체 판독되며 줄·칩·하단버튼 겹침이 없다.320은1열,440은2열이고 원래아이콘·프레임·문구를 유지한다. 짧은 창에서는 보상본문을 스크롤하면서 닫기헤더와 하단버튼 접근을 유지한다. [해당영역 재검증로그](rewards-test.log)의 각문구 자연폭·font10·범위 assert PASS를 확인했다. 이미통과한전체앱실행은 반복하지 않았다.

최종 UI소스 `lobby.gd`/`lobby_stages.gd`의 원본·격리본 SHA가 일치한다. 공용 회귀하네스는 최종 추가assert와 실행본 사이 차이가 있으며, 최신 보상 검증은 별도 rewards-test 및 독립 resize 하네스로 확인했다([입력](strict-inputs.json)). 미해결 요청범위 결함 없음. 사용자실행 PID/저장은 수정하지 않았다.


보정 영향으로 남은 동일모달 폭변경도 독립 추가 확인했다: [하네스](strict_grid_resize.gd), [로그](strict-grid-resize.log), [440→320 직후 화면](strict-resize-320.png). 실제 Lobby의 같은 stage8모달이440→320→440에서2→1→2열로 변하고 font10/문구폭129→199→129를 유지한다. 모달은각뷰포트 안에서중앙을유지하며,320높이는392px로내용에맞게늘어난다. 이새위험조건만 검사했고 전체AppLifecycle/입력회귀는 반복하지 않았다. **최종 PASS,미해결없음.**
