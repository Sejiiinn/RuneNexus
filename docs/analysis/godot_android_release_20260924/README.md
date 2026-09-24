# Godot 단독 Android 전환 검증

역할: 2026-09-24 전환 구현의 검증 근거와 한계. 기준은 `1ac84a53b1790226e4644841fe7cb99c59f7cc26` 위의 작업 트리이며 커밋·공개 배포하지 않았다. 사용자 기존 변경을 보존했다. 상태 원본은 [이관 로드맵](../../godot_unified_app_roadmap.md), 배포 선행 조건은 [배포 상태](../../deployment_status.md)다.

## 범위

Godot 기본 앱 진입, 계정/온라인 저장/경제 서비스, Kotlin OS 어댑터, Flutter 제거, Android 패키징과 CI. 서버·DB·게임 수치·승인 디자인은 변경하지 않는다. 웹 배포는 사용자 결정으로 제외한다.

## 확인한 근거

| 구분 | 결과 | 근거 |
| --- | --- | --- |
| Python 빌드·팩·APK·manifest 검사 | 40개 통과 | python.log (`python.log`, 로컬 검증 파일) |
| Godot 전투·저장·HUD·로비·경제·업데이트 회귀 | 25개 통과 | native.log (`native.log`, 로컬 검증 파일) |
| 계정 서비스 | 격리 저장 및 localhost HTTPRequest 검사 통과 | `scripts/verify_godot_account_services.py` |
| 경제 서비스 | exact replay·snapshot revision·저장 실패·426·계정 교체 검사 통과 | `godot/verify_economy_service.gd` |
| 업데이트 | 독립 검사 통과: patch fallback·설치 실패 재다운로드·권한 후 재설치·필수 gate | `godot/verify_update_service.gd` |
| 실제 앱 수명주기 | 격리된 실제 main scene 자동 검사 통과 | lifecycle.log (`lifecycle.log`, 로컬 검증 파일) |
| Kotlin | production Kotlin 컴파일 및 delta 18개 검사 통과 | `android-godot-only/`, `scripts/run_apk_delta_kotlin_tests.py` |

검증 중 발견한 결함은 현재 버전 426에서 미지급 런 제거, 필수 모달 재표시 중 누적, 설치 캐시 손상 후 영구 재시도 실패였다. 수정 후 해당 조건을 다시 확인했다. 계정 bootstrap 순서·자동 rebase 재로드·오프라인 로그아웃 및 업데이트 gate의 앱 통합은 별도 통합 검사로 확인한다.

## 최종 앱·패키지 확인

기본 앱/fixture/session/script 진입을 별도 임시 프로젝트에서 독립 실행해 Flutter bridge 없이 정상 분기하는 것을 확인했다(default (`default.log`, 로컬 검증 파일), fixture (`fixture.log`, 로컬 검증 파일), session (`session.log`, 로컬 검증 파일), script (`script.log`, 로컬 검증 파일)). 계정·앱 통합 runner도 별도 검증자가 실행해 통과했다([독립 검증 기록](independent-review.json)). 필수 업데이트 이전 로컬/보안 저장/API 접근이 없고 선택 업데이트 건너뛰기 뒤 한 번 초기화하는 조건을 포함한다.

실제 데스크톱 Godot Mobile/Metal 앱의 로비 (`screenshots/lobby.png`, 로컬 검증 파일), 계정 (`screenshots/account.png`, 로컬 검증 파일), 게스트 우편 (`screenshots/mail-guest.png`, 로컬 검증 파일), 연구 (`screenshots/research.png`, 로컬 검증 파일), 전투 (`screenshots/battle.png`, 로컬 검증 파일)를 구현 담당과 독립 검증자가 직접 검토했다. 보이는 범위에서 잘림·가림·모달 중첩이 없다. 운영 설정 미포함으로 Google 연결 비활성 안내가 표시되는 검수 실행이다.

productionRelease와 inspectionDebug 빌드를 완료했다. production 패키지 ID·3개 ABI·debuggable=false 및 Flutter 파일/DEX 참조 0을 확인했다. 로컬 production APK는 versionCode 1의 구조 검증 산출물이며 **서명되지 않았고 운영 설정이 없어 배포용이 아니다**. 실제 릴리스에는 기존 설치본보다 큰 버전 코드와 기존 서명키가 필요하다. [APK 검사](apk-audit.json), [PCK 검사](pck-audit.json), [manifest 정보](apk-badging.txt)가 근거다.

보관된 공개 6028 APK(431,317,704 bytes, 기존 기록과 SHA-256 일치) 대비 새 unsigned APK는 372,088,818 bytes로 59,228,886 bytes(13.73%) 작다. Flutter native 60,287,340 bytes와 종전 자산 등 기타 엔트리 36,411,612 bytes가 감소했고, Godot 앱/UI를 포함한 PCK는 37,933,764 bytes 증가했다. PCK는 143,889,096 bytes·871항목이며 완전 중복은 0이다. 이 수치는 최종 서명·운영 설정 APK의 실제 크기를 대신하지 않는다.

Android API 37 읽기 전용 에뮬레이터의 검사 패키지에서 설치·플러그인 등록·포탑 배치·웨이브·뒤로가기·HOME 복귀·force-stop 후 저장 복원을 확인했다. [에뮬레이터 기록](emulator/README.md)과 복원 화면 (`emulator/restored-battle.png`, 로컬 검증 파일)을 참조한다. 새 차단 결함·스크립트 오류·크래시는 없었다. 시작 시 UID 경로 대체와 XR 설정 경고는 기록에 보존했다. 검증 후 에뮬레이터를 종료했으며 원본 AVD는 보존했다.

## 환경과 격리

Godot 4.7.2, macOS, JDK 17, 기존 Android SDK를 사용한다. 서비스 검사는 임시 디렉터리와 loopback 서버를 사용하고 운영 API·토큰·사용자 저장 원문을 읽지 않는다. 실제 화면 검증용 프로젝트는 `build/godot/release-validation`, 사용자 디렉터리는 `RuneNexus-ReleaseValidation-20260924-final`로 분리했다. 사용자가 열어 둔 `build/godot/editor`의 실행을 중지하거나 변경하지 않는다.

## 남은 최종 조건

현재 로컬 release 서명키와 운영 API/Google 설정이 없으며 연결된 Android 실기기가 없다. 검사 전용 에뮬레이터 결과는 실제 기기와 구분한다. 기존 공개 앱 위로 서명 일치 업데이트, 실제 Google 로그인·다른 계정·클라우드 저장, Android 터치/뒤로가기/백그라운드 복귀, 설치 권한과 실제 업데이터, 모바일 GPU·최종 화면은 미확인이다. 데스크톱 또는 fake 플랫폼 테스트로 이를 통과 처리하지 않는다.

실제 공개 배포는 수행하지 않았다. 최종 서명 APK와 실기기 조건이 해소되기 전에는 전체 배포 준비 완료로 판정하지 않는다.
