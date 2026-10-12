"""Read-only release planning and explicit artifact integrity checks.

Detailed evidence goes to --output; stdout stays bounded. GitHub inspection is
read-only and opt-in. No publication, build, fetch, or installation is performed.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.parse
import urllib.request
import zipfile
import shutil

from audit_godot_pack import audit_path

MAX_APK = 512 * 1024 * 1024


class ObservationMismatch(ValueError):
    """Supplied observation contradicts an explicit repository or release identity."""


def now():
    return datetime.now(timezone.utc).isoformat()


def full_sha(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("Expected a full 40-character commit SHA")
    return value


def github_api(repository, endpoint):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid GitHub repository")
    result = subprocess.run(["gh", "api", f"repos/{repository}/{endpoint}"],
                            capture_output=True, text=True, check=True, timeout=45)
    return json.loads(result.stdout)


def github_url_identity(value):
    if not isinstance(value, str) or not value:
        return None
    parsed = urllib.parse.urlsplit(value)
    parts = urllib.parse.unquote(parsed.path).split("/")
    if parsed.scheme != "https" or parsed.netloc.lower() != "github.com" or len(parts) < 4 or parsed.query or parsed.fragment:
        return None
    return (parts[1].lower(), parts[2].lower(), *parts[3:])


def bind_observation(data, require_release, require_run):
    """Bind consumed raw API objects to the wrapper repo; absent fields are unknown."""
    repository = data.get("github_repo")
    if not isinstance(repository, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise KeyError("Observation GitHub repository unavailable")
    missing, mismatches = [], []

    def url(value, suffix, label):
        if not value:
            missing.append(label)
            return
        parsed = urllib.parse.urlsplit(value)
        pieces = urllib.parse.unquote(parsed.path).split("/")
        repo_parts = repository.split("/")
        if (parsed.scheme != "https" or parsed.netloc.lower() != "github.com" or parsed.query or parsed.fragment or
                len(pieces) < 4 or [part.lower() for part in pieces[1:3]] != [part.lower() for part in repo_parts] or
                "/".join(pieces[3:]) != suffix):
            mismatches.append(label)

    if require_run:
        run = data.get("run") or {}
        raw_repo = (run.get("repository") or {}).get("full_name")
        if not raw_repo:
            missing.append("run.repository.full_name")
        elif raw_repo.lower() != repository.lower():
            mismatches.append("run.repository.full_name")
        run_id = run.get("id", run.get("databaseId"))
        if run_id is None:
            missing.append("run.id")
        else:
            url(run.get("html_url", run.get("url")), f"actions/runs/{run_id}", "run.html_url")
    if require_release:
        release = data.get("release") or {}
        tag = release.get("tag_name")
        if not tag:
            missing.append("release.tag_name")
        else:
            url(release.get("html_url"), f"releases/tag/{tag}", "release.html_url")
            for asset in release.get("assets", []):
                name = asset.get("name")
                if not name:
                    missing.append("release asset name")
                else:
                    url(asset.get("browser_download_url"), f"releases/download/{tag}/{name}",
                        f"asset browser_download_url: {name}")
    if mismatches:
        raise ObservationMismatch("Raw GitHub observation repository/path mismatch: " + ", ".join(mismatches))
    if missing:
        raise KeyError("Raw GitHub observation incomplete: " + ", ".join(missing))
    return data


def observation(repository=None, source=None, tag=None, run_id=None):
    """A saved observation contains raw release/run API objects and peeled tag_sha.

    Saved inputs are explicitly supplied evidence, never a fresh GitHub query.
    The release's target_commitish may be a moving branch; it is not a baseline.
    """
    if source:
        data = json.loads(Path(source).read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("Observation must be an object")
        if repository and str(data.get("github_repo", "")).lower() != repository.lower():
            if data.get("github_repo"):
                raise ObservationMismatch("Saved observation GitHub repository mismatch")
        if not data.get("observed_at") or not data.get("github_repo"):
            raise KeyError("Saved observation requires observed_at and github_repo")
        return bind_observation({**data, "evidence_source": str(source), "live_query": False}, tag is not False, bool(run_id))
    if not repository:
        raise ValueError("Supply --github-repo or --release-info/--run-info")
    data = {"observed_at": now(), "github_repo": repository, "live_query": True}
    if tag is not False:
        endpoint = "releases/latest" if tag is None else "releases/tags/" + urllib.parse.quote(tag, safe="")
        data["release"] = release = github_api(repository, endpoint)
        name = release["tag_name"]
        obj = github_api(repository, "git/ref/tags/" + urllib.parse.quote(name, safe=""))["object"]
        for _ in range(8):
            if obj["type"] == "commit":
                break
            if obj["type"] != "tag":
                raise ValueError("Release tag does not resolve to a commit")
            obj = github_api(repository, "git/tags/" + obj["sha"])["object"]
        else:
            raise ValueError("Release tag nesting limit exceeded")
        data["tag_sha"] = full_sha(obj["sha"])
        data["latest_tag"] = (name if tag is None else github_api(repository, "releases/latest")["tag_name"])
    if run_id:
        data["run"] = github_api(repository, f"actions/runs/{run_id}")
    return bind_observation(data, tag is not False, bool(run_id))


def public_release(data, expected_tag=None):
    release = data["release"]
    tag = release["tag_name"]
    if not re.fullmatch(r"apk-[1-9][0-9]*", tag):
        raise ValueError("Public release must use apk-<versionCode>")
    if release.get("draft") is not False or release.get("prerelease") is not False or not release.get("published_at"):
        raise ValueError("Release is not a published stable APK")
    if expected_tag is not None and tag != expected_tag:
        raise ObservationMismatch("Public release tag mismatch")
    if not data.get("latest_tag"):
        raise KeyError("Latest public release unconfirmed")
    if data["latest_tag"] != tag:
        raise ObservationMismatch("Latest public release differs from observed release tag")
    names = [asset["name"] for asset in release["assets"]]
    if not {"update.json", "rune-nexus.apk"}.issubset(names):
        raise ValueError("Public APK release is missing APK or update manifest asset")
    return {"tag": tag, "sha": full_sha(data["tag_sha"]),
            "version_code": int(tag[4:]), "url": release.get("html_url"),
            "published_at": release["published_at"], "observed_at": data.get("observed_at"),
            "evidence_source": data.get("evidence_source", "GitHub API"),
            "live_query": data.get("live_query", False)}


def commits(repo, *revisions):
    lines = git(repo, "log", "--format=%H%x09%s", *revisions).splitlines()
    return [{"sha": line.split("\t", 1)[0], "subject": line.split("\t", 1)[1]} for line in lines]


def snapshot(repo, target, local_ref="HEAD", remote_ref="origin/main", repository=None,
             release_info=None, expected_baseline=None, server_baseline=None, server_evidence=None):
    if expected_baseline:
        full_sha(expected_baseline)
    report = {"operation": "snapshot", "ok": False, "status": "unknown", "observed_at": now(),
              "errors": [], "unknown": [], "limitations": [
                  "No git fetch; remote ref is a local cached observation, not current GitHub HEAD.",
                  "Tag metadata does not prove APK embedded build, signature or installed version.",
                  "Path hints do not decide API compatibility, migration order or release approval."]}
    local = git(repo, "rev-parse", "--verify", "--end-of-options", local_ref + "^{commit}")
    target_sha = git(repo, "rev-parse", "--verify", "--end-of-options", target + "^{commit}")
    dirty = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=normal")
    report.update(target_sha=target_sha, local_sha=local, dirty=bool(dirty), working_tree_porcelain_z=dirty)
    try:
        remote = git(repo, "rev-parse", "--verify", "--end-of-options", remote_ref + "^{commit}")
        report["branches"] = {"local_ref": local_ref, "remote_ref": remote_ref, "remote_sha": remote,
                              "captured_at": report["observed_at"], "freshness": "local_ref_only",
                              "merge_base": git(repo, "merge-base", local, remote),
                              "local_only": commits(repo, remote + ".." + local),
                              "remote_only": commits(repo, local + ".." + remote)}
        fetch_head = Path(git(repo, "rev-parse", "--git-path", "FETCH_HEAD"))
        if not fetch_head.is_absolute():
            fetch_head = Path(repo) / fetch_head
        report["branches"]["fetch_head_mtime_utc"] = (datetime.fromtimestamp(fetch_head.stat().st_mtime, timezone.utc).isoformat()
                                                     if fetch_head.exists() else None)
        report["excluded_commits"] = commits(repo, local, remote, "^" + target_sha)
    except subprocess.CalledProcessError:
        report["unknown"].append("Remote ref or merge base unavailable")
        report["excluded_commits"] = commits(repo, local, "^" + target_sha)
    for item in report["excluded_commits"]:
        item["reason"] = "Not reachable from explicit target SHA"
    try:
        public = public_release(observation(repository, release_info))
        report["apk_baseline"] = {"status": "pass", **public}
        if expected_baseline and public["sha"] != full_sha(expected_baseline):
            report["errors"].append("Explicit baseline differs from public tag SHA")
        report["apk_plan"] = plan(repo, public["sha"], target_sha)
        report["included_commits"] = commits(repo, public["sha"] + ".." + target_sha)
        if subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", public["sha"], target_sha],
                          capture_output=True).returncode:
            report["errors"].append("Public baseline is not an ancestor of target; divergent diff requires review")
    except ObservationMismatch as error:
        report["apk_baseline"] = {"status": "fail", "reason": str(error)}
        report["errors"].append(str(error))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        report["apk_baseline"] = {"status": "unknown", "reason": str(error)}
        report["unknown"].append("Public APK baseline unavailable or inconsistent")
    if server_baseline:
        if not server_evidence:
            raise ValueError("--server-baseline requires --server-evidence (explicit observation description)")
        report["server_baseline"] = {"status": "explicit_input", "sha": full_sha(server_baseline), "evidence": server_evidence}
        try:
            report["server_plan"] = plan(repo, server_baseline, target_sha)
        except subprocess.CalledProcessError:
            report["unknown"].append("Explicit server baseline commit is absent from local repository; server diff unavailable")
    else:
        report["server_baseline"] = {"status": "unknown", "reason": "No server runtime observation supplied"}
        report["unknown"].append("Server baseline unknown; APK baseline cannot substitute")
    report["status"] = "fail" if report["errors"] else "unknown" if report["unknown"] else "pass"
    report["ok"] = report["status"] == "pass"
    return report


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
        "client": ("assets/", "godot/", "android-godot-only/"),
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


def check_run(run, expected_sha, run_id):
    full_sha(expected_sha)
    if (any(run.get(key) is None for key in ("status", "conclusion")) or
            not run.get("head_sha", run.get("headSha")) or run.get("id", run.get("databaseId")) is None):
        raise KeyError("Incomplete CI observation")
    if str(run.get("id", run.get("databaseId"))) != str(run_id):
        raise ValueError("CI run ID mismatch")
    if run.get("head_sha", run.get("headSha")) != expected_sha:
        raise ValueError("CI head SHA mismatch")
    if run.get("status") != "completed" or run.get("conclusion") != "success":
        raise ValueError("CI run is not completed successfully")
    return {"status": "pass", "run_id": str(run_id), "head_sha": expected_sha,
            "url": run.get("html_url", run.get("url"))}


def apk_build(path):
    """Read only the build field through the existing PCK parser; never extract paths."""
    audit = audit_path(path)
    entries = [entry for entry in audit["entries"]
               if entry["path"] in ("app_config.json", "res://app_config.json")]
    if len(entries) != 1 or entries[0]["bytes"] > 64 * 1024:
        raise ValueError("Missing or oversized app_config.json in APK PCK")
    entry = entries[0]
    with zipfile.ZipFile(path) as archive:
        members = [item for item in archive.infolist() if item.filename.endswith(".pck")]
        with archive.open(members[0]) as packed, tempfile.TemporaryFile() as stream:
            shutil.copyfileobj(packed, stream, 1024 * 1024)
            stream.seek(entry["offset"])
            return json.loads(stream.read(entry["bytes"]))["clientBuild"]


def verify(manifest_source, apk_source, patch_sources, audit=False, baseline_source=None,
           expected_sha=None, expected_run_id=None, run_info=None, repository=None,
           candidate_report=None, release_info=None, release_tag=None, latest_manifest=None,
           inspect_build=False, plan_report=None):
    report = {"operation": "verify", "ok": False, "assets": [], "errors": [],
              "limitations": ["Checks supplied bytes against supplied metadata only.",
                              "No signature, binary package identity, patch restoration, installation, or visual quality checked.",
                              "Local candidate provenance is supplied by caller; run metadata alone does not prove downloaded artifact origin."]}
    if bool(expected_sha) != bool(expected_run_id):
        raise ValueError("Supply both --expected-sha and --expected-run-id")
    if expected_sha:
        full_sha(expected_sha)
        if not re.fullmatch(r"[1-9][0-9]*", str(expected_run_id)):
            raise ValueError("Expected a positive numeric CI run ID")
    if candidate_report and not (expected_sha and release_tag and latest_manifest):
        raise ValueError("Public comparison requires expected SHA/run ID, release tag and latest manifest")
    if (release_info or release_tag or latest_manifest) and not candidate_report:
        raise ValueError("Public inputs require --candidate-report, --release-tag and --latest-manifest")
    if run_info and release_info:
        raise ValueError("Supply one observation file: --run-info or --release-info")
    if (run_info or release_info or release_tag or latest_manifest or plan_report or repository or inspect_build) and not expected_sha:
        raise ValueError("Identity, public and plan inputs require expected SHA/run")
    report["unknown"] = []
    report["unverified"] = ["signature", "binary_package_identity", "patch_restoration", "Android_install", "account_E2E"]
    if not candidate_report:
        report["unverified"].append("latest_public_release")
    if not expected_sha:
        report["unverified"].extend(["CI_identity", "APK_embedded_build"])
    with tempfile.TemporaryDirectory(prefix="rune-release-report-") as folder:
        root = Path(folder)
        report["manifest"] = fetch(manifest_source, root / "update.json", 64 * 1024)
        manifest = json.loads((root / "update.json").read_text(encoding="utf-8"))
        if type(manifest.get("schemaVersion")) is not int or manifest["schemaVersion"] != 1:
            raise ValueError("Unsupported schemaVersion")
        report["version_code"] = manifest.get("versionCode")
        report["version_name"] = manifest.get("versionName")
        report["update_policy"] = {"minimum_supported_version_code": manifest.get("minimumSupportedVersionCode"),
                                   "package_name_metadata": manifest.get("packageName")}
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
                          filename="rune-nexus.apk" if name == "apk" else f"patch-from-{name[6:]}.rndelta",
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
        if expected_sha:
            report["expected"] = {"source_sha": expected_sha, "run_id": str(expected_run_id)}
            if plan_report:
                scope = json.loads(Path(plan_report).read_text(encoding="utf-8"))
                if scope.get("target_sha") != expected_sha or scope.get("operation") not in ("plan", "snapshot"):
                    raise ValueError("Plan report target differs from expected SHA")
                if scope.get("errors") or scope.get("status") == "fail":
                    raise ValueError("Plan report contains unresolved errors")
                report["release_scope"] = scope
            try:
                data = observation(repository, release_info or run_info, release_tag if candidate_report else False, expected_run_id)
                report["ci"] = check_run(data["run"], expected_sha, expected_run_id)
                report["ci"]["evidence_source"] = data.get("evidence_source", "GitHub API")
            except (OSError, subprocess.SubprocessError) as error:
                report["unknown"].append(f"CI observation unavailable: {error}")
                data = None
            except KeyError as error:
                report["unknown"].append(f"CI observation incomplete: {error}")
                data = None
            except (ValueError, TypeError) as error:
                report["errors"].append(str(error))
                data = None
            if inspect_build:
                try:
                    build = apk_build(root / "apk")
                    report["apk_client_build"] = build
                    if build != "android:" + expected_sha:
                        report["errors"].append("APK embedded clientBuild SHA mismatch")
                except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
                    report["unknown"].append(f"APK embedded build unavailable: {error}")
            else:
                report["unverified"].append("APK_embedded_build")
            if candidate_report:
                candidate = json.loads(Path(candidate_report).read_text(encoding="utf-8"))
                if candidate.get("ok") is not True or candidate.get("expected") != report["expected"]:
                    report["errors"].append("Candidate verification failed or expected SHA/run differs")
                def hashes(value):
                    entries = {item["filename"]: (item["size_bytes"], item["sha256"]) for item in value["assets"]}
                    if len(entries) != len(value["assets"]):
                        raise ValueError("Duplicate candidate asset name")
                    entries["update.json"] = (value["manifest"]["size_bytes"], value["manifest"]["sha256"])
                    return entries
                actual, reviewed = hashes(report), hashes(candidate)
                report["candidate_comparison"] = {"candidate_report": str(candidate_report), "asset_count": len(actual),
                                                  "same_bytes": actual == reviewed}
                if actual != reviewed:
                    report["errors"].append("Public bytes differ from verified candidate")
                report["latest_manifest"] = fetch(latest_manifest, root / "latest.json", 64 * 1024)
                if report["latest_manifest"]["sha256"] != report["manifest"]["sha256"]:
                    report["errors"].append("Latest and version manifest bytes differ")
                if data is not None:
                    try:
                        report["public_release"] = public = public_release(data, release_tag)
                        if public["sha"] != expected_sha:
                            report["errors"].append("Public tag target SHA mismatch")
                        if public["version_code"] != report["version_code"]:
                            report["errors"].append("Public tag and manifest version code differ")
                        assets = data["release"]["assets"]
                        names = [item["name"] for item in assets]
                        if len(set(names)) != len(names) or set(names) != set(actual):
                            report["errors"].append("Public release asset set differs from candidate")
                        for item in assets:
                            if item["name"] not in actual:
                                continue
                            size, digest = actual[item["name"]]
                            if not item.get("digest"):
                                report["unknown"].append(f"GitHub digest unavailable: {item['name']}")
                            elif item["size"] != size or item["digest"] != "sha256:" + digest:
                                report["errors"].append(f"Public release metadata mismatch: {item['name']}")
                        sources = {item["filename"]: item["source"] for item in report["assets"]}
                        sources["update.json"] = manifest_source
                        urls = {item["name"]: item.get("browser_download_url") for item in assets}
                        advertised = {"rune-nexus.apk": manifest.get("apkUrl")}
                        advertised.update({f"patch-from-{item['fromVersionCode']}.rndelta": item.get("url") for item in patches})
                        for name, advertised_url in advertised.items():
                            if not github_url_identity(advertised_url) or github_url_identity(advertised_url) != github_url_identity(urls.get(name)):
                                report["errors"].append(f"Manifest download URL missing or differs from public asset: {name}")
                        report["public_downloads"] = []
                        for name, source in sources.items():
                            if not urllib.parse.urlsplit(source).scheme:
                                report["unknown"].append(f"Public download not observed for local input: {name}")
                                status = "unknown"
                            elif not github_url_identity(source) or github_url_identity(source) != github_url_identity(urls.get(name)):
                                report["errors"].append(f"Explicit public URL differs from release asset: {name}")
                                status = "fail"
                            else:
                                status = "pass"
                            report["public_downloads"].append({"name": name, "source": source, "status": status})
                        github_repo = repository or data.get("github_repo")
                        latest_urls = {github_url_identity(urls.get("update.json"))}
                        if github_repo:
                            latest_urls.add(github_url_identity(f"https://github.com/{github_repo}/releases/latest/download/update.json"))
                        if not urllib.parse.urlsplit(latest_manifest).scheme:
                            report["unknown"].append("Latest manifest public download not observed for local input")
                        elif not github_url_identity(latest_manifest) or github_url_identity(latest_manifest) not in latest_urls:
                            report["errors"].append("Explicit latest manifest URL is not bound to this release/repository")
                    except KeyError as error:
                        report["unknown"].append(f"Public release observation incomplete: {error}")
                    except (ValueError, TypeError) as error:
                        report["errors"].append(str(error))
                else:
                    report["unknown"].append("Public release identity unavailable")
                if "release_scope" in candidate:
                    report["release_scope"] = candidate["release_scope"]
        elif inspect_build:
            raise ValueError("--inspect-apk-build requires expected SHA/run")
        report["status"] = "fail" if report["errors"] else "unknown" if report["unknown"] else "pass"
        report["ok"] = report["status"] == "pass"
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
    v.add_argument("--expected-sha")
    v.add_argument("--expected-run-id")
    v.add_argument("--run-info", type=Path, help="Saved observation containing raw GitHub run object")
    v.add_argument("--github-repo")
    v.add_argument("--inspect-apk-build", action="store_true")
    v.add_argument("--plan-report", type=Path)
    v.add_argument("--candidate-report", type=Path)
    v.add_argument("--release-info", type=Path)
    v.add_argument("--release-tag")
    v.add_argument("--latest-manifest")
    s = commands.add_parser("snapshot")
    s.add_argument("--repo", type=Path, default=Path("."))
    s.add_argument("--target", required=True)
    s.add_argument("--local-ref", default="HEAD")
    s.add_argument("--remote-ref", default="origin/main")
    s.add_argument("--github-repo")
    s.add_argument("--release-info", type=Path)
    s.add_argument("--expected-baseline")
    s.add_argument("--server-baseline")
    s.add_argument("--server-evidence")
    w = commands.add_parser("wait")
    w.add_argument("--github-repo", required=True)
    w.add_argument("--run-id", required=True)
    w.add_argument("--expected-sha", required=True)
    w.add_argument("--log", type=Path, required=True)
    w.add_argument("--timeout", type=float, default=1800)
    w.add_argument("--interval", type=int, default=30)
    for command in (p, v, s, w):
        command.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            report = plan(args.repo, args.baseline, args.target)
        elif args.command == "snapshot":
            report = snapshot(args.repo, args.target, args.local_ref, args.remote_ref, args.github_repo,
                              args.release_info, args.expected_baseline, args.server_baseline, args.server_evidence)
        elif args.command == "wait":
            from release_ci_wait import wait_run
            report = wait_run(args.github_repo, args.run_id, args.expected_sha, args.log, args.timeout, args.interval)
        else:
            patches = {}
            for item in args.patch:
                code, source = item.split("=", 1)
                code = int(code)
                if code in patches or not source:
                    raise ValueError("Duplicate patch code or empty source")
                patches[code] = source
            report = verify(args.manifest, args.apk, patches, args.audit_godot_pack, args.baseline_apk,
                            args.expected_sha, args.expected_run_id, args.run_info, args.github_repo,
                            args.candidate_report, args.release_info, args.release_tag, args.latest_manifest,
                            args.inspect_apk_build, args.plan_report)
    except (OSError, subprocess.TimeoutExpired) as error:
        report = {"operation": args.command, "ok": False, "status": "unknown", "unknown": [str(error)]}
    except (ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        report = {"operation": args.command, "ok": False, "errors": [str(error)]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{args.command}: {report.get('status', 'pass' if report['ok'] else 'fail').upper()}; details: {args.output}")
    if args.command == "plan" and report["ok"]:
        print(f"{report['baseline_sha'][:12]} → {report['target_sha'][:12]}; changed files: {len(report['changed_paths'])}; dirty: {report['dirty']}")
    elif args.command == "verify" and report["ok"]:
        print(f"Verified {len(report['assets'])} asset(s); see JSON for checked and unverified scope.")
    elif not report["ok"]:
        print("Inspection failed; see JSON errors. This is not deployment approval.")
    if "apk_size_comparison" in report:
        delta = report["apk_size_comparison"]
        print(f"APK size: {delta['baseline_bytes']} → {delta['target_bytes']} bytes; delta {delta['delta_bytes']:+d} ({delta['delta_percent']:+.2f}%).")
    return 0 if report["ok"] else 2 if report.get("status") == "unknown" else 1


if __name__ == "__main__":
    raise SystemExit(main())
