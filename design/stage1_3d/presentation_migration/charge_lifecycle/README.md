# 번개 충전 표시 이관 — 2026-09-19

`nativeChargeEffectEvents` 지원 확인 후 표시만 Godot 생성 이벤트로 전달한다. 기존 포탑 위치·조준각과 생성 시 포구 반경(size.x×0.58/타일 크기)으로 위치를 재현하므로 충전 좌표를 매 프레임 추가 전송하지 않는다. 기존 `_charge` 그리기와 투영은 유지한다.

Flame 컴포넌트는 실제 발사 타이머로 계속 갱신한다. isActive 판정→시간 진행→onRelease 순서를 유지하고, 표시 복귀 때 이 컴포넌트를 새로 만들거나 시간을 다시 진행하지 않는다. 정상 완료는 공용 시계로 표시를 끝내며 다른 효과의 세대를 바꾸지 않는다. 비활성·강제 제거는 journal 세대를 바꿔 취소하고 미ACK/프레임 병합 뒤 이전 시작 이벤트가 되살아나는 것을 막는다. 이미 만료된 충전은 뒤늦게 표시하지 않는다. owner 없는 기존 생성 경로와 미지원 runtime은 기존 snapshot을 유지한다.

## 작업량 비교

실제 RuneNexusGame update→frame→encode, 기본 수명 0.3초, 60Hz, 움직이는 포탑 위치, 매 프레임 즉시 ACK 조건. 동일한 10×6 테스트 맵에 실제 포탑을 등록했다. 측정에서 조준각은 고정했다.

| 조건 | Flame update 전→후 | 위치 콜백/스냅샷 전→후 | 전송 레코드 전→후 | effects JSON 전→후 |
| --- | ---: | ---: | ---: | ---: |
| 충전 1·포탑 1 | 18→18 | 19→1 | 18→1 | 8,550→2,775B |
| 충전 1·포탑 40 | 18→18 | 19→1 | 18→1 | 8,568→2,776B |
| 충전 8·포탑 8 | 144→144 | 152→8 | 144→8 | 52,288→5,938B |

모든 충전은 양 경로에서 18번째 프레임에 정확히 한 번 발사했다. 포탑 배열의 8필드 및 바이트는 전후 동일하다. 생성 시 owner 정보 51B/충전을 포함한다. 타이머 CPU 작업이나 컴포넌트 생성을 제거한 결과가 아니다. ACK 지연과 취소 시 다른 살아 있는 이벤트 재전송 비용이 남으며, 전체 frame·CPU/Godot/GPU 시간·FPS·실기기 지속 성능은 미측정이다. [원자료](work-results.json), [측정 코드](measure_work.dart).

## 검증

관련 Dart 52 PASS/기존 skip 1, flutter analyze 0 issues, Godot 4.7.2 effects 및 presentation protocol PASS, diff 검사 PASS. 실제 widget capability 활성/철회, 동일 타이머 유지·중복 발사 방지, pause/4×/resize 복귀, 미ACK 시작 취소·다른 이벤트 유지, 정상 종료 시 세대 불변, 포탑 각도 기반 위치·owner 제거·만료 충전 재생 방지를 검사했다.

추가 실행한 기존 balance 테스트 `chain lightning hits sequential targets with delayed jumps`는 Flame OrderedSet ConcurrentModificationError로 실패했다. 작업트리를 바꾸지 않고 HEAD의 lib/test를 별도 임시 프로젝트에 복사해 같은 의존성으로 실행했으며 동일 실패를 재현했다. 이번 충전/미커밋 연쇄선 변경으로 발생한 실패가 아니며 해당 기존 테스트를 수정하지 않았다. [현행 로그](existing-balance-current.log), [HEAD 기준선 로그](existing-balance-head.log).

## Android 본게임 확인

일반 main.dart ARM64 release 로컬 검수 빌드 2008, Android 17 에뮬레이터에서 기존 빌드 2007과 같은 18웨이브 저장 fixture로 확인했다. 1배속에서 회전한 포구의 청록색 충전 원·짧은 선과 번개 발사 연결을 확인하고, 4배속·스테이지 메뉴 열기/닫기·백그라운드 복귀 후 표시도 확인했다. 메뉴의 정지된 충전 프레임 자체를 별도로 판정한 것은 아니며 pause 시간 계약은 자동 검사로 확인했다. 짧은 충전 구간은 초기 영상 표본에서 빠졌지만 15~16초 구간에서 확인된다. `_charge`와 `effect_transform` 구현 해시는 변경 전과 동일하다. [변경 전](before.png), [최종 충전·발사](final.png), [4배속](final-4x.png), [영상](final.mp4).

APK 391,254,186B로 직전 로컬 빌드보다 736B 증가했다. 공개 배포 비교나 실기기 FPS 측정은 아니다. 실행 로그에 FATAL EXCEPTION·SCRIPT ERROR·Parse Error·Unhandled Exception은 없었다. 검수 후 원본 저장과 백업을 바이트 단위로 복원하고 로비로 재실행했다.
