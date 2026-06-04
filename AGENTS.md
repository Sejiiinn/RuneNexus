## Coding Guidelines
- 반드시 바꾼 형상으로도 잘 동작하도록 임시 코드를 넣지 않도록 하세요.
- **동작만 잘 하는** 코드로 작성하면 안 됩니다. 반드시 현재 프로젝트의 구조와 맞물리면서 작동하도록 하세요.
- 사용자의 의사 결정이 필요한 핵심 분기가 존재한다면, 사용자에게 의사 결정을 요구하세요.
- 이득이 크지 않은 단순 wrapping에 가까운 helper 메서드 작성을 하지 마세요.
- 사용자가 실제로 코드 작성을 지시할 때에만 작성을 수행하세요. 모호한 경우, 사용자의 의사를 물으세요.
- 목적을 달성하기 위해 최소한의 수정만 진행하세요. 목표 달성에 직접 필요한 국소 구조 정리는 진행할 수 있지만, API 계약 변경·데이터 손실 가능성·대규모 책임 경계 변경·외부 의존성 추가가 필요한 경우에는 먼저 사용자의 의사를 물으세요.
- 사용자가 구현 중 구조나 책임 경계를 여러 차례 바꾸려 할 경우, 매번 그대로 따라가지 말고 현재 단계의 목표·비목표·커밋 단위를 기준으로 변경 필요성을 먼저 검토하세요. 지금 단계의 핵심 목표와 직접 관련 없는 구조 변경은 보류를 제안하고, 이미 합의된 책임 경계가 있다면 그 경계를 유지하는 쪽으로 중심을 잡으세요.
- 이해가 어려울 수 있는 코드 구문에는 간단한 주석을 추가하세요. 주석은 설명문보다 짧은 명사형·구문형으로 작성하세요.
- 데미지 계산식, 저항, 취약, 피해 배율, 포탑 스탯 보정을 추가하거나 변경할 때는 반드시 `docs/damage_calculation_rules.md`를 먼저 확인하고 그 계층 규칙을 따르세요.
- 한글로 설명하세요.

## Commit Guidelines
- 커밋 메시지는 한글로 작성하고, 아래 항목을 참고하여 앞에 prefix를 붙여주세요.
1. 기능 추가 - feat:
2. 버그 수정 - fix:
3. 리팩토링 - refactor:
4. 기타 수정 - chore:

## Windows Flutter 검증 주의
- Windows 샌드박스 환경에서는 `dart`, `flutter` 배치 래퍼가 오래 멈추거나 `dartaotruntime.exe` 실행이 `Access denied`로 실패할 수 있습니다.
- 포맷은 가능한 경우 Dart SDK 실행 파일을 직접 호출하세요.
  - `C:\Users\rlatp\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format <파일>`
- 인앱 브라우저 확인 전에는 53000 포트의 기존 Flutter web server가 살아 있는지 확인하세요. 개발 서버가 살아 있으면 hot reload 후 인앱 브라우저 새로고침을 우선하고, 오래된 정적 번들이 의심될 때만 `restart` 후 cache-bust URL로 접속하세요.

## 샌드박스 운영 가이드
- 권한 문제가 의심되는 명령은 샌드박스에서 먼저 실행하지 말고 샌드박스 밖 실행 승인을 요청하세요.
- `flutter analyze`, `flutter test`, `flutter run`, `flutter build`, `scripts/in_app_server.ps1 -Action dev`, `scripts/in_app_server.ps1 -Action restart`, `scripts/in_app_server_macos.sh dev`, `scripts/in_app_server_macos.sh restart`, `git add`, `git commit`, `git push`는 처음부터 샌드박스 밖 실행 승인을 요청하세요.
- `rg`, 파일 읽기, 파일 수정, `git status`, `git diff`처럼 읽기·편집 중심 작업은 샌드박스에서 진행하세요.
- 53000 포트 서버는 먼저 `scripts/in_app_server.ps1 -Action status` 또는 `scripts/in_app_server_macos.sh status`로 확인하세요. HTTP 200이면 재기동보다 cache-bust URL 갱신을 우선하고, 개발 서버 세션이 살아 있으면 hot reload 후 인앱 브라우저 새로고침을 우선하세요.
- Flutter 실행 뒤 생성 파일이나 줄바꿈만 바뀐 파일이 섞일 수 있으므로 커밋 전에는 의도한 변경만 스테이징하세요.

## 인앱 테스트 공통 지침
- Windows와 macOS 모두에서 사용자가 인앱 테스트 화면을 요청하면 일반 `flutter run` 직접 실행보다 프로젝트의 빠른 인앱 테스트 경로 스크립트를 우선 활용하세요. 반복 개발은 `scripts/in_app_server.ps1 -Action dev` 또는 `scripts/in_app_server_macos.sh dev`를 사용하고, 스크립트가 없거나 실패할 때만 기존 Flutter web server 경로로 진행하세요.
- UI·게임플레이·렌더링 등 인게임 내 변화가 있는 변경 요청을 완료한 경우, 작은 Dart 변경은 53000 개발 서버에서 hot reload 후 인앱 브라우저 새로고침으로 먼저 확인하세요. 큰 변경·빌드 산출물·캐시 문제 확인이 필요할 때만 `restart`로 전체 웹 빌드를 갱신하고 cache-bust URL로 접속하세요.
- Codex 자동 screenshot 캡처가 `dev` 경로에서 실패하거나 타임아웃되면 같은 재시작을 반복하지 말고, 인앱 브라우저 새로고침과 페이지 상태 확인으로 검증하세요. 최종 시각 캡처가 반드시 필요할 때만 `restart` 정적 서버 경로를 사용하세요.
- 인앱 테스트 편의를 위한 디버그 패널은 `RUNE_NEXUS_DEBUG_PANEL=true` dart-define이 켜진 경우에만 보여야 합니다. 이 flag는 `scripts/in_app_server.ps1`, `scripts/in_app_server_macos.sh` 같은 인앱 테스트 경로에서만 전달하고, 일반 빌드·CI·배포 빌드에는 절대 전달하지 마세요.
- 디버그 패널 액션은 보상 UI, 특성 선택, 보스 웨이브처럼 수동 진행이 오래 걸리는 상태를 빠르게 만들기 위한 개발용 진입점입니다. 실제 게임 밸런스나 저장 포맷의 필수 흐름으로 의존시키지 마세요.
