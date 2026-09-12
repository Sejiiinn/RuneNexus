# 스테이지 1 실제 3D 환경

2026-09-11. 승인된 `design/stage1_3d/actor_refinement/stage1-actors-refined.blend`의 전체 정적 환경을 실제 메시 그대로 런타임 GLB에 포함한다. 실제 스테이지 1에서는 `stage1_environment`를 우선 사용하며, 기존 단위 키트 5개도 보존한다.

2026-09-12 추가된 풀·고사리·이끼돌·뿌리 군락과 바람은 [환경 장식 원본](../environment_dressing/README.md)의 별도 `dressing.glb`를 Godot에서 함께 배치한다. 아래 `terrain.glb`의 원본·메시 수·재질 수치는 기존 지형만을 설명한다.

## 파일과 제작

- 게임 파일: `assets/images/stage1_3d/environment/terrain.glb`
- 현행 편집 원본: `terrain-approved.blend`
- 전체 원본 환경 이식: `append_source_environment.py`
- 원본 공간 재질 보존: `bake_authored_floor_atlas.py`, `authored_atlas/`의 2048² 이미지 6장
- 단위 키트 제작: `import_approved_materials.py`, 구조 복원: `restore_source_geometry.py`
- 지면 PBR 소스: `approved_textures/`. basecolor/normal/roughness/cavity 1024² 소스를 GLB의 basecolor/normal/ORM으로 패킹한다.

Blender MCP로 원본을 확인하고 독립 Blender 프로세스에서 append·modifier 적용·재질별 병합·export했다. 원본 actor_refinement 파일은 변경하지 않았다. 단위 키트를 처음부터 다시 생성하면 `append_source_environment.py`로 전체 환경 루트를 추가하고 마지막으로 `bake_authored_floor_atlas.py`를 실행한다.

## 전체 환경 루트 계약

`stage1_environment`에는 원본 흙기단 58개, 길 26개, 건설석판 32개, 외곽 자연석 150개, 이끼 576개, 풀 576개, 뿌리 11개 — 총 **1,429개 원본 오브젝트**가 포함된다. 원본 Bevel·Weighted Normal 및 곡선 두께를 메시로 적용했다. 임의 타일 재배치나 장식 단순화 없이 재질별 **7개 메시 / 65,624삼각형**으로 병합했다.

포탑·적·포털·코어·카메라·광원은 포함하지 않는다. 포털·코어는 기존 개별 루트를 게임에서 배치한다.

- +Y 위, XZ 전장 평면, 타일 1단위.
- 원본의 `(x, y, z)`를 `(x*.5, (z-.082)*.5, -y*.5)`의 glTF 좌표로 변환했다.
- 칸 중심: **X=column−3.5, Z=row−4.5**. 전체 환경 root는 원점이며 자식의 변환은 메시 좌표에 적용했다.
- 원본 상면의 미세 형태 유지: 최고 약 Y=+.0028, 흙기단 최저 Y=−.3335. 풀·뿌리·이끼는 원래 높이 그대로다.
- root extras: `columns: 8`, `rows: 10`, `tileTypes: [...]` 이름 80개의 row-major 배열. 실제 맵 크기·타일 종류가 모두 맞을 때만 사용한다.
- `sourceObjectCounts`, `staticMeshCount`, `tileSize`, `gridCenterConvention`도 extras에 포함한다.

## 보존한 단위 키트

| 루트 | 역할 |
| --- | --- |
| `build_tile` | 녹회색 석재·이끼 건설 칸 |
| `path_tile` | 회갈색 포장길 |
| `blocked_tile` | 필요 시 사용하는 자연석 지면 |
| `portal` | 바닥형 보라 소용돌이 |
| `core` | 청록 결정 코어 |

단위 타일은 XZ1×1·상면 기준Y=0·전체두께.334이며, 기존 루트 및 포털/코어 계약을 유지했다. 전체 환경을 배치한 경우 단위 지면을 중복 배치하지 않는다.

## 재질과 비용

전체 환경의 건설석판·길은 원본 UV에 적용된 Vector Math 스케일과 Geometry.Position/Object 기반 색·이끼 변화까지 원래 위치에서 평가한 전체 스테이지 atlas를 사용한다. 단위 평면을 반복하는 베이크가 원본의 칸별 변화를 잃는 문제를 수정했다. 기존 UVMap은 원본 셰이더 평가용으로 보존한 상태에서 RuntimeAtlas에 bake하고, 런타임에는 RuntimeAtlas만 남겼다. 외곽석재는 기존 C1 PBR을 공유하고 이끼·풀·흙·뿌리 상수재질은 원본값을 보존한다. **내장 이미지18장: 2048²6장 + 1024²9장 + 512²3장.**

원천 사진맵은 Poly Haven의 monastery_stone_floor / cobblestone_floor_08 / castle_wall_slates. 출처와 CC0 기록은 `design/high_fidelity_battlefield/production/textures/SOURCES.md`에 있다.

- GLB **27,957,564 bytes(약26.66MiB)**
- 전체 GLB **74,564삼각형**: 전체환경65,624 + 보존키트8,940.
- basecolor=sRGB, normal/ORM=Non-Color. 원본 Coat0, SpecularIORLevel.5, IOR1.5, metal0 유지.
- cavity는 낮은 홈만 .65~1 범위로 보강하여 ORM R에 포함한다. 전체 밝기를 어둡게 칠하지 않았다.

## 검증 범위

최종 GLB에서 기존 5루트와 새 환경 루트, extras의8×10/타일80개, 내장 이미지18장, 환경메시7개, 원본 오브젝트 수, 변환 후 각 메시 bounds와 삼각형을 확인했다. 원본 정적 요소를 모두 포함하고 동적 배우를 제외했음을 prefix 선택 목록으로 확인했다. 이번 전체 이식에서는 사용자 요청대로 별도 Blender 시각 렌더를 반복하지 않았다. 실제 앱의 최신 비교 화면을 우선한다. 과거 `terrain-glb-import-qa.png`는 단위 키트 검수 기록이다.

전체맵 atlas의 basecolor를 확인하여 칸별 석재 샘플과 색 변화가 보존됨을 검증했다. 원본의 장식 크기·위치·메시 수는 이번 UV 수정에서 바꾸지 않았다.
