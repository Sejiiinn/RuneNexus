# 독립 엄격 검증

2026-09-22. 최종 판정: **PASS — 요청한 데스크톱 포탑 액션 UI 범위**. 기존 PASS 기록과 별개로 현재 코드·에셋을 직접 검사했다. 구현 코드는 수정하지 않았다.

## 발견 결함과 수정 재검증

- P2: `godot/ui/turret_action_panel.gd:158–163`의 제한 없는 글꼴 축소. 320px 화면/304px 스트립에서 라이트닝, Lv.7 → 8, 강화 확정, 123456 G를 조합하면 비용이 5px가 된다. 라벨 폭 안에는 들어가지만 정상 배율에서 금액 판독이 어렵다. [실제 엔진 합성 경계 화면](synthetic-dense-320.png), [재현 하네스](dense.gd), [수치](dense.log). 일반 게임 비용 상태와 구분한 합성 경계 검사이며 기존 `verify_battle_hud.gd`도 같은 큰 금액 조합을 명시한다. 수정 전 FAIL 근거로 보존한다.

- 구현 담당 수정 후 **해결 PASS**: 통화는 gold 아이콘으로 식별하고 폭이 부족할 때만 중복 G/간격을 생략하며 동전을 줄인다. 숫자 반올림·누락 없이 `123456`이 320에서 8px(문자폭30/영역31), 440에서 11px(문자폭41/영역44)로 직접 판독된다. 툴팁은 정확 `123456 G` 유지. [320 최종 합성 경계](synthetic-dense-fixed-320.png), [440 최종 합성 경계](synthetic-dense-fixed-440.png), [재검증 하네스](dense_retest.gd), [재검증 로그](dense-fixed.log).
- 수정 영향 재검증 **PASS**: [최종 440 실제게임](fixed/base-440.png), [최종 320 실제게임](fixed/base-320.png), [320 강화미리보기](fixed/preview-320.png), [최대레벨](fixed/panel-max-320.png). 기본 `204 G` 유지, 320→440→280→320 크기 변경 후 실제 마우스 강화 preview/confirm, 부족골드·최대레벨, 구조/라벨 경계 포함 449개 assert 실패0. [결과](fixed/result.json), [실행](fixed/run.log), [재검증 하네스](retest.gd). [현재 HUD 회귀](fixed/hud.log)도 PASS. 여기서 assert 수는 입력 시나리오 수가 아니라 노드/라벨 검사까지 합친 수다.
- 가격 범위 코드 독립 확인: `growth_content.json`의 6종 maxLevel=10, Lv1–9 강화 기본 비용 최대는 기관총258/대포387/화염344/냉각366/저격516/라이트닝602 G. `app/run_commands.gd`와 `app/growth_rules.gd`의 보정은 할인이다. 정상 게임 최대는 602 G이고, 6자리 금액은 기존 회귀가 요구한 여유 스트레스다. 임의 7자리 합성값을 현행 제품 범위로 추가하지 않았다.

## 실제 확인한 통과 범위

- Godot 4.7.2, macOS Metal Forward Mobile/Apple M4, `build/godot/hud-review-v4`; 런타임 사용자 경로가 `RuneNexus-HUD-review-v4`인지 assert. 사용자 플레이 저장과 공용 생성 프로젝트는 수정하지 않았다.
- 실제 3D 전장+HUD를 440×900, 320×760에서 실행했다. 280×760은 추가 스트립 경계 확인이다. [440 전체](base-440.png), [320 긴 이름](lightning-320.png), [320 강화 미리보기](preview-320.png), [280 경계](preview-280.png).
- 승인 `06-v2-upgrade-traits.png`의 실제 UI 영역과 직접 비교했다. 한 줄 포탑/강화/특성/판매, 청록·보라·작은 판매 금속 프레임, 두 연결 탭의 여백·상대폭을 보존한다. 포탑은 승인된 기존 3D 렌더 6종이며 임시 기관총 그림이 아니다. 특성은 후보 10번 태양/잎/소용돌이 3육각이다. 비용은 공용 투명 gold.png이며 강화·판매·특성에서 사각 배경이나 불투명 crop 경계가 보이지 않는다.
- `audit.gd`는 실제 viewport `push_input(InputEventMouseMotion/InputEventMouseButton)`의 press/release로 클릭한다. 버튼 `pressed.emit()`이나 액션 메서드 직접 호출로 입력 검사를 대체하지 않았다. 강화 왼쪽 가장자리→미리보기(레벨·골드 보존)→중앙 확정(레벨 증가·골드 감소), 특성 1차/2차 미리보기·확정, 젬/스탯 탭 전환, 판매 가장자리→모달→취소, 320px 판매 확정·환불을 검사했다. 골드 부족·최대레벨은 비활성이며 입력이 무시된다. [실행](run.log), [860건 결과](result.json).
- 실제 보이는 상태: [특성1](panel-traits-one-440.png), [특성2](panel-traits-two-440.png), [골드부족](panel-poor-440.png), [최대레벨](panel-max-440.png), [판매모달](sell-confirm-440.png). 기관총/대포/냉각/저격/화염/라이트닝을 직접 확인했다.
- 코드·실제 노드 검사: VBox/HBox/Margin/PanelContainer, 전용 Theme 변형, StyleBoxTexture, 고정 texture margin와 별도 content margin, 모든 Control.scale=(1,1). 수동 9조각·Canvas 대체·전체 패널 scale은 없다. 버튼 위치·순서·겹침·상대폭과 라벨 폭·높이 검사 통과.
- [HUD 회귀](verify_battle_hud.gd.log) PASS, [런 명령](verify_run_commands.gd.log) 4,830건 failures=[], [런 저장 어댑터](verify_run_save_adapter.gd.log) 28건 failures=[]. 저장검사의 Exponent too high 경고 4건은 ±1e99999 잘못된 JSON 거부 사례에서 발생했으며 UI 실행에는 오류·경고가 없다.
- [에셋 검사](asset-check.json): 배포 manifest 중복0/누락0, 제작 manifest 13개 SHA 일치. 최종 액션 파일 11개는 모두 현재 구현에서 사용하며 이전 crop/중복 프레임은 게임 에셋 디렉터리에 없다. 실제 런타임 복사본도 13개 원본과 byte 동일.

## 범위와 제한

Android 실제 터치·폰트 밀도·배포는 미검증이며 데스크톱 PASS로 간주하지 않는다. Android 전용 코드 변경이 없어 APK를 빌드하지 않았다. 280px 전체 HUD의 상단 지표 충돌은 이 스트립 변경의 통과 근거가 아니며, 이 검사는 포탑 액션 스트립 경계에 한정한다. 자동 캡처만으로 판정하지 않고 위 이미지들을 직접 열어 확인했다.
