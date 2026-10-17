import json
from pathlib import Path
import unittest
import tempfile
import shutil

from compile_gem_capabilities import ROOT, compile_capabilities, generated_output


class GemCapabilityTests(unittest.TestCase):
    def test_generated_server_matches_sources(self):
        compile_capabilities(check=True)
        self.assertIn('func Allows(turret, gem string)', generated_output())

    def test_turret_capabilities_match_growth_rules(self):
        turrets = json.loads((ROOT / 'godot/content/source/turrets.json').read_text())
        rules = json.loads((ROOT / 'godot/content/growth_content.json').read_text())['turretRules']
        for key, turret in turrets.items():
            actual = turret['configuration']['statInput']['definition'].get('attackCapabilities', [])
            self.assertEqual(actual, rules[key].get('attackCapabilities', []), key)
            self.assertEqual(actual, ['projectile'] if key in ('arrow', 'cannon', 'magic') else [], key)

    def test_future_tower_projection_and_readonly_check(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in ['godot/content/source/turrets.json', 'godot/content/growth_content.json',
                             'godot/content/gem_capabilities.json', 'server/internal/gemcapabilities/generated.go']:
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            source_path = root / 'godot/content/source/turrets.json'
            source = json.loads(source_path.read_text())
            source['futureTower'] = {'configuration': {'statInput': {'definition': {'attackCapabilities': ['projectile']}}}}
            source_path.write_text(json.dumps(source))
            growth_path = root / 'godot/content/growth_content.json'
            before = growth_path.read_bytes()
            with self.assertRaises(ValueError):
                compile_capabilities(root, check=True)
            self.assertEqual(before, growth_path.read_bytes())
            compile_capabilities(root)
            self.assertEqual(json.loads(growth_path.read_text())['turretRules']['futureTower']['attackCapabilities'], ['projectile'])
            self.assertIn('"futureTower": {"projectile"}', generated_output(root))
            compile_capabilities(root, check=True)

    def test_piercing_requirement_is_distinct(self):
        metadata = json.loads((ROOT / 'godot/content/gem_capabilities.json').read_text())
        self.assertEqual(metadata['gemRequirements']['piercing'], ['projectile'])
        self.assertNotIn('armorPiercing', metadata['gemRequirements'])
        gems = json.loads((ROOT / 'godot/content/growth_content.json').read_text())['gems']
        self.assertIn('piercing', gems)
        self.assertIn('armorPiercing', gems)


if __name__ == '__main__':
    unittest.main()
