#!/usr/bin/env python3
"""Regress ordinal materialization, fixed contracts and rejecting invalid content."""
import contextlib
import copy
import io
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from apply_stage_expansion import ROOT, materialize
from stage_progression import stage_ordinals
import verify_godot_content

FIELDS = ('maxHp', 'maxShield', 'maxArmor')


class StageDurabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.content = json.loads((ROOT / 'godot/content/game_content.json').read_text())
        cls.ordinals = stage_ordinals()

    def verify_content(self, game):
        reader = verify_godot_content.read
        with patch.object(verify_godot_content, 'read', side_effect=lambda path:
                          game if path == 'godot/content/game_content.json' else reader(path)):
            with contextlib.redirect_stdout(io.StringIO()):
                verify_godot_content.verify()

    def test_every_fixed_stage_round_and_enemy_uses_ordinal(self):
        self.assertEqual(len(self.content['enemyDefinitions']), 8)
        self.assertEqual([s['id'] for s in self.content['stages']], list(range(1, 26)))
        count = 0
        for stage in self.content['stages']:
            self.assertEqual([w['round'] for w in stage['waves']], list(range(1, 41)))
            for wave in stage['waves']:
                factor = 2 ** ((wave['round'] - 1) / 10) * 1.15 ** (self.ordinals[stage['id']] - 1)
                self.assertEqual(set(wave['enemyDurability']), set(self.content['enemyDefinitions']))
                for kind, base in self.content['enemyDefinitions'].items():
                    for field in FIELDS:
                        self.assertTrue(math.isclose(wave['enemyDurability'][kind][field],
                                                   base[field] * factor, rel_tol=1e-12, abs_tol=1e-12),
                                        (stage['id'], wave['round'], kind, field))
                    count += 1
        self.assertEqual(count, 25 * 40 * 8)

    def test_adjacent_logical_stages_have_fifteen_percent_growth(self):
        order = list(self.ordinals)
        # Regression anchors cross the inserted and original chapter boundaries.
        for a, b in ((5, 16), (20, 6), (10, 21), (25, 11)):
            self.assertEqual(self.ordinals[b], self.ordinals[a] + 1)
        by_id = {s['id']: s for s in self.content['stages']}
        for first, second in zip(order, order[1:]):
            for a, b in zip(by_id[first]['waves'], by_id[second]['waves']):
                for kind, definition in self.content['enemyDefinitions'].items():
                    for field in FIELDS:
                        if definition[field] > 0:
                            self.assertAlmostEqual(b['enemyDurability'][kind][field] /
                                                   a['enemyDurability'][kind][field], 1.15, places=12)

    def test_rebuild_is_idempotent_and_does_not_mutate_input(self):
        original = copy.deepcopy(self.content)
        rebuilt = materialize(original)
        self.assertEqual(original, self.content)
        self.assertEqual(rebuilt, self.content)
        self.assertEqual(materialize(rebuilt), rebuilt)

    def test_old_id_scaling_is_replaced_without_changing_other_contracts(self):
        legacy = copy.deepcopy(self.content)
        for stage in legacy['stages']:
            if stage['id'] > 15:
                continue
            for wave in stage['waves']:
                factor = 2 ** ((wave['round'] - 1) / 10) * 1.15 ** (stage['id'] - 1)
                for kind, definition in legacy['enemyDefinitions'].items():
                    wave['enemyDurability'][kind] = {f: float(definition[f] * factor) for f in FIELDS}
        repaired = materialize(legacy)
        self.verify_content(repaired)
        for old, new in zip(legacy['stages'], repaired['stages']):
            for a, b in zip(old['waves'], new['waves']):
                if old['id'] <= 5 or old['id'] >= 16:
                    self.assertEqual(a['enemyDurability'], b['enemyDurability'])
                a.pop('enemyDurability')
                b.pop('enemyDurability')
        self.assertEqual(legacy, repaired)

    def test_incomplete_and_duplicate_existing_ids_are_rejected(self):
        missing = copy.deepcopy(self.content)
        missing['stages'] = [s for s in missing['stages'] if s['id'] != 6]
        duplicate = copy.deepcopy(self.content)
        duplicate['stages'].append(copy.deepcopy(duplicate['stages'][0]))
        for game in (missing, duplicate):
            with self.assertRaises(ValueError):
                materialize(game)
            with self.assertRaises(ValueError):
                self.verify_content(game)

    def test_wrong_old_id_scaling_and_missing_durability_are_rejected(self):
        for field in FIELDS:
            for kind in ('normal', 'shielded', 'armored'):
                game = copy.deepcopy(self.content)
                game['stages'][5]['waves'][39]['enemyDurability'][kind][field] += 1.0
                with self.assertRaises(ValueError):
                    self.verify_content(game)
        game = copy.deepcopy(self.content)
        del game['stages'][24]['waves'][39]['enemyDurability']['forgeBoss']
        with self.assertRaises(ValueError):
            self.verify_content(game)

    def test_progression_authority_rejects_duplicate_or_missing_ids(self):
        with tempfile.TemporaryDirectory(prefix='stage-order-test-') as temp:
            root = Path(temp)
            path = root / 'godot/content/stage_progression.gd'
            path.parent.mkdir(parents=True)
            for order in (list(range(1, 25)), list(range(1, 25)) + [24]):
                path.write_text('const ORDER := ' + repr(order) + '\n')
                with self.assertRaises(ValueError):
                    stage_ordinals(root)


if __name__ == '__main__':
    unittest.main()
