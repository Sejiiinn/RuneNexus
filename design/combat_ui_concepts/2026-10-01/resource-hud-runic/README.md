# 상단 자원 HUD 룬 프레임 제작 원본

역할: 승인된 [3번 프레임](../../2026-09-30/target-priority/frame-concepts/03-runic-edge.png)의 청동 모서리를 보존한 초기 가로형 원본과 당시 검증 근거. 확인: 2026-10-01. 현재 상단 HUD는 사용자 가독성 요청에 따른 [슬림 파생본](slim/README.md)을 사용한다.

[게임용 PNG](../../../../assets/images/ui/hud/resource_runic_panel.png)는 104×88 RGBA이며 논리 픽셀과 소스 픽셀을 1:1로 사용한다. `resource-hud-runic-panel.xcf`에 원본 코너·룬 띠와 연속 남청색 내부 복원 레이어를 보존했다.

입력은 기존 [104×180 공격 목표 프레임](../../../../assets/images/ui/hud/target_priority/frame.png)이다. 기존 GIMP MCP·UI의 복사·붙여넣기·정수 픽셀 이동으로 빈 직선 구간만 줄였다.

| 입력 행 | 최종 행 | 보존 영역 |
| --- | --- | --- |
| 0–20 | 0–20 | 상단 청동 코너와 금속 가로 테두리 |
| 51–96 | 21–66 | 청록 룬 및 금속 룬판의 위·아래 사선 어깨 |
| 159–179 | 67–87 | 하단 청동 코너와 금속 가로 테두리 |

빈 내부는 위 `#07131e`에서 아래 `#04090e`로 이어지는 연속 배경으로 정리했다. 외곽 알파·코너·룬 픽셀을 보존했다.

9patch texture 고정 여백은 **좌 22 / 위 67 / 우 22 / 아래 18px**을 권장한다. 금속 코너의 청동색 픽셀은 좌측 최대 x18, 우측 가장자리에서 최대 15px까지 분포하며 22px 고정 영역으로 코너 끝부분까지 보호한다. 높이 고정 영역 합계는 85px이므로 기존 94px HUD에 들어간다. 좌우 룬판과 코너는 가로 늘림에서 제외하며 룬판 아래의 직선 구간만 세로로 늘린다. 콘텐츠 여백은 기존 **상하좌우 8px**을 유지한다.

## 실제 적용·통합 검증

`battle_hud.gd`의 `ResourceHUD`만 이 PNG의 `StyleBoxTexture`로 연결했다. 정보 배치·폰트·여백·다른 HUD 프레임은 기존 상태를 유지한다. 관련 `verify_battle_hud.gd` 회귀가 통과했다.

별도 검증자가 Godot 4.7.2 / macOS Metal Forward Mobile의 격리된 실제 `main.tscn --app` 실행으로 440×900·320×900을 확인했다. 청동 모서리 네 개·청록 측면 룬판 전체·단일 깎인 외곽이 유지되고, 가로 확장에 따른 코너 늘어짐·상단 추가 배경·잘림이 없다. 부모도 두 최종 화면을 직접 확인했다.

일반·긴 자원 수치의 네 상태에서 전체 자식 위치·크기·폰트·정렬·텍스트·카메라가 적용 전과 같았다. 상단 HUD는 외곽 여백 8px, 높이 94px을 유지한다. 실제 포인터로 홈 메뉴 열기와 뒤로 닫기·전투 재개를 확인했다. 독립 판정은 PASS이며 미해결 결함은 없다. Android 전용 변경이 아니므로 APK·실기기 검증은 수행하지 않았다.

[적용 전 440px](verification/resource-hud-before-440x900.png) · [최종 440px](verification/resource-hud-runic-440x900.png) · [최종 320px](verification/resource-hud-runic-320x900.png) · [긴 수치 320px](verification/resource-hud-runic-long-320x900.png).

상세 비교·실행 로그·최종 입력 해시는 Git에서 제외된 `build/godot/resource-hud-runic-review/`에 로컬 보관한다. 초기 원시 Dictionary와 JSON 기준값 비교의 숫자 타입 차이는 같은 JSON 변환을 적용한 최종 비교에서 해소했으며, 네 상태의 기록 필드가 모두 같았다.
