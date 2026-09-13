# 내장 PBR + 공용 환경 반사 적용

2026-09-13. 사용자가 승인한 후속 방향을 공용 런타임에 적용했다. **코어는 화면 굴절 없는 StandardMaterial3D로 전환했다.** 반사 하이라이트가 회전에 따라 다른 결정면에 나타나고, 화면 굴절 때문에 받침이 내부 흰 띠처럼 보이던 현상은 사라졌다. 현재 결과는 광택 있는 불투명 결정이며 Blender Cycles의 투과·내부 다중 굴절 재현은 아니다.

- GLB의 형태·피벗·면색·노멀·거칠기 .055·금속성0·발광을 유지한다. 원본 StandardMaterial3D를 한 번 복제해 모든 코어가 공유하며 굴절·알파 혼합을 끈다.
- `godot/materials/battlefield_reflection_sky.tres`는 내장 GradientTexture2D(256×128 HDR)·PanoramaSkyMaterial·128px Sky로 구성한 공용 반사 환경이다. 밝기 띠는 반사에 보이는 공용 광원 형태이며 코어 색·발광·테두리에 그린 효과가 아니다. 외부 이미지·광학 shader·의존성을 추가하지 않았다.
- 주광 1.45→1.0, 확산 환경광 .35→.25로 조절하고 공용 반사광을 석재·금속에도 연결했다. 기존 색 배경·게임 카메라·추가 보조광은 유지한다. 사용하지 않는 코어 전용 ReflectionProbe는 제거했다.
- 포탈·식생 바람·입체 포탄 VFX, 전투·저장·원본 GLB 변경 없음.

## 확인한 결과

게임 방향 확대 (`core-glass.png`, 로컬 자료) · 회전 후 (`core-glass-rotated.png`, 로컬 자료) · 반사 없음 대조 (`core-glass-no-reflection.png`, 로컬 자료) · Android 본게임 고정 (`android-fixed.png`, 로컬 자료) · Android 본게임 드론 (`android-drone.png`, 로컬 자료)

직전 커스텀 화면은 첫 실험의 같은 게임 시점 (`../first-native-20260913/desktop/game-close-A-custom-0.0.png`, 로컬 자료)과 비교할 수 있다. GLB·카메라·0초 위상은 동일하고, 이번 변경 변수는 내장 재질과 명시한 공용 조명/반사 환경이다. 확대 이미지는 데스크톱 Godot, HUD가 있는 이미지는 일반 본게임 release APK의 Android17 ARM64 에뮬레이터 캡처다.

관련 검사만 실행했다: 기존 `verify_scene.gd --crystal-glass`로 반사·보조광·회전 반응, `verify_runtime.gd` 실패0으로 공유 재질·원본 PBR·단일 결정·받침 고정·정지·기존 표시 계약 확인. Android 실제 본게임에서 기존 스테이지1·HUD·고정/드론 시점을 확인했다. 새 검수 앱/UI·전체 테스트 반복·성능 벤치마크는 추가하지 않았다. 실기기 발열·4배속 지속 전투 성능은 미검증이다.

## 설치와 비용

설치용 ARM64 본게임 APK (`../../../../../build/apk-main/rune-nexus-native-reflection-arm64.apk`, 로컬 자료): **234,773,173 B**, 직전 같은 본게임 ARM64 APK 대비 **+208 B**. PCK도 58,453,692→58,453,900 B(+208 B)이며 APK 내장 팩과 공용 팩이 일치한다. 설정 리소스 추가와 기존 런타임 코드 정리가 상쇄된 결과다. APK 해시·크기 (`apk.json`, 로컬 자료). 입력 build-number4004 / ARM64 실제 versionCode6004이며 기존 앱 데이터 삭제 없이 설치했다. 공개 배포·커밋·푸시는 하지 않았다.
