# Codex Git 커밋 가이드

실행 권한은 [현재 권한 가이드](../.agents/sandbox_command_guide.md)를 따른다. 아래는 커밋 범위·검증 절차이며 별도 승인 정책을 만들지 않는다.

## 반복 문제

Codex 샌드박스 환경에서는 `git add` 또는 `git commit`이 아래 오류로 실패할 수 있다.

```text
fatal: Unable to create '.git/index.lock': Permission denied
```

이 문제는 실제 `.git/index.lock` 파일이 남아 있어서만 발생하는 문제가 아니다. 현재 실행 권한 경계에서 `.git` 메타데이터 쓰기가 막혀 생길 수 있다.

## 원칙

- 작업 범위가 섞여 있으면 `git add -A`를 사용하지 않는다.
- 커밋 대상 파일을 명시한다.
- 서버 로그, PID 파일, 스크린샷, 플랫폼 generated 줄바꿈 변경은 별도 요청 없이는 커밋하지 않는다.
- 실제 권한 오류가 나면 원인을 확인하고 현재 세션 정책이 허용하는 경우에만 필요한 실행 권한을 요청한다.
- 명령 이름이나 예상 오류만으로 사전 승인을 요청하지 않는다. 승인 요청이 금지된 세션에서는 확대 요청·우회를 하지 않는다.

## 표준 절차

1. 상태 확인

```powershell
git status --short --branch
git log --oneline --decorate -5
```

2. 커밋 대상 diff 확인

```powershell
git diff -- <파일1> <파일2>
```

3. 명시 스테이징

```powershell
git add -- <파일1> <파일2>
```

권한 오류 시 현재 권한 가이드에 따라 처리한다.

4. 스테이징 검증

```powershell
git diff --cached --name-only
git diff --cached --stat
git diff --cached --check
git status --short --branch
```

5. 커밋

```powershell
git commit -m "<prefix>: <한글 메시지>"
```

실제 권한 오류 시 현재 권한 가이드에 따라 처리한다.

6. 커밋 결과 확인

```powershell
git log --oneline --decorate -4
git show --stat --oneline --name-status HEAD
git status --short --branch
```

## 임시 산출물과 생성 파일 예시

다음 항목은 보통 임시 산출물이다. 요청과 직접 관련된 확정 디자인 원본·기준 캡처와 구분해 스테이징한다.

- `flutter_web_server.err.log`
- `flutter_web_server.out.log`
- `flutter_web_server.pid`
- `ui-candidate-screenshots/`
- `linux/flutter/generated_*`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_*`

## 푸시 주의

현재 브랜치가 `origin/main`보다 여러 커밋 앞서 있을 수 있다. 푸시 전에는 반드시 아래를 확인한다.

```powershell
git log --oneline origin/main..HEAD
```

푸시할 커밋이 기존 요청·승인 범위에 포함되는지 확인한다. 포함되면 재승인 없이 진행하고, 무관한 커밋이 섞여 있어 범위를 판단할 수 없을 때만 사용자에게 확인한다.
