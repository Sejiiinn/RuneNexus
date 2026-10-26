#!/usr/bin/env python3
"""운영 DB를 외장 볼륨에 매일 백업하고 보관 개수를 관리한다.

backup          운영 DB 덤프 → 목록 확인 → 외장 볼륨에 게시 → 오래된 백업 정리
verify          백업 하나를 일회용 격리 DB에 복원해 확인(운영 DB 미접속)
install-launchd 매일 백업하는 사용자 launchd 작업 등록

launchd로 실행한 python은 macOS 개인정보 보호(TCC) 때문에 외장 볼륨을 읽고 쓰지
못한다. 외장 볼륨의 파일은 접근 권한이 있는 Docker Desktop의 보조 컨테이너로만 다룬다.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import server_ops  # noqa: E402

DESTINATION = Path("/Volumes/KIOXIA_MAC/RuneNexus/db-backups")
DAILY, WEEKLY = 14, 8
PATTERN = re.compile(r"rune-nexus-(\d{8}T\d{6}Z)-schema(\d+)\.dump")
LABEL = "com.runenexus.db-backup"
# launchd는 ~/Documents(보호 폴더)의 스크립트도 읽지 못하므로 사본을 여기에 둔다
INSTALL = Path.home() / "Library/Application Support/RuneNexus/bin"
LOGS = Path.home() / "Library/Logs/RuneNexus"


def retained(names, daily=DAILY, weekly=WEEKLY):
    """최근 daily개와, 최근 weekly개 ISO 주의 주별 최신 백업을 남긴다."""
    stamped = sorted(((datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ"), name)
                      for name in names if (m := PATTERN.fullmatch(name))), reverse=True)
    keep = {name for _, name in stamped[:daily]}
    weeks = []
    for stamp, name in stamped:
        week = stamp.isocalendar()[:2]
        if week not in weeks:
            if len(weeks) == weekly:
                break
            weeks.append(week)
            keep.add(name)
    return keep


def volume(destination: Path, script, *args, stdin=None, read_only=False, stream=False):
    """외장 볼륨 파일 작업을 Docker 보조 컨테이너의 sh 스크립트로 수행한다."""
    command = ["docker", "run", "--rm", "-i", "-v",
               f"{destination}:/backups" + (":ro" if read_only else ""),
               server_ops.POSTGRES_IMAGE, "sh", "-ec", script, "sh", *args]
    if stream:
        return subprocess.Popen(command, stdout=subprocess.PIPE)
    return subprocess.run(command, stdin=stdin, check=True, capture_output=True, text=stdin is None).stdout


def backup(destination: Path):
    if not Path(*destination.parts[:3]).is_mount():
        raise SystemExit(f"Backup volume is not mounted: {destination}")
    user, name = server_ops.credentials()
    version = server_ops.schema_version(server_ops.DB_CONTAINER, user, name)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = f"rune-nexus-{stamp}-schema{version}.dump"
    partial = "." + output + ".partial"
    # pg_dump는 한 트랜잭션 스냅샷이라 API가 쓰는 중에도 일관된 백업이 된다
    producer = subprocess.Popen(["docker", "exec", server_ops.DB_CONTAINER, "pg_dump", "-U", user, "-d", name, "-Fc"],
                                stdout=subprocess.PIPE)
    try:
        digest = volume(destination, 'umask 077; trap \'rm -f "/backups/$1"\' EXIT; cat > "/backups/$1"; '
                        'pg_restore --list "/backups/$1" | grep -q "TABLE public schema_version"; '
                        'sha256sum "/backups/$1" | cut -d" " -f1; mv "/backups/$1" "/backups/$2"; trap - EXIT',
                        partial, output, stdin=producer.stdout).decode().strip()
    finally:
        producer.stdout.close()
        if producer.wait():
            raise SystemExit(f"pg_dump failed ({producer.returncode})")
    names = volume(destination, "ls -1 /backups").split()
    removed = sorted(n for n in names if PATTERN.fullmatch(n) and n not in retained(names))
    record = {"completed_at": stamp, "backup": output, "sha256": digest, "schema": version, "removed": removed}
    volume(destination, 'printf "%s  %s\\n" "$1" "$2" > "/backups/$2.sha256"; printf "%s\\n" "$3" >> /backups/backup-log.jsonl; '
           'shift 3; for old in "$@"; do rm -f "/backups/$old" "/backups/$old.sha256"; done',
           digest, output, json.dumps(record), *removed)
    print(json.dumps(record))


def latest(destination: Path):
    dumps = sorted(n for n in volume(destination, "ls -1 /backups", read_only=True).split() if PATTERN.fullmatch(n))
    if not dumps:
        raise SystemExit(f"No backup in {destination}")
    return dumps[-1]


def verify(destination: Path, name_: str):
    if not PATTERN.fullmatch(name_):
        raise SystemExit(f"Not a backup name: {name_}")
    volume(destination, 'cd /backups; [ ! -e "$1.sha256" ] || sha256sum -c "$1.sha256" >/dev/null', name_, read_only=True)
    user, name = server_ops.credentials()
    with tempfile.TemporaryDirectory() as work, \
            server_ops.isolated_database(user, name, Path(work), "backup-verify") as isolated:
        reader = volume(destination, 'cat "/backups/$1"', name_, read_only=True, stream=True)
        try:
            server_ops.restore(reader.stdout, isolated["db"], user, name)
        finally:
            reader.stdout.close()
            reader.wait()
        restored = server_ops.schema_version(isolated["db"], user, name)
        tables = server_ops.fingerprint(isolated["db"], user, name)
    if restored != int(PATTERN.fullmatch(name_).group(2)):
        raise SystemExit(f"Restored schema {restored} does not match {name_}")
    print(json.dumps({"backup": name_, "schema": restored, "tables": len(tables),
                      "rows": sum(table["count"] for table in tables.values()), "production_accessed": False}))


def install_launchd(destination: Path, hour: int, minute: int):
    INSTALL.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    for module in ("server_ops.py", "server_backup.py"):
        shutil.copy2(Path(__file__).resolve().parent / module, INSTALL / module)
    docker = shutil.which("docker")
    if not docker:
        raise SystemExit("docker CLI not found")
    agent = Path.home() / "Library/LaunchAgents" / f"{LABEL}.plist"
    agent.write_bytes(plistlib.dumps({
        "Label": LABEL,
        "ProgramArguments": [sys.executable, str(INSTALL / "server_backup.py"),
                             "backup", "--destination", str(destination)],
        "StartCalendarInterval": {"Hour": hour, "Minute": minute},
        "EnvironmentVariables": {"PATH": f"{Path(docker).parent}:/usr/bin:/bin"},
        "StandardOutPath": str(LOGS / "db-backup.log"),
        "StandardErrorPath": str(LOGS / "db-backup.log"),
    }))
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", f"{domain}/{LABEL}"], capture_output=True)
    subprocess.run(["launchctl", "bootstrap", domain, str(agent)], check=True)
    print(f"Installed {agent}; daily at {hour:02d}:{minute:02d} → {destination}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("backup", "verify", "install-launchd"):
        commands.add_parser(command).add_argument("--destination", type=Path, default=DESTINATION)
    commands.choices["verify"].add_argument("backup", nargs="?", help="백업 파일 이름(기본값: 가장 최근)")
    commands.choices["install-launchd"].add_argument("--hour", type=int, default=4)
    commands.choices["install-launchd"].add_argument("--minute", type=int, default=17)
    args = parser.parse_args(argv)
    if args.command == "backup":
        backup(args.destination)
    elif args.command == "verify":
        verify(args.destination, args.backup or latest(args.destination))
    else:
        install_launchd(args.destination, args.hour, args.minute)


if __name__ == "__main__":
    main()
