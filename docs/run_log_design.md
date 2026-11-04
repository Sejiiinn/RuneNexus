# 런 기록 수집 설계

역할: 런이 끝날 때 플레이 요약 한 건을 서버에 남겨 스테이지 난이도·포탑 배치·실패 원인을 분석하는 기능의 결정과 계약. 정리: 2026-11-04 KST.
상태: 구현, 미배포([배포 인계](deployment_status.md#현재-미배포-변경)). 계획 결정은 [TODO](TODO.md#플레이-기록-체계화)에 있다.

## 배경

지금 서버에 남는 런 정보는 `economy_runs`와 `run_settlement` 명령(스테이지·도달 라운드·성공·다이아)뿐이다. 포탑 배치가 담긴 진행 중 런 저장(`save_active_runs`)은 런이 끝나면 지운다. 그래서 유저가 어떤 포탑을 어디에 지었는지, 무엇에 뚫렸는지 알 수 없다.

## 결정

- 런이 끝나고 그 런의 정산 응답을 받으면, 요약 한 건을 기록 API로 **한 번** 보낸다. 실패하면 버린다. 대기열·재시도는 두지 않는다. 정산 직후라 네트워크가 살아 있는 경우가 대부분이고, 분석용이라 일부 누락은 허용한다.
- 분석 전용이다. 보상·순위·도전과제·경제 판정에 쓰지 않는다. 서버는 크기와 기본 형식만 검사하고 본문을 그대로 저장한다.
- 계정에 묶는다(게스트 없음). 탈퇴를 요청하면 그 계정의 기록을 지운다.
- 체감 지연과 부작용이 없어야 한다. 결과 화면·보상 표시·다음 판 시작은 전송을 기다리지 않는다. 전송은 기존 `AccountSession.request()`를 쓰지 않는다. 그 경로는 네트워크 실패·401·5xx를 인증 실패로 보고 세션을 끝낼 수 있기 때문이다. 현재 액세스 토큰만 읽어 HTTP 전송기로 직접 보내고, 결과는 어디에도 전달하지 않는다.
- 포탑 항목 키는 [밸런스 벤치 봇](../tool/balance_benchmark/README.md)의 런 결과와 같게 해 봇과 같은 스크립트로 비교한다.

## 기록 내용

ID는 콘텐츠·저장의 내부 ID를 그대로 쓴다. 스테이지는 고정 ID이며 분석할 때 화면 번호(예: 3-2)로 바꾼다. 한 건은 포탑 15~25기 기준 약 4~6KB다.

| 필드 | 내용 |
| --- | --- |
| `schemaVersion`, `runId`, `clientBuild` | 1, 런 상태 `economyRunId`, 앱 버전 코드 |
| `stageId`, `difficulty`, `success`, `completedRounds`, `waveCount`, `coreHp`, `coreHpMax`, `resumed` | 종료 시점 런 결과. `resumed`는 앱 재시작 후 이어 한 런 |
| `challengeMet`, `peakTurrets`, `turretTypesUsed` | 도전 판정과 최대 동시 포탑 수·사용 종류 |
| `arrivals`: `{"type:rarity": count}` | 이번 세션에 코어에 닿은 적 수. 앱을 재시작해 이어 하면 재시작 전 도달은 빠진다 |
| `turrets`: `[{type, x, y, level, gems, primaryTrait, secondaryTrait, targetPriority, damage}]` | 최종 배치. `damage`는 결과 화면과 같은 런타임 누적 피해(직접·범위·연쇄·지속 합) |
| `supportCores`: `[{x, y, family}]` | 지원 코어 배치 |
| `upgradeLevels`, `researchLevels`, `coreNodeRanks`, `totalCorePoints`, `moduleCount`, `clearedStages` | 종료 시점 계정 수준 합계 |

닉네임·기기 정보·위치·광고 ID는 보내지 않는다. 계정은 인증 토큰으로 서버가 정한다.

## 서버

- `POST /v1/telemetry/run-logs`, 계정 인증. 본문 32KiB 초과는 400. 계정당 분당 20건(기존 토큰 버킷 방식), 초과는 429.
- 검사: JSON 객체, `schemaVersion`=1, UUID `runId`, 정수 `stageId`(1~9999), 정수 `clientBuild`(0 이상). 나머지는 검사하지 않고 `payload`로 저장한다.
- `run_logs` 테이블: `account_id`(accounts 참조, `ON DELETE CASCADE`), `run_id`, `received_at`, `client_build`, `stage_id`, `payload JSONB`, 기본 키 `(account_id, run_id)`. 같은 런은 `ON CONFLICT DO NOTHING`. 응답은 항상 200 `{"code":"OK"}`.
- 탈퇴: `accounts.deletion_requested_at`이 기록되면 트리거가 그 계정의 `run_logs`를 지운다. 저장은 계정 행을 `FOR SHARE`로 잠근 뒤 탈퇴 요청이 없을 때만 하므로 탈퇴 처리와 겹쳐도 다시 남지 않는다. 계정 행 삭제는 `ON DELETE CASCADE`.
- 보관: 180일. 서버 주기 작업이 지난 기록을 지운다.

## 분석

운영자가 읽기 전용 질의로 `run_logs`를 내보내 로컬에서 집계한다(스테이지별 클리어율·실패 웨이브·도달 적·포탑 사용률과 피해 비중·배치 분포). 내보낸 자료는 커밋하지 않는다. 분석 스크립트는 필요할 때 만든다.

## 배포 선행 조건

- 계정에 묶인 플레이 기록이므로 개인정보처리방침에 수집 항목·목적·보관 기간을 적어 게시한 뒤 앱을 배포한다. 저장소와 앱에는 방침이 아직 없으며 작성·게시는 사용자 담당이다. Google Play로 옮기면 데이터 보안의 '앱 활동'도 신고한다.
- 서버를 먼저 배포한다. 이전 서버에 보낸 기록은 404로 버려진다.

## 구현과 검증

- 서버: `server/internal/runlog`, `server/internal/httpapi/run_log.go`, `server/db/migrations/024_run_logs.sql`. 클라이언트: `godot/app/run_log.gd`(생성), `godot/session/run_session.gd`(도달 집계·종료 시 생성·정산된 기록 수거), `godot/services/app_services.gd`(`_send_settled_run_logs`).
- 서버: `internal/runlog`·`internal/httpapi` 단위 검사(인증 없음 401, 크기 초과·형식 오류 400, 저장 200), DB 통합 검사 `run_log_integration_test.go`(중복 1건, 180일 정리, 탈퇴 요청 시 삭제·이후 미저장, 탈퇴 처리와 겹친 업로드의 대기·미저장).
- 클라이언트: `godot/tests/verify_run_log.gd`(`run_godot_project_checks.py`) — 실제 ARRIVAL 이벤트 집계, 런타임 피해 합, 한 번만 생성, 정산된 런만 전송, 응답하지 않는 서버에도 즉시 반환, `AccountSession.request()` 미사용, 다른 계정 Outbox에서는 전송하지 않음.
