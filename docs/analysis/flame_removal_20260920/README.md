# Flame 제거와 Godot 전투 통합 — 2026-09-20

Android 전투 이관과 Flame 의존성·2D 실행 경로 제거 작업의 검증 기록이다. 다른 플랫폼의 전투 연결/지원 범위는 미확정이므로 전체 플랫폼 완료나 배포 가능 상태를 뜻하지 않는다.

## 변경

- 코어 HP·방어·패배까지 Godot에서 결정하고 도착마다 앱 응답을 기다리던 구간을 제거했다.
- ACK 상태를 저장 모델에 미러하며 매 배치의 전체 저장 JSON 생성을 제거했다. 기존 저장·온라인 경제·보상 계약은 유지한다.
- Flame 패키지, 컴포넌트 트리, 2D 전투/효과, Dart 타격 실행기를 제거하고 Flutter 레이아웃·입력 호스트를 연결했다.
- 연결 실패와 전투 프로토콜 불일치를 명시적 오류·재시도로 처리한다. 오래된 화면의 응답/종료가 새 전투를 덮지 못하게 했다.

## 검증

- [Flutter 전체 검사](flutter-test.log): 1,140개 통과·11개 조건부 건너뜀. [정적 분석](flutter-analyze.log): 지적 없음.
- Godot 실제 엔진 검사: 기존 전투 회귀 7,346항목, 웨이브/코어 682항목, 코어 방어 46항목과 기존 전투 구성·적 상태 검사를 통과했다. 이들은 Flutter 실행기 5개 테스트에도 포함되며 Flutter 개수와 중복 합산하지 않는다.
- [Android 빌드](android-build.log): 일반 lib/main.dart, debug 6027, Android 17 ARM64 에뮬레이터. 23웨이브 저장 복원 → 4배속 시작 → 코어 발동 → 웨이브 완료 → 24웨이브 준비를 확인했다. 포탑 터치로 사거리/상세 패널을 열고 홈 화면 이탈·복귀 뒤 같은 전투를 유지했다. [실행 로그](android-combat.log), [최종 실제 화면](android-final.png).
- [저장 복원 확인](save-restoration.json): 기존 98파일 SHA-256 일치. 테스트 중 추가된 res_timestamp 파일 1개만 제거했고 앱은 정지했다.
- 실화면은 대표 흐름 1회, 입력 확인용 중간 캡처 1장과 최종 1장으로 제한했다. 패배·동시 도착·재시도·지연 응답은 자동 회귀 검사로 검증했으며 Android에서 모든 조합을 반복하지 않았다.

## 패키지 점검

debug APK 562,391,310바이트, PCK 106,014,844바이트. 직전 로컬 debug 기록 대비 각각 3,904바이트 증가했으며 팩의 전투 코드 증가분과 같다. 공개 release APK와의 비교나 배포 용량 검증은 아니다. APK에는 기존 arm64-v8a/armeabi-v7a/x86_64 엔진 라이브러리가 유지된다. [팩 감사](apk-audit.json)는 289항목, 완전 중복 payload 0바이트다. kernel_blob에 NativeGameHost가 있고 FlameGame 및 package:flame 소스는 없음을 확인했다. 이번 작업에서 ABI·에셋 정책을 바꾸거나 공개 배포하지 않았다.

[기존 테스트와 Godot 회귀 검사 대응](legacy_test_coverage.md). 원본 Dart 전투 검사는 [보관본](../../archive/flame_reference_tests_20260920/README.md)에 남긴다. 새 Godot 전투 검사 5종은 `test/godot_native_regression_test.dart`에서 실제 엔진으로 실행한다. Godot 실행 파일이 없으면 사유를 표시해 건너뛰므로 CI에서는 GODOT_BIN을 준비해야 한다.

실기기 FPS·p95/p99·발열은 이번 제거 작업에서 재측정하지 않는다. 이전 FPS 기록은 [별도 보고서](../fps_20260920/README.md)를 참고한다.
