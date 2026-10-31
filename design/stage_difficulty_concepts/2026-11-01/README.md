# 스테이지 난이도 화면 시안 (2026-11-01)

실제 게임 캡처 위에 하드 난이도 요소만 덧그린 HTML 합성 시안이다. 탭·테두리·버튼 색·말풍선·ⓘ는 이미지 편집으로 흉내 낸 것이며 실제 에셋이 아니다. 보상 아이콘은 기존 게임 에셋(`assets/images/stage_rewards/`, `assets/images/turret_modules/icons/`)을 썼다. 채택한 방향은 [로비 화면 결정](../../../docs/design_decisions/lobby.md)의 「스테이지 난이도」 행이 원본이다.

| 파일 | 상태 | 바탕 캡처 |
| --- | --- | --- |
| `01-normal-hard-locked.jpg` | 3-5 노말 선택, 노말 미클리어라 하드 탭 잠김 | [스테이지 지도 홈 적용 캡처](../../stage_map_concepts/2026-10-27/implemented/home_ch3_440x900.png) |
| `02-hard-selected.jpg` | 하드 선택(3-5 노말 클리어 가정). 룬 ×1.5, 룬 옆 반복 보상, 오른쪽 위 하드 첫 클리어 모듈권 | 위와 같음 |
| `03-hard-reward-tooltip.jpg` | 반복 보상 아이콘을 눌렀을 때의 한 줄 말풍선 | 위와 같음 |
| `04-core-points-tooltip.jpg` | 코어 화면 「획득」 옆 ⓘ를 눌렀을 때 스테이지 첫 클리어 보상 말풍선 | `verify_expanded_core_ui.gd`를 화면 모드로 실행해 얻은 2026-10-30 코어 화면(검사 저장 기준 획득 60P) |

## 실제 적용 캡처

시험용 진행 데이터를 넣은 실제 로비 코드(`godot/ui/lobby.gd`)를 데스크톱 Godot 창 모드 440×900으로 캡처했다. 1단계에는 하드 보상이 없어 반복 보상 아이콘과 오른쪽 위 보상 자리가 비어 있다. 룬 수치는 카드의 기존 축약 규칙(1만 이상은 K)을 따른다.

| 파일 | 상태 |
| --- | --- |
| `implemented/home_ch3_normal_hard_locked.jpg` | 3-5 노말 선택, 노말 미클리어라 하드 탭 잠김 |
| `implemented/home_ch3_hard_record.jpg` | 3-5 하드 선택, 하드 기록 23/40, 룬 ×1.5 배지 |

시안 한계: 02·03은 하드 상태인데 지도의 3-5 소켓이 미클리어 모양이다. 수치(3-5 하드 룬 11,949, 전리품 37%)는 [난이도 설계](../../../docs/stage_difficulty_design.md)의 공식으로 계산한 예시이며, 하드 첫 클리어 모듈권 양은 미정이다.
