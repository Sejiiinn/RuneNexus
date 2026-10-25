# 지원 코어 게임용 모델

[E2 Blender 원본](../blender/README.md)을 게임에 넣었다(2026-10-25). 게임 모델은 `assets/images/stage1_3d/turrets/support_core.glb`, 건설 아이콘은 `assets/images/ui/hud/turrets_3d/supportCore.png`다. 규칙·저장·화면은 [지원 코어 설계](../../../docs/support_core_design.md)가 기준이다.

- [베이크·내보내기 스크립트](export_game.py)와 [검사 기록](export-check.json):
  - 원본의 평가 메시를 그대로 쓴다. 감량·Decimate 없이 10,844 삼각형이다.
  - 모델이 쓰는 금속 3종(철·청동·홈 금속)의 절차 재질을 1024 색·거칠기·노멀 아틀라스 한 벌로 굽는다. 화염·독 포탑과 같은 방식이다. 제작 코드의 강철 재질은 정의만 있고 쓰이지 않는다.
  - 아틀라스에는 금속 면만 펼쳐 같은 밀도로 다시 배치한다(`average_islands_scale`, `pack_islands`). 처음에는 발광·결정 면까지 자리를 차지해 절반 이상이 비어 있었다.
  - 짧은 거리(0.05)의 앰비언트 오클루전을 따로 구워 색에 85% 곱한다. 홈과 맞닿은 모서리가 시안처럼 어두워지고, 게임의 모바일 조명만으로는 생기지 않는 깊이가 난다.
  - 팔마다 홈·캡 창의 발광 재질을 따로 둔다(`... | arm <i>`). 게임은 이 표면의 위치로 팔 방향을 구해, 연결된 포탑 쪽 팔만 켜고 나머지는 어두운 재질로 바꾼다.
  - 발광 재질(룬 홈·우물·캡 창·결정 심)은 강도 1로 내보낸다. glTF 확장을 쓰지 않으려는 것이다. 게임에서 재질별 발광 배율을 1.8~2.6으로 올린다(`support_core_presentation.gd`).
  - 떠 있는 결정의 껍질·파편은 원본에서 투과 보석 재질이다. glTF 투과는 확장이 필요하므로 GLB에는 반투명 대체 재질로 내보내고, 게임이 유리 셰이더(`godot/effects/support_core_crystal.gdshader`)로 바꾼다. 기지 코어 결정의 유리 셰이더와 같은 방식으로 뒤쪽 화면을 굴절해 비춘다.
  - GLB는 메시 2개(본체, 결정), 이미지 3장, 약 3.9MB다.
- 계층: `support_core_root` → 본체 메시와 `core_crystal`. 게임은 결정을 천천히 띄우고 돌린다. 축척은 타일 폭 1.0이고, 끝 캡 바깥면이 타일 가장자리에 닿는다.
- 건설 아이콘은 설치한 GLB를 포탑과 같은 고정 HUD 카메라(직교 1.45)로 렌더한다. 결과 범위는 [`hud-icon-verification.json`](hud-icon-verification.json)에 있다. 몸체가 낮고 넓어서 포탑 아이콘보다 작게 보인다. 같은 축척을 유지하려고 확대하지 않았다.

## 실제 화면

정식 준비 경로(`prepare_godot_project.py`와 import)로 만든 프로젝트에서 실제 `main.gd`와 앱 HUD를 띄웠다. 오프라인 게스트 런(격리 저장, 네트워크 없음), 3-3(ID13), 골드 3000의 검사 예산이다. HUD 버튼으로 지원 코어를 지었다. 재현 스크립트는 [capture_support_core.gd](review/capture_support_core.gd)다.

| 캡처 | 내용 |
| --- | --- |
| [건설 단계](review/1-build-gem-choice.png) | 지원 코어 선택, 미리보기 모델, 상하좌우 건설 칸 윤곽, 소비할 젬 선택 |
| [코어 상세](review/2-core-detail.png) | 피해 증가, 연결된 포탑 2기, 소비한 젬, 철거 +112 G. 연결된 동·남쪽 팔만 빛나고 북·서쪽 팔은 꺼져 있다. |
| [강화받는 포탑](review/3-turret-detail.png) | 분류 줄의 "연결 피해 +15%" |
| [드론 시점](review/4-field-drone.png), [확대](review/4-field-drone-zoom3x.png) | 기본 배율의 연결 빛줄기와 받침 고리 |
| [고정 시점](review/5-field-angled.png) | 기본 전장 |
| [근접 사선](review/6-close-angled.png), [근접 위](review/7-close-high.png) | 별도 근접 카메라. 게임 조명·재질·효과는 그대로다. 2D 레벨 표시는 주 카메라 기준이라 근접 화면에서는 위치가 어긋난다. |
| [파동 단계(근접)](review/8-pulse-close.png), [파동 단계(게임 거리)](review/9-pulse-game.png) | 왼쪽부터 같은 시각의 다섯 단계: 팔 번쩍임과 출발, 이동, 도착 직전, 고리 번쩍임, 물결 확산. 단계마다 전투 시계를 고정해 찍었다. |
| [파동 영상](review/support-core-pulse.mp4), [GIF](review/support-core-pulse.gif) | 같은 근접 위 시점, 30fps로 세 주기(4.2초), 880×756. `capture_support_core.gd -- <폴더> --gif --video`가 같은 월드를 화면 밖 2배 뷰포트로 렌더해 원시 프레임을 저장한다(우주 배경은 창 화면을 확대해 깐다). [make_video.py](review/make_video.py)가 ffmpeg로 MP4(H.264)와 절반 크기 20fps GIF를 만든다. ffmpeg는 `~/.venvs/media-tools`의 `imageio-ffmpeg`다(Homebrew·관리자 권한 불필요). `--video` 없이 찍은 프레임은 표준 라이브러리 [make_gif.py](review/make_gif.py)로도 묶을 수 있다. |

- 드론 확대 화면의 연기는 방금 지은 포탑의 설치 먼지다.
- 처음에는 게임 조명에서 청동이 광택 있는 황동색으로 보였다. 청동의 금속성(.62)·거칠기(.5~.7)를 낮추고 홈 음영을 늘려 시안의 무광 청동에 가깝게 했다.
- Android 실기기 화면·성능은 확인하지 않았다.

## 재생성

저장소 루트에서 실행한다.

```sh
cd design/support_core_concepts/game
/Applications/Blender.app/Contents/MacOS/Blender -b ../blender/support-core-E2.blend --factory-startup --python export_game.py -- --install
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python render_hud_icon.py
```
