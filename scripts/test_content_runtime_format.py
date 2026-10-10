#!/usr/bin/env python3
"""Exercise generated storage boundaries independently of source generation."""
import copy
from content_test_helpers import without_dispatch_metadata
import json
from pathlib import Path
import tempfile
import unittest

from content_compiler import ROOT, compile_content, read_json, typed_digest
from content_runtime_format import (decode_runtime, encode_runtime,
                                    load_compiled_content, runtime_text, schedule_digest)


class RuntimeFormatTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.domain = compile_content()
        cls.runtime = encode_runtime(cls.domain)

    def test_schedule_identity_preserves_bits_types_and_order(self):
        queue = [{'enemyType': 'normal', 'delay': 0.0}, {'enemyType': '보스', 'delay': 0.18}]
        self.assertNotEqual(schedule_digest(queue), schedule_digest(list(reversed(queue))))
        minus_zero = copy.deepcopy(queue)
        minus_zero[0]['delay'] = -0.0
        self.assertNotEqual(schedule_digest(queue), schedule_digest(minus_zero))
        reordered_keys = [{'delay': row['delay'], 'enemyType': row['enemyType']} for row in queue]
        self.assertEqual(schedule_digest(queue), schedule_digest(reordered_keys))
        for invalid in (0, True, float('nan')):
            corrupted = copy.deepcopy(queue)
            corrupted[0]['delay'] = invalid
            with self.assertRaises(ValueError): schedule_digest(corrupted)

    def test_full_typed_baseline_roundtrip_and_deterministic_render(self):
        fixture = read_json(ROOT / 'test/fixtures/content_source_baseline.json')
        restored = decode_runtime(json.loads(runtime_text(self.runtime)))
        legacy = without_dispatch_metadata(restored)
        legacy['stages'] = [s for s in legacy['stages'] if s['id'] <= 25]
        self.assertEqual(typed_digest(legacy), fixture['typedDigest'])
        self.assertEqual(typed_digest(restored), typed_digest(self.domain))
        self.assertEqual(runtime_text(self.runtime), runtime_text(encode_runtime(restored)))
        legacy_runtime = encode_runtime(legacy)
        self.assertEqual(len(legacy_runtime['spawnSchedules']), 481)
        self.assertEqual(sum(len(rows) for rows in legacy_runtime['spawnSchedules'].values()), 9400)
        self.assertEqual(self.runtime['enemies'], self.domain['enemies'])
        self.assertEqual(self.runtime['turrets'], self.domain['turrets'])
        self.assertEqual([s['map'] for s in self.runtime['stages']], [s['map'] for s in self.domain['stages']])

    def test_one_queue_edit_preserves_unaffected_stable_ids(self):
        edited = copy.deepcopy(self.domain)
        wave = edited['stages'][0]['waves'][0]
        wave['spawnQueue'][-1]['delay'] += 0.125
        for row in wave['groupDispatch']:
            if row['spawnIndices'][-1] == len(wave['spawnQueue']) - 1:
                row['lastDispatch'] = wave['spawnQueue'][-1]['delay']
                if row['count'] == 1: row['firstDispatch'] = row['lastDispatch']
        changed = encode_runtime(edited)
        refs = lambda game: [w['spawnSchedule'] for s in game['stages'] for w in s['waves']]
        before, after = refs(self.runtime), refs(changed)
        self.assertNotEqual(before[0], after[0])
        self.assertEqual(before[1:], after[1:])
        for identifier in set(before) & set(after):
            self.assertEqual(self.runtime['spawnSchedules'][identifier], changed['spawnSchedules'][identifier])

    def test_encode_decode_and_duplicate_schedule_mutation_isolation(self):
        original = copy.deepcopy(self.domain)
        runtime = encode_runtime(self.domain)
        runtime['stages'][0]['waves'][0]['groups'][0]['count'] += 1
        self.assertEqual(self.domain, original)
        restored = decode_runtime(self.runtime)
        by_reference = {}
        for stage, expanded in zip(self.runtime['stages'], restored['stages']):
            for encoded_wave, wave in zip(stage['waves'], expanded['waves']):
                key = encoded_wave['spawnSchedule']
                if key in by_reference:
                    earlier = by_reference[key]
                    before = copy.deepcopy(earlier)
                    wave['spawnQueue'][0]['delay'] += 1.0
                    wave['enemyDurability']['normal']['maxHp'] += 1.0
                    wave['groups'][0]['count'] += 1
                    self.assertEqual(earlier, before)
                    self.assertEqual(self.runtime, encode_runtime(original))
                    self.assertEqual(decode_runtime(self.runtime), original)
                    return
                by_reference[key] = wave
        self.fail('Fixture requires duplicate schedule references')

    def test_dynamic_enemy_inventory_is_preserved_with_all_durability_rows(self):
        domain = copy.deepcopy(self.domain)
        domain['enemyDefinitions']['futureEnemy'] = copy.deepcopy(domain['enemyDefinitions']['normal'])
        domain['enemies']['futureEnemy'] = copy.deepcopy(domain['enemies']['normal'])
        for stage in domain['stages']:
            for wave in stage['waves']:
                wave['enemyDurability']['futureEnemy'] = copy.deepcopy(wave['enemyDurability']['normal'])
        self.assertEqual(typed_digest(decode_runtime(encode_runtime(domain))), typed_digest(domain))

    def test_missing_extra_corrupted_rows_and_types_are_rejected(self):
        def wave(game): return game['stages'][0]['waves'][0]
        def first_rows(game): return game['spawnSchedules'][wave(game)['spawnSchedule']]
        mutations = [
            lambda g: g.update(schemaVersion=True),
            lambda g: g.update(schemaVersion=1),
            lambda g: g.update(unexpected=1),
            lambda g: g.pop('runtimeFormat'),
            lambda g: g['runtimeFormat'].update(durabilityColumns=['maxArmor', 'maxShield', 'maxHp']),
            lambda g: g['runtimeFormat'].update(spawnColumns=['delay', 'enemyType']),
            lambda g: wave(g).update(spawnSchedule='schedule_' + '0' * 64),
            lambda g: wave(g).update(spawnSchedule=[]),
            lambda g: wave(g).update(spawnQueue=[]),
            lambda g: wave(g).pop('groups'),
            lambda g: wave(g)['groups'][0].update(count=True),
            lambda g: wave(g)['groups'][0].update(enemyType='missing'),
            lambda g: wave(g)['enemyDurability'].pop('normal'),
            lambda g: wave(g)['enemyDurability'].update(unknown=[1.0, 0.0, 0.0]),
            lambda g: wave(g)['enemyDurability'].update(normal=[1.0, 0.0]),
            lambda g: wave(g)['enemyDurability'].update(normal=[1, 0.0, 0.0]),
            lambda g: wave(g)['enemyDurability'].update(normal=[float('inf'), 0.0, 0.0]),
            lambda g: first_rows(g)[0].__setitem__(0, 'missing'),
            lambda g: first_rows(g)[0].__setitem__(1, 0),
            lambda g: first_rows(g)[0].__setitem__(1, True),
            lambda g: first_rows(g)[0].append(0.0),
            lambda g: first_rows(g).__setitem__(0, {}),
            lambda g: first_rows(g)[-1].__setitem__(1, first_rows(g)[-1][1] + 0.01),
            lambda g: g['stages'][0].update(id=True),
            lambda g: g['stages'].append(copy.deepcopy(g['stages'][0])),
            lambda g: wave(g).update(round=2),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                invalid = copy.deepcopy(self.runtime)
                mutate(invalid)
                with self.assertRaises(ValueError): decode_runtime(invalid)
        invalid = copy.deepcopy(self.runtime)
        duplicate = copy.deepcopy(first_rows(invalid))
        duplicate[-1][1] += 0.1
        queue = [{'enemyType': row[0], 'delay': row[1]} for row in duplicate]
        invalid['spawnSchedules']['schedule_' + schedule_digest(queue)] = duplicate
        with self.assertRaisesRegex(ValueError, 'Unreferenced'): decode_runtime(invalid)

    def test_disk_loader_rejects_duplicates_and_reads_generated_not_source(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'runtime.json'
            path.write_text(runtime_text(self.runtime))
            self.assertEqual(typed_digest(load_compiled_content(path)), typed_digest(self.domain))
            path.write_text('{"schemaVersion":2,"schemaVersion":2}')
            with self.assertRaisesRegex(ValueError, 'Duplicate JSON key'): load_compiled_content(path)
            path.write_text('{"schemaVersion":NaN}')
            with self.assertRaisesRegex(ValueError, 'Non-finite'): load_compiled_content(path)


if __name__ == '__main__':
    unittest.main()
