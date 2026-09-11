# 챕터 1 분위기·고밀도 재질 방향 확인

2026-09-10 사용자 정정: 기존 챕터 1에서는 분위기만 유지하며, 현재 2D 타일의 단순한 질감까지 따라가지 않는다. 앞선 고품질 전장 시안의 재질 밀도를 적용한다. 통합 작업은 잠시 멈추고 이미지 한 장으로 방향을 먼저 확인한다.

- `stage1-material-direction.png`: 1440×1600 Blender 렌더 1장. 실제 게임 실행 캡처가 아니다.
- `stage1-material-direction.blend`: 편집 원본.
- `render_direction.py`: 실제 `gameMap`의 8×10 칸을 읽고 장면을 만드는 재현 스크립트.

챕터 1의 녹회색 이끼 지형·갈색 길·보라 포털·청록 코어를 유지하고, `design/high_fidelity_battlefield/production`의 석재 PBR에 이끼 피복과 낮은 자연석 가장자리를 결합했다. 성소 벽·기둥·횃불은 사용하지 않았다. 재질 출처는 해당 production/textures/SOURCES.md를 따른다.

포탑·적은 새로 제작한 `assets/images/stage1_3d/` GLB를 배치한 예시이며, 포탑 배치와 몹 위치는 실제 플레이 결과가 아니다. 실제 인게임 형태를 바탕으로 한 모델이다. 이 렌더의 지형 재질은 방향 확인용으로, 기존 `environment/terrain.glb`에는 아직 적용하지 않았다.
