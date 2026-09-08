# In-App Test Guide

## 적용 환경

- 이 문서는 Windows와 macOS의 공통 인앱 검증 진입점입니다.
- Windows에서는 `.agents/windows_flutter_guide.md`의 실행 규칙을 함께 적용하세요. macOS에서는 아래의 macOS 스크립트 경로를 사용하세요.
- 서버 실행 권한은 현재 세션 정책과 `.agents/sandbox_command_guide.md`를 따르세요.

## 기본 순서

1. 53000 포트 서버 상태를 먼저 확인합니다.
2. HTTP 200이면 재기동보다 cache-bust URL 갱신을 우선합니다.
3. 개발 서버 세션이 살아 있으면 hot reload 후 인앱 브라우저 새로고침을 우선합니다.
4. 오래된 정적 번들이 의심되거나 빌드 산출물 갱신이 필요할 때만 `restart`로 전체 웹 빌드를 갱신합니다.

## 서버 경로

저장소 루트에서 아래 명령을 사용합니다. `dev`·`restart`는 서버를 시작하거나 교체하므로 먼저 `status`로 기존 서버를 확인하세요.

| 목적 | macOS | Windows |
| --- | --- | --- |
| 기존 서버 확인 | `scripts/in_app_server_macos.sh status` | `scripts/in_app_server.ps1 -Action status` |
| 개발 서버 기동 | `scripts/in_app_server_macos.sh dev` | `scripts/in_app_server.ps1 -Action dev` |
| 필요한 경우 전체 빌드·재기동 | `scripts/in_app_server_macos.sh restart` | `scripts/in_app_server.ps1 -Action restart` |

macOS 스크립트의 작업 경로가 현재 checkout과 다르면 `WORK_DIR="$PWD"`로 해당 호출의 경로를 지정하세요. SDK 경로는 스크립트의 `FLUTTER`·`DART` 설정을 따릅니다. Windows의 상세 실행 규칙은 [Windows 가이드](windows_flutter_guide.md)를 확인하세요.

- Windows와 macOS 모두에서 사용자가 인앱 테스트 화면을 요청하면 일반 `flutter run` 직접 실행보다 프로젝트의 빠른 인앱 테스트 경로 스크립트를 우선 활용하세요.
- 반복 개발은 `scripts/in_app_server.ps1 -Action dev` 또는 `scripts/in_app_server_macos.sh dev`를 사용하세요.
- 스크립트가 없거나 실패할 때만 기존 Flutter web server 경로로 진행하세요.

## UI·게임플레이·렌더링 검증

- 검증 범위와 완료·반복 중단 기준은 [DESIGNS.md](../DESIGNS.md#검증과-완료-기준--완벽한-복제보다-요청-충족)를 따르세요. 대표 화면에서 핵심 조건이 충족되면 종료하며, 미세한 시안 차이를 맞추기 위한 재촬영·전체 빌드를 반복하지 마세요.

- UI·게임플레이·렌더링 등 인게임 내 변화가 있는 변경 요청을 완료한 경우, 작은 Dart 변경은 53000 개발 서버에서 hot reload 후 인앱 브라우저 새로고침으로 먼저 확인하세요.
- 큰 변경·빌드 산출물·캐시 문제 확인이 필요할 때만 `restart`로 전체 웹 빌드를 갱신하고 cache-bust URL로 접속하세요.
- Codex 자동 screenshot 캡처가 `dev` 경로에서 실패하거나 타임아웃되면 같은 재시작을 반복하지 말고, 인앱 브라우저 새로고침과 페이지 상태 확인으로 가능한 동작 검증을 진행하세요. 페이지 로딩·요소 상태 확인을 실제 화면의 레이아웃·텍스트 잘림·렌더링 확인과 동일하게 취급하지 마세요.
- 최종 시각 캡처가 반드시 필요할 때만 `restart` 정적 서버 경로를 사용하세요.
- 실제 화면 검증에서는 변경된 UI·게임플레이 상태를 재현하고, 해당 변경의 완료 조건을 확인하세요. UI 변경은 실제 게임 크기에서 주요 문구·아이콘·수치의 잘림과 겹침을 확인하세요.
- 완료 보고에는 실행한 자동 검사, 동작 확인, 실제 화면 확인을 구분하세요. 시각 검증에 필요한 캡처나 화면 확인을 끝내지 못했다면 그 이유와 미확인 항목을 명시하고 시각 검증을 통과했다고 보고하지 마세요.

## 디버그 패널

- 인앱 테스트 편의를 위한 디버그 패널은 `RUNE_NEXUS_DEBUG_PANEL=true` dart-define이 켜진 경우에만 보여야 합니다.
- 이 flag는 `scripts/in_app_server.ps1`, `scripts/in_app_server_macos.sh` 같은 인앱 테스트 경로에서만 전달하세요.
- 일반 빌드·CI·배포 빌드에는 절대 전달하지 마세요.
- 디버그 패널 액션은 보상 UI, 특성 선택, 보스 웨이브처럼 수동 진행이 오래 걸리는 상태를 빠르게 만들기 위한 개발용 진입점입니다.
- 실제 게임 밸런스나 저장 포맷의 필수 흐름으로 의존시키지 마세요.
