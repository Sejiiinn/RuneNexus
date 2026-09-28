# 우편함 Godot 검증

> 원시 로그·일회성 검사·측정 덤프는 로컬 기록으로 Git 추적에서 제외했다. 본문의 요약 결과와 유지되는 회귀 테스트는 보존하며, 아래 로컬 기록은 새 체크아웃에 포함되지 않는다.

최신 후속 변경: [자동 페이지 로드 구현·검증](auto-pagination/verification.md).

- 승인 시안: `../proposal.png`
- 격리 fake service 검사: Godot 4.7.2, 최종 `checks=23`, `failures=[]`
- 기존 로비 스모크 `verify_lobby.gd`: PASS
- 독립 Astra 검증: 동작 28개 검사 및 최종 영향 27개 검사 PASS. 독립 검증 기록 (`independent-validation.log`, 로컬 기록), [320px 하단 우편 최종 화면](mailbox-320-lower-expanded.png). 최종 화면은 부모도 직접 확인했다.
- 실제 Godot 렌더: GUI CLI 종료 코드 0, 시각 변경본 `checks=20`, `failures=[]`
- 캡처: `mailbox-440-collapsed.png`, `mailbox-440-expanded.png`, `mailbox-320-collapsed.png`, `mailbox-320-expanded.png`
- 검증 범위: 기본 접힘, 단일 펼침·재접힘, 늦은 읽음 응답의 선택 유지·중복 방지, 추가 페이지 유지, 개별·모두 받기 진입, 440·320 화면, UTC 만료일의 KST 표시, 320에서 마지막 우편을 펼친 뒤 스크롤과 본문 가시성 유지. 실제 계정과 서버는 사용하지 않음.

재현 명령(저장소 루트에서 실행):

```sh
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import tempfile
from scripts.run_godot_native_regressions import godot_executable, prepare, run_script

work = Path(tempfile.mkdtemp(prefix='rn-mailbox-ui-'))
project = prepare(work, godot_executable())
run_script(godot_executable(), project, 'verify_mailbox_ui.gd', '"failures":[]', work)
capture = Path('design/lobby/mailbox/restoration-preview/implementation').resolve()
process = subprocess.run(
    [godot_executable(), '--path', str(project), '--script', 'res://verify_mailbox_ui.gd'],
    env={**os.environ, 'MAILBOX_CAPTURE_DIR': str(capture)},
    text=True, capture_output=True, timeout=60,
)
print(process.stdout, process.stderr)
raise SystemExit(process.returncode)
PY
```
