"""Isolated release report fixtures; no network, real deployment, or game edits."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile
from unittest.mock import patch

from release_report import main, plan, verify
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


if __name__ == "__main__":
    unittest.main()
