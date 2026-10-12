"""Isolated release report fixtures; no network, real deployment, or game edits."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import struct
import tempfile
import unittest
import zipfile
from unittest.mock import patch

from release_report import main, plan, verify, snapshot, observation
from test_apk_pack_audit import pack_fixture


class ReleaseReportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.apk = self.root / "rune.apk"
        self.apk.write_bytes(b"fixture APK bytes")
        self.patch = self.root / "patch.bin"
        self.patch.write_bytes(b"fixture patch bytes")
        self.manifest = self.root / "update.json"
        self.data = {"schemaVersion": 1, "versionCode": 2, "versionName": "0.1.2",
                     "apkUrl": "https://github.com/owner/repo/releases/download/apk-2/rune-nexus.apk",
                     **self.metadata(self.apk)}
        self.save()

    def metadata(self, path):
        data = path.read_bytes()
        return {"sizeBytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

    def save(self):
        self.manifest.write_text(json.dumps(self.data))

    def test_local_integrity_and_tampering(self):
        report = verify(str(self.manifest), str(self.apk), {})
        self.assertTrue(report["ok"])
        self.apk.write_bytes(b"changed same size!")
        report = verify(str(self.manifest), str(self.apk), {})
        self.assertFalse(report["ok"])
        self.assertEqual(report["errors"], ["Integrity mismatch: apk"])

    def test_manifest_urls_are_not_implicitly_fetched_and_missing_patch_fails(self):
        self.data["apkUrl"] = "https://example.invalid/unrequested.apk"
        self.data["patches"] = [{"fromVersionCode": 1, "url": "https://example.invalid/patch", **self.metadata(self.patch)}]
        self.save()
        with patch("urllib.request.urlopen", side_effect=AssertionError("Unexpected network")):
            self.assertFalse(verify(str(self.manifest), str(self.apk), {})["ok"])
            report = verify(str(self.manifest), str(self.apk), {1: str(self.patch)})
            self.assertTrue(report["ok"])
            self.assertEqual(len(report["assets"]), 2)

    def test_duplicate_patch_manifest_rejected(self):
        item = {"fromVersionCode": 1, **self.metadata(self.patch)}
        self.data["patches"] = [item, item]
        self.save()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            verify(str(self.manifest), str(self.apk), {1: str(self.patch)})

    def test_cli_writes_failure_json_and_nonzero(self):
        self.apk.write_bytes(b"wrong")
        output = self.root / "report.json"
        with contextlib.redirect_stdout(io.StringIO()) as stdout:
            code = main(["verify", "--manifest", str(self.manifest), "--apk", str(self.apk), "--output", str(output)])
        self.assertEqual(code, 1)
        self.assertFalse(json.loads(output.read_text())["ok"])
        self.assertLessEqual(len(stdout.getvalue().splitlines()), 3)

    def test_malformed_manifest_writes_failure_json(self):
        self.manifest.write_text("[]")
        output = self.root / "report.json"
        with contextlib.redirect_stdout(io.StringIO()):
            code = main(["verify", "--manifest", str(self.manifest), "--apk", str(self.apk), "--output", str(output)])
        self.assertEqual(code, 1)
        self.assertTrue(json.loads(output.read_text())["errors"])

    def test_explicit_url_download_is_streamed(self):
        with patch("urllib.request.urlopen", return_value=io.BytesIO(self.apk.read_bytes())) as fetch:
            report = verify(str(self.manifest), "https://example.invalid/explicit.apk", {})
        self.assertTrue(report["ok"])
        fetch.assert_called_once_with("https://example.invalid/explicit.apk", timeout=45)

    def test_optional_pack_audit_uses_existing_parser(self):
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("assets/game.pck", pack_fixture())
        self.data.update(self.metadata(self.apk))
        self.save()
        report = verify(str(self.manifest), str(self.apk), {}, audit=True)
        self.assertTrue(report["ok"])
        self.assertEqual(report["godot_pack_audit"]["entry_count"], 2)
        self.assertEqual(report["godot_pack_audit"]["logical_duplicate_bytes"], 12)
        self.assertEqual(report["godot_pack_audit"]["source"], str(self.apk))

    def test_baseline_size_comparison_reports_growth_and_removal(self):
        baseline = self.root / "baseline.apk"
        with zipfile.ZipFile(baseline, "w") as archive:
            archive.writestr("growing.bin", b"123")
            archive.writestr("removed.bin", b"remove")
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("growing.bin", b"1234567890")
            archive.writestr("added.bin", b"added")
        self.data.update(self.metadata(self.apk))
        self.save()
        report = verify(str(self.manifest), str(self.apk), {}, baseline_source=str(baseline))
        self.assertTrue(report["ok"])
        comparison = report["apk_size_comparison"]
        self.assertEqual(comparison["delta_bytes"], self.apk.stat().st_size - baseline.stat().st_size)
        entries = {item["path"]: item for item in comparison["largest_entry_changes"]}
        self.assertEqual(entries["growing.bin"]["compressed_delta_bytes"], 7)
        self.assertEqual(entries["removed.bin"]["status"], "removed")
        self.assertEqual(entries["removed.bin"]["uncompressed_delta_bytes"], -6)
        self.assertEqual(entries["added.bin"]["status"], "added")

    def test_non_zip_baseline_fails_with_json_evidence(self):
        baseline = self.root / "baseline.apk"
        baseline.write_bytes(b"not a ZIP")
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("fixture.bin", b"payload")
        self.data.update(self.metadata(self.apk))
        self.save()
        output = self.root / "report.json"
        with contextlib.redirect_stdout(io.StringIO()):
            code = main(["verify", "--manifest", str(self.manifest), "--apk", str(self.apk),
                         "--baseline-apk", str(baseline), "--output", str(output)])
        self.assertEqual(code, 1)
        self.assertFalse(json.loads(output.read_text())["ok"])

    def test_plan_committed_diff_separate_from_dirty_tree(self):
        def git(*args):
            return subprocess.check_output(["git", "-C", str(self.root), *args], text=True).strip()
        git("init", "-q")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "user.name", "Fixture")
        git("add", ".")
        git("commit", "-qm", "baseline")
        base = git("rev-parse", "HEAD")
        folder = self.root / "server" / "migrations"
        folder.mkdir(parents=True)
        (folder / "001.sql").write_text("select 1;")
        git("add", ".")
        git("commit", "-qm", "migration")
        self.apk.write_bytes(b"uncommitted")
        report = plan(self.root, base, "HEAD")
        self.assertTrue(report["dirty"])
        self.assertEqual(report["changed_paths"], ["server/migrations/001.sql"])
        self.assertEqual(report["impact_candidates"]["migration"], report["changed_paths"])
        self.assertNotEqual(report["baseline_sha"], report["target_sha"])

    def init_branch_fixture(self):
        def git(*args):
            return subprocess.check_output(["git", "-C", str(self.root), *args], text=True).strip()
        git("init", "-q")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "user.name", "Fixture")
        git("add", ".")
        git("commit", "-qm", "public baseline")
        base = git("rev-parse", "HEAD")
        (self.root / "local.txt").write_text("local")
        git("add", ".")
        git("commit", "-qm", "local only feature")
        local = git("rev-parse", "HEAD")
        git("checkout", "--detach", "-q", base)
        (self.root / "remote.txt").write_text("remote")
        git("add", ".")
        git("commit", "-qm", "remote only feature")
        remote = git("rev-parse", "HEAD")
        git("update-ref", "refs/remotes/origin/main", remote)
        git("checkout", "--detach", "-q", local)
        return base, local, remote

    def release_fixture(self, sha="a" * 40):
        return {"observed_at": "2026-10-13T00:00:00Z", "github_repo": "owner/repo", "tag_sha": sha, "latest_tag": "apk-2",
                "release": {"tag_name": "apk-2", "target_commitish": "main", "draft": False,
                            "html_url": "https://github.com/owner/repo/releases/tag/apk-2",
                            "prerelease": False, "published_at": "2026-10-12T00:00:00Z",
                            "assets": [{"name": name, "browser_download_url": "https://github.com/owner/repo/releases/download/apk-2/" + name}
                                       for name in ("update.json", "rune-nexus.apk")]},
                "run": {"id": 123, "head_sha": sha, "status": "completed", "conclusion": "success",
                        "repository": {"full_name": "owner/repo"}, "html_url": "https://github.com/owner/repo/actions/runs/123"}}

    def save_observation(self, data):
        path = self.root / "observation.json"
        path.write_text(json.dumps(data))
        return path

    def test_snapshot_separates_branches_full_scope_and_unknown_server(self):
        base, local, remote = self.init_branch_fixture()
        info = self.save_observation(self.release_fixture(base))
        with patch("release_report.github_api", side_effect=AssertionError("No network")):
            report = snapshot(self.root, local, release_info=info)
        self.assertEqual(report["apk_baseline"]["sha"], base)
        self.assertEqual(report["branches"]["merge_base"], base)
        self.assertEqual([x["sha"] for x in report["branches"]["local_only"]], [local])
        self.assertEqual([x["sha"] for x in report["branches"]["remote_only"]], [remote])
        self.assertEqual([x["sha"] for x in report["included_commits"]], [local])
        self.assertEqual([x["sha"] for x in report["excluded_commits"]], [remote])
        self.assertEqual(report["server_baseline"]["status"], "unknown")
        self.assertEqual(report["status"], "unknown")
        self.assertFalse(report["ok"])
        self.assertEqual(report["branches"]["freshness"], "local_ref_only")

    def test_snapshot_wrong_baseline_and_separate_server_baseline(self):
        base, local, remote = self.init_branch_fixture()
        info = self.save_observation(self.release_fixture(base))
        report = snapshot(self.root, local, release_info=info, expected_baseline=remote,
                          server_baseline=remote, server_evidence="explicit container image observation")
        self.assertEqual(report["status"], "fail")
        self.assertEqual(report["server_plan"]["baseline_sha"], remote)
        self.assertEqual(report["apk_plan"]["baseline_sha"], base)
        self.assertIn("Explicit baseline differs", report["errors"][0])

    def test_snapshot_network_failure_and_draft_are_unknown(self):
        base, local, _ = self.init_branch_fixture()
        with patch("release_report.github_api", side_effect=OSError("offline")):
            report = snapshot(self.root, local, repository="owner/repo")
        self.assertEqual(report["status"], "unknown")
        self.assertTrue(report["dirty"] is False)
        data = self.release_fixture(base)
        data["release"]["draft"] = True
        report = snapshot(self.root, local, release_info=self.save_observation(data))
        self.assertEqual(report["apk_baseline"]["status"], "unknown")
        self.assertNotIn("apk_plan", report)

    def test_snapshot_divergent_public_baseline_requires_review(self):
        _, local, remote = self.init_branch_fixture()
        report = snapshot(self.root, local, release_info=self.save_observation(self.release_fixture(remote)))
        self.assertEqual(report["status"], "fail")
        self.assertIn("not an ancestor", report["errors"][0])

    def test_snapshot_conflicting_latest_fails_and_missing_latest_is_unknown(self):
        base, local, _ = self.init_branch_fixture()
        for latest, expected in (("apk-3", "fail"), (None, "unknown")):
            with self.subTest(latest=latest):
                data = self.release_fixture(base)
                if latest:
                    data["latest_tag"] = latest
                else:
                    del data["latest_tag"]
                report = snapshot(self.root, local, release_info=self.save_observation(data),
                                  server_baseline=base, server_evidence="fixture")
                self.assertEqual(report["status"], expected)
                self.assertFalse(report["ok"])
                self.assertNotIn("apk_plan", report)

    def test_snapshot_raw_release_repo_mismatch_fails_even_with_valid_wrapper(self):
        base, local, _ = self.init_branch_fixture()
        data = self.release_fixture(base)
        data["release"]["html_url"] = "https://github.com/other/repo/releases/tag/apk-2"
        report = snapshot(self.root, local, repository="owner/repo", release_info=self.save_observation(data),
                          server_baseline=base, server_evidence="fixture")
        self.assertEqual(report["status"], "fail")
        self.assertIn("repository/path mismatch", report["errors"][0])

    def candidate_fixture(self):
        sha = "a" * 40
        info = self.save_observation(self.release_fixture(sha))
        candidate = verify(str(self.manifest), str(self.apk), {}, expected_sha=sha,
                           expected_run_id="123", run_info=info)
        path = self.root / "candidate.json"
        path.write_text(json.dumps(candidate))
        data = self.release_fixture(sha)
        data["release"]["assets"] = [
            {"name": "update.json", "size": candidate["manifest"]["size_bytes"],
             "browser_download_url": "https://github.com/owner/repo/releases/download/apk-2/update.json",
             "digest": "sha256:" + candidate["manifest"]["sha256"]},
            {"name": "rune-nexus.apk", "size": candidate["assets"][0]["size_bytes"],
             "browser_download_url": "https://github.com/owner/repo/releases/download/apk-2/rune-nexus.apk",
             "digest": "sha256:" + candidate["assets"][0]["sha256"]}]
        return path, self.save_observation(data), data

    def public_verify(self, candidate, info):
        prefix = "https://github.com/owner/repo/releases/download/apk-2/"
        def respond(url, timeout):
            return io.BytesIO((self.apk if url.endswith(".apk") else self.manifest).read_bytes())
        with patch("urllib.request.urlopen", side_effect=respond):
            return verify(prefix + "update.json", prefix + "rune-nexus.apk", {}, expected_sha="a" * 40,
                          expected_run_id="123", candidate_report=candidate, release_info=info,
                          release_tag="apk-2", latest_manifest="https://github.com/owner/repo/releases/latest/download/update.json")

    def test_public_verify_same_candidate_manifest_tag_run_and_asset_set(self):
        candidate, info, _ = self.candidate_fixture()
        report = self.public_verify(candidate, info)
        self.assertTrue(report["ok"])
        self.assertTrue(report["candidate_comparison"]["same_bytes"])
        self.assertEqual(report["candidate_comparison"]["asset_count"], 2)

    def test_public_mismatches_never_pass(self):
        candidate, _, original = self.candidate_fixture()
        variants = [
            ("tag SHA", lambda data: data.update(tag_sha="b" * 40)),
            ("run SHA", lambda data: data["run"].update(head_sha="b" * 40)),
            ("run ID", lambda data: data["run"].update(id=124)),
            ("latest moved", lambda data: data.update(latest_tag="apk-3")),
            ("extra asset", lambda data: data["release"]["assets"].append({"name": "extra.bin", "browser_download_url": "https://github.com/owner/repo/releases/download/apk-2/extra.bin"})),
            ("asset digest", lambda data: data["release"]["assets"][0].update(digest="sha256:" + "0" * 64)),
            ("public URL", lambda data: data["release"]["assets"][0].update(browser_download_url="https://example.invalid/update.json")),
        ]
        for name, change in variants:
            with self.subTest(name=name):
                data = json.loads(json.dumps(original))
                change(data)
                report = self.public_verify(candidate, self.save_observation(data))
                self.assertEqual(report["status"], "fail")

    def test_public_missing_digest_unknown_and_changed_candidate_bytes_fail(self):
        candidate, _, data = self.candidate_fixture()
        del data["release"]["assets"][0]["digest"]
        report = self.public_verify(candidate, self.save_observation(data))
        self.assertEqual(report["status"], "unknown")
        self.apk.write_bytes(b"valid replacement APK")
        self.data.update(self.metadata(self.apk))
        self.save()
        report = self.public_verify(candidate, self.save_observation(data))
        self.assertEqual(report["status"], "fail")
        self.assertFalse(report["candidate_comparison"]["same_bytes"])

    def test_latest_manifest_changed_bytes_fail(self):
        candidate, info, _ = self.candidate_fixture()
        latest = self.root / "latest.json"
        latest.write_text(json.dumps(self.data) + "\n")
        report = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                        expected_run_id="123", candidate_report=candidate, release_info=info,
                        release_tag="apk-2", latest_manifest=str(latest))
        self.assertIn("Latest and version manifest bytes differ", report["errors"])

    def test_local_public_bytes_do_not_claim_public_download_success(self):
        candidate, info, _ = self.candidate_fixture()
        report = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                        expected_run_id="123", candidate_report=candidate, release_info=info,
                        release_tag="apk-2", latest_manifest=str(self.manifest))
        self.assertEqual(report["status"], "unknown")
        self.assertTrue(report["candidate_comparison"]["same_bytes"])

    def test_expected_run_network_unknown_and_plan_binding(self):
        with patch("release_report.github_api", side_effect=subprocess.TimeoutExpired("gh", 45)):
            report = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                            expected_run_id="123", repository="owner/repo")
        self.assertEqual(report["status"], "unknown")
        scope = self.root / "scope.json"
        scope.write_text(json.dumps({"operation": "plan", "target_sha": "b" * 40}))
        with self.assertRaisesRegex(ValueError, "Plan report target"):
            verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                   expected_run_id="123", plan_report=scope)

    def test_full_included_excluded_scope_survives_candidate_and_public_reports(self):
        candidate, info, _ = self.candidate_fixture()
        scope = {"operation": "snapshot", "target_sha": "a" * 40, "status": "unknown", "errors": [],
                 "included_commits": [{"sha": "a" * 40, "subject": "all included changes"}],
                 "excluded_commits": [{"sha": "b" * 40, "subject": "excluded", "reason": "Not reachable"}],
                 "server_baseline": {"status": "unknown"}}
        scope_path = self.root / "scope.json"
        scope_path.write_text(json.dumps(scope))
        reviewed = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                          expected_run_id="123", run_info=info, plan_report=scope_path)
        candidate.write_text(json.dumps(reviewed))
        report = self.public_verify(candidate, info)
        self.assertTrue(report["ok"])
        self.assertEqual(report["release_scope"], scope)

    def test_expected_identity_requires_pair_and_public_explicit_inputs(self):
        with self.assertRaisesRegex(ValueError, "both"):
            verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40)
        with self.assertRaisesRegex(ValueError, "Public comparison requires"):
            verify(str(self.manifest), str(self.apk), {}, candidate_report=self.root / "candidate.json")

    def test_public_arguments_are_never_ignored_without_complete_combination(self):
        candidate, info, _ = self.candidate_fixture()
        partials = [
            {"release_tag": "apk-999", "latest_manifest": "https://unrequested.invalid/update.json", "run_info": info},
            {"release_info": info}, {"release_tag": "apk-2"}, {"latest_manifest": str(self.manifest)},
            {"candidate_report": candidate, "release_tag": "apk-2"},
            {"candidate_report": candidate, "latest_manifest": str(self.manifest)},
            {"candidate_report": candidate, "release_tag": "apk-2", "latest_manifest": str(self.manifest),
             "run_info": info, "release_info": info},
        ]
        for values in partials:
            with self.subTest(arguments=sorted(values)), patch("release_report.fetch", side_effect=AssertionError("No fetch before validation")):
                with self.assertRaises(ValueError):
                    verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40, expected_run_id="123", **values)

    def test_raw_run_repository_or_url_mismatch_fails_missing_fields_unknown(self):
        original = self.release_fixture()
        variants = [
            ("raw repository", lambda data: data["run"]["repository"].update(full_name="other/repo"), "fail"),
            ("run URL", lambda data: data["run"].update(html_url="https://github.com/other/repo/actions/runs/123"), "fail"),
            ("run URL ID", lambda data: data["run"].update(html_url="https://github.com/owner/repo/actions/runs/999"), "fail"),
            ("missing repository", lambda data: data["run"].pop("repository"), "unknown"),
            ("missing run URL", lambda data: data["run"].pop("html_url"), "unknown"),
        ]
        for name, change, expected in variants:
            with self.subTest(name=name):
                data = json.loads(json.dumps(original))
                change(data)
                report = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                                expected_run_id="123", run_info=self.save_observation(data), repository="owner/repo")
                self.assertEqual(report["status"], expected)
                self.assertFalse(report["ok"])

    def test_public_other_repository_cannot_pass_matching_foreign_urls_and_wrapper(self):
        candidate, _, data = self.candidate_fixture()
        data["run"]["repository"]["full_name"] = "other/repo"
        data["run"]["html_url"] = "https://github.com/other/repo/actions/runs/123"
        data["release"]["html_url"] = "https://github.com/other/repo/releases/tag/apk-2"
        for item in data["release"]["assets"]:
            item["browser_download_url"] = item["browser_download_url"].replace("owner/repo", "other/repo")
        prefix = "https://github.com/other/repo/releases/download/apk-2/"
        with patch("urllib.request.urlopen", side_effect=lambda url, timeout: io.BytesIO(
                (self.apk if url.endswith(".apk") else self.manifest).read_bytes())):
            report = verify(prefix + "update.json", prefix + "rune-nexus.apk", {}, expected_sha="a" * 40,
                            expected_run_id="123", candidate_report=candidate, release_info=self.save_observation(data),
                            release_tag="apk-2", latest_manifest=prefix + "update.json", repository="owner/repo")
        self.assertEqual(report["status"], "fail")
        self.assertTrue(any("repository/path mismatch" in error for error in report["errors"]))

    def test_public_raw_release_missing_url_unknown_and_asset_tag_mismatch_fails(self):
        candidate, _, original = self.candidate_fixture()
        variants = [
            (lambda data: data["release"].pop("html_url"), "unknown"),
            (lambda data: data["release"]["assets"][0].pop("browser_download_url"), "unknown"),
            (lambda data: data["release"]["assets"][0].update(browser_download_url="https://github.com/owner/repo/releases/download/apk-999/update.json"), "fail"),
        ]
        for change, expected in variants:
            data = json.loads(json.dumps(original))
            change(data)
            report = self.public_verify(candidate, self.save_observation(data))
            self.assertEqual(report["status"], expected)

    def test_public_manifest_apk_target_mismatch_or_absence_fails_legacy_integrity_preserved(self):
        for advertised in ("https://github.com/other/repo/releases/download/apk-999/rune-nexus.apk", None):
            with self.subTest(apkUrl=advertised):
                if advertised:
                    self.data["apkUrl"] = advertised
                else:
                    self.data.pop("apkUrl")
                self.save()
                self.assertTrue(verify(str(self.manifest), str(self.apk), {})["ok"])
                candidate, info, _ = self.candidate_fixture()
                report = self.public_verify(candidate, info)
                self.assertEqual(report["status"], "fail")
                self.assertIn("Manifest download URL missing or differs from public asset: rune-nexus.apk", report["errors"])

    def test_public_patch_advertised_target_is_bound_without_extra_fetch(self):
        prefix = "https://github.com/owner/repo/releases/download/apk-2/"
        name = "patch-from-1.rndelta"
        for advertised, expected in ((prefix + name, "pass"),
                                     ("https://github.com/other/repo/releases/download/apk-999/" + name, "fail"),
                                     (None, "fail")):
            with self.subTest(patchUrl=advertised):
                item = {"fromVersionCode": 1, **self.metadata(self.patch)}
                if advertised:
                    item["url"] = advertised
                self.data["patches"] = [item]
                self.save()
                self.assertTrue(verify(str(self.manifest), str(self.apk), {1: str(self.patch)})["ok"])
                data = self.release_fixture()
                info = self.save_observation(data)
                reviewed = verify(str(self.manifest), str(self.apk), {1: str(self.patch)}, expected_sha="a" * 40,
                                  expected_run_id="123", run_info=info)
                candidate = self.root / "candidate.json"
                candidate.write_text(json.dumps(reviewed))
                metadata = {"update.json": reviewed["manifest"], **{item["filename"]: item for item in reviewed["assets"]}}
                data["release"]["assets"] = [{"name": name, "size": value["size_bytes"], "digest": "sha256:" + value["sha256"],
                                               "browser_download_url": prefix + name} for name, value in metadata.items()]
                info = self.save_observation(data)
                paths = {prefix + "update.json": self.manifest, prefix + "rune-nexus.apk": self.apk, prefix + name: self.patch}
                def respond(url, timeout):
                    return io.BytesIO(paths[url].read_bytes())
                with patch("urllib.request.urlopen", side_effect=respond) as fetch:
                    report = verify(prefix + "update.json", prefix + "rune-nexus.apk", {1: prefix + name},
                                    expected_sha="a" * 40, expected_run_id="123", candidate_report=candidate,
                                    release_info=info, release_tag="apk-2", latest_manifest=prefix + "update.json")
                self.assertEqual(report["status"], expected)
                self.assertEqual(fetch.call_count, 4)
                if expected == "fail":
                    self.assertIn("Manifest download URL missing or differs from public asset: " + name, report["errors"])

    def test_live_raw_run_api_shape_and_repository_case_are_supported(self):
        run = self.release_fixture()["run"]
        run["repository"]["full_name"] = "OWNER/REPO"
        run["html_url"] = "https://github.com/OWNER/REPO/actions/runs/123"
        with patch("release_report.github_api", return_value=run) as api:
            data = observation("owner/repo", tag=False, run_id="123")
        self.assertEqual(data["run"], run)
        api.assert_called_once_with("owner/repo", "actions/runs/123")

    def test_live_observation_peels_tag_and_never_uses_moving_target_commitish(self):
        release = self.release_fixture()["release"]
        responses = [release, {"object": {"type": "tag", "sha": "b" * 40}},
                     {"object": {"type": "commit", "sha": "a" * 40}}]
        with patch("release_report.github_api", side_effect=responses) as api:
            data = observation("owner/repo")
        self.assertEqual(data["tag_sha"], "a" * 40)
        self.assertTrue(data["live_query"])
        self.assertEqual(api.call_count, 3)
        self.assertNotIn("main", [call.args[1] for call in api.call_args_list])

    def test_embedded_client_build_is_read_from_real_fixture_pack(self):
        def write_build(sha, paths, padding=""):
            payload = json.dumps({"clientBuild": "android:" + sha, "padding": padding}).encode()
            base = 112
            header = struct.pack("<6I2Q", 0x43504447, 4, 4, 7, 2, 2, base, base + len(payload))
            entries = b""
            for path in paths:
                name = path.encode()
                name += b"\0" * (-len(name) % 4)
                entries += struct.pack("<I", len(name)) + name + struct.pack("<2Q16sI", 0, len(payload), hashlib.md5(payload).digest(), 0)
            pck = header.ljust(base, b"\0") + payload + struct.pack("<I", len(paths)) + entries
            with zipfile.ZipFile(self.apk, "w") as archive:
                archive.writestr("assets/game.pck", pck)
            self.data.update(self.metadata(self.apk))
            self.save()
        info = self.save_observation(self.release_fixture())
        for path in ("app_config.json", "res://app_config.json"):
            with self.subTest(path=path):
                write_build("a" * 40, [path])
                report = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                                expected_run_id="123", run_info=info, inspect_build=True)
                self.assertTrue(report["ok"])
                self.assertEqual(report["apk_client_build"], "android:" + "a" * 40)
                write_build("b" * 40, [path])
                report = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                                expected_run_id="123", run_info=info, inspect_build=True)
                self.assertEqual(report["status"], "fail")
                self.assertIn("APK embedded clientBuild SHA mismatch", report["errors"])
        for paths, padding in ((["app_config.json", "res://app_config.json"], ""),
                               (["nested/app_config.json"], ""),
                               (["app_config.json"], "x" * (64 * 1024))):
            with self.subTest(paths=paths, oversized=bool(padding)):
                write_build("a" * 40, paths, padding)
                report = verify(str(self.manifest), str(self.apk), {}, expected_sha="a" * 40,
                                expected_run_id="123", run_info=info, inspect_build=True)
                self.assertEqual(report["status"], "unknown")
                self.assertFalse(report["ok"])

    def test_http_failure_cli_is_unknown_nonzero(self):
        output = self.root / "unknown.json"
        with patch("urllib.request.urlopen", side_effect=OSError("offline")), contextlib.redirect_stdout(io.StringIO()):
            code = main(["verify", "--manifest", "https://example.invalid/update.json", "--apk", str(self.apk),
                         "--output", str(output)])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(output.read_text())["status"], "unknown")


if __name__ == "__main__":
    unittest.main()
