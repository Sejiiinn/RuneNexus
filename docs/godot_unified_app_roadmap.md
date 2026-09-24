# Godot 단일 앱 전환 상태

역할: 전환 단계별 구현·검증·남은 완료 조건의 원본. 확인: 2026-09-24.
대상은 **Godot 단독 Android 앱**이다. 사용자 결정에 따라 웹 배포는 종료하며 웹 호환 작업과 Pages 배포를 요구하지 않는다. 사용자 요청에 따른 Android 공개 배포와 확인 결과는 [배포 상태](deployment_status.md)를 따른다. 실기기 로그인 검증은 사용자가 직접 담당하며, 자동 검사 통과로 간주하지 않는다.

## 현재 실행 경로와 확정한 전환 방식

`godot/app/boot.tscn` → 전용 시작 화면·업데이트 확인 → `godot/main.tscn` 비동기 로딩 → Godot 앱 수명주기 → 로비·게임 세션이 기본 진입이다. 업데이트 통과 전에는 게임 저장·계정 복원을 시작하지 않는다. `--app` 없이도 앱을 실행한다. `--session`, `--fixture`, 검증용 `--script`는 명시적 개발 진입이다. Android 호스트는 `android-godot-only/`의 GodotActivity와 `RuneNexusPlatform`이며 Flutter 런타임·플랫폼 합성·프레임 브리지를 사용하지 않는다.

기존 전투·디자인·저장·API 계약과 서버 권위 경제는 보존한다. Android의 기존 패키지 ID, 저장 지원 경로, Keystore 세션 형식은 유지한다. 검사 패키지는 별도 applicationId로 격리한다. iOS·PC 공개 배포는 이번 범위에 포함하지 않으며 데스크톱 Godot은 개발 검증에 사용한다.

## 3. 단계와 의존 관계

| 단계 | 구현 상태 | 남은 완료 조건 |
| --- | --- | --- |
| 1. 전투 호스트 대체 | Godot 자체 시계·입력·전장 표시, Flutter 브리지 제거 | 에뮬레이터 입력·수명주기 통과; 최종 실기기 확인 |
| 2. 런·성장·저장 | Godot 도메인, 기존 저장 codec/체크포인트·격리 검사 | 기존 공개 앱→Godot 앱 업데이트·저장 인계 에뮬레이터 통과; 최종 실기기 확인 |
| 3. 전투 UI | Godot HUD·배치·보상·결과 화면 | 에뮬레이터 화면·터치 통과; 최종 실기기 확인 |
| 4. 계정·온라인 서비스 | Godot 인증·온라인 저장·경제 Outbox·업데이트 서비스 구현, 앱 통합·독립 자동 검증 통과 | 실제 Google 로그인·계정 전환·저장 동기화 |
| 5. 로비·라우팅 | Godot 로비·성장·계정·메일·순위 및 서버 명령 연결 | 데스크톱·에뮬레이터 기본 흐름 확인; 실기기·실계정 흐름 확인 |
| 6. 플랫폼·패키징 | 단독 Godot Android 호스트, 기존 세션 보관·로그인·업데이터 어댑터, production/inspection 분리 | 기존 서명·운영 설정·release 빌드·에뮬레이터 설치/업데이트 통과; 최종 실기기 확인 |
| 7. Flutter 제거·최종 검증 | 활성 Flutter/Dart 소스·생성기·검사 의존성 제거, Pages workflow 제거 | 팩/APK 포함물·용량·서명·운영 설정·독립 검증 통과; 사용자 담당 실기기 항목 확인 |

구현·자동 검사·데스크톱 화면·Android 실기기·공개 배포는 별도로 판정한다. 소스 전환만으로 배포 가능 상태를 선언하지 않는다. 현재 검증 근거와 한계는 [이번 검증 기록](analysis/godot_android_release_20260924/README.md), 배포 선행 조건은 [배포 상태](deployment_status.md)를 따른다.

## 책임과 보존 계약

- 전투 HP·명중·웨이브는 Godot 전투 런타임, 런·일반 성장은 세션 도메인, 중요 재화는 Go API가 소유한다.
- 계정 서비스는 UI 수명과 분리한다. 계정 교체 시 오래된 응답을 버리고 계정별 저장·Outbox를 사용한다. 재시도는 원래 요청 본문과 멱등 키를 보존한다.
- 저장 동기화는 원격 우선 bootstrap, writer/revision, 로컬 백업, 재기반화 후 런타임 재로드를 보존한다. 로그아웃 의도는 네트워크 실패에도 영속화한다.
- Android 어댑터에는 게임 규칙을 넣지 않는다. 로그인·암호화 저장·업데이트 설치·OS 설정·텍스트 배율만 담당한다.
- 릴리스 설정은 API·Google client ID·업데이트 manifest·client build를 명시한다. 배포 서명 누락을 debug 서명으로 대체하지 않는다.
- 웹 배포는 폐기한다. 기존 공개 웹을 실제로 삭제하거나 운영 설정을 변경하는 작업은 수행하지 않았다.

## 소스와 검증 진입점

[전투 책임](godot_combat_migration_boundaries.md), [앱 서비스](../godot/services/), [앱 안내](../godot/app/README.md), [인앱 검증](../.agents/in_app_test_guide.md), [APK 절차](android_apk_distribution.md)를 따른다. 콘텐츠 JSON은 단일 원본이며 Dart 생성 단계가 없다.

이전 이관 계획의 고유한 제약·과거 단계별 근거는 [전환 전 로드맵](archive/godot_unified_app_roadmap_before_native_release_20260924.md)에 보존한다. 제거한 Flutter 원본은 [보관 설명](archive/flutter_reference_20260924.md)에 있으며 활성 실행 경로가 아니다.
