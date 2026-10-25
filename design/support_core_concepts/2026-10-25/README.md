# 지원 코어 외형 시안 (2026-10-25)

[지원 코어 설계](../../../docs/support_core_design.md)의 본체 외형 후보다. 승인 전 시안이며 실제 게임 화면이 아니다.

- 생성: Codex 이미지 생성(`codex-imagegen` 스킬, `gpt-6.1-sol`)
- 스타일 참고: [승인 화염 포탑 14번 시안](../../fire_tower_concepts/2026-09-14/14-runic-mechanism.png). 재질·카메라·조명만 맞추고 형태는 따르지 않도록 지시했다.
- 공통 프롬프트: [common-prompt.txt](common-prompt.txt). 비공격 구조물, 상하좌우 네 방향 연결부, 청록 발광을 공통 조건으로 두고 각 안은 공통 프롬프트 뒤에 아래 설명을 덧붙였다.

| 안 | 파일 | 형태 |
| --- | --- | --- |
| A 룬 오벨리스크 | [A-rune-obelisk.png](A-rune-obelisk.png) | 굵고 짧은 오벨리스크, 꼭대기에 뜬 청록 결정, 받침 네 변의 발광 노드 |
| B 공명 고리 | [B-resonance-rings.png](B-resonance-rings.png) | 교차한 청동 고리 두 개 안의 청록 구체, 받침 네 변의 렌즈 돌기 |
| C 연결 기둥 | [C-conduit-pylon.png](C-conduit-pylon.png) | 낮은 중앙 기둥에서 십자로 뻗은 청동 도관 팔, 팔 끝의 결합 소켓 |
| D 젬 도가니 | [D-gem-crucible.png](D-gem-crucible.png) | 젬이 녹아 에너지로 오르는 도가니, 받침 윗면을 따라 네 변으로 흐르는 룬 홈 |

### A·C 절충안

사용자가 A와 C의 절충을 요청했다. A·C 이미지를 함께 참고로 넣고 공통 프롬프트 뒤에 절충 설명을 덧붙였다.

| 안 | 파일 | 형태 |
| --- | --- | --- |
| E1 오벨리스크 + 도관 | [E1-obelisk-conduit.png](E1-obelisk-conduit.png) | A의 높은 오벨리스크와 떠 있는 결정이 중심, 바닥 판 위로 타일 가장자리까지 뻗은 얇은 도관 팔 |
| E2 낮은 오벨리스크 + 굵은 도관 | [E2-short-obelisk-conduit.png](E2-short-obelisk-conduit.png) | 3분의 2 높이의 오벨리스크, 넓고 굵은 도관 팔과 큰 결합 소켓이 주된 형태 |

사용자 판정: 절충이 아니라 A에 C의 부품을 끼워 넣은 수준이라 기각.

### A·C 융합 재작성

A·C 이미지를 참고로 넣지 않고 새로 그렸다. 오벨리스크와 네 방향 도관을 이음매 없는 한 덩어리로 만들도록 지시했다. 프롬프트는 [fusion-prompts.txt](fusion-prompts.txt)에 있다.

| 안 | 파일 | 형태 |
| --- | --- | --- |
| F1 뿌리 첨탑 | [F1-rooted-spire.png](F1-rooted-spire.png) | 첨탑 아래가 네 갈래 뿌리로 휘어 내려 타일 가장자리까지 뻗음, 꼭대기 결정에서 뿌리 끝까지 청록 홈이 끊김 없이 이어짐 |
| F2 십자 단면 오벨리스크 | [F2-cruciform-obelisk.png](F2-cruciform-obelisk.png) | 단면이 십자인 네 장의 날개 돌이 결정을 감싸 올라감, 날개 바깥 모서리가 바닥 판 끝까지 내려옴 |
| F3 갈라진 모노리스 | [F3-parted-monolith.png](F3-parted-monolith.png) | 네 조각으로 갈라진 오벨리스크, 가운데 틈에 청록 빛, 각 조각의 발이 낮은 레일이 되어 네 방향으로 뻗음 |

### E2 비중 반영

사용자가 F안에 E2 느낌을 더 원했다. E2 이미지는 넣지 않고, 낮고 넓은 비례·굵은 도관·큰 청동 끝 소켓을 글로 지시했다.

| 안 | 파일 | 형태 |
| --- | --- | --- |
| G1 낮은 뿌리 첨탑 | [G1-squat-rooted-spire.png](G1-squat-rooted-spire.png) | 짧은 첨탑의 네 능선이 그대로 굵은 팔이 됨, 결정에서 팔 끝 소켓까지 넓은 청록 홈이 이어짐 |
| G2 낮은 갈라진 모노리스 | [G2-squat-parted-monolith.png](G2-squat-parted-monolith.png) | 네 조각 모노리스 가운데 틈의 빛, 굵은 팔과 큰 끝 소켓. 팔이 바닥 판 위에 얹힌 막대처럼 보여 융합이 약함 |

결정 상태: 사용자가 F·G 융합안 대신 E2안을 골랐다(2026-10-25). E2안 Blender 원본은 [../blender/](../blender/README.md)에 있다.
