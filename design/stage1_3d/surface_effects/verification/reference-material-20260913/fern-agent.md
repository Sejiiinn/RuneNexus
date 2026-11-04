# 고사리 그림자 개선 · 2026-09-13

실제 기준 시안과 변경 전 Android 화면을 직접 확인했다. 기존 고사리 아래 검은 다각형 경계를 실제 잎 범위에 맞춘 중심 차폐와 부드러운 외곽으로 바꾼다. 최종 Android 시각 판정과 패키징은 주 에이전트가 맡는다.

## 확정 원인과 해결

새 GLB를 Godot에서 자동 LOD로 단순화하면서 낮고 닫힌 그림자 외피가 실제 게임 시점에서 소거되어 그림자가 사라졌다. 주 에이전트의 기존 GPU 검수 경로에서 `lod_bias=128`만으로 그림자가 복원됨을 확인했다. `shadow_mesh=null`은 필요하지 않았으며, 전용 Alpha Hash 셰이더 `.80/.16`에서도 중심과 부드러운 외곽이 복원됐다.

원인을 파악하기 전의 coverage 증가, 높이 +.14, 워밍업 연장은 해결책이 아니었다. 원래 불투명 foliage 셰이더도 같은 새 GLB에서 소실되어 Alpha Hash나 좌표색 변환을 배제했다. 지형 BVH raycast 4군락 각 1,200표본에서 기존 proxy는 지형보다 최소 `.121~.134`타일 위에 있어 침수도 아니었다. PCF 필터가 전역 bias에 영향을 주는 사실은 있으나 이번 소실의 주원인은 LOD다.

`scripts/prepare_godot_project.py`는 정확히 `assets/environment/fern_shadow.glb.import`의 `meshes/generate_lods=false`만 적용한다. 기존 UID·다른 옵션·다른 GLB 설정은 보존한다. 최초 준비 때도 scene importer의 최소 sidecar를 만든다. `meshes/create_shadow_meshes`는 변경하지 않는다. 런타임에 큰 LOD bias 값을 남기지 않고 이 1,200삼각형 그림자 에셋만 원본 topology를 유지한다.

## 최종 후보 파일과 계약

- `godot/environment/fern_shadow.gdshader`: SHADOWS_ONLY 전용 재질. 실제 여섯 잎층 convex 외곽에서의 안쪽 거리로 coverage를 계산한다. 중심 `.80`, 가장자리 전이 폭 원본 공간 `.16`, Godot native alpha hash. 조명 PCF가 실제 깊이 그림자를 필터링한다.
- `godot/environment/fern_shadow_outline.gdshaderinc`: 실제 잎 끝에서 생성한 25개 경계 평면과 local XY 복원 상수. 원·타원 마스크가 아니다.
- `design/stage1_3d/environment_dressing/build_fern_shadows.py`, `fern-shadow-proxies.blend`, `fern-shadow-manifest.json`: 전체 XY·높이·topology·Wind/Occupancy UV를 원래 낮은 외피로 보존한다. `worldShadowLift=0.0`으로 복귀했다. COLOR에 군락 원본 XY만 추가하며 생성기는 GLB와 경계 include를 함께 갱신한다.
- `assets/images/stage1_3d/environment/fern_shadow.glb`: 182,544 bytes, 단일 메시/primitive, 4군락, 1,200삼각형. 정규화 16비트 COLOR_0 추가. 가시 고사리 메시·색·배치는 변경하지 않았다.
- `scripts/test_prepare_godot_project.py`: 기존 테스트 안에서 clean 최초 sidecar 생성, 재준비 시 false 재적용, 기존 UID·shadow mesh 옵션·다른 GLB import 설정 보존을 확인한다.

`main.gd`의 별도 `_fern_shadow_material`에 전용 shader를 지정하고 기존 SHADOWS_ONLY를 유지한다. 기존 foliage 재질에 점유 값을 전달하는 두 지점에서 같은 `occupied_build_tiles`를 전달한다. TIME/UV/UV2와 바람 계산식은 기존 foliage shader와 동일하므로 CPU 시간 갱신은 추가하지 않는다. 생성된 `.gdshaderinc`는 기존 copytree로 함께 복사된다.

## 확인한 근거와 남은 검수

Blender MCP로 실행 중인 Blender binary를 확인한 뒤 독립 background Blender로 제작했으며 열린 UI 장면은 바꾸지 않았다. 초기 후보의 608정점 좌표·1,200면 topology·Wind/Occupancy UV가 기존 `.blend`와 정확히 동일함을 assert로 확인했다. 높이 실험은 최종 생성기에서 0으로 복귀했다. 원본 식물 master SHA는 `4eb09cf6c7503f720c4b5bc69f29a89b3e566e9ce20ed992aa165acaa7a667d7`이다.

실제 GLB POSITION을 군락 역행렬로 복원한 local XY와 COLOR_0의 최대 오차는 `0.000007721`로 정규화 양자화 수준이었다. glTF 재질은 OPAQUE/doubleSided이고 노멀 파손은 없었다. 실제 버전 Godot 4.7.2 Mobile 엔진 소스에서도 COLOR varying은 shadow/depth 패스에 전달되고 Alpha Hash는 그림자 생성 대상으로 분류됨을 확인했다.

`python3 -m unittest discover -s scripts -p test_prepare_godot_project.py` 1회 통과. 공유 Godot 준비·최종 재import·원래 높이의 고정/드론 GPU 캡처·Android 설치·성능 확인은 주 에이전트가 진행한다. LOD 진단 때의 복원 캡처와 최종 Android 시각 검증을 구분한다.
