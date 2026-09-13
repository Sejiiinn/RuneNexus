# In-App Test Guide

UI·게임플레이·렌더링 변경의 실제 화면 검증과 인앱 테스트 화면을 열 때 사용한다. 검증 범위·완료 기준·스크린샷 제공은 [DESIGNS.md](../DESIGNS.md#검증과-완료-기준--완벽한-복제보다-요청-충족)가 기준이다.

## Android 스테이지 1 3D

스테이지 1 **3D 렌더·카메라·다중 사격 검수는 웹을 사용하지 않고 Android APK로 진행한다**. [본게임 실행·공용 빌드](../docs/stage1_3d_preview.md)를 기준으로, 일반 `lib/main.dart` 진입 APK에서 변경에 관련된 로비·스테이지 1·기존 HUD·건설 입력·시점 전환을 확인한다.

순수 대포 비교는 별도 [Godot 검수 APK](../design/stage1_3d/godot_preview/README.md)를 사용한다. 두 앱은 같은 Godot 런타임을 공유한다. ThreeJS 검수 실행 경로는 제거했으며 [과거 소스](../design/legacy_threejs/README.md)만 보관한다.

Godot MCP 편집 연결은 [개발 프로젝트 준비·원본 보존](godot_mcp_guide.md)을 따른다. 데스크톱 편집·실행 결과로 Android 본게임의 HUD·저장·실기기 성능 검증을 대신하지 않는다.

## 그 밖의 Flutter 인앱 검증

저장소 루트에서 프로젝트 서버 스크립트를 사용한다. 먼저 `status`로 53000 포트의 서버를 확인한다. HTTP 200이면 기존 서버와 cache-bust URL을 사용하고, 개발 서버에서는 hot reload 후 새로고침한다. 정적 번들이 오래됐거나 빌드 산출물 갱신이 필요한 경우에만 `restart`한다.

| 목적 | macOS | Windows |
| --- | --- | --- |
| 서버 확인 | `scripts/in_app_server_macos.sh status` | `scripts/in_app_server.ps1 -Action status` |
| 개발 서버 기동 | `scripts/in_app_server_macos.sh dev` | `scripts/in_app_server.ps1 -Action dev` |
| 전체 빌드·재기동 | `scripts/in_app_server_macos.sh restart` | `scripts/in_app_server.ps1 -Action restart` |

macOS 스크립트의 작업 경로가 현재 checkout과 다르면 `WORK_DIR="$PWD"`로 지정한다. SDK는 스크립트의 `FLUTTER`·`DART` 설정을 따른다. Windows SDK 차이는 [Windows 가이드](windows_flutter_guide.md)를 참고한다. 스크립트가 없거나 실패하면 기존 Flutter web server 경로를 사용한다.

변경된 상태를 재현해 실제 게임 크기에서 조작·문구·아이콘·수치를 확인한다. 페이지 로딩·요소 상태만으로 레이아웃이나 렌더링 검증을 통과했다고 판단하지 않는다. 캡처 문제는 원인을 확인해 가능한 경로로 해결하며, 같은 재시작을 반복하지 않는다. 정적 서버가 캡처 문제 해결에 필요한 경우 `restart`를 사용할 수 있다. 끝내 확인하지 못한 항목은 완료 보고에 남긴다.

## 디버그 패널

`RUNE_NEXUS_DEBUG_PANEL=true` dart-define이 켜진 경우에만 패널을 노출한다. 이 플래그는 인앱 테스트 스크립트에서만 전달한다. 일반 빌드·CI·배포에는 포함하지 않는다. 패널은 보상·특성·보스 상태의 빠른 재현용이며, 실제 게임 밸런스나 저장 흐름의 필수 경로로 의존시키지 않는다.
