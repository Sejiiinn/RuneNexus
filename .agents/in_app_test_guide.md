# In-App Test Guide

역할: Godot 앱의 실제 화면·조작·수명주기 검증. 2026-09-24에 순수 Godot Android 실행 경로와 네이티브 검사 명령을 대조했다. 완료 기준과 스크린샷은 [디자인 기준](../DESIGNS.md#검증과-완료-기준--완벽한-복제보다-요청-충족), 이관·배포 상태는 [로드맵](../docs/godot_unified_app_roadmap.md)과 [배포 현황](../docs/deployment_status.md)을 따른다.

## 테스트 저장과 생성 디렉터리 격리

- 사용자 플레이 저장을 기본 검수 대상으로 사용하지 않는다. Android 검수 앱 `com.example.rune_nexus.godotonly` 또는 임시 Godot 프로젝트를 사용해 정식 `com.example.rune_nexus` 저장 영역과 분리한다. 실제 저장 인계 검증에는 원본을 지우거나 덮어쓰지 않고 복사본과 명시된 절차를 사용한다.
- 개발·검사·패키징이 같은 생성 디렉터리를 동시에 변경하지 않게 한다. `scripts/prepare_godot_project.py`는 `build/godot/project/assets`를 재생성하므로 그 프로젝트의 편집·실행·패키징과 순차 실행한다. 편집 프로젝트의 소스 링크·열린 원본은 [Godot 가이드](godot_mcp_guide.md)를 따른다.
- `scripts/run_godot_native_regressions.py`는 임시 프로젝트·fixture를 만들고 종료 후 정리한다. Godot 실행 파일이 없으면 실패하며 skip을 통과로 처리하지 않는다.

## 도구 복구와 대체 경로

- 실행·입력·캡처 실패 시 대상 프로젝트·프로세스·연결과 오류를 확인하고 기존 연결 복구를 시도한다. 상태 변화나 새로운 근거 없이 같은 명령·재시작을 반복하지 않는다.
- 복구되지 않으면 동일 소스·상태·검증 대상을 유지하는 Godot 직접 실행·CLI 등으로 전환한다. 사용자 지정 도구·열린 원본·미저장 작업을 보존한다.
- 데스크톱 도구 문제만으로 APK를 만들지 않는다. 대체 경로에서도 확인하지 못한 항목은 미검증과 이유를 보고한다.

## Godot 앱·세션

검증 경로와 APK 빌드 조건은 [작업 기준](../AGENTS.md#godot-검증과-apk-빌드)을 따른다. 일반 UI·메뉴·게임 로직·카메라·효과 위치는 데스크톱 `--app`와 관련 자동 검사에서 먼저 확인한다. 수동 전투 검사 `--session`은 [세션 가이드](../godot/session/README.md)를 따른다.

```sh
python3 scripts/prepare_godot_project.py
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/project --import --quit
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/project --resolution 440x900 -- --app
```

`GODOT_BIN=/path/to/godot python3 scripts/run_godot_native_regressions.py`는 임시 프로젝트에서 전투·런·저장·UI 회귀를 실행한다. 콘텐츠 JSON은 `python3 scripts/verify_godot_content.py`로 확인한다. 헤드리스 통과는 실제 화면·터치나 기기 인증·저장 인계의 완료가 아니다.

## Android 검수 앱과 정식 앱

Android 전용 폰트/SP·밀도·안전 영역, 터치·시스템 뒤로가기·수명주기, Google 인증·보안 세션·APK 설치기, 모바일 GPU·기기 성능은 실제 Android 기기에서 확인한다. 검수 앱 빌드는 아래 명령이며 정식 앱과 앱 ID·저장 영역을 분리한다.

```sh
python3 scripts/build_godot_only_apk.py
adb install -r build/godot-only/rune-nexus-godot-only-arm64.apk
adb shell am start -S -n com.example.rune_nexus.godotonly/com.example.rune_nexus.MainActivity
```

정식 변형 `com.example.rune_nexus`는 [Android 호스트](../android-godot-only/README.md)의 `productionRelease`와 [APK 배포 절차](../docs/android_apk_distribution.md)를 따른다. 기존 설치·저장·계정 인계는 같은 패키지와 실제 서명 키를 확인한 뒤 별도 기기 검증으로 수행한다. 배포 키 없는 로컬 production APK는 미서명이며 정식 설치 후보가 아니다.

스테이지 1~15에서 관련 로비·HUD·건설 입력·시점·전장, 챕터 전환의 경로·건설칸·포탈·코어 위치를 변경 영향에 맞게 확인한다. Android 직접 화면에서 확인할 항목은 데스크톱 캡처로 완료 처리하지 않는다. [전투·저장 책임](../docs/godot_combat_migration_boundaries.md)과 [UI 복원 기준](../docs/godot_ui_restoration_baseline.md)을 따른다.

## 반복 작업 원칙

- 새 변경·실패·미해결 위험이 없으면 같은 캡처·전체 검사·빌드를 반복하지 않는다. APK는 사용자 요청, Android 전용 확인, 최종 배포 검증 때만 만든다.
- 화면 변화 뒤 관련 영역과 대표 상태를 확인하고 실제 실행·화면·기기 결과를 구분해 보고한다.
- 문서만 수정한 작업에는 게임 빌드·인앱 시각 검증을 추가하지 않는다. 링크·내용·diff를 확인한다.
