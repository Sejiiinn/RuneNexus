# 전투 HUD 홈 버튼

- 내장 ImageGen으로 거친 돌 느낌의 표면을 매끈한 은빛 금속·청록 바탕으로 수정했다. 중앙 홈 형태·크기·정렬은 유지했다. [현행 프롬프트](prompt-smooth.txt), [현행 원본](generated-smooth.png). 이전 시안은 `generated.png`에 보존한다.
- 게임 파일: `assets/images/ui/hud/icons/home_button.png`. 생성 원본의 알파를 보존했다.
- Godot `AtlasTexture`의 `(207, 207, 840, 840)` 영역을 비율 유지하여 28×28로 표시한다. 32×32 버튼의 중심 앵커에 ±14px로 고정하여 정렬하고 별도 프레임을 그리지 않는다.
- GIMP MCP 연결은 복구했으나 파일 열기가 응답하지 않아 후처리 파일을 만들지 않았다. 원본은 수정하지 않고 엔진 표시 영역으로 여백을 제외했다.
- 화면 검증은 [HUD 적용 기록](../combat_ui_concepts/2026-09-22/implementation/README.md)의 격리된 Godot 실행 경로를 사용한다.
