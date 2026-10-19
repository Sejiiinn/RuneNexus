# 젬 파편 아이콘

2026-10-19: 사용자가 실제 적용 화면을 확인하고 1번 단일 파편의 커밋을 승인했다. 외형 기준은 [전투 UI 결정](../../../../docs/design_decisions/combat_ui.md)의 ‘젬 파편 아이콘’이다.

- 채택 생성 원본: `01-single-shard.png` (ImageGen, 투명 배경).
- 편집 원본: `01-single-shard-hud.xcf` (GIMP에서 여백 정리·축소, 96×96).
- 게임 적용본: [shard.png](../../../../assets/images/ui/hud/icons/shard.png). 기존 공용 경로를 유지해 상단 HUD·젬 구매 가격표·파편 비용 표시가 같은 이미지를 사용한다.
- [실제 Godot 적용 화면](01-applied-440.png): Mobile/Metal, 440×900, 격리된 오프라인 스테이지 26·웨이브 10 fixture. 새 파편이 상단 HUD와 구매 가격표에 표시됨을 직접 확인했다.
- 검증 한계: 에셋 import 완료. 캡처 실행기 `verify_chapter_three_combat_render.gd --startup-smoke`는 명중 관측 항목 `real firing hits and kills 26`에서 실패했으므로 전투 검사 전체 통과로 보지 않는다. 상세 실행 로그·테스트 저장은 Git에서 제외된 `build/ignored/gem-shard-preview/`에 로컬 보관했다. Android 및 독립 검증은 미실시다.
- `02-three-fragments.png`·`03-rough-chip.png`는 미채택 형태 후보로 보관한다. [생성 프롬프트](prompts.txt)는 제작 입력 기록이다.
