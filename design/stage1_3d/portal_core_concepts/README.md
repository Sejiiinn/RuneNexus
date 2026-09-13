# 포탈·코어 공용 A안

2026-09-12. 사용자가 선택한 A안을 바탕으로 바닥과 분리된 실제 3D 모델을 제작하고 Android 스테이지 1의 공용 Godot 런타임에 연결했다. 새 배포는 하지 않았다. 설치용 로컬 검수 APK는 `build/apk-preview/rune-nexus-core-crystal-v6-arm64.apk`다.

## 현재 이관 상태 — 시각 재현 미완료

2026-09-13 [첫 내장 재질 비교](../native_material_workflow/verification/first-native-20260913/README.md): Android에서 임포트 재질의 불투명한 인상과 내장 굴절의 내부 띠·유리 하이라이트 부족을 확인해 후보를 채택하지 않았다. 첫 실험에서는 기존 GLB·공용 런타임을 유지했다. 이후 사용자 승인으로 [굴절 없는 내장 PBR·공용 환경 반사](../native_material_workflow/verification/native-reflection-20260913/README.md)를 적용했다.

사용자가 승인한 모습은 `verification/transfer-diagnosis/approved-blender-reference.jpg`다. 게임의 뭉뚝한 인상과 유리 내부면 표현 차이가 남아 있어, v6의 빌드·재질 값 연결 검사 통과를 시각 이관 완료로 취급하지 않는다.

동일 GLB·동일 게임 재질/조명·동일 배율에서 카메라만 비교한 결과, Blender 방향은 고도49.5846도·실루엣 세로/가로2.0025, 게임은 고도62.7123도·1.5007이다. 원본과 Godot 입력 GLB의 바이트 해시, 512개 정점 수·크기(.27104,.84,.27104)·스케일은 일치했다. 승인 이미지도 최종 GLB를 재임포트한 Blender 렌더이므로 형상 내보내기 변형이 아니다. 게임의 한 번짜리 화면 굴절은 Blender Cycles의 다중 굴절과도 다르다.

증거는 `verification/transfer-diagnosis/`의 두 카메라 캡처와 JSON·로그다. 진단 중에는 게임 카메라·재질·형상을 추가 변경하지 않았다. 기존 `verify_scene.gd`의 `--crystal-camera-comparison` 옵션으로 같은 조건의 비교를 재현할 수 있다.

## 현행 형태와 재사용 계약

- 포탈: 낮은 석재 고리, 황동 룬 고정구 네 개, 오목한 보라색 소용돌이.
- 코어: 낮은 팔각 받침, 네 방향 금속 지지대, 길쭉한 청록 크리스탈 부유 결정. 긴 다이아몬드 주면과 폭 약 0.0025타일의 얇은 절단면으로 구성한다. 내부의 불투명 덩어리·선을 제거한 단일 결정이다. 사용자가 승인한 Blender 렌더의 면색·유리 광택을 기준으로 실제 주변 반사·광원 하이라이트를 적용한다. 파란 테두리·모서리 전용 발광은 사용하지 않는다.
- 두 모델 모두 **바닥 타일·이끼·식생을 포함하지 않는다**. 타일의 지면 위에 독립 배치하며 포장길·건설석판·자연석에 같은 모델을 쓴다.
- glTF `+Y` 위, XZ 평면, 타일 한 변 `1`, 지면 `Y=0`, 루트 원점은 타일 중심이다. 방향에 따라 별도 모델을 만들지 않는다.
- 포탈 폭 약 `0.91`, 높이 `0.191`타일. 코어 받침 폭 약 `0.75`, 전체 높이 `1.14`타일. 결정 자체는 폭 `0.27104`·길이 `0.84`타일로 이전보다 40% 길고 약 12% 가늘다. 정적 부품과 애니메이션이 한 타일 수평 경계를 넘지 않는다.
- 루트 이름은 `portal`, `core`. `portal_vortex`는 로컬 XZ 반경 `0.305`, 가장자리 Y `0.115` / 중심 Y `0.048`의 오목 메시다. `core_crystal` 피벗 Y는 `0.72`이다.
- 포탈 소용돌이는 **불투명 공유 셰이더 1패스**, 코어는 결정만 최대 `0.018`타일 부유·완만 회전한다. 석재 받침은 움직이지 않는다. 전투 시간·정지·배속을 따르며 기존 피격 반응은 결정에만 적용한다.
- 결정은 GLB의 StandardMaterial3D를 한 번 복제해 공유한다. 원본 면색·노멀·거칠기 .055·금속성0·발광을 보존하고 화면 굴절·알파 혼합은 끈다. Transmission .80/IOR1.46은 제작 metadata이며 현재 엔진 광학 동작으로 사용하지 않는다. 내부 객체·별도 윤곽선을 만들지 않는다.
- 공용 `battlefield_reflection_sky.tres`의 128px 하늘 반사를 사용한다. 내장 GradientTexture2D·PanoramaSkyMaterial로 밝은 광원의 반사를 만들고 석재·금속도 같은 환경을 수신한다. 기존 코어 전용 ReflectionProbe는 제거했다. 배경·게임 카메라는 유지한다.
- 여러 인스턴스는 메시·재질을 공유한다. 모델별 광원·AnimationPlayer·스킨 애니메이션을 추가하지 않는다.

## 파일과 제작 경로

| 파일 | 역할 |
| --- | --- |
| `portal-core-directions-v1.png` | ImageGen의 최초 A/B/C 비교 시안. 위 포탈 / 아래 코어. A의 사각 바닥은 공용 모델에 포함하지 않음 |
| `prompt.txt` | 최초 시안의 전체 생성 프롬프트 |
| `production/rune-landmarks.blend` | 편집 가능한 현행 원본. `01 Portal Master`, `02 Core Master`에서 각각 확인 |
| `production/build_landmarks.py` | 최초 형태 생성기. 수동 편집한 원본 위에 다시 실행하지 않음 |
| `production/refine_core_crystal.py` | 기존 편집 원본의 결정만 절대 목표 치수·반사/굴절 유리 재질로 보정하고 이전 내부 물체를 제거. 반복 실행 시 치수 누적 없음 |
| `production/export_landmarks.py` | 원본에서 읽은 복사본의 정적 부품만 재질별 병합, 독립 GLB 출력. 부품을 공유하는 검수 Scene은 출력 복사본에서만 제거해 병합 잔여 객체 방지 |
| `production/render_landmarks.py` | 내보낸 GLB를 재임포트해 형태·기존 세 타일 배치 검수 |
| `production/models-a.png` | 게임 GLB의 Blender 정지 렌더. 투명 RGBA, 1400×950. Godot 소용돌이·결정 시선각 셰이더는 포함하지 않은 형태 검수 |
| `production/tile-compatibility-a.png` | 포장길·건설석판·자연석 위 동일 모델 배치. Blender 렌더이며 게임 캡처가 아님 |
| `production/manifest.json` | 실제 메시·삼각형·좌표 경계·GLB 크기 |
| `../../../assets/images/stage1_3d/environment/landmarks.glb` | 게임용 최종 파일: 저장소 루트 `assets/images/stage1_3d/environment/landmarks.glb` |
| `verification/crystal-v6/android-angled.png` | 최신 원본 재질 연결·테두리 제거의 Android 실제 검수 앱 화면 |
| `verification/crystal-v5/android-angled.png` | 이전 모서리 발광 방식의 Android 기록 |
| `verification/crystal-v4/android-angled.png` | 이전 유리 반사·굴절 보정의 Android 기록 |
| `verification/crystal-v3/android-angled.png` | 이전 알파 투명 방식의 Android 기록 |
| `verification/crystal-v2/android-angled.png` | 이전 내부 발광체 방식의 Android 기록 |
| `verification/android-angled.png` | Android 17 ARM64 에뮬레이터의 실제 별도 검수 앱, 고정 시점 |
| `verification/android-drone.png` | 같은 앱의 4배속 전투·드론 시점 |
| `verification/android-4x-drone.mp4` | 같은 앱의 4배속 재생 10초 녹화 |

현재 세션에는 Blender MCP가 없어 설치된 Blender 5.2.1의 독립 background 프로세스로 제작했다. 석재 normal은 기존 `environment/textures/weathered_stone_normal.png` 512²를 재사용한다. GIMP MCP의 축소 연결이 실패하여 원본 크기를 유지했으며 새 2D 보정은 하지 않았다. 노멀 이미지는 편집 원본과 GLB에 포함된다. 외부 이미지·새 의존성은 추가하지 않았다.

수동 편집 후 저장소 루트에서 다음 순서로 내보낸다. `export_landmarks.py`는 저장된 원본을 읽고 복사본에서만 병합하며 `.blend`를 덮어쓰지 않는다. 생성기를 다시 실행하면 수동 편집을 대체하므로 구분한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/portal_core_concepts/production/export_landmarks.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/portal_core_concepts/production/render_landmarks.py
python3 scripts/build_godot_pack.py
```

원본은 [Blender 작업 허브](../blender_workspace/README.md)의 Scene 22/23에 연결한다. Blender 정지 렌더의 재질과 실제 Godot 조명은 동일한 결과를 보장하지 않는다. Blender 원본은 Alpha=1, Transmission=.80, IOR=1.46, Roughness=.055의 유리이며 렌더 검수의 좁은 면광원은 출력 모델에 포함하지 않는다. 소용돌이의 움직이는 깊이·발광은 `godot/environment/portal_vortex.gdshader`가 담당한다. glTF는 정점색의 emission 연결을 지원하지 않으므로 코어 발광은 고정 청록색으로 내보내고 정점색은 결정 면별 base color에만 사용한다. `core_crystal.gdshader`는 단일 `core_crystal_facets` surface에 적용한다. 정점색은 원본의 면색으로만 사용하며 모서리 분류나 발광 표식으로 해석하지 않는다. 이전 내부 물체 재질은 내보내지 않는다. 초기 형태 생성기를 다시 사용한 경우 `refine_core_crystal.py`를 먼저 실행해 현행 결정을 복원한다.

## 게임 연결과 비용

Godot `main.gd`는 기존 terrain 라이브러리와 별도로 `landmarks.glb`를 읽어 실제 spawn/core 타일 중심에 복제한다. 기존 `terrain.glb`의 예전 포탈·코어는 다른 렌더 경로 호환을 위해 보존하지만 Godot에서는 새 모델을 배치한다. 기존 지형·맵 데이터·전투 수치·저장 계약은 유지한다. 공용 모델을 여러 지형에 배치할 수 있으나 현재 Godot 본게임 적용 범위는 기존과 같은 Android 스테이지 1이다.

- GLB **1,408,664 bytes(약 1.34MiB)**. 포탈 4메시/5,320삼각형, 코어 6메시/2,004삼각형.
- 두 모델 합계 7,324삼각형. 코어 결정은 단일 유리 재질 surface만 사용한다. 받침 중앙 발광만 별도 재질로 낮춰 투명한 결정 아래가 흰 원으로 뭉치지 않게 했다.
- 새 GLB는 Godot PCK에만 들어간다. Flutter `pubspec.yaml`에 중복 추가하지 않았다.
- 최신 원본 재질 연결의 로컬 ARM64 검수 APK는 230,839,797 → 230,840,613 bytes(+816 bytes / +0.00035%). 증가는 원본 속성 전달·셰이더·검증 코드다. Flutter 중복 포함은 없으며 공개 배포는 하지 않았다.
- 네이티브 압축 크기 95,305,424 bytes 유지, 검수 APK ABI `arm64-v8a` 유지. 새 GLB의 Flutter 중복·design 원본 포함 없음. 최신 상세는 `verification/crystal-v6/apk-before.json`, `apk-after.json`. 이전 A안 최초 적용 비교는 상위 `verification/`에 보존한다.

## 검증과 한계

- Godot import 및 `verify_runtime.gd`: 실패 0개. 포탈·코어 각각 두 개 동시 배치, 메시·재질 공유, 타일 경계·접지, 결정만 움직임, 같은 시간 재전달 시 정지, 맵 재진입을 확인했다. 유색 발광/마모 보정 뒤 import·런타임 검사도 통과했다.
- `verify_environment.gd`: 실패 0개. 기존 환경·점유 구조 회귀 확인.
- `verify_scene.gd`: macOS Metal GPU 고정·드론 렌더 및 포탈 셰이더 컴파일 통과. Android 캡처와 구분한다.
- Python 제작·내보내기 스크립트 구문 검사 및 변경 파일 공백 검사 통과. Dart 수정이 없어 Flutter 분석·테스트를 불필요하게 반복하지 않았다.
- 공용 PCK·별도 release APK 빌드 및 기존 검수 앱 덮어 설치 성공. 본게임과 같은 Godot 런타임을 사용한다.
- Android 17 ARM64 에뮬레이터에서 실제 검수 앱의 고정/드론 시점, 4배속 연속 사격 중 타일 내 배치·포탈 보라색/코어 청록색 구분·시점 전환을 확인했다. 10초 재생을 녹화했으며 해당 실행 로그에서 스크립트·셰이더·앱 크래시 오류가 없었다. 실기기 성능 수용 판정은 아니다.
- UI 계층 덤프는 초기 화면에서 실패하여 직접 Android 화면 캡처로 확인했다. 화면 덤프 성공을 시각 검증으로 대신하지 않았다.
- 실기기의 지속 전투·발열 성능이나 공개 배포 검증은 수행하지 않았다. 에뮬레이터 화면의 FPS를 실기기 성능 보장으로 해석하지 않는다.

## 이전 v2 보정 기록 — 내부 물체 방식은 v3에서 대체

2026-09-12 후속 요청. 이전 모델·원본은 `verification/crystal-v2/landmarks-before.glb`, `production/rune-landmarks-before-crystal-v2.blend`에 보존했다. 최신 기록은 `verification/crystal-v2/`를 따른다.

- Godot import·런타임 검사 실패 0개. 결정 길이·슬림비, 높이 1.2타일 이내, 외피 재질 공유와 불투명 내부 발광체 보존을 확인했다.
- Metal GPU 고정/드론 장면의 새 투명 셰이더 컴파일과 두 화면 확인 완료.
- 외피·내부 형상과 실제 GLB를 재임포트한 Blender 렌더를 확인했다. 포탈·받침의 형태와 공용 수평 타일 경계는 보존했다.
- 최신 release APK 빌드·기존 검수 앱 덮어 설치 성공. Android 17 ARM64 에뮬레이터의 고정 시점에서 길어진 결정·반투명 외피·청록 내부를 확인했고, 실행 로그에 스크립트·셰이더·앱 크래시 오류가 없었다. 새 APK 증가량은 3,004 bytes이며 네이티브 라이브러리·ABI·Flutter 중복 포함 변화는 없다.
- 실기기 지속 전투·발열 성능은 미측정이다. 이번 국소 재질/형태 보정에서 기존 전체 Flutter 테스트와 환경 검사를 반복하지 않았다.

## 이전 v3 보정 기록 — 알파 중심 재질은 v4에서 대체

사용자 피드백에 따라 내부에 갇힌 것처럼 보이던 불투명 발광 결정과 내포물 선을 제거했다. 길쭉한 형태·받침·포탈·부유 동작은 유지한다. 재사용 시 불투명 내부 surface가 다시 들어오지 않는지 런타임 검사에 포함했다. 이전 v2 원본·GLB는 `verification/crystal-v3/source-before.blend`, `landmarks-before.glb`에 보존했다.

단일 결정 보정 후 Godot import·런타임 검사 실패 0개, GLB 재임포트 형태 렌더와 release APK 빌드가 통과했다. 최신 Android 화면·로그 결과는 `verification/crystal-v3/result.json`을 따른다. 실기기 성능 판정은 아니다.

## 이전 v4 보정 — 환경 반사·광원·굴절 기반

시안의 유리 표현에 맞춰 낮은 알파로 흐리게 만들던 재질을 교체했다. 실제 지형을 반사하고 면 방향으로 화면을 굴절하며, 결정 전용 고정 보조광의 하이라이트가 회전에 따라 지나간다. 내부 물체·도색 하이라이트는 추가하지 않았다. 기존 높이·받침·공용 타일 배치·부유 동작은 유지한다. 이전 v3 원본·GLB는 `verification/crystal-v4/source-before.blend`, `landmarks-before.glb`에 보존했다.

Godot runtime 실패 0개. Metal Mobile GPU에서 프로브 끄기·보조광 specular 끄기·결정 회전을 각각 비교해 실제 반사와 광원 반응을 확인했다. 결정 투영 영역에서 변화한 픽셀 수는 각각 6,137 / 1,301 / 11,505였다. 동일 시점 정지 렌더와 원거리 고정·드론 화면도 확인했다. Metal 검수 프로세스 종료 시 Texture RID 7개 경고가 남으며, 장면 해제 뒤에도 재현된다. 렌더 중 기능 실패와 구분하며 실기기 장기 실행 성능은 미측정이다.

## 이전 v5 보정 — 모서리 발광은 v6에서 제거

다이아몬드형 주면과 좁은 실제 bevel을 연결해 결정의 큰 면·얇은 경계를 만들었다. 돌바닥이 그대로 비쳐 보이던 굴절 기여는 낮추고 청록 면의 농도와 절단면의 산란광을 더했다. v4의 실제 환경 반사·고정 보조광·회전 반응은 유지한다. 삼각형은 204개 늘었고 내부 물체·추가 surface·텍스처·광원은 추가하지 않았다.

최종 GLB import·runtime 검사 실패 0개. 단일 결정·치수·공유 재질·주면/절단면 RGB 표식과 부유·회전·정지를 확인했다. GPU에서 환경 반사 끄기·보조광 specular 끄기·회전을 각각 비교해 실제 반응을 확인했으며, 결정 영역의 변화 픽셀은 9,613 / 1,723 / 14,215였다. 출력 GLB 재임포트 Blender 렌더에서 큰 면과 좁은 절단면도 확인했다. 최신 로그·캡처·APK 용량 비교는 `verification/crystal-v5/`에 있다.

## v6 현행 보정 — Blender 원본 재질 연결

사용자가 괜찮다고 한 Blender 원본의 형태와 면색을 보존하고, 게임에만 추가했던 파란 모서리 발광·임의의 색 보정을 제거했다. 표준 PBR 값은 GLB 재질에서 읽고, 기본 importer가 생략하는 유리 투과율·굴절률은 export 시 원본 BSDF 값을 노드 extras로 전달한다. 게임에서 재질 값을 별도로 조정하지 않는다.

Godot runtime 실패 0개. 원본과 게임의 거칠기·발광색·투과율·굴절률 일치를 검사에 포함했다. GPU 확대 렌더에서 파란 테두리 제거와 실제 반사·광원·회전 반응을 확인했다. Blender Cycles의 다중 굴절과 Godot Mobile의 화면 굴절, 조명 환경은 서로 다르므로 이미지가 픽셀 단위로 같다는 의미는 아니다. 최신 기록은 `verification/crystal-v6/`를 따른다.
