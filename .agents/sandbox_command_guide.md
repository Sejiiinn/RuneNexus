# Sandbox Command Guide

## 기본 원칙

- 권한 문제가 의심되는 명령은 샌드박스에서 먼저 실행하지 말고 샌드박스 밖 실행 승인을 요청하세요.
- 읽기·편집 중심 작업은 샌드박스에서 진행하세요.

## 처음부터 승인 요청할 명령

- `flutter analyze`
- `flutter test`
- `flutter run`
- `flutter build`
- `scripts/in_app_server.ps1 -Action dev`
- `scripts/in_app_server.ps1 -Action restart`
- `scripts/in_app_server_macos.sh dev`
- `scripts/in_app_server_macos.sh restart`
- `git add`
- `git commit`
- `git push`

## 샌드박스에서 진행할 작업

- `rg`
- 파일 읽기
- 파일 수정
- `git status`
- `git diff`

## 53000 포트 서버 확인

- 53000 포트 서버는 먼저 `scripts/in_app_server.ps1 -Action status` 또는 `scripts/in_app_server_macos.sh status`로 확인하세요.
- HTTP 200이면 재기동보다 cache-bust URL 갱신을 우선하세요.
- 개발 서버 세션이 살아 있으면 hot reload 후 인앱 브라우저 새로고침을 우선하세요.

## 커밋 전 확인

- Flutter 실행 뒤 생성 파일이나 줄바꿈만 바뀐 파일이 섞일 수 있으므로 커밋 전에는 의도한 변경만 스테이징하세요.
- 플랫폼 generated plugin 파일은 요청 범위가 아니면 스테이징하지 마세요.
