# Rune Nexus 다중 기기 온라인 저장 상세 설계

문서 상태: 채택 설계, 1·2차 핵심 구현 완료
마지막 갱신: 2026-08-27
상위 문서: `docs/backend_architecture.md`

## 1. 결정

Rune Nexus 계정은 여러 기기에서 로그인할 수 있다. 다만 계정 저장을 동시에 쓰는
게임 세션은 하나만 허용한다. 서버가 저장의 단일 기준이며, 클라이언트의 저장 시각은
동기화 순서를 결정하는 데 사용하지 않는다.

동기화의 핵심 규칙은 다음과 같다.

1. 저장 순서는 서버 `revision`으로만 판단한다.
2. 한 계정에서 현재 `writerGeneration`을 가진 인증 세션만 새 저장을 쓸 수 있다.
3. 결과가 불명확한 in-flight 요청은 같은 본문과 idempotency key로 먼저 재시도한다.
4. 그 요청이 서버에 반영되지 않았고 원격 revision이 로컬 기준보다 앞서면 원격을
   자동 적용한다.
5. 사용자에게 로컬·원격 저장 중 하나를 고르게 하지 않는다.
6. 폐기되는 로컬 진행은 원격 적용 전에 복구용 backup으로 남기되 일반 UI의 선택지로
   노출하지 않는다.

이 정책은 마지막 저장 시각 기준 last-write-wins가 아니다. 서버가 원자적으로 승인해
증가시킨 revision을 기준으로 하는 **server-revision-wins** 정책이다.

## 2. 목표와 비목표

### 목표

- 휴대폰, 태블릿, Web 등 여러 기기에서 같은 계정 진행을 이어서 플레이한다.
- 느린 연결이나 일시적인 서버 장애가 일반 로컬 플레이를 즉시 막지 않는다.
- 동시에 도착한 전체 스냅샷이 서로를 조용히 덮어쓰지 못하게 한다.
- 응답 유실과 실제 다중 기기 충돌을 구분한다.
- 충돌 해결을 사용자에게 떠넘기지 않고 결정적인 정책으로 자동 복구한다.
- 큰 저장 JSON이 원격에서 바뀌지 않았으면 다시 내려받지 않는다.
- 유료 재화와 중요 경제 데이터의 서버 권위 확장 경계를 유지한다.

### 비목표

- 두 기기의 서로 다른 오프라인 진행 병합
- 여러 기기의 동시 플레이 결과를 모두 보존하는 협업 저장
- 클라이언트 저장 스냅샷만으로 치트를 방지하는 것
- 전투 프레임이나 일반 조작을 실시간 서버에서 처리하는 것
- 충돌 저장을 사용자가 고르는 UI
- 저장 동기화를 위한 WebSocket 도입

두 기기가 같은 기준 revision에서 서로 다른 오프라인 진행을 만들면 두 진행을 모두
보존할 수 없다. 병합과 사용자 선택을 제공하지 않는 대신, 서버에 먼저 승인된 진행을
계정 진행으로 유지하고 나중에 연결된 기기의 분기는 backup 후 폐기한다.

## 3. 용어

| 용어 | 의미 |
| --- | --- |
| remote revision | 서버가 정상 저장 트랜잭션마다 1씩 증가시키는 계정 저장 버전 |
| base revision | 로컬 account 슬롯이 마지막으로 확인한 원격 revision |
| writer generation | 현재 저장 작성 세션을 구분하는 서버 발급 세대 번호 |
| account local | 원격 계정 진행의 로컬 캐시이자 오프라인 플레이 원본 |
| guest local | 계정에 연결되지 않은 기기 전용 진행 |
| in-flight | HTTP 결과를 아직 확정하지 못한 정확한 저장 요청 하나 |
| dirty | base revision 이후 서버에 반영되지 않은 로컬 체크포인트가 있음 |
| rebase | 원격 최신 저장을 account local에 적용하고 Outbox 기준을 바꾸는 작업 |
| client instance ID | 설치 또는 브라우저 프로필을 구분하는 비밀이 아닌 진단용 UUID |
| client compatibility version | 서버 저장 계약에 안전하게 쓸 수 있는 클라이언트 세대 정수 |
| client build | Web Git SHA 또는 앱 버전처럼 배포물을 식별하는 진단용 문자열 |

## 4. 불변 조건

구현은 다음 조건을 항상 지켜야 한다.

1. 서버 저장 갱신은 `expectedRevision == currentRevision`일 때만 성공한다.
2. 저장 갱신 트랜잭션 안에서 모든 JSONB 영역, revision과 요청 영수증이 함께 반영된다.
3. 새 저장은 현재 인증 session과 `writerGeneration`이 모두 일치할 때만 허용한다.
4. 이미 성공한 idempotency key의 재시도는 writer가 교체됐더라도 기존 성공 결과를
   반환한다.
5. 서로 다른 본문 또는 writer generation에 같은 idempotency key를 재사용하지 않는다.
6. in-flight 본문을 새 로컬 데이터로 다시 인코딩하지 않는다.
7. 원격 적용 전에 기존 account local을 backup한다.
8. rebase 도중 종료된 클라이언트는 재시작 후 업로드부터 하지 않고 rebase를 먼저
   완료한다.
9. account ID가 다른 로컬 슬롯과 Outbox는 절대 함께 사용하지 않는다.
10. `savedAtMillis`와 기기 시각은 충돌 승자를 결정하지 않는다.
11. 유료 재화가 서버 권위로 전환된 뒤에는 스냅샷 값으로 서버 잔액을 덮어쓰지 않는다.
12. 서버 최소 호환 버전보다 오래된 클라이언트는 writer 획득과 저장 PUT을 모두 쓸 수
    없다.

## 5. 전체 흐름

### 정상 시작

```text
Google/PGS 로그인
  -> account별 로컬 저장과 Outbox 복구
  -> 남은 exact in-flight 요청 1회 재확인
  -> writer generation 획득
  -> base revision을 사용한 조건부 GET /v1/save
  -> 원격이 같으면 로컬 계속 사용
  -> 원격이 앞서면 backup 후 원격 자동 적용
  -> account 플레이 시작
```

### 정상 저장

```text
중요 체크포인트
  -> account local 통파일 저장
  -> Outbox dirty/generation 영속
  -> exact request body + key + writer generation 영속
  -> PUT /v1/save
  -> 서버 writer/revision 검사와 전체 트랜잭션
  -> ack revision을 Outbox에 반영
```

HTTP 완료는 플레이 체크포인트의 완료 조건이 아니다. 로컬 저장과 durable enqueue가
끝나면 플레이를 계속하고 네트워크 전송은 단일 worker가 처리한다.

### 다른 기기가 먼저 저장한 경우

```text
기기 A: base revision 12, 오프라인 진행
기기 B: writer generation 8 획득
기기 B: expected revision 12 저장 -> revision 13
기기 A: 연결 복구
기기 A: 남은 exact in-flight 재시도
  -> 과거 성공 영수증이 없고 writer가 바뀌었으므로 거부
기기 A: 새 writer generation 9 획득 후 원격 조회
  -> remote 13 > local base 12
기기 A: 로컬 backup -> remote 13 적용 -> Outbox 재기준화
```

## 6. 서버 writer generation

revision만으로도 오래된 저장의 덮어쓰기는 막을 수 있다. 그러나 두 기기가 계속
번갈아 저장하면 매번 한쪽이 409를 받고 원격을 다시 적용하는 현상이 반복될 수 있다.
writer generation은 이 반복을 줄이고 현재 계정 플레이의 작성자를 명확히 한다.

### 획득 시점

- 로그인 성공만으로 writer를 획득하지 않는다.
- 계정 진행으로 플레이를 시작하거나 앱이 foreground에서 계정 진행을 재개할 때
  획득한다.
- 백그라운드 retry worker는 `SAVE_WRITER_REPLACED`를 받은 뒤 writer를 자동 탈환하지
  않는다.
- 사용자가 해당 기기의 계정 플레이로 실제 복귀할 때만 새 generation을 획득한다.

### 효력

- 새 generation이 발급되면 이전 generation은 즉시 새 저장을 쓸 수 없다.
- 이전 인증 session 자체를 로그아웃시키지는 않는다.
- 이전 session은 원격 조회와 인증된 일반 API를 사용할 수 있다.
- 이전 session의 이미 성공한 저장 요청 재시도는 요청 영수증으로 성공을 확인할 수 있다.
- 이전 session에서 아직 성공하지 않은 요청은 원격 진행으로 rebase한다.

### 실시간 알림을 하지 않는 이유

이전 기기에 writer 교체를 push하지 않는다. 다음 저장 요청, 앱 resume 또는 명시적
동기화 시점에 교체 사실을 알게 된다. 현재 게임은 실시간 PvP가 아니고 중요 이벤트
체크포인트에서만 서버 저장하므로 WebSocket 비용을 정당화하지 못한다.

## 7. API 계약 변경

### 7.1 writer 획득

`POST /v1/save/writer`

```http
Authorization: Bearer <access-token>
Idempotency-Key: <UUID>
Content-Type: application/json
```

```json
{
  "clientInstanceId": "019...",
  "saveSchemaVersion": 2,
  "clientCompatibilityVersion": 1,
  "clientBuild": "web-git-sha-or-app-version"
}
```

성공 응답:

```json
{
  "writerGeneration": 8,
  "claimedAt": "2026-08-25T03:00:00Z"
}
```

규칙:

- 새 idempotency key이면 account writer generation을 1 증가시킨다.
- 같은 key와 같은 요청을 재시도하면 같은 generation을 반환한다.
- 같은 key의 본문이 다르면 `409 IDEMPOTENCY_KEY_REUSED`를 반환한다.
- 지원하지 않는 구버전 클라이언트는 generation을 교체하기 전에 거부한다.
- `clientInstanceId`는 진단 정보이며 인증 수단으로 신뢰하지 않는다.
- 과도한 writer 교체는 account/session 단위 rate limit과 위험 로그 대상으로 삼는다.

### 7.2 조건부 저장 조회

기존 `GET /v1/save`에 ETag를 추가한다.

```http
GET /v1/save
Authorization: Bearer <access-token>
If-None-Match: "rn-save-12"
```

처리:

- 원격 저장이 없으면 `404 SAVE_NOT_FOUND`
- 현재 revision이 12이면 `304 Not Modified`, body 없음
- 현재 revision이 다르면 `200`과 전체 저장 body
- 완전한 저장 응답에는 `ETag: "rn-save-<revision>"` 설정
- 응답 캐시는 `Cache-Control: private, no-cache`

ETag는 저장 내용 해시가 아니라 revision validator다. 이를 사용하면 저장 JSON이 커도
원격이 변하지 않은 정상 시작에서는 전체 JSON을 다시 내려받지 않는다.

### 7.3 저장 갱신

기존 `PUT /v1/save`에 writer generation header를 추가한다.

```http
PUT /v1/save
Authorization: Bearer <access-token>
Idempotency-Key: <UUID>
Rune-Nexus-Save-Writer: 8
Content-Type: application/json
```

```json
{
  "expectedRevision": 12,
  "clientCompatibilityVersion": 1,
  "data": {}
}
```

body의 `expectedRevision`과 전체 `data` 계약은 유지한다. 호환성 검사는 writer
generation뿐 아니라 이미 writer를 가진 장시간 실행 클라이언트의 PUT에도 적용한다.

서버 검사 순서는 다음과 같다.

```text
1. account + idempotency key 영수증 빠른 조회
2. 영수증이 있으면 body hash와 writer generation 확인 후 기존 결과 반환
3. writer state 행 잠금
4. save header 행 준비와 잠금
5. 영수증 재조회
6. 현재 auth session + writer generation 검사
7. expected revision 검사
8. 저장 영역, revision, 영수증을 같은 트랜잭션에 기록
```

writer 검사보다 영수증 조회가 먼저다. 저장 성공 후 응답만 유실된 사이 다른 기기가
writer를 획득했더라도, 이전 기기의 exact retry에는 기존 성공 결과를 반환해야 한다.

성공 응답에는 기존 body와 함께 `ETag: "rn-save-<new revision>"`을 설정한다.

### 7.4 오류 코드

| HTTP | 코드 | 클라이언트 처리 |
| --- | --- | --- |
| `409` | `SAVE_REVISION_CONFLICT` | exact 요청 결과 확인 후 원격 조회·자동 rebase |
| `409` | `SAVE_WRITER_REPLACED` | 자동 writer 탈환 금지, account 플레이 정지 후 원격 재확인 |
| `409` | `IDEMPOTENCY_KEY_REUSED` | blocked, 자동 재시도 금지 |
| `426` | `CLIENT_UPDATE_REQUIRED` | exact 요청 보존, 로컬 저장·계정 플레이 정지, 업데이트 안내 |
| `422` | `SAVE_VERSION_UNSUPPORTED` | blocked, 앱 업데이트 안내 |
| `422` | `SAVE_CLIENT_VERSION_UNSUPPORTED` | 서버보다 미래 세대 클라이언트이므로 blocked |
| `428` | `SAVE_WRITER_REQUIRED` | foreground 계정 플레이에서 writer 획득 후 재시도 |
| `404` | `SAVE_NOT_FOUND` | base 0에서만 최초 저장 가능 |

`SAVE_WRITER_REPLACED` 응답에는 현재 generation 숫자만 선택적으로 포함하고 현재
writer의 session ID나 기기 정보는 노출하지 않는다.

### 7.5 CORS

GitHub Pages Web 클라이언트를 위해 다음 header를 CORS allow/expose 목록에 포함한다.

- request: `Authorization`, `Content-Type`, `Idempotency-Key`,
  `If-None-Match`, `Rune-Nexus-Save-Writer`
- response: `ETag`, `X-Request-ID`, `Retry-After`

## 8. PostgreSQL 스키마 추가

기존 `save_headers`, 영역 테이블과 `save_requests`는 유지한다.

### save_writer_states

```text
save_writer_states
- account_id UUID PK FK accounts(id) ON DELETE CASCADE
- generation BIGINT NOT NULL DEFAULT 0
- session_id UUID NULL FK sessions(id) ON DELETE SET NULL
- client_instance_id UUID NULL
- claimed_at TIMESTAMPTZ NULL
- updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
- CHECK generation >= 0
```

writer가 한 번도 발급되지 않은 account는 generation 0이다. 실제 저장 PUT은
generation 1 이상을 요구한다. session과 account가 같은지는 인증 principal과
트랜잭션 service에서 검사하고 통합 테스트로 고정한다.

### save_writer_claims

```text
save_writer_claims
- account_id UUID NOT NULL FK accounts(id) ON DELETE CASCADE
- idempotency_key UUID NOT NULL
- session_id UUID NOT NULL FK sessions(id) ON DELETE CASCADE
- client_instance_id UUID NOT NULL
- request_hash BYTEA NOT NULL
- resulting_generation BIGINT NOT NULL
- result_claimed_at TIMESTAMPTZ NOT NULL
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- PRIMARY KEY(account_id, idempotency_key)
- UNIQUE(account_id, resulting_generation)
- CHECK octet_length(request_hash) = 32
- CHECK resulting_generation > 0
```

claim 영수증은 writer 획득 응답 유실 뒤 같은 generation을 돌려주기 위해 필요하다.
보존 기간은 클라이언트의 최대 재시도 기간보다 길게 두며, 운영 정리 정책은 기존
`save_requests` 영수증과 함께 관리한다.

### save_requests 확장

```text
save_requests
+ writer_generation BIGINT NOT NULL
+ CHECK writer_generation > 0
```

같은 idempotency key가 다른 writer generation으로 재사용되는 것도 key 재사용 오류로
처리한다. 이미 기록된 영수증의 성공 결과 반환은 현재 writer 여부와 무관하다.

### 잠금 순서

동시 claim과 저장의 교착을 막기 위해 모든 저장 쓰기 트랜잭션은 다음 순서를 따른다.

```text
save_writer_states FOR UPDATE
  -> save_headers FOR UPDATE
  -> 저장 영역과 영수증
```

writer claim은 `save_writer_states`만 잠근다. 동일 account의 저장이 먼저 잠금을 잡으면
그 저장이 커밋된 뒤 generation이 교체되고, claim이 먼저 잡으면 이전 writer 저장은
거부된다.

## 9. 클라이언트 영속 동기화 상태

계정별 Outbox 상태를 다음 개념으로 확장한다.

```text
version: 1
accountIdBinding
clientInstanceId
writerGeneration: nullable
writerClaim:
  idempotencyKey
  encodedRequestBody
baseRevision
basePayloadHash
localGeneration
dirty
inFlight:
  idempotencyKey
  writerGeneration
  expectedRevision
  encodedRequestBody
  payloadHash
  localGeneration
rebase:
  targetRevision
  targetPayloadHash
  stage
phase
retryKind
retryCount
nextRetryAt
lastSyncedAt
issueCode
```

### payload hash

- `GameSaveData.toJson()`의 고정된 key 순서로 만든 UTF-8 JSON에 SHA-256을 사용한다.
- 현재의 빠른 fingerprint는 중복 전송 억제 보조값으로는 쓸 수 있지만, 로컬 진행
  폐기 여부를 결정하는 근거로 사용하지 않는다.
- hash는 캐시·crash 복구용이며 서버의 인증 또는 치트 방지 수단이 아니다.
- 동시성의 최종 기준은 언제나 revision과 writer generation이다.

### persistent phase

```text
idle
sending
retryWaiting
rebasing
suspended
blocked
```

- `rebasing`: 원격 우선이 확정되어 로컬 backup·교체를 진행 중
- `suspended`: 다른 writer가 활성화되어 이 인스턴스가 계정 저장을 쓸 수 없음
- `blocked`: 손상, 지원하지 않는 버전, idempotency 위반처럼 자동 복구하면 안 되는 상태

`activating`, `fetchingRemote` 같은 짧은 네트워크 단계는 메모리 상태로만 둘 수 있지만,
rebase 단계는 종료 복구를 위해 반드시 영속화한다.

## 10. 시작·재개 판정표

로그인 또는 영속 인증 세션 복원 후 다음 순서를 지킨다. 현재 Web·Android 앱은 세션
판정을 저장 bootstrap보다 먼저 수행한다. 복원 실패를 세션 없음으로 취급하지 않으며,
자동 복원은 guest 저장을 읽거나 복사하지 않는다. 인증 계약은
[백엔드 아키텍처](backend_architecture.md)의 자체 세션 절을 따른다.

1. account local과 Outbox를 읽는다.
2. 남은 in-flight가 있으면 정확한 요청을 먼저 한 번 재시도한다.
3. foreground 계정 플레이 의도라면 writer generation을 획득한다.
4. base revision ETag로 원격 저장을 조건부 조회한다.
5. 아래 표에 따라 처리한다.

| 원격 상태 | 로컬 상태 | 처리 |
| --- | --- | --- |
| 없음 | base 0, 로컬 있음 | 최초 업로드 대상으로 dirty 설정 |
| 없음 | base 0, 로컬 없음 | 새 계정 진행 생성 |
| 없음 | base > 0 | 서버 rollback 또는 환경 혼선으로 blocked |
| `304`, local hash = base hash | clean | 그대로 시작 |
| `304`, local hash != base hash | dirty 복구 후 조건부 업로드 |
| remote revision = base | dirty/in-flight 없음, hash 일치 | 그대로 시작 |
| remote revision = base | 로컬 hash가 다름 | dirty 복구 후 조건부 업로드 |
| remote revision > base | 상태 무관 | 로컬 backup 후 원격 자동 rebase |
| remote revision < base | 상태 무관 | blocked, 자동 업로드 금지 |
| 같은 revision인데 원격 hash != 알려진 base hash | 상태 무관 | 서버 불변 조건 위반으로 blocked |

마지막 행은 일반 충돌이 아니다. revision 증가 없이 서버 payload가 변했거나 로컬
metadata가 손상된 경우이므로 조용히 덮어쓰지 않고 진단 대상으로 남긴다.

## 11. in-flight 우선 복구

원격 우선 판정을 하기 전에 in-flight 요청을 먼저 확인해야 한다.

### 서버에 이미 반영된 경우

```text
PUT key A, expected 12 전송
서버 revision 13 커밋
응답 유실
다른 기기가 writer 획득
key A exact retry
서버 영수증 조회 -> revision 13 성공 반환
```

클라이언트는 이를 충돌로 처리하지 않고 ack로 반영한다. 이후 GET에서 revision 14가
발견되면 14를 원격 최신으로 적용한다.

### 서버에 반영되지 않은 경우

exact retry가 `SAVE_REVISION_CONFLICT`를 반환하면 성공 영수증이 없고 원격 revision이
이미 앞섰다는 뜻이다. 이 요청과 최신 dirty 저장을 backup 대상으로 표시한 뒤 원격
rebase를 시작한다.

`SAVE_WRITER_REPLACED`는 다른 session이 writer를 획득했다는 뜻일 뿐 원격 저장이
실제로 전진했다는 뜻은 아니다. account 플레이를 `suspended`로 바꾸고 자동 writer
탈환을 멈춘 뒤 원격을 조회한다.

- 원격 revision이 base보다 앞섰으면 backup 후 원격 rebase한다.
- 원격 revision이 base와 같으면 미전송 로컬을 폐기하지 않고 suspended 상태로
  보존한다.
- 사용자가 이 기기에서 account 플레이를 다시 시작할 때 새 writer generation을
  획득하고, 원격이 여전히 같은 base면 최신 로컬을 새 key/generation으로 전송한다.
- 재시작 시점에 원격이 앞서졌다면 그때 원격 rebase한다.

네트워크 오류로 성공 여부를 여전히 알 수 없으면 in-flight를 버리지 않는다. 같은
본문·key·writer generation으로 backoff 재시도한다.

## 12. 자동 rebase와 crash consistency

원격 적용은 다음 영속 단계로 수행한다.

```text
1. 원격 전체 payload 검증과 SHA-256 계산
2. Outbox에 rebase(target revision/hash, stage=prepared) 기록
3. 현재 account local을 backup으로 보존
4. rebase stage=backupPreserved 기록
5. 원격 payload를 account primary에 원자적 저장
6. rebase stage=payloadApplied 기록
7. Outbox를 target revision/hash 기준 clean 상태로 재설정
8. rebase marker 제거
9. 게임 상태를 안전 지점에서 새 account local로 다시 생성
```

재시작 복구:

- `prepared`: backup을 아직 만들지 않았으면 만들고 계속한다.
- `backupPreserved`: 원격을 다시 GET한 뒤 primary 적용부터 반복한다.
- `payloadApplied`: 로컬 hash가 target과 같은지 확인하고 Outbox 재설정부터 계속한다.
- marker가 있는 동안에는 로컬 checkpoint를 온라인으로 보내지 않는다.

같은 rebase를 반복할 때 기존 충돌 backup을 원격 payload로 덮지 않도록 backup 완료
단계를 별도로 기록한다.

### backup 보존

- 일반 primary/backup 회전과 별도로 최근 충돌 backup 1개를 보존한다.
- metadata에는 account ID, 로컬 base revision, 발견한 remote revision, 생성 시각과
  payload hash만 기록한다.
- token, Google ID token과 전체 HTTP 응답은 기록하지 않는다.
- backup은 일반 사용자 선택 UI에 노출하지 않고 운영 복구 또는 개발 진단에만 쓴다.
- Web 저장 용량이 부족하면 원격 적용을 진행하기 전에 명시적으로 blocked 처리한다.
  backup 실패 상태에서 원본을 덮어쓰지 않는다.

현재 Web Local Storage는 account primary·backup과 Outbox exact body까지 여러 전체
JSON 복사본을 가질 수 있다. 실제 저장 크기가 증가하면 충돌 backup 도입과 함께
IndexedDB로 옮기는 것을 구현 선행 조건으로 삼는다.

## 13. 게임 실행 중 충돌 UX

원격 저장을 전투 상태에 즉시 덮어쓰지 않는다.

### 메뉴 또는 로딩 화면

- 즉시 account local을 교체하고 게임 상태를 다시 만든다.
- 선택창을 띄우지 않는다.
- 완료 후 `다른 기기의 최신 진행을 불러왔습니다.` 안내를 표시한다.

### 전투 중

- 현재 렌더링 프레임을 강제로 중단하지 않는다.
- conflict를 발견한 순간부터 새로운 계정 경제 변경과 다음 라운드 시작을 막는다.
- 현재 결과 연출 또는 체크포인트 처리를 마친 뒤 로딩 화면으로 이동한다.
- rebase를 완료하고 메인 메뉴 또는 저장된 안전 지점에서 게임 상태를 다시 만든다.
- 충돌 확인 후 원격을 받지 못한 동안에는 계정 진행을 계속 만들지 않는다.

네트워크 장애만 있고 충돌이 확인되지 않은 상태에서는 기존 로컬 우선 정책대로
플레이를 계속할 수 있다. 반면 원격이 앞섰다는 사실을 확인한 뒤 계속 플레이하면
반드시 폐기될 분기만 늘어나므로 안전 지점에서 일시 정지한다.

### 표시 상태

- 정상: `클라우드 저장 완료 · <시각>`
- 네트워크 재시도: `오프라인 플레이 중 · 연결 시 저장`
- 원격 적용 중: `다른 기기의 최신 진행을 불러오는 중`
- writer 교체: `다른 기기에서 계정 플레이가 시작되었습니다.` 이후 account 플레이 정지
- 완료: `다른 기기의 최신 진행을 불러왔습니다.`
- 구버전: `최신 계정 진행을 사용하려면 게임을 업데이트해 주세요.`

writer 교체와 원격 적용은 사용자의 저장 선택을 요구하지 않는다.

## 14. 최초 계정 연결

guest 진행과 이미 존재하는 account 진행은 다중 기기 충돌과 다른 문제다.

정책:

- 원격 account 저장이 있으면 항상 account 진행을 불러온다.
- guest 진행은 guest 슬롯에 그대로 남기고 account 저장과 병합하지 않는다.
- 원격 account 저장이 없고 사용자가 guest 화면의 `계정에 연결`을 실행한 경우 현재
  guest 진행을 backup 후 account 슬롯에 복사하고 revision 0으로 업로드한다.
- 자동 세션 복원은 원격·Outbox·account cache만 사용하고, 이들이 없는 계정은 새 진행을
  만든다. guest 복사는 대화형 최초 연결에만 허용한다. 로그인 필수화 자체는 아직 미적용이다.
- account local은 별도 선택 후보가 아니라 원격 account 진행의 캐시로만 취급한다.
- 기존 구현의 로컬·Google 계정 진행 선택창은 정상 로그인 흐름에서 제거한다.

원격이 이미 있는데 guest 진행도 있는 경우에는 `기존 계정 진행을 불러오며 현재
기기의 게스트 진행은 이 기기에 보관됩니다.`라고 알릴 수 있지만, 어느 저장을 사용할지
묻지는 않는다.

## 15. Web 다중 탭

서버 revision은 원격 덮어쓰기를 막지만 같은 브라우저의 여러 탭이 Local Storage
Outbox를 서로 덮는 문제까지 해결하지는 못한다.

Web에서는 앱 전체 저장 writer lock을 둔다.

```text
Web Locks name: rune-nexus-local-save-writer
mode: exclusive
scope: guest와 account local 저장 전체
```

- 첫 번째 탭만 로컬 저장과 OnlineSaveCoordinator를 활성화한다.
- 두 번째 탭은 `다른 탭에서 Rune Nexus를 플레이 중입니다.` 상태로 계정 플레이를
  시작하지 않는다.
- `BroadcastChannel`로 기존 탭의 종료·로그아웃·계정 전환을 알린다.
- Web Locks를 지원하지 않는 환경에서도 서버 writer generation과 revision을 최종
  정합성 방어선으로 유지한다.
- localStorage heartbeat만으로 writer 권한을 보장하지 않는다. 시계 오차와 종료 감지
  실패 때문에 정확한 잠금으로 신뢰할 수 없다.

## 16. 저장 스키마와 구버전 클라이언트

전체 스냅샷 PUT 구조에서는 구버전 클라이언트가 미래 필드를 지울 위험이 있다.

- writer claim에 클라이언트의 쓰기 `saveSchemaVersion`을 포함한다.
- writer claim과 저장 PUT에 정수 `clientCompatibilityVersion`을 포함한다.
- 서버는 `MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION`보다 낮거나 필드가 없는 요청을
  새 저장 mutation에 사용하지 않는다. claim은 service·DB 호출 전에
  `426 CLIENT_UPDATE_REQUIRED`로 거부한다. PUT은 과거 exact 성공 영수증만 조회하고,
  영수증이 없을 때 같은 426을 반환한다.
- 서버가 이해하는 현재 호환 버전보다 높은 요청은
  `422 SAVE_CLIENT_VERSION_UNSUPPORTED`로 거부한다.
- claim 검사만으로는 이미 writer를 가진 오래 실행된 클라이언트를 막을 수 없으므로
  PUT도 같은 호환성 검사를 수행한다.
- `clientBuild`는 Web Git SHA나 앱 버전의 진단값이며 문자열 비교로 권한을 판단하지
  않는다.
- 원격 저장 schema가 클라이언트보다 높으면 기존 writer를 교체하지 않고
  `SAVE_VERSION_UNSUPPORTED`를 반환한다.
- `GET /v1/save` 응답의 schema를 파싱할 수 없으면 로컬을 변경하지 않는다.
- 저장 schema 마이그레이션은 읽기 변환과 canonical 최신 버전 쓰기를 분리한다.
- 새 schema 배포 시 서버가 먼저 구버전 보호 규칙을 배포한 뒤 클라이언트를 배포한다.
- Flutter는 426을 받으면 exact writer claim 또는 in-flight PUT을 Outbox에 그대로
  보존하고 새 로컬 저장과 계정 플레이를 멈춘 뒤 업데이트 안내를 표시한다.
- 업데이트된 Flutter는 현재 버전보다 낮은 양의 호환 버전 Outbox를 읽을 수 있다.
  과거 writer claim은 mutation 전 요청이므로 폐기하고 현재 버전으로 다시 획득한다.
  과거 in-flight PUT은 exact body·key·generation으로 영수증을 먼저 확인한다.
- 과거 PUT 영수증이 있으면 기존 성공 revision을 ACK한다. 영수증이 없어 426이면 해당
  in-flight를 로컬 dirty payload로 되돌리고, 현재 writer 획득과 원격 GET/rebase를 마친
  뒤 새 idempotency key와 현재 버전 본문으로 전송한다.
- 현재 버전보다 높은 Outbox 요청이나 해석할 수 없는 payload는 계속 손상으로 거부한다.

GitHub Pages의 오래된 캐시가 새 저장을 쓰지 않도록 Web 배포에서도 같은 검사를
적용한다. Pages 빌드는 `RUNE_NEXUS_CLIENT_BUILD=web:<git-sha>`를 주입하지만 실제
허용 여부는 코드에 고정한 정수 호환 버전으로 판정한다.

## 17. 큰 JSON과 저장 용량

- 로컬 `GameSaveData`는 트랜잭션 일관성을 위해 통파일을 유지한다.
- 서버는 기존처럼 영역별 JSONB 행으로 분리하고 한 트랜잭션으로 갱신한다.
- 조건부 GET의 304로 변경 없는 전체 다운로드를 피한다.
- Outbox는 in-flight exact body 하나와 최신 local payload를 참조하는 dirty 상태만
  유지한다.
- 여러 pending 전체 payload를 각각 보관하지 않는다.
- conflict backup은 최근 1개만 별도 보존한다.
- Web에서 실제 저장과 모든 복사본의 합이 Local Storage 안전 한도에 접근하면
  IndexedDB 이전을 먼저 진행한다.

서버의 revision별 전체 이력은 MVP 필수 조건이 아니다. 운영 복구는 PostgreSQL
backup/restore가 기본이며, 필요하면 최근 N개 승인 snapshot을 별도 테이블에 보존하는
기능을 후속으로 추가한다. 서버 이력은 서버가 승인한 과거 저장을 복구할 뿐, 서버에
도착하지 않은 다른 기기의 오프라인 진행을 복구해 주지는 못한다.

## 18. 보안과 경제 데이터

- writer generation은 동시 저장 제어 수단이지 기기 인증이나 치트 방지 수단이 아니다.
- `clientInstanceId`는 복사하거나 위조할 수 있으므로 권한 판단에 사용하지 않는다.
- account ID와 session ID는 bearer 인증 principal에서 결정한다.
- 전체 payload와 인증 token을 로그에 남기지 않는다.
- 다이아, 결제 상품과 일회성 보상은 snapshot revision과 별도의 command API,
  idempotency receipt와 서버 원장을 사용한다.
- 서버 권위 값은 원격 snapshot을 적용한 뒤 서버 authoritative 응답으로 다시 overlay한다.
- 로컬 플레이에서 생긴 서버 권위 보상 claim은 생성 당시 base revision과 writer
  generation에 결속한다. exact 영수증을 먼저 확인하고, writer 교체 뒤
  `remote > base`이면 폐기 분기의 보상을 무효화한다. `remote == base`이면 보상을
  suspended로 보존하고 명시적 writer 재획득 뒤 새 generation에 재결속한다.
- 경제 cache는 `(authorityEpoch, economyRevision)`으로 비교한다. DB restore 뒤에는
  운영자가 authority epoch를 회전하고 클라이언트가 기존 cache를 backup한 뒤 서버
  상태로 재기준화한다.
- 반복 writer 탈환과 비정상 conflict 빈도는 관찰하되 단일 신호로 자동 제재하지 않는다.

## 19. 리스크와 대응

| 위험 | 영향 | 대응 |
| --- | --- | --- |
| 두 기기의 오프라인 분기 | 한쪽 진행 폐기 | remote revision 우선, 적용 전 local backup, 명확한 안내 |
| 저장 성공 응답 유실 오판 | 실제 승인 진행을 충돌로 폐기 | writer/revision 검사보다 exact idempotency 영수증 우선 |
| 두 기기의 writer 반복 탈환 | 진행 중단과 rebase 반복 | foreground 명시 시에만 claim, background 자동 탈환 금지, rate limit |
| rebase 중 앱 종료 | local과 Outbox 기준 불일치 | 영속 rebase journal과 단계별 재시작 복구 |
| 같은 Web 저장의 다중 탭 쓰기 | Local Storage·Outbox 유실 | Web Locks 단일 local writer, 서버 generation 최종 방어 |
| 구버전 전체 snapshot PUT | 새 필드 삭제 | claim·PUT 호환 버전 검사, exact 요청 보존과 계정 플레이 정지 |
| Web 저장 용량 초과 | backup 또는 Outbox 저장 실패 | 실제 크기 측정, 304, 복사본 제한, 필요 시 IndexedDB 이전 |
| DB restore로 revision 후퇴 | 오래된 서버 상태에 새 로컬 업로드 | remote revision < base이면 blocked, 운영 복원 절차로만 해결 |
| 클라이언트 저장 조작 | 비정상 일반 진행 | snapshot은 동기화로 한정, 유료 재화·보상은 별도 서버 명령·원장 |

가장 큰 제품 리스크는 오프라인 분기 손실이다. 이는 구현 오류가 아니라 무병합·무선택
정책의 결과이므로 안내 문구와 운영 복구 기준까지 기능의 일부로 취급한다.

## 20. 관찰 지표

payload 없이 다음 구조화 이벤트와 수치만 기록한다.

- writer claim 성공, 이전 generation과 새 generation
- `SAVE_WRITER_REPLACED` 횟수
- `SAVE_REVISION_CONFLICT`의 expected/current revision
- exact in-flight receipt 복구 성공 횟수
- remote rebase 시작·완료·실패와 소요 시간
- Outbox 최고 대기 시간과 retry 횟수
- 저장 request/response byte 크기
- account별 짧은 시간 내 writer 교체 횟수
- schema·client compatibility version 거부 횟수

토큰, idempotency key 원문, 전체 저장 payload와 Google subject는 일반 로그에 남기지
않는다.

## 21. 구현 단계

### 단계 A: 현재 충돌 정책 교체 — 완료

- [x] 기존 사용자 저장 선택을 전제로 한 문구와 정상 흐름 제거
- [x] SHA-256 payload hash와 단일 canonical Outbox
- [x] 시작·재개 revision 판정기 구현
- [x] exact in-flight 우선 복구
- [x] 자동 rebase journal, 별도 충돌 backup과 계정 게임 상태 재로딩
- [x] 조건부 GET ETag

기술적인 동기화·복구 경로는 2026-08-26 구현 완료했고, 2026-08-27 최초 계정 연결도
원격 account 우선 자동 bootstrap으로 교체했다. 기존 Outbox가 있으면 원격 조회나
로컬 교체보다 exact 요청 복구를 우선하며, 새 연결에서만 원격 account·guest·새 진행
순서로 account 슬롯을 준비한다.

### 단계 B: 단일 writer session — 완료

- [x] writer state·claim receipt DB 스키마
- [x] writer claim API와 CORS header
- [x] save request의 writer generation 검증
- [x] Flutter writer 획득·교체·suspended 상태 연결
- [x] writer 교체 후 로컬 저장·게임 입력 정지와 foreground 원격 복구 UX
- [x] claim/save 동시성 통합 테스트

단계 A만으로도 revision이 오래된 덮어쓰기를 막는다. 단계 B까지 완료해야 두 기기의
반복 충돌과 background 자동 탈환을 안정적으로 제한할 수 있다.

### 단계 C: Web과 운영 안전장치

- [x] Web Locks 단일 탭 writer와 두 번째 탭 부팅 차단
- [x] writer claim·PUT 공통 client compatibility gate와 업데이트 필요 UX
- [ ] BroadcastChannel 기반 기존 탭 종료 알림·재획득 안내
- 실제 저장 크기 측정과 필요 시 IndexedDB 이전
- PostgreSQL backup·restore 훈련
- conflict/rebase 운영 지표
- 공개 HTTPS 환경의 두 기기 E2E

### 단계 D: 플랫폼 인증 확대

- Android PGS identity를 기존 account에 연결
- iOS identity 추가
- 어느 인증 수단으로 로그인해도 같은 내부 account와 동일 저장 정책 적용

### 코드 책임 경계

현재 구조를 크게 재편하지 않고 다음 경계로 구현한다.

- `OnlineSaveApi`
  - writer claim, ETag 조건부 조회와 writer generation 포함 PUT 계약
- Go save handler/service
  - 이미 bearer principal에 있는 account ID와 session ID를 writer claim·PUT에 함께 전달
  - 저장 service가 idempotency 영수증, writer state와 revision을 정해진 잠금 순서로 검사
- `OnlineSaveCoordinator`
  - Outbox read-modify-write의 단일 소유자
  - exact in-flight 우선 복구, claim 이후 runtime 전송, revision 판정과 rebase journal
  - 원격 적용 완료 뒤 `requiresGameReload` 상태 발행
- account local repository
  - account primary 원자적 저장과 conflict backup 보존
  - coordinator에 load/save/backup 계약을 제공하고 네트워크 정책은 알지 않음
- `RuneNexusApp`
  - 로그인 뒤 account coordinator 구성
  - 전투 안전 지점 결정과 `RuneNexusGame` 재생성
  - 동기화 상태와 안내 문구 표시
- `AccountSaveBootstrapService`
  - 정상 로그인 경로의 저장 선택 dialog를 제거
  - 기존 Outbox 우선 복구와 guest 연결·기존 account cache의 보존형 전환 담당
- Web local writer lock
  - Flutter Web 전용 저장소 경계에서 account coordinator 생성 전에 획득

coordinator가 game object를 직접 교체하거나 UI dialog를 호출하지 않는다. 반대로 앱은
Outbox JSON을 직접 수정하지 않는다. rebase 중 account local과 Outbox 상태 전이의
순서는 coordinator 한 곳에서 관리한다.

## 22. 테스트 기준

### Flutter 단위·통합 테스트

- remote = base, clean이면 다운로드·업로드하지 않음
- remote = base, local hash가 다르면 dirty 복구 후 업로드
- remote > base, clean/dirty 각각 원격 적용
- remote < base이면 자동 업로드 차단
- in-flight 성공 응답 유실 뒤 같은 bytes/key/generation 재시도
- 다른 writer가 생긴 뒤에도 성공 영수증을 먼저 확인
- 실제 미반영 in-flight는 backup 후 폐기
- rebase 각 영속 단계 강제 종료와 재시작 복구
- backup 실패 시 primary와 Outbox를 덮지 않음
- 원격 payload 검증 실패 시 기존 로컬 유지
- 전투 중 conflict는 다음 안전 지점에서 게임 상태 재생성
- 계정 변경 시 다른 account Outbox 전송 금지
- 배포 전 중간 Outbox 형식을 읽거나 변환하지 않고 canonical 형식만 허용
- writer claim과 저장 PUT의 426에서 exact 요청을 보존하고 로컬 저장을 정지
- 업데이트 뒤 이전 호환 버전 Outbox의 claim 재획득과 in-flight 영수증 hit/miss 전환

### Go·PostgreSQL 테스트

- 첫 writer claim은 generation 1
- 같은 claim key/body 재시도는 같은 generation
- 같은 claim key의 다른 body 거부
- 다른 session claim은 generation 증가
- 이전 session/generation의 새 PUT 거부
- 이전 writer의 이미 성공한 exact PUT은 영수증 성공 반환
- claim과 PUT 경쟁에서 잠금 순서와 결과 일관성
- 동일 revision 동시 저장은 하나만 성공
- 최소 client compatibility version 미만 claim은 service 호출 전 426
- 최소 버전 미만 PUT은 exact 영수증 hit만 성공하고 miss는 mutation 없이 426
- unsupported client claim이 기존 writer를 교체하지 않음
- 다른 account의 session으로 writer 상태를 변경하지 못함
- conditional GET 304와 404/200 구분
- account 삭제 시 writer state와 영수증 cascade

### 실제 E2E

1. 기기 A 저장 후 기기 B 로그인·복원
2. 기기 B가 writer가 된 뒤 기기 A 저장 거부·원격 복원
3. 기기 A 오프라인 진행 중 B 저장 후 A 재연결
4. PUT 커밋 직후 응답 연결을 끊고 exact retry
5. rebase 다운로드 중 API 재시작
6. 같은 브라우저 두 탭 실행
7. 구버전 Web 빌드가 최신 schema 계정을 열 때 저장 거부
8. 큰 실제 저장에서 304가 전체 body를 전송하지 않는지 확인

## 23. 완료 조건

- stale revision이 현재 원격 저장을 덮어쓰는 경로가 없다.
- 동시에 유효한 저장 writer generation은 account당 하나다.
- 응답 유실된 성공 요청을 실제 충돌로 오인해 폐기하지 않는다.
- 실제 충돌에서는 사용자 선택 없이 원격 revision을 적용한다.
- 원격 적용 전에 복구 가능한 로컬 backup이 존재한다.
- rebase 도중 종료되어도 다음 시작에서 stale payload를 업로드하지 않는다.
- 두 번째 Web 탭이 같은 로컬 저장과 Outbox를 동시에 쓰지 않는다.
- 구버전 클라이언트가 새 schema 저장을 전체 snapshot으로 덮지 않는다.
- 서버 장애 동안 로컬 플레이와 durable Outbox는 유지된다.
- 충돌 확인 뒤에는 원격 복구가 끝날 때까지 새 계정 분기를 만들지 않는다.

## 24. 알려진 한계

- 두 기기의 서로 다른 오프라인 진행 중 하나는 폐기될 수 있다.
- 이전 writer는 다음 서버 접점까지 교체 사실을 즉시 알 수 없다.
- 새 기기에 로컬 캐시가 없고 서버도 연결되지 않으면 계정 진행을 시작할 수 없다.
- 로컬 conflict backup은 해당 기기를 잃으면 함께 사라진다.
- 서버 snapshot 동기화만으로 클라이언트 조작과 치트를 막을 수 없다.

이 한계는 다중 기기, 오프라인 플레이, 무선택 자동 해결을 동시에 채택한 결과다.
Rune Nexus는 진행 병합보다 결정성, 자동 복구와 구현 복잡도 제한을 우선한다.

## 25. 참고 기준

- Google Play Games Saved Games는 여러 기기 conflict와 자동 최신 저장 선택 정책을
  제공한다: <https://developer.android.com/games/pgs/android/saved-games>
- Unity Cloud Save write lock은 stale write를 거부하는 낙관적 동시성 제어 사례다:
  <https://docs.unity.com/en-us/cloud-save/concepts/write-locks>
- Apple GameKit도 여러 기기 saved game conflict를 게임 정책으로 해결하도록 한다:
  <https://developer.apple.com/documentation/gamekit/saving-the-player-s-game-data-to-an-icloud-account>
- HTTP `If-Match`와 entity tag는 lost update 방지의 표준 조건부 요청 방식이다:
  <https://www.rfc-editor.org/rfc/rfc9110.html>
