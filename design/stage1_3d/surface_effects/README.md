# 스테이지 1 표면·조명·효과 적용 기록

2026-09-13. [설계](../../../docs/stage1_surface_effects.md)와 사용자가 전달한 [최소 외형 기준](target-reference.jpg)을 따른다. 첫 거칠기·cavity 보정만으로는 시안의 깊이감이 부족하다는 피드백을 반영해 조명·그림자·측면 UV를 함께 수정했다. 시안과 식생 조형·밀도가 동일하다는 판정은 하지 않는다.

## 실제 적용

- **빛·그림자:** 주광 `(-48,-125,0) / 1.50`, 환경광 `.16`, 보조광 `.14`. 밝은 윗면의 확산광 총량을 유지하면서 카메라에 보이는 수직면을 분리한다. 2048 직교 그림자, bias `.03` / normal bias `.35`, 식생 양면 그림자로 기단·잎 밑의 접촉을 표현한다. PCF Soft Medium을 Android에도 명시하고 blur `1.25`로 경계를 완화한다.
- **지형 재질:** 전체맵의 누락된 cavity와 돌·이끼의 거칠기를 ORM에 연결했다. 실제 정적 지형의 0.35타일 이내 차폐를 Blender에서 함께 구웠다. Godot 내장 PBR의 AO 직접광 반영 `.8`, 건설석판/길 normal scale `1.2/1.0`를 사용한다. 전체 색을 검게 칠하거나 bloom으로 표면을 덮지 않는다.
- **측면 UV:** 이전 전체맵 평면 투영은 건설석판·길의 수직면 UV 면적 약 86%를 선으로 눌렀다. 상면 atlas를 유지하고 측면은 면 방향에 맞는 UV와 기존 석재 PBR을 연결했다. 수정 측면의 UV 퇴화 면적은 0%다.
- **기관총·대포:** 연기·폭발이 실제 카메라와 장면 깊이를 읽어 적·지형 뒤쪽을 가린다. HUD 카메라 오프셋도 반영한다. 기존 효과 형태·입자 수·풀·1.1초 수명을 보존했다.
- **모바일 오류 수정:** 전 지형에 적용했던 anisotropic 필터는 Android에서 Vulkan 파이프라인 오류와 면 누락을 일으켰다. mipmap 필터로 복원한 뒤 오류·면 누락이 사라졌다. MSAA 2x와 깊이 효과는 유지한다. 시험했던 glow는 채택하지 않았다.
- **성능 기준:** 실측 근거 없이 둔 장식 24,000삼각형 상한과 제작·검증 실패 조건을 제거했다. 삼각형 집계와 구조 검증은 유지하며, 목표 외형을 확보하고 실제 병목에 따라 최적화한다. 이번에는 장식 형상을 추가하거나 줄이지 않았다.

## 원본과 재생성

현행 편집 원본은 [terrain-surface.blend](terrain-surface.blend), 게임 출력은 `assets/images/stage1_3d/environment/terrain.glb`다. 원래 `../environment/terrain-approved.blend`와 `../actor_refinement/stage1-actors-refined.blend`는 보존했다. 변경 전 GLB는 로컬 `build/godot/terrain-before-surface.glb`에 있다. Blender 작업 허브의 `01 Terrain`도 현행 원본을 가리킨다.

Blender MCP에서 열린 편집 세션을 보존하는 별도 background Blender 프로세스로 아래 순서대로 실행한다. 두 번째·세 번째 스크립트는 앞 단계가 저장한 `terrain-surface.blend`를 읽는다.

1. [refine_surface_maps.py](refine_surface_maps.py): 원본 위치별 cavity·거칠기 베이크.
2. [bake_contact_ao.py](bake_contact_ao.py): 실제 지형의 근거리 차폐 베이크.
3. [repair_surface_uv.py](repair_surface_uv.py): 상면 보존·측면 UV 복구와 GLB 출력.

`maps/`의 PNG와 `terrain-candidate.glb`는 제작 산출물이다. 현재 출력은 **30,688,776바이트, 24메시·29프리미티브·15재질, 74,564삼각형**이다. 삼각형의 실제 좌표와 노드 변환·맵 계약은 변경 전과 동일하다. 상면 UV와 basecolor·normal 이미지도 유지했다. 내장 PNG는 **18장: 2048² 6장 + 1024² 9장 + 512² 3장**이다.

## 현행 후속 적용

돌의 roughness 범위 `.40–.70`, 이끼 `.90`을 원본 마스크로 혼합한다. 이후 사용자 요청에 따라 고사리 전용 외피를 제거하고 실제 식생 메시의 공통 주광 그림자를 사용한다. 카메라는 지형·회전하는 모델·탄체·폭발을 포함하는 깊이 경계를 계산하며 전투 중 넓어진 경계는 맵을 재생성할 때까지 보존한다. 구도·HUD 오프셋·시점 전환은 유지한다. `stage1_dressing_foliage`의 추가 자동 LOD만 끄고 바위·포탑·적 등은 기존 LOD를 유지한다. [현행 공통 그림자 화면·APK·검사](verification/common-shadow-implementation-20260913/README.md)를 따른다.

앞 단계의 [재질·고사리 외피 적용 기록](verification/reference-material-20260913/README.md)은 당시 결과이며, 전용 외피는 현행 구현에서 폐기했다.

## 이전 표면 단계 검수

- 실제 Android 본게임: 고정 시점 (`verification/android-lighting-fixed.png`, 로컬 자료), 드론 시점 (`verification/android-lighting-drone.png`, 로컬 자료), 4배속 전투 영상 (`verification/android-combat.mp4`, 로컬 자료). 기존 두 기관총·한 대포로 한 웨이브를 실행한 뒤 고정 시점·1배속·웨이브 대기 상태로 두었다. 검수 과정에서 저장된 게임이 6→7웨이브로 진행됐다.
- Android 17 ARM64 에뮬레이터, Godot 4.7.2 Mobile/Vulkan. 최종 장면·시점 전환·사격 실행에서 Godot 오류 없음. 기존 `xr/shaders/enabled` 설정 경고는 남아 있다. **모바일 실기기 성능은 미검증**이다.
- 기존 Godot 기관총 카메라·풀·수명 검사와 공용 런타임 검사 실패 0건. 최종 환경 장식의 바람·점유/철거·재진입 검사도 실패 0건이다. 최종 지형은 메시 좌표·상면 이미지 보존과 측면 UV를 별도 확인했다. GPU 캡처 기록 (`verification/lighting-depth.log`, 로컬 자료)은 데스크톱 Metal이며 Android 성능 수치로 사용하지 않는다.
- 중간 `after-*.png`, `android-no-*.png`, `android-mipmap.png`는 최종 결과가 아니다. 위 `android-lighting-*`가 현재 조명·재질을 반영한다.

## 이전 표면 단계 설치 파일과 용량

로컬 설치용 APK: `build/apk-main/rune-nexus-stage1-surface-effects-arm64.apk`, versionCode **6009**, 일반 `lib/main.dart` 진입. 공개 배포·커밋·푸시는 하지 않았다.

직전 로컬 native-reflection APK **234,773,173바이트 → 241,924,329바이트**, **+7,151,156바이트(+3.046%)**. 네이티브 라이브러리의 압축 크기는 그대로 **99,172,048바이트**다. Flutter 자산 압축 크기는 **75,208,176→77,837,404바이트**, Godot PCK는 **58,453,900→62,975,828바이트**다. 새 ORM 내용과 수정 지형의 가져오기 자원이 증가 원인이다. 공용 PCK의 SHA-256이 APK 내부와 일치하며 ABI는 arm64-v8a 하나, Blender 원본·design 파일은 0개다. 기존 다른 렌더 경로가 쓰는 Flutter 원본 지형과 Godot 가져오기 자원의 중복은 유지한다. APK 검사값 (`verification/apk.json`, 로컬 자료).
