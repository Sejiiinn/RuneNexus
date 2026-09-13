# RuneNexus 작업 기준

- 현재 구조에 맞춰 요청한 결과를 완성한다. 필요한 국소 구조 정리는 가능하며, 저장 호환성·API 계약·합의한 책임 경계를 보존한다. 요청에 포함되지 않은 데이터 손실, 호환성 파괴, 대규모 구조·제품 변경은 해당 변경 전에 확인한다.
- 문서가 필요하면 [작업별 지도](docs/README.md)에서 관련 기준과 필요한 절을 고른다. 제안·역사 기록을 현행 요구로 사용하지 않는다. 기능·디자인·배포 조건을 바꾸면 같은 지도의 갱신 규칙을 따른다.

## UI·시각 에셋

- UI·레이아웃·시각 에셋 변경에는 [DESIGNS.md](DESIGNS.md)의 공통 방향과 해당 화면 기준을 적용한다. 작은 화면에서도 문구·아이콘·수치·주요 액션의 의미를 유지하고 간격·스케일·줄바꿈·스크롤로 수용한다.
- 승인 시안의 핵심 형태·색·재질 표현을 구현 편의나 속도를 이유로 임의 대체하지 않는다. 기법 변경 승인은 외형 변경 승인이 아니다. [시안 보존과 채택 기준](DESIGNS.md#승인-시안-보존과-채택)에 따라 실제 결과를 직접 보고 판정하며, 시각적으로 실패한 결과를 채택하거나 완료로 보고하지 않는다.
- 3D 원본·애니메이션·프레임 렌더는 Blender MCP를 우선한다. 그 경로에서 필요한 2D 보정·알파·크롭·패킹은 GIMP MCP를 사용한다. 3D 원본이나 프레임별 제어가 필요 없는 일반 2D 생성·편집은 ImageGen을 사용하며, 사용자가 지정한 도구와 편집 가능한 원본을 우선한다.
- 제작 원본·중간 산출물은 `design/`, 게임용 최종 이미지는 `assets/images/`에 두고 기존 로딩 경로에 연결한다. 크기·프레임·투명 배경·형식은 실제 사용처에 맞추고, 움직이는 에셋은 순서·여백·루프·게임 크기를 확인한다.
- 이미지 에셋을 임시 Flutter Canvas 도형으로 대체하지 않는다. 게임 상태에 반응하는 가벼운 보조 표현만 인게임 렌더링으로 구현한다.

## 전투·배포

- 데미지 계산식·저항·취약·피해 배율·포탑 스탯 보정 변경은 [데미지 계층 규칙](docs/damage_calculation_rules.md)을 따른다.
- 엔진·네이티브 의존성·대용량 에셋 변경과 APK 배포에는 [APK 용량 점검](docs/android_apk_distribution.md#용량-점검)을 적용한다. 배포 전 이전 공개 APK 대비 실제 크기·증가 원인·불필요한 포함 항목을 확인한다.
- 배포 옵션·환경값은 `.github/workflows/deploy-pages.yml`, `.github/workflows/deploy-apk.yml`이 기준이다.

## Flutter 공통 검증

저장소 루트에서 변경 영향에 맞는 명령을 선택한다. macOS의 `dart`·`flutter`는 각각 `scripts/in_app_server_macos.sh dart`·`scripts/in_app_server_macos.sh flutter`로 실행한다. Windows 실행은 [Windows 가이드](.agents/windows_flutter_guide.md)를 따른다.

| 목적 | 명령 |
| --- | --- |
| 수정 Dart 파일 포맷 | `dart format <수정 파일>` |
| Dart 코드·분석 설정 변경 | `flutter analyze` |
| 변경 동작 검증 | `flutter test <관련 파일 또는 디렉터리>` |
| 넓은 공통 로직·CI 검증 | `flutter test` |
| 웹 빌드·에셋 호환성 확인 | `flutter build web --pwa-strategy=none --no-tree-shake-icons` |

UI·게임플레이·렌더링은 [인앱 검증](.agents/in_app_test_guide.md)에서 해당 플랫폼 경로를 선택한다. 검증 범위·완료 기준·화면 제공은 [DESIGNS.md](DESIGNS.md#검증과-완료-기준--완벽한-복제보다-요청-충족)를 따른다. 문서만 수정하면 링크·내용·diff를 확인하며 Flutter 검사·빌드는 필요 없다.

## 커밋

커밋 메시지는 한글로 작성하고 `feat:`, `fix:`, `refactor:`, `chore:`를 사용한다. 의도한 변경만 스테이징하며, 요청 밖의 플랫폼 generated plugin 파일·자동 줄바꿈 변경은 제외한다. 커밋·푸시는 요청이나 기존 승인 범위에 있을 때 수행한다.
