# Rune Nexus 백엔드·인증·온라인 저장 최종 아키텍처

문서 상태: 채택된 구현 기준
마지막 갱신: 2026-08-19

## 목적

이 문서는 Rune Nexus의 계정 인증, 로컬 우선 저장, 비동기 온라인 저장,
PostgreSQL 스키마, API 계약과 향후 중요 재화 보호 경계를 정의한다. 이후
백엔드와 클라이언트 구현은 이 문서를 기본 계약으로 사용한다.

현재 구현된 기반은 다음과 같다.

- Flutter + Flame 게임 클라이언트
- `GameSaveData` v2 통파일 직렬화
- `preferences`, `progression`, `turretModules`, `activeRun` 최상위 영역 분리
- 로컬 파일 또는 Web Local Storage 기반 저장
- 라운드 체크포인트의 `OnlineSaveRepository` 확장 지점
- Docker Compose 기반 PostgreSQL 18
- Go `net/http` API 서버 기반
- `pgx/v5` 연결 풀과 `/health/live`, `/health/ready`
- `tern` 마이그레이션 실행 환경
- 계정·외부 identity·세션·refresh token PostgreSQL 스키마
- Google ID token 검증과 `POST /v1/auth/google` 세션 발급
- refresh token 단일 사용 회전·재사용 감지와 로그아웃
- access Bearer 인증 미들웨어와 DB 기반 account/session 결정
- Flutter 메모리 세션 자동 갱신·single-flight·401 1회 재시도

PGS 인증, 실제 온라인 저장 API와 클라이언트 동기화기는 아직 구현되지 않았다.
Google 웹 로그인은 Google Identity Services 버튼에서
`POST /v1/auth/google`로 이어지는 경로까지 구현되었으며 배포 환경에 OAuth Client와
API 주소를 설정하면 활성화된다.

## 최종 결정 요약

1. 게임 플레이는 로컬 우선이며 전투 세부 동작은 서버를 거치지 않는다.
2. 로컬 저장은 `GameSaveData` 통파일을 유지한다.
3. 온라인 저장은 전체 스냅샷 하나를 받고 서버 내부에서만 영역별로 분리한다.
4. 로컬 저장 성공은 온라인 저장 성공에 의존하지 않는다.
5. 스냅샷 저장은 한 계정당 하나만 전송하고, 대기 데이터는 최신 하나로 합친다.
6. timeout 재시도는 같은 idempotency key와 같은 요청 본문을 사용한다.
7. 서버 revision으로 여러 기기의 동시 수정을 감지하며 자동 덮어쓰지 않는다.
8. 일반 진행 값은 1차 범위에서 치트 방지용 서버 권위 데이터가 아니다.
9. 실제 결제, 다이아, 유료 상품과 중요한 일회성 보상만 필요 시 서버 권위로 승격한다.
10. 서버 권위 행동은 스냅샷 저장과 분리된 명령 API와 원장으로 처리한다.
11. 일반 라운드 완료는 로컬 체크포인트일 뿐 서버 응답을 기다리는 행동이 아니다.
12. 외부 API는 HTTPS + JSON을 사용하며 WebSocket은 도입하지 않는다.
13. Firebase, Auth0, Supabase Auth 등 관리형 인증 서비스는 사용하지 않는다.
14. 치트 대응은 불가능 상태 검증과 최소 통계 수집부터 시작하고 자동 제재는 보류한다.

## 채택 기술

| 영역 | 채택 기술 | 역할 |
| --- | --- | --- |
| 게임 클라이언트 | Flutter/Dart | Android·iOS 공용 게임과 로컬 저장 |
| Android 플랫폼 인증 | Kotlin + PGS v2 | server auth code 획득 |
| API 서버 | Go 표준 `net/http` | 인증, 계정, 세션, 저장 API |
| Google 토큰 검증 | `google.golang.org/api/idtoken` | 서명, audience, 만료 검증 |
| PostgreSQL 연결 | `pgx/v5`, `pgxpool` | 연결 풀, SQL 실행, 트랜잭션 |
| 쿼리 코드 생성 | `sqlc` | SQL 기반 타입 안전 Go 코드 생성 |
| 마이그레이션 | `tern` | 순차 SQL 마이그레이션 |
| 데이터베이스 | PostgreSQL 18 | 계정, 세션, 온라인 저장 |
| 개발·배포 | Docker Compose | API와 PostgreSQL 자체 운영 |

PostgreSQL 드라이버는 `pgx/v5`를 직접 사용한다. GORM 같은 ORM, Redis,
메시지 큐와 Kubernetes는 실제 요구가 생기기 전까지 추가하지 않는다.

## 신뢰 경계

### 데이터 분류

| 분류 | 예시 | 기준 |
| --- | --- | --- |
| 로컬 권위 | 전투, 적 위치, 포탑 공격, 현재 라운드 | 서버 요청 없이 즉시 처리 |
| 동기화 스냅샷 | 설정, 일반 진행, 모듈, 활성 런 | 로컬 저장 후 비동기 업로드 |
| 서버 권위 확장 | 실제 결제, 다이아, 유료 상품 | 서버 명령과 원장으로만 변경 |
| 위험 관찰 | 비정상 성장 속도, 반복 충돌 | 기록과 통계, 단일 신호 자동 제재 금지 |

1차 온라인 저장은 백업과 기기 간 동기화가 목적이다. 클라이언트가 보낸
전투 결과와 일반 진행 값은 구조적 유효성은 검사하지만 정당한 플레이 결과라고
증명하지는 않는다.

한 값에는 하나의 쓰기 권위만 둔다. 다이아를 서버 권위로 전환한 이후에는
클라이언트 스냅샷의 다이아 값을 잔액 원본으로 사용하지 않는다. 서버 잔액을
클라이언트에 내려 주고 클라이언트는 이를 로컬 캐시로만 저장한다.

### Flutter 클라이언트 책임

- 게임 상태 생성과 `GameSaveData` 직렬화
- 로컬 저장과 복구
- PGS 로그인 시작
- access token을 포함한 HTTPS 요청
- 로컬 저장 완료 후 백그라운드 온라인 동기화 예약
- 정확한 in-flight 요청과 최신 pending 스냅샷 보존
- 온라인 오류 중에도 일반 플레이 유지
- 원격 저장 적용 전 로컬 백업
- 충돌 시 양쪽 데이터를 보존하고 사용자 선택 요청

클라이언트가 전송한 account ID, 시각, revision과 중요한 재화 결과값을
그 자체로 신뢰하지 않는다.

### Go API 서버 책임

- PGS server auth code 교환과 Player ID 검증
- 내부 계정 생성·조회
- opaque access/refresh token 발급, 회전, 폐기
- 인증 토큰으로 account ID 결정
- 요청 크기, 저장 버전, 최상위 구조와 명백한 범위 오류 검사
- idempotency key 중복 처리
- expected revision 충돌 검사
- 통파일을 영역별 PostgreSQL 행으로 분리
- 모든 저장 영역의 원자적 트랜잭션
- 영역별 행을 통파일 응답으로 조립
- 향후 중요 경제 행동의 가격·중복·잔액 검사

### PostgreSQL 책임

- 내부 계정과 여러 외부 인증 수단 연결
- 세션과 refresh token 회전 이력
- 원격 저장 revision과 영역별 JSONB
- 저장 요청 처리 영수증
- 향후 중요 재화 원장과 구매 검증 결과

PostgreSQL은 클라이언트에 직접 노출하지 않는다.

## 전체 흐름

### 일반 플레이와 저장

```text
게임 행동
  -> 메모리 상태 변경
  -> 로컬 통파일 저장
  -> save outbox의 최신 pending 갱신
  -> 백그라운드 PUT /v1/save
```

로컬 저장은 온라인 요청보다 먼저 끝나야 한다. 온라인 요청이 timeout 또는
서버 오류로 실패해도 게임 진행과 다음 로컬 저장을 막지 않는다.

### 중요 행동 확장

```text
결제·다이아 소비·중요 보상 수령
  -> 고유 idempotency key로 서버 명령
  -> 서버가 조건 검사와 원장 변경을 한 트랜잭션으로 처리
  -> authoritative 결과 반환
  -> 클라이언트 캐시 반영
  -> 로컬 저장과 일반 스냅샷 동기화
```

서버 명령 성공 시 중요한 상태는 이미 DB에 반영된다. 뒤이은 전체 스냅샷
업로드가 실패해도 중요한 재화는 유실되지 않으며, 다음 서버 응답에서 다시
클라이언트 캐시를 교정한다.

## 로컬 저장 계약과 마이그레이션

### 저장 형식

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

통파일은 로컬 시점의 일관성을 위한 경계다. 서버 테이블이 나뉘더라도
클라이언트는 영역별 파일이나 영역별 저장 요청을 만들지 않는다.

### 영속 저장 위치

현재 IO 구현의 `Directory.systemTemp`는 OS 정리 대상이므로 로컬 우선 저장의
정식 위치로 사용할 수 없다. Android와 iOS는 앱 전용 application support
디렉터리를 사용한다. `path_provider` 같은 새 의존성이 필요하면 구현 전에
사용자 확인을 받는다.

저장 슬롯은 guest와 인증된 account별로 분리한다. 로그인 응답의 내부 account
ID는 로컬 namespace 용도로만 사용하며 API의 권한 판단에는 사용하지 않는다.
계정 전환 시 다른 계정 또는 guest 슬롯을 자동 업로드하지 않는다.

논리 namespace는 다음처럼 고정한다. account ID는 서버가 발급한 UUID를 정규화하고
검증한 뒤에만 키 또는 경로 조각으로 사용한다.

```text
Web guest:
  rune_nexus:save:v2:guest:primary
  rune_nexus:save:v2:guest:backup
  rune_nexus:sync:v1:guest
  rune_nexus:outbox:v1:guest

Web account:
  rune_nexus:save:v2:account:<account-uuid>:primary
  rune_nexus:save:v2:account:<account-uuid>:backup
  rune_nexus:sync:v1:account:<account-uuid>
  rune_nexus:outbox:v1:account:<account-uuid>

IO guest:
  <application-support>/saves/guest/save_v2.json
  <application-support>/saves/guest/save_v2.backup.json
  <application-support>/saves/guest/sync_v1.json
  <application-support>/saves/guest/outbox_v1.json

IO account:
  <application-support>/saves/accounts/<account-uuid>/save_v2.json
  <application-support>/saves/accounts/<account-uuid>/save_v2.backup.json
  <application-support>/saves/accounts/<account-uuid>/sync_v1.json
  <application-support>/saves/accounts/<account-uuid>/outbox_v1.json
```

### v1 보존형 마이그레이션

현재 v2 구현은 기존 `rune_nexus_save_v1` 키와 파일을 같은 위치에서 덮어쓸
수 있어 구버전 롤백 안전성이 부족하다. `main` 배포 전 다음 방식으로 보강한다.

- Web 신규 기본/backup 키: 위 namespace의 guest 슬롯
- Web legacy 키: `rune_nexus_save_v1`
- IO 신규 파일/backup: 위 namespace의 application support guest 슬롯
- IO legacy 후보: 기존 system temp의 `rune_nexus_save_v1.json`

로드 순서는 다음과 같다.

1. canonical 또는 허용된 transitional v2 기본 저장을 검사한다.
2. 기본 v2가 손상되었으면 정상 v2 backup을 검사한다.
3. 둘 다 없거나 손상되었으면 legacy v1을 읽는다.
4. v1을 메모리에서 v2로 변환하고 검증한다.
5. 신규 영속 v2 guest 슬롯에 저장한다.
6. legacy v1은 읽기 전용 백업으로 남긴다.

canonical v2는 `preferences`, `progression`, `turretModules`, `activeRun` 최상위
영역이 모두 있어야 한다. transitional v2는 기존 모듈 필드가 `progression`에
있고 `turretModules`만 빠진 이미 배포된 중간 형식만 허용한다. `{"version":2}`
처럼 대부분의 영역이 없는 데이터는 기본값으로 정상 복구하지 않고 손상으로
분류한다. 파싱 전에 별도 envelope validator가 이 구분을 수행한다.

legacy 저장 삭제는 별도 출시 이후 실제 마이그레이션 성공률을 확인한 뒤
명시적으로 결정한다. payload version과 저장 위치 version은 서로 다른 개념이다.

IO 저장은 임시 파일 쓰기와 flush 후 교체하는 방식으로 원자성을 확보하고,
교체 실패 시 직전 정상 파일을 보존한다. Web은 기존 정상 값을 backup 키에
복사한 뒤 신규 값을 기록한다. 로드 실패를 빈 새 게임으로 자동 확정하고
기존 파일을 덮어쓰지 않는다.

구버전으로 롤백하면 legacy v1의 업그레이드 직전 상태를 읽을 수 있다. 구버전
실행 중 새로 진행한 데이터와 이미 존재하는 v2를 자동 양방향 병합하지 않으므로,
운영 장애는 가능하면 수정 버전을 재배포하는 roll-forward로 해결한다.

## 계정과 인증

### 내부 계정 우선

게임 데이터 소유자는 외부 Player ID가 아니라 `accounts.id`다.

```text
accounts.id
  |- auth_identities(provider=play_games, subject=<PGS Player ID>)
  |- auth_identities(provider=google, subject=<Google subject>)
  `- auth_identities(provider=apple, subject=<Apple subject>)    # 추후
```

동일 이메일만으로 계정을 자동 병합하지 않는다. 다른 인증 수단 연결은 기존
Rune Nexus 계정으로 인증한 상태에서 사용자가 명시적으로 승인해야 한다.

### PGS 인증 흐름

```text
1. Android 앱이 PGS v2 로그인을 수행한다.
2. 앱이 Web OAuth Client ID로 server auth code를 요청한다.
3. 앱이 auth code를 POST /v1/auth/play-games로 전달한다.
4. Go 서버가 Google OAuth 서버에서 코드를 교환한다.
5. Go 서버가 PGS Player ID를 검증한다.
6. play_games + Player ID identity를 조회한다.
7. 없으면 account와 identity를 같은 트랜잭션으로 생성한다.
8. opaque access token과 refresh token을 발급한다.
```

auth code, OAuth client secret과 외부 access token은 로그나 앱 저장에 남기지
않는다. OAuth client secret은 서버 secret으로만 주입한다.

### Google 웹 인증과 계정 연결

GitHub Pages에서는 Android 전용 PGS 대신 Google Identity Services로 로그인한다.
웹과 Android가 같은 온라인 저장을 사용하도록 외부 identity는 같은 내부 account에
연결한다.

```text
1. Web이 Google Identity Services에서 ID token을 받는다.
2. Web이 ID token을 POST /v1/auth/google로 전달한다.
3. Go 서버가 서명, issuer, audience와 만료를 검증한다.
4. 검증된 Google subject로 google identity를 조회한다.
5. 기존 identity가 있으면 해당 account session을 발급한다.
6. 없으면 account와 google identity를 같은 트랜잭션으로 생성한다.
```

이미 인증된 PGS account에 Google identity를 추가할 때는 별도 연결 API에서 사용자
승인을 다시 확인한다. Google identity가 이미 다른 account에 연결되어 있으면
이메일을 기준으로 병합하거나 identity를 자동 이전하지 않고 충돌을 반환한다.

### 자체 세션

- access/refresh token은 충분한 엔트로피의 무작위 opaque token이다.
- DB에는 원문이 아니라 SHA-256 해시만 저장한다.
- access token은 짧게, refresh session은 더 길게 만료한다.
- refresh token은 사용할 때마다 회전한다.
- 이미 소비된 refresh token이 다시 오면 해당 세션을 폐기한다.
- 여러 기기는 서로 다른 session을 가진다.
- timeout·연결 단절로 refresh 결과가 모호하면 같은 소비된 token을 반복 회전하지
  않는다. 클라이언트 메모리 세션을 폐기하고 PGS server auth code 또는 Google
  로그인을 새로 수행한다.

refresh 회전 트랜잭션은 다음 순서로 고정한다.

```text
BEGIN
  -> token_hash로 refresh token과 session을 같은 lock order로 FOR UPDATE
  -> session status, 만료, 폐기, token 소비 여부 검사
  -> 이미 소비된 token이면 session과 token family 폐기
  -> 정상이면 기존 token consumed 처리
  -> child refresh token 생성
  -> session access token hash와 만료 갱신
COMMIT
```

모든 refresh 경로가 같은 잠금 순서를 사용한다. 모바일 refresh token은
Keychain/Keystore 기반 보안 저장소에 두고 access token은 메모리 보관을
우선한다. 일반 게임 저장과 sync outbox에 인증 token 원문을 넣지 않는다.

클라이언트에는 session별 전역 `RefreshCoordinator`를 둔다. 여러 API 요청이
동시에 `401`을 받아도 refresh HTTP 요청은 최대 하나만 in-flight로 두며 나머지
요청은 같은 Future를 기다린다. 성공하면 모두 새 access token으로 각각 한 번만
재시도한다. 이 single-flight 규칙을 지키지 않으면 정상 클라이언트의 중복 refresh가
서버에서 token replay로 판정되어 session 전체가 폐기될 수 있다.

지연된 `401`을 처리할 때는 해당 요청이 사용한 access token과 coordinator의 현재
token을 비교한다. 이미 다른 요청이 token을 회전했다면 추가 refresh 없이 현재
token으로 한 번만 재시도한다. logout 또는 dispose가 시작된 뒤 refresh를 기다리던
요청은 새 보호 요청을 시작하지 않는다.

## 온라인 저장 API

### 공통 규칙

- 외부 요청은 HTTPS만 허용한다.
- 인증 API를 제외한 요청은 `Authorization: Bearer <access-token>`을 사용한다.
- HTTP 시도별 추적 ID는 `X-Request-ID`로 응답한다.
- 저장과 향후 경제 명령은 `Idempotency-Key: <UUID>`를 사용한다.
- 동일 key 재시도는 동일하게 인코딩한 요청 본문을 사용한다.
- 서버 오류 응답은 `code`, `message`, `requestId` 형식이다.
- 사용자 표시 문구는 클라이언트 오류 코드 매핑으로 결정한다.

auth code 교환과 refresh는 일반 저장 idempotency 영수증 계약에서 제외한다.
PGS 교환 응답이 유실되면 새 server auth code로 인증을 다시 시작한다. logout은
이미 폐기된 session에도 성공으로 응답하는 자체 멱등 동작으로 만든다.

### 인증 요청과 응답

`POST /v1/auth/play-games` 요청:

```json
{
  "serverAuthCode": "one-time-code"
}
```

`POST /v1/auth/google` 요청:

```json
{
  "idToken": "google-id-token"
}
```

이미 로그인한 account에 Google identity를 연결하는
`POST /v1/account/identities/google`도 같은 body를 사용하며 bearer access token을
추가로 요구한다.

성공 응답:

```json
{
  "account": {"id": "019..."},
  "accessToken": "opaque-access-token",
  "accessExpiresAt": "2026-08-16T03:15:00Z",
  "refreshToken": "opaque-refresh-token",
  "refreshExpiresAt": "2026-09-15T03:00:00Z"
}
```

`POST /v1/auth/refresh`는 `refreshToken`을 받고 같은 token 응답 형식을 반환한다.
`POST /v1/auth/logout`은 body의 `refreshToken`으로 token family를 찾아 현재
session을 폐기하고 `204`를 반환한다. bearer access token이 유효하면 같은
session인지 함께 검사한다. 이미 만료·폐기된 token에도 `204`를 반환하며 token
원문을 URL이나 로그에 남기지 않는다.

| 상태 | 오류 코드 | 의미 |
| --- | --- | --- |
| `401` | `PLAY_GAMES_AUTH_REJECTED` | auth code 교환 또는 Player ID 검증 실패 |
| `401` | `GOOGLE_AUTH_REJECTED` | ID token 서명, issuer, audience 또는 만료 검증 실패 |
| `401` | `REFRESH_TOKEN_INVALID` | 알 수 없거나 만료된 refresh token |
| `401` | `REFRESH_TOKEN_REUSED` | 이미 소비된 refresh token 재사용과 session 폐기 |
| `401` | `ACCESS_TOKEN_INVALID` | 누락·만료·폐기되었거나 올바르지 않은 access token |
| `401` | `ACCESS_TOKEN_SESSION_MISMATCH` | logout의 유효한 access/refresh token이 서로 다른 세션에 속함 |
| `403` | `ACCOUNT_NOT_ACTIVE` | suspended 또는 deletion pending account |
| `404` | `SAVE_NOT_FOUND` | 아직 원격 저장이 없음 |
| `409` | `IDENTITY_ALREADY_LINKED` | Google identity가 다른 account에 이미 연결됨 |
| `409` | `SAVE_REVISION_CONFLICT` | expected revision과 현재 원격 revision이 다름 |
| `409` | `IDEMPOTENCY_KEY_REUSED` | 같은 key가 다른 저장 요청 본문에 재사용됨 |
| `413` | `REQUEST_TOO_LARGE` | 설정된 최대 요청 본문 크기 초과 |
| `422` | `SAVE_VERSION_UNSUPPORTED` | 서버가 지원하지 않는 저장 데이터 버전 |
| `422` | `INVALID_SAVE_DATA` | 필수 영역·값 형식 또는 JSON 중첩 제한 위반 |
| `503` | `AUTH_PROVIDER_UNAVAILABLE` | Google 인증 제공자 일시 장애 |

Android는 PGS, GitHub Pages는 Google 로그인을 사용한다. 두 identity가 같은 내부
account에 연결된 이후에는 동일한 온라인 저장을 사용한다. iOS는 플랫폼 인증 수단이
추가되기 전까지 로컬 저장만 사용한다.

Flutter Web 빌드는 `GOOGLE_WEB_CLIENT_ID`, `RUNE_NEXUS_API_BASE_URL` 두 dart-define이
모두 유효할 때만 Google 연결 액션을 노출한다. Google의 공식 GIS 버튼을 렌더링하고
받은 ID token은 즉시 인증 API로 전달한다. access/refresh token은 현재 브라우저
메모리에만 유지하며 Local Storage에는 저장하지 않는다. 페이지가 열린 동안에는 access
만료 전에 refresh를 단일 요청으로 회전하고, 여러 요청이 동시에 `401`을 받아도 같은
refresh 결과를 기다린 뒤 각 요청을 한 번만 재시도한다. refresh 응답 유실처럼 결과가
불명확한 실패는 같은 token으로 자동 재시도하지 않고 다시 로그인이 필요한 상태로
전환한다. 브라우저 새로고침 뒤 세션을 복구하는 영속 저장은 하지 않으므로 새로고침
시에도 다시 로그인한다.

### 초기 엔드포인트

| Method | Path | 역할 |
| --- | --- | --- |
| `POST` | `/v1/auth/play-games` | PGS 인증과 세션 발급 |
| `POST` | `/v1/auth/google` | Google 웹 인증과 세션 발급 |
| `POST` | `/v1/auth/refresh` | refresh token 회전 |
| `POST` | `/v1/auth/logout` | 현재 세션 폐기 |
| `POST` | `/v1/account/identities/google` | 기존 account에 Google identity 연결 |
| `GET` | `/v1/save` | 원격 저장 통파일 조회 |
| `PUT` | `/v1/save` | 전체 저장 조건부 갱신 |
| `GET` | `/health/live` | 프로세스 생존 확인 |
| `GET` | `/health/ready` | PostgreSQL 포함 준비 확인 |

### 저장 조회

`GET /v1/save` 성공 응답:

```json
{
  "revision": 12,
  "serverSavedAt": "2026-08-16T03:00:00Z",
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

원격 저장이 없으면 `404`와 `SAVE_NOT_FOUND`를 반환한다. 클라이언트는 이를
네트워크 실패가 아니라 최초 업로드 가능한 정상 상태로 처리한다.

### 저장 갱신

`PUT /v1/save` 요청:

```http
Authorization: Bearer <access-token>
Idempotency-Key: <UUID>
Content-Type: application/json
```

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

성공 응답:

```json
{
  "revision": 13,
  "serverSavedAt": "2026-08-16T03:00:01Z"
}
```

최초 저장은 원격 데이터가 없을 때 `expectedRevision: 0`으로 전송한다. 서버
현재 revision과 다르면 `409 SAVE_REVISION_CONFLICT`와 현재 revision을 반환한다.

### 멱등성

네트워크 timeout은 서버 실패를 의미하지 않는다. 클라이언트는 결과를 모르는
요청에 새 idempotency key를 발급하지 않는다.

서버 규칙은 다음과 같다.

1. account ID와 idempotency key로 저장 영수증을 빠르게 조회한다.
2. 같은 key가 있으면 hash를 비교해 기존 결과 또는 key 재사용 오류를 반환한다.
3. 새 요청이면 최초 header를 `INSERT ... ON CONFLICT DO NOTHING`으로 준비한다.
4. `save_headers`를 `SELECT ... FOR UPDATE`로 잠근다.
5. 잠금 획득 후 같은 idempotency key의 영수증을 반드시 다시 조회한다.
6. 잠금 대기 중 먼저 처리된 동일 요청이면 hash를 비교해 기존 결과를 반환한다.
7. 여전히 새 요청일 때만 expected revision을 검사한다.
8. 저장 영역, revision, 요청 영수증을 같은 트랜잭션에 기록한다.

요청 hash는 서버가 실제 수신한 body bytes로 계산한다. 클라이언트는 in-flight
요청의 정확한 인코딩 결과를 로컬에 보존하여 재시도 때 그대로 사용한다.

### 저장 트랜잭션

```text
BEGIN
  -> save_headers INSERT ... ON CONFLICT DO NOTHING
  -> save_headers SELECT ... FOR UPDATE
  -> 잠금 획득 후 기존 save request 재확인
  -> expected revision 검사
  -> preferences upsert
  -> progression upsert
  -> turretModules upsert
  -> activeRun upsert 또는 행 삭제
  -> save_headers revision 증가
  -> save_requests 영수증 기록
COMMIT
```

이 순서는 동일 key 요청 두 개가 동시에 도착해도 둘 다 같은 resulting revision을
응답하게 한다. 영수증 재조회가 header 잠금보다 앞에만 있으면 두 번째 요청이
잘못된 revision 충돌을 받을 수 있으므로 잠금 뒤 재조회는 생략하지 않는다.

중간 단계가 실패하면 전체를 rollback한다. `savedAtMillis`는 신뢰할 수 없는
참고값이며 원격 순서는 revision과 서버 시각만으로 판단한다.

## 클라이언트 동기화 상태 기계

### 현재 코드 통합 제약

현재 `SaveScheduler`는 `_writeLocalSave`만 직렬화하고 `_saveRoundCheckpoint`는
직접 파일 쓰기와 온라인 호출을 수행한다. 최종 구현에서는 다음처럼 바꾼다.

- 모든 로컬 파일 쓰기는 하나의 `LocalSaveCoordinator` 직렬화 경로를 사용한다.
- 체크포인트도 직접 `_writeLocalSaveData`를 호출하지 않는다.
- 로컬 저장 완료 후 outbox enqueue까지 성공해야 온라인 동기화를 예약한다.
- 로컬 저장 실패는 플레이를 막지 않지만 내부 결과로 실패를 전달해 outbox가
  저장되지 않은 스냅샷을 전송하지 않게 한다.
- `OnlineSaveRepository`의 Future는 HTTP 완료가 아니라 durable enqueue 완료를
  뜻한다.
- `_saveRoundCheckpoint`는 durable enqueue까지만 기다리고 HTTP는 기다리지 않는다.
- 여러 곳의 `unawaited(_saveRoundCheckpoint())`가 네트워크 병렬 요청을 만들지
  않도록 실제 HTTP 전송은 별도 `OnlineSaveCoordinator` 한 곳에서만 수행한다.

일반 게임 흐름이나 메뉴 이동은 느린 네트워크 응답을 기다리지 않는다.

### 영속 메타데이터

```text
accountIdBinding
remoteRevision
lastSyncedPayloadHash
dirty
inFlight:
  idempotencyKey
  expectedRevision
  encodedRequestBody
  payloadHash
  payloadGeneration
pendingLatestGeneration
syncState
retryCount
nextRetryAt
```

토큰 원문과 저장 동기화 상태는 분리한다. 계정이 바뀌면 다른 계정의 outbox를
전송하지 않도록 `accountIdBinding`을 확인한다.

payload 파일 쓰기는 `LocalSaveCoordinator`가 직렬화하고, **모든 sync metadata
read-modify-write는 계정 슬롯별 하나의 `SyncStateCoordinator` mutex를 거친다.**
`LocalSaveCoordinator`와 `OnlineSaveCoordinator`가 metadata 파일을 각자 읽고
덮어쓰는 경로는 허용하지 않는다. 로컬 저장 후 dirty/generation 기록, in-flight
생성, retry 갱신과 ack 적용을 모두 같은 임계구역에서 수행한다. payload 파일과
metadata 파일은 서로 다른 원자적 교체 단위지만 metadata 상태 전이는 한 경로다.

### save outbox

- 계정별 네트워크 in-flight 저장은 최대 하나다.
- in-flight 중 생긴 여러 저장은 최신 스냅샷 하나로 합친다.
- in-flight 성공 후 새 revision으로 최신 pending을 다시 인코딩한다.
- in-flight 결과가 불명확하면 같은 bytes와 같은 key로 먼저 재시도한다.
- 과거 요청 응답이 늦게 도착해도 현재 in-flight key와 다르면 무시한다.
- outbox 상태는 앱 재시작 후에도 복구한다.

### crash consistency

로컬 payload 파일과 sync metadata는 서로 다른 저장 단위이므로 다음 순서와
재시작 복구 규칙을 지킨다.

```text
1. 새 로컬 payload를 원자적으로 저장한다.
2. sync metadata를 dirty와 새 generation으로 원자적 교체한다.
3. 전송 직전 exact encoded body와 idempotency key를 inFlight로 원자적 저장한다.
4. inFlight 영속 성공 후에만 HTTP 요청을 시작한다.
5. ack 수신 시 슬롯 mutex 안에서 metadata를 다시 읽고 현재 generation/hash를
   ack의 `payloadGeneration`/`payloadHash`와 비교한다.
6. remoteRevision, lastSyncedPayloadHash와 inFlight 제거를 한 번의 metadata 교체로
   반영하되, ack 대상보다 최신 로컬 payload가 있으면 dirty를 유지하고 다음
   pending으로 둔다.
```

1과 2 사이에서 앱이 종료될 수 있으므로 시작할 때 현재 로컬 payload hash와
`lastSyncedPayloadHash`를 항상 다시 비교하여 dirty를 재구성한다. `inFlight`가
남아 있으면 현재 파일로 다시 인코딩하지 않고 보존된 exact body부터 재시도한다.
`pendingLatestGeneration`은 실제 payload 복사본이 아니며, 최신 pending은 현재
정상 로컬 파일에서 새 요청으로 재구성한다.

예시:

```text
remote revision 10
A 전송(expected 10, key A)
로컬 B, C 저장 -> pending에는 C만 유지
A 응답 유실 -> 같은 A 재전송
서버가 기존 결과 revision 11 반환
C 전송(expected 11, key C)
성공 revision 12
```

### 향후 command outbox

결제, 다이아 소비와 보상 수령은 스냅샷처럼 합치지 않는다. 각 명령은 고유
idempotency key와 정확한 본문을 가진 FIFO 항목으로 영속 보존한다. 앞 명령의
결과를 모르는 상태에서 같은 자원을 쓰는 뒤 명령을 먼저 보내지 않는다.

### 상태와 오류 처리

```text
idle
sending
retryWaiting
refreshingAuth
conflict
blocked
```

| 결과 | 처리 |
| --- | --- |
| network, timeout, `408`, `429`, `5xx` | 같은 요청을 backoff + jitter로 재시도 |
| `401` | refresh 한 번 수행 후 같은 요청 재시도 |
| `409 SAVE_REVISION_CONFLICT` | 자동 업로드 중단, conflict 진입 |
| `400`, `413`, `422` | 무한 재시도 금지, blocked 및 진단 기록 |

`429`의 `Retry-After`가 있으면 우선 적용한다. 동기화 작업은 게임 프레임과
로컬 저장 경로를 기다리게 하지 않는다.

### 최초 로그인과 충돌

- 로그인 전에는 로컬 저장만 사용한다.
- legacy v1은 account 슬롯으로 직접 이전하지 않고 guest 슬롯으로만 보존형
  마이그레이션한다.
- 최초 계정 연결 시 guest 데이터를 자동으로 account 슬롯에 복사하거나 업로드하지
  않는다. guest 원본과 별도 backup을 먼저 남기고 사용자 선택을 받는다.
- 원격과 기존 account 슬롯이 모두 없으면 `guest 진행을 account로 복사` 또는
  `새 account 진행 사용` 중 선택한다. 복사 선택 시 새 account 슬롯을 만들고
  revision 0 업로드 대상으로 표시한다.
- 원격 또는 기존 account 슬롯이 있으면 `guest 유지`, `guest 진행을 account로
  복사하여 조건부 업로드`, `기존 account/원격 진행 사용`을 명시적으로 선택하게
  한다. guest 복사로 원격을 대체할 때도 최신 원격 revision을 다시 조회한다.
- `guest 유지`는 해당 저장을 local-only guest 슬롯에 남긴다는 뜻이며 로그인된
  account 저장과 합치지 않는다. logout도 슬롯 사이 데이터를 자동 복사하지 않는다.
- 업로드 대상으로 선택된 account 슬롯에 원격 저장이 없으면 해당 저장을
  revision 0으로 업로드한다.
- 원격 저장이 있고 현재 로컬 저장이 같은 계정의 알려진 revision에 기반하면
  dirty 여부와 revision으로 업로드 또는 다운로드를 결정한다.
- 계정 연결 이력이 없는 로컬 저장과 기존 원격 저장이 모두 의미 있으면 둘을
  보존하고 사용자가 선택하도록 한다.
- 원격 데이터를 적용하기 전에 현재 로컬 파일을 별도 backup으로 남긴다.
- revision 충돌 시 client timestamp가 더 크다는 이유로 자동 덮어쓰지 않는다.
- 사용자가 로컬 사용을 명시하면 최신 원격 revision을 다시 조회한 후 같은
  `PUT /v1/save` 계약으로 조건부 업로드한다.

## 중요 경제·이벤트 API 확장

이 절은 실제 결제나 서버 권위 이벤트를 도입할 때 구현한다. 초기 인증과
클라우드 저장을 위해 미리 불필요한 경제 테이블과 API를 만들지 않는다.

### 원칙

- `PATCH /player`처럼 잔액이나 레벨을 직접 설정하는 API를 만들지 않는다.
- 클라이언트는 상품 ID, 구매 증명과 수행하려는 행동만 보낸다.
- 서버가 가격, 잔액, 중복, 보상과 RNG를 결정한다.
- 실제 결제 증명은 Google Play 또는 Apple 서버 결과로 검증한다.
- 서로 같은 상품에 사용할 수 있는 free/paid diamonds는 경제 전환 시점부터
  모두 서버 원장에 둔다.
- 유료 재화로 모듈을 뽑을 수 있으면 재화 차감, RNG와 모듈 생성까지 서버에서 한다.
- 서버 권위 필드는 일반 save payload로 변경할 수 없다.

현재 코드는 적 처치 RNG, 일·주간 퀘스트, 출석과 모듈 분해에서 free diamonds를
지급하고, 연구 완료·연구 슬롯·모듈 티켓 구매에서 통합 diamond 잔액을 쓴다.
따라서 실제 경제 전환은 일부 setter만 서버화해서는 안 되며 다음 경로를 함께
명령으로 승격해야 한다.

- 모든 free/paid diamond 획득과 소비
- 다이아를 소비하는 연구와 상품 구매
- 다이아를 지급하거나 소비하는 모듈 생성·분해
- 다이아를 지급하는 퀘스트·출석·이벤트 claim

전환 전에는 현재 diamond 값도 일반 로컬 진행 데이터이며 치트 방지 대상이라고
주장하지 않는다. 실제 결제를 여는 출시 전에 계정당 한 번만 허용하는
`legacy_import` 원장 정책과 정상 최대치 cap을 확정한다. 전환 이후 paid diamond는
검증된 구매에서만 증가하고, free diamond는 idempotent 서버 명령으로만 증가한다.

서버 권위 필드는 로컬 `GameSaveData`에 오프라인 표시용 캐시로 남을 수 있지만
`PUT /v1/save`에서는 무시한다. `GET /v1/profile` 또는 bootstrap 응답의 값으로
항상 overlay한다. save revision과 economy revision은 별도 aggregate revision으로
관리하여 오래된 스냅샷이 뒤늦게 도착해도 경제 상태를 되돌리지 못하게 한다.

### 확장 엔드포인트 후보

| Method | Path | 역할 |
| --- | --- | --- |
| `GET` | `/v1/profile` | 서버 권위 지갑·권리 조회 |
| `POST` | `/v1/purchases/play/verify` | Google Play 구매 검증과 지급 |
| `POST` | `/v1/purchases/apple/verify` | Apple 거래 검증과 지급 |
| `POST` | `/v1/store/{productId}/purchase` | 서버 가격 기준 상품 구매 |
| `POST` | `/v1/events/{eventId}/progress-actions` | 절대 합계가 아닌 event action 보고 |
| `POST` | `/v1/events/{eventId}/rewards/{rewardId}/claim` | 이벤트 보상 중복 검사와 지급 |
| `POST` | `/v1/runs/complete` | 서버 보상이 연결된 런 완료 보고 |

일반 라운드 완료는 `/v1/runs/complete`를 호출하지 않는다. 로컬 체크포인트와
save outbox 갱신만 수행한다. 서버 보상이나 이벤트 판정이 붙은 런 완료만
별도 명령을 사용한다.

경제 전환 후에도 오프라인 일반 플레이와 다이아가 아닌 로컬 보상은 유지한다.
오프라인에서 발생한 diamond 획득은 고유 source ID를 가진 pending claim으로
보관하며 서버가 승인하기 전 소비 가능한 잔액에 포함하지 않는다. 서버는
카탈로그 상한과 중복을 검사하지만 클라이언트 전투 진위를 완전히 증명할 수는
없으므로 획득 속도 통계를 함께 기록한다. diamond 소비, 실제 결제와 서버 권위
보상은 온라인 확인이 필요하며 결과가 불명확하면 같은 명령을 재시도한다.

### 통계 기반 위험 대응

통계는 서버 권위 전투를 대신하지 않으며 완전한 치트 증명이 아니다.

1. 음수 잔액, 중복 구매 증명, 중복 보상처럼 불가능한 상태는 즉시 거부한다.
2. 비정상 성장 속도, 과도한 클리어 빈도와 시계 역행은 이벤트로 기록한다.
3. 계정별 일간 집계를 만들고 반복된 이상 징후에 위험 점수를 부여한다.
4. 단일 통계나 기기 무결성 신호로 자동 차단하지 않는다.
5. 필요하면 민감한 경제 요청에만 Play Integrity 또는 App Attest를 추가한다.

초기에는 외부 분석 서비스를 사용하지 않고 PostgreSQL 집계와 서버 로그로
충분한지 먼저 검증한다. 토큰, auth code, 전체 save payload와 불필요한 개인
정보는 통계 로그에 남기지 않는다.

## PostgreSQL 1차 스키마

PostgreSQL 18의 `uuidv7()`을 내부 ID 기본값으로 사용한다. account ID는 API
본문에서 받지 않고 인증된 session에서 얻는다.

### 관계

```text
accounts
  |- auth_identities
  |- sessions
  |    `- refresh_tokens
  `- save_headers
       |- save_preferences
       |- save_progression
       |- save_turret_modules
       |- save_active_runs     # optional
       `- save_requests
```

### 계정과 인증 수단

```text
accounts
- id UUID PK DEFAULT uuidv7()
- status VARCHAR(32) NOT NULL DEFAULT 'active'
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
- deletion_requested_at TIMESTAMPTZ NULL
- CHECK status IN ('active', 'suspended', 'deletion_pending')

auth_identities
- id UUID PK DEFAULT uuidv7()
- account_id UUID NOT NULL FK accounts(id) ON DELETE CASCADE
- provider VARCHAR(32) NOT NULL
- subject VARCHAR(255) NOT NULL
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- last_verified_at TIMESTAMPTZ NOT NULL DEFAULT now()
- UNIQUE(provider, subject)
- UNIQUE(account_id, provider)
- CHECK provider IN ('play_games', 'google', 'apple')
- CHECK subject <> ''
```

이메일은 identity 병합 기준이나 필수 계정 컬럼으로 사용하지 않는다.

### 세션과 refresh token

```text
sessions
- id UUID PK DEFAULT uuidv7()
- account_id UUID NOT NULL FK accounts(id) ON DELETE CASCADE
- access_token_hash BYTEA NOT NULL UNIQUE
- access_expires_at TIMESTAMPTZ NOT NULL
- refresh_expires_at TIMESTAMPTZ NOT NULL
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- last_used_at TIMESTAMPTZ NOT NULL DEFAULT now()
- revoked_at TIMESTAMPTZ NULL
- CHECK octet_length(access_token_hash) = 32
- CHECK access_expires_at > created_at
- CHECK refresh_expires_at > access_expires_at

refresh_tokens
- id UUID PK DEFAULT uuidv7()
- session_id UUID NOT NULL FK sessions(id) ON DELETE CASCADE
- token_hash BYTEA NOT NULL UNIQUE
- parent_token_id UUID NULL FK refresh_tokens(id)
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- consumed_at TIMESTAMPTZ NULL
- revoked_at TIMESTAMPTZ NULL
- CHECK octet_length(token_hash) = 32
```

`refresh_tokens(session_id)`과 `sessions(account_id)`를 인덱스화한다. session당
`consumed_at IS NULL AND revoked_at IS NULL`인 refresh token은 하나만 허용하는
partial unique index를 둔다. parent token당 자식도 하나만 허용한다.

### 저장 헤더와 영역

```text
save_headers
- account_id UUID PK FK accounts(id) ON DELETE CASCADE
- schema_version INTEGER NOT NULL
- revision BIGINT NOT NULL DEFAULT 0
- client_saved_at_millis BIGINT NOT NULL
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
- CHECK schema_version > 0
- CHECK revision >= 0
- CHECK client_saved_at_millis >= 0

save_preferences
save_progression
save_turret_modules
save_active_runs
- account_id UUID PK FK save_headers(account_id) ON DELETE CASCADE
- payload JSONB NOT NULL
- CHECK jsonb_typeof(payload) = 'object'
```

`preferences`, `progression`, `turretModules` 행은 정상 저장에서 항상 존재한다.
`activeRun: null`은 `save_active_runs` 행이 없는 상태로 표현한다. 저장 조회는
account ID PK로만 수행하므로 JSONB GIN index는 만들지 않는다.

payload 전체 크기, JSON 중첩, 지원 버전, 필수 키와 게임 값 범위는 Go에서
검사한다. DB CHECK로 다른 테이블 값을 참조하는 규칙을 만들지 않는다.

### 저장 요청 영수증

```text
save_requests
- account_id UUID NOT NULL FK save_headers(account_id) ON DELETE CASCADE
- idempotency_key UUID NOT NULL
- request_hash BYTEA NOT NULL
- expected_revision BIGINT NOT NULL
- resulting_revision BIGINT NOT NULL
- result_saved_at TIMESTAMPTZ NOT NULL
- created_at TIMESTAMPTZ NOT NULL DEFAULT now()
- PRIMARY KEY(account_id, idempotency_key)
- UNIQUE(account_id, resulting_revision)
- CHECK octet_length(request_hash) = 32
- CHECK expected_revision >= 0
- CHECK resulting_revision = expected_revision + 1
```

영수증 보존 기간은 클라이언트의 최대 재시도 기간보다 길게 설정한다. 정리된
영수증의 아주 오래된 요청이 다시 오더라도 expected revision 불일치로 중복
저장은 막힌다.

### 삭제 정책

account hard delete는 identity, session, 저장을 `ON DELETE CASCADE`로 제거한다.
일반 API가 곧바로 hard delete하지 않고 먼저 `deletion_pending`으로 전환하며,
출시 안전장치 단계에서 유예 기간과 복구 정책을 확정한다.

인증 middleware는 매 요청에서 session뿐 아니라 `accounts.status = 'active'`를
확인한다. `suspended` 또는 `deletion_pending` 전환은 기존 session을 같은
관리 트랜잭션에서 폐기하여 이미 발급된 access token도 더 이상 허용하지 않는다.

### 향후 중요 경제 스키마

실제 서버 권위 경제를 도입할 때 다음 테이블을 별도 마이그레이션으로 추가한다.

```text
player_wallets
economy_ledger
purchase_transactions
command_requests
event_progress
reward_claims
security_events
player_metrics_daily
```

purchase token 또는 Apple transaction ID는 중복 지급 방지를 위해 unique해야
한다. 원장 행은 수정하지 않고 정정 행을 추가한다. 경제 전환 뒤 다이아로
전환할 수 있거나 서버 권위 상품과 교환할 수 있는 모든 모듈은 무료 티켓 등
획득 경로와 무관하게 JSONB 스냅샷이 아니라 서버 소유 item 테이블로 승격한다.
그렇지 않으면 위조한 무료 모듈을 분해해 서버 권위 다이아로 바꾸는 경로가 생긴다.

## SQL과 Go 코드 규칙

- 스키마 변경은 새 `tern` SQL 파일로만 수행한다.
- 적용된 마이그레이션을 뒤늦게 수정하지 않는다.
- 데이터 삭제와 비가역 변경은 사용자 확인 후 진행한다.
- 실행 쿼리는 `server/db/queries`에 작성한다.
- `sqlc` 생성 코드는 `server/internal/dbgen`에 두고 직접 수정하지 않는다.
- 생성 코드는 저장소에 커밋한다.
- 쿼리 또는 스키마 변경 후 `sqlc generate`, `sqlc vet`을 실행한다.
- 트랜잭션은 저장과 인증 유스케이스에서 명시적으로 관리한다.
- 단순 전달만 하는 repository/service wrapper는 만들지 않는다.

초기 마이그레이션은 다음처럼 나눈다.

```text
001_accounts_and_sessions.sql
002_online_saves.sql
```

## Go 서버 디렉터리 기준

```text
server/
|- cmd/api/main.go
|- internal/
|  |- account/
|  |- auth/playgames/
|  |- auth/google/
|  |- config/
|  |- dbgen/
|  |- httpapi/
|  |  |- middleware/
|  |  `- v1/
|  |- save/
|  `- session/
|- db/
|  |- migrations/
|  `- queries/
|- docker/migrate-entrypoint.sh
|- Dockerfile
|- Dockerfile.migrate
|- Makefile
|- go.mod
|- go.sum
`- sqlc.yaml
```

## 설정과 비밀값

```text
DATABASE_URL 또는 DATABASE_* 파일 설정
PGS_WEB_CLIENT_ID
PGS_WEB_CLIENT_SECRET_FILE
GOOGLE_WEB_CLIENT_ID
GOOGLE_AUTH_ENABLED
HTTP_ADDRESS
IDENTITY_VERIFY_TIMEOUT
ACCESS_TOKEN_TTL
REFRESH_TOKEN_TTL
CORS_ALLOWED_ORIGINS
MAX_SAVE_BODY_BYTES
READINESS_TIMEOUT
SHUTDOWN_TIMEOUT
```

- 실제 비밀값은 Git에 커밋하지 않는다.
- secret 파일 또는 읽기 전용 Docker secret을 우선한다.
- 누락되거나 잘못된 설정은 서버 시작 시 즉시 거부한다.
- `GOOGLE_AUTH_ENABLED` 기본값은 `false`다. `true`일 때
  `GOOGLE_WEB_CLIENT_ID`가 없으면 시작을 거부한다.
- `CORS_ALLOWED_ORIGINS`는 쉼표로 구분한 정확한 HTTP(S) origin 목록이다. 경로,
  query와 wildcard는 받지 않는다.
- 기본 access token 만료는 15분, refresh token 만료는 30일이며 refresh 만료가
  access 만료보다 길지 않으면 시작을 거부한다.
- `MAX_SAVE_BODY_BYTES` 기본값은 4 MiB이며 0보다 큰 정수 byte 값만 허용한다.
- 저장 요청 JSON은 최대 64단계까지 중첩할 수 있다.
- 토큰, auth code, OAuth secret, 구매 증명과 전체 save payload를 로그에 남기지 않는다.

## 네트워크와 배포

- 개발 Compose 내부 API는 HTTP로 통신한다.
- 외부 모바일·웹 요청은 HTTPS만 허용한다.
- TLS는 Caddy 또는 Nginx 같은 자체 운영 reverse proxy에서 종료할 수 있다.
- PostgreSQL 포트는 운영 외부에 공개하지 않는다.
- 현재 Compose의 단일 DB 사용자는 개발 편의를 위한 구성이다.
- 운영에서는 schema migration owner와 제한된 DML runtime role을 분리한다.
- API runtime role에는 애플리케이션 테이블의 필요한 SELECT/INSERT/UPDATE/DELETE만
  허용하고 스키마 변경 권한을 주지 않는다.
- 인증·저장·경제 요청은 모두 일반 HTTP 요청-응답으로 충분하다.
- 실시간 PvP, 채팅, 서버 push 요구가 생기기 전에는 WebSocket을 추가하지 않는다.
- named volume은 `pg_dump` 백업과 실제 복원 시험을 마련한다.

## 검증 전략

### Flutter 단위·통합 테스트

- system temp legacy v1을 application support의 account/guest v2 슬롯으로 이관
- legacy v1을 별도 v2 위치로 이관하고 v1을 보존
- 손상된 기본 v2에서 v2 backup, 이후 v1 순서로 fallback
- canonical v2와 허용된 transitional v2 구분
- 로드 실패 후 기존 저장을 빈 게임으로 덮어쓰지 않음
- IO 임시 파일 교체 실패 시 직전 저장 보존
- 통파일 API 직렬화 왕복
- save outbox 단일 in-flight 보장
- 모든 로컬 쓰기의 단일 coordinator 직렬화
- 여러 pending 저장을 최신 하나로 병합
- payload 저장과 dirty 기록 사이 강제 종료 후 hash 기반 복구
- timeout 후 동일 bytes/key 재시도
- 앱 재시작 후 in-flight 복구
- stale 응답 무시
- `401` refresh 후 동일 요청 재시도
- `409` 충돌에서 자동 덮어쓰기 방지
- 온라인 실패가 게임 진행을 막지 않음

### Go 단위 테스트

- 설정 검증
- opaque token 생성과 SHA-256 해시
- refresh 회전과 재사용 탐지
- 동시 refresh 중 하나만 회전 성공
- refresh 응답 유실 후 재사용과 PGS 재로그인 복구 구분
- PGS 응답 파싱과 오류 매핑
- 저장 크기, 버전, 구조 검증
- 동일 idempotency key 재응답
- 같은 key의 다른 body 거부
- 공통 API 오류 형식

### PostgreSQL 통합 테스트

- 최초 account와 identity 동시 생성
- 같은 PGS Player ID의 동시 가입 중복 방지
- refresh 회전 후 이전 token 재사용 시 session 폐기
- 최초 revision 0 저장
- 영역 전체 upsert
- 중간 오류 전체 rollback
- 동시에 저장한 요청 중 하나만 성공
- 응답 유실을 가정한 같은 요청 재처리
- 동일 key와 body의 동시 2요청이 같은 resulting revision 성공
- 동일 key와 다른 body의 동시 요청이 key 재사용 오류
- 다른 body의 key 재사용 거부
- `activeRun: null` 행 삭제
- account 삭제 cascade

### 실제 통합 검증

- PGS 테스트 계정 로그인
- 앱 재설치 후 원격 저장 복원
- 느린 네트워크와 응답 유실 시 저장 순서 보장
- 앱 강제 종료 후 outbox 복구
- 두 기기 revision 충돌과 양쪽 백업
- Web legacy 저장 실제 마이그레이션
- PostgreSQL 백업 파일 복원

## 구현 순서

### 1단계: 서버 기반

- [x] Go와 도구 버전 고정
- [x] `server/` 모듈과 HTTP 서버
- [x] Dockerfile과 Compose API 서비스
- [x] PostgreSQL 연결과 health check
- [x] `tern` 실행 기반

### 2단계: 로컬 저장 배포 안전성

- [x] system temp 저장을 application support 영속 위치로 이전
- [x] guest/account별 로컬 슬롯 분리
- [x] v2 전용 키·파일과 legacy v1 fallback
- [x] canonical/transitional v2 validator
- [x] 원자적 IO 저장과 v2 backup
- [x] 모든 로컬 쓰기의 단일 coordinator 통합
- [x] legacy v1과 legacy 위치의 v2 fixture 마이그레이션 테스트
- [x] 전체 Flutter analyze/test와 Web·Android 빌드 검증

### 3단계: 계정·저장 DB

- [x] account, identity, session, refresh token 마이그레이션
- [x] 영역별 저장과 save request 마이그레이션
- [x] `sqlc.yaml`, 쿼리와 생성 코드
- [x] 실제 PostgreSQL 통합 테스트

### 4단계: PGS·Google 인증과 계정 UX

- Android Application ID를 `com.runenexus.game`으로 변경
- 출시 서명과 PGS/OAuth 설정
- Kotlin PGS v2와 Flutter MethodChannel
- [x] Google Identity Services 웹 로그인과 허용 origin 설정
- [x] Google ID token 검증과 account/session 발급 API
- [x] refresh 회전·재사용 감지·로그아웃·Bearer 인증 기반
- [x] Flutter 메모리 세션 자동 갱신과 401 1회 재시도
- Go PGS auth code 교환과 Player ID 검증
- identity 연결 API와 중복 account 충돌 처리
- [x] 계정 상태 모델과 계정·저장 진입 UI

### 5단계: 온라인 저장

- [x] 인증된 `GET/PUT /v1/save`
- [x] revision, 멱등성과 저장 트랜잭션
- Flutter 영속 save outbox와 동기화 상태 기계
- 최초 로그인, 재시도, 충돌과 백업 정책
- 느린 네트워크·재시작 통합 검증

### 6단계: 중요 경제 확장

- 실제 결제 기능이 확정된 뒤 구매 검증과 원장 추가
- 다이아·상품·중요 이벤트 보상 명령 API
- command outbox
- 규칙 기반 위험 이벤트와 최소 통계

### 7단계: 출시 안전장치

- HTTPS reverse proxy, 요청 제한과 보안 헤더
- 계정·원격 데이터 삭제
- DB 백업과 복원 자동화
- 개인정보 처리방침과 스토어 데이터 공개 항목

## 1차 범위에서 제외

- 서버 권위형 전투 시뮬레이션
- 모든 라운드와 전투 행동의 서버 명령화
- WebSocket
- 자동 저장 병합과 last-write-wins
- 관리자 페이지와 외부 분석 플랫폼
- 머신러닝 기반 치트 탐지
- 단일 무결성 신호를 이용한 자동 차단
- 실제 결제 기능이 없는 상태의 선제적 경제 시스템
- Apple 일반 로그인 실제 구현
- 이메일·비밀번호 로그인

## main 통합 전 배포 게이트

`main` push는 GitHub Pages 자동 배포로 이어진다. 저장 v2 변경은 다음 조건을
모두 만족하기 전 `main`에 통합하지 않는다.

- legacy v1 저장을 덮어쓰지 않는 v2 위치 분리
- system temp legacy 저장의 영속 위치 이전
- v1 -> v2, v2 backup, 손상 v2 fallback 테스트
- canonical/transitional v2 validator
- 모든 로컬 저장 경로의 단일 직렬화
- 로컬 저장 실패 시 기존 데이터 보존
- 전체 Flutter analyze/test 통과
- 실제 Chrome Web Local Storage fixture 자동 검증
- 이전 배포로 되돌렸을 때 legacy v1을 읽을 수 있음

Go 서버, Compose와 문서처럼 클라이언트 저장 형식을 바꾸지 않는 변경은 별도
커밋으로 통합할 수 있다.

## 현재 구현 상태

- 현재 브랜치에는 `GameSaveData` v2 영역 분리와 v1 -> v2 변환 코드가 있다.
- Web과 IO 모두 guest/account별 v2 primary와 backup 위치를 사용한다.
- guest legacy 저장은 원본을 보존한 채 신규 v2 위치로 이전한다.
- IO 저장은 application support를 사용하며 원자적 교체 중단도 복구한다.
- 일반 저장과 체크포인트는 단일 `LocalSaveCoordinator`를 거친다.
- Go 1.26.5, pgx 5.10.0, sqlc 1.31.1, tern 2.4.1을 고정했다.
- PostgreSQL, migrate, API Compose 실행 기반이 있다.
- 계정·session과 영역별 온라인 저장 스키마 및 `sqlc` 쿼리가 구현되어 있다.
- 게스트·연결·오프라인·확인 필요 상태를 표시하는 계정·저장 UI 기반이 구현되어 있다.
- `/health/live`, `/health/ready`가 구현되어 있다.
- Android Application ID는 아직 `com.example.rune_nexus`다.
- release 빌드는 아직 debug signing을 사용한다.
- PGS 인증과 실제 저장 API는 아직 없다.
