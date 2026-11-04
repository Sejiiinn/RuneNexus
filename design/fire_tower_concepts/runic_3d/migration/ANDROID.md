# 화염 포탑 Android 검수

`android_preview.dart`는 기존 대포 검수 UI를 보존한 별도 진입점이다. `debugShowCannonBarrage(turretType: TurretType.magic)`로 실제 전투의 화염 포탑 6문과 정지 표적 3기를 만들며, 본게임과 같은 Godot PCK·브리지를 사용한다. 메모리 저장소·Noop 온라인 저장소를 사용하여 본게임 계정과 진행 데이터를 바꾸지 않는다.

```sh
bash design/fire_tower_concepts/runic_3d/migration/build_android.sh
```

산출물은 `build/apk-preview/rune-nexus-runic-fire-arm64.apk`다. 기존 별도 검수 패키지 `com.example.rune_nexus.godotpreview`에 설치하며 일반 앱은 유지한다. ARM64 release이고 외부 배포는 하지 않는다.

고정/드론 시점, 정지, 실제 연속 발사 1배속/4배속과 화면 복귀를 확인한다. 에뮬레이터 결과는 실기기 성능 측정이나 본게임 HUD·건설 입력 검증을 대신하지 않는다.

## 2026-09-14 검수 결과

Android 17 ARM64 에뮬레이터에서 최종 원본과 같은 PCK를 사용하는 검수 앱과 `lib/main.dart` 본게임 release APK를 확인했다. 본게임의 기존 스테이지 1·8라운드 저장을 `install -r`로 보존하여 이어서 진입했고, 화염 포탑 선택·빈 타일 미리보기·80G 설치·실제 사격·피해 표시·고정/드론 시점을 확인했다. 정상 전투로 9라운드까지 진행한 후 스테이지 메뉴에서 멈췄다. 데이터 초기화·외부 배포는 하지 않았다.

- [본게임 화구·탄체·피해 표시](android/main-drone-4x.png)
- [본게임 건설 미리보기](android/main-build-preview.png)
- [본게임 영상](android/runic-fire-main.mp4) — 약 33초
- [6문 검수 앱 영상](android/runic-fire-android.mp4) — 약 23초
- [검사 기록](android/validation.json) · [APK 비교](android/apk-audit.json) · [팩 감사](android/pack-audit.json)

영상은 에뮬레이터 녹화 특성상 약 4.6~8.5fps로 저장되어 끊겨 보일 수 있다. 실제 게임 렌더 속도나 실기기 성능의 측정값이 아니다. 검수 구간의 Godot 스크립트 오류와 앱 크래시는 없었다.

본게임 로컬 검수 빌드:

```sh
ORG_GRADLE_PROJECT_runeNexusGodotPreview=false WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter build apk --release --target-platform=android-arm64 --split-per-abi --target=lib/main.dart --dart-define=RUNE_NEXUS_DEBUG_PANEL=true --no-tree-shake-icons
```

공개 6024 APK는 ABI 3종이고 이번 로컬 검수 APK는 ARM64만 포함하므로 총 크기 감소를 자산 최적화 성과로 해석하지 않는다. 같은 ARM64 엔진·Flutter 코드와 PCK 항목을 나눠 비교했다. 디자인 원본·Blender 파일과 검수 스크립트는 최종 팩에 포함하지 않는다.
