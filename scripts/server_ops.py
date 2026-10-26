"""운영 서버 DB 백업·격리 복원·마이그레이션의 공용 docker 단계.

비밀값과 운영 compose는 저장소 밖(운영 작업 폴더)에 두고 여기서는 경로만 다룬다.
"""
from __future__ import annotations

import contextlib
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
import uuid

OPERATIONS = Path.home() / "Library/Application Support/RuneNexus/operations"
DB_CONTAINER = "rune-nexus-postgres"
API_CONTAINER = "rune-nexus-api-1"
POSTGRES_IMAGE = "postgres:18"
# pg_restore가 비우는 search_path를 과거 CHECK 보조 함수가 쓰는 public으로 복원
SEARCH_PATH_RESET = b"SELECT pg_catalog.set_config('search_path', '', false);"
SEARCH_PATH_PUBLIC = b"SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', false);"


def private_file(path: Path):
    """소유자만 읽는 파일로 연다(백업에는 계정·세션 데이터가 들어 있다)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(descriptor, 0o600)  # 이미 있던 파일의 권한도 좁힌다
    return os.fdopen(descriptor, "wb")


def write_private_json(path: Path, value):
    with private_file(path) as stream:
        stream.write((json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode())


def run(args, log: Path | None = None, **options):
    if log is None:
        return subprocess.run(args, check=True, capture_output=True, **options)
    with log.open("ab") as stream:
        return subprocess.run(args, check=True, stdout=stream, stderr=stream, **options)


def inspect(name):
    return json.loads(subprocess.check_output(["docker", "inspect", name]))[0]


def environment(container):
    return dict(item.split("=", 1) for item in container["Config"]["Env"])


def credentials(db=DB_CONTAINER):
    env = environment(inspect(db))
    return env["POSTGRES_USER"], env["POSTGRES_DB"]


def query(db, user, name, sql):
    return subprocess.check_output(
        ["docker", "exec", db, "psql", "-U", user, "-d", name, "-tA", "-v", "ON_ERROR_STOP=1", "-c", sql],
        text=True).strip()


def schema_version(db, user, name):
    return int(query(db, user, name, "SELECT version FROM schema_version"))


def columns(db, user, name):
    rows = query(db, user, name, "SELECT COALESCE(json_object_agg(table_name, cols), '{}') FROM ("
                 "SELECT table_name, json_agg(column_name ORDER BY column_name) cols "
                 "FROM information_schema.columns WHERE table_schema='public' GROUP BY table_name) t")
    return {table: set(names) for table, names in json.loads(rows).items()}


def fingerprint(db, user, name, only=None):
    """테이블별 행 수와 전체 행 해시. only가 있으면 그 테이블·열만 비교한다.

    마이그레이션이 열을 추가해도 기존 열 값이 보존됐는지 확인하기 위한 것이다.
    """
    present = columns(db, user, name)
    result = {}
    for table in sorted(only or present):
        if table == "schema_version" or table not in present:
            continue
        if not table.replace("_", "").isalnum():
            raise ValueError(f"Unexpected table name: {table}")
        extra = sorted(present[table] - only[table]) if only else []
        row = "to_jsonb(t)" + (" - ARRAY[" + ",".join(f"'{c}'" for c in extra) + "]::text[]" if extra else "")
        result[table] = json.loads(query(db, user, name,
            f"SELECT json_build_object('count', count(*), 'hash', "
            f"md5(COALESCE(string_agg(({row})::text, '|' ORDER BY ({row})::text), ''))) FROM {table} t"))
    return result


def dump(db, user, name, output: Path):
    """pg_dump -Fc 백업을 만들고 목록을 읽어 손상 여부를 확인한 뒤 게시한다.

    pg_dump는 한 트랜잭션 스냅샷이라 API가 쓰는 중에도 일관된 백업이 된다.
    """
    partial = output.with_name("." + output.name + ".partial")
    try:
        with private_file(partial) as stream:
            subprocess.run(["docker", "exec", db, "pg_dump", "-U", user, "-d", name, "-Fc"],
                           stdout=stream, check=True)
        with partial.open("rb") as stream:
            listing = subprocess.run(["docker", "exec", "-i", db, "pg_restore", "--list"],
                                     stdin=stream, capture_output=True, check=True, text=True).stdout
        if "TABLE public schema_version" not in listing:
            raise RuntimeError("Backup listing has no schema_version table")
        os.replace(partial, output)
    finally:
        partial.unlink(missing_ok=True)
    return sha256(output)


def sha256(path: Path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def wait_ready(db, user, name, seconds=60):
    for _ in range(seconds):
        if subprocess.run(["docker", "exec", db, "pg_isready", "-q", "-h", "127.0.0.1", "-U", user, "-d", name],
                          capture_output=True).returncode == 0:
            return
        time.sleep(1)
    raise RuntimeError(f"{db} is not ready")


@contextlib.contextmanager
def isolated_database(user, name, workdir: Path, label):
    """tmpfs에만 데이터를 두는 일회용 PostgreSQL. 운영 컨테이너·볼륨·비밀은 쓰지 않는다."""
    ident = f"rune-nexus-{label}-{uuid.uuid4().hex[:8]}"
    network, db = ident + "-net", ident + "-db"
    secret = workdir / f".{ident}.password"
    with private_file(secret) as stream:
        stream.write(secrets.token_hex(24).encode())
    try:
        run(["docker", "network", "create", network])
        run(["docker", "run", "-d", "--name", db, "--network", network, "--tmpfs", "/var/lib/postgresql",
             "-e", "POSTGRES_USER=" + user, "-e", "POSTGRES_DB=" + name,
             "-e", "POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password",
             "-v", f"{secret}:/run/secrets/postgres_password:ro", POSTGRES_IMAGE])
        wait_ready(db, user, name)
        yield {"db": db, "network": network, "secret": secret}
    finally:
        subprocess.run(["docker", "rm", "-f", db], capture_output=True)
        subprocess.run(["docker", "network", "rm", network], capture_output=True)
        secret.unlink(missing_ok=True)


def restore(backup, db, user, name):
    """backup은 경로 또는 이미 연 바이너리 스트림(외장 볼륨을 Docker로 읽는 경우)."""
    with (backup.open("rb") if isinstance(backup, Path) else contextlib.nullcontext(backup)) as stream:
        sql = subprocess.run(["docker", "exec", "-i", db, "pg_restore", "--no-owner", "--file=-"],
                             stdin=stream, capture_output=True, check=True).stdout
    if sql.count(SEARCH_PATH_RESET) != 1:
        raise RuntimeError("Unexpected pg_restore search_path header")
    run(["docker", "exec", "-i", db, "psql", "-U", user, "-d", name, "-v", "ON_ERROR_STOP=1"],
        input=sql.replace(SEARCH_PATH_RESET, SEARCH_PATH_PUBLIC))


def migrate(image, migrations: Path, network, host, user, name, secret: Path, log: Path | None = None):
    run(["docker", "run", "--rm", "--network", network, "-e", "PGHOST=" + host, "-e", "PGPORT=5432",
         "-e", "PGDATABASE=" + name, "-e", "PGUSER=" + user,
         "-e", "PGPASSWORD_FILE=/run/secrets/postgres_password", "-e", "PGSSLMODE=disable",
         "-e", "TERN_MIGRATIONS=/migrations", "-v", f"{migrations}:/migrations:ro",
         "-v", f"{secret}:/run/secrets/postgres_password:ro", image, "migrate"], log)


def latest_migration(migrations: Path):
    return max(int(path.name.split("_", 1)[0]) for path in migrations.glob("[0-9][0-9][0-9]_*.sql"))
