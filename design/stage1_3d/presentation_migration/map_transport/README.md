# 정적 맵 전송 최적화 — 2026-09-18

측정 원자료·재현 스크립트·실행 로그·캡처·영상은 로컬 검수 자료로 보관하며 이 커밋에는 포함하지 않는다. 아래 해당 링크는 로컬 작업 폴더 기준이다.

## 적용

Android 본게임의 Flutter→Godot 프레임에서 맵 적용 확인 후 전체 타일 배열을 생략한다. `GodotBattlefieldMapTransport`가 크기·테마·타일 값을 확인하고 변경 시 revision을 올린다. 같은 MapDefinition 내부 배열 변경도 감지한다. 변경 없는 프레임에서도 값 비교는 남지만 배열·문자열 목록 생성과 맵 JSON 직렬화는 반복하지 않는다.

초기/변경 프레임은 실제 적용 ACK까지 전체 맵을 반복해 Kotlin 최신 프레임 병합에 대응한다. 장면 세대 변경은 캐시를 초기화하고, Godot에 일치하는 맵이 없으면 `mapRequired`로 다시 요청한다. 복구 응답은 ready·투영·효과 ACK가 아니다. 기존 full-map 입력과 stateless codec을 유지한다. 전투 규칙·저장 형식·에셋·사거리 표시 변경 없음.

## 측정

macOS Flutter test JIT에서 실제 스테이지 1·6·11·15 맵과 합성 포탑 6·적 24·탄환 12개를 사용했다. 라벨·선택·효과 DTO는 제외했다. 변경 전 codec은 `legacy_frame.dart`, 재현은 `measure_codec.dart`, 원자료는 [codec-results.json](codec-results.json)이다. 변경 전후 동적 데이터 동일성도 검사한다.

변형마다 1,000회 준비 후 AB/BA 교대로 3,000회씩 6묶음 측정했다. 아래 시간은 맵 변경 감지·DTO 생성·JSON 인코딩의 호출당 평균이다. 빌드와 동시에 측정하지 않았다.

| 스테이지 | 전송 바이트 전 → 후 | 프레임당 절감 | 인코딩 μs 전 → 후 |
| --- | ---: | ---: | ---: |
| 1 | 3592 → 2888 | 704 | 44.20 → 36.01 |
| 6 | 3623 → 2888 | 735 | 42.44 → 36.39 |
| 11 | 3610 → 2888 | 722 | 41.76 → 35.95 |
| 15 | 3621 → 2888 | 733 | 42.00 → 36.11 |

합성 전투 입력에서 바이트 약 20%, 인코딩 CPU 약 14~19% 감소. 빈 전장의 payload는 1,039~1,070 → 335바이트. ACK 후 정상 상태 기준이며 최초 전달·맵 변경·복구 때 전체 맵을 보낸다. 플랫폼 채널·Godot 파싱·GPU·전체 FPS·실기기 발열은 측정하지 않았다. 전체 프레임 병목이나 모바일 FPS 개선을 확정하는 수치가 아니다.

## 자동 검사

- 관련 Dart/widget 22개 통과: 최초 적용 확인, 프레임 병합, 이전 응답, viewport, 새 장면, 동일 크기 맵/테마 변경, 복구, 실제 widget→codec 연결, 기존 전체 맵 호출.
- `flutter analyze`: 0 issues ([로그](analyze-final.log)).
- Godot 4.7.2 headless presentation protocol: 0 failures ([로그](godot-protocol.log)).
- [Dart 로그](dart-tests.log), [최종 lifecycle 로그](dart-lifecycle-final.log), [측정 로그](codec-measurement.log).

## Android 본게임

ARM64 Android 17 에뮬레이터 `emulator-5554`, 1080×2424, Godot 4.7.2, release 메인 APK build 2003(검수용 debug panel 포함). `adb install -r`로 기존 앱 데이터를 유지했다. APK는 391.3MB이며 외부 배포하지 않았다. [빌드 로그](android-build.log).

- 로비 → 저장된 스테이지 1 / 15웨이브 재개: 초기 맵·포탈·코어·포탑·적·HUD 정상. [진입](android-enter.png).
- 1배속 실제 전투: 지형이 유지되고 사격·이동·피해 숫자 정상. [본게임 화면](android-combat.png).
- 드론 시점 전환 → Android 홈 → 앱 복귀: 지형·HUD 정상. 15웨이브 완료 보상 창이 열린 상태로 복귀해 해당 대표 상태를 확인했고, 보상 선택은 하지 않고 정지 상태로 두었다. [복귀 화면](android-resume.png).

Android 시각 확인은 스테이지 1 대표 상태에 한정한다. 다른 맵의 변경·복구는 자동 프로토콜 검사, 스테이지 6·11·15 직렬화는 위 측정으로 확인했다. 모든 스테이지의 Android 시각 재검수나 실기기 성능 검증을 뜻하지 않는다.
