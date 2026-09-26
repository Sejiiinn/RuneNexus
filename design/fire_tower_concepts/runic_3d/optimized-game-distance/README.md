# 룬 화염 포탑 경량 모델 적용

사용자가 저격 포탑과 같은 조건의 경량 비교를 요청했다. 현행 [90% 크기 모델](../scale-90/README.md)을 기준으로 팔각 몸체·단일 총구·주황 룬 홈·청동 지지대와 금속 재질을 유지하는 경량 모델을 제작했고, 사용자 승인에 따라 게임의 `assets/images/stage1_3d/turrets/magic.glb`에 적용했다. 고해상도 제작 원본과 불꽃 효과는 보존한다.

- [편집 원본](runic-fire-optimized.blend), [경량 GLB](runic-fire-optimized.glb), [확대 렌더](runic-fire-optimized-hero.png)
- [부품별 감축 기록](optimization-manifest.json), [제작 스크립트](build_optimized.py), [내보내기 스크립트](export_optimized.py)

본체는 46,795삼각형에서 11,411개로 약 75.6% 줄었다. 부품별 베벨·원주 분할을 줄였으며 음각 룬 패널과 속이 빈 팔각 총구의 형상은 보존했다. 임의의 1만 삼각형 목표보다 원거리에서 읽히는 형태와 금속 표현을 우선했다.

GLB는 3메시·5재질이며 약 7.22MB에서 2.86MB로 줄었다. [내보내기 검사](export-check.json)에서 90% 크기·계층·부착점과 총구 내부 깊이, 원본 보존을 확인했다.

비교 조건은 [저격 포탑 S26 Ultra QHD+ 비교](../../../sniper_tower_concepts/2026-09-26/production/optimized-game-distance/review/s26-ultra/README.md)와 같다. 1440×3120 SubViewport에서 3D 렌더 배율 1.0, 정식 앱의 440×760 기준 논리 배율·HUD 영역 계산, 줌 1.0, 같은 타일·방향·조명으로 고정·드론 시점을 비교한다. 실기기 캡처가 아니며 안전 영역은 0으로 가정한다.

두 버전 모두 실제 게임의 `Runes |` 재질에 적용하는 Unshaded 설정을 사용한다. 본체 차이를 확인하는 비교이므로 불꽃 VFX는 제외하고 기존 효과는 변경하지 않는다. 총구·상부 불꽃 마커와 조준·반동 계층, 전체 90% 배율의 보존은 별도로 확인한다.

[고정 시점 비교](review/angled-native-pair-left-original-right-optimized.png) · [드론 시점 비교](review/drone-native-pair-left-original-right-optimized.png)는 왼쪽 원본 / 오른쪽 경량본을 원본 픽셀 크기로 나란히 놓았다. [경량본 전체 전장](review/optimized-angled-full.png)은 1440×3120 렌더다. 미세한 베벨·곡률 차이는 있으나 두 시점에서 주요 실루엣·주황 룬·청동 반사·총구 가독성을 유지했다. [캡처 조건](review/capture-conditions.json), [파일 비교](review/asset-comparison.json), [재현 스크립트](review/reproduce.py)를 보존한다.

게임 에셋 교체는 본체에 한정하며 전투 수치·불꽃 효과·기존 HUD 아이콘은 유지한다. Android 실기기 FPS/발열 측정은 수행하지 않았다. 삼각형 감소율을 전체 성능 향상률로 해석하지 않는다.

[독립 검수](review/independent-review.md)는 두 시점의 시각 비교와 90% 크기·계층·총구 및 상부 불꽃 마커 보존을 PASS로 판정했다. 불꽃 VFX의 실제 동작은 이 초기 비교 검수에 포함하지 않았다.

게임 적용 후에는 격리 프로젝트에서 변경된 게임 GLB를 실제 import해 화염 효과·런타임 통합 검사를 통과했다. [적용 독립 검수](integration/independent-review.md)에서 상부 불꽃 부착·조준·발사·복귀와 90% 크기를 확인했다. [실행·재현 안내](integration/README.md), [근접 실행 영상](integration/runtime-fire-close-preview.mp4)과 [발사 화면](integration/runtime-fire.png)을 보존한다. Android 실기기 성능은 미측정이다.

비교 재현 시 고해상도 원본은 교체 전 커밋의 GLB를 임시 추출하고 해시를 확인한다. 현재 게임 GLB를 과거 원본으로 간주하지 않는다. 편집 가능한 경량 원본에서 `export_optimized.py`를 실행하면 게임용 GLB를 별도 제작 폴더에 다시 내보낼 수 있다. `build_optimized.py`는 이전 고해상도 편집 원본이 있을 때 최초 감축 과정을 재현하는 기록이다.
