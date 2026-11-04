# 시작 화면 버튼·진행 표시 수정 근거

역할: 2026-09-26 시작 화면 국소 시각 수정의 실제 Godot 실행 근거. 기준은 [공통 디자인](../../DESIGNS.md)과 기존 공용 [금속 컴포넌트](../combat_ui_concepts/2026-09-22/modal-components/native/README.md)다.

604×136 투명 버튼 프레임에 18px 고정 모서리를 적용해 측면이 늘어났고, 24px 진행 표시에는 16px 위·아래 모서리가 겹쳤다. 공용 완성형 primary/secondary/disabled PNG와 공용 Theme를 재사용했다. 진행 프레임은 동일 금속 secondary 표면의 11px 모서리와 8×6px 콘텐츠 여백을 분리해 24px 안에 맞췄다. 동적 진행은 기존 그라데이션을 유지한다. 새 이미지·공용 테마 변경은 없다.

검증: 격리 복사 프로젝트에서 Godot 4.7.2, macOS Apple M4, OpenGL Compatibility 직접 실행. 일반 화면 440×988, 작은 화면 320×720·글자 2배, 가로 760×320·글자 2배. [실행 로그](after/run.log)와 [헤드리스 로그](after/headless.log)는 STARTUP_SCREEN failures=0이다. 실제 mouse input으로 두 콜백 및 busy 차단, 불확정 이동, 0·5·50·100% 트랙 크기, 선택/필수/재시도/설치 계속, 내부 스크롤 및 부팅 지연 계약을 검사했다. Android 빌드·설치·실기기는 이 작업에서 실행하지 않았다.

실제 시작 화면 컴포넌트를 회귀 fixture에서 실행한 캡처이며 업데이트 서버 접속 화면은 아니다.

독립 검증 PASS: 최종 코드와 대표 캡처에서 버튼·진행 표시 외형, 필수/선택/재시도/설치 계속, 좁은 화면·큰 글자 접근성을 확인했다. 동일 소스의 별도 Godot 실행으로 불확정 이동, 0·50·100% 진행 크기, 양 버튼 콜백 분리와 busy 입력 차단을 확인했다([독립 실행 로그](after/independent.log)). 미해결 결함은 없으며 Android 실기기는 미확인이다.

- [수정 전](before/optional.png) / [수정 후](after/optional.png)
- [눌림](after/primary-pressed.png) / [비활성](after/busy-disabled.png)
- [진행 0%](after/progress-0.png) / [5%](after/progress-5.png) / [50%](after/progress-50.png) / [100%](after/progress-100.png)
- [불확정](after/checking.png) / [작은 화면·큰 글자](after/narrow-large-text.png) / [가로·큰 글자](after/landscape-large-text.png)

관련 입력 SHA-256(공유 의존성과 캡처 유효성 판단용):

- `godot/ui/startup_screen.gd`: `3313ac1493a02c48875cf5d1935f5dcc9b81647b752b3afd89d326e1b33cdb83`
- `godot/ui/combat_component_theme.gd`: `360ec266c7c37cb9e33a749827b1ffd483a37140761ed9f29ab32516e84854a5`
- `godot/verify_startup_screen.gd`: `85083893a889b4d71cf9eab293d1c735d7a43909c3b163bed51656814dd14c1f`
- `assets/images/ui/combat_components/native/primary.png`: `9802798600f1d75e36a5cf4c798b126c030a7541839815ad0cb272b6d799f2ae`
- `assets/images/ui/combat_components/native/secondary.png`: `4460e9a959c3d57c50861dc5761fa683cd6c911617591810d7573396bfa89254`
- `assets/images/ui/combat_components/native/disabled.png`: `6cb1a4911897557f87dfdef3864f8ae38a03f28ce769114950bf5b8085145ff4`
- `assets/images/ui/combat_components/native/selected.png`: `f31bf741ae945628e348ab1d3dfb647fb864d8aa973fd489a04ce113ba1adc1d`
