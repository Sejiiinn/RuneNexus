# Godot Android 호스트

Flutter 없이 공용 `rune_nexus.pck`를 실행한다. `productionRelease`는 기존 앱 ID `com.example.rune_nexus`, 기존 배포 서명 환경변수, `VERSION_CODE`·`VERSION_NAME`, `armeabi-v7a`·`arm64-v8a`·`x86_64` ABI를 사용한다. 릴리스는 `debuggable=false`다. 키 없이 만든 로컬 production APK는 미서명이며 설치·배포 후보가 아니다. 배포에서는 `RUNE_NEXUS_REQUIRE_RELEASE_SIGNING=true`로 키 누락 시 실패시킨다.

`inspectionDebug`는 앱 ID `com.example.rune_nexus.godotonly`, 디버그 서명, arm64 ABI를 사용한다. 기존 사용자 앱과 저장소에서 분리된 기기 검수용이다. 두 variant 모두 같은 Godot 프로젝트 팩을 실행한다.

Godot Android singleton 이름은 `RuneNexusPlatform`이다. 결과 JSON은 `{ok:true,...}` 또는 `{ok:false,error:code}` 형태다.

Godot 4.7.2의 Android `JNISingleton`은 `@UsedByGodot` 메서드를 직접 호출하거나 `call()`로 실행할 수 있지만, `Object.has_method()`는 해당 동적 메서드에 `false`를 반환한다. 아래 필수 API의 호출 가능 여부를 그 결과로 차단하지 않는다. 선택적 테스트 어댑터에도 같은 우회를 적용하지 않도록 `Engine.get_singleton("RuneNexusPlatform")`과 객체가 같은지 확인한다. GDScript 모의 객체만으로 이 경계를 검증하지 않고 Android에서 실제 암호화 저장 호출과 계정 서비스 연결을 확인한다.

| 메서드 | 결과 |
| --- | --- |
| `application_support_path()` | 기존 Flutter path_provider Android의 `filesDir` 절대 경로 |
| `sp_to_logical(logical_size)` | Android 비선형 SP 변환을 적용한 Godot 논리 DP 크기 |
| `legacy_save_path()` | 기존 v1 임시 저장 파일 경로 |
| `device_preferences()` | 기존 `graphics_settings_v1.json` 원문을 `value`로 가진 결과 JSON |
| `session_read()` | 암호화 세션 문자열 또는 null을 `value`로 가진 결과 JSON |
| `session_write(value)`, `session_delete()` | 결과 JSON |
| `installed_version()` | `value:{versionCode,versionName,packageName,apkSha256}` 결과 JSON |
| `query_installed_version()` | APK 해시를 작업 스레드에서 계산해 `installed_version_ready(result_json)` 신호로 전달 |
| `sign_in_google(client_id)`, `sign_out_google()` | 비동기 작업 시작 여부 bool |
| `download_update(url,sha256,size_bytes,version_code)` | 비동기 전체 APK 다운로드 시작 여부 bool |
| `download_patch(url,sha256,size_bytes,version_code,base_sha256,target_sha256,target_size_bytes)` | 비동기 패치 다운로드 시작 여부 bool |
| `install_update(version_code)` | 설치 권한 화면 또는 Android 설치기 열기 시작 여부 bool |
| `open_app_settings()` | 앱 설정 화면 열기 |

비동기 결과는 `google_sign_in_completed(result_json)`, `google_sign_out_completed(result_json)`, `update_completed(operation,result_json)` 신호로 전달한다. Google 로그인 성공 JSON에는 `idToken`이 있다. 업데이트 설치 성공의 `value`는 `permissionRequired` 또는 `installerOpened`다. 패치 실패 `error=update_patch_failed` 시 전체 APK로 재시도할 수 있다. APK는 SHA-256, 크기, 버전, 패키지 이름, 현재 앱 서명과 대조한 뒤 설치기로 보낸다.

세션 파일 `noBackupFilesDir/auth_session.enc` 및 Android Keystore 별칭 `rune_nexus_session_v1`, APK 패치 형식 `RNDELTA1`은 기존 호스트와 동일하다. 사용자 데이터 읽기·쓰기·삭제는 Godot 앱 요청으로만 수행한다.
