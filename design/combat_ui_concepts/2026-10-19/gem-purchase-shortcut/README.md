# 젬 구매 바로가기 시안 (2026-10-19)

젬 파편이 구매 비용(`gemChoicePurchaseCost` 20) 이상이고 준비·웨이브 단계일 때 전투 화면 왼쪽에 젬 구매 아이콘을 표시하고, 누르면 확인창을 거쳐 기존 젬 구매 선택(`purchase_reward_gems`)으로 이어지는 흐름의 시안이다. **6번(세 결정 묶음)을 승인했다.** 현행 기준은 [전투 UI 결정](../../../../docs/design_decisions/combat_ui.md)의 ‘젬 구매 바로가기’ 행이다.

이 README와 `implemented-440-*.png`만 저장소에 포함한다. 아래 시안·`assets/` Codex 원본은 로컬 전용이며 `.gitignore`로 제외했다.

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
- 자동 검사: `verify_battle_hud.gd`가 비용 미만 회색 잠금(눌러도 확인창 없음)·비용 이상 활성·가격·위치(자원 패널 아래 왼쪽, 카메라 토글과 겹치지 않음)·에셋 로드·확인창만 열림·취소 시 파편 유지·구매 1회 차감·구매 선택 중 숨김을 확인한다.
- 2026-10-19 변경: 파편이 비용 미만일 때 숨기던 동작을 회색 잠금으로 바꿨다. 실제 앱 캡처 `implemented-440-grey.png`(파편 19)로 활성 상태와 구분되는 것을 확인했다.
- 2026-10-19 효과 추가(A+C안): 활성화 순간 연출(`godot/ui/hud_gem_shortcut_fx.gd`, 링 번쩍임·반짝임·확대)과 셰이더 `TIME` 기반 결정 광택(CPU 반복 작업 없음). 실제 앱 프레임 캡처(약 30fps, 파편 19 → 20)로 만든 로컬 GIF `implemented-fx-zoom.gif`(3배 확대)·`implemented-fx-context.gif`(왼쪽 위 2배)로 확인했다. 첫 시도의 `+` 모양 빛 조각이 결정 위에 찍혀 UI 기호처럼 보여 링 바깥 네 갈래 반짝임으로 바꿨다.
- 미확인: 320px 폭 캡처와 Android 실기기 터치는 확인하지 않았다.

## 시안 기록

로컬에는 승인 결정의 근거가 된 시안만 남겼다. 바탕 캡처(스테이지 26 실제 앱)와 거절 후보는 삭제했다.

| 파일 | 내용 |
| --- | --- |
| `04-confirm-modal.png` | 확인창 흐름 시안(기존 전투 모달 외형, 비용·보유 변화·취소/구매). 제목 아이콘은 초기 다이아형이라 구현에서 6번 아이콘으로 바꿨다. |
| `06-gem-crystal-trio.png`, `06-gem-crystal-trio-closeup.png` | 승인안. 상단 패널 아래 왼쪽 원형 소켓, 금·청·적 결정 3개를 한 발톱에 묶은 아이콘, 파편 가격표 |

- 거절 후보: 1~3번은 배치 비교(원형 소켓·왼쪽 끝 탭·사각 알림 버튼)였고 1번 배치를 택했다. 그 아이콘은 브릴리언트 컷이라 다이아 재화처럼 보인다는 피드백을 받아, 실제 젬 원본(`assets/images/gems/simplified/`)의 길쭉한 결정·금속 발톱 형태로 5번(단일 청색 결정)·6번·7번(무지개 결정)을 다시 만들고 6번을 승인했다.
- 도구: Codex image_gen(`codex-imagegen` 스킬). 실제 앱 캡처를 `--edit`, `assets/images/ui/hud/icons/gems.png`·`shard.png`·젬 원본·전투 종료 확인창 캡처를 `--ref`로 사용했다.
