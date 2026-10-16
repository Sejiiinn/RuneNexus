# Git 커밋 절차

역할: 커밋 범위 선정·스테이징 검증·푸시 확인 절차. 정리: 2026-10-16 KST. 메시지 형식·추적 대상 기준은 [AGENTS.md 커밋](../AGENTS.md#커밋), 실행 권한은 [권한 기준](../.agents/sandbox_command_guide.md)을 따른다. 별도 승인 정책을 만들지 않는다.

## 원칙

- 작업 범위가 섞여 있으면 `git add -A`·`git add .`를 쓰지 않고 커밋 대상 경로를 명시한다.
- 성격이 다른 변경은 커밋을 나눈다. 같은 파일에 두 성격이 섞이면 부분 스테이징한다.
- 파일 이동·이름 변경은 `git mv`로 기록하고, 이동 전후 내용이 같은지(`R100`) 확인한다.
- 이미 추적 중인 파일은 `.gitignore`만으로 제외되지 않는다. 추적 해제는 승인 범위 안에서 로컬 파일을 보존하며 별도로 수행한다.
- 커밋·푸시는 요청이나 기존 승인 범위에 있을 때만 수행한다.

## 표준 절차

1. 상태와 기존 스테이징 확인. 다른 작업이 미리 스테이징한 파일이 섞이지 않게 한다.

```bash
git status --short --branch
git diff --cached --name-only
git log --oneline --decorate -5
```

2. 대상 diff 확인 후 명시 스테이징

```bash
git diff -- <파일1> <파일2>
git add -- <파일1> <파일2>
```

3. 스테이징 검증. 파일 목록·추가/삭제 줄 수로 대량 산출물이 섞였는지 본다.

```bash
git diff --cached --stat
git diff --cached --check
git diff --cached
```

Markdown을 바꿨으면 스테이징 뒤 `python3 scripts/check_doc_links.py --changed`로 링크·앵커를 확인한다([문서 완료 확인](documentation_guide.md#완료-확인)).

4. 커밋. 메시지는 한글, `feat:`·`fix:`·`refactor:`·`chore:` 중 하나로 시작한다.

```bash
git commit -m "<prefix>: <한글 메시지>"
git show --stat --oneline HEAD
git status --short --branch
```

권한 오류(예: `.git/index.lock: Permission denied`)는 남은 lock 파일뿐 아니라 실행 환경의 쓰기 제한에서도 생긴다. 원인을 확인하고 [권한 기준](../.agents/sandbox_command_guide.md)에 따라 처리한다.

## 커밋하지 않는 로컬 산출물

아래는 기본적으로 로컬 보관 대상이다. 대부분 `.gitignore`에 규칙이 있으며, 새 작업 폴더에서 같은 종류가 생기면 해당 경로 규칙을 추가한다. 요청과 직접 관련된 확정 원본·대표 검증 화면은 구분해 스테이징한다.

- 실행·검사 로그(`*.log`), 원시 측정 덤프, 일회성 검사 스크립트
- 인게임 검증의 격리 저장 폴더(`isolated-save-*/`)와 캡처 스크립트 출력(`captures/`, `turn-captures/`)
- 원본에서 다시 렌더할 수 있는 미리보기 프레임(`frames/`, `tile-frames/`). 아틀라스·패킹 입력이면 추적 대상이다.
- Blender 세션 보존본(`design/blender_sessions/`)과 자동 백업(`*.blend1` 등)
- 생성 디렉터리(`build/`, `.godot/`, `__pycache__/`)
- 제거한 Flutter 플랫폼 폴더(`ios/`, `linux/`, `macos/`, `windows/`, `android/`)에 남은 생성 파일

## 푸시 전 확인

현재 브랜치가 `origin/main`보다 여러 커밋 앞서 있을 수 있다.

```bash
git fetch origin
git log --oneline origin/main..HEAD
```

푸시할 커밋이 모두 요청·승인 범위에 포함되면 재승인 없이 진행한다. 무관한 커밋이 섞여 범위를 판단할 수 없을 때만 사용자에게 확인한다. `main` 푸시는 APK 배포를 시작하지 않는다(`deploy-apk.yml`은 수동 실행).
