---
name: codex-verify
description: Claude가 구현을 마친 변경을 Codex CLI(gpt-6-astra, reasoning high)에게 독립 검증받는다. RuneNexus에서 UI·시각 작업, 저장·전투·API 계약 변경, 여러 시스템에 걸친 변경, 복잡한 버그 수정을 끝낸 뒤 완료 보고·커밋 전에 사용한다. 단순 문구·문서 정리나 자동 대조로 판정되는 기계적 변경에는 쓰지 않는다.
---

# Codex 독립 검증

전제: 이 PC에 Codex CLI(`codex`)가 설치·로그인되어 있어야 한다. 없거나 실행에 실패하면 그 사실을 사용자에게 알리고, 다른 도구로 몰래 대체하지 않는다.

구현은 Claude가, 독립 검증은 Codex가 맡는다. Codex는 `gpt-6-astra` + `model_reasoning_effort=high`로 고정한다(사용자 지정, 스크립트에 고정). 다른 모델로 바꾸지 않는다.

## 언제

- 대상: AGENTS.md 「독립 검증 적용」 기준과 같다. UI·시각, 저장·전투·API 계약, 여러 시스템, 복잡한 버그 수정.
- 생략: 단순 문구·문서 정리, 자동 대조로 완료를 명확히 판정할 수 있는 기계적 변경. 사용자 요청이나 프로젝트 필수 검증은 생략하지 않는다.
- 시점: Claude가 구현·관련 기본 검사·발견 결함 수정을 끝낸 뒤, 완료 보고·커밋 전.

## 검증 요청 작성

스크래치패드에 `verify-request.md`를 쓴다. 한국어로, 아래를 모두 넣는다.

1. 원래 요청: 사용자 원문 인용과 이번 범위의 최근 사용자 교정.
2. 변경 범위: 대상 파일 또는 `git diff <범위>`. 미커밋이면 "작업 트리의 해당 파일".
3. 보존할 계약·승인 원본: 저장·API·전투 계약, 승인 시안 경로와 보존할 형태·색·재질.
4. 완료 조건: 검증자가 PASS/FAIL을 판정할 항목 목록.
5. 사용자가 지적했던 실패 모습(있으면).
6. Claude가 수행한 검사와 결과: 참고용임을 밝힌다. 검증자는 이를 재인용해 PASS를 대신하지 않는다.
   - 실제 렌더 화면이 필요한 UI·시각 항목은 Claude가 찍은 캡처 경로를 넣는다. Codex는 샌드박스 때문에 창 모드 Godot을 띄울 수 없어(스크립트가 `--headless` 전용 제약을 요청 앞에 자동으로 붙임) 캡처를 직접 만들지 못한다.
7. 규칙: 소스·문서·에셋을 수정하지 않는다. 커밋·푸시·APK 빌드를 하지 않는다(AGENTS.md 허용 조건 밖). 검사 출력은 `build/` 또는 `/tmp`에 둔다. 결함은 재현 조건·기대 결과·실제 결과로 보고하고 고치지 않는다.
8. 보고 형식: 완료 조건별 PASS/FAIL/미확인, 근거(명령·경로·화면), 미해결 사항. 한국어.

## 실행

```bash
python3 .claude/skills/codex-verify/scripts/codex_verify.py \
  --prompt-file <스크래치패드>/verify-request.md \
  --out <스크래치패드>/verify-report.md
```

- 수 분에서 수십 분 걸린다. Bash `run_in_background: true`로 실행하고 완료 알림을 기다린다. 기본 제한 시간 3600초.
- stdout JSON: `ok`, `report`, `codex_exit`, `error`, `head_changed`, `worktree_changed_by_codex`.
- `worktree_changed_by_codex`나 `head_changed`가 있으면 Codex가 규칙을 어긴 것이다. 그 변경을 확인해 되돌리거나 사용자에게 알린다. 검사 실행이 만든 무시 대상 파일은 목록에 나오지 않는다.

## 결과 처리

1. `verify-report.md`를 읽는다. FAIL은 Claude가 고친 뒤, 영향받는 항목만 다시 검증 요청한다(같은 전체 검증을 반복하지 않는다).
2. 미확인 항목은 이유와 함께 사용자 보고에 남긴다. 통과로 바꾸지 않는다.
3. 사용자에게 검증 결과 요약(조건별 PASS/FAIL/미확인)을 함께 보고한다.
4. Codex 실행 실패·시간 초과는 독립 검증 미수행으로 보고하며 통과로 처리하지 않는다.
