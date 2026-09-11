# 챕터 1 포탑·적 형태 개선

사용자 피드백에 따라 타일과 조명·구도를 유지하고 기관총, 적 6종, 냉각 포탑 GLB를 개선했다.

- 기관총: 현행 2D의 회색 리시버·후방 탄창·중앙 황동 원판을 입체화하고 쌍열과 본체의 연결을 보강했다.
- 적: 기존 종별 색과 가시 실루엣을 유지하면서 곡면 다면체 외피·감싸는 장갑·함몰형 결정 핵을 적용했다.
- 냉각 포탑: 기존 2D 형태에 구애받지 않고 비대칭 얼음 결정과 낮은 서리 금속 받침으로 제작했다.

`stage1-actors-refined.png`는 당시 개선 GLB를 배치한 Blender 렌더이며 실제 게임 실행 캡처가 아니다. `stage1-actors-refined.blend`는 상세 환경·절차 재질·조명의 상위 편집 원본이자 당시 배우 배치 검수 파일이다. 이 파일에 배치된 모델을 모두 최신 게임 모델로 간주하지 않는다. 특히 대포의 마지막 도장 보정은 이후 제작됐다.

현재는 실제 3D 시험 앱에 포탑·적 모델이 연결되어 있다. 이 원본의 전체 정적 환경은 `../environment/terrain-approved.blend`에 병합되었고, 원래 위치에서 평가한 지면 재질 atlas와 함께 게임의 `assets/images/stage1_3d/environment/terrain.glb`에 반영됐다. 환경 제작 경로는 [환경 기준](../environment/README.md), 최신 포탑별 원본은 [포탑 기준](../turrets/README.md)을 따른다.

`render_actors.py`는 배치 검수 장면을 구성하는 제작 스크립트다. 현재 게임 GLB를 가져오므로 실행 당시 에셋에 따라 결과가 달라지며 저장된 과거 검수 장면을 그대로 재현한다고 보장하지 않는다. 기존 상세 원본을 다시 만들 목적으로 무심코 실행하지 않는다. 현재 작업·원본·게임 적용 상태의 진입점은 [Blender 작업 허브](../blender_workspace/README.md)다.

재질 출처는 `design/high_fidelity_battlefield/production/textures/SOURCES.md`, 최초 지형 방향은 `../direction_preview/README.md`를 참조한다.
