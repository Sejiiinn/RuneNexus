# 피해 이벤트 collect 독립 검증

판정: **PASS**. 변경 전 원본을 별도 oracle로 실행하여 최종 구현과 53개 collect 시나리오, 951개 assertion을 비교했다. 생산 코드 수정 없이 격리된 Godot 4.7.2 headless 프로젝트에서 실행했다. 실패·미해결 결함 없음.

## 직접 검증한 계약

- `state` 전체, 반환 commands/ok, ACK, error, state revision, 누적 wall time, play-time 밀리초와 내부 소수 나머지가 원본과 정확히 같다. 0.2ms 누적, 중복 ACK, 역행·무한 wall 입력도 기존 결과를 유지했다.
- 59,999/60,000/60,001ms last-seen 경계, 300초 rollback 경계, 일/주 변경과 이전 날짜, 관련 키 누락, 출석 배열 추가를 비교했다.
- 배치 도중 실제 시간 콜백이 자정을 넘는 경우도 킬별 퀘스트 상태와 콜백 호출 횟수가 같다. 전역 now를 한 번만 재사용하여 킬별 시간 의미를 바꾸지 않는다.
- 정상/보스 킬, 없는 적·잘못된 적 정의의 실패, 성공한 prefix 이후 재시도, 잘못된 웨이브와 재시도, wave→core→kill 순서, 죽은 코어에서 웨이브 억제, terminal/success 보상 및 중복 finish, stale epoch 거절을 비교했다. 무작위 보상은 양쪽에 같은 seed를 설정했다.
- 각 실행 전에 보존한 **모든 과거 state의 nested 내용**과 입력 runtime이 그대로 유지된다. 같은 날 피해·중복 ACK 경로의 400개 모듈 synthetic inventory와 research dictionary는 이전/이후 `is_same`으로 공유됨을 확인했다. 전체 progression deep copy가 없는 경로를 값 비교와 별도로 확인한 것이다.

## 최종 소스 리뷰

`run_session.collect`는 state와 progression 상위 dictionary만 먼저 분리한다. play-time 쓰기는 scalar에 한정된다. `QuestProgress.needs_refresh`가 참이면 nested 전체를 분리한 뒤 기존 refresh 규칙을 실행한다. 킬 보상의 `award_kill_owned`는 scalar wallet만 수정하며, 킬 퀘스트 nested 쓰기 직전에 lazy deep copy가 수행된다. `complete_wave` 성공은 기존 `state.duplicate(true)` 결과를 사용한다. 종료 보상은 기존 `quests.finish`의 deep copy를 유지한다.

`needs_refresh`의 날짜·주차·rollback·last-seen·출석 조건은 기존 `refresh_owned`에서 값이 달라질 수 있는 경우를 포함한다. 이미 true인 rollback을 true로 다시 대입하는 no-op은 생략 가능하다. 피해 공식·런타임·표시 소스는 이번 변경 대상이 아니다.

## 근거

- [독립 실행 로그](independent-run.log): `INDEPENDENT_DAMAGE_COLLECT steps=53 checks=951 failures=[]`, 종료 코드 0.
- [독립 검사](independent-check.gd), [원본 collect oracle](independent-oracle-run.gd), [원본 quest oracle](independent-oracle-quest.gd).
- [최종 소스 SHA와 실행 정보](independent-inputs.json).
- 저장 전 정산과 실제 session/checkpoint 연결은 부모의 [통합 실행 로그](integration-run.log), [최종 소스 SHA](integration-inputs.json)를 결합한다. 해당 run/quest SHA는 독립 검증 최종 소스와 일치한다. 이를 독립 headless 검사가 실제 앱 화면을 재검증한 것으로 표현하지 않는다.

## 한계

실제 A34 프레임 시간·GPU·발열·FPS는 미측정이다. nested deep copy 제거 확인은 전체 앱 성능 개선율을 뜻하지 않는다. 초기 독립 실행은 반복 catalog 로딩으로 제한 시간에 종료되어 판정에 쓰지 않았다. fixture catalog를 공유하도록 검사만 정리한 뒤 위 최종 실행을 완료했으며 production 소스는 바꾸지 않았다.
