# Android APK 직접 배포

앱이 GitHub Releases의 업데이트 정보를 확인하고 새 APK 설치를 안내하는 테스트 배포 방식입니다. 게임 클라이언트는 Android 앱에서 실행하며 GitHub Pages 배포와 별개입니다. APK 설치에는 Android의 사용자 확인이 필요합니다.

앱을 새로 시작할 때 업데이트를 확인합니다. 단순히 백그라운드에서 돌아오는 경우마다 확인하지는 않습니다. 오프라인이거나 업데이트 정보 조회가 실패해도 현재 설치된 앱으로 계속 플레이할 수 있습니다.

GitHub Pages는 main push 자동 배포를 중단하고 수동 실행을 복구 경로로 남깁니다. 기존 페이지 자체를 삭제하거나 기존 브라우저 저장을 변경하지 않습니다.

## 최초 준비

- 앱 업데이트 기능이 없는 기존 설치에는 이 기능을 포함한 APK를 한 번 직접 전달합니다.
- **기존 설치와 동일한 패키지명·서명 키**를 유지해야 앱 데이터가 유지되는 업데이트가 가능합니다. 현재 패키지는 `com.example.rune_nexus`이며 변경하지 않습니다.
- 과거 APK가 디버그 키로 서명됐다면 그 APK를 만든 환경의 **동일한 디버그 키**가 필요합니다. 다른 컴퓨터에서 만든 디버그 키나 새로 만든 배포 키로 바꾸면 기존 설치를 업데이트할 수 없습니다. 먼저 기존 APK의 서명 인증서와 보관한 키를 대조하세요. 키를 잃어버렸다면 데이터 이관을 별도로 설계해야 하며 설치 삭제를 해결책으로 사용하지 않습니다.
- Google Cloud의 Android OAuth 클라이언트에 현재 패키지명과 **실제 배포 서명 인증서의 SHA-1**을 등록합니다. 기존 `GOOGLE_WEB_CLIENT_ID`는 서버용 웹 클라이언트 ID로 계속 사용합니다.
- 익명 다운로드가 가능한 공개 GitHub Releases가 필요합니다. 앱에 GitHub 접근 토큰을 넣지 않습니다.

GitHub 저장소의 Actions secrets:

| 이름 | 값 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 기존 서명 키스토어의 줄바꿈 없는 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 키스토어 비밀번호 |
| `ANDROID_KEY_ALIAS` | 기존 키 별칭 |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호 |

Actions variables:

| 이름 | 값 |
| --- | --- |
| `GOOGLE_WEB_CLIENT_ID` | Google 서버용 웹 클라이언트 ID |
| `RUNE_NEXUS_API_BASE_URL` | 앱에서 접근할 HTTPS API 주소 |

키스토어와 비밀번호를 저장소에 커밋하지 않습니다. CI는 네 가지 서명 설정 중 하나라도 없으면 배포를 중단합니다. 로컬 개발 빌드는 별도 설정이 없을 때 기존 디버그 서명을 사용합니다.

현재 테스트 배포는 기존 Mac의 `~/.android/debug.keystore`를 사용합니다. 이 키를 위 네 가지 Actions secrets에 등록했으며, CI에서도 새 디버그 키를 생성하지 않고 같은 키로 서명합니다. 이 키스토어는 별도로 보관하고 재생성하지 않습니다.

## 배포 실행

1. GitHub Actions에서 **Deploy Android APK**를 수동 실행합니다.
2. `version_code`에 기존에 설치·배포한 모든 APK보다 큰 정수를 입력합니다. 예를 들어 설치된 APK가 `1`이면 첫 배포는 `2`, 다음은 `3`입니다. 수동 빌드에서 더 큰 값을 사용했다면 그보다 크게 입력합니다. 최댓값은 `2100000000`입니다.
3. `version_name`에 `x.y.z` 형식 사용자 표시 버전(예: `0.2.0`), `notes`에 업데이트 안내를 입력합니다. 변경 항목은 한 줄에 하나씩 작성하며 `- ` 글머리표를 사용할 수 있습니다. 앱은 기존 한 문단 안내도 문장 단위로 나누어 표시하고, 긴 노트는 안내 영역 안에서 스크롤합니다.
4. 분석·테스트·서명 APK 빌드가 통과하면 최근 공개된 최대 3개 APK에서 새 버전으로의 차등 패치를 생성·복원 검증합니다. 패치가 전체 APK의 90% 이상이면 해당 패치는 생략합니다. 첫 배포는 전체 APK만 제공합니다.
5. `apk-<version_code>` 초안 릴리스에 전체 APK·유효한 차등 패치·`update.json`을 모두 올린 뒤 공개하고 최신 릴리스로 지정합니다.
6. 첫 설치에는 릴리스의 `rune-nexus.apk`를 전달합니다. 이후에는 앱이 업데이트를 확인합니다.

버전 코드는 워크플로 실행 횟수 대신 명시적으로 관리합니다. 다른 방식으로 만든 기존 APK의 버전도 넘어야 하고, 재실행이나 워크플로 교체가 버전 충돌을 일으키지 않도록 하기 위함입니다. CI는 초안을 포함한 기존 APK 릴리스보다 작거나 같은 번호를 거부합니다. 업로드 실패로 초안이 남으면 이를 확인하고 다음 번호로 재배포하세요. 공개한 APK 파일·태그를 덮어쓰지 않습니다.

업데이트 정보 주소:

```text
https://github.com/Sejiiinn/RuneNexus/releases/latest/download/update.json
```

APK는 `releases/download/apk-<version_code>/rune-nexus.apk`처럼 버전별 주소를 사용합니다. 다운로드 중 최신 릴리스가 바뀌어도 해당 메타데이터와 같은 APK를 받습니다. 다른 종류의 릴리스를 최신 릴리스로 지정하면 위 업데이트 주소가 깨질 수 있으므로 APK 배포 릴리스만 최신으로 지정합니다.

## 차등 업데이트

새 APK 전체를 매번 내려받는 대신, 현재 설치 버전과 일치하는 패치가 있으면 변경된 부분을 받아 앱 내부에서 새 APK를 복원합니다. 기준 파일은 Android가 제공하는 현재 설치 APK의 `sourceDir`입니다. 예전 다운로드 파일을 사용하거나 브라우저로 넘기지 않습니다.

앱은 설치 버전과 APK SHA-256이 패치의 기준과 일치하는지 확인하고, 패치 다운로드·복원 뒤 최종 APK의 크기와 SHA-256도 확인합니다. 맞는 패치가 없거나 기준 버전·해시가 다르거나 패치 다운로드·복원 검증이 실패하면 전체 APK 다운로드로 전환합니다. 전체 APK 검증까지 실패한 경우에는 설치하지 않습니다. 차등 패치에서도 설치 전 Android의 사용자 확인은 필요합니다.

배포 파이프라인은 GitHub 릴리스를 버전 코드 내림차순으로 정렬해 공개된 최근 3개 `apk-*` 릴리스를 기준으로 선택합니다. 각 릴리스의 태그·메타데이터·실제 APK 크기·해시·서명 인증서를 확인합니다. 기준 데이터가 잘못되거나 서명이 바뀌면 조용히 생략하지 않고 배포를 중단합니다. 생성한 패치를 직접 적용해 이번에 빌드한 서명 APK와 동일한 바이트가 복원되는지도 검증합니다.

`update.json`은 `schemaVersion: 1`을 유지하며 차등 업데이트를 제공할 때만 최대 3개의 `patches` 항목을 추가합니다. 기존 앱은 전체 APK 정보를 계속 사용할 수 있습니다.

```json
{
  "format": "rune-apk-delta-v1",
  "fromVersionCode": 1,
  "fromSha256": "<기준 APK의 SHA-256>",
  "url": "https://github.com/Sejiiinn/RuneNexus/releases/download/apk-2/patch-from-1.rndelta",
  "sha256": "<패치 파일의 SHA-256>",
  "sizeBytes": 12345
}
```

## 로컬 빌드

로컬 빌드에서도 업데이트 확인을 사용하려면 다음 Dart define을 전달합니다. CI 배포는 자동으로 포함합니다.

```text
--dart-define=RUNE_NEXUS_UPDATE_MANIFEST_URL=https://github.com/Sejiiinn/RuneNexus/releases/latest/download/update.json
```

로컬 APK에도 배포 시와 동일한 API 주소·Google 클라이언트 ID를 전달하고, 실제 배포 APK와 같은 서명 키를 사용해야 후속 설치 업데이트가 가능합니다.

## 메타데이터와 검증

`scripts/create_apk_update_manifest.py`가 실제 APK 바이트의 SHA-256과 크기를 계산해 다음 계약의 JSON을 생성합니다. APK는 최대 512 MiB, JSON 파일은 줄바꿈을 포함해 UTF-8 기준 최대 64 KiB이며 앱의 수신 한도와 일치합니다.

```json
{
  "schemaVersion": 1,
  "versionCode": 2,
  "versionName": "0.2.0",
  "packageName": "com.example.rune_nexus",
  "apkUrl": "https://github.com/Sejiiinn/RuneNexus/releases/download/apk-2/rune-nexus.apk",
  "sha256": "<64자리 소문자 SHA-256>",
  "sizeBytes": 123456,
  "notes": "업데이트 안내"
}
```

실제 기기에서 첫 APK 설치 → 더 큰 버전 릴리스 → 앱 재실행 → 차등 다운로드·복원 → 설치 허용 및 설치 확인 → 기존 저장 유지 순서로 검증합니다. 지원하지 않는 이전 버전과 패치 실패 시 전체 APK 다운로드로 전환되는지도 확인합니다. 설치 권한을 거부하거나 설치를 취소했을 때 기존 앱을 계속 사용할 수 있는지도 확인합니다.

Google Play 전환 시 패키지명과 앱 서명 연속성을 먼저 결정해야 합니다. 현재 디버그 키 테스트 설치를 정식 배포 키로 곧바로 덮어쓸 수 있다고 가정하지 않습니다. Play 인앱 업데이트와 현재 직접 APK 설치 경로의 전환은 정식 배포 시 별도 작업입니다.

참고: [Android 앱 서명](https://developer.android.com/studio/publish/app-signing), [버전 코드 규칙](https://developer.android.com/studio/publish/versioning), [GitHub 릴리스 생성](https://cli.github.com/manual/gh_release_create).
