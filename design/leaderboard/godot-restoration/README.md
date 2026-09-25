# Godot 리더보드 복원

2026-09-25. 기준은 [이전 Flutter 구현 이미지](../implemented_preview.png), [화면 계약](../../../docs/leaderboard_design.md), [디자인 기준](../../../DESIGNS.md)이다.

순위·닉네임#태그·진행도를 분리하고, 트로피 헤더·상위 3위 금색·본인 청록 강조와 하단 고정 내 순위를 복원했다. 안전 영역 높이 84%에서 목록만 스크롤한다. 좁은 화면의 큰 글자는 진행도를 아래로 배치하며, 기준시각·동점 설명을 ‘순위 안내’로 열 수 있다. 본인 기록의 확정 시각은 별도 팝업으로 표시하여 하단 영역의 높이를 유지한다. 서버/API·저장·순위 계산 계약은 변경하지 않았다.

## 실행 근거

실제 Godot 로비·리더보드 컴포넌트를 [검수 스크립트](../../../godot/verify_leaderboard_ui.gd)에서 실행했다. 계정·저장과 분리한 모의 서버 응답이며, 이미지 속 플레이어와 순위는 운영 데이터가 아니다.

- Godot 4.7.2 stable, macOS Apple M4, OpenGL Compatibility 렌더러.
- 440×900, 320×568, 320×568에서 실제 글꼴 크기 2배. 확대 상태에는 최대 8한글 본인 닉네임과 태그를 사용했다.
- [상태·입력 검사 로그](render-check.log): 77개 검사, 실패 0. 목록 스크롤·내 순위 고정, 새로고침 입력, 터치 탭/드래그 구분, 확정 시각, 안내 팝업, 로딩·빈 목록·오류 시 기존 기록 유지·게스트·닫기·일반 모달 크기를 검사했다. 긴 본인 이름·글자 2배·갱신 실패의 조합에서도 오류 안내를 목록 내부에 배치해 고정 영역과 스크롤 접근을 유지했다. 데스크톱 터치 검사는 `Input.set_emulate_touch_from_mouse(true)`로 엔진의 터치 에뮬레이션을 활성화했다.
- 관련 기존 검사: `verify_lobby.gd`의 `LOBBY_SMOKE_OK`, `verify_menu_shell_parity.gd`의 `PASS menu shell` 확인.
- [헤드리스 회귀](headless-check.log)도 77개 검사·실패 0. 별도 Astra 검증자가 원본·최종 코드·실제 캡처를 대조해 PASS 판정했으며, 부모도 최종 화면을 직접 확인했다.
- Android APK 빌드·실기기 및 운영 서버 조회는 이번 검증 범위에 포함하지 않았다.

| 실제 렌더 | 근거 |
| --- | --- |
| 일반 화면 | [440px](leaderboard-440.png), [320px·긴 이름](leaderboard-320.png) |
| 글자 2배·긴 본인 이름 | [확대 화면](leaderboard-320-large-text.png) |
| 확정 시각·순위 안내 | [행 선택](leaderboard-record-detail.png), [확대 안내](leaderboard-large-text-guide.png), [내 기록](leaderboard-large-text-my-record.png) |
| 오류·빈 목록 | [갱신 실패](leaderboard-refresh-error.png), [확대·긴 이름·갱신 실패](leaderboard-large-text-refresh-error.png), [빈 목록](leaderboard-empty.png) |

관련 소스·공유 스타일·폰트·아이콘·실행 설정의 해시는 [검증 입력](verification-inputs.json)에 기록한다. 확대 화면에서도 목록 내부 스크롤로 긴 행 전체를 확인하며, 고정 영역과 팝업은 화면 안에 유지된다.
