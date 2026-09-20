# 웨이브·코어 주기 실제 이관 검증 — 2026-09-20

## 변경과 경계

Android 3D 전투 인수 후 Godot이 생성 대기열의 시간 진행과 적 생성, 코어 스킬 주기·타깃·피해, 웨이브 완료 판정을 수행한다. Dart의 대응 프레임 갱신은 중지한다. 웨이브 시작의 정적 설정 생산, 코어 HP·방어·패배 결과, 보상·경제·UI·기존 저장 변환은 앱에 남는다. Flame 완전 제거 또는 성능 개선 측정 완료를 뜻하지 않는다.

코어 도착을 처리하는 중에는 남은 프레임을 보관하고 앱의 방어·패배 응답 뒤 이어간다. 패배면 보관 프레임을 폐기하고 완료 보상을 지급하지 않는다. 완료 보상은 한 번 처리한 뒤 체크포인트에 반영한다. 긴급 충전의 사용 여부는 실제 피격과 같은 확정 저장 경계에 기록한다.

## 자동 검증

- Flutter 전체 1,275개 통과·12개 건너뜀. 새 회귀 5개는 실제 Dart 초기 입력 → Godot 적 생성·코어 시간 진행 → Dart 적 ID 미러와 남은 큐 저장, 중복 완료/보상 방지, 치명 도착 우선순위를 포함한다.
- Flutter 분석 지적 없음. 원본 로그: `/tmp/rune_wave_full_tests.log`, `/tmp/rune_wave_final_analyze.log`.
- [Dart 기준값 생성 기록](dart-reference-generation.log): 기존 WaveSpawner/CoreCombatSkillController에 고정 dt를 적용한 [기준값](../../../test/fixtures/native_wave_core_timing.json). 기준 커밋은 `0241ef6`이며 파일 안에 원본 경로를 기록했다.
- [Godot 683개 검사](native-wave-core.log): 생성/복원 지연, 코어 활성·쿨다운·틱·긴급 충전·공격 연동, 타깃·상한, 여러 도착·실패·다음 웨이브, 빔 끝점·수명·피해 숫자 계약.
- [기존 전투 회귀](native-combat-regression.log): 포탑 설정 273개와 기존 런타임 경계 검사. 전체 전투 프레임의 수학적 동등성을 주장하는 검사는 아니다.

재현:

```sh
WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/native_wave_game_test.dart
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path godot --script verify_native_wave_core.gd
```

## Android 통합 확인

일반 `lib/main.dart` debug APK(0.1.19+6027, 디버그 패널 켜짐)를 Android 17 ARM64 에뮬레이터에 설치했다. API·업데이트 주소는 지정하지 않았다. 사용자 요청에 따라 대표 웨이브 1회와 [최종 캡처 1장](android-wave-complete.png)으로 제한했다.

- 로비 이어서 진행 → 3D 인수 → 4배속 23웨이브 시작 → 코어 스킬 6회 발동(누적 113~118) → 23웨이브 완료를 [native ACK 이벤트](android-native-events.log)로 확인했다.
- 최종 HUD는 24/40 준비 상태, HP 4/20, 골드 2,348. 저장 파일도 `roundIndex=23`, `phase=preparation`, 생성 큐/적 0, 코어 활성 횟수 118로 반영됐다.
- Godot script/parse error 및 Android fatal exception은 없었다. 빔 프레임을 포착하려고 전투·캡처를 반복하지 않았으며 빔의 끝점·수명·추적 계약은 자동 검사로 확인했다.
- 앱을 정지하고 로컬 데이터 98개 파일을 실행 전과 바이트 단위로 동일하게 복원했다. 설치한 APK는 유지하고 앱은 정지했다.
- [용량 검사](apk.json): APK 562,387,406바이트, 직전 같은 debug APK 대비 +13,452바이트. PCK 하나만 포함하며 106,010,940바이트(+13,452), 새 이미지·모델·native 라이브러리는 추가하지 않았다. 이 수치는 공개 release APK와의 배포 비교가 아니다.

실기기 CPU/GPU·지속 FPS·발열은 측정하지 않았다. 2D fallback과 Flame 의존성은 남아 있다. 커밋·배포·푸시는 하지 않았다.
