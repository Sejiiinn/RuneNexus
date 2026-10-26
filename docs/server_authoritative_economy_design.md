# Rune Nexus 서버 권위 경제 상세 설계

문서 상태: 채택 설계 · 서버 권위 경제 MVP 구현
기존 경제 MVP 설계: 2026-08-30. 웨이브 젬·필수 인증 계약 점검: 2026-10-12. 문서 정리: 2026-10-27 KST(전환 전 구현 단계 기록 분리).

`player_economies`, 별도 economy revision·authority epoch, 모듈 소유권, 원장과 exact
명령 영수증을 구현했다. 기존 account 저장은 최초 연결 시 한 번만 bootstrap하며 구매
다이아를 무료 다이아로 합산한다. 로그인 account의 모듈 뽑기·분해, 연구 즉시 완료,
두 번째 연구 슬롯, 일·주간 보상, 런 획득 다이아와 스테이지 11 최초 모듈권은 모두
서버 명령으로만 확정된다. Flutter `EconomyCoordinator`는 계정별 경제 Outbox를 사용해
응답 유실 시 같은 key와 본문을 복구하고, 일반 save의 경제 필드는 서버 원본을 변경하지
못한다. 경제 전환 계정은 최소 호환성 세대 2를 요구한다. 성장 이전
(`progression.growthVersion=1`)을 마친 계정은 세대 3을 요구하며 성장 버전 회귀도
거절한다. 서버 선배포 중 미이전 계정의 세대 2를 허용하고 필수 앱 공개 후 전역 최소
세대를 3으로 올린다. 저장 schemaVersion은 2를 유지한다.

구세대 명령은 이미 처리된 exact 영수증을 복구할 수 있다. 미처리 구세대 경제 요청이
426으로 거절되면 새 앱은 요청만 폐기하고 미지급 런 보상은 보존해 새 요청으로
재정산한다. 과거 토벌 즉시완료 영수증은 이전된 토벌 강화에 멱등 적용한다.

일반 저장 형식은 당장 v3로 크게 바꾸지 않고 v2 경제 필드를 bootstrap source와 로컬
표시 cache로 유지한다. 따라서 단계 5의 별도 `CloudSaveData` serializer와 경제 cache
제외는 후속 최적화이며, 실제 Google 계정·다중 기기 공개 E2E와 운영 백업 검증은 아직
남아 있다. 실제 Google Play 결제 검증은 상품 도입 시 별도 단계로 진행한다.

## 젬 보상과 도전 수명주기 (호환 세대 9)

무료 웨이브 보상과 기존 20파편 구매 선택의 후보 생성·선택 확정은 인증된 계정의 서버 명령으로 처리한다. 도전 전체 무료 재선택 1회와 젬 리셋권 1장당 추가 1회(최대 2회)를 유지한다. 구매 선택에는 재선택·10파편 대체 선택을 추가하지 않는다. 웨이브 재선택은 바로 직전 후보 3종만 제외하며 그 이전 후보는 다시 나올 수 있다. 후보 풀은 기존 해금 기준(기본 12종, 추가 2종)이다. 상점·광고·다이아 결제나 실제 계정 리셋권 지급은 추가하지 않는다.

세대 10 앱이 시작한 도전은 아래 [런 젬 덱](#런-젬-덱-호환-세대-10)을 사용한다. 이 절의 서버 명령 흐름은 덱이 없는 도전(세대 9 이하에서 시작했거나 덱 발급 전에 열린 도전)에 적용한다.

### 권위·저장 경계

- 새 후보는 서버 암호학적 난수로 균등 비복원 추출하고 응답 전에 영속한다. 계정·도전·웨이브별 wave offer는 최대 7행이다. 같은 의미의 최초 발급을 새 key로 재요청하면 읽기만 수행하며 후보·영수증·save/economy revision을 추가하지 않는다. 단, 아직 이전하지 않은 canonical 저장의 최초 요청은 아래 한 번의 adoption을 commit한 뒤 복구 결과를 노출하며, 새 writer claim을 먼저 했다는 클라이언트 순서에 의존하지 않는다. 리롤·선택은 현재 offer ID/revision과 writer/source/economy revision을 검사한다.
- `economy_runs`는 서버 발급 UUID, 계정당 하나의 열린 도전, 스테이지, 정확한 타입별 젬 소유 합계, 리롤 예산, 마지막 구매 offer/구매 차수를 보존한다. 새 도전은 ID 없는 완전한 초기 체크포인트를 동기화한 뒤 start로 결속한다. 이미 진행된 checkpoint·보상·사용 예산을 새 UUID에 결속하지 않는다. 일반 save의 null/다른 UUID는 열린 도전을 종료하지 못한다. 명시적 close 또는 정산으로 닫으며, 닫힌 UUID는 tombstone으로 남아 재활성화하지 않는다.
- 가방과 저장 codec이 보존하는 장착 슬롯의 타입별 합계는 서버 소유 합계와 정확히 같아야 한다. `equippedGemSlots`가 있으면 `equippedGems` 미러를 중복 계산하지 않으며, 구형 슬롯 배열이 없는 저장만 기존 fallback을 읽는다. 장착·해제·교체·포탑 판매는 소유 젬의 위치를 바꾸므로 허용한다. 미래 소비/합성 기능은 소유 합계를 변경하는 명령을 추가해야 하며 일반 저장으로 젬을 없애거나 만들어서는 안 된다. 슬롯 codec 의존성은 별도 소유권 adapter에 모은다.
- 20파편 구매는 현재 단계·wave/준비 복귀 위치·파편 잔액을 확인하고 차감, 후보, 차수, 저장, 영수증을 같은 트랜잭션에서 확정한다. 현재 구매 offer는 도전 aggregate에 하나만 보존하고, 이전 완료 결과는 작고 불변인 명령 영수증으로 복구한다. wave 선택도 젬/10파편 지급·재고·offer 완료·save revision을 원자적으로 확정한다.
- 전투 수행·웨이브 완료·스테이지 클리어·파편 획득은 여전히 클라이언트 보고를 신뢰한다. 조작된 획득 파편으로 서버 구매 명령을 통과할 가능성까지 차단한 것은 아니다. 서버 UUID와 정확한 젬 보존은 전투 증명이나 게임 전체 부정행위 방지를 의미하지 않는다. 금화·포탑 배치·스탯을 서버 전투로 다시 구현하지 않는다.

### 인증·복구

정식 앱에는 게스트 플레이가 없다. 업데이트 확인과 별도로 실제 인증·계정 저장·경제 복구가 끝나기 전에는 시작·이어하기·전투와 보상 선택을 잠근다. 통신 실패가 기존 인증 정보·계정 저장을 지우거나 로컬 fallback 플레이를 열지 않는다.

계정별 durable Outbox는 요청 key/본문을 재시도 내내 보존한다. 새 젬/start/close 명령의 `gemReceipt.version=1`은 권위 epoch·경제 revision·리셋권 잔액과 작은 명령 결과만 보존한다. 전체 `activeRun`, 모듈, 평생 reward claim keys를 매 영수증에 복제하지 않는다. exact 결과를 확인한 뒤 `GET /v1/economy`와 `GET /v1/save`의 현재 상태를 대조해 저장/경제 기준을 수용하고 나서 Outbox를 완료한다. 과거 영수증을 현재 전체 save로 사용하지 않으며, 정상인 후속 웨이브·새 도전·후속 구매·로컬 장착을 되돌리지 않는다. `gemEconomyRevision`은 같은 웨이브의 서로 다른 구매 offer 간 순서를 구분한다. 중간 쓰기 실패·주 저장 손상·백업 복구도 같은 경로를 따른다. 선택과 함께 요청한 로컬 자동 장착은 원래 선택 직후 canonical revision에서만 처리한다. 다른 기기의 후속 저장이나 사라진/변경된 장착 대상 때문에 의도가 낡았으면 현재 소유분과 배치를 보존한 채 장착 의도만 완료 처리한다. 새로 지급된 젬을 재지급하거나 새 대상으로 돌리지 않으며, 실제 로컬 저장 실패는 완료로 숨기지 않고 Outbox를 재시도 상태로 남긴다. 장착까지 로컬 완료한 뒤 업로드 전에 주 저장이 손상된 경우에도 마지막 장착 의도는 현재 canonical GET을 거친 live 복구에서만 재검토한다. 캐시 로드는 장착하거나 취소하지 않고, 완료된 명령 POST를 다시 보내지 않는다.

젬/구매/start/close와 economy/save GET 복구 읽기는 인증된 account를 기준으로 공유 token bucket(프로세스당 분당 60회, 최대 20,000계정)을 적용한다. 세션 교체로 제한을 우회하지 못하고 429의 `Retry-After` 후 durable 요청을 재시도한다. 다중 API replica의 전역 요청 제한은 별도 ingress/shared limiter가 필요하다. 의미상 읽기 전용인 offer 복구도 동시 상태를 맞추기 위한 FOR UPDATE 잠금을 사용한다. 새 영수증·상태 revision·지급을 만들지 않는다는 뜻이며 DB 잠금/물리 쓰기/WAL 비용이 0이라는 주장은 아니다.

### 선배포·이전·보존

migration 014–016과 API, 세대 9 앱을 함께 검증해 준비한다. 실제 적용 시에는 구 API 인스턴스의 쓰기를 먼저 막고 transactional migration을 적용한 뒤 모든 API를 새 버전으로 바꾼다. 구 바이너리가 migration 뒤에 canonical 저장을 갱신하는 혼합 쓰기 구간을 허용하지 않는다. 앱 공개·필수 업데이트 안내는 이 쓰기 전환과 조율한다. 저장 schemaVersion은 2를 유지한다. 최초 전환은 migration 016 시점에 고정한 canonical save revision의 activeRun 젬 보유/장착과 기존 서버 예산만 한 번 import하고 provenance를 남긴다. `account_run_authorities`의 pin이 없는 새 계정은 기존 UUID/보유분을 import하지 않는다. 모든 새 writer/save 요청은 세대 9 미만이면 exact 영수증 조회 뒤 거절한다. 이 기준은 운영 환경값에만 의존하지 않고 서비스에서 적용한다. 세대 9는 먼저 이전한 뒤 새 저장을 검사한다. GET과 기존 exact 영수증 읽기는 유지한다. 새로 전송된 save나 임의 UUID를 import source로 삼지 않는다. 활성 도전이 없던 계정도 전환 표식을 남겨 후속 import를 금지한다. 이미 정산된 도전은 닫힌 상태로 이전한다. migration 시점의 canonical run에 ID가 누락/null/빈 문자열이면 그 트랜잭션 안에서 서버 UUID를 한 번 부여하고 해당 save revision만 증가시킨 뒤 pin한다. 기존 canonical 리롤 사용량이 영속 예산보다 작으면 사용량만 최댓값으로 올리고 해당 header revision을 증가시킨 뒤 pin한다. clientSavedAt, 기존 후보와 그 밖의 게임 진행 값은 보존하며, 첫 bootstrap 업로드 전에 canonical과 소유권 예산이 일치한다. 이전 paid 선택 중인 canonical 저장은 이미 지불한 비용과 기존 후보를 legacy provenance로 한 번 보존한다. 뒤늦은 로컬/게스트 이전 경로가 이 기준을 덮어쓰거나 새 젬을 legacy로 등록하지 못한다. 서버에 동기화되지 않았던 구세대의 추가 젬/도전은 자동으로 권위화하지 않으며, 충돌 백업을 보존해 사용자가 복구 경위를 확인할 수 있게 한다. 세대 7/8에서 확정된 exact 영수증의 full recovery 자료는 변경·삭제하지 않으며 신규 명령에는 세대 9를 요구한다.

닫힌 도전 ID, wave 완료 기록, 리롤 예산과 exact 명령 영수증은 계정 생존 동안 보존한다. 기간 기반 삭제나 재사용은 하지 않는다. 계정 삭제의 기존 cascading 정책 외에 이번 변경으로 데이터를 지우지 않는다. 향후 보관 축소에는 replay/부활 방지를 보존하는 별도 정책과 migration이 필요하다.

### 코어 트리 v5 호환 경계

코어 트리 v5와 새 전투 저장 필드는 호환 세대 10에서 사용한다. 저장 스키마는 2를 유지하며, [코어 트리 계약](core_passive_tree_implementation_plan.md)의 생성 카탈로그를 서버 배분 검사에도 사용한다. 서버가 지원하는 최댓값 10과 모든 계정의 최저 버전은 별개다. 기존 세대 9의 revision 4 진행·활성 도전·초기 preparation 체크포인트 복구는 유지하고, 새 앱이 만드는 도전은 revision 5 배분을 시작 시점에 고정한다. 이미 고정한 도전 배분은 바꾸지 않으며, 계정 배분 변경은 다음 도전에만 적용한다.

revision 5 계정 또는 새 필드를 사용하는 저장에는 세대 10 writer/save·경제 명령이 필요하다. 이전 세대의 새 쓰기나 최신 클라이언트의 오래된 Outbox로 revision을 낮출 수 없다. exact 본문 SHA-256 영수증 조회는 이 검사보다 먼저 수행하며 기존 요청 본문과 누락된 필드는 다시 쓰지 않는다. 살아 있는 revision 4 도전의 이전은 미루고, 종료 시 legacy 배분·실제 누적 비용을 보관한 뒤 무료 초기화한다. 종료 보상·다음 배분이 한 PUT으로 합쳐져도 허용하며, 코어 포인트 획득의 기존 클라이언트 신뢰 경계는 바꾸지 않는다. 잘못된 배분·보관 비용·고정 런·새 전투 필드는 `422 INVALID_SAVE_DATA`, 구세대의 새 쓰기는 `426 CLIENT_UPDATE_REQUIRED`로 거절한다. 배포·검증 상태는 [배포 인계](deployment_status.md)가 원본이다.

### API·snapshot 계약

- `POST /v1/economy/runs/start`: source save/economy revision·catalog·writer generation·compatibility와 `stageNumber`. 초기 canonical checkpoint에 서버 UUID를 결속한다.
- `POST /v1/economy/runs/close`: 같은 공통 필드와 `runId`. tombstone 생성과 canonical run 제거를 원자 처리한다. 현재 열린 도전은 snapshot의 `run`으로 재개한다.
- `POST /v1/economy/gems/offer`: 공통 필드와 `runId`, `completedRounds`.
- `POST /v1/economy/gems/purchase`: 같은 공통 필드. 고정 20파편을 차감하며 클라이언트 후보/금액은 받지 않는다.
- `POST /v1/economy/gems/reroll`: 현재 `offerId`, `expectedOfferRevision`, `expectedRerollCount`를 더한다.
- `POST /v1/economy/gems/choose`: 현재 `offerId`, `expectedOfferRevision`, `choice`(후보 ID 또는 wave의 `shards`). 지급량은 서버가 정한다.
- `gemOffer`는 `offerId/runId/kind/rewardWave/revision/economyRevision/totalUsed/gemOptions/status/choice/grantedGem/grantedShards/gemInventory/gemShards`를 가진다. 구매에는 `purchaseSequence/returnPhase`가 추가된다. `pending/chosen` 상태와 header/payload 일치를 DB 제약과 서비스가 확인한다.
- 새 명령 응답은 `gemReceipt`, `gemOffer` 또는 `run`, `saveRevision`, `serverSavedAt`이며 full save/economy는 포함하지 않는다. 과거 exact 응답의 계약은 별도로 유지한다.

검증은 서버 경제·save·HTTP·runstate 테스트, 실제 DB용 통합 검사, Godot gem/account/lifecycle/backup 회귀로 나눈다. 실행한 단계와 미검증 항목, 배포 승인 범위는 [배포 인계](deployment_status.md#현재-미배포-변경)에 기록한다.

## 런 젬 덱 (호환 세대 10)

젬 후보 표시·리롤·선택이 네트워크 왕복을 기다리지 않도록, 서버는 도전 시작 시 그 도전의 모든 후보를 미리 확정하고 클라이언트는 이를 즉시 적용한다. 서버는 도전이 닫힐 때 저장에 남은 기록을 덱과 대조하고 리셋권을 차감한다. 재선택 횟수·무료 1회·10파편 대체·구매 비용 등 보상 규칙은 위 절과 같다.

- 발급: 세대 10 `runs/start`가 서버 난수로 덱을 만들어 `economy_runs.gem_deck`(migration 017)에 저장하고 응답 `gemDeck`으로 돌려준다. 덱은 웨이브 5–35마다 offer ID와 후보 사슬(첫 후보 + 리롤 3회분, 각 항목은 직전 3종 제외), 구매용 offer ID·후보 24세트를 가진다. 후보 풀은 시작 checkpoint의 해금 기준이다. 해금 젬이 3종 미만이면 덱 없이 세대 9 흐름을 쓴다.
- 클라이언트: 덱은 메모리에만 둔다. `GET /v1/economy`는 열린 덱 도전의 `gemDeckVersion=1`·`gemDeck`을 돌려주며, 경제 Outbox 캐시에는 `gemDeck`만 빼고 저장한다. 재시작 뒤 덱을 다시 읽기 전에는 보상 조작을 잠그고 서버 젬 명령으로 대체하지 않는다. offer·리롤·선택·구매는 로컬 체크포인트에 바로 커밋하며 activeRun의 `gemDeckLog`(offer마다 `kind`, `wave` 또는 `sequence`, `rerolls`, `choice`)에 기록한다.
- 저장: 덱 도전의 일반 save는 서버 offer 행·리롤 예산·젬 소유 합계 일치 검사를 하지 않는다. 도전 UUID·스테이지 결속과 종료 tombstone 규칙은 유지한다. 덱 도전에 대한 `gems/*` 명령은 세대 10 요청이면 `GEM_OFFER_STATE_CONFLICT`, 그 미만이면 `CLIENT_UPDATE_REQUIRED`로 거절한다.
- 리셋권: 클라이언트는 사용분을 즉시 로컬 잔액에서 빼고, 열린 덱 도전이 있는 동안 서버 잔액 반영 시에도 그 사용분을 계속 제외한다. 서버는 정산(`runs/settle`) 또는 종료(`runs/close`) 트랜잭션에서 canonical 체크포인트의 리롤 수(`gemDeckLog`와 `gemRerollsUsed` 중 큰 값, 최대 3)로 비용을 계산해 한 번 차감하고 원장에 남긴다. 잔액은 0 아래로 내려가지 않는다.
- 젬 소비(세대 14): [지원 코어](support_core_design.md)를 지으면 소비한 가방 젬을 `{"kind":"consume","choice":젬}`으로 기록한다. 재생은 그때까지 받은 같은 젬이 있어야 하며 그만큼 보유 합계에서 뺀다. `supportCores` 또는 `consume` 기록이 있는 저장은 세대 14 미만 요청을 거절한다.
- 사후 대조: 서버는 기록을 덱에 재생해 표시 후보, 선택이 후보 안에 있는지, 보유 젬 합계, 리롤 수를 확인할 수 있다(`replayGemDeckLog`). 현재는 리롤 수 계산에만 사용하며, 불일치나 잔액 부족을 조작으로 판정해 조치하는 동작은 아직 없다.
- 한계: 덱은 클라이언트 메모리와 응답에 있으므로 다음 후보를 미리 보는 것은 막지 못한다. 전투·파편 획득의 클라이언트 신뢰 경계는 위 절과 같다.

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

전투 입력, 적 이동, 포탑 공격, 룬·코어 포인트, 연구 진행 시간, 스테이지 기록과 일반 활성 런은 기존 로컬 계산을 유지한다. 다만 위 젬 offer·선택·소유 합계·도전 ID와 아래 경제 원본은 서버가 확정하며, 정식 앱의 플레이에는 인증 및 복구 완료가 필요하다. 로컬 전투 계산을 허용한다는 사실을 게스트·미인증 플레이 허용으로 해석하지 않는다.

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

| 전환 전 경로 | 전환 전 처리 | 구현된 최종 권위 |
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
| 전투와 활성 런 | 인증된 세션의 로컬 전투 계산. 도전 ID·젬 offer·선택·소유 합계는 서버 원본에 종속 |
| 룬, 코어 포인트, 파편 획득과 업그레이드 | 기존 클라이언트 신뢰 범위 유지. 젬 장착 위치는 서버 소유 합계 안에서만 변경 |
| 스테이지 클리어·최고 라운드 | 클라우드 백업 대상이지만 서버 권위 판정 대상은 아님 |
| 퀘스트 진행량 | 로컬에서 누적하고 claim 때 서버에 행동 증거로 보고 |
| 연구 상태 | 시작·시간 완료와 레벨은 로컬. 즉시 완료 effect는 서버 영수증에서 멱등 적용 |
| 모듈 장착 ID | 일반 진행 스냅샷에 저장하고 서버 소유 목록과 대조 |
| 설정·플레이타임 | 기존 온라인 저장으로 동기화 |

모듈 장착은 인증·복구 gate를 통과한 로컬 전투에서 즉시 바꿀 수 있다. 서버 경제 상태를
새로 받았을 때 더 이상 소유하지 않은 ID는 자동 해제한다. 서버는 분해 요청에서
클라이언트의 `equipped` 값을 보안 조건으로 신뢰하지 않는다.

### 3.3 로컬 캐시

클라이언트는 마지막으로 받은 경제 snapshot을 로컬 통파일에 캐시한다. 캐시는 정식 앱의
인증·복구 gate를 대신하지 않는다. 연결 실패 시 다음 서버 확정 행동도 막는다.

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
다른 body·다른 명령 종류·다른 URL 대상(연구 종류, effect ID, 우편 ID)에 재사용하면
`IDEMPOTENCY_KEY_REUSED`를 반환한다.

- `request_hash`는 SHA-256 32 bytes CHECK를 둔다. URL 대상이 있는 명령은
  `<대상>\n<body>`(`research:<type>`, `effect:<id>`, `mail:<id>`), 나머지는 body를
  해시한다. 재생은 저장된 `command_type`과 해시가 모두 같을 때만 허용한다.
- 대상 결속 전 연구 완료·effect ack 영수증은 body만 해시했으므로, 같은 명령 종류와
  body의 재시도는 계속 재생한다(진행 중 재시도 호환). 이 영수증의 대상은 기록되지 않았다.
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

2026-09-10 보상표(출석 포함):

| 구분 | 개별 임무 다이아 | 출석 다이아 | 전체 임무 완료 보상 |
| --- | --- | --- | --- |
| 일일 | 각 20 | 20 | 다이아 40 + 모듈권 1개 |
| 주간 | 각 40 | 40 (5일 출석) | 다이아 100 + 모듈권 4개 |

일·주간 진행은 출석 1개와 전투 임무 4개 중 4개를 달성하면 완료 보상을 지급한다.
일일 출석은 해당 일 접속, 주간 출석은 해당 주의 서로 다른 5일 접속으로 달성한다.
개별 보상 수령 여부와 관계없이 달성한 임무를 집계하며, 진행 표시는 최대 `4 / 4`로 유지한다.
전체 완료 보상은 개별 임무 보상에 추가로 지급한다. 기존 수령 이력·영수증은 유지하며,
이미 수령한 보상에 차액이나 추가 모듈권을 소급 지급하지 않는다.

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

- 온라인이면 종료 체크포인트와 outbox 영속 기록 성공 직후 기존 계정 경제 worker로
  백그라운드 정산을 시작한다. 일반 30초 저장 동기화 주기나 결과창 닫기를 기다리지
  않는다. 결과창 이동은 통신 완료를 기다리지 않고, run ID별 요청 중·완료·통신 실패와
  재시도·오프라인·로컬 저장 실패를 구분한다. 실패 outbox는 유지하고 온라인 복구나
  수동 재시도에서 동일 요청 bytes와 idempotency key로 회복한다.
- 오프라인이면 확정 잔액과 분리해 표시하고 durable reward outbox에 보존한다.
- 같은 run ID는 성공·실패와 무관하게 한 번만 정산한다.
- 스테이지 최초 모듈권은 마지막 런 표시값이 아니라 run draft에 함께 보존한 증거로
  정산하며, bootstrap 시 이미 클리어한 계정은 수령 완료로 이관한다.
- 서버는 스테이지·완료 라운드별 가능한 상한과 현재 writer generation을 검사한다.
- 승인 전 pending 값은 뽑기나 연구에 사용할 수 없다.
- 서버가 영구 거부하면 잔액에 더하지 않고 run ID와 거부 코드를 outbox에 보존해
  성공 정산과 구분한다. writer 교체·동기화 요구는 영구 거부로 확정하지 않고 재동기화한다.

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

## 11. 구현 단계 기록

경제 전환의 단계별 작업 분해(단계 0–6), Flutter 클라이언트 테스트 목록, 단계별 진행 순서는 [전환 전 기록](archive/server_authoritative_economy_rollout_before_godot_20260924.md)에 보존했다. 남은 후속 작업은 이 문서 머리말(공개 환경 다중 기기 E2E·운영 백업 검증, 저장 v3 `CloudSaveData` 분리, 실제 결제 검증)을 따른다. 현재 Godot 클라이언트의 대응 검사는 [Godot 앱·저장 계약](../godot/app/README.md#검사)을 따른다.

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
