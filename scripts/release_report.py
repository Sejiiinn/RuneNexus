"""Read-only release planning and explicit artifact integrity checks.

Detailed evidence goes to --output; stdout stays bounded. No release discovery,
publication, build, signature verification, or installation is performed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.parse
import urllib.request
import zipfile

from audit_godot_pack import audit_path

MAX_APK = 512 * 1024 * 1024


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).rstrip("\n")


def plan(repo, baseline, target):
    base = git(repo, "rev-parse", "--verify", "--end-of-options", baseline + "^{commit}")
    head = git(repo, "rev-parse", "--verify", "--end-of-options", target + "^{commit}")
    paths = git(repo, "diff", "--name-only", "-z", base, head).split("\0")
    paths = [p for p in paths if p]
    dirty = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=normal")
    candidates = {}
    for name, prefixes in {
        "server_or_contract": ("server/", "api/", "compose", ".env"),
        "migration": ("server/migrations/", "migrations/"),
        "client": ("lib/", "assets/", "godot/", "android/", "web/", "pubspec"),
        "deployment_or_tooling": ("scripts/", ".github/"),
        "documentation": ("docs/", "design/", "DESIGNS.md", "AGENTS.md", "README.md"),
    }.items():
        candidates[name] = [p for p in paths if p.startswith(prefixes)]
    classified = {p for values in candidates.values() for p in values}
    candidates["other"] = [p for p in paths if p not in classified]
    return {"operation": "plan", "ok": True, "baseline_sha": base,
            "target_sha": head, "changed_paths": paths, "impact_candidates": candidates,
            "dirty": bool(dirty), "working_tree_porcelain_z": dirty,
            "limitations": ["Diff covers committed refs only; working tree changes are separate.",
                            "Path categories are hints, not API/DB compatibility decisions.",
                            "No public version, device version, CI, or deployment state checked."]}


def fetch(source, destination, limit):
    parsed = urllib.parse.urlsplit(source)
    if parsed.scheme and parsed.scheme not in ("https", "http"):
        raise ValueError("Only local paths and explicit HTTP(S) URLs are supported")
    if parsed.scheme:
        stream = urllib.request.urlopen(source, timeout=45)
    else:
        stream = Path(source).open("rb")
    digest = hashlib.sha256()
    size = 0
    with stream, destination.open("wb") as output:
        while chunk := stream.read(1024 * 1024):
            size += len(chunk)
            if size > limit:
                raise ValueError(f"Input exceeds {limit} bytes")
            digest.update(chunk)
            output.write(chunk)
    return {"source": source, "size_bytes": size, "sha256": digest.hexdigest()}


def expectation(value):
    size = value.get("sizeBytes")
    sha = value.get("sha256")
    if type(size) is not int or not 0 < size <= MAX_APK:
        raise ValueError("Invalid expected sizeBytes")
    if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
        raise ValueError("Invalid expected sha256")
    return size, sha


def compare_apk_sizes(baseline, target):
    def inventory(path):
        with zipfile.ZipFile(path) as archive:
            entries = {}
            for item in archive.infolist():
                if item.filename in entries:
                    raise ValueError("Duplicate ZIP entry prevents unambiguous size comparison")
                entries[item.filename] = (item.file_size, item.compress_size)
            return entries

    before, after = inventory(baseline), inventory(target)
    changes = []
    for name in before.keys() | after.keys():
        old = before.get(name, (0, 0))
        new = after.get(name, (0, 0))
        if old == new and name in before and name in after:
            continue
        changes.append({
            "path": name,
            "status": "added" if name not in before else "removed" if name not in after else "changed",
            "baseline_uncompressed_bytes": old[0], "target_uncompressed_bytes": new[0],
            "uncompressed_delta_bytes": new[0] - old[0],
            "baseline_compressed_bytes": old[1], "target_compressed_bytes": new[1],
            "compressed_delta_bytes": new[1] - old[1],
        })
    changes.sort(key=lambda item: (-abs(item["compressed_delta_bytes"]),
                                  -abs(item["uncompressed_delta_bytes"]), item["path"]))
    old_size, new_size = baseline.stat().st_size, target.stat().st_size
    return {"baseline_bytes": old_size, "target_bytes": new_size,
            "delta_bytes": new_size - old_size,
            "delta_percent": (new_size - old_size) / old_size * 100,
            "changed_entry_count": len(changes), "largest_entry_changes": changes[:10],
            "limitations": ["Build conditions and signing certificate equivalence not checked.",
                            "Entry sizes exclude ZIP/signing overhead; equal sizes do not prove equal content.",
                            "Nested PCK contents are not compared; no ABI or quality approval implied."]}


def verify(manifest_source, apk_source, patch_sources, audit=False, baseline_source=None):
    report = {"operation": "verify", "ok": False, "assets": [], "errors": [],
              "limitations": ["Checks supplied bytes against supplied metadata only.",
                              "No signature, package identity, CI, latest release, patch restoration, installation, or visual quality checked."]}
    with tempfile.TemporaryDirectory(prefix="rune-release-report-") as folder:
        root = Path(folder)
        report["manifest"] = fetch(manifest_source, root / "update.json", 64 * 1024)
        manifest = json.loads((root / "update.json").read_text(encoding="utf-8"))
        if type(manifest.get("schemaVersion")) is not int or manifest["schemaVersion"] != 1:
            raise ValueError("Unsupported schemaVersion")
        report["version_code"] = manifest.get("versionCode")
        report["version_name"] = manifest.get("versionName")
        patches = manifest.get("patches", [])
        if not isinstance(patches, list) or len(patches) > 3:
            raise ValueError("Invalid patches list")
        wanted = [("apk", apk_source, manifest)]
        codes = set()
        for patch in patches:
            code = patch.get("fromVersionCode")
            if type(code) is not int or code <= 0 or code in codes:
                raise ValueError("Invalid or duplicate patch fromVersionCode")
            codes.add(code)
            source = patch_sources.get(code)
            if source is None:
                report["errors"].append(f"Missing explicit --patch {code}=SOURCE")
            else:
                wanted.append((f"patch-{code}", source, patch))
        if set(patch_sources) - codes:
            raise ValueError("Supplied patch code is absent from manifest")
        for name, source, metadata in wanted:
            size, sha = expectation(metadata)
            path = root / name
            result = fetch(source, path, MAX_APK)
            result.update(name=name, expected_size_bytes=size, expected_sha256=sha,
                          ok=result["size_bytes"] == size and result["sha256"] == sha)
            report["assets"].append(result)
            if not result["ok"]:
                report["errors"].append(f"Integrity mismatch: {name}")
            if name == "apk" and audit and result["ok"]:
                report["godot_pack_audit"] = audit_path(path)
                # Remove temporary paths from persistent evidence.
                report["godot_pack_audit"]["source"] = source
        if baseline_source is not None:
            baseline_path = root / "baseline.apk"
            report["baseline_apk"] = fetch(baseline_source, baseline_path, MAX_APK)
            report["apk_size_comparison"] = compare_apk_sizes(baseline_path, root / "apk")
        report["ok"] = not report["errors"]
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("plan")
    p.add_argument("--repo", type=Path, default=Path("."))
    p.add_argument("--baseline", required=True)
    p.add_argument("--target", required=True)
    v = commands.add_parser("verify")
    v.add_argument("--manifest", required=True)
    v.add_argument("--apk", required=True)
    v.add_argument("--patch", action="append", default=[], metavar="CODE=SOURCE")
    v.add_argument("--audit-godot-pack", action="store_true")
    v.add_argument("--baseline-apk", help="Optional previous APK path or explicit HTTP(S) URL for size comparison")
    for command in (p, v):
        command.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            report = plan(args.repo, args.baseline, args.target)
        else:
            patches = {}
            for item in args.patch:
                code, source = item.split("=", 1)
                code = int(code)
                if code in patches or not source:
                    raise ValueError("Duplicate patch code or empty source")
                patches[code] = source
            report = verify(args.manifest, args.apk, patches, args.audit_godot_pack, args.baseline_apk)
    except (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        report = {"operation": args.command, "ok": False, "errors": [str(error)]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{args.command}: {'PASS' if report['ok'] else 'FAIL'}; details: {args.output}")
    if args.command == "plan" and report["ok"]:
        print(f"{report['baseline_sha'][:12]} → {report['target_sha'][:12]}; changed files: {len(report['changed_paths'])}; dirty: {report['dirty']}")
    elif report["ok"]:
        print(f"Verified {len(report['assets'])} asset(s); signature/CI/install/latest not checked.")
    else:
        print("Inspection failed; see JSON errors. This is not deployment approval.")
    if "apk_size_comparison" in report:
        delta = report["apk_size_comparison"]
        print(f"APK size: {delta['baseline_bytes']} → {delta['target_bytes']} bytes; delta {delta['delta_bytes']:+d} ({delta['delta_percent']:+.2f}%).")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
