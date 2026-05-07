# 인앱 테스트 실행 가이드 (웹 서버 기동 정규 절차)

이 문서는 매번 동일한 방식으로 인앱 테스트 화면을 띄우기 위한 정해진 절차입니다.

## 1) 실행 전 확인

- 워크트리 기준 경로:
  - `C:\Users\rlatp\Documents\RuneNexus`
- 대상 포트: `53000`
- 이미 떠 있는 기존 테스트 서버가 있는지 확인
  - `Get-NetTCPConnection -LocalPort 53000 -State Listen -ErrorAction SilentlyContinue`
- 현재 로그인된 Flutter 실행 파일이 동작 가능한지 확인
  - `flutter --version`
- 인앱 브라우저에서 200 응답 확인 (필요 시 즉시 실행 여부 판단)
  - `Invoke-WebRequest -Uri http://127.0.0.1:53000/ -UseBasicParsing -TimeoutSec 5`

## 2) 기존 상태 정리 (필요 시)

- 새 세션 시작 전 기존 PID 파일이 있으면 정리
  - `Remove-Item flutter_web_server.pid -ErrorAction SilentlyContinue`
- 포트 점유 중이면 해당 프로세스를 확인해 종료
  - `Get-NetTCPConnection -LocalPort 53000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }`
- 로그 파일은 새 실행 전에 비워두면 원인 추적이 쉬움
  - `Remove-Item flutter_web_server.out.log, flutter_web_server.err.log -ErrorAction SilentlyContinue`

## 3) 서버 기동 (권장)

- 백그라운드 실행 (로그 파일 분리)
  - 
    ```powershell
    $work = "C:\Users\rlatp\Documents\RuneNexus"
    $proc = Start-Process -WindowStyle Hidden `
      -WorkingDirectory $work `
      -FilePath flutter `
      -ArgumentList @('run','-d','web-server','--web-hostname=127.0.0.1','--web-port=53000','-t','lib/main.dart') `
      -RedirectStandardOutput (Join-Path $work "flutter_web_server.out.log") `
      -RedirectStandardError (Join-Path $work "flutter_web_server.err.log") `
      -PassThru
    $proc.Id | Out-File (Join-Path $work "flutter_web_server.pid")
    Write-Output "STARTED_PID=$($proc.Id)"
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

## 5) 종료

- PID 기반 정지
  - `if (Test-Path flutter_web_server.pid) { Stop-Process -Id (Get-Content flutter_web_server.pid | ForEach-Object { [int]($_ -as [string]).Trim() }) -Force -ErrorAction SilentlyContinue }`
- PID 파일 및 로그 정리
  - `Remove-Item flutter_web_server.pid,flutter_web_server.out.log,flutter_web_server.err.log -ErrorAction SilentlyContinue`

## 6) 실패 원인 체크리스트

- 53000 포트가 이미 점유됨
  - 기존 프로세스가 살아 있는지 확인 후 종료 후 재실행
- 프로세스가 즉시 죽음
  - `err.log`의 마지막 라인을 먼저 확인
- 실행이 느리거나 정지됨
- 앱에서 보인다고 해도 화면이 갱신되지 않을 때
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
