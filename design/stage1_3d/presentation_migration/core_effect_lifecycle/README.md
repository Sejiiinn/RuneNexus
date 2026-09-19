# 코어 빔·균열 파동 수명 이관 — 2026-09-19

`nativeLinkedEffectEvents` 지원 확인 뒤 생성 이벤트·대상 ID와 공용 전투 시계로 Godot이 수명·추적을 관리한다. 연결 대상인 적에만 논리 좌표를 추가하고 기존 시각 offset은 사용하지 않는다. 빔은 마지막 수신 생존 위치를 유지하며 최초 전달 전 사망은 생성 위치를 유지한다. 균열은 사라진 대상의 연결선을 제거한다. 기존 피해·낙인 판정·개별 duration·그리기 함수는 유지했다.

구형 runtime은 기존 snapshot을 유지한다. ACK 후 생성 입력 재전송을 멈추며, 정지·배속·지원 철회·2D 복귀·리사이즈는 기존 공용 시계/세대 계약을 따른다. 복귀용 Component 객체는 보관하므로 객체 생성 자체를 없앤 변경은 아니다.

## 작업량

실제 RuneNexusGame update→frame→encode, 기본 수명(빔 0.14초/균열 0.42초), 60Hz, 이동 대상, 매 프레임 즉시 ACK 조건이다. 아래 바이트는 effects JSON과 추가 논리 좌표 비용의 합이다.

| 조건 | Flame update 전→후 | 효과 snapshot 생성 전→후 | 관련 JSON 전→후 |
| --- | ---: | ---: | ---: |
| 빔 1·적 1 | 9→0 | 10→1 | 5,104→2,133B |
| 빔 1·적 40 | 9→0 | 10→1 | 5,104→2,133B |
| 균열 1·대상 4 | 26→0 | 27→1 | 16,291→7,868B |
| 빔 4·균열 2·공유 대상 4 | 88→0 | 94→6 | 44,737→10,447B |

비대상 적에는 추가 좌표가 없다. 전체 enemy 배열까지 포함하면 빔 1·적 40 조건은 59,096→56,125B다. 최초 생성 입력은 추가 정보로 커질 수 있고 ACK 지연 때 반복 전송이 남는다. 전체 프레임·CPU 시간·Godot/GPU 시간·FPS·실기기 지속 성능은 미측정이다.

## 검증

관련 Dart 44 PASS/기존 skip 1, 마지막 수정의 integration 26 PASS와 추가 회귀 검사 PASS. 실제 widget의 capability 활성/ACK/철회, 움직이는 논리 좌표, 대상 사망/첫 전달 전 사망, 고정 종료점, 균열 링크 제거, 정지/배속/리사이즈 복원 포함. `flutter analyze` 0 issues. Godot 4.7.2 import 및 `verify_battlefield_effects.gd` PASS. 기존 `_beam`, `_rift`, `_local_points`, `effect_transform` 함수 해시 동일.

Android 17 ARM64 에뮬레이터(1080×2424), 일반 `main.dart` release build 2006에서 스테이지 1/18~19웨이브를 확인했다. 기존 진행을 백업하고 빔/균열의 테스트 저장을 각각 재사용했다. 1× 빔·균열 표시와 연결 대상의 이동, 효과 종료, 메뉴 정지 후 화면 유지·재개, 4× 전투, 홈→앱 복귀를 확인했다. 메뉴 직후 대기 중인 전장 프레임이 적용된 다음 빔·적의 정지 상태가 유지됐다. 영상은 540×1212이며 픽셀 시점·난수나 FPS 비교용이 아니다. 수집 logcat에 SCRIPT ERROR/Parse Error/FATAL EXCEPTION/Flutter 예외 없음.

- [코어 빔 실제 화면](beam-final.png), [정지 유지](beam-paused-settled.png), [이후 정지 화면](beam-paused-settled-later.png).
- [균열 파동 실제 화면](rift-final.png), [종료 후](rift-ended.png).
- [작업량 원자료](work-results.json), [측정 코드](measure_work.dart), [최종 APK 정보](final-build.json).

APK 391,252,346B로 직전 로컬 build 2005보다 560B 증가했다. 새 에셋·의존성 추가 없음. 검수 후 원본 primary/backup 저장 파일을 바이트 단위로 복원하고 로비에 두었다. 원자료·스크립트·로그·캡처·영상은 로컬 검수 자료이며 자동 커밋하지 않는다. 커밋·푸시·공개 배포는 하지 않았다.
