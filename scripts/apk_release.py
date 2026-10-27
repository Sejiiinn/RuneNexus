#!/usr/bin/env python3
"""APK 배포 워크플로 실행·대기·검수를 한 명령으로 묶는다.

build    build-only(publish=false) 실행 → 완료 대기 → 아티팩트를 받아 release_report로 후보 검수
publish  build와 같은 입력으로 publish=true·promote_run_id=<build 실행> 실행 → 검수한 후보 파일을
         다시 빌드하지 않고 공개 → 공개 주소에서 익명으로 받은 자산을 후보 파일·GitHub 자산 digest·
         latest update.json과 대조

입력·결과는 build/apk-release-<code>/에 남는다. 대상은 origin/main에 푸시된 현재 HEAD다.
build 뒤 다른 APK가 공개되면 패치 기준이 달라져 승격이 거부되므로 build부터 다시 한다.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
REPO = "Sejiiinn/RuneNexus"
WORKFLOW = "deploy-apk.yml"
DOWNLOAD = f"https://github.com/{REPO}/releases/download"
LATEST_MANIFEST = f"https://github.com/{REPO}/releases/latest/download/update.json"


def sh(*args, **options):
    return subprocess.run(args, cwd=ROOT, check=True, text=True, capture_output=True, **options).stdout.strip()


def head():
    sha = sh("git", "rev-parse", "HEAD")
    sh("git", "fetch", "-q", "origin", "main")
    if sh("git", "rev-parse", "origin/main") != sha:
        raise SystemExit("HEAD is not origin/main; push first")
    return sha


def dispatch(inputs, publish, promote_run=None):
    """워크플로를 실행하고 이번 실행의 run ID를 찾는다."""
    started = datetime.now(timezone.utc) - timedelta(seconds=5)
    extra = {"publish": str(publish).lower(), **({"promote_run_id": str(promote_run)} if promote_run else {})}
    fields = [f"{key}={value}" for key, value in {**inputs, **extra}.items() if key != "sha"]
    sh("gh", "workflow", "run", WORKFLOW, "--ref", "main", *sum((["-f", field] for field in fields), []))
    for _ in range(30):
        time.sleep(4)
        runs = json.loads(sh("gh", "run", "list", "--workflow", WORKFLOW, "--event", "workflow_dispatch",
                             "--limit", "5", "--json", "databaseId,headSha,createdAt"))
        run = pick_run(runs, inputs["sha"], started)
        if run:
            return run
    raise SystemExit("Dispatched run not found")


def pick_run(runs, sha, started):
    for run in runs:
        created = datetime.fromisoformat(run["createdAt"].replace("Z", "+00:00"))
        if run["headSha"] == sha and created >= started:
            return run["databaseId"]
    return None


def wait(run, sha, work, label):
    subprocess.run(["python3", "scripts/release_report.py", "wait", "--github-repo", REPO, "--run-id", str(run),
                    "--expected-sha", sha, "--timeout", "3600", "--log", str(work / f"{label}-watch.log"),
                    "--output", str(work / f"{label}-ci.json")], cwd=ROOT, check=True)


def verify(folder: Path, sha, run, output: Path, *public, source=None):
    """source가 공개 URL이면 release_report가 공개 주소에서 직접 받아 관측한다."""
    manifest = json.loads((folder / "update.json").read_text())
    base = source or str(folder)
    patches = [f"--patch={p['fromVersionCode']}={base}/patch-from-{p['fromVersionCode']}.rndelta"
               for p in manifest.get("patches", [])]
    subprocess.run(["python3", "scripts/release_report.py", "verify", "--manifest", f"{base}/update.json",
                    "--apk", f"{base}/rune-nexus.apk", *patches, "--inspect-apk-build", "--audit-godot-pack",
                    "--expected-sha", sha, "--expected-run-id", str(run), "--github-repo", REPO, *public,
                    "--output", str(output)], cwd=ROOT, check=True)
    return manifest


def summary(folder: Path, manifest, report: Path):
    audit = json.loads(report.read_text()).get("godot_pack_audit", {})
    abis = sorted({line.split("lib/")[1].split("/")[0] for line in sh("unzip", "-Z1", str(folder / "rune-nexus.apk"))
                   .splitlines() if line.startswith("lib/")})
    return {"apk_bytes": manifest["sizeBytes"], "apk_sha256": manifest["sha256"],
            "minimum_supported": manifest["minimumSupportedVersionCode"], "abis": abis,
            "patches": {p["fromVersionCode"]: (folder / f"patch-from-{p['fromVersionCode']}.rndelta").stat().st_size
                        for p in manifest.get("patches", [])},
            "pack_bytes": audit.get("pack_bytes"), "pack_entries": audit.get("entry_count"),
            "pack_duplicate_bytes": audit.get("logical_duplicate_bytes")}


def build(code, name, notes, required):
    work = ROOT / f"build/apk-release-{code}"
    work.mkdir(parents=True, exist_ok=True)
    inputs = {"version_code": str(code), "version_name": name, "notes": notes,
              "required_update": str(required).lower(), "sha": head()}
    run = dispatch(inputs, False)
    print(f"build-only run {run}", flush=True)
    wait(run, inputs["sha"], work, "build")
    candidate = work / "build-only"
    sh("gh", "run", "download", str(run), "-n", f"rune-nexus-apk-{code}", "-D", str(candidate))
    manifest = verify(candidate, inputs["sha"], run, work / "build-only-verification.json")
    result = {"inputs": inputs, "build_run": run, **summary(candidate, manifest, work / "build-only-verification.json")}
    (work / "build.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))


def publish(code):
    work = ROOT / f"build/apk-release-{code}"
    built = json.loads((work / "build.json").read_text())
    inputs = built["inputs"]
    if head() != inputs["sha"]:
        raise SystemExit("HEAD moved since build; run build again")
    run = dispatch(inputs, True, built["build_run"])
    print(f"publish run {run} (promoting build-only run {built['build_run']})", flush=True)
    wait(run, inputs["sha"], work, "publish")
    verify_public(code, inputs, run, work, work / "build-only")


def file_hashes(folder: Path):
    return {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in folder.iterdir() if path.is_file()}


def verify_public(code, inputs, run, work: Path, candidate: Path | None = None):
    public = work / "public"
    public.mkdir(exist_ok=True)
    assets = json.loads(sh("gh", "api", f"repos/{REPO}/releases/tags/apk-{code}", "--jq",
                           "[.assets[] | {name, size, digest}]"))
    mismatched = []
    for asset in assets:
        # 공개 주소를 인증 없이 받아 실제 사용자가 받는 바이트를 대조한다
        path = public / asset["name"]
        urllib.request.urlretrieve(f"{DOWNLOAD}/apk-{code}/{asset['name']}", path)
        digest = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != asset["digest"] or path.stat().st_size != asset["size"]:
            mismatched.append(asset["name"])
    with urllib.request.urlopen(LATEST_MANIFEST) as response:
        latest_same = response.read() == (public / "update.json").read_bytes()
    manifest = verify(public, inputs["sha"], run, work / "public-candidate.json")
    verify(public, inputs["sha"], run, work / "public-verification.json",
           "--candidate-report", str(work / "public-candidate.json"), "--release-tag", f"apk-{code}",
           "--latest-manifest", LATEST_MANIFEST, source=f"{DOWNLOAD}/apk-{code}")
    # 승격 공개는 검수한 후보와 바이트까지 같아야 한다
    same_as_candidate = None if candidate is None else file_hashes(public) == file_hashes(candidate)
    result = {"inputs": inputs, "publish_run": run, "release": f"https://github.com/{REPO}/releases/tag/apk-{code}",
              "assets_match_github_digest": not mismatched, "mismatched": mismatched,
              "latest_manifest_matches": latest_same, "same_as_build_only_candidate": same_as_candidate,
              **summary(public, manifest, work / "public-candidate.json")}
    (work / "publish.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if mismatched or not latest_same or same_as_candidate is False:
        raise SystemExit("Public assets do not match the release")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    build_parser = commands.add_parser("build")
    build_parser.add_argument("--version-code", type=int, required=True)
    build_parser.add_argument("--version-name", required=True)
    build_parser.add_argument("--notes", required=True)
    build_parser.add_argument("--required-update", action="store_true")
    commands.add_parser("publish").add_argument("--version-code", type=int, required=True)
    check = commands.add_parser("verify-public", help="이미 공개된 릴리스를 다시 대조한다")
    check.add_argument("--version-code", type=int, required=True)
    check.add_argument("--run-id", type=int, required=True)
    check.add_argument("--sha", required=True)
    args = parser.parse_args(argv)
    if args.command == "build":
        build(args.version_code, args.version_name, args.notes, args.required_update)
    elif args.command == "publish":
        publish(args.version_code)
    else:
        work = ROOT / f"build/apk-release-{args.version_code}"
        work.mkdir(parents=True, exist_ok=True)
        verify_public(args.version_code, {"sha": args.sha}, args.run_id, work)


if __name__ == "__main__":
    main()
