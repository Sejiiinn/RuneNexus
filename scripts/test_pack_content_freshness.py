"""A cached pack cannot bypass authoring-source freshness checks."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import build_godot_pack as pack


class PackContentFreshnessTests(unittest.TestCase):
    def test_cached_pack_rejects_an_edited_unlock_registry(self):
        with tempfile.TemporaryDirectory(prefix="pack-progression-test-") as directory:
            root = Path(directory)
            source = root / "godot/content/source"
            shutil.copytree(pack.ROOT / "godot/content/source", source)
            for relative in ("godot/content/game_content.json", "godot/content/generated_progression.gd",
                             "server/internal/progression/generated.go"):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(pack.ROOT / relative, target)
            registry_path = source / "progression.json"
            registry = json.loads(registry_path.read_text())
            registry["requirements"]["turret"]["sniper"] = 4
            registry_path.write_text(json.dumps(registry))
            cached_pack, stamp = root / "cached.pck", root / "pack-inputs.json"
            cached_pack.write_bytes(b"previous valid pack")
            stamp.write_text(json.dumps({"inputs": "cached"}))
            with patch.object(pack, "ROOT", root), patch.object(pack, "PACK", cached_pack), \
                    patch.object(pack, "STAMP", stamp), patch.object(pack, "input_digest", return_value="cached") as digest, \
                    patch.object(pack, "run") as run:
                with self.assertRaisesRegex(ValueError, "Stale progression"):
                    pack.main()
                digest.assert_not_called()
                run.assert_not_called()
            self.assertEqual(cached_pack.read_bytes(), b"previous valid pack")

    def test_cached_pack_rejects_an_edited_source_before_cache_lookup(self):
        with tempfile.TemporaryDirectory(prefix="pack-content-test-") as directory:
            root = Path(directory)
            source = root / "godot/content/source"
            shutil.copytree(pack.ROOT / "godot/content/source", source)
            shutil.copy2(pack.ROOT / "godot/content/game_content.json", source.parent / "game_content.json")
            stage_path = source / "stages/001.json"
            stage = json.loads(stage_path.read_text())
            stage["waves"][0]["clearRewardGold"] += 1
            stage_path.write_text(json.dumps(stage))
            cached_pack, stamp = root / "cached.pck", root / "pack-inputs.json"
            cached_pack.write_bytes(b"previous valid pack")
            stamp.write_text(json.dumps({"inputs": "cached"}))
            with patch.object(pack, "ROOT", root), patch.object(pack, "PACK", cached_pack), \
                    patch.object(pack, "STAMP", stamp), patch.object(pack, "input_digest", return_value="cached") as digest, \
                    patch.object(pack, "run") as run:
                with self.assertRaisesRegex(ValueError, "stale"):
                    pack.main()
                digest.assert_not_called()
                run.assert_not_called()
            self.assertEqual(cached_pack.read_bytes(), b"previous valid pack")


if __name__ == "__main__":
    unittest.main()
