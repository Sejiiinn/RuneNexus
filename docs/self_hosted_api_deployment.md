# 자체 운영 API 배포

Rune Nexus 운영 API는 기존 개발용 Compose에 `compose.production.yaml`을 겹쳐
실행합니다. Caddy만 외부 80/443 포트를 받고, Go API와 PostgreSQL은 Docker
내부망 또는 호스트 loopback에서만 접근할 수 있습니다.

이 구성은 HTTPS 진입점과 컨테이너 경계를 준비하는 운영 배포 골격입니다. DB 권한
분리와 백업·복원 자동화가 완료되기 전에는 정식 출시 구성으로 보지 않습니다.

```text
GitHub Pages / 모바일 앱
          | HTTPS :443
          v
        Caddy
          | HTTP, Compose 내부망
          v
      Go API :8080
          |
          v
      PostgreSQL :5432
```

## 외부 공개 전 조건

- ipTIME WAN 주소가 실제 공인 IP인지 확인한다. 통신사 CGNAT 환경이면 공유기 포트
  포워딩만으로 외부 접속할 수 없다.
- 공개 인증서 발급이 가능한 전용 호스트명의 A/AAAA 레코드를 공인 IP로 연결한다.
  `API_HOST`에는 scheme과 경로를 제외한 호스트명만 넣는다.
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

실제 값은 커밋하지 않는 `.env.production`에 기록합니다.

```bash
cp .env.production.example .env.production
chmod 600 .env.production
```

필수 항목은 다음과 같습니다.

- `API_HOST`: `api.example.com`과 같은 공개 API 호스트명
- `ACME_EMAIL`: 인증서 계정 알림을 받을 이메일
- `GOOGLE_WEB_CLIENT_ID`: Google Identity Services Web OAuth Client ID
- `CORS_ALLOWED_ORIGINS`: GitHub Pages를 포함한 정확한 허용 origin 목록

다음 요청 제한 조정값은 생략하면 예시 파일에 적힌 기본값을 사용합니다.

- `AUTH_RATE_LIMIT_WINDOW`: 인증 요청 token bucket이 완전히 충전되는 기간
- `GOOGLE_AUTH_RATE_LIMIT`: 기간 내 허용할 Google 로그인 요청 수
- `REFRESH_AUTH_RATE_LIMIT`: 기간 내 허용할 토큰 갱신 요청 수
- `AUTH_RATE_LIMIT_MAX_CLIENTS`: endpoint마다 메모리에 보관할 최대 클라이언트 수

`MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION`은 writer 획득과 저장 PUT에 허용할 최소
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
진행됩니다.

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

curl --fail "https://<API_HOST>/health/live"
curl --fail "https://<API_HOST>/health/ready"
```

Caddy access log는 JSON으로 표준 출력에 기록합니다. 요청 본문은 기록하지 않으며
Authorization, Cookie 같은 민감 헤더는 Caddy 기본 정책으로 가려집니다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  logs -f caddy api
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
보존합니다.

## 클라이언트 전환

외부 HTTPS 검증이 끝난 뒤 GitHub Actions Variables의
`RUNE_NEXUS_API_BASE_URL`을 `https://<API_HOST>`로 변경합니다. Google Cloud의
Authorized JavaScript origins에는 GitHub Pages origin을 유지하고,
`CORS_ALLOWED_ORIGINS`에도 같은 origin을 등록합니다.
