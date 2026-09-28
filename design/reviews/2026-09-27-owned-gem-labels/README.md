# 보상 획득 젬 이름 줄바꿈 수정

> 원시 로그·일회성 검사·측정 덤프는 로컬 기록으로 Git 추적에서 제외했다. 본문의 요약 결과와 유지되는 회귀 테스트는 보존하며, 아래 로컬 기록은 새 체크아웃에 포함되지 않는다.

사용자 제공 15웨이브 보상 화면의 `가속 ×1`, `연쇄 ×1` 세로 줄바꿈을 실제 Godot HUD fixture에서 재현했다. HFlowContainer 내부 Label이 공통 자동 줄바꿈 설정으로 자연 텍스트 폭을 잃는 것이 원인이다. 해당 목록 Label에만 AUTOWRAP_OFF를 적용해 이름·수량을 한 줄로 유지하고, 항목 전체를 다음 행으로 넘긴다.

- 변경: `godot/ui/battle_rewards.gd`, 관련 검사 `godot/verify_battle_rewards.gd`.
- Godot 4.7.2 / Metal Mobile / macOS. 320×900, 440×900, 젬 2종 및 전체 종류·두 자릿수 수량. 저장 없는 HUD fixture 사용.
- [수정 전](before/owned-440-two.png): 같은 세로 줄바꿈 재현, 한 줄 검사 실패.
- [수정 후](after/owned-440-two.png), [좁은 화면·다수 젬](after/owned-320-many.png): 이름/수량 한 줄, 항목별 행 넘김·폭 검사 통과.
- 실행 로그 (`after/run.log`, 로컬 기록): 관련 레이아웃 및 기존 보상 선택·장착·교체 검사 PASS, exit 0.
- Android APK 빌드·설치는 수행하지 않았다. 데스크톱으로 재현 가능한 공통 UI 레이아웃 수정 범위이다.
