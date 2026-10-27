# 스테이지 지도 홈 (2026-10-27)

별도 메인 로비를 없애고 스테이지 탭을 첫 화면으로 만든 지도 홈의 원본과 실제 적용 캡처. 결정은 [로비 디자인 결정](../../../docs/design_decisions/lobby.md)의 「스테이지 지도 홈」「스테이지 카드」를 따른다.

## 원본과 게임 에셋

| 원본(ImageGen) | 게임 에셋 | 용도 |
| --- | --- | --- |
| `chapter1_map_bg.png`, `chapter2_map_bg.png`, `chapter3_map_bg.png` | `assets/images/stage_map/chapter{1,2,3}_map.jpg` (853×1844) | 챕터 지도 배경. 발판 좌표는 `godot/ui/stage_map_view.gd`의 `SPOTS` |
| `node_socket_gold.png` | `assets/images/stage_map/node_socket_gold.png` (256px) | 선택 스테이지 소켓 |
| `stage_number_socket_v1.png` | `assets/images/stage_map/stage_number_socket.png` (227×256) | 카드의 스테이지 번호 소켓 |

지도 JPEG는 밉맵을 켠 손실(WebP) 가져오기로 앱에 들어간다(`scripts/prepare_godot_project.py`). 클리어·열림 소켓, 카드 프레임, 시작 버튼, 해금 아이콘 칸은 기존 에셋을 재사용한다.

## 실제 적용 캡처

실제 로비 코드(`godot/ui/lobby.gd`)에 시험용 진행 데이터를 넣어 Godot에서 캡처했다. 데스크톱 `--app`은 로그인 관문이 지도 홈을 가리므로 이 방식으로 확인했다.

- `implemented/home_ch3_440x900.png`: 3-5 선택, 해금 배지·룬 보상·이동 표시
- `implemented/home_ch3_tooltip.png`: 해금 아이콘 말풍선
- `implemented/home_ch3_locked.png`: 잠긴 스테이지 선택
- `implemented/home_ch1_active.png`: 진행 중 전투(이어서 진행)
- `implemented/home_ch2.png`: 모두 클리어한 챕터
- `implemented/home_ch3_440x760.png`, `implemented/home_ch3_880x760.png`: 짧은 화면 스크롤, 넓은 화면 배경
