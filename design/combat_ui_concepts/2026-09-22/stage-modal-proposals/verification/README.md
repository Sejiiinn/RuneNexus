# 스테이지 모달 02 독립 검증

최종 판정: **PASS** (2026-09-22, Godot 데스크톱). 기준은 [criteria.md](criteria.md)와 승인 원본 상단 오른쪽 02. 검증 담당은 구현 코드를 변경하지 않았다.

## 직접 확인

- 승인 원본과 최종 실제 캡처를 직접 비교했다. 중앙 제목·상태 pill, 상단 룬, 금색 코너와 청록 석재, 3열 지표, 넓은 보상 행, 청록 시작 버튼을 보존한다. 보상 아이콘은 기존 게임 아이콘을 유지한다. 440 기본 모달은 390×390, 320은 읽기 가능한 자연 높이로 표시된다. 320 잠금 단계의 긴 연구명도 16px로 전체 표시된다. 모서리 이음새·내용 겹침·세로글자·외곽 잘림은 발견하지 않았다.
- 실제 `main.tscn → AppLifecycle → Lobby`로 실행했다. FakeHost나 pressed.emit을 사용하지 않고 viewport 마우스 이동/누름/해제 이벤트를 주입했다. 단계 8 잠금 무동작, 11 최초 보상, 1 시작 및 실제 native combat 활성화를 확인했다.
- 애니메이션 ON. 같은 모달 440→320→440, 닫기 후 재진입, 애니메이션 도중 physical 900→1100→900에서 중앙 위치·경계·최종 scale 1을 확인했다. logical 440×760/physical 440×900 조건을 포함한다. 지연 후 위치 복귀도 없었다.
- 최종 코드 3개와 PNG 6개는 실행 복사본과 SHA-256이 동일하다. 격리 manifest의 이전 목록은 발견 즉시 전달해 최신본으로 동기화했고 현재 원본과 동일하다. 실제 검증 실행 시에도 PNG 6개는 모두 최종본이었다. [source-hashes.json](source-hashes.json)
- [strict-live.log](strict-live.log): 프로세스 exit 0, 모든 검사 PASS, ERROR/SCRIPT ERROR/WARNING 없음.

대표 직접 캡처: [440 단계1](strict-real-stage1.png), [320 단계8](strict-real-320-stage8.png), [440 단계11](strict-real-stage11.png). 나머지 320/440 단계별 캡처도 같은 디렉터리에 있다. 재현 하네스: [strict_live.gd](strict_live.gd).

## 구조 감사

`stage_detail_theme.gd`의 StyleBoxTexture가 완성 PNG와 고정 texture margins를 사용하고 content margins는 독립 설정한다. `lobby_stages.gd`는 Panel/VBox/HBox/Label/Scroll 구조다. 프레임 수동 9조각·전체 UI 강제 축척은 없다. 기존 보상 포탑 아이콘의 draw 구현은 이번 프레임 대체 대상이 아니며 기존 아이콘 보존 범위다. `lobby.gd`의 배치 wrapper/애니메이션 wrapper 분리와 고정 헤더/본문 스크롤 구조도 보존했다.

## 다른 담당 근거와 한계

구현 담당의 최종 [320/짧은 창 검사](../../stage-modal-v2/final-layout-test.log)는 단계 1/8/11 실제 입력, 16px 보상 문구, 짧은 320×260 창의 스크롤과 닫기 접근을 확인했다. 해당 로그의 마지막 공용 문구는 320/440이라 쓰여 있지만 최종 추가 실행 범위는 320이다. 독립 실제 앱 검사는 위와 같이 두 폭 모두 실행했다.

부모는 사용자 실행의 Forward Mobile 실제 화면과 최종 입력 해시를 별도로 확인했다: `user-live-final.png`, `user-live-inputs.json` 등 이 디렉터리의 user-live 산출물. 독립 검증은 별도 `modal-v2-review` 프로젝트와 `RuneNexus-modal-v2-review` userdata에서 GL Compatibility로 수행했으며 사용자 실행과 저장을 건드리지 않았다. Android 실기기·터치·배포 검증은 하지 않았고 이 PASS 범위에 포함하지 않는다. 미해결 결함 없음.
