# 공통 식생 그림자 구현

2026-09-13. 사용자 검토 후 진행 승인에 따른 식생 담당 변경이다. 실제 전체 통합 GPU·Android 검수는 주 에이전트가 진행한다.

## 결과와 책임 경계

고사리 4군락만의 그림자 외피를 런타임에서 제거하고, 풀·넓은 잎·고사리 등 가시 식생 본체의 원래 형상이 공통 주광에 그림자를 만들도록 한다. 생산 `dressing.glb`의 기하·UV·색은 변경하지 않았다. SHA256: `9544247164e52790b1571b2140d16b1d0ed5c971bff71bfcd0935aecdb0ec658`.

`scripts/prepare_godot_project.py`는 `dressing.glb.import`의 `_subresources.meshes["Dressing Export (temporary)_stage1_dressing_foliage"]["generate/lods"] = 2`만 적용한다. Godot 4.7.2 `ResourceImporterScene`의 mesh별 override enum에서 2는 Disable이다. GLB의 실제 mesh 이름이 `stage1_dressing_foliage`임을 읽어 확인했다. 전역 `meshes/generate_lods`와 같은 GLB의 `stage1_dressing_rocks` 설정, shadow mesh 생성, 지형·포탑·적 LOD는 유지한다. 큰 런타임 `lod_bias` 값은 추가하지 않았다.

전체 dressing LOD를 끄는 방식은 구현은 더 짧지만 바위까지 함께 바뀐다. 실제 잎의 차폐를 보존하는 책임을 식생 mesh에 한정할 수 있어 mesh별 import 계약을 선택했다. 기존 UID·다른 import 옵션·기존 subresource 값은 보존하며, 읽을 수 없는 비 JSON Variant 확장 값이 sidecar에 추가되면 이를 덮어쓰지 않고 준비가 실패하도록 했다. 현재 Godot가 작성한 기본 dictionary와 이 프로젝트의 mesh/material 설정은 JSON 호환이다.

근거가 된 주 에이전트의 사전 검수에서는 보조 외피 OFF, near/far 10/50 조건에서 가시 식생의 원본 LOD만 유지했을 때 풀·넓은 잎·고사리 실제 그림자가 복원됐다. 해당 GPU 카운터는 primitive 142,543→173,271, draw call 81 유지였다. 이는 해당 장면 비교값이며 실기기 성능 수용 판정은 아니다.

## 제거·보존

- `godot/main.gd`: FernShadow preload 두 개, 별도 재질 변수, 외피 연결, 점유 전달 두 곳만 제거했다. 가시 식생의 공유 바람 shader·DOUBLE_SIDED·점유 계산은 유지했다. 카메라 구현은 다른 담당 영역으로 변경하지 않았다.
- `godot/verify_environment.gd`: 외피 필수 검사와 외피 재질 동기화 검사를 제거했다. 외피 노드 부재와 정상 `lod_bias=1`, 실제 imported foliage의 LOD 배열 비어 있음/바위 LOD 유지까지 확인하며 기존 가시 식생 shader/cast/bounds/뿌리/바람/점유/철거/재진입 검사를 유지한다. 고사리 슬롯도 같은 본체 점유 검사로 남긴다.
- 런타임 `fern_shadow.glb`, `fern_shadow.gdshader`, `fern_shadow_outline.gdshaderinc`는 삭제 전 `design/stage1_3d/environment_dressing/retired-fern-shadow-20260913/`에 보관했다. 기존 `.blend`, 생성기, manifest 등 편집·역사 원본은 보존했다.
- prepare는 외피를 required 목록에서 제외하고, 과거 생성기로 asset이 다시 생겨도 정확히 `environment/fern_shadow.glb`만 복사에서 제외한다. 기존 빌드의 해당 GLB/sidecar와 `.godot/imported/fern_shadow.glb-*` 캐시만 삭제한다. 삭제된 shader include도 stale 정리 대상에 포함하고 해당 shader UID 두 개를 정리한다. 다른 imported cache는 유지한다.

## 검증

기존 `scripts/test_prepare_godot_project.py` 안에서 clean 최초 mesh별 설정 생성, 기존 UID/전역 LOD/shadow 옵션/바위와 재질 subresource/다른 terrain import 설정 보존, 반복 준비의 멱등성, 폐기 source/import/cache/shader/include/UID 제거 및 다른 캐시 보존을 검증했다. 과거 외피가 source fixture에 남아 있어도 재복사되지 않음을 확인한다.

`python3 -m unittest discover -s scripts -p test_prepare_godot_project.py` 1회 통과. 변경 파일 diff 공백 검사 통과. 이 담당은 공유 prepare/Godot 실행/GPU/Android/APK/커밋을 수행하지 않았다. 최종 import에서 mesh별 설정이 실제 적용되는지, 원본 식생의 공통 그림자가 두 시점에서 자연스럽고 고사리 외피 흔적이 사라졌는지는 주 에이전트가 판정한다.

실제 LOD 검사는 Godot 4.7.2에서 C++ `surface_get_lods`가 GDScript에 직접 바인딩되지 않아 `ArrayMesh.get("_surfaces")`의 같은 실제 LOD 데이터를 읽는다. 공식 `mesh.cpp`의 `_get_surfaces` 및 속성 바인딩을 확인했다. 실행 결과는 주 에이전트의 공통 검수에 따른다.

첫 통합 실제 LOD 검사에서 GLB 원명만 사용한 override가 무시됨을 잡았다. Godot 4.7.2 `GLTFDocument::_parse_meshes`는 `scene_name + "_" + mesh_name`을 ImporterMesh 이름으로 생성한다. 따라서 실제 import ID는 `Dressing Export (temporary)_stage1_dressing_foliage`이며 이 키로 교정했다. 잘못 만든 원명 키의 정확한 단일 LOD 옵션만 정리한다. Python 기존 테스트를 이 결함 회귀까지 보강하여 교정 후 1회 다시 통과했다. 실제 import 효력은 동일 환경 검사를 다시 실행해 확인한다.
