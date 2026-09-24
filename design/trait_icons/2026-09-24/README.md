# 포탑 특성 아이콘 선제작

2026-09-24. 6개 포탑의 특성 24개를 전용 래스터 아이콘으로 선제작한 원본·검수 폴더. 이후 사용자가 요청한 [Godot 특성 모달 연결과 검증](../../combat_ui_concepts/2026-09-24/trait-modal/README.md)은 해당 구현 기록에서 관리한다.

- 기준: [아이콘과 정돈된 행 시안](../../combat_ui_concepts/2026-09-24/trait-modal/02-icon-rows.png)의 금속 재질·명확한 실루엣·국소 발광. 공통 원형 소켓과 선택 테두리는 아이콘에 굽지 않는다.
- 정의 원본: [특성 목록](../../../lib/domain/turret/turret_trait_catalog.dart), [효과·이름](../../../lib/domain/turret/turret_trait_type.dart), [기존 특성별 색상](../../../lib/ui/hud/turret_trait_panel.dart).
- [미리보기](preview.html): 160px 원화 확인 및 48/64px 원형 소켓 축소 표시. 실제 게임 화면이 아니다.
- [매핑 및 프롬프트](manifest.json): ID, 포탑, 1/2차 단계, 색상, 원본·게임용 경로. [개별 프롬프트](prompts/)도 보존한다.
- `sources/`: 내장 ImageGen으로 개별 생성한 원본 PNG. CLI/API 대체 경로를 사용하지 않았다.
- [게임용 에셋](../../../assets/images/ui/traits/): GIMP에서 알파를 보존하여 256×256 PNG로 축소 내보내기. ID와 동일한 파일명으로 후속 연결 가능.

## 검수 결과

- 독립 Astra 검수 PASS: 실제 특성 목록과 매핑을 대조하고 최종 [기관총](arrow-preview.png)·[대포](cannon-preview.png)·[화염](magic-preview.png)·[냉각](frost-preview.png)·[저격](sniper-preview.png)·[라이트닝](lightning-preview.png) 미리보기를 직접 확인했다. 48/64px 주요 실루엣, 효과 의미·색상 계열, 금속·에너지 테마, 개별 아이콘에 UI 소켓·포탑 초상이 없는 구성을 확인했다.
- 확장 폭심의 좌우 잔광과 파쇄 충격의 상단 꼬리는 축소 상태에서 핵심 형태 손실로 읽히지 않는다. 필수 수정 결함 없음.
- 부모도 최종 6개 축소 미리보기와 [전체 목록](overview.png)을 직접 검토했다.
- [파일 검사](asset-check.json): 실제 카탈로그와 24개 ID·순서 일치, 중복 없는 256×256 RGBA PNG 24개, 투명 배경·원본 보존 확인. 게임용 파일 합계 2,023,622바이트. 파일 해시를 검사 기록에 보존했다.
- 미리보기 조건: Chrome headless, viewport 1120×900, DPR 1, 실제 게임용 PNG를 CSS 48/64px로 표시. 원형 소켓은 HTML의 표시 예시이며 에셋에 포함되지 않는다.
- 이 기록의 검수 범위는 에셋 선제작과 축소 미리보기다. 후속 모달 적용 결과는 위 구현 기록을 따른다. 이 에셋 검수를 Android 검수로 취급하지 않는다.
