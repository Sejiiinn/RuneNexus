# 인앱 테스트 실행 가이드 (웹 서버 기동 정규 절차)

이 문서는 매번 동일한 방식으로 인앱 테스트 화면을 띄우기 위한 정해진 절차입니다.

## 1) 실행 전 확인

- 워크트리 기준 경로:
  - `C:\Users\rlatp\Documents\RuneNexus`
  - macOS: `/Users/sejin/Documents/RuneNexus`
- 대상 포트: `53000`
- 이미 떠 있는 기존 테스트 서버가 있는지 확인
  - `Get-NetTCPConnection -LocalPort 53000 -State Listen -ErrorAction SilentlyContinue`
  - macOS: `lsof -nP -iTCP:53000 -sTCP:LISTEN`
- 현재 로그인된 Flutter 실행 파일이 동작 가능한지 확인
  - `flutter --version`
  - macOS: `/Users/sejin/development/flutter/bin/flutter --version`
- 인앱 브라우저에서 200 응답 확인 (필요 시 즉시 실행 여부 판단)
  - `Invoke-WebRequest -Uri http://127.0.0.1:53000/ -UseBasicParsing -TimeoutSec 5`
  - macOS: `curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:53000/`

## 2) 기존 상태 정리 (필요 시)

- 새 세션 시작 전 기존 PID 파일이 있으면 정리
  - `Remove-Item flutter_web_server.pid -ErrorAction SilentlyContinue`
- 포트 점유 중이면 해당 프로세스를 확인해 종료
  - `Get-NetTCPConnection -LocalPort 53000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }`
- 로그 파일은 새 실행 전에 비워두면 원인 추적이 쉬움
  - `Remove-Item flutter_web_server.out.log, flutter_web_server.err.log -ErrorAction SilentlyContinue`

## 3) Windows 서버 기동 (권장)

- 상태 확인:

```powershell
.\scripts\in_app_server.ps1 -Action status
```

- 반복 개발용 foreground 서버:

```powershell
.\scripts\in_app_server.ps1 -Action dev
```

같은 세션에서 Dart 코드를 수정한 뒤에는 터미널에 `r`을 입력해 hot reload를 보내고, 인앱 브라우저 탭을 새로고침한다.

- 큰 변경 또는 실제 `build\web` 산출물 확인:

```powershell
.\scripts\in_app_server.ps1 -Action restart
```

> 주의: 이전 실행 이력에서 `--web-renderer` 옵션이 특정 Flutter 버전에서 실패한 로그가 남았습니다.
> 따라서 본 가이드에서는 `--web-renderer`를 사용하지 않습니다.

## 4) 기동 완료 확인

- 3초 대기 후 로그 확인
  - `Get-Content flutter_web_server.out.log -Tail 120`
  - `Get-Content flutter_web_server.err.log -Tail 120`
- 포트 바인딩 확인
  - `Get-NetTCPConnection -LocalPort 53000 -State Listen -ErrorAction SilentlyContinue | Format-Table -AutoSize`
- 브라우저 접속 주소
  - `http://127.0.0.1:53000`

## 5) Windows 종료

```powershell
.\scripts\in_app_server.ps1 -Action stop
```

## 5-1) macOS Codex 빠른 경로

macOS에서는 Windows용 `scripts/in_app_server.ps1`을 쓰지 않는다. Codex 세션에서는 아래 순서를 기본 경로로 사용한다.

1. 워크트리로 이동한다.

```bash
cd /Users/sejin/Documents/RuneNexus
```

2. 53000 포트 상태를 확인한다.

```bash
scripts/in_app_server_macos.sh status
```

3. 수정 파일을 포맷하고 관련 테스트를 먼저 실행한다.

```bash
scripts/in_app_server_macos.sh dart format <수정 파일>
scripts/in_app_server_macos.sh flutter test <관련 테스트 파일>
```

4. 반복 개발 중이면 Flutter 개발 서버를 foreground 세션으로 띄운다.

```bash
scripts/in_app_server_macos.sh dev
```

같은 세션에서 Dart 코드를 수정한 뒤에는 터미널에 `r`을 입력해 hot reload를 보내고, 인앱 브라우저 탭을 새로고침한다.

큰 변경이거나 실제 `build/web` 산출물 확인이 필요할 때만 최신 웹 빌드를 만들고 정적 서버를 foreground 세션으로 띄운다.

```bash
scripts/in_app_server_macos.sh restart
```

5. 인앱 브라우저를 개발 서버 주소 또는 스크립트가 출력한 cache-bust URL로 연다. 이미 탭이 열려 있다면 Browser 플러그인으로 reload 명령을 보낸다.

URL만 다시 확인해야 하면 다음을 사용한다.

```bash
scripts/in_app_server_macos.sh url
```

Codex에서는 Browser 플러그인의 인앱 브라우저에 직접 연다. macOS `open` 명령으로 외부 브라우저를 띄우지 않는다.

6. 화면 확인 후 서버 세션에 `Ctrl-C`를 보내 종료한다. 별도 정리가 필요하면 다음을 사용한다.

```bash
scripts/in_app_server_macos.sh stop
```

macOS 주의:

- 반복 개발 중에는 `scripts/in_app_server_macos.sh dev`를 우선 사용하고, hot reload 후 인앱 브라우저 새로고침으로 확인한다. 큰 변경이나 전체 웹 산출물 확인이 필요할 때만 `restart`를 사용한다.
- `python3 -m http.server ... &` 백그라운드 기동은 세션 종료와 함께 바로 죽을 수 있다. 인앱 확인 중에는 foreground 세션을 유지한다.
- Flutter SDK 캐시 접근, 포트 바인딩, 프로세스 종료가 `Operation not permitted`로 실패하면 같은 명령을 반복하지 말고 샌드박스 밖 실행 승인을 요청한다.
- 기존 53000 포트 프로세스를 종료해야 하면 다음 명령을 사용한다.

```bash
scripts/in_app_server_macos.sh stop
```

## 6) 실패 원인 체크리스트

- 53000 포트가 이미 점유됨
  - 기존 프로세스가 살아 있는지 확인 후 종료 후 재실행
- 프로세스가 즉시 죽음
  - `err.log`의 마지막 라인을 먼저 확인
- 실행이 느리거나 정지됨
- 앱에서 보인다고 해도 화면이 갱신되지 않을 때
  - 개발 서버 사용 중이면 터미널에 `r`을 보낸 뒤 인앱 브라우저 탭을 새로고침
  - 브라우저 캐시 우회 주소 사용:
  - `http://127.0.0.1:53000/?cache_bust=$(Get-Date -Format yyyyMMddHHmmss)`
  - 캐시 이슈 의심 시 53000 서버 재시작 후 재확인
- 브라우저 접속은 되지만 화면이 안 나올 때
  - `out.log`에서 `lib/main.dart is being served at ...` 메시지 존재 여부 확인
  - `err.log`에 `Could not find an option named "--web-renderer".`가 있으면 해당 실행은 실패로 간주하고 재기동
- 서버 프로세스 확인만으로 오판될 때
  - PID 파일만 존재하면 오해의 소지가 있으므로 `Get-NetTCPConnection`으로 실제 LISTEN 상태를 추가 확인

## 7) 기록 규칙

- 인앱 테스트 요청이 들어오면 위 순서를 기본 흐름으로 사용
- 임시 판단이 아니라 위 항목을 기준으로 `기동 실패/성공/종료`를 분리 기록
- 같은 패턴을 반복하면 포트 점유/로그 미생성/옵션 미일치로 인한 지연이 줄어듭니다.
