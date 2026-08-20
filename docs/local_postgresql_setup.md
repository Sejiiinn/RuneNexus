# 로컬 PostgreSQL 실행

Rune Nexus 서버 개발용 PostgreSQL은 Docker Compose로 실행합니다. 데이터베이스 포트는 Mac 내부의 `127.0.0.1`에만 노출되며, 데이터는 Docker named volume에 보존됩니다.

계정, 인증, 온라인 저장과 Go 서버의 전체 구조는 `docs/backend_architecture.md`를 기준으로 합니다.
외부 HTTPS 공개 절차는 `docs/self_hosted_api_deployment.md`를 따릅니다.

## 최초 실행

Docker Desktop을 설치하고 실행한 뒤 저장소 루트에서 비밀번호 파일을 한 번 생성합니다.

```bash
mkdir -p .secrets
openssl rand -base64 48 > .secrets/postgres_password
chmod 600 .secrets/postgres_password
docker compose up -d --build api
```

`.secrets/`는 Git에서 제외됩니다. 생성한 비밀번호 파일은 별도로 안전하게 보관하고 저장소에 커밋하지 않습니다.

위 명령은 PostgreSQL을 시작하고, `tern` 마이그레이션을 적용한 뒤 Go API 서버를 시작합니다. 데이터베이스만 먼저 실행하려면 `docker compose up -d db`를 사용합니다.

Google 인증은 실제 OAuth Client ID 없이도 로컬 서버가 실행되도록 기본적으로
비활성화되어 있습니다. 웹 로그인을 시험할 때만 Google Cloud에서 발급한 Web OAuth
Client ID와 정확한 웹 origin을 주입합니다.

```bash
GOOGLE_AUTH_ENABLED=true \
GOOGLE_WEB_CLIENT_ID='<web-oauth-client-id>' \
CORS_ALLOWED_ORIGINS='http://127.0.0.1:53000,https://sejiiinn.github.io' \
docker compose up -d --build api
```

GitHub Pages 주소의 `/RuneNexus/`는 경로이므로 CORS origin과 Google OAuth의
Authorized JavaScript origins에는 `https://sejiiinn.github.io`까지만 등록합니다.
Google ID token 원문은 서버 로그와 DB에 저장하지 않으며, 서버가 발급하는 opaque
세션 토큰도 DB에는 SHA-256 해시만 저장합니다.

Flutter Web 개발 서버도 같은 값으로 빌드합니다.

```bash
flutter run -d web-server --web-port 53000 \
  --dart-define=GOOGLE_WEB_CLIENT_ID='<web-oauth-client-id>' \
  --dart-define=RUNE_NEXUS_API_BASE_URL='http://127.0.0.1:8080'
```

GitHub Pages 배포에는 저장소의 Actions Variables에 `GOOGLE_WEB_CLIENT_ID`와
`RUNE_NEXUS_API_BASE_URL`을 등록합니다. API 주소는 실제 배포 환경에서 HTTPS여야
하며, 둘 중 하나라도 없거나 잘못되면 계정 화면의 Google 연결 버튼은 표시하지
않습니다.

## 상태와 접속 확인

```bash
docker compose ps
docker compose exec db psql -U rune_nexus_app -d rune_nexus
curl --fail http://127.0.0.1:8080/health/live
curl --fail http://127.0.0.1:8080/health/ready
```

호스트에서 접속하는 서버 프로세스의 기본 연결 정보는 다음과 같습니다.

```text
host=127.0.0.1
port=5432
database=rune_nexus
user=rune_nexus_app
password=<.secrets/postgres_password 파일 내용>
```

API 서버는 같은 Compose 네트워크에서 호스트 `db`, 포트 `5432`로 접속합니다. 호스트에서 Go 서버를 직접 실행할 때만 위의 `127.0.0.1` 접속 정보를 사용합니다.

## Go 서버 검증

호스트에 Go, sqlc, tern을 별도로 설치하지 않고 고정된 Docker 이미지로 검증합니다.

```bash
make -C server format
make -C server test
make -C server vet
make -C server sqlc-version
make -C server tern-version
docker compose config --quiet
```

현재 고정 버전은 Go 1.26.5, sqlc 1.31.1, tern 2.4.1입니다. `go.mod`에는 PostgreSQL
드라이버 `pgx/v5` 5.10.0과 Google ID token 검증 모듈
`google.golang.org/api` 0.290.0이 고정되어 있습니다.

## 중지와 재실행

```bash
docker compose stop api db
docker compose start db
docker compose run --rm migrate
docker compose start api
```

컨테이너만 내리고 데이터는 유지하려면 다음 명령을 사용합니다.

```bash
docker compose down
```

`docker compose down -v`는 PostgreSQL 데이터 볼륨까지 삭제하므로 데이터 초기화가 명확히 필요한 경우에만 사용합니다.
