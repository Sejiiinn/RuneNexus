# Rune Nexus 서버 권위 경제 상세 설계

문서 상태: 채택 설계 · 주간 보상 수령 판정 1차 구현
마지막 갱신: 2026-08-29

현재 구현된 범위는 `POST /v1/economy/rewards/claim`의 주간 임무·전체 완료·주간 출석
수령 판정이다. 서버가 현재 save writer와 최신 account snapshot을 잠그고 진행 증거,
서버 주차, 고정 보상량과 계정별 reward key를 검증한다. 클라이언트는 영수증 뒤에만
로컬 캐시를 갱신한다. 아직 `player_economies`, economy revision, legacy bootstrap과
다른 다이아 증감 경로가 전환되지 않았으므로 전체 지갑 서버 권위 전환으로 보지는
않는다. 이 단계에서는 오프라인 claim을 쌓지 않고 로그인·저장 동기화가 완료된 때만
수령한다. 응답 유실은 동일 reward key의 기존 영수증을 다시 내려 복구한다.

## 1. 결론

Rune Nexus는 전투와 일반 진행을 계속 로컬에서 처리하되, 다음 값만 하나의
**서버 권위 경제 영역**으로 묶는다.

- 무료·유료 다이아 잔액
- 포탑 모듈권 잔액과 구매 횟수
- 포탑 모듈 뽑기 횟수와 확률 단계
- 소유 포탑 모듈, 옵션과 분해 상태
- 다이아·모듈권을 지급하는 보상 수령 이력
- 다이아로 구입하는 연구 슬롯 2 entitlement와 즉시 완료 영수증
- 향후 Google Play·Apple 구매 검증 결과

가챠 결과만 서버에서 만들고 다이아나 모듈권을 로컬에 남기는 방식은 채택하지
않는다. 현재 코드에는 퀘스트·출석·다이아 운반 적·스테이지 최초 클리어·연구·모듈
분해처럼 같은 경제 값으로 이어지는 경로가 여럿 있기 때문이다. 이 중 하나라도
로컬 쓰기로 남으면 로컬 값을 복제하거나 수정해 서버 가챠 결과를 반복해서 얻을 수
있다.

반대로 전투 입력, 적 이동, 포탑 공격, 룬·코어 포인트·젬, 연구 진행 시간, 스테이지
기록과 활성 런은 서버 권위로 올리지 않는다. 오프라인 플레이와 느린 네트워크에서의
플레이 연속성을 유지하고, 서버는 중요 경제 행동이 발생할 때만 호출한다.

```text
로컬 권위 게임 상태                         서버 권위 경제 상태
전투·런·일반 성장·퀘스트 진행               다이아·모듈권·소유 모듈·수령 이력
        |                                              |
        `-> 비동기 PUT /v1/save                       |
                                                       |
중요 행동 --------------------------------------------> 명령 API
  뽑기, 분해, 다이아 소비, 보상 수령                   |
                                                       v
                                  PostgreSQL 트랜잭션 + 멱등 영수증
                                                       |
클라이언트 로컬 캐시 <---------------- authoritative 응답
```

## 2. 현재 형상에서 확인된 경제 경로

현재 `GameSaveData` v2는 `progression`에 다이아와 퀘스트 보상 수령 상태를,
`turretModules`에 모듈권·뽑기 횟수·소유 모듈·장착 여부를 저장한다. 모든 증감은
클라이언트 메모리에서 동기적으로 끝난 뒤 로컬 저장된다.

| 현재 경로 | 현재 처리 | 최종 권위 |
| --- | --- | --- |
| 퀘스트·출석 보상 | 클라이언트가 무료 다이아와 모듈권 직접 증가 | 서버 claim |
| 다이아 운반 적 처치 | 클라이언트 RNG와 즉시 무료 다이아 증가 | 로컬 미확정 보상 + 서버 정산 |
| 스테이지 11 최초 클리어 | 클라이언트가 모듈권 직접 증가 | 서버 run 정산의 일회성 보상 |
| 모듈 뽑기 | 클라이언트가 티켓 차감, RNG, 모듈 생성 | 서버 명령 |
| 부족한 모듈권 구매 | 클라이언트가 다이아 차감 | 뽑기 서버 트랜잭션에 포함 |
| 모듈 분해 | 클라이언트가 모듈 삭제, 무료 다이아 증가 | 서버 명령 |
| 연구 즉시 완료 | 클라이언트가 다이아 차감 후 연구 완료 | 서버 차감 명령 + 로컬 효과 적용 |
| 연구 슬롯 2 해금 | 클라이언트가 다이아 차감 후 로컬 해금 | 서버 차감 명령 + 로컬 효과 적용 |
| 디버그 다이아 지급 | 클라이언트 직접 증가 | release 차단, 테스트 전용 경로 |

현재 다이아 소비 순서는 `free`를 먼저 쓰고 부족분을 `paid`에서 쓴다. 서버 전환 뒤에도
이 순서를 유지한다. 현재 모듈권 부족분 가격은 코드 기준 1장당 다이아 40개다. 서버
카탈로그를 도입할 때 이 값을 서버 권위 값으로 옮기고 클라이언트가 가격을 전송하지
않게 한다.

개별 분해는 unique 등급을 막지 않지만 일괄 분해는 막는 현재 불일치도 확인됐다.
서버 전환 전에 정책을 하나로 고정해야 하며, 기본안은 unique 등급을 개별·일괄 모두
분해할 수 없게 하는 것이다.

## 3. 권위 경계

### 3.1 서버가 원본인 값

| 데이터 | 설명 |
| --- | --- |
| `freeDiamonds`, `paidDiamonds` | 클라이언트 저장 값은 표시용 캐시일 뿐 잔액 원본이 아님 |
| `moduleTickets` | 획득과 사용을 서버 명령으로만 처리 |
| `moduleDrawCount` | 뽑기 확률 단계 계산의 서버 원본 |
| `moduleTicketPurchaseCount` | 가격·통계 계산의 서버 원본 |
| 소유 모듈 | 모듈 ID, 포탑 종류, 부위, 등급, 옵션, 획득 순서와 상태 |
| 경제 보상 수령 이력 | 일·주간, 출석, 스테이지 최초, 런 정산의 중복 방지 |
| 연구 슬롯 2 해금 | 다이아로 구입하는 영구 entitlement, 로컬 값은 cache |
| 결제 거래 | provider 거래 식별자, 검증 상태와 지급 결과 |

서버 권위 값은 `PUT /v1/save`로 갱신할 수 없다. 오래된 저장 스냅샷이 나중에
도착해도 경제 잔액과 소유 모듈은 절대 되돌아가지 않는다.

### 3.2 로컬·동기화 스냅샷이 원본인 값

| 데이터 | 설명 |
| --- | --- |
| 전투와 활성 런 | 서버 응답 없이 계속 진행 |
| 룬, 코어 포인트, 젬과 일반 업그레이드 | 현재의 클라이언트 신뢰 범위 유지 |
| 스테이지 클리어·최고 라운드 | 클라우드 백업 대상이지만 서버 권위 판정 대상은 아님 |
| 퀘스트 진행량 | 로컬에서 누적하고 claim 때 서버에 행동 증거로 보고 |
| 연구 상태 | 시작·시간 완료와 레벨은 로컬. 즉시 완료 effect는 서버 영수증에서 멱등 적용 |
| 모듈 장착 ID | 일반 진행 스냅샷에 저장하고 서버 소유 목록과 대조 |
| 설정·플레이타임 | 기존 온라인 저장으로 동기화 |

모듈 장착은 오프라인 전투를 위해 로컬에서 즉시 바꿀 수 있다. 서버 경제 상태를
새로 받았을 때 더 이상 소유하지 않은 ID는 자동 해제한다. 서버는 분해 요청에서
클라이언트의 `equipped` 값을 보안 조건으로 신뢰하지 않는다.

### 3.3 로컬 캐시

클라이언트는 마지막으로 받은 경제 snapshot을 로컬 통파일에 캐시한다. 네트워크가
없을 때도 캐시된 소유 모듈의 효과로 전투할 수 있지만 다음 행동은 막는다.

- 다이아 또는 모듈권 소비
- 모듈 뽑기와 분해
- 다이아·모듈권 보상 확정
- 실제 구매 복원과 지급

오프라인 화면은 캐시 잔액과 마지막 동기화 시각을 표시하되 `서버 확인 전` 상태임을
나타낸다. 같은 authority epoch에서 cache revision보다 낮은 응답은 적용하지 않는다.

## 4. 저장 revision과 economy revision

일반 저장의 `saveRevision`과 경제의 `economyRevision`은 서로 다른 aggregate
revision이다.

- `saveRevision`: 큰 로컬 진행 스냅샷의 충돌과 원격 자동 rebase에 사용
- `economyRevision`: 다이아·모듈권·소유 모듈 명령 순서에 사용

일반 저장 writer generation은 여러 기기의 로컬 진행 분기를 하나로 정리한다.
경제 소비 명령은 계정 단위 DB 잠금과 `expectedEconomyRevision`으로 직렬화한다.
두 기기가 같은 revision으로 동시에 뽑기를 요청하면 하나만 성공하고, 다른 요청은
최신 경제 상태를 받은 뒤 사용자가 다시 실행해야 한다. 충돌한 소비 명령을 새로운
revision으로 자동 재실행하지 않는다.

전투에서 생긴 보상 claim은 생성 당시 `baseSaveRevision`과 save writer generation에
결속한다. 다른 기기가 writer를 획득했을 때는 일반 save와 같은 판정을 사용한다.

- exact in-flight가 있으면 현재 writer 여부보다 성공 영수증을 먼저 확인한다.
- 원격 save revision이 base보다 앞섰으면 폐기되는 로컬 분기의 미확정 보상도
  무효화하고 backup·진단 정보에만 남긴다.
- 원격 save revision이 base와 같으면 미확정 보상을 `suspended`로 보존한다.
- 사용자가 이 기기에서 명시적으로 account 플레이를 재개하고 원격이 여전히 같은
  base일 때만 새 writer generation에 재결속해 보낸다.
- 재결속 시 새 body와 idempotency key를 사용하되 동일 reward key의 unique 제약으로
  이전 요청의 지연 성공까지 중복 지급하지 않는다.

writer가 바뀌었다는 사실만으로 미확정 보상을 폐기하지 않는다. 실제로 원격 진행이
앞섰을 때만 일반 진행 분기와 함께 폐기한다.

```text
기기 A, B가 economy revision 8을 조회
A 뽑기 -> DB row lock -> revision 9, 결과 A 확정
B 뽑기(expected 8) -> 409 ECONOMY_REVISION_CONFLICT
B는 revision 9를 조회하고 결과 A를 확인
B의 원래 요청은 자동 실행하지 않음
```

이 구조에서는 두 기기에 같은 10,000 다이아 상태가 캐시되어 있어도 한쪽의 뽑기
결과를 본 뒤 다른 쪽의 오래된 상태로 되돌려 다시 뽑을 수 없다.

### 4.1 authority epoch와 DB 복원

economy cache 비교 키는 revision 하나가 아니라
`(authorityEpoch, economyRevision)`이다. `authorityEpoch`는 경제 시스템 전체에 대한
서버 발급 UUID이며 모든 economy 응답과 command 영수증에 포함한다.

- 같은 epoch에서는 더 낮은 revision 응답을 무시한다.
- 실행 중 예상하지 못한 다른 epoch 응답을 받으면 경제 변경을 막고 전체 상태를 다시
  조회한다. 한 번 새 epoch를 확정한 뒤 도착한 이전 epoch 응답은 폐기한다.
- 앱 시작 시 서버 epoch가 로컬 cache와 다르면 기존 cache를 backup하고 서버 상태로
  재기준화한다.
- PostgreSQL backup을 복원한 운영자는 공개 전에 epoch를 새 UUID로 회전한다.
- 서버 권위 전환 이후 경제 migration은 forward-only다. production down migration으로
  경제 테이블이나 원장을 삭제하지 않는다.

이 절차가 없으면 DB 복원으로 서버 revision이 낮아졌을 때 클라이언트가 정상 서버
상태를 영구히 거부할 수 있다.

## 5. PostgreSQL 설계

### 5.1 관계

```text
economy_system_state
accounts
  |- player_economies
  |- player_modules
  |- economy_commands
  |    `- economy_ledger_entries
  |    `- economy_progression_effects
  |- reward_claims
  `- purchase_transactions        # 실제 결제 단계에서 추가
```

지갑과 모듈권 상태를 별도 head 테이블로 나누지 않는다. 모듈권 부족분을 다이아로
구매하면서 즉시 뽑는 행동처럼 두 자원을 한 번에 바꾸는 명령이 있으므로 계정당
`player_economies` 한 행을 잠그는 편이 단순하고 안전하다.

`economy_system_state`는 singleton 행으로 현재 `authority_epoch` UUID를 보존한다.
DB 복원 뒤 운영자가 epoch를 회전할 때만 변경한다.

### 5.2 `player_economies`

```text
account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE
revision BIGINT NOT NULL DEFAULT 0
free_diamonds BIGINT NOT NULL DEFAULT 0
paid_diamonds BIGINT NOT NULL DEFAULT 0
module_tickets BIGINT NOT NULL DEFAULT 0
module_draw_count BIGINT NOT NULL DEFAULT 0
module_ticket_purchase_count BIGINT NOT NULL DEFAULT 0
module_item_sequence BIGINT NOT NULL DEFAULT 0
research_slot_two_unlocked BOOLEAN NOT NULL DEFAULT FALSE
authority_state TEXT NOT NULL          # legacy_local, bootstrap_in_progress, server_authoritative
authority_version INTEGER NOT NULL
bootstrap_save_revision BIGINT NULL
bootstrapped_at TIMESTAMPTZ NULL
created_at TIMESTAMPTZ NOT NULL
updated_at TIMESTAMPTZ NOT NULL
```

모든 수치에는 0 이상 CHECK를 두고 `authority_state`는 정의된 세 값만 허용한다.
정상 성공 명령 하나가 전체 상태를 바꿀 때마다 revision을 정확히 1 증가시킨다.
`module_item_sequence`는 새 모듈마다 증가하며 `acquired_order`의 계정 내 유일한
생성 원본으로 사용한다. draw command 하나에서 여러 개를 만들면 잠근 head 행에서
연속된 범위를 먼저 예약한다.

### 5.3 `player_modules`

```text
id UUID PRIMARY KEY DEFAULT uuidv7()
account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
legacy_item_id TEXT NULL
turret_type TEXT NOT NULL
part TEXT NOT NULL
family TEXT NOT NULL
grade TEXT NOT NULL
options JSONB NOT NULL
acquired_order BIGINT NOT NULL
acquired_revision BIGINT NOT NULL
status TEXT NOT NULL                 # active, disassembled
created_by_command_id UUID NOT NULL REFERENCES economy_commands(id)
disassembled_by_command_id UUID NULL REFERENCES economy_commands(id)
created_at TIMESTAMPTZ NOT NULL
disassembled_at TIMESTAMPTZ NULL
```

- 활성 목록은 `(account_id, status, acquired_order)` index로 조회한다.
- `(account_id, acquired_order)`와 값이 있는 `(account_id, legacy_item_id)`에는 unique
  제약을 둔다.
- bootstrap 중 기존 `tm_<n>` ID는 `legacy_item_id`에 보존한다.
- 서버 UUID와 legacy ID 대응을 bootstrap·조회 응답에 과도기적으로 내려 장착 ID를
  안전하게 바꾼다.
- 분해 시 hard delete하지 않고 상태를 변경해 감사와 중복 요청 판정에 사용한다.
- 옵션 JSONB는 서버 카탈로그의 허용 타입·범위·중복 여부를 검사한다.

### 5.4 `economy_commands`

```text
id UUID PRIMARY KEY DEFAULT uuidv7()
account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
idempotency_key UUID NOT NULL
command_type TEXT NOT NULL
request_hash BYTEA NOT NULL
expected_revision BIGINT NULL
resulting_revision BIGINT NOT NULL
authority_epoch UUID NOT NULL
catalog_version INTEGER NULL
rng_algorithm_version INTEGER NULL
response_payload JSONB NOT NULL
created_at TIMESTAMPTZ NOT NULL
UNIQUE(account_id, idempotency_key)
UNIQUE(account_id, resulting_revision)
```

`response_payload`에는 뽑힌 모듈을 포함한 최초 성공 응답을 그대로 보존한다. 같은
key와 같은 body 재시도는 RNG를 다시 실행하지 않고 이 응답을 돌려준다. 같은 key를
다른 body에 재사용하면 `IDEMPOTENCY_KEY_REUSED`를 반환한다.

- `request_hash`는 SHA-256 32 bytes CHECK를 둔다.
- `expected_revision`이 있는 성공 명령은 `resulting_revision = expected_revision + 1`
  CHECK를 둔다.
- reward·구매처럼 expected revision이 없는 성공 명령도 잠근 head의 직전 revision보다
  정확히 1 증가시킨 값을 기록하며 service 통합 테스트로 보장한다.
- 가격·보상 또는 RNG를 사용하는 명령은 실행한 catalog version을 기록하고, RNG를
  사용하면 RNG algorithm version도 반드시 기록한다.

### 5.5 `economy_ledger_entries`

```text
command_id UUID NOT NULL REFERENCES economy_commands(id)
entry_order SMALLINT NOT NULL
asset_type TEXT NOT NULL             # free_diamond, paid_diamond, module_ticket
delta BIGINT NOT NULL
balance_after BIGINT NOT NULL
reason TEXT NOT NULL
PRIMARY KEY(command_id, entry_order)
```

원장 행은 수정하거나 삭제하지 않는다. 운영 정정도 새 명령과 반대 delta 행으로
남긴다. 소유 모듈의 생성·분해는 `player_modules`의 command 참조로 추적한다.

여기서 불변은 account가 존재하는 동안 API나 운영 정정으로 기존 원장 행을 수정하지
않는다는 뜻이다. 사용자의 계정 삭제 요청은 현재 전체 account hard delete 정책에
따라 원장도 `ON DELETE CASCADE`로 제거한다. 실제 결제를 도입할 때 법정 보존이 필요한
거래가 생기면 개인 식별 정보와 분리한 별도 보존 정책을 먼저 확정한다.

### 5.6 `reward_claims`

```text
account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
reward_key TEXT NOT NULL
command_id UUID NOT NULL REFERENCES economy_commands(id)
writer_generation BIGINT NULL
origin_save_revision BIGINT NULL
evidence JSONB NOT NULL
claimed_at TIMESTAMPTZ NOT NULL
PRIMARY KEY(account_id, reward_key)
```

reward key는 서버가 정규화한다.

- `daily:2026-08-26:kill_enemies`
- `weekly:2026-W35:all_complete`
- `attendance:daily:2026-08-26`
- `stage:11:first_clear`
- `run:<run-uuid>:settlement`

클라이언트가 보상 금액이나 지급 자산을 직접 보내지 않는다. 서버 카탈로그가 reward
key와 행동 증거를 보고 금액을 계산한다.

일·주간 period key는 기기 자정이 아니라 현재 게임 규칙과 같은 **KST 오전 5시**를
경계로 서버가 계산한다. 주간은 월요일 오전 5시에 바뀐다. 클라이언트가 보낸
날짜·주차는 권위 값으로 사용하지 않는다.

### 5.7 `economy_progression_effects`

다이아 차감과 로컬 일반 진행 변경 사이의 crash·rebase 간극을 막는 서버 보관
journal이다.

```text
id UUID PRIMARY KEY DEFAULT uuidv7()
account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
command_id UUID NOT NULL REFERENCES economy_commands(id)
effect_type TEXT NOT NULL            # complete_research
payload JSONB NOT NULL
status TEXT NOT NULL                 # pending, applied
applied_save_revision BIGINT NULL
applied_by_command_id UUID NULL REFERENCES economy_commands(id)
created_at TIMESTAMPTZ NOT NULL
applied_at TIMESTAMPTZ NULL
UNIQUE(account_id, command_id)
```

`GET /v1/economy`는 pending effect를 함께 반환한다. 어떤 기기에서든 원격 save rebase를
먼저 끝낸 뒤 effect를 멱등 적용하고 일반 save 업로드까지 성공해야 applied ack를
보낼 수 있다. 서버는 ack의 save revision과 저장 payload가 effect 결과를 포함하는지
검사한 뒤에만 `applied`로 바꾼다. 로컬 저장소가 사라져도 pending effect가 서버에
남으므로 다이아만 차감되고 연구 완료가 유실되지 않는다.

effect ack도 idempotency key를 사용하는 경제 command다. expected economy revision은
요구하지 않지만 head를 잠그고 pending -> applied 변경, applied command 참조와 economy
revision 증가를 한 transaction으로 처리한다. 같은 effect의 반복 ack는 최초 성공
영수증을 반환한다.

## 6. 서버 명령 API

모든 endpoint는 Bearer 인증을 사용하고 account ID는 session에서 얻는다. 변경
요청은 `Idempotency-Key: <UUID>`를 필수로 받는다.

| Method | Path | 역할 |
| --- | --- | --- |
| `GET` | `/v1/economy` | authoritative 잔액, 모듈과 현재 claim 요약 조회 |
| `GET` | `/v1/economy/catalog` | 가격, 확률, 보상 표시 계약 조회 |
| `POST` | `/v1/economy/bootstrap` | 기존 account 저장을 한 번만 경제 원본으로 이전 |
| `POST` | `/v1/economy/turret-modules/draw` | 티켓 구매·차감, RNG와 모듈 생성을 한 트랜잭션으로 처리 |
| `POST` | `/v1/economy/turret-modules/disassemble` | 소유 모듈 상태 변경과 무료 다이아 지급 |
| `POST` | `/v1/economy/researches/{type}/complete` | 서버 가격으로 다이아 차감 |
| `POST` | `/v1/economy/research-slots/2/unlock` | 조건 확인과 다이아 차감 |
| `POST` | `/v1/economy/progression-effects/{effectId}/ack` | effect가 반영된 save revision 확인 |
| `POST` | `/v1/economy/rewards/claim` | 일·주간·출석 보상 지급 |
| `POST` | `/v1/economy/runs/settle` | 런 다이아와 최초 클리어 모듈권 정산 |
| `POST` | `/v1/purchases/google/verify` | 후속 단계의 Play 구매 검증과 지급 |

`PATCH /v1/economy`나 `setDiamonds` 같은 직접 값 설정 API는 만들지 않는다.

### 6.1 조회 응답

```json
{
  "authorityEpoch": "019d3f3c-64a0-7b12-a763-b6df00c1af55",
  "economyRevision": 18,
  "catalogVersion": 1,
  "serverTime": "2026-08-26T12:00:00Z",
  "wallet": {
    "freeDiamonds": 320,
    "paidDiamonds": 100,
    "moduleTickets": 4
  },
  "turretModules": {
    "drawCount": 27,
    "ticketPurchaseCount": 3,
    "items": []
  },
  "entitlements": {
    "researchSlotTwoUnlocked": false
  },
  "pendingProgressionEffects": [],
  "claims": {
    "dailyPeriodKey": "2026-08-26",
    "weeklyPeriodKey": "2026-W35",
    "claimedRewardKeys": []
  }
}
```

전체 모듈 목록이 커지면 cursor pagination보다 먼저 `ETag`와 economy revision 기반
`304 Not Modified`를 적용한다. 현재 규모에서는 한 번에 내려도 충분하다.

### 6.2 모듈 뽑기

요청 예시:

```json
{
  "expectedEconomyRevision": 18,
  "expectedCatalogVersion": 1,
  "sourceSaveRevision": 12,
  "count": 5,
  "turretType": "arrow",
  "buyMissingTicketsWithDiamonds": true
}
```

서버 처리 순서:

1. 동일 idempotency key의 기존 영수증 조회
2. DB transaction 시작과 `player_economies` 행 잠금
3. 잠금 뒤 영수증 재조회
4. expected economy revision과 expected catalog version 검사
5. `sourceSaveRevision`이 현재 save revision인지 확인하고 해당 snapshot의 진행으로
   사용 가능한 포탑 종류 검사
6. 서버 카탈로그로 부족 티켓 가격과 잔액 검사
7. 무료 다이아 우선 차감, 모듈권 차감
8. `crypto/rand` 기반 등급·옵션 추첨과 모듈 행 생성
9. 지갑, 원장, command 영수증과 revision을 같은 transaction에 기록
10. commit 뒤 exact 결과 반환

결과 모달은 서버 성공 응답을 받은 뒤에만 연다. 응답이 유실되면 같은 key와 body를
재시도해 최초 결과를 복원하므로 다시 추첨하지 않는다.

확인 화면을 연 뒤 catalog가 바뀌었으면 `409 ECONOMY_CATALOG_CHANGED`로 소비 없이
거부하고 새 catalog를 조회한다. 서버는 실행한 catalog와 RNG algorithm version을
영수증에 기록한다.

### 6.3 모듈 분해

요청은 `expectedEconomyRevision`, `expectedCatalogVersion`과 모듈 ID 집합만 보낸다.
서버가 계정 소유, active 상태, 등급별 분해 가능 여부와 환급액을 결정한다. 일부 ID만
유효한 상태에서 조용히 부분 성공시키지 않고 전체 요청을 거부하여 UI와 서버 목록이
달라지는 일을 피한다.

서버 성공 뒤 클라이언트는 반환된 authoritative 목록으로 캐시를 교체하고, 사라진
모듈 ID가 장착되어 있으면 로컬 장착을 해제한다.

### 6.4 연구 다이아 소비

연구 레벨 자체는 로컬 권위지만 다이아로 구입하는 슬롯 2는 서버 entitlement다.
즉시 완료는 다음 순서로 처리한다.

1. 클라이언트가 `expectedEconomyRevision`, `expectedCatalogVersion`, 현재 writer
   generation과 `sourceSaveRevision`을 보낸다.
2. 서버는 save writer와 현재 save revision을 확인하고, 저장된 active research로
   대상·목표 레벨·남은 시간을 판정한다.
3. 서버가 가격과 잔액을 검사하고 다이아 차감, command 영수증과 pending progression
   effect 생성을 한 transaction으로 처리한다.
4. 클라이언트는 일반 save의 exact 요청과 rebase를 먼저 끝낸 뒤 서버 pending effect를
   선택된 account 진행에 멱등 적용한다.
5. 로컬 통파일 저장과 일반 save 업로드가 성공하면 해당 save revision으로 effect ack를
   보낸다.
6. 서버가 저장 payload의 effect 결과를 확인한 뒤 effect를 applied로 변경한다.

앱 종료, 로컬 저장 삭제 또는 다른 기기 rebase가 발생해도 pending effect는 서버에
남아 다음 로그인 기기가 다시 적용한다. effect는 연구 레벨을 목표 레벨 이상으로
올리고 같은 active research를 제거하는 단조 연산으로 정의해 반복 적용해도 안전하게
한다.

연구 슬롯 2 해금은 성공 즉시 `player_economies.research_slot_two_unlocked`를 true로
만들고 이후 `GET /v1/economy`마다 overlay한다. 로컬 snapshot의 false 값이 entitlement를
되돌릴 수 없다.

일반 진행이 클라이언트 권위이므로 조작된 클라이언트가 연구 레벨을 직접 바꾸는 것까지
막는 설계는 아니다. 이 단계의 목표는 서버 다이아가 복제·롤백되지 않게 하는 것이다.

### 6.5 로컬 플레이 보상

다이아 운반 적 보상은 전투 프레임마다 서버를 호출하지 않는다. 런 동안
`pendingRunDiamonds`로 누적하고 **런이 성공·실패로 종료되는 시점에만** stable
`runId`로 정산 명령 하나를 만든다. MVP에서는 중간 체크포인트 정산을 하지 않는다.

- 온라인이면 백그라운드에서 즉시 정산한다.
- 오프라인이면 확정 잔액과 분리해 표시하고 durable reward outbox에 보존한다.
- 같은 run ID는 성공·실패와 무관하게 한 번만 정산한다.
- 서버는 스테이지·완료 라운드별 가능한 상한과 현재 writer generation을 검사한다.
- 승인 전 pending 값은 뽑기나 연구에 사용할 수 없다.
- 서버가 거부하면 잔액에 더하지 않고 진단 가능한 상태로 남긴다.

이 검사는 클라이언트 전투의 진위를 증명하지는 못한다. 조작된 런 반복과 허위 완료는
획득 속도 통계로 관찰하고, 실제 문제가 확인되기 전에는 자동 제재하지 않는다.

향후 중간 정산이 반드시 필요해지면 단순히 같은 run ID를 재사용하지 않는다.
`runId + checkpointSequence`와 서버의 누적 지급 high-water를 함께 도입하여 이전
누적치와의 차이만 지급하는 별도 migration으로 확장한다.

## 7. 클라이언트 저장과 coordinator

### 7.1 로컬 통파일 유지

로컬 저장은 기존 결정대로 하나의 원자적 JSON 파일을 유지한다. 최종 저장 모델에는
다음 개념이 들어간다.

```text
GameSaveData
  preferences
  progression
  turretModuleLoadout
  economyCache
  activeRun
```

`economyCache`는 authority epoch, economy revision, 마지막 동기화 시각, 잔액,
모듈권과 서버 모듈 목록의 마지막 응답이다. `turretModuleLoadout`은 장착 ID만 가진다.
파일을 물리적으로 여러 개로 쪼개지 않으므로 로컬 복구의 원자성은 유지된다.

현재 v2에서 즉시 v3로 대규모 이동하지 않는다. 먼저 경제 API와 client adapter를
기능 플래그 뒤에 구현하고, 전환 release에서 보존형 v3 migration을 수행한다.
v2의 경제 필드는 migration source와 하위 호환 cache로만 읽으며 전환 뒤 쓰기
권위로 사용하지 않는다.

### 7.2 온라인 save payload

경제 전환 후 일반 save payload에는 로컬 권위 데이터와 모듈 장착 ID만 동기화한다.
로컬 통파일의 `economyCache`를 보내더라도 서버는 저장 원본으로 사용하지 않는다.
권장 구현은 `GameSaveData`와 별도의 `CloudSaveData` serializer를 두어 경제 cache가
애초에 `PUT /v1/save` body에 포함되지 않게 하는 것이다.

save Outbox의 payload fingerprint도 로컬 `GameSaveData.toJson()`이 아니라 실제로
전송하는 canonical `CloudSaveData` bytes를 기준으로 계산한다. 경제 cache만 바뀐 것을
일반 진행 dirty로 오인해 불필요한 save revision을 증가시키지 않는다.

원격 일반 저장을 rebase한 뒤에는 반드시 `GET /v1/economy` 결과를 overlay한다.
두 응답의 도착 순서가 바뀌어도 높은 economy revision만 적용한다.

### 7.3 두 종류의 outbox

일반 save outbox와 경제 command outbox는 합치지 않는다.

| 종류 | 보존 규칙 | 오프라인 신규 생성 | 자동 실행 |
| --- | --- | --- | --- |
| save outbox | in-flight 하나 + 최신 pending 하나 | 허용 | 연결 복구 시 전송 |
| 소비 command | expected economy/catalog revision을 가진 exact in-flight 하나 | 금지 | 응답 불명확 요청만 같은 body 재시도 |
| 보상 claim | expected economy revision 없는 FIFO exact command | 허용 | 유효한 writer 분기일 때 순서대로 전송 |
| progression effect | 서버 pending 목록 + 로컬 적용 journal | 서버 명령 성공 시 생성 | rebase 뒤 멱등 적용·save·ack |
| 구매 검증 | expected economy revision 없는 provider 거래별 exact 항목 | 구매 단계에서 허용 | 검증 완료까지 재시도 |

뽑기 같은 소비 명령을 오프라인에서 여러 개 쌓아 두었다가 나중에 자동 실행하면 사용자가
보지 못한 최신 잔액으로 예상 밖의 소비가 발생할 수 있다. 따라서 오프라인 버튼은
비활성화하고, 서버에 실제로 전송했으나 응답만 유실된 한 요청만 exact retry한다.

reward claim과 구매 검증은 `expectedEconomyRevision`을 보내지 않는다. 서버가 현재
`player_economies` head를 잠그고 reward key 또는 provider transaction unique를 검사한
뒤 현재 revision에서 1 증가시킨다. 따라서 같은 revision에서 여러 보상을 FIFO에
쌓아도 첫 보상 성공 때문에 다음 보상이 stale conflict로 막히지 않는다.

명령 유형별 revision 계약:

| 명령 | expected economy revision | expected catalog version | save writer/source revision |
| --- | --- | --- | --- |
| 뽑기·분해 | 필수 | 필수 | 해금 조건을 읽으면 필수 |
| 연구 즉시 완료·슬롯 해금 | 필수 | 필수 | 필수 |
| 퀘스트·런 진행 보상 | 없음 | 서버가 현재 보상 catalog 사용 | 필수 |
| 서버 시각만 보는 출석 | 없음 | 없음 | 없음 |
| progression effect ack | 없음 | 없음 | 반영된 save revision 필수 |
| 구매 검증 | 없음 | 상품 catalog version 또는 provider product ID | 없음 |

### 7.4 적용 순서

로그인·앱 재개 시:

1. 인증 session 복구
2. exact 경제 in-flight가 있으면 같은 요청의 영수증을 복구해 응답을 영속하되,
   progression effect는 아직 적용하지 않음
3. 일반 save의 exact in-flight와 revision 판정 수행
4. 원격 일반 저장이 앞섰으면 backup 후 rebase
5. `GET /v1/economy` 조회와 authority epoch 확정
6. authoritative cache와 entitlement를 overlay
7. 서버 pending progression effect를 선택된 진행에 멱등 적용
8. 로컬 통파일과 일반 save 업로드가 성공한 effect만 서버에 ack
9. 소유하지 않은 장착 ID 정리
10. 현재 writer 분기가 유효하면 pending reward claim 전송
11. 일반 플레이 활성화

경제 조회가 실패해도 캐시된 모듈로 일반 플레이는 허용한다. 단 경제 변경 UI는
조회가 성공할 때까지 잠근다.

## 8. 멱등성·동시성·장애 처리

### 8.1 서버 transaction 공통 순서

```text
기존 command 영수증 조회
BEGIN
필요한 경우 save_writer_states FOR UPDATE
필요한 경우 save_headers FOR UPDATE
player_economies ensure 후 FOR UPDATE
command 영수증 재조회
명령 유형별 expected revision·catalog·writer·행동 조건 검사
잔액/모듈/claim 변경
원장과 exact 응답 영수증 기록
COMMIT
```

빠른 영수증 조회와 잠금 뒤 재조회가 모두 필요하다. 동시에 도착한 같은 key 요청이
두 번 처리되는 것을 잠금 뒤 재조회가 막는다.

모든 aggregate를 함께 읽는 transaction의 잠금 순서는
`save_writer_states -> save_headers -> player_economies`로 고정한다. 경제 행이 없는
bootstrap은 `INSERT ... ON CONFLICT DO NOTHING`으로 head를 보장한 뒤 같은 transaction
안에서 `FOR UPDATE`한다. 존재하지 않는 행에 `FOR UPDATE`만 실행하지 않는다.

소비 명령은 expected economy revision을 검사한다. reward claim과 구매 검증은 이를
검사하지 않고 고유 reward/provider key로 중복을 막는다. 모든 성공 명령은 잠근 현재
head에서 economy revision을 정확히 1 증가시킨다.

### 8.2 오류 계약

| HTTP | code | 처리 |
| --- | --- | --- |
| `401` | 인증 오류 | refresh 1회 뒤 같은 요청 재시도 |
| `409` | `ECONOMY_REVISION_CONFLICT` | 최신 상태 조회, 소비 자동 재실행 금지 |
| `409` | `ECONOMY_CATALOG_CHANGED` | 소비 없이 catalog 재조회와 확인 UI 갱신 |
| `409` | `IDEMPOTENCY_KEY_REUSED` | blocked, 진단 기록 |
| `409` | `REWARD_ALREADY_CLAIMED` | 다른 key의 중복 claim이면 최신 상태 적용 |
| `409` | `SAVE_WRITER_REPLACED` | 로컬 플레이 보상 claim 정지와 save rebase |
| `422` | `INSUFFICIENT_DIAMONDS` | 최신 상태 적용, 사용자에게 부족 표시 |
| `422` | `INSUFFICIENT_MODULE_TICKETS` | 최신 상태 적용 |
| `422` | `MODULE_NOT_OWNED` | 목록 재조회와 장착 정리 |
| `426` | `CLIENT_UPDATE_REQUIRED` | 경제·계정 저장 변경 금지, 업데이트 안내 |
| `429`, `5xx`, timeout | 일시 오류 | 같은 key와 exact body 재시도 |

재시도 가능한 오류에서 idempotency key, expected revision과 body를 바꾸지 않는다.
revision 충돌은 전송 성공 여부가 불명확한 timeout과 다르므로 자동으로 새 명령을
만들지 않는다.

경제 오류 body에는 최소 `authorityEpoch`, `currentEconomyRevision`과
`currentCatalogVersion`을 포함한다. 모듈 목록 전체는 오류 body에 반복하지 않고
클라이언트가 `GET /v1/economy`로 다시 조회한다.

## 9. 기존 사용자 보존형 migration

현재 저장 값은 조작 가능하므로 과거의 유료 구매 증명으로 취급할 수 없다. 다만
정식 결제 도입 전 플레이테스트 진행을 잃지 않도록 계정당 한 번만 다음 방식으로
이전한다.

1. 사용자가 account에 로그인하고 기존 guest를 연결할 경우 먼저 현재 절차로 원격
   저장을 생성한다.
2. 클라이언트는 account 진행 변경을 잠그고 save Outbox의 exact in-flight와 pending을
   모두 처리한다. 현재 로컬 `CloudSaveData` fingerprint가 마지막 ack와 같을 때만
   bootstrap을 시작한다.
3. bootstrap 요청은 잔액이나 모듈을 받지 않고 `expectedSaveRevision`, 현재 writer
   generation, client compatibility version과 authority version만 받는다.
4. 서버는 클라이언트가 보낸 임의 잔액이 아니라 잠근 최신 account snapshot을 읽는다.
5. progression의 free·paid diamond 합계를 모두 `free_diamonds`로 이전하고
   `paid_diamonds`는 0으로 시작한다.
6. 모듈권·뽑기 횟수와 카탈로그에 맞는 모듈을 이전한다.
7. 잘못된 모듈 옵션은 무조건 보정해 가져오지 않고 원본 snapshot backup과 진단
   목록을 남긴다.
8. `legacy_bootstrap` command·원장·모듈·source save revision과
   `authority_state=server_authoritative` 변경을 한 transaction에 기록한다.
9. 같은 account의 두 번째 bootstrap은 최초 exact 결과를 반환하거나 거부한다.
10. 응답의 legacy ID 대응으로 로컬 장착 ID를 서버 UUID로 바꾼 뒤 통파일 저장한다.

bootstrap transaction의 잠금·검사 순서는 다음과 같다.

```text
BEGIN
save_writer_states FOR UPDATE
현재 session/generation 확인
save_headers FOR UPDATE
expectedSaveRevision과 현재 revision 일치 확인
player_economies INSERT ... ON CONFLICT DO NOTHING
player_economies FOR UPDATE
기존 bootstrap receipt/authority_state 재확인
서버 저장 snapshot 읽기와 경제 변환
경제 행·모듈·원장·exact receipt 기록
authority_state = server_authoritative
COMMIT
```

현재 save PUT도 같은 `save_writer_states -> save_headers -> player_economies` 순서로
잠그거나 authority 상태를 같은 transaction에서 확인한다. bootstrap보다 먼저 시작한
legacy PUT은 끝난 뒤 bootstrap이 그 최신 revision을 읽고, bootstrap보다 늦게 도착한
구버전 PUT은 `426 CLIENT_UPDATE_REQUIRED`로 거부한다. 새 클라이언트의 CloudSaveData
PUT은 경제 cache를 포함하지 않으므로 계속 허용한다.

bootstrap 응답에는 다음 진단을 포함한다.

- `importedLegacyIdMap`
- `rejectedModules`의 legacy ID와 사유
- 무효 모듈 때문에 제거한 `clearedEquippedIds`
- `bootstrapSaveRevision`, authority epoch와 resulting economy revision

거부된 모듈의 원본은 account snapshot backup에 남긴다. 누락을 성공으로 숨기지 않고
클라이언트가 장착 상태를 자동 정리한 뒤 진단 화면에서 확인할 수 있게 한다.

기존 `paidDiamonds`를 무료 다이아로 합치는 이유는 현재 저장에 실제 스토어 구매
증명이 없기 때문이다. 실제 결제를 연 뒤에는 legacy bootstrap을 닫고 provider 검증을
통과한 거래만 paid 잔액을 늘린다.

전환 뒤 구버전 클라이언트가 로컬 경제를 계속 쓰지 않도록
`clientCompatibilityVersion`과 `economyAuthorityVersion` gate를 먼저 배포한다. 이미
bootstrap된 account는 지원하지 않는 호환 세대의 save·경제 변경을 `426`으로 거부한다.
일반 save가 받아들여지더라도 그 payload의 경제 필드는 서버 경제에 절대 반영하지
않는다.

## 10. 기능 플래그와 배포 순서

다이아 쓰기 권위는 기능별로 조금씩 켜지 않는다. 구현은 세로 기능 단위로 나누되,
account 전환은 모든 경로가 준비된 뒤 원자적으로 수행한다.

```text
legacy_local
  -> bootstrap_in_progress
  -> server_authoritative
```

- `legacy_local`: 기존 플레이와 저장만 사용, 새 서버 경제는 외부에 노출하지 않음
- `bootstrap_in_progress`: client coordinator가 진행·경제 UI를 잠근 transient 상태.
  서버의 단일 transaction이 rollback되면 legacy 상태로 재시도하고, commit되면 곧바로
  server authoritative가 됨
- `server_authoritative`: 모든 다이아·티켓·모듈 변경은 명령 API만 사용

`server_authoritative`에서 `legacy_local`로 되돌리는 rollback은 허용하지 않는다.
장애 시에는 경제 명령을 일시 중지하고 캐시로 일반 플레이만 허용한다. 로컬 잔액을
다시 원본으로 삼으면 이미 확정된 서버 가챠를 복제할 수 있기 때문이다.

## 11. 구현 작업 분해

### 단계 0. 선행 저장 안전성

현재 미완료인 다음 작업을 먼저 끝낸다.

- canonical Outbox와 exact in-flight 영수증 우선 복구
- revision 기반 자동 rebase와 crash-safe backup journal
- save writer generation API·DB
- Web 다중 탭 writer 잠금
- [x] 구버전 `clientCompatibilityVersion` gate

성공 기준:

- 이전 writer의 보상은 exact 영수증 우선 확인 뒤 `remote > base`일 때만 폐기되고,
  `remote == base`이면 안전하게 suspended·재결속된다.
- 실제 다중 기기 충돌은 사용자 선택 없이 원격 진행으로 복구된다.

### 단계 1. 경제 도메인 경계와 DB 기반

예상 변경 위치:

```text
server/db/migrations/003_authoritative_economy.sql
server/db/queries/economy.sql
server/internal/economy/catalog.go
server/internal/economy/service.go
server/internal/httpapi/economy.go
```

작업:

- 위 테이블과 sqlc 쿼리 추가
- economy snapshot, command와 error 도메인 정의
- authority epoch와 DB restore 회전 절차 구현
- catalog version, 티켓 가격, 등급 확률, 옵션 범위와 분해 가격의 서버 원본 정의
- `GET /v1/economy`, bootstrap 구현
- 계정 격리, bootstrap/save PUT 경쟁, 1회성, transaction rollback 통합 테스트

성공 기준:

- bootstrap 재시도는 같은 결과를 반환한다.
- bootstrap과 legacy save PUT의 순서가 바뀌어도 최신 ack snapshot만 이전된다.
- 일반 save PUT으로 경제 행이나 모듈을 변경할 수 없다.

### 단계 2. 가챠·분해 서버 vertical slice

작업:

- 서버 뽑기와 분해 명령, 안전한 RNG와 exact 영수증 구현
- expected catalog version과 실행 catalog/RNG algorithm version 기록
- Flutter `EconomyApi`, `EconomyCoordinator`와 영속 exact in-flight 구현
- 현재 동기 `drawTurretModules`, `disassembleTurretModules` UI를 async 결과 기반으로 변경
- `RunProgression`에는 서버 snapshot 적용과 모듈 효과 계산만 남김
- 오프라인·전송 중·revision 충돌 UX 추가

성공 기준:

- 응답 유실 재시도에서 동일 모듈만 반환된다.
- 두 기기의 같은 revision 뽑기 중 하나만 성공한다.
- 저장 rollback이나 재로그인으로 뽑기 전 잔액으로 돌아갈 수 없다.
- unique 모듈 분해 정책이 개별·일괄에서 일치한다.

### 단계 3. 나머지 다이아 소비

작업:

- 연구 즉시 완료와 두 번째 연구 슬롯 해금 명령 추가
- 연구 슬롯 2 서버 entitlement와 pending progression effect 테이블·조회·ack 구현
- save rebase -> effect 적용 -> 통파일 저장 -> cloud save ack -> effect ack 순서 구현
- 무료 다이아 우선 소비를 서버·클라이언트 표시에서 동일하게 검증

성공 기준:

- 서버 차감 뒤 앱 종료가 발생해도 효과가 누락되거나 이중 차감되지 않는다.
- 명령을 보낸 기기의 로컬 저장이 사라져도 다른 기기가 pending effect를 적용한다.
- 오프라인에서 소비 버튼이 명령으로 예약되지 않는다.

### 단계 4. 모든 보상 지급 경로

작업:

- stable run ID와 런 종료 1회 pending diamond 정산 모델 추가
- run settlement와 현재 writer generation 결속
- 일·주간 퀘스트, 출석과 스테이지 최초 클리어 reward key 추가
- account별 durable reward claim outbox 구현
- 서버 기간 키와 클라이언트 표시 overlay
- release debug 지급 경로 차단

성공 기준:

- 같은 보상은 다른 기기·다른 idempotency key로도 한 번만 지급된다.
- 여러 reward claim이 같은 최초 economy revision에서 생성돼도 FIFO로 모두 처리된다.
- 오프라인 런 보상은 유실되지 않지만 승인 전 소비할 수 없다.
- writer 교체 뒤 `remote == base` 보상은 보존되고 `remote > base` 분기의 보상만 무효화된다.

### 단계 5. 저장 v3와 account 단위 전환

작업:

- `economyCache`와 `turretModuleLoadout`을 분리하는 보존형 v3 migration
- 일반 cloud save serializer에서 경제 cache 제외
- save Outbox fingerprint를 canonical CloudSaveData bytes 기준으로 변경
- v2 snapshot 기반 bootstrap과 legacy module ID 대응
- 모든 경제 변이 경로가 server coordinator를 거치는 정적 검색·테스트
- `legacy_local`에서 `server_authoritative`로 account 1회 전환
- 구버전 호환 세대 차단과 장애 시 경제 read-only 모드

성공 기준:

- 기존 사용자 진행과 장착 모듈이 보존된다.
- 전환된 account에는 로컬 경제 writer가 하나도 남지 않는다.
- 원격 일반 저장 rebase 뒤에도 경제 상태가 낮아지지 않는다.

### 단계 6. 실제 구매

Google Play 결제가 필요할 때만 진행한다.

- Google Play purchase token 서버 검증
- provider transaction unique와 중복 지급 방지
- acknowledgement·소비 정책 확정
- paid diamond 지급과 환불·취소 처리
- Apple StoreKit 거래 검증 추가

외부 관리형 백엔드나 유료 인증·경제 서비스는 도입하지 않고 현재 Go API와
PostgreSQL 안에서 처리한다.

## 12. 테스트 계약

### 서버 단위·통합 테스트

- 같은 key·같은 body 재시도 exact response
- 같은 key·다른 body 거부
- 같은 economy revision의 동시 뽑기 하나만 성공
- catalog 변경 직전 소비가 금액 차감 없이 거부됨
- 무료 다이아 우선 소비와 잔액 부족 rollback
- 티켓 구매, 차감, RNG, 모듈 생성의 전체 transaction rollback
- 안전 RNG 결과가 카탈로그 범위를 벗어나지 않음
- 존재하지 않음·타 account·이미 분해된 모듈 거부
- reward key 중복 지급 거부
- expected revision 없는 reward FIFO가 앞 command의 revision 증가 뒤에도 계속 처리됨
- writer 교체의 `remote == base` 보존과 `remote > base` run reward claim 거부
- bootstrap/save PUT 경쟁, 1회성, paid -> free 이전, invalid legacy module 진단
- DB restore 뒤 authority epoch 회전과 낮은 revision 재기준화
- pending progression effect의 save payload 확인 전 ack 거부
- account 삭제 cascade와 원장·영수증 보존 정책

### Flutter 테스트

- 오프라인 경제 버튼 비활성화와 일반 플레이 유지
- 응답 유실, 앱 재시작 뒤 exact in-flight 복구
- 서버 응답 영속 전/후 강제 종료 복구
- 같은 authority epoch의 낮은 revision 응답 무시와 새 epoch 재기준화
- 저장 rebase 뒤 authoritative overlay
- rebase 뒤 pending progression effect 적용과 cloud save 성공 전 ack 금지
- 분해 뒤 장착 ID 자동 정리
- pending run 보상과 확정 잔액 분리 표시
- 다른 account outbox로 경제 명령이 전송되지 않음
- economy cache 변경만으로 CloudSaveData fingerprint가 바뀌지 않음

### E2E 시나리오

1. A와 B가 같은 10,000 다이아·economy revision을 조회한다.
2. A가 뽑아 revision을 증가시킨다.
3. B의 오래된 요청은 충돌하고 결과를 만들지 않는다.
4. A 응답을 강제로 유실해도 같은 결과만 복원된다.
5. B가 새 revision을 받은 뒤 다시 명시적으로 뽑으면 별도 비용과 결과가 확정된다.
6. 어느 기기의 일반 save를 복구·재설치해도 서버 잔액과 모듈은 되돌아가지 않는다.
7. 같은 base에서 만들어진 여러 오프라인 reward claim은 FIFO로 각각 한 번씩 지급된다.
8. writer만 교체되고 save가 전진하지 않으면 기존 보상이 보존되며, 다른 기기 save가
   전진한 뒤에는 폐기 분기의 보상이 지급되지 않는다.
9. DB backup 복원 뒤 새 authority epoch를 받은 클라이언트가 기존 cache를 backup하고
   서버 경제 상태로 재기준화한다.

## 13. 범위 밖

- 전투 프레임·포탑 공격의 서버 판정
- 모든 적 처치 이벤트의 실시간 서버 전송
- WebSocket
- 서로 다른 오프라인 일반 진행의 병합
- 서버 권위 연구·스테이지 시뮬레이션
- 외부 유료 인증·경제·분석 서비스
- 통계 한 건만으로 자동 계정 제재

## 14. 최종 추천 순서

현재 형상에서 실제 구현은 다음 순서가 가장 안전하다.

1. 다중 기기 save canonical Outbox·자동 rebase 완성
2. save writer generation과 구버전 client compatibility gate 완성
3. 경제 DB·`GET /v1/economy`·bootstrap을 기능 플래그 뒤에 구현
4. 가챠·분해 vertical slice와 Flutter exact command 복구 구현
5. 연구 소비와 모든 다이아·모듈권 보상 경로 구현
6. 저장 v3 migration과 account 단위 서버 권위 전환
7. 공개 환경 두 기기 E2E와 운영 backup 검증
8. 필요할 때만 Google Play 구매 검증 추가

가장 먼저 경제 코드부터 작성하는 것보다 1~2번을 선행해야 한다. 보상 claim을 현재
save writer에 묶고, 오래된 기기가 로컬 진행과 보상을 함께 제출하는 경로를 막기 위한
전제이기 때문이다.
