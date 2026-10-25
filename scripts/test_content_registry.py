import json
import shutil
import tempfile
import unittest
from pathlib import Path

from compile_content_registry import GODOT_TARGET, ROOT, TARGET, compile_registry, generated_output


class ContentRegistryTests(unittest.TestCase):
    def test_generated_server_registry_matches_sources(self):
        compile_registry(check=True)

    def test_core_damage_range_is_part_specific(self):
        output = generated_output()
        self.assertIn('"core": {\n\t\t"damageIncrease": {"normal": {5, 8}, "magic": {9, 15}, "rare": {16, 24}, "unique": {25, 36}},', output)
        self.assertIn('"damageIncrease": {"normal": {4, 7}, "magic": {8, 13}, "rare": {14, 21}, "unique": {22, 30}},', output)

    def _copy_sources(self, root: Path) -> None:
        for relative in ['godot/content/source/turrets.json', 'godot/content/growth_content.json', TARGET, GODOT_TARGET]:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)

    def test_new_gem_regenerates_without_manual_server_edit(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self._copy_sources(root)
            growth_path = root / 'godot/content/growth_content.json'
            growth = json.loads(growth_path.read_text())
            growth['gems'].append('futureGem')
            growth_path.write_text(json.dumps(growth))
            with self.assertRaises(ValueError):
                compile_registry(root, check=True)
            compile_registry(root)
            self.assertIn('"poisonDamage", "futureGem"}', (root / TARGET).read_text())
            self.assertIn('"poisonDamage","futureGem"]', (root / GODOT_TARGET).read_text())
            compile_registry(root, check=True)

    def test_turret_identity_drift_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self._copy_sources(root)
            source_path = root / 'godot/content/source/turrets.json'
            source = json.loads(source_path.read_text())
            source['futureTower'] = source['arrow']
            source_path.write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError, 'Turret identities'):
                generated_output(root)


if __name__ == '__main__':
    unittest.main()
