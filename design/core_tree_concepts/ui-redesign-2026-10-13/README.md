# 코어 스킬트리 UI 개선 시안 (2026-10-14 승인·인게임 반영)

현재 v5 트리 화면의 구조 개선 제안. 실제 게임 에셋(`assets/images/core_passive_tree/`)과 v5 좌표(`tree_data.js`, `core_passive_tree_v5.json`·`core_tree_visuals.json`에서 추출)로 그린 440×900 HTML 시안이다. 상·하단 앱 크롬은 현재 캡처를 잘라 사용했다.

- `board-2026-10-13.png`: 현재 / A 전체 보기 / B 투자 계획 중 / C 노드 상세 / D 코어 스킬 비교
- `mockup.html`: 조작 가능한 프로토타입. 드래그·휠·두 손가락 확대, 노드 선택과 −/+ 투자, 적용·되돌리기·전체 초기화, 가운데 룬을 눌러 스킬 장착을 v5 해금 규칙대로 시험한다. 파일을 직접 열면 상대 경로 에셋이 로드되지 않으므로 저장소 루트에서 `python3 -m http.server 8765 --bind 127.0.0.1`로 띄운 뒤 `http://127.0.0.1:8765/design/core_tree_concepts/ui-redesign-2026-10-13/mockup.html`로 연다. `#planning`·`#detail`·`#skill`은 캡처용 초기 상태다.
- 시나리오: 적용 19P(S6 5, A01 3, B01 3, S1 2), 계획 +7P(C02 2, B02 1)

- 진행 모델: 라이트 유저는 고른 경로를 키우고(선택형), 장기 플레이어는 결국 대부분을 채운다(수집형, 탭타이탄2와 유사). 그래서 남은 포인트를 상한처럼 보이지 않게 표시하고, 영역별 진행도와 최대 등급 상태를 따로 보여 준다.

- 버튼·패널·닫기·명패는 기존 에셋(`combat_components/native`, `ui/components`, `skill_nameplate_v1`)과 게임의 9분할 여백을 그대로 쓴다. 새 이미지는 만들지 않았다.

확정 결정은 [로비·메뉴 화면](../../../docs/design_decisions/lobby.md)에 기록한다.
