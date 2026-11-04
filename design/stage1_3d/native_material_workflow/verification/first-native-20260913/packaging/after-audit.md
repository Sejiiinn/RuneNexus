# 첫 내장 재질 실험 패키징·비용 감사

공용 런타임은 내장 코어 후보를 채택하지 않았다. 최종 공용 PCK의 136개 리소스 경로와 내용은 실험 직전 PCK와 동일하며, 이번 실험으로 shipping 런타임에 추가된 재질·텍스처·코드 payload는 **0바이트**다. 검수 하네스는 별도 실험 APK/PCK에만 있다.

## PCK 확인

| 비교 | 크기 차이 | 실제 리소스 내용 |
| --- | ---: | --- |
| 직전 PCK → 현재 공용 PCK | 0 B | 파일 전체 SHA-256까지 동일 |
| 직전 PCK → 본게임 ARM64 APK 내장 팩 | 0 B | 파일 전체 SHA-256까지 동일 |
| 직전 PCK → 본게임 universal APK 내장 팩 | 0 B | 136개 payload 모두 동일, 두 항목 저장 위치만 변경 |
| 직전 PCK → 격리 실험 팩 | +31,524 B | 검수 진입/검증 스크립트 및 scene·UID 메타데이터 추가 |

공용 PCK: **58,453,692 B**, SHA-256 `b3f9a0c0c73d4e405b8f3ea12496c46663deb0f16305c3f67eea5fdd6250f5b0`.

PCK v4 header의 data base와 directory offset을 읽고 모든 entry의 범위와 디렉터리 MD5를 실제 payload에서 검증했다. 경로별 SHA-256도 비교했다. universal의 파일 SHA 차이는 `assets/cannon_field.bin`(44,172,704 → 44,278,416)과 `engine_licenses.txt`(58,328,480 → 44,172,704) 저장 위치 교환 때문이다. 내용 변경·누락·추가가 아니다.

최종 shipping 팩에 `verify_*`, MCP, `.tres`, `materials/`, `core_glass`, `native_material` 경로가 없다. 기존 core shader·portal·foliage·3D projectile 리소스는 직전 payload와 동일하다. 미채택 프리셋을 공용 팩에 남기지 않았다.

격리 실험 팩은 `native_experiment_entry`와 필요한 `verify_environment`, `verify_machinegun`, `verify_native_materials`, `verify_projectiles`를 포함한다. 격리 APK 안의 팩은 `build/godot/native-material-experiment.pck`와 바이트 단위로 동일하다.

## APK 크기와 비교 조건

| APK | 실제 바이트 | 조건 |
| --- | ---: | --- |
| 보존된 이전 본게임 universal | 374,337,758 | 오래된 PCK; x86_64/armeabi Flutter 앱 라이브러리 없음 |
| 이전 core-v6 검수 ARM64 | 230,840,613 | 최신 직전 PCK; 별도 검수 앱 |
| 첫 본게임 universal 빌드 | 426,119,640 | 3 ABI Flutter 앱 라이브러리; 현재 공용 payload |
| 본게임 ARM64 | 234,772,965 | 일반 lib/main.dart 진입; 입력 build-number 4003 / 실제 versionCode 6003 |
| 격리 내장 재질 실험 ARM64 | 230,922,722 | 기존 검수 APK + 검수 PCK; 재서명 |

이전 universal 대비 첫 universal의 **+51,781,882 B**는 동일 기준 전후 실험 비용이 아니다. 이전 파일에도 ABI 폴더는 세 개 있었지만 x86_64/armeabi-v7a의 `libflutter.so`/`libapp.so`가 없었다.

| universal 증가 원인 | 바이트 |
| --- | ---: |
| 추가 x86_64 libflutter | 13,051,424 |
| 추가 x86_64 libapp | 8,651,656 |
| 추가 armeabi-v7a libflutter | 8,615,900 |
| 추가 armeabi-v7a libapp | 9,454,152 |
| 오래된 PCK → 현재 PCK | 11,968,484 |
| AndroidManifest 압축 차이 | -3 |
| ZIP 정렬·서명·메타데이터 | 40,269 |

오래된 PCK 증가 +11,968,484 B는 텍스처 포맷/기존 자산 차이 +10,663,544 B, 기존 dressing·landmarks scene +1,291,418 B, 기타 리소스 +12,350 B, 패키지 정렬/디렉터리 +1,172 B다. `.ctex`에서 `.etc2.ctex`로 바뀐 텍스처 경로를 포함한다. 이 변경들은 실험 시작 전 58,453,692 B 팩에 이미 들어 있으므로 이번 내장 재질 실험 비용으로 보고하지 않는다.

이전 core-v6 검수 ARM64와 본게임 ARM64의 차이는 앱 진입점 비교다. 주된 ZIP payload 증가는 본게임 `libapp.so` +3,866,624 B와 `classes.dex` +65,903 B다. 같은 ARM64·같은 PCK라는 사실만으로 같은 앱 비용의 전후 측정이라고 보지 않는다.

격리 실험 APK는 이전 core-v6 대비 **+82,109 B**다. 실험 팩 자체는 **+31,524 B**이며 나머지는 재서명의 `META-INF/ANDROIDD.SF`, `MANIFEST.MF`, `ANDROIDD.RSA`(압축 합 +51,648 B)와 ZIP/리소스 메타데이터 차이다. 네이티브 엔진·Flutter 라이브러리·텍스처 확대가 아니다.

## 무결성과 제한

본게임 universal·ARM64 및 격리 실험 APK에 Android Build Tools 35.0.1 `apksigner verify --verbose --print-certs`와 `zipalign -c -P 16 4`가 통과했다. 본게임은 APK Signature Scheme v2, Android Debug 인증서 SHA-256 `f27afe6b6b1064e97a841ef915ee8a8ce4d2f7b5abb67e6481cf7f16c4644766`다. 공개 배포/배포 서명 작업은 수행하지 않았다.

실기기 p95/p99·발열 후 성능과 공개 배포 호환성은 이 패키징 감사로 검증하지 않는다. 이 결과는 실제 모바일 시각 판정을 대신하지 않는다.

정확한 파일 경로·APK/PCK SHA·서명/정렬 명령 출력·ZIP 항목 증감은 [after-audit.json](after-audit.json), 각 팩의 경로·오프셋·payload 해시는 `pck-*-directory.json`에 있다.

최종 전달본: `build/apk-main/rune-nexus-native-material-review-arm64.apk`, SHA-256 `f5b3d635ce9fb2a2c432eb5eb94891d9bbaa5805125d2bddcd732aee00114263`. 기존 설치 versionCode 4002에 데이터 삭제·강제 다운그레이드 없이 덮어 설치하기 위해 `--build-number=4003`으로 빌드했으며, `aapt2 dump badging`에서 실제 versionCode **6003**을 확인했다. Flutter의 ARM64 split ABI 오프셋 +2000이 적용되므로 입력 build-number와 구분한다. 최종 전달본의 서명·16KB 정렬과 직전 PCK 바이트 동일성도 재확인했다.
