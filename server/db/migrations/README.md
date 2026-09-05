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

007은 기존 유한 세션의 만료 값을 변경하지 않습니다. 신규 영속 로그인에서만
`sessions.refresh_expires_at = NULL`을 사용합니다. `refresh_receipts`의 암호문은 10분 복구
기간 뒤 정리하지만 token 소비 이력과 receipt 메타데이터는 재사용 판정을 위해 유지합니다.
영속 세션이 남아 있으면 down의 `NOT NULL` 복원이 실패하여 트랜잭션이 롤백됩니다.
이를 우회하려고 세션을 자동 삭제하거나 임의 만료 시각을 채우지 않습니다.

영속 로그인/갱신 활성화에는 마이그레이션과 별도로 고정 `AUTH_SESSION_RECEIPT_KEY`가
필요합니다. [운영 배포 선행 조건](../../../docs/self_hosted_api_deployment.md)을 따릅니다.
2026-09-05 검증은 격리 PostgreSQL에서 수행했으며 운영 DB에는 적용하지 않았습니다.

`sqlc`는 이 디렉터리를 schema 입력으로 사용하며 tern의 down 구간은 제외하고
해석합니다. 로컬 적용은 저장소 루트에서 `docker compose run --rm migrate migrate`,
쿼리 코드 생성은 `server/`에서 `make sqlc-generate`로 실행합니다.
