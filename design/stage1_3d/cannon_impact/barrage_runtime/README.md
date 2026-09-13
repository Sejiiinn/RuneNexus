# 대포 다중 사격 — 실제 3D 전투 검수

> 역사 기록: 2026-09-13 ThreeJS 실행 경로를 제거했다. `main.dart`는 `main.dart.txt`로 보존하며 아래 실행 명령은 현재 사용할 수 없다. 현행 검수는 저장소의 `docs/stage1_3d_preview.md`를 따른다.

2026-09-11. **Android APK로 검수한다. 웹 렌더와 브라우저 검수는 더 이상 사용하지 않는다.** 앱을 실행하면 별도 조작 없이 시작한다.

- 대포 6문, 체력 10억의 정지 표적 3기. `RuneNexusGame.debugShowCannonBarrage()`의 실제 조준·발사·피해 판정을 사용한다.
- 단일 폭발 검수와 동일한 `Stage1Scene`에 실제 전투 프레임을 전달한다. Flame은 전투를 갱신하고 화면은 3D 지형·포탑·적·탄환·필드 캐시 폭발로만 표시한다.
- 고정/드론 시점, 1·2·4배속, 일시 정지, 재배치, 확대를 제공한다. 표적별 실제 남은 체력을 표시한다.
- 저장은 메모리와 Noop 온라인 저장소로 격리한다. 기본 적 데이터나 저장 형식은 변경하지 않는다.

## 별도 설치용 APK

저장소 루트에서 실행한다. macOS 기준:

```sh
ORG_GRADLE_PROJECT_runeNexus3dPreview=true WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter build apk --release --target-platform=android-arm64 --target=design/stage1_3d/cannon_impact/barrage_runtime/main.dart --dart-define=RUNE_NEXUS_DEBUG_PANEL=true --no-tree-shake-icons
```

출력은 `build/app/outputs/flutter-apk/app-release.apk`이며 전달본은 `build/apk-preview/rune-nexus-3d-cannon-arm64.apk`로 보관한다. 다른 빌드가 기본 출력 파일을 덮어쓸 수 있으므로 전달에는 이름을 구분한 복사본을 사용한다.

- 설치 이름: **Rune Nexus 3D 테스트**
- 패키지: `com.example.rune_nexus.preview3d`
- 기존 앱 `com.example.rune_nexus`와 동시 설치 가능. 앱 데이터와 FileProvider 권한도 패키지별로 분리한다.
- ARM64 Android용 릴리스 최적화 빌드. 로컬 검수 서명을 사용하며 기존 정식 APK의 업데이트 파일로 배포하지 않는다.
- 위 Gradle 속성을 생략한 일반 빌드의 패키지와 앱 이름은 기존 값을 유지한다.

위 디버그 정의는 이 로컬 검수 빌드에만 적용하며 배포 빌드에는 사용하지 않는다. 모바일 실기기 성능 측정은 별도다.

## APK 검증

2026-09-11: ARM64 릴리스 APK 빌드와 v2 서명 검증 통과. 최종 Manifest에서 별도 패키지·앱 이름·FileProvider authority를 확인했고, APK에 내장된 지형 GLB와 폭발 필드 캐시의 SHA-256이 원본과 일치한다. 검증 내역은 `build/apk-preview/verification.json`에 둔다. 연결된 Android 기기가 없어 실제 설치·화면·성능은 아직 확인하지 못했다.
