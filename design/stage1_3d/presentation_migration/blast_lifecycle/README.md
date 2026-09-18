# 대포 폭발 수명 이관 — 2026-09-19

측정 원자료·재현 스크립트·실행 로그·캡처·영상은 로컬 검수 자료로 보관하며 이 커밋에는 포함하지 않는다. 아래 해당 링크는 로컬 작업 폴더 기준이다.

## 범위와 유지 계약

대포 `ImpactEffectStyle.blast`를 `nativeBlastEffectEvents` 지원 확인 뒤 생성 이벤트로 전달한다. 기존 피해 숫자·일반 착탄 journal의 유한 보관·공용 전투 시계·실제 적용 ACK를 재사용하며, Godot에서 위치·반경·개별 duration과 현재 age로 기존 3D 폭발 progress를 계산한다. 대포 사격·투사체·명중·데미지 계산은 변경하지 않는다.

Godot의 Canvas 효과 목록과 분리하여 기존 `_update_impacts`에 공급한다. 기존 `GodotImpact`, GPU 파편, 체적 표현, 광원 및 풀 재사용을 유지한다. legacy `impacts` 입력도 계속 처리하고 같은 ID가 있으면 legacy 입력을 우선한다. 옵션·카메라 재적용은 현재 progress를 유지한다. Flame blast의 `battlefieldEffect()`는 기존처럼 null이라 구형 런타임에 이중 snapshot을 보내지 않는다.

정지·배속·보상·코어 파괴 감속은 실제 컴포넌트 dt의 공용 시계를 따른다. 실제 적용 전에는 생성 입력을 재전송하고 ACK 후 중단한다. 장면/전투 정리 시 취소하고, 지원 철회·2D 복귀 때는 살아 있는 효과를 현재 나이와 타일 크기에 맞춰 복원한다. 전송이 늦은 짧은 효과·중복 수신·용량 상한은 기존 생성 journal 계약을 따른다. 복귀용 Component 객체는 계속 보관하므로 전체 객체 생성을 제거한 것은 아니다.

## 작업량 비교

[measure_work.dart](measure_work.dart)는 실제 RuneNexusGame 추가·갱신·직렬화 경로에서 blast capability를 끈 기존 경로와 켠 경로를 비교한다. 기본 수명 0.42초인 대포 폭발 60개를 동시에 생성하고 최초 + 60Hz 24틱(0.4초)을 진행했다. 실제 게임은 각 생성 시 지정한 blastDuration을 그대로 사용하며 이 측정의 기본 수명으로 바꾸지 않는다. ACK는 매 프레임 즉시 전달한다.

| 지표 | 기존 | 생성 이벤트 |
| --- | ---: | ---: |
| Flame 트리 blast 수 | 60 | 0 |
| Flame update 호출 | 1,440 | 0 |
| visualProgress 읽기 | 1,500 | 0 |
| 직렬화 폭발 레코드 | 1,500 | 60 |
| 25프레임 impacts+effects JSON 바이트 | 125,780 | 27,224 |
| 최초 프레임 바이트 | 4,122 | 23,802 |

이 조건의 관련 JSON은 약 78.4% 감소했다. 최초 이벤트는 수명·생성 시각 등의 추가 필드 때문에 기존 5항목 progress 배열보다 크다. ACK 지연 시 이벤트 반복 전송이 남으므로 모든 부하·구간에 같은 감소율을 적용하지 않는다. 실제 평균 동시 폭발 수를 재현한 측정도 아니다. [원자료](work-results.json), [실행 로그](work-measurement.log).

전체 frame payload, CPU 시간, Godot/GPU 비용, FPS, 실기기 p95/p99·발열 개선은 미측정이다. 기존 [입자 GPU 운동 전환](../../cannon_impact/gpu_motion/README.md)의 CPU 절감 수치를 이번 이벤트 이관 성능으로 재사용하지 않는다.

## 검증

- 집중 Flutter 검사 48 PASS / 기존 debug 조건 1 skip. 실제 widget capability·지연 ACK, 개별 수명, legacy 입력, 혼합 효과, resize/fallback 검사 포함. [로그](dart-tests.log).
- [flutter analyze](analyze.log): 0 issues.
- Godot 4.7.2 [실제 blast 경로 검사](godot-tests.log): Impact/MultiMesh/광원/풀, legacy 병합, 옵션·카메라 재적용 통과.
- Godot [공용 효과 검사](godot-effects.log): 혼합 256개 상한·만료·재시도 통과. [presentation protocol](godot-protocol.log) 통과.
- 별도 작업량 측정 검사 통과. 독립 읽기 검토에서 추가 결함 없음.

Android 최종 APK는 build 2005, 391,251,786바이트다. 일반 `lib/main.dart` ARM64 release이며 로컬 검수용 debug 패널을 포함했다. `adb install -r`로 기존 데이터를 유지했다. [빌드 로그](android-build.log), [APK 해시·환경](final-build.json).

변경 전 main APK build 2004에서 스테이지 1/17웨이브를 [기준 영상](before-combat.mp4)으로 남겼다. Android 17 ARM64 에뮬레이터, 1080×2424이고 영상은 540×1212다. 같은 포탑 배치의 연속 전투이며 웨이브 시각·난수는 고정하지 않았으므로 픽셀 단위 전후 비교나 FPS 비교로 해석하지 않는다. 기존 폭발 렌더러·shader SHA-256은 `visual-inputs-before.json`과 작업 후 동일함을 확인했다.

최종 main APK의 스테이지 1/17~18웨이브에서 1×·4× 연속 포격, 폭발 화염·먼지·파편과 종료를 확인했다. 18웨이브 도중 메뉴 정지 후 3초 간격 두 화면에서 적·피해 숫자·효과 상태가 유지됐고, 닫은 뒤 1× 전투가 이어졌다. 드론 시점으로 바꾸고 Android 홈→앱 복귀 후 새 폭발이 정상 표시됐다. 마지막은 메뉴 정지 상태로 두었다.

- [최종 전투 영상](combat.mp4), [4× 폭발](combat-8.0.png).
- [전투 정지](active-paused.png), [정지 유지](active-paused-later.png).
- [복귀 후 드론 시점의 실제 폭발 화면](resumed.png).
- 수집 logcat에서 SCRIPT ERROR/Parse Error/FATAL EXCEPTION/Flutter 예외 없음.

Android 대표 검수는 스테이지 1의 기존 대포 6문 배치이며 모든 스테이지·모든 동시 폭발 부하를 검수한 것은 아니다. 영상 FPS는 성능 수치로 사용하지 않는다. 공개 배포·커밋·푸시는 하지 않는다.
