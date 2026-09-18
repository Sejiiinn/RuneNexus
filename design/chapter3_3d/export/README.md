# 챕터 3 타일·교체 패널 — 내장 PBR 이관

[승인한 링 없는 타일](../environment_concepts/plain-turret-tile-multiview.png)과 기존 3종 상판을 함께 제공한다. [Blender 원본](../tiles/chapter3-thick-tiles.blend)의 실제 형상을 그대로 베이크했으며, 타일마다 4면 중앙에 실제 패널 좌석을 팠다. 기본 타일 메시에는 측면 주황 창이나 패널이 포함되지 않는다. 격자 상부 25개 관통구멍과 내부 열판은 유지한다.

- 게임 파일: [chapter3_tiles.glb](../../../assets/images/stage1_3d/environment/chapter3_tiles.glb)
- 실제 GLB 조립: [4종 대표 렌더](glb-reimport-hero.png), [빈 좌석·막힌 패널·환기 패널 깊이 비교](glb-reimport-panel-depth.png)
- 검사: [geometry-check.json](geometry-check.json), [원본 좌석 ray 검사](../tiles/modular_revision/seat-verification.json)
- 재현: 독립 background Blender에서 `export_native.py`, `render_reimport.py` 순서 실행. 열린 Blender 문서는 보존한다.

루트는 `path_tile`, `grate_tile`, `build_tile`, `plain_build_tile`, `panel_solid`, `panel_vent`다. 각 1 surface이며 모든 원점은 타일 중심이다. 타일은 1×1, 상판 0, 하단 -0.50을 유지한다. 링 없는 상판도 외곽 코너 볼트 4개를 보존한다.

패널은 타일 원점에 그대로 배치하며 Godot Y회전 0/π2/π/3π2로 +Z/+X/-Z/-X 면에 장착한다. 기본 패널은 Blender -Y 전면에 모델링되어 GLB에서 +Z가 된다. 좌석 폭 .296, 높이 .250, Blender Z=-.405..-.155이다. 외부 보강대 전면은 -.500, 환기 프레임 전면 -.485, 열원 전면 -.465로 .020의 실제 안쪽 깊이를 확보했다. 열원 앞에 막힌 벽이 없고 프레임·기둥·안쪽 리턴·열원·뒷벽이 개별 입체 형상이다. 일반 패널은 좌석을 막는다.

공용 2048² atlas의 Base Color·Roughness·Metallic·Normal·Emission 5채널을 GLB 안에 포함한다. 색·방출은 조명을 포함하지 않는 EMIT 베이크이며 Normal은 tangent 공간이다. 런타임 재색칠을 요구하지 않는다. 삼각형은 path 24,416 / grate 30,320 / build 24,916 / plain 16,276 / solid 2,660 / vent 4,048개다. 재임포트 위치 오차는 6종 모두 0이다.

최종 GLB 18,672,584 bytes, SHA-256 `eedef06047fe74d093e8b356fd91dc4c6d88cf039ee364e7d2b60ce48302818f`. 이전 16,667,400 bytes보다 2,005,184 bytes 증가했으며 원없는 상판·2종 교체 패널의 메시와 같은 2048² atlas에 추가한 재질 영역 때문이다. 환경 파이프나 외부 장식은 포함하지 않았다. Android 최종 인게임 판정은 부모 작업의 스테이지 11 통합 검증에서 진행한다.

Android 55도 고정 시점에서 열원이 점처럼 작아지던 결함을 환기구 프레임·개구·실제 열원 깊이에서 수정했다. 이전 .092 후퇴는 현재 .020으로 대체했다. 개구 높이 .200, 열원 폭 .044·높이 .201로 주황 세로 3슬롯을 보존한다. 발광 강도와 다른 4종 타일·막힌 패널 형상은 변경하지 않았다. 대표 GLB 조립 렌더와 [원본 확인](../tiles/modular_revision/vent-55deg-source.png)은 고도 55도이다. 원본·GLB 자체 형태 확인이며 Android 게임 크기 최종 판정은 스테이지 11 통합 검증에서 진행한다.

2026-09-18 형태 검수 PASS: Blender 5.2.1 LTS / Cycles 32 samples / 정투영 고도 55도 / 1800×950에서 원본과 재임포트 GLB 모두 세로 주황 슬롯 3개를 확인했다. GLB와 베이크 채널 입력은 위 SHA-256 및 geometry-check.json에 연결된다. Android는 별도 통합 검수 대상으로 남긴다.
