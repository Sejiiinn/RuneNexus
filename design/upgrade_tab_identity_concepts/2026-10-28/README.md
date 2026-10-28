# 영구 강화 탭 개성 시안 (2026-10-28)

연구 탭과 구분되는 영구 강화 탭(청동 단련대)의 시안·제작 원본·실제 적용 캡처. 결정은 [로비 디자인 결정](../../../docs/design_decisions/lobby.md)의 「영구 강화 목록」을 따른다. 프롬프트는 `prompts.json`.

## 시안

- `current-*-440.png`: 바꾸기 전 강화·연구 탭
- `a-upgrade-tab.png`(단련대 줄), `c-upgrade-tab.png`(훈련대 레벨 숫자): 승인한 두 방향. `b-upgrade-tab.png`는 비교안
- `final-upgrade.png`: A+C 합친 최종안. `final-upgrade-tabs-default.png`·`-locked.png`·`-done.png`: 해금·잠김·완료 상태 탭을 더한 승인 시안
- `research-a/b/c.png`, `final-research.png`: 연구 탭 시안(A 설계도 + 단순 슬롯). 아직 구현하지 않음

## 제작 원본과 게임 에셋

ImageGen(`--ref` 최종 시안) 부품 시트 `production/sheet-rows-v2.png`·`sheet-parts-v2.png`에서 잘라 할로를 지운 `production/v2-*.png`가 편집 원본이다. 상태 탭·눈금 홈·칸막이는 첫 시트 `production/sheet-parts.png`·`sheet-detail.png`에서 자른 `production/tab_bar.png`·`tab_selected.png`·`gauge_track.png`·`divider.png`를 그대로 쓴다. 망치는 `production/hammer-v3.png`. 게임 에셋은 `assets/images/ui/components/upgrade/`이며 3배 원본(`source_scale = 3.0`)으로 줄여 9-slice 가운데를 다듬었다. 판·버튼·탭은 `godot/ui/lobby_frame.gd`의 `Frame`으로 늘리고, 눈금은 `lobby_growth.gd`의 `ForgeGauge`가 폭에 맞춰 그린다.

## 실제 적용 캡처

실제 로비 코드에 시험용 진행 데이터를 넣어 Godot에서 캡처했다.

- `implementation/unlocked-440.png`·`locked-440.png`·`done-440.png`: 해금·잠김·완료 탭
- `implementation/economy-440.png`, `implementation/economy-760.png`: 경제 분류, 넓은 화면
- `implementation/levelup-strike.mp4`: 레벨업 성공 단련 연출(30fps)
