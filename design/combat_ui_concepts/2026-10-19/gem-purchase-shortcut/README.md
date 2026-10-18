# 젬 구매 바로가기 시안 (2026-10-19)

젬 파편이 구매 비용(`gemChoicePurchaseCost` 20) 이상이고 준비·웨이브 단계일 때 전투 화면 왼쪽에 젬 구매 아이콘을 표시하고, 누르면 확인창을 거쳐 기존 젬 구매 선택(`purchase_reward_gems`)으로 이어지는 흐름의 시안이다. **6번(세 결정 묶음)을 승인했다.** 현행 기준은 [전투 UI 결정](../../../../docs/design_decisions/combat_ui.md)의 ‘젬 구매 바로가기’ 행이다.

이 README와 `implemented-440-*.png`만 저장소에 포함한다. 아래 시안·`current-440.png`·`assets/` Codex 원본은 로컬 전용이며 `.gitignore`로 제외했다.

## 게임 적용 에셋

`assets/` 아래 Codex 원본(투명 배경)을 여백 제거·축소해 `assets/images/ui/hud/`에 두고 `godot/ui/assets.json`에 등록했다. 구현은 `godot/ui/hud_gem_shortcut.gd`이다.

| 원본 | 게임용 | 용도 |
| --- | --- | --- |
| `assets/gem_purchase_socket.png` | `ui/hud/gem_purchase_socket.png` (192px) | 청록 금속 원형 소켓 |
| `assets/gem_purchase_trio.png` | `ui/hud/icons/gem_purchase_trio.png` (160px 높이) | 금·청·적 결정 3개 아이콘, 확인창 제목에도 사용 |
| `assets/gem_purchase_tag.png` | `ui/hud/gem_purchase_tag.png` (240×60, 4배 원본 9조각) | 가격표 |

확인창은 디자인 기준의 비용 중복 금지에 따라 시안 4번과 달리 ‘구매’ 버튼에 비용을 다시 넣지 않는다.

## 적용 확인 (2026-10-19)

- 실제 앱 캡처: `implemented-440-hud.png`(스테이지 26, 웨이브 10, 파편 1,000), `implemented-440-confirm.png`(확인창). `verify_chapter_three_combat_render.gd --startup-smoke` 실행 중 HUD를 그대로 캡처했다. 6번 시안과 소켓·세 결정·가격표 형태와 위치가 일치한다.
- 자동 검사: `verify_battle_hud.gd`가 비용 미만 숨김·비용 이상 표시·가격·위치(자원 패널 아래 왼쪽, 카메라 토글과 겹치지 않음)·에셋 로드·확인창만 열림·취소 시 파편 유지·구매 1회 차감·구매 선택 중 숨김을 확인한다.
- 미확인: 320px 폭 캡처와 Android 실기기 터치는 확인하지 않았다.

## 시안 목록

| 파일 | 내용 |
| --- | --- |
| `current-440.png` | 바탕으로 쓴 실제 앱 캡처(스테이지 26, 웨이브 10, 파편 1,000) |
| `01-left-socket-button.png` | 상단 패널 아래 왼쪽, ‘고정’ 토글과 대칭인 원형 금속 소켓 + 파편 20 가격 태그 |
| `02-left-edge-tab.png` | 화면 왼쪽 끝에 붙은 사선 탭, 젬 아이콘 + ‘젬 구매’ |
| `03-left-square-badge.png` | 상단 패널 아래 왼쪽 사각 버튼, 젬 + `+`, 민트 알림점, ‘구매 가능’ |
| `04-confirm-modal.png` | 아이콘을 누른 뒤 확인창(기존 전투 모달 외형), 비용·보유 변화·취소/구매 |
| `05-gem-crystal-single.png` | 1번 배치 유지, 아이콘을 실제 젬처럼 길쭉한 청색 결정 + 금속 발톱으로 교체 |
| `06-gem-crystal-trio.png` | 1번 배치 유지, 금·청·적 결정 3개를 한 발톱에 묶어 ‘3개 중 선택’을 표현 |
| `07-gem-crystal-prism.png` | 1번 배치 유지, 결정 하나에 호박→청록→보라 무지개 발광 |
| `05~07-*-closeup.png` | 각 아이콘 부분을 잘라 2배 확대한 비교용 |

- 1~4번 아이콘은 브릴리언트 컷 형태라 다이아 재화처럼 보인다는 피드백을 받았다. 5~7번은 실제 젬 원본(`assets/images/gems/simplified/`)의 길쭉한 결정·금속 발톱 형태를 `--ref`로 넣어 다시 만들었다.

- 도구: Codex image_gen(`codex-imagegen` 스킬), `current-440.png`를 `--edit`, `assets/images/ui/hud/icons/gems.png`·`shard.png`와 전투 종료 확인창 캡처를 `--ref`로 사용했다.
- 생성 글자 오류: 01의 상단 ‘젬 파편 1’이 ‘칩 파편 1’로, 04의 ‘13기’가 ‘137|’로 바뀌었다. 기존 HUD는 그대로 유지하므로 구현과 무관하다.
