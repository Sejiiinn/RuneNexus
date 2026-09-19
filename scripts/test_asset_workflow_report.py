import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from asset_workflow_report import CATALOG, collect


class AssetWorkflowReportTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        recipe = {"source": "source.blend", "guide": "guide.md",
                  "steps": [{"script": "bake.py"}], "outputs": ["asset.glb"],
                  "checks": ["verify.gd"], "records": ["old-result.json"]}
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


if __name__ == "__main__":
    unittest.main()
