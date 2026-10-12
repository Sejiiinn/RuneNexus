import hashlib
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import asset_workflow_report as reporting
from asset_workflow_report import CATALOG, collect, main


class AssetWorkflowReportTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        recipe = {"source": "source.blend", "guide": "guide.md",
                  "steps": [{"script": "bake.py", "entrypoint": "main()", "context": "fixture"}], "outputs": ["asset.glb"],
                  "checks": ["verify.gd"], "records": ["old-result.json"], "limitation": "fixture"}
        (self.root / CATALOG).parent.mkdir(parents=True)
        (self.root / CATALOG).write_text(json.dumps({"workflows": {"sample": recipe}}))
        for filename in ["source.blend", "guide.md", "bake.py", "asset.glb", "verify.gd"]:
            (self.root / filename).write_bytes(b"fixture")

    def test_present_files_do_not_certify_old_results_or_execute_scripts(self):
        (self.root / "bake.py").write_text("raise RuntimeError('must not run')")
        (self.root / "old-result.json").write_text('{"passed": true}')
        report = collect(self.root, "sample")
        self.assertEqual(report["status"], "files_present")
        self.assertEqual(report["outputs"][0]["sha256"], hashlib.sha256(b"fixture").hexdigest())
        self.assertEqual(report["validation"], "not_run")
        self.assertEqual(report["record_freshness"], "not_verified")

    def test_missing_output_is_reported_and_not_created(self):
        (self.root / "asset.glb").unlink()
        report = collect(self.root, "sample")
        self.assertEqual(report["status"], "missing_files")
        self.assertEqual(report["output_bytes"], 0)
        self.assertFalse((self.root / "asset.glb").exists())

    def test_unknown_recipe_has_no_fallback(self):
        with self.assertRaises(ValueError):
            collect(self.root, "unknown")

    def registered(self):
        catalog = json.loads((self.root / CATALOG).read_text())
        recipe = catalog["workflows"]["sample"]
        digest = hashlib.sha256(b"fixture").hexdigest()
        recipe.update(source_sha256=digest, accepted_source="source.blend",
                      accepted_source_sha256=digest,
                      runtime_outputs=[{"path": "asset.glb", "sha256": digest}],
                      record_links=[{"path": "old-result.json", "kind": "producer",
                                     "bindings": [{"target": "asset.glb",
                                                   "sha256_field": ["exports", 0, "sha256"],
                                                   "path_field": ["exports", 0, "path"]}]}],
                      runtime_references=[{"path": "loader.gd", "output": "asset.glb",
                                           "token": "res://assets/asset.glb"}])
        (self.root / CATALOG).write_text(json.dumps(catalog))
        (self.root / "old-result.json").write_text(json.dumps({"passed": True, "exports": [
            {"path": "asset.glb", "sha256": digest}]}))
        (self.root / "loader.gd").write_text('load("res://assets/asset.glb")')
        return catalog

    def save(self, catalog):
        (self.root / CATALOG).write_text(json.dumps(catalog))

    def verified(self):
        return collect(self.root, "sample", True)["record_verification"]

    def test_matched_identities_never_make_validation_pass(self):
        self.registered()
        report = collect(self.root, "sample", True)
        self.assertEqual(report["record_verification"]["status"], "matched")
        self.assertEqual(report["validation"], "not_run")
        self.assertEqual(report["record_verification"]["records"][0]["signature_verification"], "not_run")

    def test_changed_source_and_runtime_hashes_are_mismatch(self):
        self.registered()
        (self.root / "source.blend").write_bytes(b"changed source")
        (self.root / "asset.glb").write_bytes(b"changed runtime")
        report = self.verified()
        self.assertEqual(report["status"], "mismatch")
        self.assertEqual(report["source"]["reason"], "sha256_changed")
        self.assertEqual(report["runtime_outputs"][0]["reason"], "sha256_changed")

    def test_missing_source_unknown_without_creation(self):
        self.registered()
        (self.root / "source.blend").unlink()
        report = self.verified()
        self.assertEqual(report["status"], "unknown")
        self.assertEqual(report["source"]["reason"], "missing_file")
        self.assertFalse((self.root / "source.blend").exists())

    def test_unmounted_ssd_is_unknown(self):
        catalog = self.registered()
        catalog["workflows"]["sample"]["source"] = "/Volumes/asset-report-unmounted-test/source.blend"
        self.save(catalog)
        self.assertEqual(self.verified()["source"]["reason"], "unmounted_volume")

    def test_expected_sha_absence_is_unknown_even_with_old_pass_record(self):
        catalog = self.registered()
        del catalog["workflows"]["sample"]["runtime_outputs"][0]["sha256"]
        self.save(catalog)
        self.assertEqual(self.verified()["status"], "unknown")
        self.assertEqual(self.verified()["runtime_outputs"][0]["reason"], "missing_or_invalid_expected_sha256")

    def test_missing_acceptance_path_is_unknown(self):
        catalog = self.registered()
        del catalog["workflows"]["sample"]["accepted_source"]
        self.save(catalog)
        self.assertEqual(self.verified()["accepted"]["reason"], "missing_path")

    def test_record_path_difference_is_mismatch_even_when_hash_matches(self):
        self.registered()
        record = self.root / "old-result.json"
        d = json.loads(record.read_text()); d["exports"][0]["path"] = "other.glb"
        record.write_text(json.dumps(d))
        report = self.verified()
        self.assertEqual(report["status"], "mismatch")
        self.assertEqual(report["records"][0]["comparisons"][0]["reason"], "record_path_changed")

    def test_absolute_record_path_equivalent_to_repo_path_matches(self):
        self.registered()
        record = self.root / "old-result.json"
        d = json.loads(record.read_text()); d["exports"][0]["path"] = str(self.root / "asset.glb")
        record.write_text(json.dumps(d))
        self.assertEqual(self.verified()["status"], "matched")

    def test_missing_or_malformed_record_is_unknown(self):
        self.registered()
        record = self.root / "old-result.json"
        record.unlink()
        self.assertEqual(self.verified()["records"][0]["reason"], "missing_record")
        record.write_text("invalid json")
        self.assertEqual(self.verified()["records"][0]["reason"], "unreadable_record")

    def test_prose_review_without_hash_binding_is_unknown(self):
        catalog = self.registered()
        catalog["workflows"]["sample"]["record_links"][0].pop("bindings")
        self.save(catalog)
        self.assertEqual(self.verified()["records"][0]["reason"], "no_identity_binding")
        self.assertEqual(self.verified()["status"], "unknown")

    def test_missing_record_field_unknown_but_wrong_path_still_mismatch(self):
        self.registered()
        record = self.root / "old-result.json"
        record.write_text(json.dumps({"exports": [{"path": "other.glb"}]}))
        self.assertEqual(self.verified()["status"], "mismatch")
        record.write_text(json.dumps({"exports": [{"path": "asset.glb"}]}))
        self.assertEqual(self.verified()["status"], "unknown")

    def test_recipe_runtime_and_loader_disagreement_is_mismatch(self):
        catalog = self.registered()
        catalog["workflows"]["sample"]["outputs"] = ["other.glb"]
        (self.root / "other.glb").write_bytes(b"fixture")
        self.save(catalog)
        self.assertEqual(self.verified()["status"], "mismatch")
        self.registered()
        (self.root / "loader.gd").write_text('load("res://assets/other.glb")')
        self.assertEqual(self.verified()["runtime_references"][0]["reason"], "loader_token_missing")

    def test_legacy_approved_source_hash_is_used(self):
        catalog = self.registered()
        recipe = catalog["workflows"]["sample"]
        recipe["approved_source"] = recipe.pop("accepted_source")
        recipe["approved_source_sha256"] = recipe.pop("accepted_source_sha256")
        self.save(catalog)
        self.assertEqual(self.verified()["accepted"]["status"], "matched")

    def test_cli_exit_codes_distinguish_unknown_from_mismatch(self):
        self.registered()
        with patch.object(reporting, "ROOT", self.root), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(["sample", "--verify-records"]), 0)
            (self.root / "old-result.json").unlink()
            self.assertEqual(main(["sample", "--verify-records"]), 2)
            (self.root / "asset.glb").write_bytes(b"changed")
            self.assertEqual(main(["sample", "--verify-records"]), 1)
            self.assertEqual(main(["sample"]), 0)

    def test_existing_record_can_own_expected_hash_without_catalog_duplication(self):
        catalog = self.registered()
        recipe = catalog["workflows"]["sample"]
        recipe["expected_hashes_from_records"] = True
        del recipe["runtime_outputs"][0]["sha256"]
        self.save(catalog)
        report = self.verified()
        self.assertEqual(report["status"], "matched")
        self.assertEqual(report["runtime_outputs"][0]["expected_record"]["path"], "old-result.json")
        (self.root / "old-result.json").unlink()
        self.assertEqual(self.verified()["status"], "unknown")

    def test_record_links_and_outputs_supply_paths_without_duplicate_lists(self):
        catalog = self.registered()
        recipe = catalog["workflows"]["sample"]
        recipe["expected_hashes_from_records"] = True
        del recipe["runtime_outputs"]
        del recipe["records"]
        self.save(catalog)
        report = collect(self.root, "sample", True)
        self.assertEqual(report["record_verification"]["status"], "matched")
        self.assertEqual(report["records"][0]["path"], "old-result.json")
        self.assertEqual(report["record_verification"]["runtime_outputs"][0]["path"], "asset.glb")

    def test_conflicting_receipt_hashes_remain_mismatch(self):
        catalog = self.registered()
        recipe = catalog["workflows"]["sample"]
        recipe["expected_hashes_from_records"] = True
        del recipe["runtime_outputs"][0]["sha256"]
        recipe["record_links"].append({"path": "conflicting.json", "kind": "review", "bindings": [
            {"target": "asset.glb", "sha256_field": ["sha256"]}]})
        (self.root / "conflicting.json").write_text(json.dumps({"sha256": "0" * 64}))
        self.save(catalog)
        self.assertEqual(self.verified()["status"], "mismatch")

    def test_unreadable_runtime_unknown_and_one_hash_read_per_file(self):
        self.registered()
        original = reporting.file_info
        def inaccessible(root, path, with_hash=False):
            if path == "asset.glb":
                raise PermissionError("fixture denied")
            return original(root, path, with_hash)
        with patch.object(reporting, "file_info", side_effect=inaccessible):
            report = self.verified()
        self.assertEqual(report["status"], "unknown")
        self.assertEqual(report["runtime_outputs"][0]["reason"], "unreadable_file")
        with patch.object(reporting, "file_info", wraps=original) as observed:
            self.verified()
        self.assertEqual(sum(1 for call in observed.call_args_list if call.args == (self.root, "asset.glb", True)), 1)


if __name__ == "__main__":
    unittest.main()
