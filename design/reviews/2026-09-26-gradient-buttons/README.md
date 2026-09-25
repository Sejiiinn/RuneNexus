# 로비 버튼 금속 스타일 통일

2026-09-26. 코어 장착·해제·닫기의 그라데이션 버튼과 같은 스타일을 조사한 뒤, 사용자가 공통 금속 이미지로 통일하고 눌림 상태까지 정리하도록 승인했다. 기준은 [DESIGNS](../../../DESIGNS.md)와 기존 `assets/images/ui/combat_components/native/` PNG다.

`button_skin.gd`가 기존 금속 표면을 공유한다. 로비 일반 버튼과 GameButton을 여기에 연결하고 `GradientBox`를 제거했다. 주요·보조·위험·비활성·포커스 상태를 구분한다. 전투·시작 화면의 기존 금속 색·여백은 보존했다. 강화 탭은 기존 선택 이미지를, 홈 모달 닫기는 투명 기본과 가벼운 상태 표시를 유지한다. 공통 hover_pressed를 새로 등록해 기존 전투 전용 토글을 덮는 방식은 사용하지 않는다.

## 근거

Godot 4.7.2/macOS Apple M4/OpenGL Compatibility, 격리 프로젝트 `/tmp/rune-metal-buttons-20260926/godot`. 기존 로비 fixture를 사용한 실제 UI 실행이며 운영 계정·사용자 저장은 접근하지 않았다. 440×900과 코어 320×720을 확인했다.

- [자동 검사](after/checks.log): 시작 화면·로비·성장·모듈·모달 입력·레이아웃 안정성·전투 HUD·전투 보상 8개 PASS.
- [GUI 실행](after/runtime.log): 버튼별 실제 스타일 및 자원 조회, mouse로 코어 해제→장착 상태 변경·영역 크기 보존 확인. 실행 오류 없음.
- 코어 [기존](core-skills.png) → [기본](after/core-skills.png), [눌림](after/core-pressed.png), [좁은 화면](after/core-narrow.png).
- [연구](after/research-details.png), [모듈](after/modules.png), [계정](after/account.png), [주요 눌림](after/account-primary-pressed.png), [위험 눌림](after/account-danger-pressed.png), [비활성](after/disabled-confirm.png).
- [홈 닫기 눌림](after/home-close-pressed.png), [강화 탭 눌림](after/upgrade-tab-pressed.png).

원래 검수의 `runtime.log`와 루트 캡처는 수정 전 근거다. 공통 버튼 적용 근거는 `after/`, 후속 수정한 코어 닫기의 최종 근거는 `close/alpha-clean/`다. 최초 검증에서 상수명과 Godot 클래스 충돌 및 공통 hover_pressed로 인한 전용 버튼 표면 노출 위험을 수정한 뒤 최종 코드로 재실행했다. 오류 상태 캡처는 채택하지 않았다.

이번 작업은 UI 스타일 변경이며 Android APK 빌드·실기기 검증은 하지 않았다.

별도 Astra가 최종 코드·실행 로그·캡처 11종을 직접 대조해 독립 검증 PASS. 우편의 모든 조건별 화면은 직접 캡처하지 않았으며 같은 공통 버튼 경로의 적용을 코드로 확인했다. 미해결 결함 없음.

## 코어 닫기 전용 버튼

사용자가 작은 ×에 공용 프레임 모서리가 과하게 보인다고 지적해 코어 스킬·노드 상세의 닫기를 별도 `close_button.gd`로 분리했다. 기존 `stage_details/v2/close_button.png`의 프레임과 ×를 한 장 그대로 32×32에 표시하며 9분할 늘림이나 텍스트 × 중첩을 하지 않는다. 장착·해제 버튼은 유지한다.

[기본](close/core-skills.png)·[눌림](close/close-pressed.png)·[노드 키보드 포커스](close/node-focus.png)·[320px 화면](close/core-narrow.png). 같은 격리 Godot 환경에서 mouse 닫기·키보드 Enter 닫기·상태와 영역 보존을 확인했다([로그](close/run.log)).

후속 변경도 별도 Astra가 원본·최종 캡처 4장·코드·로그를 직접 대조해 독립 검증 PASS. 모서리 비율과 × 중복 문제 없음.

## 닫기 외곽 배경 수정

사용자 지적으로 기존 시안 crop에 불투명한 패널 배경과 오른쪽 위 장식 일부가 남아 있음을 확인했다. 앞선 닫기 검증은 이 결함을 놓쳤으므로 외곽 투명도 합격 근거로 사용하지 않는다. GIMP에서 기존 프레임·× 픽셀을 유지하고 외곽을 투명하게 제거한 뒤 36×36으로 크롭했다. 전용 `assets/images/ui/components/close_button.png`로 분리해 원래 스테이지 에셋은 보존했다. 편집 원본은 [XCF](close/alpha-clean/close-button.xcf)다.

최종 [기본](close/alpha-clean/core-skills.png)·[눌림](close/alpha-clean/close-pressed.png)·[포커스](close/alpha-clean/node-focus.png)·[320px](close/alpha-clean/core-narrow.png). 실제 Godot 실행에서 닫기 입력·32×32 크기·상태/영역 보존을 다시 확인했다([로그](close/alpha-clean/run.log)).

별도 Astra 독립 검증 PASS: 36×36 RGBA의 외곽 77px 완전 투명, 나머지 1219px은 원본 크롭의 RGB와 동일해 프레임·× 보존을 확인했다. 최종 캡처 4종에서 사각 배경·금색 이물 제거와 상태 표시를 직접 확인했다.
