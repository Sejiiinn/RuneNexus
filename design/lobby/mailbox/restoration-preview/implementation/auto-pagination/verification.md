# 우편함 자동 페이지 로드 검증

> 원시 로그·일회성 검사·측정 덤프는 로컬 기록으로 Git 추적에서 제외했다. 본문의 요약 결과와 유지되는 회귀 테스트는 보존하며, 아래 로컬 기록은 새 체크아웃에 포함되지 않는다.

- 마지막 우편 하단이 보이면 다음 cursor를 한 번 요청한다. 정상 ‘더 보기’ 버튼은 제거했고 실패 때만 ‘다시 시도’를 표시한다.
- 자동 요청은 기존 모달을 유지하며 본문만 갱신한다. 펼친 우편·읽음 상태·현재 스크롤을 보존한다.
- 짧은 첫 페이지는 한 번 자동 이어받는다. 이어받은 목록도 짧으면 아래 방향 휠·터치 스와이프로 계속 불러오며 연쇄 전체 preload를 막는다.
- 최종 격리 fake service 검사: Godot 4.7.2, headless·GUI 각각 `checks=40`, `failures=[]`, 종료 코드 0.
- 기존 `verify_lobby.gd` 스모크 PASS. 실제 계정·서버·사용자 저장을 사용하지 않았다.
- 독립 Astra 검증: headless 46개·실제 GUI 49개 검사 PASS. 독립 실행 로그 (`independent-validation.log`, 로컬 기록)에 최초 터치 결함과 수정 후 근거를 보존했다.
- 독립 Astra 검증: 최종 headless 46개·실제 Godot GUI 49개 검사 PASS. 모의 터치·휠 입력과 제목 클릭, 중복·실패·늦은 응답을 확인했다. 독립 검증 기록 (`independent-validation.log`, 로컬 기록). 부모도 최종 대표 화면을 직접 확인했으며 Android 실기기·APK 배포는 수행하지 않았다.
- 근거: 실행 로그 (`verification.log`, 로컬 기록), [440 접힘](mailbox-auto-440-collapsed.png), [440 펼침](mailbox-auto-440-expanded.png), [320 스크롤 전](mailbox-auto-320-before-scroll.png), [320 자동 로드 후](mailbox-auto-320-after-scroll.png), [320 마지막 우편 펼침](mailbox-auto-320-last-expanded.png).

검사 범위는 단일 펼침·재접힘·읽음 요청, 실제 휠 및 모의 터치 입력, 추가 페이지·중복 신호·같은 cursor, 실패와 명시 재시도, pending/busy 차단, 마지막 페이지 종료, 닫기·재진입 늦은 응답, 스크롤 보존 및 모두 받기 접근이다.

재현 명령(저장소 루트):

```sh
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import tempfile
from scripts.run_godot_native_regressions import godot_executable, prepare, run_script

work = Path(tempfile.mkdtemp(prefix='rn-mailbox-auto-'))
project = prepare(work, godot_executable())
run_script(godot_executable(), project, 'verify_mailbox_ui.gd', '"failures":[]', work)
run_script(godot_executable(), project, 'verify_lobby.gd', 'LOBBY_SMOKE_OK', work)
capture = Path('design/lobby/mailbox/restoration-preview/implementation/auto-pagination').resolve()
process = subprocess.run(
    [godot_executable(), '--path', str(project), '--script', 'res://verify_mailbox_ui.gd'],
    env={**os.environ, 'MAILBOX_CAPTURE_DIR': str(capture)},
    text=True, capture_output=True, timeout=60,
)
print(process.stdout, process.stderr)
raise SystemExit(process.returncode)
PY
```
