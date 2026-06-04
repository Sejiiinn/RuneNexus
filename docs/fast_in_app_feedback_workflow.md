# 인앱 테스트 피드백 단축 가이드

## 문제 원인

최근 UI 수정/캡처 루프가 느렸던 이유는 코드 수정 자체가 아니라 실행 방식이었다.

- 전체 웹 빌드 기반 `restart`는 작은 Dart 수정에도 `flutter build web` 비용을 매번 낸다.
- 숨김 백그라운드 실행은 `r` hot reload 입력을 보낼 수 없어, Dart UI 코드를 바꿀 때마다 전체 재시작이 필요하다.
- `flutter_web_server.pid`가 실제 53000 리스너와 어긋날 수 있다. PID 파일만 믿으면 오래된 서버가 계속 살아 있는 상태를 놓친다.
- Flutter Web 첫 접속 직후에는 검은 초기화 화면이 잠깐 잡힐 수 있다. 바로 캡처하면 실패 컷이 생긴다.
- 후보 UI를 코드 상수로 바꿔가며 비교하면 후보 수만큼 전체 재시작 비용이 반복된다.

## 기본 원칙

- 서버 상태는 PID 파일보다 실제 53000 LISTEN + HTTP 200으로 판단한다.
- 작은 Dart/UI/게임플레이 수정은 foreground 개발 서버 `dev`로 확인하고, 터미널에서 `r` hot reload를 보낸 뒤 인앱 브라우저를 새로고침한다.
- `restart`는 큰 변경이나 전체 웹 산출물 확인이 필요할 때만 사용한다.
- Windows와 macOS 모두 수동 명령 조합 대신 프로젝트 스크립트를 진입점으로 사용한다.
- 캡처 전에는 화면 텍스트나 DOM 상태를 확인한 뒤 스크린샷을 찍는다. `dev` 경로에서 screenshot 캡처가 타임아웃되면 같은 재시작을 반복하지 말고, 인앱 브라우저 새로고침과 페이지 상태 확인으로 먼저 검증한다.
- UI 후보가 2개 이상이면 후보별 재시작 루프를 만들지 말고, 먼저 한 번에 전환 가능한 preview 상태를 만든다.

## Windows 서버 명령

상태 확인:

```powershell
.\scripts\in_app_server.ps1 -Action status
```

서버 시작:

```powershell
.\scripts\in_app_server.ps1 -Action start
```

개발 서버 시작:

```powershell
.\scripts\in_app_server.ps1 -Action dev
```

서버 재시작:

```powershell
.\scripts\in_app_server.ps1 -Action restart
```

서버 종료:

```powershell
.\scripts\in_app_server.ps1 -Action stop
```

스크립트는 다음을 한 번에 처리한다.

- 53000 포트의 실제 LISTEN PID 확인
- 필요 시 오래된 서버 종료
- `flutter_web_server.pid`, `out.log`, `err.log` 정리
- `start`/`restart`에서는 정적 서버 백그라운드 기동
- `dev`에서는 Flutter web-server foreground 기동
- HTTP 200이 나올 때까지 대기
- cache-bust URL 출력

## macOS 서버 명령

macOS Codex 세션 기준 경로:

```bash
cd /Users/sejin/Documents/RuneNexus
```

Flutter/Dart 실행 파일:

```bash
/Users/sejin/development/flutter/bin/flutter
/Users/sejin/development/flutter/bin/cache/dart-sdk/bin/dart
```

macOS에서는 다음 스크립트를 고정 진입점으로 사용한다.

```bash
scripts/in_app_server_macos.sh status
scripts/in_app_server_macos.sh dev
scripts/in_app_server_macos.sh restart
scripts/in_app_server_macos.sh stop
```

`dev`는 53000 포트 정리 후 `flutter run -d web-server`를 foreground로 실행한다. Dart 변경 뒤 같은 터미널에 `r`을 입력하고 인앱 브라우저 탭을 새로고침하면 빠르게 갱신된다. 최근 측정 기준으로 단순 UI 변경 hot reload는 대략 0.2~0.5초 수준이었다.

`restart`는 53000 포트 정리, `flutter build web --pwa-strategy=none`, 정적 서버 foreground 기동을 순서대로 실행한다. 큰 변경이나 전체 웹 산출물 확인이 필요할 때 사용한다.

상태 확인:

```bash
scripts/in_app_server_macos.sh status
```

포맷:

```bash
scripts/in_app_server_macos.sh dart format <수정 파일>
```

테스트:

```bash
scripts/in_app_server_macos.sh flutter test <관련 테스트 파일>
```

웹 빌드:

```bash
scripts/in_app_server_macos.sh build
```

정적 서버 기동:

```bash
scripts/in_app_server_macos.sh start
```

개발 서버 기동:

```bash
scripts/in_app_server_macos.sh dev
```

브라우저 접속 주소:

```bash
scripts/in_app_server_macos.sh url
```

인앱 브라우저 열기:

- Codex에서는 macOS `open` 명령을 쓰지 않는다.
- Browser 플러그인의 인앱 브라우저에 위 cache-bust URL을 직접 연다.
- 화면 확인 전 `title == Rune Nexus`와 주요 텍스트 표시를 먼저 확인한다.

포트 정리:

```bash
scripts/in_app_server_macos.sh stop
```

주의:

- macOS Codex 샌드박스에서는 Flutter SDK 캐시 쓰기, 포트 바인딩, 프로세스 종료가 `Operation not permitted`로 막힐 수 있다.
- 이 경우 같은 명령을 오래 반복하지 말고 즉시 샌드박스 밖 실행 승인을 요청한다.
- 백그라운드 `python3 -m http.server ... &`는 세션 종료와 함께 바로 죽을 수 있으므로, 인앱 확인 중에는 foreground PTY 세션으로 띄워 둔다.
- 확인이 끝나면 서버 세션에 `Ctrl-C`를 보내 정리한다.
- 개발 중 반복 확인은 `scripts/in_app_server_macos.sh dev`를 우선한다. 코드 변경 후에는 터미널에 `r`을 입력하고 Browser 플러그인의 인앱 브라우저 탭에 reload를 보낸다.
- `scripts/in_app_server_macos.sh restart`는 실제 `build/web` 결과를 확인해야 하는 큰 변경에서만 사용한다.

## 빠른 화면 확인 절차

1. 코드 수정 전 현재 서버 상태를 확인한다.

Windows:

```powershell
.\scripts\in_app_server.ps1 -Action status
```

macOS:

```bash
scripts/in_app_server_macos.sh status
```

2. Dart UI 코드를 수정했다면 포맷 후 테스트를 먼저 돌린다.

Windows:

```powershell
C:\Users\rlatp\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format <수정 파일>
C:\Users\rlatp\develop\flutter\bin\flutter.bat test test\widget_test.dart
```

macOS:

```bash
scripts/in_app_server_macos.sh dart format <수정 파일>
scripts/in_app_server_macos.sh flutter test <관련 테스트 파일>
```

3. 작은 수정이면 개발 서버를 띄우거나 기존 개발 서버에 hot reload를 보낸 뒤, 인앱 브라우저 탭을 새로고침한다.

Windows:

```powershell
.\scripts\in_app_server.ps1 -Action dev
```

macOS:

```bash
scripts/in_app_server_macos.sh dev
```

큰 변경이거나 전체 웹 산출물을 확인해야 할 때만 `restart`를 사용한다.

Windows:

```powershell
.\scripts\in_app_server.ps1 -Action restart
```

macOS:

```bash
scripts/in_app_server_macos.sh restart
```

4. 개발 서버가 출력한 주소 또는 `URL=...cache_bust=...` 주소로 인앱 브라우저를 연다. 이미 탭이 열려 있다면 URL 재접속 대신 브라우저 reload 명령을 보낸다.

macOS 정적 서버는 직접 다음 형식으로 연다.

```text
http://127.0.0.1:53000/?cache_bust=<현재시각>
```

Codex에서는 이 URL을 Browser 플러그인의 인앱 브라우저로 연다. macOS `open` 명령은 사용하지 않는다.

5. Flutter 초기화 화면 방지:
   - 제목이 `Rune Nexus`로 바뀌었는지 확인
   - 필요한 탭 텍스트가 보이는지 확인
   - 그 다음 캡처
   - `dev` 경로에서 screenshot 캡처가 타임아웃되면 페이지 상태를 먼저 확인하고, 최종 시각 캡처가 필요할 때만 `restart`로 정적 서버를 띄운다.

## 후보 UI 비교를 빨리 하는 방법

후보가 1개면 개발 서버에서 실제 코드만 바꾸고 hot reload 후 인앱 브라우저 새로고침으로 확인한다.

후보가 2개 이상이면 아래 방식이 낫다.

1. 임시 상수를 후보마다 바꾸지 않는다.
2. `?previewUpgradeLayout=1`, `?previewUpgradeLayout=2`처럼 URL query로 후보 레이아웃을 바꾸는 preview 진입점을 먼저 만든다.
3. 개발 서버는 한 번만 띄운다.
4. 인앱 브라우저에서 URL만 바꿔 후보별 캡처를 찍는다.
5. 후보가 결정되면 preview query 분기와 미선택 후보 코드는 제거한다.

이 방식이면 후보 3개 비교가 “전체 빌드 3회”가 아니라 “개발 서버 1회 + URL 3회 이동”으로 줄어든다.

## 다음부터 Codex가 따라야 할 체크리스트

- 인앱 확인 요청을 받으면 먼저 현재 OS를 확인한다.
- Windows면 `scripts/in_app_server.ps1 -Action status`를 실행한다.
- macOS면 `scripts/in_app_server_macos.sh status`로 53000 LISTEN/HTTP 200을 확인한다.
- 코드 변경이 없으면 서버를 재시작하지 않는다.
- Dart UI 변경이 있으면 Windows는 `dev`, macOS는 `scripts/in_app_server_macos.sh dev`를 우선 사용하고, hot reload 후 인앱 브라우저 reload로 확인한다.
- 큰 변경이나 전체 웹 산출물 확인이 필요할 때만 `restart`를 실행한다.
- 후보 비교가 필요하면 먼저 URL query 기반 preview 진입점을 제안하거나 만든다.
- 캡처 실패 시 같은 재시작을 반복하지 않는다. 브라우저 렌더 완료 상태를 먼저 확인한다.
- PID 파일과 실제 LISTEN PID가 다르면 실제 LISTEN PID를 기준으로 정리한다.
- macOS에서 `Operation not permitted`가 나오면 같은 명령을 반복하지 말고 승인 요청으로 전환한다.

## 기대 시간

- 기존 후보 3개 비교: 전체 빌드 3회 이상 + 검은 화면 재시도 포함, 2~4분 이상.
- 이 가이드 적용 후 후보 3개 비교: 개발 서버 1회 + URL 전환 캡처, 대략 30~60초.
- 단일 UI 수정 확인: 개발 서버 기동 후 hot reload + 인앱 브라우저 reload, 대략 수 초 단위.
