# 스테이지 1 환경 장식

역할: 2026-09-12 승인 시안의 독립 마스터 11종을 실제 스테이지 1 맵에 연결한 원본·출력·검수 진입점. [승인 시안](../environment_concepts/01-overgrown-stone-edges.png)의 돌 뒤 고사리, 중층 잎과 풀, 낮은 이끼, 드문 흰꽃과 벽 아래 덩굴을 기존 타일 배열에 맞춰 배치한다. 지형·포탑·이동 경로는 변경하지 않는다.

## 현행 배치

`master-assembly-20260912`는 `(3,0)`, `(5,1)`, `(7,4)`, `(7,7)`, `(0,7)`, `(0,9)` 여섯 권역의 크기·주종·높이를 달리하고, 권역 사이에는 선택한 연결점과 빈 면을 남긴다. 큰 돌은 윗면이 보이게 낮게 앉히고, 돌 옆의 고사리·넓은 잎·풀과 낮은 이끼가 겹친다. 흰꽃은 세 군락, 덩굴은 실제 외곽 벽 네 곳, 짧은 뿌리는 선택한 세 타일 틈에만 둔다. 모든 타일을 같은 식물이나 한 종류씩 전시하는 배치로 채우지 않는다.

맵용 개별 메시 58개는 식생 45개와 정적 돌·뿌리 13개다. 식생 중 27개는 포탑 설치 시 숨고 철거하면 다시 나타나며, 영구 식생 18개는 가장자리에 남는다. 이 수는 독립 원본을 배치한 인스턴스 수다.

| 독립 원본 | 배치 수 |
| --- | ---: |
| 휘어진 풀 포기 | 13 |
| 다층 고사리 | 4 |
| 넓은 잎 식물 | 8 |
| 낮은 지피 | 6 |
| 작은 흰꽃 | 3 |
| 낮게 퍼진 이끼 | 7 |
| 늘어진 덩굴 | 4 |
| 드러난 뿌리 | 3 |
| 이끼 바위 | 4 |
| 납작한 돌 | 3 |
| 작은 돌멩이 군집 | 3 |

## 원본과 게임 파일

- 편집 원본: [environment-dressing.blend](environment-dressing.blend), Scene `Stage1EnvironmentDressing`, 컬렉션 `10 Dressing - editable master instances`. 각 메시의 `sourceAssetId`, 원본 파일·장면·해시와 LOD 정보로 독립 마스터를 추적한다.
- 식물 원본 4종: [plant_library/README.md](plant_library/README.md), [forest-plant-masters.blend](plant_library/forest-plant-masters.blend).
- 추가 원본 7종: [companion_library/README.md](companion_library/README.md), [organic-masters.blend](companion_library/organic/organic-masters.blend), [rock-masters.blend](companion_library/rocks/rock-masters.blend).
- 기존 지형: `00 Terrain` 컬렉션의 `environment/terrain-approved.blend` 연결 참조. 장식 출력에는 포함하지 않는다. 타일 종류·행/열·원점은 등록된 `assets/images/stage1_3d/environment/terrain.glb`의 `stage1_environment` metadata를 읽는다.
- 게임 에셋: `assets/images/stage1_3d/environment/dressing.glb`. 원점은 지형과 같고, `stage1_dressing` 아래 `stage1_dressing_foliage`와 `stage1_dressing_rocks` 두 메시만 출력한다.
- [placement_manifest.json](placement_manifest.json)은 인스턴스별 원본·변환·점유 슬롯·삼각형 계수를, [master-assembly-manifest.json](master-assembly-manifest.json)은 원본 해시·메시별 LOD 방법과 계수를, [export_manifest.json](export_manifest.json)은 실제 출력 계수를 기록한다.

독립 원본 3개는 조립 과정에서 저장하거나 재생성하지 않는다. 원본 장면을 평가한 뒤 개별 메시의 저장된 위치·회전을 포함해 읽는다. 따라서 수동으로 배치한 돌멩이 6개의 간격·방향도 유지한다. 맵 복사본에서는 잎의 외곽·능선 샘플과 닫힌 면의 단순화로 삼각형을 줄인다. 고사리의 13쌍 잔잎과 승인된 1.5배 폭을 유지하며, 고사리·넓은잎·지피·꽃·덩굴의 주줄기는 잎자루 접합이 어긋나지 않도록 원본 길이 방향 링을 모두 보존한다. 가려지는 이끼의 작은 잎과 별도 미세 중륵은 줄인다. 비틀림 때문에 단순화가 원본 앞면을 바꾸는 잎은 그 부분의 원본 세분을 유지한다.

## 편집·조립·출력

맵용 메시를 직접 수정할 때는 `environment-dressing.blend`를 저장하고 아래 출력·검사를 실행한다. 내보내기는 저장한 Basis 좌표를 읽으며 Shape Key·드라이버·카메라·광원·연결 지형을 제외한다. 미적용 modifier는 출력하지 않으므로 필요한 modifier는 원본에서 적용한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background design/stage1_3d/environment_dressing/environment-dressing.blend --python-exit-code 1 --python design/stage1_3d/environment_dressing/export_dressing.py
/Applications/Blender.app/Contents/MacOS/Blender --background design/stage1_3d/environment_dressing/environment-dressing.blend --python-exit-code 1 --python design/stage1_3d/environment_dressing/verify_source.py
```

독립 마스터를 수정했거나 배치 목록을 바꾼 경우에는 [assemble_master_dressing.py](assemble_master_dressing.py)로 저장된 마스터를 다시 읽는다. 재조립은 맵 복사본을 새로 만들므로 기존 맵용 직접 편집은 먼저 백업된다. 기본 실행은 이미 조립된 원본의 덮어쓰기를 차단하고, 의도적인 재조립에는 `--rebuild`를 쓴다. 이후 위 출력·검사를 수행한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/environment_dressing/assemble_master_dressing.py -- --rebuild
```

`build_dressing.py`는 이전 기본 식생 생성 기록이며 현행 제작 경로가 아니다. 현재 원본이 있으면 실행을 차단한다. 이전 원본·GLB·생성기·manifest는 로컬 `before-master-assembly-20260912/`에 보존한다. 그보다 이전 단계는 `previous-20260912/`, `before-lush-20260912/`와 해당 `.blend` 백업에 남아 있다.

## 렌더링 계약

지형·바위·포탑·적과 같은 Godot 주광 그림자를 실제 식생 메시에서 생성한다. 얇은 잎은 양면으로 그림자를 만들며, `dressing.glb` 안의 `stage1_dressing_foliage` 메시만 Godot의 추가 자동 LOD 생성을 끈다. Blender에서 이미 단순화한 게임용 잎의 투영 면적·겹침을 보존하기 위한 기준이다. 같은 GLB의 바위와 다른 지형·포탑·적의 LOD는 유지한다. 바람·건설 점유가 가시 메시와 그림자에 함께 적용되므로 별도 그림자용 점유 재질이 필요하지 않다.

과거 고사리 전용 외피·전용 셰이더는 공통 그림자 적용으로 폐기했다. [fern-shadow-proxies.blend](fern-shadow-proxies.blend)와 [build_fern_shadows.py](build_fern_shadows.py)는 제작 이력으로 보존하고 게임 패키지에서는 제외한다. 원본 고사리를 수정할 때 이 과거 외피를 재생성하지 않는다. [공통 그림자 적용 기록](../surface_effects/verification/common-shadow-implementation-20260913/README.md)을 따른다.

`Color`는 선형 RGB·알파 1의 불투명 정점색이다. `Wind`는 첫 번째 UV이며 x는 0~1 굽힘 가중치, y는 `1−군락 위상`이다. glTF V축 변환 뒤 위상값이 Godot에 전달된다. 같은 식물의 연결 부위에는 동일한 공간 기준으로 가중치를 주며, 지면 뿌리와 덩굴 위 걸침점은 고정한다. 덩굴은 음수 Z로 내려가는 경로를 기준으로 가중치를 계산한다. 낮은 이끼는 흔들리지 않는다.

두 번째 UV `Occupancy.x`는 건설 타일 row-major 순번 0~31, `Occupancy.y`는 영구 1·제거 가능 0이다. glTF V축 변환 뒤 Godot UV2.y는 제거 플래그가 된다. 중앙 식생에는 `removableOnBuild`도 기록한다. 영구 장식은 소속·이웃 건설칸의 중앙 0.7×0.7을 비우며 바람 변위까지 고려한다. 제거 가능한 식생의 고정점은 소속 타일 안에 둔다. 슬롯 0·16의 실제 제거 대상도 유지한다.

`SourceFront`와 `SourceSurfaceRole`은 제작 원본의 표면 방향 검사용 FACE 속성이다. 잎·꽃잎은 원본 앞면과 비교하고, 줄기·돌은 닫힘과 인접 면 winding을 검사한다. 정상적인 곡면 잎·꽃받침·덩굴 뒷면이 아래를 향할 수 있으므로 모든 foliage 면을 위쪽으로 뒤집지 않는다.

바람은 기존 `godot/environment/foliage_wind.gdshader`의 공유 두 사인파를 그대로 사용한다. 최대 0.022타일이며 전투 배속·정지와 독립적이다. 중앙 식생은 기존 두 16비트 점유 마스크로 숨기고, 추가 드로콜·투명 블렌딩·개체별 CPU 갱신을 만들지 않는다.

## 성능·검증

현재 출력은 두 메시·두 재질, **23,964삼각형**(식생 20,496·정적 3,468), **1,552,836바이트**다. 이 수치는 현재 에셋의 측정값이며 고정 상한이 아니다. 목표 형태·질감·입체감을 먼저 보존하고, 성능은 Android 실기기의 4배속 전투에서 프레임 시간과 실제 병목을 비교해 판단한다. 삼각형 수만으로 제작·내보내기를 실패시키거나 시각 품질을 제한하지 않는다. 현재 출력에는 텍스처·스킨·애니메이션 클립·물리·추가 광원이 없다. 식생은 기존 조명을 받으며, 2026-09-13 표면·조명 개선에서 잎 밑의 접촉을 살리도록 양면 그림자를 켰다. [현행 조명·검수 기록](../surface_effects/README.md)을 따른다. 새 장식 GLB는 공용 Godot PCK에만 포함하며 Flutter 자산과 중복 패키징하지 않는다. `design/` 원본과 제작 렌더는 게임 패키지에 포함하지 않는다.

[원본 검사](source-verification.json)는 실패 0건이다. 11종 원본 해시 보존, 원본 단면 앞면 방향, 닫힌 표면, 유효 정점·색상, 소속·인접 건설칸 중앙과 이동 경로 여유, 점유 UV를 확인한다. 덩굴 네 곳은 음수 Z 전체의 벽 안쪽 침범·걸침점·하강 범위를 따로 검사한다. 7개 바람 시점에서 최대 이동 0.021871타일, 고정점 이동 0을 확인했다.

Godot의 실제 메시·UV·자원 공유·점유/철거·재진입 검사와 Android 실제 화면·패키징 결과는 [현행 검수 기록](verification/master-assets-20260912/README.md)에 모은다. 제작용 Blender 카메라는 `(5,-13,27)`로 Godot 고정 시점 `(5,27,13)`에 대응한다. 독립 원본 정지 이미지와 이전 `blender-preview-0001.png`·식생 목록은 해당 단계의 제작 기록이며 현행 게임 캡처와 구분한다. APK 검수는 [공용 Godot 검수 앱](../godot_preview/README.md)을 사용한다.
