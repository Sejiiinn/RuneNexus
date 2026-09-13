# 챕터 2 균열 유적 3D

Android 본게임 스테이지 6~10에 사용하는 타일·외곽 소품의 편집 원본과 출력 계약이다. [승인 시안 4종](../chapter2_asset_concepts/README.md)의 회보라색 석재 길, 청회색 건설 바닥, 룬 기둥·수정 군락·공허 균열을 따른다.

스테이지 6에서 승인한 [각진 일체형 절벽·색광](stage6/README.md)을 [스테이지 7~10](stages7_10/README.md)에도 적용한다. 실제 맵과 일치하는 전용 지형·소품 배치를 사용한다. 아래 공용 소품은 제작 재료와 일치하는 전용 원본이 없는 맵의 대체 배치에 사용한다.

## 원본과 출력

| 역할 | 편집 원본 | 게임 출력 |
| --- | --- | --- |
| 길·건설 타일 | [chapter2-tiles.blend](tiles/chapter2-tiles.blend), [생성·내보내기](tiles/build_tiles.py) | [chapter2_tiles.glb](../../assets/images/stage1_3d/environment/chapter2_tiles.glb) |
| 스테이지 6~10 공유 최적화 타일 | [편집 원본·마스크 계약](optimization/README.md), [chapter2-tiles-optimized.blend](optimization/chapter2-tiles-optimized.blend) | [chapter2_tiles_optimized.glb](../../assets/images/stage1_3d/environment/chapter2_tiles_optimized.glb) |
| 기둥·수정·균열 | [chapter2_props.blend](props/chapter2_props.blend), [소품 제작 안내](props/README.md) | [chapter2_props.glb](../../assets/images/stage1_3d/environment/chapter2_props.glb) |

타일 루트는 `path_tile`, `build_tile`이며 한 칸의 폭·깊이는 1, 표면은 Godot Y=0, 기단 바닥은 -0.45다. 건설 바닥은 얕은 마름모 음각과 테두리를 두고 중심을 비웠다. 돌 조각과 균열은 실제 메시이며 표면의 색·노멀·거칠기는 Blender에서 베이크한다. 공용 석재는 기존 승인 `C1_natural_rock_faces` 텍스처를 재사용한다. 원본은 돌 조각별로 편집 가능하게 유지하고, 게임 출력은 타일별 하나의 메시와 두 재질 면으로 합친다.

스테이지 6~10의 현행 타일 표시는 [이웃 마스크별 공유 변형](optimization/README.md)을 `MultiMesh`로 배치한다. 기존 타일 원본과 출력은 보존하고, 상면·균열·음각·외곽을 유지하면서 가려진 하부 기하만 제거한다. 타일 삼각형 수는 약 56~60% 감소하며, APK·메모리·프레임 시간은 [런타임 전후 측정](../../docs/analysis/godot_optimization_20260913.md)으로 별도 판단한다.

공용 소품 루트는 `rune_pillar`, `crystal_cluster`, `void_fissure`다. 전용 스테이지 원본에는 이 상부 소품을 복사하고, 개별 받침 대신 본판과 이어진 각진 절벽을 사용한다. 공용 대체 배치의 규칙은 다음과 같다. 각 소품 아래에는 폭 최대 1.4타일의 불규칙 부유 암반을 둔다. [외곽 배치 코드](../../godot/environment/chapter_two_environment.gd)는 맵 바깥과 연결된 비플레이 칸을 기준으로 최대 4개를 분산 배치하고, 넓어진 지면이 모든 이동·건설 칸에서 0.04타일 이상 떨어지는지 실제 메시 경계로 확인하고, 가장 가까운 타일에는 약 0.04 간격으로 붙인다. 지면의 상면·측면은 타일 원본과 같은 재질과 무늬 크기를 사용하며, 둥근 받침 대신 비대칭 판상 조각으로 연결한다. 길·건설 칸, 포탈·코어의 바로 인접 영역, 맵 안쪽의 작은 빈 공간은 비운다. 같은 맵에서는 배치·회전이 동일하다.

## 저장한 수동 편집 내보내기

저장소 루트에서 실행한다. 저장된 `.blend`의 루트 아래 모델만 내보내고 원본 재생성·재베이크·재저장은 하지 않는다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/chapter2_3d/tiles/build_tiles.py -- --export-only
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/chapter2_3d/props/build_props.py -- --export-only
```

`-- --regenerate`를 명시하면 생성 코드 기준으로 원본·맵·GLB·검수 렌더를 다시 만든다. 수동 편집은 덮어쓰므로 보존할 수정이 있으면 먼저 별도로 저장한다. 기존 원본이 있을 때 옵션 없는 재생성은 차단한다. Blender의 열린 작업을 보호하도록 별도 백그라운드 프로세스를 사용한다.

[Blender 작업 허브](../stage1_3d/blender_workspace/README.md) Scene 29에서 타일, 30~32에서 소품을 각각 확인할 수 있다. 원본에 연결된 읽기 전용 장면이며 편집은 위 원본 파일에서 수행한다.

## 게임 연결

[프레임 인코더](../../lib/game/rendering/stage1_3d/godot_battlefield_frame.dart)의 `map.theme`가 `chapterTwoRift`이면 [Godot 전장](../../godot/main.gd)이 챕터 2 타일과 소품을 지연 로딩한다. 기존 맵의 이동 경로·건설 판정·세이브 형식·전투 계산은 그대로 사용한다. 챕터 2의 `shieldBoss`는 공용 보스 모델을 사용하고 보호막과 전투 상태는 기존 게임 로직을 따른다.

Android 스테이지 1~5는 기존 챕터 1 모델을, 6~10은 이 모델을 사용한다. 11 이후와 Android 이외의 기존 2D 표시 경로는 유지한다. [공용 Android 실행 절차](../../docs/stage1_3d_preview.md)에 따라 정상 `lib/main.dart` 앱에서 확인한다. 게임용 GLB는 Godot PCK로 포함하며 편집 원본과 Blender 검수 렌더는 배포하지 않는다.

## 최초 타일 구현 검증

- 자동 검사: Flutter analyze와 관련 프레젠테이션 테스트 39개 통과. 최종 GLB를 가져온 Godot 검사에서 [기존 챕터 1](verification/final-chapter-one-stages.log)과 [챕터 2](verification/final-chapter-two-stages.log) 모두 0 failures. 실제 맵·길/건설 역할·외곽 소품 경계·원본 메시/재질 공유·테마 교체·기존 챕터 복귀를 검사했다. 석재·수정의 `COLOR_0`가 전부 흰색으로 내보내지는 오류도 회귀 검사에 포함했다.
- 실제 화면: 정상 `lib/main.dart`의 Android 에뮬레이터에서 [6](verification/android-stage6-angled.png)·[7](verification/android-stage7-angled.png)·[8](verification/android-stage8-angled.png)·[9](verification/android-stage9-angled.png)·[10](verification/android-stage10-angled.png)의 경로/건설 구분, 외곽 소품과 HUD 배치를 확인했다. [6 확대](verification/android-stage6-zoom.png)는 게임 줌 2.1배에서 타일의 틈·기단·음각과 수정의 보라색 몸체·밝은 끝·내부층을 확인한 캡처다. [타일 원본 검수 렌더](tiles/tiles-source.png)와 소품 스튜디오 이미지는 Blender 렌더로 구분한다.
- 동작: 실제 타일 터치로 대포 미리보기·설치를 확인했으며, 스테이지 10의 [40웨이브 드론 화면](verification/android-stage10-boss-drone.png)에서 보호막 적·보스의 경로 이동을 확인했다. 해당 캡처는 이동 중 상태를 디버거로 일시정지한 것이다. [스테이지 11의 기존 2D](verification/android-stage11-return.png)와 [스테이지 1의 기존 3D 복귀](verification/android-stage1-return.png)도 확인했다. 검증은 메모리 저장소를 사용하여 사용자의 영구 저장을 수정하지 않았다. 실기기 프레임 성능 벤치마크는 수행하지 않았다.
- 패키지: 동일 환경의 직전 로컬 디버그 APK 497,536,194 → 508,843,030바이트(+11,306,836바이트, 약 10.8MiB). Godot PCK 74,886,924 → 86,193,760바이트. 타일·소품과 내장 텍스처가 증가 원인이다. [ZIP 측정](verification/apk.json)에서 Flutter 원본 GLB 중복·Blender 원본·생성 Python 미포함을 확인했다. 공개 배포는 수행하지 않았으며 공개 release APK 간 비교가 아니다.
- 실행 로그의 한계: [Godot 로그](verification/android-godot.log)에 스크립트·셰이더 파싱 실패는 없지만, 에뮬레이터 초기화에서 Vulkan sampler binding 18개가 기기 한도 16개를 넘는다는 validation 진단이 발생했다. 이후 검수 화면에서 재질 누락·렌더 중단은 관찰하지 않았으며, 이 기록을 실기기 GPU 호환성 통과로 해석하지 않는다. 검증 종료 후 정상 앱으로 복원했다.

## 첫 부유 암반 적용 — 후속 수정 전

사용자가 소품만 공중에 떠 보이는 문제를 지적한 뒤, 정사각형 장식 타일보다 불규칙한 부유 지형을 채택했다. 기존 소품의 형태·색·재질은 보존하면서 넓은 지면과 아래로 이어지는 깨진 암반을 추가한다. [연결/독립 지면 검토 시안](../chapter2_asset_concepts/connected-ledge/README.md)은 논의 기록이며, 큰 하나의 땅이나 정사각형 장식 타일을 추가하는 변경은 아니다. 아래 기록은 첫 부유 암반 적용의 기능 검증이다. 이후 사용자가 둥근 받침 형태와 타일에 어울리지 않는 재질을 지적하여 현행 외형 기준에서 제외했다.


- 원본: [부유 암반 수정 스크립트](props/add_floating_ground.py)가 기존 상부 소품을 보존하며 지면을 추가한다. [보존 검사](props/floating-ground-check.json)와 [Blender 검수 렌더](props/rune_pillar-studio.png)에서 넓은 상면·파단 지층·하부 두께를 확인했다. 균열 바닥의 사각 깊이판은 골짜기 안쪽으로 줄여 하부 노출을 없앴다. 작업 허브 Scene 30~32도 갱신했다.
- 실제 화면: 정상 Android 앱의 [6 고정 시점](verification/floating-ground/android-stage6-angled.png), [6 드론 시점](verification/floating-ground/android-stage6-drone.png), [9 고정 시점](verification/floating-ground/android-stage9-angled.png)에서 소품을 받치는 지면, 주변 타일과의 분리, 화면 경계와 HUD 간격을 확인했다. [9 건설 입력](verification/floating-ground/android-stage9-build.png)은 기둥 옆 건설 칸을 실제로 터치해 대포 설치를 완료한 화면이다.
- 자동 검사: 최종 GLB를 사용한 [챕터 1](verification/floating-ground/chapter-one-stages.log)·[챕터 2](verification/floating-ground/chapter-two-stages.log) Godot 검사 모두 실패 0건. 스테이지 6~10은 각각 기둥 1·수정 2·균열 1개이며, 실제 전체 메시 경계와 플레이 타일의 간격·외곽 범위·두께·재질 공유·정점색·기존 챕터 복귀를 확인했다. Dart 코드는 이번 보강에서 변경하지 않았다.
- 패키지: [실제 APK ZIP 측정](verification/floating-ground/package.json)에서 직전 로컬 디버그 APK 508,843,030 → 509,653,734바이트(+810,704바이트, 약 0.77MiB), PCK 86,193,760 → 87,004,464바이트다. 추가 암반 메시가 증가 원인이며 GLB 중복·Blender 원본·생성 Python은 포함되지 않았다. 공개 배포는 수행하지 않았다.
- 검증 범위: 메모리 저장소로 확인해 사용자 영구 저장을 수정하지 않았다. 에뮬레이터 Vulkan validation에는 sampler 한도와 swapchain semaphore 재사용 진단이 기록됐으며, 이를 실기기 GPU 호환성·성능 통과로 해석하지 않는다. 이번 캡처에서는 재질 누락·렌더 중단을 관찰하지 않았다.


## 타일과 지형의 연결 보정

타일과 어울리지 않는 둥근 받침 형태·어두운 별도 암반 재질을 교체했다. 지면은 비대칭으로 깨진 판상 외곽과 넓은 파단판으로 구성하고, 타일 원본의 `chapter2_build`·`chapter2_side` 재질과 월드 단위 UV를 사용한다. 상부 소품 228개 메시의 형태·재질은 보존했다. [동일 조명 비교](props/tile-ground-comparison.png)는 Blender 검수 렌더다.

배치는 회전한 원본의 실제 AABB를 기준으로 가장 가까운 플레이 타일과 약 0.04타일 간격만 남긴다. 일괄 0.28타일 이동으로 생겼던 넓은 공백을 줄이면서, 전체 플레이 영역에 대한 침범 검사는 유지한다.

- 실제 Android: [스테이지 9 고정 시점](verification/ground-integration/android-stage9-angled.png), [스테이지 6 드론 시점](verification/ground-integration/android-stage6-drone.png)에서 지면의 색·무늬 크기·측면과 타일 가장자리 간격을 직접 확인했다. [기둥 옆 대포 설치](verification/ground-integration/android-stage9-build.png)는 실제 터치로 완료했다. 검수는 정상 앱 진입과 메모리 저장소를 사용했다.
- 자동 검사: [챕터 1](verification/ground-integration/chapter-one-stages.log)·[챕터 2](verification/ground-integration/chapter-two-stages.log) 모두 0 failures. 6~10 모두 소품 4개, 최근접 플레이 타일 간격 0.0399~0.05, 전체 경계 비침범, 기존 정점색·재질 공유·챕터 복귀를 확인했다. 이번 보정은 Dart 코드·저장 형식·전투 로직을 바꾸지 않는다.
