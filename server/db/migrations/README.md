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

`sqlc`는 이 디렉터리를 schema 입력으로 사용하며 tern의 down 구간은 제외하고
해석합니다. 로컬 적용은 저장소 루트에서 `docker compose run --rm migrate migrate`,
쿼리 코드 생성은 `server/`에서 `make sqlc-generate`로 실행합니다.
