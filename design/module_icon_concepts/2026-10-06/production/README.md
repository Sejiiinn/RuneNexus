# 포탑 모듈 아이콘 도입

2026-10-07. [승인 15안](../15-hybrid-simplified-normal-progression.png)을 기반으로 코어·포신·프레임 × 일반·마법·희귀·유니크 12종을 게임에 적용했다. 완전 정면 형태, 금속 재질, 등급별 보강 부품 증가를 유지한다. 사용자의 광원 위치 정정에 따라 유니크 아이콘 뒤에 별도 투명 후광 PNG를 배치한다.

## 제작·연결

- 최종 게임 이미지: [assets/images/turret_modules/icons](../../../../assets/images/turret_modules/icons), 각 384×384 RGBA PNG. 12종 합계 약 2.22 MB.
- `references/`: 승인 시안의 부품별 크롭. `source/`: 내장 ImageGen으로 추출·광원 편집한 1254×1254 PNG와 GIMP 축소·내보내기 원본 XCF.
- 제작 방식: **built-in ImageGen** 12개 독립 편집 호출 → GIMP MCP NoHalo 축소·알파 보존 PNG 내보내기. [프롬프트 전체](prompts.json), [생성 원본 대응](source-map.json).
- [공통 표시](../../../../godot/ui/module_icon.gd)는 부품과 등급으로 PNG를 선택하며 자체 색상을 유지한다. 인벤토리·장착 슬롯·뽑기 결과·분해 미리보기가 같은 에셋을 사용한다. 외곽 UI 프레임·선택·장착표시와 게임 계약은 보존했다.
- [assets.json](../../../../godot/ui/assets.json)에 12종을 등록했으며 `prepare_godot_project.py`의 실제 패키징용 에셋 복사를 확인했다.

## 기본 아이콘 검증 (후광 추가 전)

- 격리 Godot 회귀 3개 PASS: `verify_module_draw_results.gd`, `verify_lobby_collection.gd`, `verify_ui_confirmations.gd`. 12개 경로·원본 색상·크기별 중앙 정렬·인벤토리·장착·뽑기·분해 확인 계약을 검사했다. 인벤토리 Container의 실제 0.10~0.17px 반올림을 허용하도록 해당 검사 오차를 1px로 조정했다.
- 최종 PNG 독립 검수: 정면 family, 구조 성장, 등급색, 유니크 국소 광원, 실제 실루엣 잘림 없음, 배경 투명 확인.
- 최종 실제 화면 독립 검수 **PASS**: 캡처 6장을 승인 원본과 대조했다. 작은 표시에서 부품·등급·구조 차이가 읽히며 유니크 포신의 프레임 간섭, 잘림·겹침, 미해결 결함이 없다. 320×568 결과 목록의 마지막 행 접근과 고정 헤더·닫기를 확인했다.
- 실제 UI: Godot **4.7.2.stable.ed1daf0bf**, macOS Apple M4, Compatibility/OpenGL Metal. 실제 `Lobby`와 기존 회귀의 `FakeApp` 데이터로 실행했다. 사용자 저장과 네트워크 거래는 사용하지 않았다.
- 기존 MCP 편집 프로젝트의 다른 작업 설정을 보존하기 위해 격리 프로젝트를 사용했다. 편집기의 embedded 실행이 시작 대기 상태에 머물러 같은 프로젝트를 Godot 직접 실행한 뒤 연결된 MCPRuntime으로 화면을 캡처했다.
- 검증 화면과 대응하는 입력 해시는 [inputs.sha256](verification/inputs.sha256)에 기록했다. 일회성 fixture·실행 프로젝트는 Git 제외된 `build/module-icon-qa/`에만 보관한다.
- Android 실기기와 APK 배포는 이번 검증 범위에 포함하지 않았다.

| 실제 화면 | 확인 범위 |
| --- | --- |
| [인벤토리 440×896](verification/qa-inventory-440.png) | 12종 등급·부품, 유니크 3슬롯, 선택·장착표시 |
| [인벤토리 320×896](verification/qa-inventory-320-empty.png) | 좁은 5열, 선택 아이콘, 빈 장착 슬롯 |
| [뽑기 440×896](verification/qa-draw-440.png) | 상단 5개 아이콘과 같은 순서의 상세 행 |
| [뽑기 320×568 상단](verification/qa-draw-320-top.png) / [하단](verification/qa-draw-320-bottom.png) | 작은 아이콘, 고정 헤더·닫기, 마지막 행 스크롤 |
| [분해 440×896](verification/qa-disassembly-440.png) | 작은 미리보기와 등급·이름, 목록 스크롤 영역 |

## 별도 배경 후광 적용·검증

- 요청한 광원은 부품 표면이 아닌 **아이콘 뒤의 보라색 후광**이다. 별도 [unique_backglow.png](../../../../assets/images/turret_modules/icons/unique_backglow.png)를 내장 ImageGen으로 제작했다([프롬프트](backglow-prompt.txt)). 1254×1254 RGBA, 투명 가장자리, 약 1.51 MB. 원본은 `source/unique_backglow.png`에 보관한다.
- 기존 12종 PNG를 수정하지 않고 공통 표시 코드에서 유니크에만 뒤 레이어를 추가했다. 아이콘 대비 1.36배 크기·불투명도 0.55이며 리사이즈를 따라간다. 레이아웃 최소 크기에 영향을 주지 않고 입력을 가로채지 않는다.
- 후광 등록 후 관련 회귀 3개 PASS. 유니크에만 별도 텍스처가 존재하고 뒤에 그려지며 입력을 무시하는지 추가 검사했다.
- 같은 Godot 4.7.2 검수 프로젝트와 데이터로 실제 화면을 확인했다: [인벤토리 440](verification/qa-backglow-inventory-440.png), [인벤토리 320](verification/qa-backglow-inventory-320.png), [뽑기](verification/qa-backglow-draw-440.png), [분해](verification/qa-backglow-disassembly-440.png). 후광이 작은 유니크 아이콘 주변으로 보이고 기존 프레임·등급명은 유지된다.
- 이번 변경 입력: [backglow-inputs.sha256](verification/backglow-inputs.sha256). 기본 12종은 이전 입력 해시와 동일하다.
- 최종 독립 검수 **PASS**: 코드와 위 실제 캡처 4장을 직접 대조하여 유니크 전용 뒤 레이어, 후광 시인성, 프레임·문자·인접 아이콘 비침범을 확인했다. 미해결 결함 없음.
