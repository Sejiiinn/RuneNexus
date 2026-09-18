# 착탄 효과 수명 이관 — 2026-09-18

측정 원자료·재현 스크립트·실행 로그·캡처·영상은 로컬 검수 자료로 보관하며 이 커밋에는 포함하지 않는다. 아래 해당 링크는 로컬 작업 폴더 기준이다.

## 범위

`spark`·`sniperBlast`·`flame`·`frost`·`lightning`·`lightningBlast`의 수명을 Godot 생성 이벤트 경로로 전환한다. [기존 피해 숫자·사망·젬 수명 이관](../native_lifecycle/README.md)의 공용 시계·유한 큐·실제 적용 ACK를 재사용한다. 이 작업 당시 대포 `blast`, 투사체 이동·명중·피해 판정은 기존 경로다. 이후 대포 수명 이관은 [후속 기록](../blast_lifecycle/README.md)을 따른다.

`nativeEffectEvents`와 별도 `nativeImpactEffectEvents`를 모두 확인해야 전환한다. 지원 값이 없는 이전 Godot은 기존 스냅샷 경로를 유지한다. 전환 후 해당 Flame Component는 트리에 등록하지 않고 매 프레임 update·진행도 DTO 생성을 생략한다. ACK 전 생성 입력 재전송, ACK 후 중단, 정지·배속·전투 종료 및 2D 복귀 계약을 유지한다. 지원 철회 시 살아 있는 기존 효과도 공용 복원 경로로 복원한다.

Godot의 기존 착탄 그리기 수식·색·수명은 유지한다. flame/frost의 2D 착탄 도형은 기존과 같이 억제하고 기존 3D 효과를 사용한다. 비blast 효과가 사용하지 않는 대포 shock arc 목록 생성도 생략한다. 복귀용 Component 객체와 유한 이벤트 목록은 여전히 생성·보관한다.

## 작업량 비교

[measure_work.dart](measure_work.dart)는 실제 RuneNexusGame 추가·갱신·프레임 생성 경로에서 capability를 끈 기존 snapshot 경로와 켠 이벤트 경로를 비교한다. 6종을 10개씩 동시에 생성하고, 초기 프레임과 60Hz 12틱(0.2초)을 처리한다. 매 프레임 즉시 유효 ACK를 전달한다. 두 조건 모두 동일한 객체 개수·수명·시각 입력이며, 실제 전투의 평균 동시 효과 수를 뜻하지 않는다.

| 지표 | 이전 경로 | 이벤트 경로 |
| --- | ---: | ---: |
| Flame 트리의 착탄 Component | 60 | 0 |
| 착탄 update 호출 | 720 | 0 |
| 착탄 정보 생성 호출 | 840 | 60 |
| 직렬화한 효과 레코드 | 780 | 60 |
| 13프레임 effects JSON 총 바이트 | 268,673 | 25,445 |
| 최초 프레임 effects JSON 바이트 | 19,887 | 24,027 |

이 조건의 효과 JSON은 약 90.5% 감소했다. 최초 이벤트는 생성 시각 등 추가 필드 때문에 더 크며, ACK가 늦으면 전체 생성 이벤트를 반복 전달한다. 따라서 항상 같은 감소율을 보장하지 않는다. 초기 생성 이후 Flame update·스냅샷 반복을 제거한 결과이며 **전체 프레임 payload·CPU 시간·Godot/GPU 비용·FPS·실기기 발열 개선은 미측정**이다. [원자료](work-results.json), [실행 로그](work-measurement.log).

## 검증

- 관련 Flutter 4개 파일 41 PASS / debug 조건 1 skip. 추가 integration/parser 25 PASS / 동일 debug 조건 1 skip. 해당 분기까지 활성화한 최종 integration은 20/20 PASS. 중복 실행된 검사를 합산하지 않는다. [관련 검사](tests.log), [추가 검사](final-tests.log), [debug 검사](debug-tests.log).
- [정적 분석](analyze.log): 0 issues.
- Godot 4.7.2 [효과 검사](godot.log): 6종 수명·정지·반복 프레임·만료·flame/frost 도형 억제·혼합 효과 순서·300개 입력의 256개 상한 통과. 처음 실행은 공용 프로젝트 import cache 부재로 실패했으며, 기존 prepare/import 후 정상 검증했다.
- 별도 작업량 비교 검사 통과. `git diff --check` 통과.

## Android 본게임 확인

ARM64 Android 17 에뮬레이터 `emulator-5554`, 1080×2424, Godot 4.7.2, release 메인 APK build 2004. 로컬 검수용 debug panel 포함, `adb install -r`로 앱 데이터 유지. APK 391.3MB. [빌드 로그](android-build.log), [최종 APK 해시](final-build.json).

스테이지 1의 저장된 상태에서 15웨이브 보상을 파편으로 수령하고 16웨이브 실제 전투를 확인했다. 기관총 spark·화염 사격, 기존 대포·피해 숫자·사망 효과가 함께 표시된다. 1× → 4× 전환 뒤에도 진행되며 메뉴를 열면 적 위치와 전투가 정지한다. 메뉴 정지 후 두 캡처에서 상태 유지, 닫은 뒤 전투 재개를 확인했다. 드론 전환·Android 홈→복귀 후 17웨이브 준비 상태에서 지난 착탄이 잔류하거나 다시 재생되지 않았다. 마지막은 메뉴 정지 상태로 두었다.

- [실제 1×/4× 전투 영상](combat.mp4) — 540×1212, 녹화 FPS는 성능 수치로 사용하지 않음.
- [1× 전투](combat-6.0.png), [4× 전투](combat-12.0.png), [전체 크기 전투 화면](combat-4x.png).
- [메뉴 정지](paused-later.png), [정지 유지](paused-stable.png), [복귀·효과 종료](resumed.png).
- 수집한 logcat에서 SCRIPT ERROR/Parse Error/FATAL EXCEPTION/Flutter 예외 없음.

6종 전체의 Android 전투 조합은 확인하지 않았다. 나머지 스타일은 수명·입력 동등성·기존 그리기 경로의 자동 검사로 확인했으며, 실제 Android 대표 상태 확인과 구분한다. shader/GLB의 작업 중 해시는 유지됐고 새 시각 자산은 없다. `input-hashes.json`은 이번 작업 중 기록한 입력이며 과거 시각 검수의 동일 조건 재현을 뜻하지 않는다. 공개 배포·커밋·푸시는 하지 않았다.
