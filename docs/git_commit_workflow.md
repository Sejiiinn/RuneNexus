# Codex Git 커밋 가이드

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
- `git add`가 권한 오류로 실패하면 같은 명령을 반복하지 말고 승인 경로로 한 번만 재실행한다.
- `git commit`도 권한 오류가 예상되면 승인 경로로 실행한다.

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

권한 오류가 나면 같은 명령을 승인 경로로 재실행한다.

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

권한 오류가 예상되거나 발생하면 승인 경로로 실행한다.

6. 커밋 결과 확인

```powershell
git log --oneline --decorate -4
git show --stat --oneline --name-status HEAD
git status --short --branch
```

## 이번 커밋에서 확인된 제외 대상

다음 항목은 UI/문서 변경의 핵심 범위가 아니므로 커밋에서 제외한다.

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

사용자가 특정 커밋만 푸시하라고 하지 않았고 브랜치가 여러 커밋 앞서 있으면, 어떤 커밋까지 원격에 올릴지 명시 확인을 받는다.
