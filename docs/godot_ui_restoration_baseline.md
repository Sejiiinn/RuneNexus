# Godot UI 보존·정리 기준과 상태별 차이

역할: 기존 게임 전용 UI를 Godot 독립 앱에 보존하고, 웹 UI처럼 남은 표현은 정리 후보로 분리하기 위한 기준표. 보존 요구와 미확정 개선안을 구분한다.
최초 조사: 2026-09-21, HEAD `2a8eb37` 위의 당시 작업 트리. 아래 차이 표는 복구 전 소스 조사 기록이며 현재 미완료 목록이 아니다.

현재 전환 상태·남은 범위는 [실행 로드맵](godot_unified_app_roadmap.md#3-단계와-의존-관계)에서 관리한다. 아래 표와 복원 순서는 2026-09-21 최초 조사 기록이다. 제거된 Flutter 소스·검사는 [원본 보관 설명](archive/flutter_reference_20260924.md)에 따라 확인하며, 아래 `lib/` 경로는 그 보관본 내부 경로다. 후속 사용자 결정은 DESIGNS.md를 우선한다. 당시 로컬 분석·캡처는 현행 검증 근거로 제공하지 않는다.

## 기준의 우선순위와 보존 범위

1. 사용자의 최신 결정은 [DESIGNS.md 공통 방향](../DESIGNS.md#공통-방향)을 따른다. 픽셀 단위 복제 완화는 임의 UI 변경 승인이 아니며, 구체적으로 승인되지 않은 정리 후보는 원본 Flutter 화면을 유지한다.
2. [DESIGNS.md](../DESIGNS.md)의 확정 결정과 [현행 인게임 UX](in_game_ux_improvement_design.md).
3. 조사 당시 `lib/ui/` 구현·사용 에셋·상태 분기(이전 Flutter 보관본). 과거 캡처는 외형 참조이며 당시 재화·진행·빠진 후속 기능을 되돌리는 근거가 아니다.

조사 당시 Godot UI의 배치·공통 테마는 복원의 기준이 아니다. 자동 저장·복원, 저장 실패 보호, 보상 Outbox, 퀘스트 진행, 전투·성장 도메인과 기존 3D 전장은 보존한다. UI에서 빠진 조작은 기존 도메인 명령에 연결하되 로그인·서버 경제의 미연결 기능을 로컬 지급으로 대체하지 않는다. 구현 기술이나 같은 PNG 사용 여부는 디자인 보존 판정의 근거가 아니다.

## 보존·정리 분류와 결정 방법

아래 상태별 표는 **최초 조사 당시 원본과의 차이 목록**이다. 모든 원본 픽셀·컨테이너·팝업 단계를 그대로 복원하라는 구현 명세가 아니다. 다음 분류를 먼저 적용한다.

| 분류 | 해당 항목 | 처리 기준 |
| --- | --- | --- |
| 보존 확정 | 젬 원석·소켓·연결부, 코어 노드·명패·트리, 로비 배경·로고·장식·게임 아이콘, 전용 스테이지/보상 프레임, 확정된 연결형 탭·2열 스탯·한 줄 인벤토리 | 형태·색·재질·정보 구조와 용도별 비율을 유지한다. 일반 버튼이나 웹 카드로 대체하지 않는다 |
| 동작·정보 보존 | 비용/효과/수량/조건, 선택/잠금/부족 상태, 재탭 설치·장착, 강화 미리보기, 판매 확인, 보상 대상/교체, 저장·재개 | 외형 정리와 별개로 유지한다. 프레임·여백 정리를 이유로 설명·확인 단계·동작을 삭제하지 않는다 |
| 정리 후보 | 과도한 외곽 카드·중첩 패널, 큰 여백, 일반 폼처럼 나열된 설정/계정 입력, 중복 제목·상태 배지, 공용 컨트롤과 이질적인 드롭다운·모달 표현 | 실제 사용처의 문제를 특정하고 기존 게임 컴포넌트를 활용한 정리안을 만든다. 후보라는 이유만으로 일괄 교체하지 않는다 |
| 별도 후속 | 인증·온라인 저장·서버 보상·업데이트·정식 진입 교체 | UI 정리와 서버 기능 구현 승인을 혼동하지 않는다. 미연결 상태의 정보와 원래 행동 의미는 보존한다 |

Flutter 위젯이나 코드로 그린 버튼이라는 이유만으로 웹 UI로 분류하지 않는다. 이미지 카드라도 불필요한 겹침이면 정리 후보이며, 일반 라디오/텍스트 입력이라도 선택·입력에 적합하면 남길 수 있다. **게임 맥락·정보 밀도·기존 에셋과의 조화·조작 의미**로 판단한다. 전용 프레임을 모든 요소에 씌우거나 장식을 더하는 방식은 정리안이 아니다.

### 화면별 정리 후보 — 아직 최종 외형은 미확정

| 영역 | 보존할 부분 | 검토할 정리안·판정 조건 |
| --- | --- | --- |
| 공용 버튼·모달 | 용도별 primary/confirm/danger/ghost 의미, 선택·비활성·누름 구분, 게임 전용 프레임 | 역할이 같은 컨트롤의 색·글자·여백을 일관되게 맞춘다. 현재 Godot의 전역 금속 프레임도 정리 대상. 원본 GameButton을 통째로 웹 UI로 간주하지 않음 |
| 강화·연구 | 아이콘·효과 비교·레벨/비용·진행 슬롯·해금 그룹·주요 행동 | 원본의 카드 안 중첩 용기·상태 칩·중복 제목이 실제로 불필요한지 확인하고 컴팩트하게 묶는 후보를 제시한다. 카드/슬롯 자체를 긴 텍스트 목록으로 바꾸지 않음 |
| 설정·계정 | 기존 설정 진입·모달 맥락, 라디오 선택 의미·계정/저장 기능 | 일반 폼처럼 보이는 부분은 게임의 문자/선택 상태/간격에 맞춰 정리. 서버 주소 등 구현 정보를 제품 화면에 추가하지 않음. 계정 입력 흐름 변경은 구체안에서 별도 구분 |
| 모듈·임무·우편·리더보드 | 게임 아이콘·장착 슬롯·기간 선택·보상 정보·필터/목록의 역할 | 여러 박스·배지의 중복과 긴 설명 배치를 검토한다. 서비스 화면 전체가 웹 UI라고 단정하거나 전용 임무 프레임을 폐기하지 않음 |
| HUD 상세 | 전투 버튼 위치·전장 가시 영역·확정된 스탯/젬 구조·선택 동작 | 남는 여백·이중 패널·중복 설명만 국소 정리 후보. 재탭·미리보기·판매 확인 누락은 개선 후보가 아니라 복구할 결함 |
| 로비·스테이지·코어 | 승인된 화면 정체성과 전용 컴포넌트·배치 원칙 | 우선 보존 이관. 이번 Godot의 임의 확대/재배치부터 바로잡고, 웹 UI 정리를 명분으로 다시 전면 개편하지 않음 |

정리 후보는 구현 전에 `현재 부분 → 불편/불일치 → 유지할 정보·조작 → 변경 범위`를 구체화한다. 새 시각 방향이나 정보 구조 변경이 필요하면 대표 화면 비교안에서 그 부분만 판단받는다. 이미 확정된 게임 컴포넌트 보존을 다시 승인받지는 않는다. 이 기준표의 최초 작성 범위는 분류·계획이며, 새 외형 승인을 뜻하지 않는다.

## 공용 컴포넌트 기준

수치는 원본의 논리 단위이며 Godot 물리 픽셀에 그대로 대입하지 않는다. 화면별 배율·안전영역을 함께 대응한다. 보존 대상은 원본 값을 출발점으로 삼고, 정리 대상의 수치는 구체안에 따라 조정하며 원본 값 자체를 복제 의무로 삼지 않는다.

| 항목 | 유지할 원본·근거 | 조사 당시 Godot 차이 / 복원 기준 |
| --- | --- | --- |
| 색·문자 | GamePalette (`lib/ui/game/game_palette.dart`, 이전 Flutter 보관본), GameTextStyles (`lib/ui/game/game_text_styles.dart`, 이전 Flutter 보관본): 본문/보조/비활성 색 구분, 제목 20·절 제목 14·본문 12·캡션 10, 용도별 굵기·행간·그림자. 기본 NotoSansKR | `app_theme.gd`의 전역 16/굵기 550과 자체 색으로 대체됨. 원본의 역할별 스타일과 화면별 override를 대응 |
| 일반 버튼 | GameButton (`lib/ui/game/game_button.dart`, 이전 Flutter 보관본): primary/secondary/confirm/danger/ghost, selected/disabled/pressed, 기본 높이 38·compact 30, 누름 0.96배·90ms, 상태 전환 130ms | Godot은 기본 높이 44와 금속 PNG를 모든 Button에 적용. 원본 일반 버튼과 에셋 버튼을 분리하고 상태별 차이 복원 |
| 이미지 프레임 | GameAssetSurface (`lib/ui/game/game_asset_surface.dart`, 이전 Flutter 보관본): panel/card/row/lockedRow/button/chip 각각 별도 에셋·centerSlice | Godot은 panel/button 위주, 공통 20 margin. 원본별 모서리·중앙 확장 영역·안쪽 여백을 대응. 이미지 전체 비율을 임의로 늘리지 않음 |
| 모달 | game_modal.dart (`lib/ui/game/game_modal.dart`, 이전 Flutter 보관본): 배경 차단·안전영역·닫기, standard/reward/danger, 기본 maxWidth 420, 화면별 전용 프레임 override | Godot 별도 페이지·ConfirmationDialog·일반 패널로 혼용됨. 원본 모달/바텀시트/인라인의 맥락과 닫기 의미는 유지하고, 불필요한 용기·여백은 정리 후보로 구분 |
| 아이콘·탭 | game_image_assets.dart (`lib/ui/game/game_image_assets.dart`, 이전 Flutter 보관본), main_menu_frame.dart (`lib/ui/menu/main_menu_frame.dart`, 이전 Flutter 보관본): 공용 이미지·아이콘, 선택 탭 색·하단 표시·구분 홈 | Godot 텍스트 버튼·◇ 같은 문자 대체가 있음. 원본 이미지 및 코드로 그린 아이콘을 대응. 코드 아이콘은 Godot 그리기로 재현 가능하며 임의 새 아이콘으로 바꾸지 않음 |
| 레이아웃 | 화면별 SafeArea/constraints/FittedBox/내부 스크롤 규칙 | 단일 논리 해상도와 공통 VBox만으로 모든 화면을 맞추지 않음. 로비 고정·목록 내부 스크롤·트리 탐색·HUD 전장 영역을 별도 대응 |

Godot 수정 대상은 [app_theme.gd](../godot/ui/app_theme.gd), [lobby.gd](../godot/ui/lobby.gd), [battle_hud.gd](../godot/ui/battle_hud.gd), [assets.json](../godot/ui/assets.json)이다. assets.json의 현재 목록은 원본 UI 전체 목록이 아니므로 화면별 실제 사용처와 대응해 보충해야 한다.

## 로비·성장 화면 대응표

아래 차이는 최초 조사 당시 소스에서 확인했다. 후속 구현·검증 결과는 문서 상단의 기록에서 확인한다.

| 화면·필수 상태 | 원본 구조·조작 / 근거 | 조사 당시 Godot 차이 |
| --- | --- | --- |
| 홈: 신규·이어하기·종료 런 | main_menu_lobby.dart (`lib/ui/menu/main_menu_lobby.dart`, 이전 Flutter 보관본) `_MainLobby`, `_LobbyScene`: 전체 배경과 메뉴 배치 분리, 설정 우측 상단 아이콘, 로고, 중앙 정렬 전투 준비/진행 패널, 별도 스테이지 선택, 이벤트·리더보드·우편, 하단 4개 아이콘 바로가기. 진행 런에만 이어가기 | `_home/refresh`: 설정 좌측 텍스트 버튼·공통 지갑, 확대된 중앙 장식, 좌측 정렬 준비 패널 안에 스테이지 선택, 이벤트 대신 퀘스트 직접 진입, 홈에도 5개 텍스트 탭. 배치·비율·진입 흐름 복원 필요 |
| 하위 메뉴 공통: 각 탭 선택·뒤로 | main_menu_screen.dart (`lib/ui/menu/main_menu_screen.dart`, 이전 Flutter 보관본), main_menu_frame.dart (`lib/ui/menu/main_menu_frame.dart`, 이전 Flutter 보관본): 메뉴 전용 헤더·재화·5탭, 선택 강조·아이콘. 하위 탭 상단에 계정 로그인 아이콘 없음 | 홈/하위 메뉴가 같은 헤더·footer Button 묶음. 선택 탭 시각 구분과 원본 메뉴 프레임 복원 필요 |
| 스테이지: 챕터·진행 중·잠금·해금·클리어·상세·교체 확인 | main_menu_stage.dart (`lib/ui/menu/main_menu_stage.dart`, 이전 Flutter 보관본), stage details (`lib/ui/menu/main_menu_stage_details.dart`, 이전 Flutter 보관본): 챕터 탭/배너·현재 런 패널·스테이지 행·보상·상세 경유. 기준 캔버스 789×1566의 화면별 배치 | `_stages`: 전체 스테이지를 버튼+설명으로 나열, 행 탭 즉시 시작/교체 확인. 챕터별 구성·상세 경유·원본 현재 런 표현 누락 |
| 강화: 전투/경제·구매 가능·재화 부족·잠금·상한 | permanent upgrades (`lib/ui/menu/main_menu_permanent_upgrades.dart`, 이전 Flutter 보관본), `main_menu_frame.dart` 그룹 탭: 카드 보드, 아이콘·레벨·현재→다음 효과·비용·조건, 전투/경제 연결 탭 | `_upgrades`: 여러 줄 텍스트 버튼 목록. 그룹·카드·효과 비교와 상태별 시각 표현 복원 필요 |
| 연구: 가용/잠금/완료·빈/진행 슬롯·시간·취소·두 번째 슬롯 | research (`lib/ui/menu/main_menu_research.dart`, 이전 Flutter 보관본), slots (`lib/ui/menu/main_menu_research_slots.dart`, 이전 Flutter 보관본), details (`lib/ui/menu/main_menu_research_details.dart`, 이전 Flutter 보관본), catalog (`lib/ui/menu/main_menu_research_catalog.dart`, 이전 Flutter 보관본): 슬롯 패널, 조건순 그룹 카드, 상세 모달에서 행동 | `_research`: 슬롯 수 텍스트+일괄 버튼 목록, 행 클릭이 시작/취소/완료로 직접 분기. 원본 슬롯·카드·상세·확인 흐름과 슬롯 해금 경로 대조 필요 |
| 코어: 미투자/투자/접근 불가·초안/취소/초기화·스킬 미장착/장착/잠금 | core tree (`lib/ui/menu/main_menu_core_tree.dart`, 이전 Flutter 보관본), world (`lib/ui/menu/main_menu_core_tree_world.dart`, 이전 Flutter 보관본), details (`lib/ui/menu/main_menu_core_tree_details.dart`, 이전 Flutter 보관본), [현행 기준](core_passive_tree_implementation_plan.md): 헤더~하단 탭 전체 트리, 포인트/액션 고정 오버레이, 팬/핀치, 중앙 스킬 선택·양끝 보존 명패, 원본 노드 아이콘·연결선·투자 상태 | `_core`: 일반 세로 영역의 포인트/버튼 행과 ScrollContainer, +/- 줌, 자체 노드 크기·1.18 간격 배율, 일부 아이콘만 사용, 명패 대신 Label. 위상 일부 일치와 원형 프레임 수정만으로 이관 완료 아님 |
| 포탑 모듈: 포탑 선택·부위 필터·없음/보유·선택 상세·장착/해제·서버 행동 | turret modules (`lib/ui/menu/main_menu_turret_modules.dart`, 이전 Flutter 보관본), inventory/equipment/draw/disassemble 분리 파일: 포탑 선택, 장착 슬롯, 상세, 인벤토리·필터·뽑기/분해 진입 | `_modules`: 모든 보유품을 장착/해제 버튼으로 나열, 부위·등급·옵션에 원시 식별자 표시 가능, 뽑기 안내만 존재. 서버 호출 미연결과 UI 구조 누락을 별도로 기록 |
| 이벤트·임무: 일일/주간·진행/완료/수령·보상 처리 중 | daily quest (`lib/ui/menu/main_menu_daily_quest.dart`, 이전 Flutter 보관본), weekly (`lib/ui/menu/main_menu_weekly_quest.dart`, 이전 Flutter 보관본): 이벤트 경유, 전용 임무 모달, 기간 선택·보상/진행, 내부 스크롤. 최대 폭 430·높이 86% | `_quests`: 별도 페이지에 일일/주간을 동시에 나열한 기본 ProgressBar, 수령 UI 미연결. 기존 모달/기간 구조 복원, 서버 미연결 안내는 원래 행동 위치에서 처리 |
| 설정: 닫기·MSAA·그림자·계정 및 저장 | `main_menu_lobby.dart` `_openSettings`, graphics controls (`lib/ui/settings/graphics_settings_controls.dart`, 이전 Flutter 보관본): 설정 모달, 라디오·작은 폭 줄바꿈, 계정 및 저장 진입 | `_settings`: 하위 전체 페이지와 일반 테마 CheckBox, 별도 지금 저장 버튼. 기존 모달·위치·선택 스타일 복원. 기기 설정 저장 로직은 보존 |
| 우편·리더보드·계정: 미연결 상태 | mailbox (`lib/ui/menu/mailbox_dialog.dart`, 이전 Flutter 보관본), leaderboard (`lib/ui/menu/leaderboard_dialog.dart`, 이전 Flutter 보관본), account (`lib/ui/menu/main_menu_account.dart`, 이전 Flutter 보관본) | `_service`는 하단 문자열 안내. 서버 기능 완성은 이번 복원 범위와 분리하되 원본 진입 위치를 없애거나 다른 메뉴로 바꾸지 않음. 현재 서버 화면 동등성은 미확인 |

## 전투 화면 대응표

전투 수치·명령의 이관 여부와 UI에서 그 명령에 도달할 수 있는지를 구분한다. 아래는 전투 UI 담당의 독립 소스 대조 결과다.

| 화면·필수 상태 | 원본 구조·조작 / 근거 | 조사 당시 Godot 차이 |
| --- | --- | --- |
| 기본: 준비/전투/정지·배속·자동·선택 해제 | top_bar.dart (`lib/ui/hud/top_bar.dart`, 이전 Flutter 보관본): 좌측 골드/조각/전체 DPS, 중앙 상태, 우측 메뉴. bottom_bar.dart (`lib/ui/hud/bottom_bar.dart`, 이전 Flutter 보관본): 전투 조작행→상세→포탑/업그레이드/젬 3탭, 하단 배속 직접 선택 | `_ready/refresh`: 상단 문장형 자원과 조작, 하단 시작/자동/런 강화/닫기. 전체 DPS·3탭·기존 상세 열림/닫힘 구조 없음, 선택 해제 후에도 건설 목록 도크 유지 |
| 건설: 종류 선택·부족·잠금·미리보기·설치/취소 | build_selection_panel.dart (`lib/ui/hud/build_selection_panel.dart`, 이전 Flutter 보관본): 설명·속성·기초 스탯·가격, 종류 재탭 설치와 별도 설치 버튼 | `_build`: 종류/비용 버튼+설치, 설명·스탯 없음. 종류 재탭은 선택만 갱신하여 설치되지 않음 |
| 포탑: 스탯/젬 탭·조건부 정보 | gem_equip_panel.dart (`lib/ui/hud/gem_equip_panel.dart`, 이전 Flutter 보관본): 이름 옆 레벨 강조, 연결 탭, 2열·3행 높이 내부 스크롤·얇은 선, 누적 피해·DPS와 조건부 항목 | `_turret`: 연결 탭은 있으나 일부 스탯만 표시, 누적 피해·DPS·3행 고정 스크롤·구분선 없음. 효과 범위 조건/표현도 원본과 대조 필요 |
| 강화 미리보기·확정 / 판매 확인·취소 | 같은 파일 `previewOrLevelUpSelectedTurret`, `_confirmRefundSelectedTurret`: 다음 레벨/스탯 미리보기, 판매 모달 중 전투 정지 후 재개 | 강화/판매 즉시 명령 호출. `app_selection.gd`의 level_preview는 HUD에서 켜는 경로 없음 |
| 특성·공격 목표: 해금/부족·선택/확정 | turret_trait_panel.dart (`lib/ui/hud/turret_trait_panel.dart`, 이전 Flutter 보관본): 단계별 비용·조건·설명, 미리보기/재탭 확정. 전투 중 모달 정지/재개. 목표는 연구 해금 후 설명 포함 팝업 | 특성을 인라인 버튼으로 즉시 적용, 목표는 해금 전 비활성 OptionButton도 노출하며 설명 없음 |
| 젬 링크: 빈/장착/잠긴 홈·확장·선택/재탭 장착 | gem_socket_section.dart (`lib/ui/hud/gem_socket_section.dart`, 이전 Flutter 보관본), `gem_equip_panel.dart`: 금속 소켓+연결부, 연구 한도까지 잠긴 홈·직접 구매, 홈 명시 선택, 젬 첫 탭 설명/재탭 장착, 한 줄 이름·수량 인벤토리 | `_gems`: 열린 홈만 표시, 잠긴 홈/연결부 없음. 기본 첫 홈 선택·젬 한 번 탭 즉시 장착. 확장 별도 버튼과 모호한 조건 문구로 축약 |
| 전역 젬·런 강화: 목록/구매/부족 | gem_inventory_panel.dart (`lib/ui/hud/gem_inventory_panel.dart`, 이전 Flutter 보관본), run_upgrade_panel.dart (`lib/ui/hud/run_upgrade_panel.dart`, 이전 Flutter 보관본): 각각 독립 하단 탭, 포탑 젬과 구분 | 전역 젬 화면 없음. 별도 런 강화 목록과 포탑 젬 안 구매 버튼으로 재배치 |
| 보상/구매: 젬·조각·보유량·선택/확인 | reward_overlay.dart (`lib/ui/hud/reward_overlay.dart`, 이전 Flutter 보관본): 가로 카드, 보상/구매 제목 구분, 보유 총수량·효과 묶음·제약·규칙 안내, 젬 선택 후 대상 지정, 조각 선택 후 확인 | `_rewards`: 세로 텍스트 버튼, 항상 젬 선택 제목, 한 번 탭 즉시 보관/조각 명령. gemInventory와 원본 gemCollection의 보유량 의미도 대응 필요 |
| 보상 젬 대상 지정·교체·보관·뒤로 | gem_reward_target_overlay.dart (`lib/ui/hud/gem_reward_target_overlay.dart`, 이전 Flutter 보관본), game_hud.dart (`lib/ui/hud/game_hud.dart`, 이전 Flutter 보관본): 전장 포탑 지정→교체 홈, 시점 유지, 대상 중 드래그 가능/교체 중 금지 | 사용자 진입 화면 없음. `app_selection.gd`의 rewardTargeting 보존 분기만으로 실제 조작 구현으로 간주할 수 없음 |
| 코어/포탈 정보 | core_info_panel.dart (`lib/ui/hud/core_info_panel.dart`, 이전 Flutter 보관본): HP 게이지·스킬·지표. portal_summary_panel.dart (`lib/ui/hud/portal_summary_panel.dart`, 이전 Flutter 보관본): 다음 적 아이콘·준비 중 상세 시트 | `_board_detail`: HP/일반 설명·previewText/골드로 축약, 상세 시트 없음 |
| 결과: 성공/실패·재시도/스테이지 선택 | result_overlay.dart (`lib/ui/menu/result_overlay.dart`, 이전 Flutter 보관본): 전용 결과 프레임·차광·등장, 룬/코어/티켓·기록·최고 피해·현재 룬·해금 목록 | `_result`: 제목·웨이브·룬/코어와 재도전/로비 버튼. 원본 정보와 결과 프레임·행동 표현 누락 |
| 스테이지 메뉴·종료/복귀 확인 | `game_hud.dart` `_handleOpenMainMenu`: 메뉴→로비 복귀 또는 런 종료 확인, 취소 시 재개 | 상단 로비 버튼이 직접 `show_lobby` 호출. 복귀와 런 포기/정산 선택의 원본 흐름 대조·복원 필요 |

주요 치수 출발점: 원본 상단 바깥 여백 12·자원 폭 86·중앙 최대 폭 214, 하단 탭 40·전투 버튼 34. 포탑 상세 본문은 화면 높이 28%를 150~280으로 제한하고 스탯은 글자 배율을 반영한 3행 높이로 제한한다. 특성 모달 최대 폭 344/높이 82%, 결과 최대 폭 390. Godot의 현재 화면 높이 30%(170~255) 고정 도크를 이 수치와 같은 구조로 간주하지 않는다. 정확한 조건식은 위 원본 파일을 따른다.

사거리는 건설 중 모든 기존 포탑+설치 미리보기, 일반 선택은 해당 포탑만, 취소/해제는 숨김, 강화 미리보기와 보상 대상 우선순위를 유지한다. 기존 표시 데이터 연결은 보존하되 화면·명령 경로를 함께 검증한다. 과거 제안의 자동 홈 선택·새 패널 접기 기능은 이번 복원 요구에 추가하지 않는다.

## 조사 당시 비교 자료와 검증 조건

- [기존 로비 테스트 렌더](../design/lobby/implemented_lobby_fullbleed.png)와 당시 로컬 Godot Android 로비 캡처를 직접 열어 구조 차이를 확인했다. 서로 해상도·진행 상태·생성 경로가 달라 픽셀 동등 비교나 최신 Flutter 전체 기능의 증거로 쓰지 않는다. 우편처럼 후속 추가된 기능은 현재 소스를 따른다.
- HUD 외형 참조: [2열 스탯 기록](../design/stats_layout_concepts/README.md), [젬 인벤토리 기록](../design/gem_inventory_concepts/README.md), [소켓 기록](../design/gem_sockets/README.md). 당시 로컬 Godot 캡처는 복원 목표나 현행 검증 근거로 삼지 않는다.
- 조사 당시에는 후속 Flutter·Godot 비교를 같은 Android 해상도·안전영역·글자 배율, 같은 스테이지·선택·보상/재화 상태로 캡처하도록 정했다. 현행 검증 조건과 범위는 [디자인 완료 기준](../DESIGNS.md#검증과-완료-기준--완벽한-복제보다-요청-충족)을 따른다.
- 화면별 표의 기본/선택/잠금/부족/최대/모달 상태를 확인하되 모든 조합을 무차별 캡처하지 않는다. 긴 한글·수량/비용·작은 폭·글자 확대는 영향받는 대표 화면에서 확인한다.
- 시각 판정: 보존 영역은 기존 구조·에셋, 정리 영역은 확정한 변경 범위를 기준으로 배치·정보·색 역할·가독성·전장 가시 영역을 확인한다. 동작 판정: 재탭·확인/취소·모달 닫기·뒤로가기·선택 유지·팬/줌·재개. 자동 테스트 PASS로 시각 PASS를 대신하지 않는다.
- 이번 단계에서는 새 실제 화면·동등성 검증을 수행하지 않았다. 코드에서 정한 규칙과 향후 화면에서 확인할 결과를 혼동하지 않는다.

## 다음 구현에 넘길 순서

1. 공용 컴포넌트와 대표 화면별로 보존/동작 복구/표현 정리 대상을 구분한다. 위 후보를 실제 영역과 근거에 연결하고, 막연한 전체 리디자인 목록으로 확장하지 않는다.
2. 홈·기본 HUD는 보존 이관을 우선하고, 정리 후보는 강화/연구 또는 설정의 대표 영역에서 기존안과 비교할 수 있게 구체화한다. 새 외형·정보 구조가 필요한 부분만 결정한 뒤 확장한다.
3. 전투 상세 상태와 빠진 조작을 복구하고, 하위 메뉴에는 보존 기준과 확정된 정리안만 적용한다.
4. 보존 대상은 원본 대비, 정리 대상은 확정안 대비 Android에서 판정한다. 양쪽 모두 정보·동작·가독성·게임 테마와 저장 회귀를 확인한다.

위 순서는 최초 조사 때 정한 복원 방식이며, 현재 작업 순서는 실행 로드맵을 따른다. 기존 확정 디자인의 재승인 절차를 추가하지 않으며, 실제 목표 변경이 필요한 경우에만 구체적 차이를 제시한다.
