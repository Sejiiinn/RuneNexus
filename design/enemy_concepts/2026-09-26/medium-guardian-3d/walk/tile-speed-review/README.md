# 타일 이동속도에 맞춘 일반몹 걷기 — V2

**상체 움직임까지 보완한 현재 권장본은 [V3](v3-upper-body/README.md)다.** 이 문서는 [V2 원본](medium-guardian-walk-v2.blend)의 타일 속도 검증 기록이다. 이전 [V1](../README.md)은 속도 불일치 비교용으로 보존했다. 모델·게임 이동속도·게임 내 표시 폭을 바꾸지 않고 보폭과 주기를 개선했다.

- [실제 타일 전진 비교 영상](tile-walk-comparison.mp4): 위 3/4, 아래 수직에서 25° 드론. 각 화면 왼쪽은 V1, 오른쪽은 V2다.
- [3/4 비교](tile-walk-three-quarter.mp4) · [드론 비교](tile-walk-drone-25.mp4) · [V2 걷기](tile-walk-v2.mp4)
- [실제 전진 검수 씬](tile-traversal-review.blend) · [편집 가능한 V2 리그](medium-guardian-walk-v2.blend)
- [위상별 실제 렌더](contact-sheet.png) · [수치 원자료](tile-review-metrics.json)

## 검증한 게임 계약

게임 기본 이동속도는 `31.5 / 48 = 0.65625 tile/s`다. [game_content.json](../../../../../../godot/content/game_content.json)의 일반몹 speed와 tileSize를 사용하며, 현행 normal 모델은 폭 1로 정규화한 뒤 `presentationScale=0.55`를 적용한다. 따라서 이 모델도 원본 evaluated 정점 폭 **4.1295192242**를 기준으로 정규화하여 **표시 폭 0.55 tile**, uniform scale **0.1331874 tile/model-unit**를 유지한다.

| 항목 | V1 | V2 |
| --- | ---: | ---: |
| 걷기 한 주기 | 1.2초 | **0.433333초** |
| 각 발 지지 비율 | 60% | 55% |
| 지지 구간의 발 후진 거리 | 0.42 model-unit | **1.174332 model-unit** |
| 애니메이션 대응 타일 속도 | 0.077693 tile/s | **0.65625 tile/s** |
| 실제 타일 검수의 몸체 속도 | 0.65625 tile/s | 0.65625 tile/s |
| 월드 지지발 평균 속도 | -0.578557 tile/s | **0.00000910 tile/s** |

V1은 제자리 스튜디오에서는 루프가 자연스럽게 보였지만 실제 표시 크기로 줄이면 보폭이 부족해, 게임 속도로 전진할 때 발이 바닥을 빠르게 미끄러졌다. V2는 보폭을 늘리고 주기를 줄여 짧은 돌 다리의 빠른 종종걸음으로 맞췄다. 한 주기 60fps의 **26프레임**이며 27프레임은 1프레임과 같은 폐쇄 키다. 발 들림은 0.18 model-unit, 어깨 스윙은 ±15°다. 골반을 Rest보다 0.18 model-unit 낮춘 보행 자세로 길이를 늘리지 않고 발의 도달 범위를 확보했다. 형상·비율·재질과 모든 돌 부품의 강체 성질은 그대로다.

## 실제 타일 전진 확인

검수 씬에는 현행 길 타일 원본 `design/stage1_3d/surface_effects/terrain-surface.blend`의 `path_tile_natural_surface`를 사용했다. 두 몹 모두 같은 시간에 **3.2046875 tile**을 이동한다. 카메라는 몹을 따라가므로 바닥 타일이 흐르지만, 모델 root는 월드 -Y로 실제 이동하며 타일은 고정되어 있다. 60fps, 294프레임, 4.9초 영상이며 첫~마지막 프레임 사이 실제 경과는 293/60초다.

Blender EEVEE에서 원본 mesh/material graph를 유지한 채 960×640으로 각 시점 294장을 렌더했다. 비교 영상과 단독 크롭은 이 실제 프레임만 패킹했다. 3/4와 드론의 부모 씬, 접지, 모델 재질은 동일하다. 타일 원본의 돌 표면과 조명 반응까지 실제 3D다.

0.25프레임 간격 1,173상태의 월드 좌표를 검사했다. V2 지지발 바닥 높이 오차는 최대 **4.59e-6 tile**, 월드 지지발 속도는 최대 **0.0005723 tile/s**(게임속도의 약 0.087%), 다리 연결 관절 간격은 최대 **6.71e-8 tile**다. [측정 스크립트](measure_tile_review.py)와 JSON에 V1/V2의 모든 측정 좌표를 함께 남겼다. 복제 씬의 모든 메시 월드 변환은 `원본 평가 변환 × uniform 배치 변환`과 생성 시 대조하여, 골격 복사 과정에서 부품이 분리되거나 변환이 중복되지 않도록 검사한다.

이동 계산은 [native_enemy_state.gd](../../../../../../godot/combat/native_enemy_state.gd), 표시 스케일 적용은 [battlefield_units.gd](../../../../../../godot/presentation/battlefield_units.gd)를 따른다.

## 향후 게임 연결 계약

게임 적용은 이번 작업에 포함하지 않았다. 연결 시 애니메이션 위상은 실제 이동 거리로 계산한다.

```text
cycle_distance = 0.65625 × (26 / 60) = 0.284375 tile
phase = (distance_travelled / 0.284375) mod 1
```

시간으로 누적한다면 `delta × simulation_speed × slow_multiplier / (26/60)`를 이동과 같은 시계에 적용한다. 정지 시 위상도 정지한다. 감속과 배속이 이동에만 적용되거나 애니메이션에만 적용되면 다시 발 미끄럼이 생긴다. 4배속은 이동 **2.625 tile/s**, 주기 **0.108333초**이며 같은 위상/거리 관계를 유지한다. 1배속과 4배속 모두 게임 속도 수치를 변경하지 않는다.

## 재생성

- `build_walk_v2.py`: 기존 정적 승인 모델에서 V2의 실제 본과 rigid parenting, 0.1프레임 키 생성. 원본/V1/열린 다른 씬 보존.
- `finalize_walk_v2.py`: 별도 background Blender에서 V2를 정상 기본 씬으로 저장.
- `build_tile_review.py`: 실제 타일과 V1/V2 복제본을 별도 검수 씬에 배치, 같은 월드 이동속도로 키 생성.
- `render_tile_review.py`: 별도 background Blender에서 직접 재오픈·정규화하고 두 실제 시점 렌더. `-- draft`는 대표 4위상씩 확인한다.
- `measure_tile_review.py`: 실제 재오픈한 씬의 root 거리, 월드 발 접지/속도 및 관절 간격을 기록.
- `pack_tile_review.sh`: 기존 ffmpeg로 영상/위상 시트 패킹. `FFMPEG` 환경변수로 실행 파일 변경 가능.

원본 V1의 형태·루프 독립 검증은 통과했으나 타일 속도 적합성을 뜻하지 않았으며, 이번 검증에서 그 범위를 분리해 보정했다. V2는 [최종 독립 검증](independent-review.md)에서 원본 형태·재질 보존, 양 시점의 실제 타일 전진, 접지, 관절 연결 및 루프를 통과했다. 검증 범위와 수치, 남은 게임 통합 범위는 해당 보고서를 따른다.
