# 인앱 테스트 피드백 단축 가이드

## 문제 원인

최근 UI 수정/캡처 루프가 느렸던 이유는 코드 수정 자체가 아니라 실행 방식이었다.

- `flutter run -d web-server`는 이 환경에서 대략 12~15초 이상 걸린다.
- 숨김 백그라운드 실행은 `r` hot reload 입력을 보낼 수 없어, Dart UI 코드를 바꿀 때마다 서버 재시작이 필요하다.
- `flutter_web_server.pid`가 실제 53000 리스너와 어긋날 수 있다. PID 파일만 믿으면 오래된 서버가 계속 살아 있는 상태를 놓친다.
- Flutter Web 첫 접속 직후에는 검은 초기화 화면이 잠깐 잡힐 수 있다. 바로 캡처하면 실패 컷이 생긴다.
- 후보 UI를 코드 상수로 바꿔가며 비교하면 후보 수만큼 전체 재시작 비용이 반복된다.

## 기본 원칙

- 서버 상태는 PID 파일보다 실제 53000 LISTEN + HTTP 200으로 판단한다.
- Dart UI 코드를 바꾼 경우에만 서버를 재시작한다.
- 재시작은 수동 명령 조합 대신 `scripts/in_app_server.ps1` 하나로 처리한다.
- 캡처 전에는 화면 텍스트나 DOM 상태를 확인한 뒤 스크린샷을 찍는다.
- UI 후보가 2개 이상이면 후보별 재시작 루프를 만들지 말고, 먼저 한 번에 전환 가능한 preview 상태를 만든다.

## 서버 명령

상태 확인:

```powershell
.\scripts\in_app_server.ps1 -Action status
```

서버 시작:

```powershell
.\scripts\in_app_server.ps1 -Action start
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
- Flutter web server 백그라운드 기동
- HTTP 200이 나올 때까지 대기
- cache-bust URL 출력

## 빠른 화면 확인 절차

1. 코드 수정 전 현재 서버 상태를 확인한다.

```powershell
.\scripts\in_app_server.ps1 -Action status
```

2. Dart UI 코드를 수정했다면 포맷 후 테스트를 먼저 돌린다.

```powershell
C:\Users\rlatp\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format <수정 파일>
C:\Users\rlatp\develop\flutter\bin\flutter.bat test test\widget_test.dart
```

3. 서버를 한 번만 재시작한다.

```powershell
.\scripts\in_app_server.ps1 -Action restart
```

4. 출력된 `URL=...cache_bust=...` 주소로 인앱 브라우저를 연다.

5. Flutter 초기화 화면 방지:
   - 제목이 `Rune Nexus`로 바뀌었는지 확인
   - 필요한 탭 텍스트가 보이는지 확인
   - 그 다음 캡처

## 후보 UI 비교를 빨리 하는 방법

후보가 1개면 지금처럼 실제 코드만 바꾸고 한 번 재시작하면 된다.

후보가 2개 이상이면 아래 방식이 낫다.

1. 임시 상수를 후보마다 바꾸지 않는다.
2. `?previewUpgradeLayout=1`, `?previewUpgradeLayout=2`처럼 URL query로 후보 레이아웃을 바꾸는 preview 진입점을 먼저 만든다.
3. 서버는 한 번만 재시작한다.
4. 인앱 브라우저에서 URL만 바꿔 후보별 캡처를 찍는다.
5. 후보가 결정되면 preview query 분기와 미선택 후보 코드는 제거한다.

이 방식이면 후보 3개 비교가 “서버 재시작 3회”가 아니라 “서버 재시작 1회 + URL 3회 이동”으로 줄어든다.

## 다음부터 Codex가 따라야 할 체크리스트

- 인앱 확인 요청을 받으면 먼저 `scripts/in_app_server.ps1 -Action status`를 실행한다.
- 코드 변경이 없으면 서버를 재시작하지 않는다.
- Dart UI 변경이 있으면 `restart`는 한 번만 한다.
- 후보 비교가 필요하면 먼저 URL query 기반 preview 진입점을 제안하거나 만든다.
- 캡처 실패 시 같은 재시작을 반복하지 않는다. 브라우저 렌더 완료 상태를 먼저 확인한다.
- PID 파일과 실제 LISTEN PID가 다르면 실제 LISTEN PID를 기준으로 정리한다.

## 기대 시간

- 기존 후보 3개 비교: 재시작 3회 이상 + 검은 화면 재시도 포함, 2~4분 이상.
- 이 가이드 적용 후 후보 3개 비교: 재시작 1회 + URL 전환 캡처, 대략 30~60초.
- 단일 UI 수정 확인: 상태 확인 + 재시작 1회 + 캡처, 대략 20~40초.
