# 포탑 전용 액션 표시

2026-09-22. [승인 06-v2](../turret-action-proposals/06-v2-upgrade-traits.png)의 한 줄 구성·상대비율을 Godot 표준 UI로 적용한다. 특성 문양은 [후보 10번](../turret-action-proposals/trait-icons-10-candidates.png)이며 포탑 그림은 기존 3D 렌더 아이콘을 유지한다.

- `VBoxContainer` 안에 금속 헤더 `PanelContainer`와 좌우 여백을 둔 두 탭을 연결한다. 헤더 `HBoxContainer`는 좌측 포탑 아이콘·이름·레벨, 청록 강화, 보라 특성, 우측 작은 판매를 한 줄로 배치한다. 화면 폭이 달라져도 이 구성을 유지한다.
- 승인 원본에서 직접 추출한 프레임의 모바일 파생 PNG를 전용 `Theme` 변형과 `StyleBoxTexture`에 적용한다. 고정 모서리와 `MarginContainer`의 콘텐츠 여백을 분리하며 액션 내용은 `HBoxContainer`/`VBoxContainer`로 배치한다. 전체 패널 강제 축소·절대좌표 조립·커스텀 draw는 사용하지 않고 모든 `Control.scale`은 1이다. [제작 원본·절차](../turret-action-proposals/production/README.md).
- 화면 크기 변경 시 원본 비율에 맞춰 글자 크기·최소 높이·여백을 조정한다. 긴 포탑 이름·강화 확정·미리보기 레벨은 실제 라벨 폭 안에 들어오도록 글자 크기를 낮춘다. 가격은 최소 8px를 유지하며 공간이 부족할 때만 통화 아이콘과 중복되는 ` G`를 생략하고 동전·간격을 줄인다. 숫자는 생략·반올림하지 않고 강화 버튼 툴팁에도 정확한 금액을 표시한다. 판매 금액은 시안처럼 버튼에서 제외하고 기존 확인 모달·툴팁에 유지한다.
- 승인 원본의 강화 화살표·판매 동전은 모양을 유지하며 잘라낸 사각 배경만 알파로 제거했다.
- 강화 비용의 동전은 기존 투명 공용 `ui/hud/icons/gold.png`를 사용한다. 시안 배경이 포함된 동전 crop은 제거했다.
- 모든 포탑은 기존 `ui/hud/turrets_3d/{kind}.png`를 사용한다. 투명 여백만 `AtlasTexture.region`으로 제외해 정해진 아이콘 영역을 채우며 원본 파일·모델·시점은 변경하지 않는다. 영역은 종류별로 한 번 계산해 캐시한다.
- 강화 미리보기 후 확정, 골드 부족/최대 레벨 감쇠, 판매 확인, 특성 모달, 스탯 내용·단위·세 줄 내부 스크롤을 유지한다. 하단 패널의 기존 화면 28% 제한도 유지한다.

## 현재 강화 비용 범위

`godot/content/growth_content.json`의 6종 포탑은 최대 Lv.10이며 강화 가능한 Lv.1~9의 기본 비용 최댓값은 기관총 258, 대포 387, 화염 344, 냉각 366, 저격 516, 라이트닝 602 G다. `godot/app/run_commands.gd`의 `quotes()`는 이 값에 모듈 할인(0~0.8), 영구 강화 할인, 코어 패시브 할인을 곱한다. `godot/app/growth_rules.gd`와 현행 카탈로그에는 강화 비용을 기본값보다 높이는 배율이 없으므로 정상 지원 범위의 최대 비용은 **602 G(3자리)**다. 최대 레벨에서는 강화 비용이 0으로 비활성 처리된다. 123456 G는 실제 비용 상한이 아니라 긴 금액 표시의 여유 검증값이다. 현재 게임 규칙에 7자리 이상의 포탑 강화 비용은 없다.

## 현재 검증

최종 독립 검증은 [엄격 검증 보고서](native/strict-audit/README.md)를 따른다. 큰 비용의 5px 가독성 결함을 수정한 뒤 실제 입력·화면·관련 회귀를 재검증해 데스크톱 범위 PASS를 받았다. [최종 320](native/strict-audit/fixed/base-320.png), [최종 440](native/strict-audit/fixed/base-440.png), [최종 소스 해시](native/strict-audit/final-source-sha256.json). 아래 최초 검증과 구분한다.

Godot 4.7.2 macOS Metal Forward Mobile, Apple M4. 기존 격리 프로젝트 `build/godot/hud-review-v4`와 사용자 저장 `RuneNexus-HUD-review-v4`에서 실제 스테이지 1 포탑 HUD를 직접 실행했다. 고정 시점·정지 상태이며 [환경·입력·소스/에셋 해시](native/verification.json), [캡처 하네스](native/capture.gd)를 보관한다.

- 최종 아이콘 배경 확인: [440 전체](native/transparent-icons-440.png), [440 액션 부분](native/panel-transparent-icons-440.png). 투명 공용 골드와 배경 알파를 정리한 승인 화살표·판매 동전을 함께 확인했고 사각 배경이 보이지 않는다. [실행 로그](native/transparent-icons.log).
- 골드 배경 결함 후속 수정: [320 전체](native/gold-320.png), [440 전체](native/gold-440.png), [비용 부분 포함 440](native/panel-gold-440.png). 기존 투명 동전으로 복구한 최종 모습이며 나머지 구성·동작은 유지한다. [후속 로그](native/gold.log).
- 최초 native 구조 화면 PASS: [320 전체](native/after-320.png), [440 전체](native/after-440.png), [320 액션](native/panel-after-320.png), [440 액션](native/panel-after-440.png). 기존 3D 포탑 그림, 승인 금속 프레임·청록/보라 색, 한 줄 상대비율, 아래 연결 탭, 10번 특성 문양을 확인했다. 픽셀 동일성 검사가 아니라 원본 구성·비율과 실제 게임 화면을 대조한 결과다.
- 상태별 확인: [강화 미리보기](native/after-preview-320.png), [골드 부족](native/disabled-320.png), [최대 레벨](native/max-level-320.png), [특성 1개](native/traits-one-440.png), [특성 2개](native/traits-two-440.png), [젬 링크 탭](native/gems-440.png), [긴 이름·라이트닝 320](native/lightning-320.png). 제목·금액·선택 현황·스탯이 잘리지 않는다. 실제 액션 패널은 304×65 / 424×91이다. [실행 로그](native/capture.log), [라이트닝 로그](native/lightning.log).
- [HUD 회귀 PASS](native/hud-test.log): 강화 미리보기/확정, 판매 모달, 특성 선택, 골드·소켓·젬 장착 회귀. 320/440 폭의 한 줄 배치·버튼 상대폭, `StyleBoxTexture`/고정 코너, 모든 컨트롤의 scale=1, 기존 3D 아이콘과 투명 영역 일치, 스탯 노출을 검사한다. 실제 라벨 폭 대비 문자열 폭을 확인하고 라이트닝·강화 확정·Lv.7→8·123456 G의 좁은 화면 조합도 별도로 검사했다.
- Android 실제 터치·본게임 배포 검증은 미실시이며 APK를 만들지 않았다. 저장·전투 규칙 변경은 없다.

## 이전 구현 근거

기존 38px 액션의 [320 화면](after-320.png), [440 화면](after-440.png), [당시 회귀](hud-test.log), [당시 UX 검토](ux-review.md)는 비교 이력이다. `v2/`의 두 줄 적응형 구성과 `exact/`의 일괄 스케일 구성은 폐기되었으며 현행 검증 근거로 사용하지 않는다. 현재 근거는 `native/`다.
