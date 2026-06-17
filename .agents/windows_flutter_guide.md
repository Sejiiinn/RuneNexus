# Windows Flutter Guide

## 목적

- Windows 환경에서 Flutter/Dart 검증을 할 때 가장 먼저 참조하는 진입점입니다.
- `dart`, `flutter`, `flutter analyze`, `flutter test`, `flutter run`, `flutter build`, 포맷, 53000 포트 확인, 인앱 브라우저 검증에 모두 적용합니다.
- Windows에서 배치 래퍼가 멈추거나 권한 문제로 실패하는 상황을 피합니다.
- 인앱 확인을 할 때 오래된 서버나 정적 번들을 바라보는 실수를 줄입니다.

## 우선순위

1. Flutter/Dart 관련 명령을 실행하기 전에 `.agents/sandbox_command_guide.md`에서 승인 필요 여부를 확인합니다.
2. 포맷은 가능한 경우 직접 Dart SDK 실행 파일을 사용합니다.
3. 인앱 브라우저 검증 전에는 반드시 53000 포트 상태를 확인합니다.
4. HTTP 200이면 기존 서버를 우선 활용하고, 바로 다른 경로나 새 서버를 보지 않습니다.
5. 개발 서버가 살아 있으면 hot reload 후 인앱 브라우저 새로고침을 우선합니다.
6. 오래된 정적 번들이 의심될 때만 `restart` 후 cache-bust URL로 접속합니다.

## 포맷

- Windows 샌드박스 환경에서는 `dart`, `flutter` 배치 래퍼가 오래 멈추거나 `dartaotruntime.exe` 실행이 `Access denied`로 실패할 수 있습니다.
- 포맷은 가능한 경우 Dart SDK 실행 파일을 직접 호출하세요.
- 명령:
  - `C:\Users\rlatp\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format <파일>`

## 인앱 브라우저 확인 전 점검

- 먼저 `scripts/in_app_server.ps1 -Action status`로 53000 포트의 기존 Flutter web server가 살아 있는지 확인하세요.
- HTTP 200이면 다른 서버, 다른 포트, 오래된 정적 파일 경로를 먼저 보지 마세요.
- 개발 서버가 살아 있으면 hot reload 후 인앱 브라우저 새로고침을 우선하세요.
- 오래된 정적 번들이 의심될 때만 `scripts/in_app_server.ps1 -Action restart` 후 cache-bust URL로 접속하세요.

## 검증 명령

- `flutter analyze`, `flutter test`, `flutter run`, `flutter build`는 Windows 샌드박스에서 직접 실행하지 말고 샌드박스 밖 실행 승인을 먼저 요청하세요.
- 인앱 테스트 서버 실행이나 재시작도 샌드박스 밖 실행 승인을 먼저 요청하세요.
- 읽기, `rg`, `git status`, `git diff`, 문서 수정은 샌드박스에서 진행합니다.

## 관련 문서

- 인앱 테스트 화면을 실제로 열거나 UI·게임플레이·렌더링을 확인할 때는 이 문서의 우선순위를 적용한 뒤 `.agents/in_app_test_guide.md`를 따르세요.
- 승인 필요 명령 목록은 `.agents/sandbox_command_guide.md`를 함께 확인하세요.
