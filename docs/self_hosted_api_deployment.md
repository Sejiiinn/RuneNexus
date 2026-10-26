# 자체 운영 API 배포

배포 시작 전 [배포 상태와 세션 간 인계](deployment_status.md)를 확인한다. 필요한 migration과
적용 순서, 마지막 검증 상태는 해당 문서에 기록하며, 아래 과거 시점 설명과 구분한다.

Rune Nexus 운영 API는 기존 개발용 Compose에 `compose.production.yaml`을 겹쳐
실행합니다. Caddy만 외부 80/443 포트를 받고, Go API와 PostgreSQL은 Docker
내부망 또는 호스트 loopback에서만 접근할 수 있습니다.

이 구성은 HTTPS 진입점과 컨테이너 경계를 준비하는 운영 배포 골격입니다. DB 권한
분리와 백업·복원 자동화가 완료되기 전에는 정식 출시 구성으로 보지 않습니다.

2026-09-05 인증 세션 복원 구현 기준입니다. 아래 영속 인증 준비 항목은 아직 운영에
적용하지 않았으며, 기존 HTTPS/CORS 확인만으로 자동 로그인 검증이 끝난 것은 아닙니다.

```text
Godot Android 앱
          | HTTPS :443
          v
        Caddy
          | HTTP, Compose 내부망
          v
      Go API :8080
          |
          v
      PostgreSQL :5432

DuckDNS updater -- HTTPS --> DuckDNS
       | 현재 공인 IPv4 자동 등록
       +--------------------> API hostname
```

## 외부 공개 전 조건

- ipTIME WAN 주소가 실제 공인 IP인지 확인한다. 통신사 CGNAT 환경이면 공유기 포트
  포워딩만으로 외부 접속할 수 없다.
- DuckDNS에서 사용할 label을 선점한다. 예를 들어 label이 `runenexus-api`라면
  `DUCKDNS_SUBDOMAIN=runenexus-api`, `API_HOST=runenexus-api.duckdns.org`로 맞춘다.
  `API_HOST`에는 scheme과 경로를 넣지 않는다.
- ipTIME에서 TCP 80, TCP 443을 서버 호스트로 전달한다. HTTP/3를 사용할 경우
  UDP 443도 함께 전달한다.
- 서버 호스트 방화벽에서도 동일한 포트를 허용한다.
- PostgreSQL 5432와 Go API 8080은 공유기 포트 포워딩 대상으로 등록하지 않는다.

Caddy는 도메인의 DNS와 80/443 도달 조건이 충족되면 공개 인증서를 자동으로
발급하고 갱신합니다. 별도 Certbot 컨테이너나 갱신 작업은 사용하지 않습니다.
Caddy를 선택해도 공인 IP, DNS 또는 통신사 포트 제한 문제를 우회할 수는 없습니다.
Caddy 관리자 API는 컨테이너 loopback에만 바인딩하며 호스트 포트로 공개하지
않습니다.

## 운영 환경 파일

실제 공개 설정은 커밋하지 않는 `.env.production`에 기록합니다.

```bash
cp .env.production.example .env.production
chmod 600 .env.production
```

필수 항목은 다음과 같습니다.

- `DUCKDNS_SUBDOMAIN`: DuckDNS에서 선점한 label. `.duckdns.org`는 붙이지 않음
- `API_HOST`: `<DUCKDNS_SUBDOMAIN>.duckdns.org` 형식의 공개 API 호스트명
- `ACME_EMAIL`: 인증서 계정 알림을 받을 이메일
- `GOOGLE_WEB_CLIENT_ID`: Google Web OAuth Client ID. Android 앱의 server client ID로 사용
- `AUTH_SESSION_RECEIPT_KEY`: base64 인코딩한 32-byte 영수증 암호화 키. 서버 재시작과
  모든 API 인스턴스에서 동일하게 유지하며 `.env.production` 같은 비공개 설정에만 보관
- `CORS_ALLOWED_ORIGINS`: 운영 override가 요구하는 허용 origin 목록. 폐기한 웹 클라이언트의
  `/v1/auth/web/*` 경로에만 쓰이며 Android 앱의 `/v1/auth/native/*` 요청은 사용하지 않음

DuckDNS 계정 token은 환경 변수가 아니라 Docker secret 파일로 전달합니다. 계정
페이지에서 token을 확인한 뒤 다음 파일에 token 한 줄만 기록합니다.

```bash
mkdir -p .secrets
chmod 700 .secrets
${EDITOR:-vi} .secrets/duckdns_token
chmod 600 .secrets/duckdns_token
```

`.secrets/`와 `.env.production`은 Git에서 제외됩니다. DuckDNS 갱신기는 token을
로그에 남기지 않고 HTTPS로 현재 공인 IPv4를 등록합니다. 정상 상태에서는 5분마다
갱신하며 실패하면 30초마다 재시도합니다. 마지막 성공 뒤 정상 갱신 주기의 세 배가
지나면 컨테이너가 `unhealthy`로 표시됩니다.

다음 요청 제한 조정값은 생략하면 예시 파일에 적힌 기본값을 사용합니다.

- `AUTH_RATE_LIMIT_WINDOW`: 인증 요청 token bucket이 완전히 충전되는 기간
- `GOOGLE_AUTH_RATE_LIMIT`: 기간 내 허용할 Google 로그인 요청 수
- `REFRESH_AUTH_RATE_LIMIT`: 기간 내 허용할 토큰 갱신 요청 수
- `LEGACY_LOCAL_TRANSFER_ENABLED`: 기존 카카오 테스터의 일회용 이전 API 활성화.
  정식 배포 전 `false` 전환 후 관련 코드와 DB를 제거
- `LEGACY_TRANSFER_TTL`: 일회용 이전 링크 유효기간. 현재 `15m`
- `LEGACY_TRANSFER_CREATE_RATE_LIMIT`, `LEGACY_TRANSFER_CONSUME_RATE_LIMIT`:
  임시 이전 endpoint별 클라이언트 요청 상한
- `AUTH_RATE_LIMIT_MAX_CLIENTS`: endpoint마다 메모리에 보관할 최대 클라이언트 수

`MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION`은 writer 획득·저장 PUT·경제 명령에 허용할 최소
클라이언트 호환 세대입니다. 기본값 1을 유지하고, 저장 계약을 깨는 클라이언트 변경을
배포할 때 서버 보호 규칙을 먼저 배포한 뒤 올립니다. 서버 코드의 현재 호환 버전보다
크게 설정하면 API가 시작을 거부합니다.

PostgreSQL 비밀번호는 개발 환경과 동일하게 `.secrets/postgres_password` 파일을
사용하며 환경 파일에 복사하지 않습니다. 운영 override는 Google 인증을 항상
활성화하므로 Client ID나 CORS origin이 빠지면 Compose 설정 단계에서 실패합니다.
운영 override는 Caddy가 정리한 `X-Forwarded-For`를 요청 제한 키로 사용하도록
`TRUST_PROXY_HEADERS=true`도 고정합니다. API 8080을 외부에 직접 공개한 상태에서 이
값을 활성화하면 클라이언트가 전달 헤더를 위조할 수 있으므로 현재 포트 경계를
유지해야 합니다.

요청 제한 기본값은 Google 로그인 10회/분, 토큰 갱신 30회/분입니다. 초과 시 API는
`429 Too Many Requests`와 초 단위 `Retry-After`를 반환합니다. 이 제한은 단일 API
프로세스의 메모리에서 동작하므로 여러 API 인스턴스로 확장할 때는 공유 제한 계층을
별도로 검토합니다. 표준 Caddy 이미지에는 비표준 rate-limit 플러그인을 추가하지
않습니다.

## 배포 전 검증

### 영속 인증 선행 조건

1. 운영 DB 백업·복원 가능 여부를 먼저 확인하고 007까지의 적용 상태를 점검한다.
   `007_persistent_auth_sessions.sql`은 `sessions.refresh_expires_at`을 nullable로 만들고
   암호화 갱신 응답용 `refresh_receipts`를 추가한다. 기존 유한 세션의 만료 시각은 바꾸지 않는다.
2. 암호화 키는 신뢰할 수 있는 난수 생성기로 32-byte를 생성하여 base64로 저장한다.
   키 원문·token·인증 응답을 로그나 공유 터미널 출력에 남기지 않는다. 키 미설정 시
   영속 로그인/갱신은 `SESSION_PERSISTENCE_UNAVAILABLE` 503이며 기존 API는 유지된다.
   임의 재생성·인스턴스별 다른 키는 미완료 갱신 응답 복구를 깨뜨린다.
3. 웹 클라이언트와 GitHub Pages 배포는 폐기했다. same-site HTTPS 배치, Authorized JavaScript
   origins, `SameSite=Lax` 쿠키 조건은 남아 있는 `/v1/auth/web/*` 경로에만 해당하며 Android 앱
   배포 조건이 아니다.
4. 서버 설정·마이그레이션·HTTPS 구성을 먼저 반영한 뒤 해당 주소로 클라이언트를 빌드한다.
   - 챕터3 후반(ID26–30) 클라이언트는 먼저013 마이그레이션과 경로 저장 호환 세대5를 처리하는 서버가 필요하다. 기존012는 그대로 두며 [확장 스테이지 적용 기준](../server/db/migrations/README.md#확장-스테이지)을 따른다.
   영속 인증 배포가 준비되지 않은 서버에 새 클라이언트만 배포하지 않는다.

운영 적용을 승인한 뒤 사용할 마이그레이션 명령은 다음과 같다. 이 문서 갱신 작업에서는
실행하지 않았다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  run --rm migrate migrate
```

NULL 만료 세션이 남아 있으면 007 down은 거부된다. 되돌리기 위해 세션을 자동 삭제하거나
임의 만료 시각을 넣지 않는다. 구버전 클라이언트·서버 롤백과 DB down은 별도 판단한다.

### 구성 검사

저장소 루트에서 병합된 Compose 설정과 Caddyfile을 검증합니다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  config --quiet

docker run --rm \
  -v "$PWD/deploy/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
  caddy:2.11.4-alpine \
  caddy fmt --diff /etc/caddy/Caddyfile

docker run --rm \
  --env-file .env.production \
  -v "$PWD/deploy/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
  caddy:2.11.4-alpine \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

`caddy validate`는 설정을 확인하지만 실제 공개 인증서 발급까지 확인하지는
않습니다. 최초 인증서 발급은 DNS와 포트 포워딩을 적용한 뒤 Caddy를 실행할 때
진행됩니다. DuckDNS 갱신기와 Caddy는 함께 시작하며, 최초 갱신보다 인증서 요청이
먼저 실행되면 Caddy가 자동으로 재시도합니다. 갱신기 healthcheck는 장애 감시용이며
일시적인 DuckDNS 장애 때문에 기존 인증서를 가진 Caddy의 재시작을 막지는 않습니다.

## 시작과 상태 확인

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  up -d --build

docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  ps

docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  logs --tail=20 duckdns

dig +short "<API_HOST>"
curl --fail "https://<API_HOST>/health/live"
curl --fail "https://<API_HOST>/health/ready"
```

`duckdns`가 `unhealthy`라면 token과 label이 일치하는지 먼저 확인합니다. 갱신 로그는
token이나 전체 요청 URL을 출력하지 않습니다. `dig` 결과는 ipTIME 상태 화면의 WAN
공인 IPv4와 같아야 합니다. WAN 주소가 사설·공유 주소라면 DuckDNS가 정상이어도
포트 포워딩으로 외부 접근할 수 없습니다.

Caddy access log는 JSON으로 표준 출력에 기록합니다. 요청 본문은 기록하지 않으며
Authorization, Cookie 같은 민감 헤더는 Caddy 기본 정책으로 가려집니다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  logs -f duckdns caddy api
```

DuckDNS token을 재발급했다면 `.secrets/duckdns_token`을 교체한 뒤 갱신기만 다시
생성합니다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  up -d --force-recreate duckdns
```

## 설정 반영과 중지

Caddyfile만 변경했으면 검증 후 무중단으로 다시 읽힙니다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

전체 서비스를 중지할 때도 두 Compose 파일을 함께 지정합니다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  down
```

`down -v`는 PostgreSQL 데이터와 Caddy 인증서 상태를 함께 삭제하므로 데이터
초기화가 명확히 필요한 경우가 아니면 사용하지 않습니다. `/data`와 `/config`를
담는 Caddy named volume은 컨테이너 재생성 후에도 인증서와 ACME 계정 상태를
보존합니다. DuckDNS 갱신기의 상태 파일은 임시 파일이므로 컨테이너 재생성 직후
한 번 다시 갱신하고 healthcheck를 통과합니다.

## API 반영과 DB 백업

API 이미지·DB 마이그레이션 반영은 [반영 스크립트](../scripts/server_release.py)로 수행한다. 배포마다 일회성 스크립트를 새로 만들지 않는다. 산출물·동결 백업·compose는 `~/Library/Application Support/RuneNexus/operations/server-<sha8>-<UTC>/`에 남는다.

1. `python3 scripts/server_release.py prepare <commit>`: 정확한 소스로 API·migrate 이미지를 빌드하고 `make test`·`vet`·`integration-test`를 실행한다. 실행 중인 API의 compose에서 이미지만 바꾼 반영본과 직전본을 만들고, 운영 DB 사본을 격리 DB에 복원해 마이그레이션 후 기존 행·열 보존을 확인한다. 새 이미지를 그 사본으로 격리 기동해 공개 계약(상태 200·보호 경로 401)을 확인한다. 운영 컨테이너는 바꾸지 않는다.
2. `python3 scripts/server_release.py rehearse-deploy <작업 폴더>`: 운영 DB 사본과 현 API compose를 격리 이름·네트워크로 바꾼 스택에서 아래 deploy 전 과정을 실행한다.
3. `python3 scripts/server_release.py deploy <작업 폴더> --confirm`: prepare 이후 API·스키마·이미지가 그대로인지 확인한 뒤 API를 정지하고, 동결 백업을 격리 복원으로 확인한 다음 운영 마이그레이션·새 API 기동·로컬/공개 HTTP·실행 설정 보존을 확인한다.

마이그레이션 전에 실패하면 직전 API compose로 다시 띄운다. 마이그레이션 뒤 실패하면 DB를 되돌리지 않고 동결 백업과 직전 compose 경로를 안내하며, 직전 API는 새 스키마와의 호환을 확인한 뒤에만 띄운다. 기존 행을 의도적으로 바꾸는 마이그레이션은 `--allow-changed-table <table>`로 명시한다. 배포별 기능 검사(세대·지급 계약)는 Go 통합 테스트가 맡는다.

운영 DB는 매일 04:17에 [백업 스크립트](../scripts/server_backup.py)가 외장 볼륨 `/Volumes/KIOXIA_MAC/RuneNexus/db-backups/`에 `pg_dump -Fc`로 백업한다. 최근 14개와 최근 8주의 주별 최신본을 남기고 `backup-log.jsonl`에 기록한다. 볼륨이 빠져 있으면 백업하지 않고 실패한다. 실행 기록은 `~/Library/Logs/RuneNexus/db-backup.log`에 있다.

- 등록·갱신: `python3 scripts/server_backup.py install-launchd`. launchd는 `~/Documents`의 스크립트와 외장 볼륨을 직접 읽지 못하므로(macOS 개인정보 보호) 스크립트 사본을 `~/Library/Application Support/RuneNexus/bin/`에 두고, 외장 볼륨 파일은 Docker 보조 컨테이너로만 다룬다. 스크립트를 바꾸면 다시 등록한다.
- 복원 확인: `python3 scripts/server_backup.py verify [백업 이름]`이 백업을 일회용 격리 DB에 복원해 스키마·테이블·행 수를 보고한다. 운영 DB에는 접속하지 않는다.
- 실제 복구는 API를 멈춘 뒤 운영 DB에 복원하는 파괴적 작업이므로 스크립트로 자동화하지 않고 사용자 승인 후 수행한다.

## 클라이언트 전환

API HTTPS 검증이 끝난 뒤 GitHub Actions Variables의 `RUNE_NEXUS_API_BASE_URL`을
최종 API 주소로 변경합니다. Godot 팩 빌드는 `RUNE_NEXUS_API_BASE_URL`, `GOOGLE_WEB_CLIENT_ID`를
`app_config.json`에 담습니다(`scripts/prepare_godot_project.py`). `GOOGLE_WEB_CLIENT_ID`는
**Web OAuth client ID(server client ID)**입니다.
별도로 Google Cloud의 Android OAuth client에 실제 applicationId와 배포 서명의 SHA 인증서
지문을 등록해야 합니다. applicationId는 기존 `com.example.rune_nexus`를 유지하며 release 서명은
[APK 배포](android_apk_distribution.md)의 배포 서명 환경변수를 사용합니다. Credential Manager Google
로그인은 구현됐지만 PGS v2·Play Games Player ID 연동과는 별개입니다.

### 실제 환경 확인 체크리스트 (미완료)

- [ ] Android 앱 종료/재시작 후 같은 account 저장 복원
- [ ] Android 실제 Google 계정 선택, Keystore 저장과 명시적 로그아웃 뒤 재진입 확인
- [ ] 응답 유실·장기 종료·API 재시작 후 같은 요청 복구, 만료 access 재갱신 및 로그아웃·옛 응답 거부 확인
- [ ] 일시적인 네트워크/저장소 실패에서 guest 진입 없이 재시도하고 원본 저장 보존
- [ ] 로그아웃·계정 정지 후 자동 재연결 차단과 저장 슬롯 전환 확인
- [ ] 카카오 이전 링크의 대상 account 확인 후에만 consume 발생
- [ ] 실제 다중 기기 writer 교체·저장·경제 명령 E2E 확인

2026-09-05 당시 로컬 자동 테스트와 Web/APK 빌드는 통과했지만 실제 Google 로그인·실기기
검증을 대체하지 않습니다. 현재 정식 Godot 앱에는 게스트 플레이가 없습니다([런·성장 명령](../godot/app/run_commands_README.md)).
