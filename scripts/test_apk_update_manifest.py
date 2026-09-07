import hashlib
import json
import random
import zipfile
from pathlib import Path
import tempfile
import unittest

from create_apk_update_manifest import create_manifest


class ApkManifestTest(unittest.TestCase):
    def test_manifest_points_to_versioned_apk_and_hashes_actual_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(b"apk contents")
            manifest = create_manifest(apk, 12, "0.2.0", "Sejiiinn/RuneNexus", "수정", ["apk-11"])
            self.assertEqual(manifest["sha256"], hashlib.sha256(apk.read_bytes()).hexdigest())
            self.assertEqual(manifest["sizeBytes"], 12)
            self.assertEqual(manifest["apkUrl"], "https://github.com/Sejiiinn/RuneNexus/releases/download/apk-12/rune-nexus.apk")
            self.assertEqual(manifest["packageName"], "com.example.rune_nexus")

    def test_reused_and_lower_version_codes_are_rejected(self):
        for code in [8, 9]:
            with self.subTest(code=code), self.assertRaises(ValueError):
                create_manifest(Path("unused.apk"), code, "0.2.0", "owner/repo", "", ["apk-9"])

    def test_manifest_limit_counts_utf8_bytes_including_trailing_newline(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            apk.write_bytes(b"apk")
            empty = create_manifest(apk, 2, "0.2.0", "owner/repo", "", [])
            overhead = len((json.dumps(empty, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
            remaining = 65536 - overhead
            notes = "한" * (remaining // 3) + "x" * (remaining % 3)
            exact = create_manifest(apk, 2, "0.2.0", "owner/repo", notes, [])
            self.assertEqual(len((json.dumps(exact, ensure_ascii=False, indent=2) + "\n").encode("utf-8")), 65536)
            with self.assertRaisesRegex(ValueError, "64 KiB"):
                create_manifest(apk, 2, "0.2.0", "owner/repo", notes + "x", [])

    def test_oversized_apk_is_rejected_before_hashing(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "app.apk"
            with apk.open("wb") as stream:
                stream.truncate(512 * 1024 * 1024 + 1)
            with self.assertRaisesRegex(ValueError, "512 MiB"):
                create_manifest(apk, 2, "0.2.0", "owner/repo", "", [])

    def test_out_of_android_range_is_rejected(self):
        for code in [0, 2_100_000_001]:
            with self.subTest(code=code), self.assertRaises(ValueError):
                create_manifest(Path("unused.apk"), code, "0.2.0", "owner/repo", "", [])


class DifferentialManifestTest(unittest.TestCase):
    def make_release(self, directory, payload):
        base = directory / "apk-1"
        base.mkdir()
        apk = base / "rune-nexus.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            archive.writestr("assets/image.bin", payload)
        metadata = create_manifest(apk, 1, "0.1.0", "owner/repo", "", [])
        (base / "update.json").write_text(json.dumps(metadata), encoding="utf-8")
        return base

    def test_matching_base_publishes_verified_versioned_patch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = random.Random(42).randbytes(16384)
            base = self.make_release(root, payload)
            apk = root / "target.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("assets/image.bin", payload)
                archive.writestr("classes.dex", b"updated")
            result = create_manifest(apk, 2, "0.2.0", "owner/repo", "", ["apk-1"], [base], root / "output")
            patch = result["patches"][0]
            self.assertEqual(patch["fromVersionCode"], 1)
            self.assertEqual(patch["format"], "rune-apk-delta-v1")
            self.assertEqual(patch["url"], "https://github.com/owner/repo/releases/download/apk-2/patch-from-1.rndelta")
            actual = (root / "output" / "patch-from-1.rndelta").read_bytes()
            self.assertEqual(patch["sizeBytes"], len(actual))
            self.assertEqual(patch["sha256"], hashlib.sha256(actual).hexdigest())

    def test_inefficient_patch_keeps_full_apk_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = self.make_release(root, random.Random(1).randbytes(16384))
            apk = root / "target.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("assets/image.bin", random.Random(2).randbytes(16384))
            result = create_manifest(apk, 2, "0.2.0", "owner/repo", "", ["apk-1"], [base], root / "output")
            self.assertNotIn("patches", result)
            self.assertEqual(list((root / "output").iterdir()), [])

    def test_base_hash_mismatch_aborts_instead_of_publishing_patch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = self.make_release(root, b"original")
            apk = root / "target.apk"
            apk.write_bytes((base / "rune-nexus.apk").read_bytes())
            metadata = json.loads((base / "update.json").read_text())
            metadata["sha256"] = "0" * 64
            (base / "update.json").write_text(json.dumps(metadata))
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                create_manifest(apk, 2, "0.2.0", "owner/repo", "", ["apk-1"], [base], root / "output")

    def test_base_tag_and_manifest_version_must_agree(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = self.make_release(root, b"original")
            apk = root / "target.apk"
            apk.write_bytes((base / "rune-nexus.apk").read_bytes())
            metadata = json.loads((base / "update.json").read_text())
            metadata["versionCode"] = 9
            (base / "update.json").write_text(json.dumps(metadata))
            with self.assertRaisesRegex(ValueError, "Invalid metadata"):
                create_manifest(apk, 2, "0.2.0", "owner/repo", "", ["apk-1"], [base], root / "output")


if __name__ == "__main__":
    unittest.main()
