# Rune Nexus 백엔드 및 온라인 저장 아키텍처

문서 상태: 채택된 구현 기준, 서버 기반 1단계 구현
마지막 갱신: 2026-08-13

## 목적

이 문서는 Rune Nexus의 계정 인증, 온라인 저장, PostgreSQL 저장 구조와 Go 서버의 책임 경계를 정의한다. 이후 백엔드 구현과 에이전트 작업은 이 문서를 기본 계약으로 사용한다.

현재 클라이언트에는 다음 기반이 구현되어 있다.

- Flutter + Flame 게임 클라이언트
- `GameSaveData` v2 통파일 직렬화
- `preferences`, `progression`, `turretModules`, `activeRun`의 최상위 영역 분리
- 로컬 파일 또는 Web Local Storage 기반 저장
- 라운드 체크포인트에서 호출되는 `OnlineSaveRepository` 확장 지점
- Docker Compose 기반 로컬 PostgreSQL 18

Go API 서버 기반과 마이그레이션 실행 환경은 구현되었다. 원격 저장, 사용자 인증과 애플리케이션 데이터베이스 스키마는 아직 구현되지 않았다.

## 채택 기술

| 영역 | 채택 기술 | 역할 |
| --- | --- | --- |
| 게임 클라이언트 | Flutter/Dart | Android·iOS 공용 게임 구현 |
| Android 플랫폼 인증 | Kotlin + Google Play Games Services v2 | PGS 플랫폼 인증 및 server auth code 획득 |
| API 서버 | Go 표준 `net/http` | 인증, 계정, 세션, 저장 API |
| PostgreSQL 연결 | `pgx/v5`, `pgxpool` | 연결 풀, 쿼리 실행, 트랜잭션 |
| 쿼리 코드 생성 | `sqlc` | SQL로부터 타입 안전한 Go 코드 생성 |
| 스키마 마이그레이션 | `tern` | 순차 SQL 마이그레이션과 트랜잭션 적용 |
| 데이터베이스 | PostgreSQL | 계정, 인증 수단, 세션, 원격 저장 데이터 |
| 개발·배포 단위 | Docker Compose | API 서버와 PostgreSQL 자가 운영 |

Firebase Authentication, Auth0, Supabase Auth처럼 사용량 증가 시 과금될 수 있는 관리형 인증 서비스는 사용하지 않는다. PGS·Google·Apple 같은 외부 인증 제공자가 발급한 증명을 Rune Nexus 서버가 직접 검증한다.

## 전체 구조

```text
┌───────────────────────────────────────────────┐
│ Flutter/Dart 게임 클라이언트                 │
│                                               │
│  로컬 GameSaveData v2 통파일                 │
│  인증 상태 및 온라인 저장 동기화             │
└───────────────────────┬───────────────────────┘
                        │ HTTPS + JSON
                        ▼
┌───────────────────────────────────────────────┐
│ Go API 서버                                   │
│                                               │
│  PGS 인증 검증          계정·세션 관리        │
│  저장 계약 검증         revision 충돌 검사    │
│  통파일 분해·조립       저장 트랜잭션 관리    │
└───────────────────────┬───────────────────────┘
                        │ pgx/pgxpool + sqlc
                        ▼
┌───────────────────────────────────────────────┐
│ PostgreSQL                                    │
│                                               │
│  accounts               save_headers          │
│  auth_identities        save_preferences      │
│  sessions               save_progression      │
│                         save_turret_modules    │
│                         save_active_runs       │
└───────────────────────────────────────────────┘
```

운영 환경에서도 Firebase 같은 별도 인증 서버를 띄우지 않는다. Rune Nexus API 서버와 PostgreSQL만 직접 운영하며, Google 서버는 PGS 증명 검증과 OAuth 코드 교환에만 사용한다.

## 책임 경계

### Flutter 클라이언트

- 게임 상태 생성과 현재 `GameSaveData` 직렬화
- 로컬 통파일 저장과 복구
- PGS 로그인 시작
- API access token을 포함한 원격 요청
- 온라인 저장 실패 시 게임 진행을 유지하고 나중에 재시도
- 원격 저장을 적용하기 전 기존 로컬 저장 백업

클라이언트는 인증 결과나 서버 revision을 임의로 생성하지 않는다. 클라이언트 시각과 `savedAtMillis`는 신뢰할 수 없는 참고값으로 취급한다.

### Go API 서버

- PGS server auth code 교환과 Player ID 검증
- Rune Nexus 내부 계정 생성·조회
- opaque access/refresh token 발급과 폐기
- 인증된 계정만 자신의 저장 데이터에 접근하도록 제한
- 저장 버전, 구조, 크기와 revision 검사
- 통파일 저장 요청을 영역별 PostgreSQL 데이터로 분리
- 영역별 데이터를 하나의 통파일 응답으로 조립
- 모든 저장 영역의 원자적 트랜잭션 보장

### PostgreSQL

- Rune Nexus 내부 계정 ID 유지
- 한 내부 계정에 여러 외부 인증 수단 연결
- 세션 토큰 해시와 만료·폐기 상태 저장
- 영역별 원격 저장과 현재 revision 저장

PostgreSQL은 Flutter 클라이언트에 직접 노출하지 않는다.

## 계정 및 인증 모델

### 내부 계정 우선 원칙

게임 데이터의 소유자는 PGS Player ID가 아니라 Rune Nexus 내부 `accounts.id`다. 외부 인증 수단은 내부 계정을 찾기 위한 연결 정보로만 사용한다.

```text
accounts.id
  ├─ auth_identities(provider=play_games, subject=<PGS Player ID>)
  ├─ auth_identities(provider=google, subject=<Google subject>)   # 추후
  └─ auth_identities(provider=apple, subject=<Apple subject>)    # 추후
```

동일 이메일이라는 이유만으로 계정을 자동 병합하지 않는다. 다른 인증 수단 연결은 기존 Rune Nexus 계정으로 인증한 상태에서 사용자가 명시적으로 승인하는 흐름으로만 제공한다.

### PGS 1차 인증 흐름

```text
1. Android 앱이 PGS v2 로그인을 수행한다.
2. 앱이 게임 서버용 Web OAuth Client ID로 server auth code를 요청한다.
3. 앱이 server auth code를 POST /v1/auth/play-games로 전달한다.
4. Go 서버가 Google OAuth 서버에서 코드를 교환한다.
5. Go 서버가 PGS API를 호출해 Player ID를 검증한다.
6. auth_identities에서 play_games + Player ID를 조회한다.
7. 연결 계정이 없으면 accounts와 auth_identities를 생성한다.
8. 서버가 opaque access token과 refresh token을 발급한다.
```

server auth code와 OAuth client secret은 로그에 남기지 않는다. OAuth client secret은 서버에만 저장하고 앱 패키지에 포함하지 않는다.

### 자체 세션

- access token과 refresh token은 충분한 엔트로피를 가진 무작위 opaque token을 사용한다.
- 데이터베이스에는 토큰 원문이 아니라 SHA-256 해시만 저장한다.
- access token은 짧은 만료 시간을 사용한다.
- refresh token은 갱신할 때마다 회전한다.
- 폐기되었거나 이미 교체된 refresh token이 다시 사용되면 관련 세션을 폐기한다.
- 로그아웃은 해당 세션을 폐기한다.
- 여러 기기는 서로 다른 세션을 가질 수 있다.

정확한 만료 시간은 구현 시 설정값으로 확정하되 코드에 분산해서 하드코딩하지 않는다.

## 저장 계약

### 로컬 저장 형식 유지

클라이언트 로컬 저장은 현재 `GameSaveData` v2 통파일을 유지한다.

```json
{
  "version": 2,
  "savedAtMillis": 0,
  "preferences": {},
  "progression": {},
  "turretModules": {},
  "activeRun": null
}
```

로컬 파일명과 Web Local Storage 키에는 기존 호환성을 위한 `v1` 문자열이 남아 있다. payload 버전이 v2가 되었다는 이유로 이를 자동 변경하지 않는다. 이름을 바꾸면 기존 사용자의 저장을 찾지 못할 수 있다.

### API 경계에서는 통파일 사용

클라이언트는 영역마다 별도 요청하지 않는다. 저장 API는 전체 `GameSaveData`를 하나의 요청으로 받는다.

```json
{
  "expectedRevision": 12,
  "data": {
    "version": 2,
    "savedAtMillis": 1780000000000,
    "preferences": {},
    "progression": {},
    "turretModules": {},
    "activeRun": null
  }
}
```

이 구조는 클라이언트 저장 시점의 일관성을 유지하고 요청 중 일부 영역만 반영되는 문제를 막는다.

### 서버 저장 영역

서버는 요청을 다음처럼 분리한다.

| 테이블 | 저장 내용 |
| --- | --- |
| `save_headers` | schema version, revision, client saved time, server updated time |
| `save_preferences` | `preferences` JSONB |
| `save_progression` | `progression` JSONB |
| `save_turret_modules` | `turretModules` JSONB |
| `save_active_runs` | `activeRun` JSONB, 진행 중 런이 없으면 행 제거 |

포탑 모듈은 런 도중 생성되는 상태가 아니며 독립적인 장기 성장 영역이므로 `progression`과 별도 테이블로 유지한다.

### 저장 트랜잭션

저장은 다음 순서를 하나의 PostgreSQL 트랜잭션에서 처리한다.

```text
1. account_id의 save_headers 행을 잠근다.
2. expectedRevision과 현재 revision이 같은지 확인한다.
3. preferences를 upsert한다.
4. progression을 upsert한다.
5. turretModules를 upsert한다.
6. activeRun을 upsert하거나 null이면 삭제한다.
7. save_headers revision을 1 증가시킨다.
8. 트랜잭션을 commit한다.
```

중간 단계가 하나라도 실패하면 전체를 rollback한다. 서버 응답에는 새 revision과 서버 갱신 시각을 포함한다.

### 동시 저장과 충돌

- 서버 revision이 원격 저장의 순서를 결정한다.
- `expectedRevision`이 다르면 `409 Conflict`를 반환한다.
- 클라이언트는 충돌 시 자신의 데이터를 자동으로 강제 덮어쓰지 않는다.
- 최신 원격 저장을 다시 조회하고 로컬 백업을 유지한다.
- `savedAtMillis`가 더 크다는 이유만으로 서버 데이터를 덮어쓰지 않는다.

필요하면 요청 ID를 사용해 네트워크 재시도에 대한 멱등성을 추가한다. 동일 요청의 재전송이 revision을 중복 증가시키지 않아야 한다.

### 최초 로그인과 오프라인 정책

- 로그인 전에는 로컬 저장만 사용한다.
- 최초 로그인 시 원격 저장이 없으면 현재 로컬 저장을 revision 0 기준으로 업로드한다.
- 원격 저장이 이미 있으면 원격 저장을 우선하되, 적용 전에 현재 로컬 저장을 백업한다.
- 플레이 중에는 로컬 저장을 먼저 완료한 뒤 온라인 체크포인트를 시도한다.
- 네트워크 오류와 서버 오류는 게임 진행을 막지 않는다.
- 인증 오류는 무한 재시도하지 않고 토큰 갱신 또는 재로그인 상태로 전환한다.

## 게임 데이터 신뢰 수준

1차 온라인 저장은 백업과 기기 간 동기화가 목적이며 완전한 치트 방지 서버는 아니다. 전투 결과와 대부분의 진행 값은 여전히 클라이언트에서 계산된다.

다음 원칙은 처음부터 적용한다.

- payload 크기와 JSON 중첩 수준 제한
- 지원하는 저장 버전과 필수 최상위 영역 검사
- 음수 재화, 비정상적으로 큰 수치 등 명백한 범위 오류 거부
- `paidDiamonds`는 일반 저장 업로드로 증가하거나 변경할 수 없음
- 향후 유료 재화가 도입되면 구매 검증과 잔액 변경을 별도 서버 명령으로 처리
- 클라이언트가 전송한 계정 ID를 신뢰하지 않고 인증 토큰의 계정을 사용

향후 서버 권위형 경제나 치트 방지가 필요하면 저장 업로드가 아니라 보상 지급·소비 명령 단위 API를 추가한다. 이 확장은 현재 백업 API와 별도 책임으로 설계한다.

## 초기 API

| Method | Path | 역할 |
| --- | --- | --- |
| `POST` | `/v1/auth/play-games` | PGS 인증 및 Rune Nexus 세션 발급 |
| `POST` | `/v1/auth/refresh` | refresh token 회전 및 새 토큰 발급 |
| `POST` | `/v1/auth/logout` | 현재 세션 폐기 |
| `GET` | `/v1/save` | 영역별 DB 데이터를 통파일로 조립해 조회 |
| `PUT` | `/v1/save` | 전체 저장 데이터를 revision 조건으로 저장 |
| `GET` | `/health/live` | API 프로세스 생존 확인 |
| `GET` | `/health/ready` | PostgreSQL 포함 요청 처리 준비 상태 확인 |

API 오류 응답은 공통 `code`, `message`, `requestId` 형식을 사용한다. 사용자에게 보여 줄 번역 문구는 서버 메시지를 그대로 노출하지 않고 클라이언트의 오류 코드 매핑으로 결정한다.

계정 삭제 API, Google·Apple 인증 연결 API와 세션 목록 관리는 1차 구현 후 출시 준비 단계에서 추가한다.

## 데이터베이스 초안

### 계정 테이블

```text
accounts
- id UUID primary key
- status
- created_at
- updated_at

auth_identities
- id UUID primary key
- account_id UUID references accounts
- provider
- subject
- created_at
- unique(provider, subject)

sessions
- id UUID primary key
- account_id UUID references accounts
- access_token_hash
- access_expires_at
- refresh_token_hash
- refresh_expires_at
- rotated_at
- revoked_at
- created_at
- last_used_at
```

### 저장 테이블

```text
save_headers
- account_id UUID primary key references accounts
- schema_version integer
- revision bigint
- client_saved_at timestamptz
- updated_at timestamptz

save_preferences
- account_id UUID primary key references accounts
- payload jsonb

save_progression
- account_id UUID primary key references accounts
- payload jsonb

save_turret_modules
- account_id UUID primary key references accounts
- payload jsonb

save_active_runs
- account_id UUID primary key references accounts
- payload jsonb
```

실제 마이그레이션에서는 `NOT NULL`, 외래 키 삭제 정책, 길이 제한과 검사 제약을 명시한다. 스키마 이름과 컬럼은 최초 마이그레이션 작성 시 최종 검토한다.

## Go 서버 디렉터리 기준

```text
server/
├─ cmd/
│  └─ api/
│     └─ main.go
├─ internal/
│  ├─ account/
│  ├─ auth/
│  │  └─ playgames/
│  ├─ config/
│  ├─ dbgen/              # sqlc 생성 코드, 직접 수정 금지
│  ├─ httpapi/
│  │  ├─ middleware/
│  │  └─ v1/
│  ├─ save/
│  └─ session/
├─ db/
│  ├─ migrations/
│  └─ queries/
├─ docker/
│  └─ migrate-entrypoint.sh
├─ Dockerfile
├─ Dockerfile.migrate
├─ Makefile
├─ go.mod
├─ go.sum
└─ sqlc.yaml
```

패키지는 계층 수를 늘리기 위한 추상화가 아니라 실제 책임을 기준으로 나눈다. 단순 전달만 하는 repository/service wrapper는 만들지 않는다. 트랜잭션 경계는 저장 유스케이스에서 명시적으로 관리한다.

## SQL과 생성 코드 규칙

- 스키마 변경은 새 SQL 마이그레이션 파일로만 수행한다.
- 적용된 마이그레이션 파일을 뒤늦게 수정하지 않는다.
- 데이터 삭제, 컬럼 제거, 비가역 타입 변경은 사용자 확인 후 진행한다.
- 실행 쿼리는 `server/db/queries`에 작성한다.
- `sqlc`가 생성한 `server/internal/dbgen` 파일은 직접 수정하지 않는다.
- 생성 코드는 저장소에 커밋한다.
- 쿼리 또는 스키마 변경 후 `sqlc generate`를 실행한다.
- CI에서는 재생성 후 Git 차이가 없는지 확인한다.
- `sqlc vet`, `go vet ./...`, `go test ./...`를 통과해야 한다.
- sqlc Cloud나 관리형 분석 데이터베이스는 사용하지 않는다.

PostgreSQL 드라이버는 `pgx/v5`를 직접 사용한다. GORM 같은 ORM을 추가하지 않는다. ORM 도입이 필요해질 경우 SQL 가시성과 트랜잭션 제어보다 실질적인 이득이 있는지 먼저 검토한다.

## 설정과 비밀값

서버 설정에는 최소한 다음 값이 필요하다.

```text
DATABASE_URL
PGS_WEB_CLIENT_ID
PGS_WEB_CLIENT_SECRET
HTTP_ADDRESS
ACCESS_TOKEN_TTL
REFRESH_TOKEN_TTL
```

- 실제 비밀값은 Git에 커밋하지 않는다.
- 로컬에서는 `.secrets/`의 파일 또는 로컬 환경 변수로 주입한다.
- Docker Compose의 secret 또는 읽기 전용 파일 마운트를 우선한다.
- 설정 시작 시 필수값과 범위를 검증하고 누락되면 즉시 종료한다.
- 운영 로그에 토큰, auth code, OAuth secret, 전체 저장 payload를 남기지 않는다.

## Docker 및 네트워크

개발 환경의 기본 서비스는 다음과 같다.

```text
compose.yaml
├─ db          PostgreSQL
├─ migrate     SQL 마이그레이션 적용 작업
└─ api         Go API 서버
```

- API 컨테이너는 Compose 내부에서 `db:5432`로 PostgreSQL에 접속한다.
- 호스트에 노출되는 PostgreSQL 포트는 개발용 `127.0.0.1`로 제한한다.
- 운영에서는 PostgreSQL 포트를 외부에 공개하지 않는다.
- 외부 클라이언트 요청은 HTTPS로만 허용한다.
- 컨테이너 health check와 종료 유예 시간을 설정한다.
- named volume 데이터는 별도의 `pg_dump` 백업과 복원 시험을 마련한다.

구체적인 로컬 PostgreSQL 실행법은 `docs/local_postgresql_setup.md`를 따른다.

## 검증 전략

### Go 단위 테스트

- 인증 토큰 생성, 해시, 만료와 회전
- PGS 응답 파싱과 오류 변환
- 저장 버전 및 payload 검증
- API 오류 코드 매핑

### PostgreSQL 통합 테스트

- 최초 계정 및 identity 생성
- 같은 PGS Player ID의 중복 계정 방지
- 저장 영역 전체 upsert
- 중간 오류 시 전체 rollback
- 잘못된 expected revision의 `409 Conflict`
- 동시에 저장한 요청 중 하나만 성공
- `activeRun: null`일 때 행 제거
- refresh token 회전 후 이전 토큰 재사용 거부

### Flutter 테스트

- 기존 v1 저장을 v2로 이관하는 호환성 유지
- 통파일 API 직렬화 왕복
- 원격 저장이 없는 최초 로그인 업로드
- 원격 저장 적용 전 로컬 백업
- 온라인 저장 실패가 게임 진행을 막지 않음
- 인증 만료 후 refresh와 재시도
- revision 충돌 시 자동 덮어쓰기 방지

### 실제 통합 검증

- 디버그 서명 SHA-1로 등록한 PGS 테스터 로그인
- PGS server auth code를 Go 서버에서 교환
- 앱 재설치 후 원격 저장 복원
- 두 기기에서의 revision 충돌 처리
- PostgreSQL 백업 파일에서 복원

## 구현 순서

### 1단계: 서버 기반

- [x] Go 개발 버전과 도구 버전 고정
- [x] `server/` 모듈과 HTTP 서버 생성
- [x] Dockerfile 및 Compose API 서비스 추가
- [x] PostgreSQL 연결과 health check 구현
- [x] SQL 마이그레이션 도구로 `tern` 확정 및 초기화

### 2단계: 데이터베이스

- 계정, identity, session 스키마 추가
- 영역별 저장 스키마 추가
- sqlc 쿼리와 생성 코드 추가
- 실제 PostgreSQL 통합 테스트 추가

### 3단계: PGS 인증

- Android Application ID를 `com.runenexus.game`으로 변경
- 출시 서명과 PGS/OAuth 인증 정보 구성
- Kotlin PGS v2 연동과 Flutter MethodChannel 추가
- Go 인증 코드 교환, 계정 생성, 세션 API 구현

### 4단계: 온라인 저장

- 저장 조회와 전체 저장 API 구현
- 트랜잭션, revision, 멱등성 처리
- Flutter 온라인 저장 구현
- 최초 로그인, 오프라인, 충돌 정책 적용

### 5단계: 출시 안전장치

- HTTPS, 요청 제한, 보안 헤더와 로그 정리
- 계정 삭제 및 원격 데이터 삭제
- DB 백업과 복원 자동화
- 개인정보 처리방침과 스토어 데이터 공개 항목 정리

## 1차 범위에서 제외

- Firebase 또는 기타 관리형 인증 서비스
- GORM 등 ORM
- Redis, 메시지 큐, Kubernetes
- 관리자 페이지와 분석 플랫폼
- Google·Apple 로그인 실제 구현
- 이메일·비밀번호 로그인
- 서버 권위형 전체 전투 시뮬레이션
- 클라이언트 저장을 완전히 신뢰할 수 있게 만드는 치트 방지
- 저장 영역별 개별 클라이언트 API

이 항목들은 실제 요구가 생기기 전까지 추가하지 않는다.

## 현재 구현 상태

- 로컬 환경에 Docker는 설치되어 있다.
- Go 1.26.5, sqlc 1.31.1, tern 2.4.1을 프로젝트 도구 버전으로 고정했다.
- 호스트에 Go, sqlc와 tern을 설치하지 않아도 Docker 기반으로 빌드·검증할 수 있다.
- Android Application ID는 아직 `com.example.rune_nexus`다.
- release 빌드는 아직 debug signing 설정을 사용한다.
- PostgreSQL, 마이그레이션, API 컨테이너와 실행 문서가 준비되어 있다.
- `/health/live`와 PostgreSQL을 확인하는 `/health/ready`가 구현되어 있다.
- 계정과 저장 데이터의 최초 SQL 마이그레이션 및 sqlc 설정은 2단계 범위다.
