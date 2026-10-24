# PostgreSQL 마이그레이션

이 디렉터리는 `tern`이 순서대로 적용하는 SQL 마이그레이션을 저장합니다.

- 파일명은 `001_description.sql`처럼 연속된 번호를 사용합니다.
- 배포되었거나 공유 환경에 적용된 마이그레이션은 수정하지 않고 새 파일을 추가합니다.
- 외부에 배포된 적 없는 작업 브랜치의 기준선은 첫 공개 전에 하나의 canonical
  스키마로 통합하며, 중간 형식용 호환 마이그레이션을 남기지 않습니다.
- 각 파일은 기본적으로 트랜잭션 안에서 실행됩니다.
- `---- create above / drop below ----` 위에는 적용 SQL, 아래에는 롤백 SQL을 둡니다.
- 데이터 손실 가능성이 있는 롤백이나 비가역 변경은 자동 실행하지 않습니다.

현재 애플리케이션 스키마는 다음 순서로 적용합니다.

1. `001_accounts_and_sessions.sql`: 계정, 외부 identity, session, refresh token
2. `002_online_saves.sql`: 저장 header, 영역별 JSONB, writer generation, claim/save 영수증
3. `003_weekly_reward_claims.sql`: 서버 판정 보상 수령 영수증
4. `004_legacy_save_transfers.sql`: 정식 배포 전 제거할 기존 로컬 진행 일회용 이전 보관소
5. `005_legacy_transfer_existing_save_backup.sql`: 임시 이전 시 교체되는 기존 account 저장 백업
6. `006_authoritative_economy.sql`: 서버 권위 지갑·모듈·경제 명령 원장·보상·진행 effect와 bootstrap 백업
7. `007_persistent_auth_sessions.sql`: 무만료 세션용 nullable refresh 만료와 암호화 갱신 응답 receipt
8. `008_account_nicknames.sql`: 계정 닉네임·4자리 태그, 조합 유일성과 입력 규칙 제약
9. `009_leaderboard_records.sql`: 종료 정산 기반 개인 최고 기록과 달성 시각
10. `010_leaderboard_save_progress.sql`: 진행 중 저장 revision 출처 추가, 기존 정산 출처 보존

운영 적용 상태와 다음 배포 순서는 [배포 인계](../../../docs/deployment_status.md)를 확인합니다.
010은 새 API보다 먼저 적용합니다. 저장 출처 기록이 있으면 down은 거부되며 기록을 삭제해 우회하지 않습니다.

007은 기존 유한 세션의 만료 값을 변경하지 않습니다. 신규 영속 로그인에서만
`sessions.refresh_expires_at = NULL`을 사용합니다. `refresh_receipts`의 최신 암호문은 다음 갱신 성공·세션 종료까지 보존합니다.
현재 API는 기존 유한 expires_at도 최신 유효 child의 복구 제한으로 사용하지 않으며,
신규 receipt는 infinity를 기록합니다. 추가 스키마 마이그레이션은 필요하지 않습니다.
token 소비 이력과 receipt 메타데이터는 재사용 판정을 위해 유지합니다.
영속 세션이 남아 있으면 down의 `NOT NULL` 복원이 실패하여 트랜잭션이 롤백됩니다.
이를 우회하려고 세션을 자동 삭제하거나 임의 만료 시각을 채우지 않습니다.

영속 로그인/갱신 활성화에는 마이그레이션과 별도로 고정 `AUTH_SESSION_RECEIPT_KEY`가
필요합니다. [운영 배포 선행 조건](../../../docs/self_hosted_api_deployment.md)을 따릅니다.
2026-09-05 검증은 격리 PostgreSQL에서 수행했으며 운영 DB에는 적용하지 않았습니다.

`sqlc`는 이 디렉터리를 schema 입력으로 사용하며 tern의 down 구간은 제외하고
해석합니다. 로컬 적용은 저장소 루트에서 `docker compose run --rm migrate migrate`,
쿼리 코드 생성은 `server/`에서 `make sqlc-generate`로 실행합니다.

## 계정 닉네임 적용

008은 기존 계정의 닉네임과 태그를 NULL로 추가하며 ID·진행·저장 데이터를 바꾸지 않습니다.
서버 버전을 올리면 미설정 계정은 `403 NICKNAME_REQUIRED`로 게임 API 접근이 차단됩니다.
따라서 먼저 008을 적용하고, 필수 설정 UI를 포함한 클라이언트와 새 서버를 조율해서 배포해야 합니다.
구버전 클라이언트에는 설정 화면이 없으므로 업데이트를 안내해야 하며, 서버 배포만으로
구버전 사용자가 계속 플레이할 수 있는 호환 동작을 제공하지 않습니다.
운영 배포·마이그레이션은 이번 코드 변경에 포함하지 않습니다.

프로필 조회·최초 설정은 Bearer 인증으로 본인 계정만 처리합니다.

- `GET /v1/account/profile` → `{ "accountId": "...", "nickname": null, "tag": null }`
- `PUT /v1/account/nickname` 요청 `{ "nickname": "룬마스터" }`
  → `{ "accountId": "...", "nickname": "룬마스터", "tag": "0382" }`
- 최소 실제 문자 2자, 한글 완성형은 2칸·ASCII 영문/숫자/밑줄은 1칸, 최대 16칸입니다.
  앞뒤 공백은 제거하며 그 외 문자나 내부 공백은 허용하지 않습니다.
- 닉네임은 대소문자를 구별합니다. DB의 `COLLATE "C"`와 조합 UNIQUE 제약이 이를 보장합니다.
- 모든 계정에 `0000`~`9999` 중 남은 태그를 암호학적 난수로 균등 선택합니다.
  같은 닉네임의 배정을 트랜잭션 잠금으로 직렬화하므로 충돌 없이 남은 번호를 배정합니다.
- 동일 닉네임 재시도는 기존 태그를 반환합니다. 다른 이름으로 변경은 `409 NICKNAME_ALREADY_SET`,
  태그 10,000개 소진은 `409 NICKNAME_TAGS_EXHAUSTED`, 입력 오류는 `400 INVALID_NICKNAME`입니다.
- 로그인·갱신·로그아웃과 프로필 API는 설정 전에도 사용할 수 있습니다.
  저장·경제(카탈로그 포함)·보상·기존 진행 가져오기 consume은 설정 후에만 허용합니다.
  게스트의 기존 진행 이전 토큰 생성 경로는 유지합니다.

008 down은 닉네임과 태그를 삭제하므로 설정된 계정이 있는 환경에서 자동 롤백하지 않습니다.

## 확장 스테이지

012는 기존 스테이지 ID·기록·달성 시각을 보존하면서 25맵 상한과 논리 진행 순위 비교를 추가한다. 신규 기록이 남은 상태에서 down은 실패하며 데이터를 삭제하지 않는다. 운영 적용은 별도 배포다.

013은 챕터3 후반의 고정 ID26–30을 허용하고 순위 산식·표현식 인덱스를 함께 갱신한다. 기존012는 수정하지 않는다. 신규 기록이 남은 상태에서 down은 실패하며 기록을 지우지 않는다.

새 스테이지 APK를 배포하기 전에013과 해당 서버 코드를 먼저 적용해야 한다. 클라이언트 호환 세대5는 새 스테이지 진행/활성 런/경로 식별자를 보존한다. 서버는 이 데이터가 있는 저장에만 세대5를 요구하므로 기존25맵 저장의 세대4 접근은 유지된다. 운영 최소 버전 설정·마이그레이션·APK 배포는 별도 승인 작업이다.

## 014 젬 재선택

`014_gem_rerolls.sql`은 API보다 먼저 적용한다. 초기 `gem_reset_tickets`는 0이며,
기존 저장의 임의 잔액을 가져오지 않는다. 기존 우편 지급 계약에 선택적인
`gemResetTickets`를 추가했으며 실제 운영 지급은 별도 승인 작업이다.

런별 1회 무료·이후 2회 권 소모 예산과 마지막 후보는 `economy_gem_rerolls`에
계정·런 ID로 보존한다. 일반 저장의 `activeRun` 교체·제거로 이 기록을 초기화하지
않는다. 첫 서버 재선택 또는 리셋권 지급 이후 `gem_reroll_enabled`가 유지되어
일반 저장·writer 획득·새 경제 명령에 호환 세대 7을 요구한다. 처리된 이전 세대
exact 영수증 복구는 보존한다. 지갑, 런 상태, 경제 revision과 영수증은 한
트랜잭션에서 확정한다. 이 마이그레이션은 원장과 예산 보존을 위해 forward-only다.

## 015–016 서버 젬과 도전 소유권

`015_server_gem_offers.sql`은 계정·도전·웨이브별 영속 offer(도전당 최대 7행)를 추가한다. `016_server_run_ownership.sql`은 서버 발급 도전 ID·상태·정확한 타입별 젬 소유 합계·리롤 사용 수·마지막 구매 offer를 `economy_runs`에 분리한다. 계정별 열린 도전은 하나이며 닫힌 도전은 삭제하거나 다시 열지 않는다. 후보/상태 JSON의 타입과 필수 값, header/payload 동일성은 016 제약으로 검사한다.

이전 기준은 016 시점의 인증된 canonical 저장 revision으로 고정한다. 기존 canonical 도전의 ID 누락/null/빈 문자열은 같은 transaction에서 서버 UUID로 채우고 그 header revision만 한 번 증가시킨다. 기존 canonical 리롤 사용량이 영속 예산보다 낮으면 사용량만 최댓값으로 보정하고 해당 revision도 증가시킨 뒤 pin한다. clientSavedAt, 기존 후보·영수증과 다른 진행 필드는 유지한다. `account_run_authorities.legacy_source_revision`이 없는 새 계정에는 기존 UUID/젬을 import하지 않는다. 모든 구세대 새 writer/save는 exact 영수증 확인 뒤 기준을 변경하기 전에 거절하며, 세대 9는 기존 canonical을 먼저 한 번 이전한다. 일반 bootstrap이나 과거 이전 링크가 임의의 젬을 legacy로 추가하는 우회가 되어서는 안 된다. 기존 처리 완료 exact 영수증은 먼저 복구한다.

세대 9의 20파편 구매·선택은 서버 명령이고, 장착·해제·판매의 보유 합계는 정확하게 보존한다. 파편 획득과 전투/클리어 보고는 여전히 클라이언트 신뢰 영역이다. 새 영수증에는 작은 불변 결과만 저장하며 현재 전체 save/economy는 조회로 복구한다. 같은 offer의 새-key 복구와 이미 정리된 close 복구는 읽기만 수행한다.

세대 7/8의 처리 완료 영수증, 기존 예산·리셋권 잔액과 canonical 진행/이미 지불한 pending 구매는 보존한다. 새 앱을 준비한 뒤 구 API 쓰기 차단 → transactional migration → 모든 API 교체 → 필수 앱 전환 순서를 조율하며, 실제 배포·운영 DB 실행은 별도 승인이다. 계정 생존 동안 tombstone·선택·예산·영수증을 보관하고 파괴적 down은 제공하지 않는다. 상세 계약은 [젬과 도전 수명주기](../../../docs/server_authoritative_economy_design.md#젬-보상과-도전-수명주기-호환-세대-9), 미검증/배포 조건은 [배포 인계](../../../docs/deployment_status.md)를 따른다.

016의 `valid_run_gem_offer`는 `valid_run_integer`·`valid_run_gem_totals`를 스키마 없이 호출한다. 그래서 DB16·17 백업은 검색 경로를 비우는 기본 `pg_restore`에서 `economy_runs` 데이터 복원이 실패한다. 018부터 이 함수에 `SET search_path = public`을 고정해 해소했다. 2026-10-24 일회용 PostgreSQL18에서 합성 데이터(계정2·경제 영수증1·대기 웨이브 offer1·구매 offer가 있는 열린 런1·닫힌 런1, 고정 ID·과거 시각)를 넣은 백업을 옵션 없는 기본 `pg_restore`로 복원했다. DB16·17은 `economy_runs` 복원이 실패했다. DB18·20은 34개 테이블의 전체 행 지문(ID·시각 포함)이 원본과 같았고, 복원본에서 검색 경로를 비운 채 유효 구매 offer는 허용되고 잘못된 웨이브·젬·revision은 거부됐다. 운영 백업으로는 아직 확인하지 않았다([남은 확인](../../../docs/implementation_checklist.md#p2--다음-서버-배포의-기본-백업-복원-확인)). DB18 이후 백업은 검색 경로 우회 없이 기본 복원하며, 016·017 시점 백업에만 기존 보호 복원 절차를 사용한다.
