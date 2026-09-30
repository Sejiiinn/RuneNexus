# SWIFT 경량판 게임 거리 독립 검수

확인: 2026-09-26. 구현 담당과 별개의 Astra가 경량화된 최종 GLB와 기존 GLB를 직접 읽고 실제 Godot GPU 화면을 비교했다. 게임 파일을 교체하지 않았다.

**판정: PASS.** 동일한 게임 시점·조명·배율의 1:1 원본 픽셀에서 경량화로 인한 의미 있는 추가 흐림이나 실루엣 손실을 확인하지 못했다. 낮은 기둥·3발, 긴 포신, 곡면 헤드와 금속 명암이 유지된다. 최대 원거리에서 렌즈·룬·볼트는 원본도 수 픽셀 이하로 표시되므로, 모든 세부가 확대 이미지처럼 읽힌다는 의미는 아니다. 경량판만의 추가 소실은 보이지 않는다.

## 비교 화면

비교 크롭은 **왼쪽 원본 / 오른쪽 경량판**이다. Godot `Image.blit_rect`로 원본 픽셀을 그대로 옮겼으며 확대·보간·색 보정이 없다.

- [고정 시점 1:1 비교](angled-native-pair-left-original-right-optimized.png)
- [드론 시점 1:1 비교](drone-native-pair-left-original-right-optimized.png)
- [고정 원본 전체](original-angled-full.png), [고정 경량판 전체](optimized-angled-full.png)
- [드론 원본 전체](original-drone-full.png), [드론 경량판 전체](optimized-drone-full.png)

## 실제 재현 조건

Godot 4.7.2, Apple M4, Metal Forward Mobile. 현재 `godot/` 소스 사본과 준비된 게임 에셋·import 캐시를 참조하는 격리 프로젝트에서 `main.tscn`의 스테이지 1 지형·조명을 사용했다. 공유 준비 프로젝트는 현재 소스보다 이전 구조였으므로 수정하지 않고 소스 사본을 사용했다. 임시 사본은 촬영 후 제거했다.

창과 PNG는 **440×900 물리픽셀**이고, `canvas_items` stretch에 따른 실제 논리 viewport는 **880×1800**이다. `battle_hud.gd`와 같은 공식에 desktop safe inset=0을 적용한 전장 Rect2는 `(8,110,864,1498)`이다. HUD 자체는 표시하지 않았으나 **HUD 없는 fixture의 자동 배율을 사용하지 않고** 현재 `battlefield_camera.gd.fit_frame(..., formal_rect, true)`로 정식 배율을 계산했다.

맵은 공용 stage1 preview map 8×10이며, 비교 대상만 grid 중심 `(3.5,4.5)`에 scale=1, head yaw=0으로 교대로 배치했다. 다른 포탑·적·투사체를 제거한 정지 조건이다. 카메라는 ORTHOGRAPHIC/KEEP_HEIGHT, zoom=1.0(가장 먼 배율), 기본 그림자와 MSAA 2× 조건이다.

| 시점 | 카메라 위치 | camera.size | 물리 px/tile | 원본 포탑 투영 크기 | 경량판 투영 크기 |
| --- | --- | ---: | ---: | ---: | ---: |
| 고정 | (5,27,13) | 21.50133 | 41.85787 | 35.08960×49.52005 px | 35.05400×49.48828 px |
| 드론 | (0,30,0.001) | 18.12500 | 49.65517 | 38.93855×69.11035 px | 38.78273×69.11035 px |

두 GLB의 카메라 자세·오프셋·size는 동일하다. 투영 경계 차이는 최대 약 0.16px이며, 이는 원본 픽셀 비교에서 실루엣 손실로 읽히지 않는다. 크롭의 금속 면별 밝기에는 세부 법선·베벨 감소에 따른 작은 차이가 있지만 재질의 정체성을 해치지 않는다. 상세 조건은 [capture-conditions.json](capture-conditions.json)에 남겼다.

## 최종 파일 직접 검사

두 GLB의 JSON·index accessor·내장 PNG를 직접 파싱했다. 구현자의 자체 PASS를 재인용하지 않았다.

| 항목 | 원본 | 경량판 |
| --- | ---: | ---: |
| 삼각형 | 43,380 | 9,816 |
| 파일 바이트 | 3,228,344 | 1,350,476 |
| 메시 / 재질 | 3 / 5 | 3 / 5 |
| 내장 텍스처 | 1024×1024 PNG 3장 | 1024×1024 PNG 3장 |

삼각형 **77.37% 감소**, GLB 크기 **58.17% 감소**. root→head→barrel→muzzle 계층, 모든 노드 변환, head 높이 0.45와 muzzle 좌표가 동일하다. 금속 재질 factor도 일치한다. roughness는 두 GLB 모두 텍스처를 사용하므로 factor 값만을 실제 표면 거칠기로 해석하지 않았다. 상세 파싱 결과와 SHA-256은 [asset-comparison.json](asset-comparison.json)에 있다.

## 재현과 한계

저장소 루트에서 `python3 design/sniper_tower_concepts/2026-09-26/production/optimized-game-distance/review/reproduce.py`를 실행하면 임시 현재 소스 프로젝트를 만들어 같은 캡처·원본 픽셀 비교를 생성한다. 실제 촬영 로직은 [capture_compare.gd](capture_compare.gd), 무보간 비교 배치는 [pack_native.gd](pack_native.gd)다.

이번 결과는 정식 카메라 계산을 사용하는 데스크톱 Godot의 모델 비교다. 실제 앱 HUD 조작·게임 저장·Android·FPS·GPU 시간·메모리 개선은 검증하지 않았다. 폴리곤·파일 크기 감소를 전체 게임 성능 개선율로 주장하지 않는다. 원본과 경량판은 모두 runtime GLTFDocument로 로드했으며, 향후 영구 이식 시 editor import 압축·모바일 기기의 차이는 이 판정에 포함되지 않는다.
