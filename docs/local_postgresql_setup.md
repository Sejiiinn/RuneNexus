# 로컬 PostgreSQL 실행

Rune Nexus 서버 개발용 PostgreSQL은 Docker Compose로 실행합니다. 데이터베이스 포트는 Mac 내부의 `127.0.0.1`에만 노출되며, 데이터는 Docker named volume에 보존됩니다.

## 최초 실행

Docker Desktop을 설치하고 실행한 뒤 저장소 루트에서 비밀번호 파일을 한 번 생성합니다.

```bash
mkdir -p .secrets
openssl rand -base64 48 > .secrets/postgres_password
chmod 600 .secrets/postgres_password
docker compose up -d db
```

`.secrets/`는 Git에서 제외됩니다. 생성한 비밀번호 파일은 별도로 안전하게 보관하고 저장소에 커밋하지 않습니다.

## 상태와 접속 확인

```bash
docker compose ps
docker compose exec db psql -U rune_nexus_app -d rune_nexus
```

호스트에서 접속하는 서버 프로세스의 기본 연결 정보는 다음과 같습니다.

```text
host=127.0.0.1
port=5432
database=rune_nexus
user=rune_nexus_app
password=<.secrets/postgres_password 파일 내용>
```

추후 API 서버도 같은 Compose 네트워크에서 실행할 경우에는 호스트를 `db`, 포트를 `5432`로 사용합니다.

## 중지와 재실행

```bash
docker compose stop db
docker compose start db
```

컨테이너만 내리고 데이터는 유지하려면 다음 명령을 사용합니다.

```bash
docker compose down
```

`docker compose down -v`는 PostgreSQL 데이터 볼륨까지 삭제하므로 데이터 초기화가 명확히 필요한 경우에만 사용합니다.
