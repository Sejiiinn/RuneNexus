# 첫 내장 재질 실험 — 원본 전달 조사

2026-09-13. 최종 게임 GLB를 Python 표준 라이브러리로 직접 읽었다. 원본 `.blend`·GLB·런타임 코드는 수정하지 않았다. 전체 material, texture/image 참조, PNG 해시·해상도, primitive별 UV·정점색·노멀 범위는 source-audit.json (`source-audit.json`, 로컬 자료)에 있다. 이 문서는 데이터 조사이며 시각 채택 판정은 별도 비교 결과를 따른다.

## 파일 동일성

| GLB | 실제 바이트 | SHA-256 |
| --- | ---: | --- |
| landmarks | 1,408,664 | `4570aaed44510b91815f3728d1719bc3abb174d3608f11279b9c1ab302746318` |
| terrain | 27,957,564 | `125ab9df37b806eb7a8ba2005ac60ce3b3ae0900ec9d02ab3dd600054b31567d` |
| cannon | 1,075,412 | `c4e2c2093a653b3aa3b7b1a90945211b0c95d6bec75defc5b63c0a2b12ab1b9e` |

조사 시점의 `build/godot/project/assets/` 입력 세 파일은 각각 원본과 바이트가 같았다. 이 비교만으로 최종 APK/PCK 반영까지 확인한 것은 아니다.

## 코어와 대표 소재

- `core_crystal`은 `core_crystal_facets` primitive 하나, 정점 512개·삼각형 252개다. 로컬 크기 `(0.27104, 0.84, 0.27104)`, 피벗 Y `0.72`, 스케일 `(1,1,1)`이다. 결정 안에 별도 재질·내부 물체를 추가할 데이터는 없다.
- 코어는 `POSITION`, 단위 길이 `NORMAL`, FLOAT `COLOR_0`만 있다. UV·노멀맵·TANGENT가 없는 것은 텍스처 누락이 아니라 현재 면 노멀·정점색 제작 방식이다. `COLOR_0`는 10색이며 RGB 범위는 `(0, .325, .377)`~`(.0375, .625, .725)`다. Base Color factor 기본값은 흰색이다. 내장 재질에서도 정점색을 Albedo에 곱해야 승인 면색이 보존된다.
- 코어 Metallic `0`, Roughness `.055`, Alpha `1`(glTF 기본 OPAQUE), Emission factor `(.00144, .0324, .0372)`가 들어 있다. `KHR_materials_transmission=.80`·`KHR_materials_ior=1.46`과 동일한 노드 extras도 보존된다. 이 값들은 Godot `refraction_scale`·`1 - alpha`로 변환할 수 있는 동등 속성이 아니다.
- `landmark_stone`: 정점색 + UV + 512² 내장 normal, normal scale `.65`, Metallic `0`·Roughness `.87`. 별도 Base Color/roughness/AO 텍스처는 원본에 없다. `landmark_brass`는 정점색, Metallic `.65`·Roughness `.47`; `landmark_iron`은 `.52`·`.56`이다. 금속에 새 roughness texture가 있어야 정상이라는 전제를 두지 않는다.
- `terrain.glb`: 정점색이 없고 PBR 텍스처·Base Color factor를 사용한다. 현행 `stage1_authored_build`·`stage1_authored_path`는 각 2048² Base Color/normal/roughness 이미지와 UV0가 연결된다. 자연석 3종은 각 1024² Base Color/normal/ORM 공유 이미지, 기존 weathered stone은 512² 채널이다. glTF의 roughness는 G, metallic은 B, occlusion은 R 채널 의미를 유지해야 한다. 현행 authored atlas에는 별도 AO 참조가 없다.
- `cannon.glb`: 3재질이 512² normal/색 atlas 이미지 2개를 공유한다. glTF texture entry는 6개지만 실제 이미지가 6개인 것은 아니다. 주물 철은 Metallic `.52`·Roughness `.79`, 주황 도장은 `.025`·`.89`, 포구 안쪽은 `.05`·`.95`; 모두 normal scale `.60`과 UV0를 갖는다. 주황 도장 Base Color factor `(.82,.96,1,1)`도 곱셈으로 보존해야 한다.

모든 조사 primitive의 normal 길이는 반올림 5자리에서 1이었다. normal map을 참조하는 primitive에는 모두 UV0가 있다. 세 GLB 모두 TANGENT가 없으므로 **Godot importer가 생성한 tangent 배열과 실제 노멀 반응을 추가 검증해야 한다**. 원본 데이터만으로 normal map 방향·최종 GPU 색 처리의 옳음을 확정하지 않는다. 제작 스크립트는 normal 이미지를 Non-Color로 설정하고, 코어 FLOAT_COLOR를 선형 값으로 기록한다. `COLOR_0`를 다시 sRGB에서 선형으로 변환하면 이중 변환이다.

## Blender와 게임 차이의 분리

`production/render_landmarks.py`는 최종 게임 GLB를 재임포트한다. Cycles 32 samples + denoise, AgX/Medium High Contrast, World RGB `(.16,.20,.22)`·강도 `.55`, 면광원 3개와 폭 `.35`/높이 `3`의 좁은 직사각 면광원 1개를 쓴다. 좁은 면광원은 `(3,-4,.6)`에 있고 power `260`이며 코어 쪽을 향한다. 이 조명은 GLB에 들어가지 않는다.

Blender 렌더 카메라는 Z-up `(1.7,-4.8,6.2)`에서 `(0,0,.22)`를 보는 정사영, scale `2.7`이다. 원본 모델 렌더는 1400×950·투명 배경이다. 실제 Godot은 Mobile/FILMIC·색 환경광·주/보조 방향광·결정 전용 보조 방향광·정적 공유 ReflectionProbe를 쓴다. 면광원의 모양과 Cycles 경로 추적 반사/굴절이 게임으로 자동 전달되지 않는다. Blender와 Godot의 조명 숫자가 같다고 같은 조명이라고 판정할 수 없다.

기존 카메라 진단 (`../../../portal_core_concepts/verification/transfer-diagnosis/crystal-camera-geometry.json`, 로컬 자료)의 동일 GLB·동일 정사영 scale `1.8` 비교는 게임 고도 `62.7123°`에서 실루엣 종횡비 `1.5007`, Blender 방향 고도 `49.5846°`에서 `2.0025`였다. 이 수치는 기존 측정 기록이며 이번 데이터 조사에서 새로 렌더한 값이 아니다. 게임의 짧은 인상은 이 시점 차이를 분리해 해석해야 한다. A/B/C 재질 비교에는 같은 카메라·조명·배경·회전 위상을 사용하고, Blender 방향 추가 비교를 게임 카메라 수정으로 반영하지 않는다.

## 후속 검증 경계

이 조사에서 색/텍스처 참조 누락을 이유로 원본을 수정할 근거는 발견하지 못했다. 내장 import 결과의 정점색 사용·선형 처리, 생성 tangent, emission 강도, normal/roughness 채널을 확인한 뒤 재질 설정을 평가한다. 원본 roughness/금속성을 일괄 보정하거나 텍스처를 증설할 필요는 확인되지 않았다. 시각 통과, 투명 정렬/앞쪽 물체 굴절, Android 비용, 최종 PCK 반영은 이 원본 조사와 별도 증거가 필요하다.

## 실제 임포트·후보 계약 결과

후속 검증은 공용 APK 빌드와 분리한 `build/godot/native-contract-test`에서 수행했다. 소스와 GLB를 복사하고 `.godot` 캐시·기존 `.import`를 제외해 Godot 4.7.2로 새로 임포트했다. 공용 `build/godot/project`, 원본 GLB, prepare/PCK 경로를 변경하지 않았다.

[verify_native_contracts.gd](../../../../../godot/verify_native_contracts.gd)는 **6,540개 검사·실패 0개**로 종료했다. fresh import 로그 (`native-contract-fresh-import.log`, 로컬 자료), 실행 로그 (`native-contract-run.log`, 로컬 자료), 구조화 결과 (`native-contract-report.json`, 로컬 자료)를 보존했다.

- 실제 임포트 재질 25개의 storage 속성 125~126개를 비교했다. 후보가 의도적으로 바꾸는 이름·내장 굴절 활성·굴절 scale·Albedo alpha 외의 값과 참조는 같았고, 원본은 후보 생성 전후 그대로였다. 이번 원본의 `refraction_scale` 기본값도 `.05`여서 실제 차이는 이름·alpha·refraction 활성 세 속성이었다.
- 코어 `albedo_color`는 `(1,1,1,1)`, `vertex_color_use_as_albedo=true`, `vertex_color_is_srgb=false`였다. 임포트 `emission`의 sRGB 표현은 약 `(.0186,.1977,.2127)`로 GLB 선형 `(.00144,.0324,.0372)`와 표현 공간이 다르다. 후보는 이 임포트 값을 그대로 보존한다. 이 숫자 차이를 임의 색 보정의 근거로 사용하지 않는다.
- 조사한 모든 normal map surface에 UV·Godot 생성 tangent가 있었다. 임포트 roughness G, metallic B, AO R 채널과 normal/AO 사용 플래그도 통과했다. 원본 GLB에 tangent가 없었던 항목의 데이터 전달 미검증은 해소됐다. 실제 노멀 방향·광택의 시각 평가는 GPU 캡처에 남는다.
- 텍스처가 없는 코어만으로 보존을 판정하지 않고 석재·금속에 같은 후보 복제를 적용해 텍스처 속성 34개의 동일 Resource 참조를 확인했다. 이는 연결 함수 검증이며 석재·금속에 유리 설정을 채택한 것이 아니다.
- 두 타일의 결정에 후보 객체 하나를 공유한 상태에서 전투 시각 `0→1.1`, 피격 입력, 같은 시각 재전달을 검사했다. 메시·재질 공유, 결정 변환 변화·정지, 받침 10개 변환 고정, 원본 surface 재질 불변을 확인했다. 기존 전투/HUD 전체 회귀 검사는 이 스크립트에서 반복하지 않았다.

재현 명령은 독립 프로젝트 생성 후 아래와 같다. 결과 출력 디렉터리는 먼저 존재해야 한다.

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/native-contract-test --import
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/native-contract-test --script res://verify_native_contracts.gd -- --output=/Users/sejin/Documents/RuneNexus/design/stage1_3d/native_material_workflow/verification/first-native-20260913/native-contract-report.json
```

이 검사는 후보의 데이터·공유·애니메이션 계약에 한정된다. 시각 수용이나 PCK 포함, 실제 Android 렌더러의 굴절·투명 정렬·성능을 통과했다고 해석하지 않는다.
