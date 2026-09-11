# Flutter 안의 Godot 3D 연결 테스트

역할: 본게임과 동일한 Godot 전장 코드를 사용하는 별도 Android 검수 앱. 확인: 2026-09-11. 본게임 진입·공용 빌드·검증 범위는 [스테이지 1 전장 문서](../../../docs/stage1_3d_preview.md)를 따른다. 배포는 별도다.

## 실행과 비교

- 설치 이름: **Rune Nexus Godot 테스트**
- 패키지: `com.example.rune_nexus.godotpreview`
- 전달 APK: `build/apk-preview/rune-nexus-godot-cannon-arm64.apk`
- ARM64 Android용 release 빌드. 일반 앱과 이전 ThreeJS 시험 앱에 나란히 설치한다.
- 메모리 저장소와 Noop 온라인 저장소를 사용한다. 실제 계정·진행 데이터에 연결하지 않는다.

앱은 세로 화면에 대포 6문·체력 10억의 정지 표적 3기를 배치한 **정지 장면**으로 시작한다. `연속 사격 시작`으로 실제 조준·발사·피해 판정이 진행된다. 고정/드론 시점, 1·2·4배속, 일시 정지·처음 상태로·확대를 제공한다.

스테이지 1 지형의 고정↔드론 전환은 전장 중심을 바라보는 **0.7초 cubic ease-out**이다. 처음에 빠르게 움직이고 마지막에 감속하며, 전환 중 다시 누르면 현재 위치에서 새 목표로 이어진다. 전투 일시 정지·배속과 독립적으로 재생하고 확대·화면 크기·그림자 설정 변경으로 재시작하지 않는다. 정지한 폭발도 카메라 광선을 갱신해 입체감을 유지한다.

S26 Ultra에서는 다음 순서로 확인한다.

1. 정지 장면의 움직임 없는 상태에서도 화면·버튼이 끊기는지 확인한다.
2. `빈 3D 화면`으로 네이티브 화면 합성 자체의 상태를 비교한다.
3. 지형을 다시 켜고 `그림자`를 끄고 켜며 비교한다.
4. 연속 사격 1배속·4배속에서 `폭발 볼륨`을 비교한다. 이 스위치는 착탄의 볼륨·불티·파편·순간 조명을 함께 제어한다.

FPS와 ms는 **Godot 프레임 주기**이며 GPU 타임스탬프 측정값이 아니다. 드로 콜·삼각형은 Godot의 렌더 통계다. 두 엔진의 화면 크기·조명·셰이더가 완전히 같지 않으므로 기존 APK와 수치 하나만으로 동등 비용의 벤치마크로 해석하지 않는다. 실기기 성능 수용 기준은 [3D 시험 문서](../../../docs/stage1_3d_preview.md#범위와-제약)를 따른다.

## 책임과 에셋

- Flutter: 검수 UI, 수명주기, 상태 전달.
- Flame/RuneNexusGame: 기존 전투 갱신과 `BattlefieldFrame`. 보이지 않는 `GameWidget`은 전투만 갱신한다.
- Godot 4.7.2: GLB 지형·대포·표적, 탄환, 3D 볼륨·파편, 카메라·그림자·순간 조명. Mobile 렌더러를 사용한다.
- Android: 공식 `org.godotengine:godot:4.7.2.stable` AAR를 `PlatformViewLink`의 hybrid composition으로 합성한다. WebView·웹 렌더는 사용하지 않는다.

Flutter는 프레임 하나를 JSON으로 묶어 보낸다. Android 브리지는 아직 소비하지 못한 프레임을 최신값으로 교체하고 Godot 렌더 스레드가 읽는다. 개별 오브젝트마다 채널을 호출하거나 프레임 대기열을 쌓지 않는다. Godot 엔진은 프로세스에서 한 개를 유지하며 화면 분리·앱 백그라운드에서 렌더를 멈춘다. 전장 재진입과 Activity 재생성 때 같은 엔진을 다시 연결한다.

기존 `assets/images/stage1_3d/`의 지형·대포·tank GLB와 `cannon_field.json/bin`을 재사용한다. 검수 UI는 이 디렉터리, 본게임과 공유하는 Godot 소스는 루트 `godot/`, 복사·임포트된 프로젝트와 PCK는 `build/godot/`에 둔다. `encodeGodotBattlefieldFrame`도 본게임과 검수 앱이 함께 사용한다. 폭발은 같은 48³×32시점 캐시를 3D 텍스처로 공유하고 32단계 광선 적분과 불티 56개·파편 34개를 사용한다. 전체 수명은 1.1초다. 카메라를 향하는 착탄 이미지나 평면을 사용하지 않는다.

GLB의 정점 색상 사용 플래그를 임포트 후 보정한다. Godot 방향광과 환경광을 사용하므로 기존 ThreeJS의 면광원·AgX 색조와 픽셀 단위로 같지는 않다. 이 검수 UI는 대포 시나리오를 제공한다. 본게임은 같은 런타임에 포탑·적의 실제 종류와 건설 미리보기를 전달하고, 반환된 카메라 투영으로 기존 입력·상태 표시를 맞춘다.

## macOS 빌드

Godot 공식 4.7.2 일반판 실행 파일이 필요하다. 기본 탐색 경로는 `build/godot-preview/tools/Godot.app/Contents/MacOS/Godot`이며 다른 위치는 `GODOT_EXECUTABLE`로 지정한다. AAR와 PCK의 엔진 버전 일치를 검사한다.

```sh
bash design/stage1_3d/godot_preview/build_macos.sh
```

스크립트는 공용 `scripts/build_godot_pack.py`로 에셋 준비·Godot 임포트·라이선스 고지 생성·PCK 내보내기를 수행하고, 검수 UI의 Flutter release APK를 빌드해 이름을 구분한 전달본을 복사한다. `RUNE_NEXUS_DEBUG_PANEL=true`는 이 로컬 검수 대상에만 적용한다. Godot MIT 라이선스와 엔진에 포함된 외부 라이브러리 고지는 PCK의 `engine_licenses.txt`에 포함된다.

`runeNexusGodotPreview` Gradle 속성은 검수 앱의 패키지·표시 이름·Activity를 선택한다. 일반 앱과 검수 앱은 공식 Godot AAR·PCK·호스트·브리지를 공유한다. 이 전달 스크립트만 ARM64를 선택하며 일반 빌드의 ABI 선택은 유지한다. Godot이 제공하는 C++ 런타임 하나를 사용해 기존 ANGLE 런타임과의 중복을 제거한다.

일반·검수 release에 공통 `android/app/proguard-rules.pro`를 적용한다. Godot 4.7.2 AAR에는 JNI 보존 규칙이 포함되지 않아 R8이 `GodotIO.openURI` 등의 메서드를 제거하거나 네이티브 호출의 반환형을 바꿀 수 있다. `org.godotengine.godot` 패키지를 보존해 시작 시 `NoSuchMethodError`와 SIGABRT를 방지한다. 로그인·세션·업데이트 기능의 기존 구현은 유지한다.

## 검증 기록과 한계

본게임 연결 후에도 별도 검수 앱의 정지·4배속 다중 사격과 양방향 시점 전환을 Android 17 ARM64 에뮬레이터에서 다시 확인했다. 일반 본게임 APK와 같은 PCK를 사용하며 현재 두 APK의 해시·내장 팩 일치 검사는 `build/godot/main-verification/artifacts.json`에 있다. [본게임 적용 영상](../main_runtime/stage1-camera-transition.mp4)은 기존 검수 UI 영상과 구분한다. HUD 없는 검수 화면의 전체 맞춤은 기울어진 지형의 실제 투영 폭·높이를 포함해 가장자리 잘림을 방지한다.

Flutter 정적 분석, 기존 폭발·무기 표시 테스트 3개, Godot 브리지 화면 테스트 1개, Godot 프로젝트/PCK 로딩과 네이티브 Mobile GPU 렌더가 통과했다. 브리지 화면 테스트는 320×640에서 준비·기본 정지·실제 전투시간 진행·종료를 모의 Android 채널로 확인한다. ARM64 APK의 별도 패키지·서명·단일 C++ 런타임·내장 PCK 일치도 확인했다.

`godot/verify_camera.gd`는 실제 장면에서 초기 시점, 후반 감속, 중심 유지, 정확한 양방향 도착, 연속 클릭, 확대 중 전환 유지, 정지 폭발의 카메라 동기화를 검사한다. `Godot --headless --path build/godot/project --script res://verify_camera.gd`로 실행하며 검수 스크립트는 APK의 PCK에서 제외한다.

`godot/verify_scene.gd`는 같은 장면의 고정/드론 시점에서 실제 GPU 캡처를 저장한다. `build/godot/captures/`의 이미지는 **Mac의 Godot 장면 검수**이며 Android 앱 화면 캡처나 모바일 성능 결과가 아니다. 브리지 테스트는 `scripts/in_app_server_macos.sh flutter test --dart-define=RUNE_NEXUS_DEBUG_PANEL=true test/godot_preview_test.dart`로 재현한다.

Android 16 ARM64 에뮬레이터에서 이전 APK의 시작 직후 SIGABRT를 재현하고, R8 규칙을 적용한 동일 패키지의 덮어 설치와 정상 엔진 초기화를 확인했다. Android 17 ARM64 에뮬레이터에서는 수정 APK 그대로 정지 장면·Flutter/Godot 화면 합성·4배속 다중 폭발·드론 전환·백그라운드 복귀가 통과했다. 이 실행의 Godot 스크립트·렌더 오류 및 앱 크래시는 없었다. 실제 Android 앱 캡처는 `build/godot-preview/crash-after/api37/`에 있다.

카메라 감속 전환은 Android 17 ARM64 에뮬레이터의 release APK에서 확인했다. [24초 실제 앱 녹화](captures/stage1-camera-transition.mp4)에는 정지 장면의 왕복 전환, 4배속 사격 중 전환과 빠른 방향 변경이 포함된다. 실행 중 Godot 오류·크래시는 없었으며 자동 카메라 검사도 통과했다. 녹화는 1080×2424, 약 60fps이며 실기기 성능 측정은 아니다. 상세 검증은 `build/godot-preview/camera-verification/result.json`에 기록한다.

Android 16 에뮬레이터의 검은 화면과 `VkResult error 5`는 별도의 [Godot/gfxstream Swappy 이슈](https://github.com/godotengine/godot/issues/121035)와 일치하며, 같은 APK를 Android 17에서 실행하면 발생하지 않았다. 이 에뮬레이터 문제를 피하려고 실기기용 렌더 설정을 바꾸지는 않는다. S26 Ultra 사용자는 수정 APK에서 체감 끊김이 사라졌다고 확인했다. 실기기의 정량 프레임 성능은 아직 측정하지 않았다. APK 패키지·서명·ABI·내장 PCK와 실행 검증은 `build/apk-preview/godot-verification.json`에 기록한다. 기존 엔진 시험 절차는 [ThreeJS 다중 사격 APK](../cannon_impact/barrage_runtime/README.md)를 따른다.
