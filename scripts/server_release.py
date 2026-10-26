#!/usr/bin/env python3
"""서버 API·DB 운영 반영 절차. 배포마다 일회성 스크립트를 새로 만들지 않도록 고정한다.

prepare <commit>       정확한 소스로 이미지 빌드·Go 검사, 운영 DB 사본에 마이그레이션
                       리허설, 새 이미지 격리 기동 확인. 운영 컨테이너는 바꾸지 않는다.
rehearse-deploy <dir>  운영 DB 사본·현 API 설정으로 꾸린 격리 스택에 deploy 전 과정을 실행.
deploy <dir> --confirm API 정지 → 동결 백업·복원 확인 → 운영 마이그레이션 → 새 API 기동·HTTP 확인.

산출물은 저장소 밖 운영 작업 폴더에 둔다(비밀이 든 파일은 *.private.*, 0600).
마이그레이션 적용 뒤에는 구 API/DB로 자동 복귀하지 않는다(새 쓰기를 버릴 수 없다).
"""
from __future__ import annotations

import argparse
import copy
from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent))
import server_ops  # noqa: E402
from server_ops import inspect, environment, run, write_private_json  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OTHERS = ("rune-nexus-caddy-1", "rune-nexus-duckdns-1")
SOURCE_PATHS = ("server", "godot/content/source", "test/fixtures")
SMOKE = [("GET", "/health/live", 200), ("GET", "/health/ready", 200), ("GET", "/v1/save", 401),
         ("POST", "/v1/save/writer", 401), ("GET", "/v1/economy", 401), ("POST", "/v1/economy/gems/offer", 401),
         ("POST", "/v1/economy/runs/start", 401), ("POST", "/v1/economy/runs/close", 401), ("GET", "/v1/mailbox", 401)]
CONFIG_KEYS = ("User", "WorkingDir", "Entrypoint", "Cmd", "Healthcheck", "StopTimeout")
HOST_KEYS = ("Init", "LogConfig", "RestartPolicy", "ReadonlyRootfs", "Privileged", "CapAdd", "CapDrop",
             "SecurityOpt", "Memory", "NanoCpus")


def stamp():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def smoke(base):
    """인증 없이 확인 가능한 공개 계약: 상태 확인 200, 보호 경로 401."""
    checks = []
    for method, path, expected in SMOKE:
        request = urllib.request.Request(base + path, method=method, data=b"{}" if method == "POST" else None,
                                         headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                status = response.status
        except urllib.error.HTTPError as error:
            status = error.code
        checks.append({"base": base, "method": method, "path": path, "status": status, "expected": expected})
        if status != expected:
            raise RuntimeError(f"{method} {base}{path}: {status} != {expected}")
    return checks


def wait_healthy(container, seconds=90):
    for _ in range(seconds):
        state = inspect(container)["State"]
        if state["Status"] != "running":
            raise RuntimeError(f"{container} is {state['Status']}")
        if state.get("Health", {}).get("Status") == "healthy":
            return
        time.sleep(1)
    raise RuntimeError(f"{container} did not become healthy")


def host_url(container):
    return "http://127.0.0.1:" + inspect(container)["NetworkSettings"]["Ports"]["8080/tcp"][0]["HostPort"]


def runtime_signature(container):
    """prepare 이후 바뀌면 준비한 compose가 운영 설정을 되돌리게 되는 실행 설정."""
    return {"image": container["Image"], "env": environment(container),
            "config": {key: container["Config"].get(key) for key in CONFIG_KEYS},
            "host": {key: container["HostConfig"].get(key) for key in (*HOST_KEYS, "PortBindings")},
            "mounts": sorted((m.get("Type"), m.get("Source"), m["Destination"], m.get("RW")) for m in container["Mounts"]),
            "networks": sorted(container["NetworkSettings"]["Networks"])}


def restore_previous(target: Target):
    """스키마가 그대로일 때 직전 API compose로 되돌리고 실제로 healthy인지 확인한다."""
    restarted = subprocess.run(["docker", "compose", "-f", str(target.rollback), "up", "-d", "--no-deps",
                                "--no-build", "api"], capture_output=True, text=True)
    try:
        if restarted.returncode:
            raise RuntimeError(restarted.stderr.strip()[-2000:])
        wait_healthy(target.api)
    except Exception as error:  # noqa: BLE001 - 복귀 실패는 원래 오류와 함께 알린다
        print(f"ROLLBACK FAILED: the API may be down ({error}). Start it manually: docker compose -f "
              f"'{target.rollback}' up -d --no-deps --no-build api", file=sys.stderr)
        return
    print("FAILED before migration; previous API restarted and healthy", file=sys.stderr)


def compare_tables(before, after, allowed):
    changed = sorted(table for table in before if before[table] != after.get(table) and table not in allowed)
    if changed:
        raise RuntimeError(f"Existing rows changed by migration: {changed} (allow with --allow-changed-table)")


def public_url():
    for line in (ROOT / ".env.production").read_text().splitlines():
        if line.startswith("API_HOST="):
            return "https://" + line.split("=", 1)[1].strip()
    raise SystemExit("API_HOST missing in .env.production")


# ---------------------------------------------------------------- prepare

def prepare(commit, allowed):
    sha = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "--verify", commit + "^{commit}"],
                                  text=True).strip()
    short = sha[:8]
    work = server_ops.OPERATIONS / f"server-{short}-{stamp()}"
    work.mkdir(parents=True, mode=0o700)
    log = work / "prepare.log"
    print(f"Operations directory: {work}", flush=True)

    source = work / "source"
    source.mkdir()
    archive = subprocess.Popen(["git", "-C", str(ROOT), "archive", "--format=tar", sha, *SOURCE_PATHS],
                               stdout=subprocess.PIPE)
    run(["tar", "-x", "-C", str(source)], log, stdin=archive.stdout)
    archive.stdout.close()
    if archive.wait():
        raise RuntimeError("git archive failed")

    api_image, migrate_image = f"rune-nexus-api:{short}", f"rune-nexus-migrate:{short}"
    run(["docker", "build", "--label", f"org.opencontainers.image.revision={sha}", "-t", api_image,
         str(source / "server")], log)
    run(["docker", "build", "-f", str(source / "server/Dockerfile.migrate"), "-t", migrate_image,
         str(source / "server")], log)
    print("IMAGES_BUILT", flush=True)
    for target in ("test", "vet", "integration-test"):
        run(["make", target], work / f"{target}.log", cwd=source / "server")
        print(f"{target.upper()}_PASS", flush=True)

    for role, name in [("api", server_ops.API_CONTAINER), ("postgres", server_ops.DB_CONTAINER),
                       *[(name.split("-")[2], name) for name in OTHERS]]:
        write_private_json(work / f"before-{role}.inspect.private.json", inspect(name))
    current = Path(inspect(server_ops.API_CONTAINER)["Config"]["Labels"]["com.docker.compose.project.config_files"])
    if current.suffix != ".json":
        raise SystemExit(f"Running API compose is not a resolved JSON file: {current}")
    rollback = json.loads(current.read_text())
    release = copy.deepcopy(rollback)
    release["services"]["api"]["image"] = api_image
    write_private_json(work / "api-rollback.compose.private.json", rollback)
    write_private_json(work / "api-release.compose.private.json", release)

    user, name = server_ops.credentials()
    current_schema = server_ops.schema_version(server_ops.DB_CONTAINER, user, name)
    expected_schema = server_ops.latest_migration(source / "server/db/migrations")
    if expected_schema < current_schema:
        raise SystemExit(f"Release migrations stop at {expected_schema}; production is {current_schema}")
    backup = work / f"preflight-schema{current_schema}.dump"
    server_ops.dump(server_ops.DB_CONTAINER, user, name, backup)
    with server_ops.isolated_database(user, name, work, "release-preflight") as isolated:
        db = isolated["db"]
        server_ops.restore(backup, db, user, name)
        columns = server_ops.columns(db, user, name)
        before = server_ops.fingerprint(db, user, name)
        server_ops.migrate(migrate_image, source / "server/db/migrations", isolated["network"], db, user, name,
                           isolated["secret"], log)
        if server_ops.schema_version(db, user, name) != expected_schema:
            raise RuntimeError("Rehearsed migration did not reach the expected schema")
        compare_tables(before, server_ops.fingerprint(db, user, name, columns), allowed)
        print(f"PREFLIGHT_MIGRATION_PASS schema {current_schema}->{expected_schema} tables={len(before)}", flush=True)
        checks = isolated_api_smoke(work, release, api_image, isolated)
        print(f"ISOLATED_API_PASS checks={len(checks)}", flush=True)

    write_private_json(work / "metadata.json", {
        "target_sha": sha, "api_image": api_image, "migrate_image": migrate_image,
        "api_image_id": inspect(api_image)["Id"], "current_schema": current_schema,
        "expected_schema": expected_schema, "rollback_source": str(current), "allowed_changed_tables": sorted(allowed),
        "preflight_backup": backup.name, "preflight_backup_sha256": server_ops.sha256(backup),
        "isolated_smoke": checks, "prepared_at": stamp()})
    print(f"PREPARED {sha}\nNext: python3 scripts/server_release.py rehearse-deploy '{work}'\n"
          f"Then: python3 scripts/server_release.py deploy '{work}' --confirm")


def isolated_api_smoke(work, release, image, isolated):
    """새 이미지를 운영 설정·마이그레이션된 DB 사본으로 띄워 공개 계약을 확인한다."""
    env = dict(release["services"]["api"]["environment"])
    env.update({"DATABASE_HOST": isolated["db"], "AUTH_SESSION_RECEIPT_KEY": "", "TRUST_PROXY_HEADERS": "false"})
    env_file = work / "isolated-api.env.private"
    with server_ops.private_file(env_file) as stream:
        stream.write("\n".join(f"{key}={value}" for key, value in env.items()).encode())
    container = isolated["db"].removesuffix("-db") + "-api"
    try:
        run(["docker", "run", "-d", "--name", container, "--network", isolated["network"], "-p", "127.0.0.1::8080",
             "--env-file", str(env_file), "-v", f"{isolated['secret']}:{env['DATABASE_PASSWORD_FILE']}:ro", image])
        base = host_url(container)
        for _ in range(60):
            try:
                with urllib.request.urlopen(base + "/health/ready", timeout=2):
                    break
            except OSError:
                time.sleep(1)
        return smoke(base)
    finally:
        subprocess.run(["docker", "rm", "-f", container], capture_output=True)
        env_file.unlink(missing_ok=True)


# ---------------------------------------------------------------- deploy

@dataclass
class Target:
    api: str
    db: str
    others: tuple
    release: Path
    rollback: Path
    public_url: str | None
    snapshots: Path


def deploy(work: Path, target: Target, meta, allowed, label="production"):
    log = work / f"{label}-deploy.log"
    before = json.loads((target.snapshots / "before-api.inspect.private.json").read_text())
    if runtime_signature(inspect(target.api)) != runtime_signature(before):
        raise SystemExit("API container configuration changed since prepare; run prepare again")
    image = inspect(meta["api_image"])
    if image["Id"] != meta["api_image_id"] or \
            image["Config"]["Labels"]["org.opencontainers.image.revision"] != meta["target_sha"]:
        raise SystemExit("Release image does not match prepare")
    user, name = server_ops.credentials(target.db)
    schema = server_ops.schema_version(target.db, user, name)
    if schema != meta["current_schema"]:
        raise SystemExit(f"Schema moved since prepare: {schema}")
    run(["docker", "compose", "-f", str(target.release), "config", "--quiet"], log)
    env = environment(before)
    secret = next(m["Source"] for m in before["Mounts"] if m["Destination"] == env["DATABASE_PASSWORD_FILE"])
    network = next(iter(before["NetworkSettings"]["Networks"]))

    started = stamp()
    run(["docker", "stop", "--time", "15", target.api], log)
    migrated = False
    try:
        if inspect(target.api)["State"]["Status"] != "exited":
            raise RuntimeError("API did not stop")
        clients = server_ops.query(target.db, user, name,
            "SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND usename=current_user "
            "AND pid<>pg_backend_pid() AND backend_type='client backend'")
        if clients != "0":
            raise RuntimeError(f"{clients} database clients still connected")
        print(f"{label.upper()}_API_STOPPED", flush=True)
        frozen = work / f"{label}-frozen-schema{schema}.dump"
        server_ops.dump(target.db, user, name, frozen)
        columns = server_ops.columns(target.db, user, name)
        fingerprint = server_ops.fingerprint(target.db, user, name)
        with server_ops.isolated_database(user, name, work, "release-frozen") as isolated:
            server_ops.restore(frozen, isolated["db"], user, name)
            if server_ops.fingerprint(isolated["db"], user, name) != fingerprint:
                raise RuntimeError("Frozen backup does not restore to the stopped database")
        print("FROZEN_BACKUP_RESTORE_PASS", flush=True)
        if meta["expected_schema"] > schema:
            migrated = True
            server_ops.migrate(meta["migrate_image"], work / "source/server/db/migrations", network,
                               env["DATABASE_HOST"], user, name, Path(secret), log)
            if server_ops.schema_version(target.db, user, name) != meta["expected_schema"]:
                raise RuntimeError("Migration did not reach the expected schema")
            compare_tables(fingerprint, server_ops.fingerprint(target.db, user, name, columns), allowed)
            print(f"MIGRATION_PASS schema {schema}->{meta['expected_schema']}", flush=True)
        run(["docker", "compose", "-f", str(target.release), "up", "-d", "--no-deps", "--no-build", "api"], log)
        wait_healthy(target.api)
        result = verify_deployed(work, target, meta, before, schema, frozen, started, user, name, label)
    except BaseException:
        if not migrated:
            # 스키마가 그대로면 직전 API로 되돌린다
            restore_previous(target)
        else:
            print(f"FAILED after migration. Do not downgrade the DB. Frozen backup: {frozen}. Previous API "
                  f"config: {target.rollback} (start it only after checking compatibility with schema "
                  f"{meta['expected_schema']}).", file=sys.stderr)
        raise
    print(f"{label.upper()}_DEPLOY_PASS image={meta['api_image']} schema={result['schema']} "
          f"http={len(result['checks'])}")


def verify_deployed(work, target, meta, before, schema, frozen, started, user, name, label):
    after = inspect(target.api)
    checks = smoke(host_url(target.api)) + (smoke(target.public_url) if target.public_url else [])
    runtime = {key: before["Config"].get(key) == after["Config"].get(key) for key in CONFIG_KEYS}
    runtime.update({key: before["HostConfig"].get(key) == after["HostConfig"].get(key) for key in HOST_KEYS})
    preserved = {other: inspect(other)["Id"] == json.loads(
        (target.snapshots / f"before-{other.split('-')[2]}.inspect.private.json").read_text())["Id"]
        for other in target.others}
    result = {
        "target_sha": meta["target_sha"], "image": meta["api_image"], "image_id": after["Image"],
        "schema": {"before": schema, "after": server_ops.schema_version(target.db, user, name)},
        "frozen_backup": frozen.name, "frozen_backup_sha256": server_ops.sha256(frozen),
        "environment_unchanged": environment(before) == environment(after),
        "mounts_unchanged": before["Mounts"] == after["Mounts"],
        "ports_unchanged": before["HostConfig"]["PortBindings"] == after["HostConfig"]["PortBindings"],
        "networks_unchanged": set(before["NetworkSettings"]["Networks"]) == set(after["NetworkSettings"]["Networks"]),
        "runtime_contracts": runtime, "other_containers_preserved": preserved,
        "write_stop_started_at": started, "completed_at": stamp(), "checks": checks}
    write_private_json(work / f"{label}-verification.json", result)
    failed = [key for key in ("environment_unchanged", "mounts_unchanged", "ports_unchanged", "networks_unchanged")
              if not result[key]] + [k for k, ok in {**runtime, **preserved}.items() if not ok]
    if after["Image"] != meta["api_image_id"] or failed:
        raise RuntimeError(f"Post-deploy contract mismatch: {failed}")
    return result


def rehearse(work: Path, allowed):
    """운영 DB 사본과 현 API compose를 격리 이름·네트워크로 바꾼 스택에서 deploy를 실행한다."""
    meta = json.loads((work / "metadata.json").read_text())
    user, name = server_ops.credentials()
    stage = work / f"rehearsal-{stamp()}"
    stage.mkdir(mode=0o700)
    backup = stage / "source.dump"
    server_ops.dump(server_ops.DB_CONTAINER, user, name, backup)
    with server_ops.isolated_database(user, name, stage, "release-rehearsal") as isolated:
        server_ops.restore(backup, isolated["db"], user, name)
        project = isolated["db"].removesuffix("-db")
        container = project + "-api"

        def isolate(source, output):
            compose = json.loads(Path(source).read_text())
            compose["name"] = project
            compose["networks"] = {"default": {"external": True, "name": isolated["network"]}}
            api = compose["services"]["api"]
            api["container_name"] = container
            api["ports"] = [{"target": 8080, "host_ip": "127.0.0.1", "protocol": "tcp"}]
            api["environment"]["DATABASE_HOST"] = isolated["db"]
            api["environment"]["AUTH_SESSION_RECEIPT_KEY"] = ""
            for volume in api["volumes"]:
                if volume["target"] == api["environment"]["DATABASE_PASSWORD_FILE"]:
                    volume["source"] = str(isolated["secret"])
            write_private_json(output, compose)
            return output

        rollback = isolate(work / "api-rollback.compose.private.json", stage / "api-rollback.compose.private.json")
        release = isolate(work / "api-release.compose.private.json", stage / "api-release.compose.private.json")
        try:
            run(["docker", "compose", "-f", str(rollback), "up", "-d", "--no-deps", "--no-build", "api"])
            wait_healthy(container)
            write_private_json(stage / "before-api.inspect.private.json", inspect(container))
            target = Target(container, isolated["db"], (), release, rollback, None, stage)
            stage_meta = dict(meta, current_schema=server_ops.schema_version(isolated["db"], user, name))
            stage.joinpath("source").symlink_to(work / "source")
            deploy(stage, target, stage_meta, allowed, label="rehearsal")
        finally:
            subprocess.run(["docker", "rm", "-f", container], capture_output=True)
            backup.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("prepare").add_argument("commit")
    commands.add_parser("rehearse-deploy").add_argument("work", type=Path)
    deploy_parser = commands.add_parser("deploy")
    deploy_parser.add_argument("work", type=Path)
    deploy_parser.add_argument("--confirm", action="store_true", help="운영 API를 정지하고 반영한다")
    for sub in commands.choices.values():
        sub.add_argument("--allow-changed-table", action="append", default=[],
                         help="마이그레이션이 의도적으로 기존 행을 바꾸는 테이블")
    args = parser.parse_args(argv)
    allowed = set(args.allow_changed_table)
    if args.command == "prepare":
        prepare(args.commit, allowed)
    elif args.command == "rehearse-deploy":
        rehearse(args.work, allowed)
    else:
        if not args.confirm:
            raise SystemExit("deploy stops the production API; pass --confirm")
        meta = json.loads((args.work / "metadata.json").read_text())
        target = Target(server_ops.API_CONTAINER, server_ops.DB_CONTAINER, OTHERS,
                        args.work / "api-release.compose.private.json",
                        args.work / "api-rollback.compose.private.json", public_url(), args.work)
        deploy(args.work, target, meta, allowed | set(meta["allowed_changed_tables"]))


if __name__ == "__main__":
    main()
