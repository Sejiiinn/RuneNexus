#!/usr/bin/env python3
"""Source-only regeneration, exact compatibility, editing and stale rejection."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from content_compiler import (ROOT, apply_ulps, check_generated, compile_content,
                              durability_for, queue_for, read_json, record_json,
                              typed_digest, write_generated)
from content_design_views import chapter_views, map_annotations
import prepare_godot_project as preparation
import run_godot_native_regressions as regressions


class ContentCompilerTests(unittest.TestCase):
    def clone(self, directory):
        root = Path(directory)
        shutil.copytree(ROOT / 'godot/content/source', root / 'godot/content/source')
        return root

    def mutate_stage(self, root, stage_id, edit):
        path = root / 'godot/content/source/stages' / f'{stage_id:03}.json'
        stage = read_json(path)
        edit(stage)
        path.write_text(record_json(stage))
        return stage

    def test_exact_typed_baseline_without_any_generated_or_design_inputs(self):
        fixture = read_json(ROOT / 'test/fixtures/content_source_baseline.json')
        with tempfile.TemporaryDirectory() as directory:
            root = self.clone(directory)
            self.assertFalse((root / 'godot/content/game_content.json').exists())
            self.assertFalse((root / 'design').exists())
            content = compile_content(root)
            self.assertEqual(typed_digest(content), fixture['typedDigest'])
            self.assertEqual({str(s['id']): typed_digest(s) for s in content['stages']}, fixture['stageDigests'])
            self.assertEqual(sum(len(w['spawnQueue']) for s in content['stages'] for w in s['waves']), fixture['spawns'])
            write_generated(root)
            first = (root / 'godot/content/game_content.json').read_bytes()
            write_generated(root)
            self.assertEqual(first, (root / 'godot/content/game_content.json').read_bytes())
            self.assertEqual(check_generated(root), content)

    def test_digest_distinguishes_number_type_bits_and_list_order(self):
        self.assertNotEqual(typed_digest(1), typed_digest(1.0))
        self.assertNotEqual(typed_digest(0.0), typed_digest(-0.0))
        self.assertNotEqual(typed_digest([1, 2]), typed_digest([2, 1]))
        self.assertEqual(typed_digest({'a': 1, 'b': 2}), typed_digest({'b': 2, 'a': 1}))

    def test_source_changes_drive_output_and_runtime_edits_are_stale(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.clone(directory)
            write_generated(root)
            self.mutate_stage(root, 1, lambda stage: stage.update(name='edited source'))
            with self.assertRaisesRegex(ValueError, 'stale'):
                check_generated(root)
            content = write_generated(root)
            self.assertEqual(content['stages'][0]['name'], 'edited source')
            path = root / 'godot/content/game_content.json'
            path.write_text(path.read_text().replace('edited source', 'manual output'))
            with self.assertRaisesRegex(ValueError, 'stale'):
                check_generated(root)
            path.unlink()
            with self.assertRaisesRegex(ValueError, 'Missing/stale'):
                check_generated(root)

    def test_edited_group_schedule_does_not_reuse_legacy_delay_corrections(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.clone(directory)
            source = next((s, w) for s in sorted((root / 'godot/content/source/stages').glob('*.json'))
                          for w in read_json(s)['waves'] if w.get('compatibility', {}).get('spawnDelayUlps'))
            path, wave = source
            data = read_json(path)
            target = data['waves'][wave['round']-1]
            target['groups'][0]['interval'] += 0.25
            expected = queue_for(target['groups'], target.get('queuePrecision'))
            path.write_text(record_json(data))
            actual = compile_content(root)['stages'][data['id']-1]['waves'][wave['round']-1]['spawnQueue']
            self.assertEqual(typed_digest(actual), typed_digest(expected))

    def test_changed_enemy_definition_is_not_replaced_by_old_durability(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.clone(directory)
            stage, wave = next((read_json(p), w)
                               for p in sorted((root / 'godot/content/source/stages').glob('*.json'))
                               for w in read_json(p)['waves'] if w.get('compatibility', {}).get('durabilityUlps'))
            key = next(iter(wave['compatibility']['durabilityUlps']))
            kind, field = key.split('.')
            path = root / 'godot/content/source/enemies.json'
            definitions = read_json(path)
            definitions['enemyDefinitions'][kind][field] *= 1.5
            path.write_text(record_json(definitions))
            from stage_progression import stage_ordinals
            expected = durability_for(definitions['enemyDefinitions'][kind], wave['round'], stage_ordinals(root)[stage['id']], wave.get('durabilityOrder', 'factor-first'))[field]
            actual = compile_content(root)['stages'][stage['id']-1]['waves'][wave['round']-1]['enemyDurability'][kind][field]
            self.assertEqual(actual.hex(), expected.hex())

    def test_missing_extra_duplicate_and_invalid_sources_fail(self):
        edits = [lambda s: s.update(id=True),
                 lambda s: s.update(firstClearCorePointReward=1.0),
                 lambda s: s['waves'][0].update(round=1.0),
                 lambda s: s['waves'][0].update(clearRewardGold=True),
                 lambda s: s['waves'][0]['groups'][0].update(count=0),
                 lambda s: s['waves'][0]['groups'][0].update(interval=0),
                 lambda s: s['waves'][0].update(spawnQueue=[]),
                 lambda s: s['map']['path'][0].__setitem__(0, 999),
                 lambda s: s['map']['path'][0].__setitem__(0, True),
                 lambda s: s['map'].update(teleportPairs=[{'color': 'blue', 'entrance': s['map']['path'][0], 'exit': s['map']['path'][1]}])]
        for edit in edits:
            with self.subTest(edit=edit), tempfile.TemporaryDirectory() as directory:
                root = self.clone(directory)
                self.mutate_stage(root, 1, edit)
                with self.assertRaises((ValueError, KeyError)):
                    compile_content(root)
        for mutation in ('missing', 'extra', 'duplicate'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = self.clone(directory)
                folder = root / 'godot/content/source/stages'
                if mutation == 'missing': (folder / '001.json').unlink()
                elif mutation == 'extra': shutil.copy2(folder / '001.json', folder / '026.json')
                else: (folder / '001.json').write_text('{"id":1,"id":2}')
                with self.assertRaises(ValueError): compile_content(root)

    def test_build_and_regression_preparation_reject_stale_before_side_effects(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.clone(directory)
            write_generated(root)
            self.mutate_stage(root, 1, lambda stage: stage.update(name='pending compile'))
            with patch.multiple(preparation, ROOT=root, SOURCE=root / 'godot', PROJECT=root / 'build/project'):
                with self.assertRaisesRegex(ValueError, 'stale'): preparation.prepare()
            with patch.object(regressions, 'ROOT', root):
                with self.assertRaisesRegex(ValueError, 'stale'): regressions.prepare(root / 'regression', 'unused')
            self.assertFalse((root / 'build').exists())
            self.assertFalse((root / 'regression').exists())

    def test_design_manifests_resolve_runtime_identical_maps_and_queues(self):
        compiled = {s['id']: s for s in compile_content()['stages']}
        for chapter, ids in ((1, range(16, 21)), (2, range(21, 26))):
            maps, rounds = chapter_views(chapter)
            for stage_id, map_data, schedule in zip(ids, maps['maps'], rounds['stages']):
                stage = compiled[stage_id]
                for key, value in stage['map'].items(): self.assertEqual(map_data[key], value)
                for wave, view in zip(stage['waves'], schedule['rounds']):
                    self.assertEqual(typed_digest(view['spawnQueue']), typed_digest(wave['spawnQueue']))
                    self.assertEqual(view['groups'], wave['groups'])

    def test_map_summaries_follow_edited_geometry_and_retain_existing_order(self):
        stage = read_json(ROOT / 'godot/content/source/stages/016.json')
        before = map_annotations(stage['map'], stage['design'])
        self.assertEqual(before['buildCells'], stage['design']['buildCells'])
        original = before['buildCells'][0]
        columns = stage['map']['columns']
        stage['map']['tiles'][original[1] * columns + original[0]] = 'blocked'
        free = stage['map']['tiles'].index('blocked')
        stage['map']['tiles'][free] = 'build'
        added = [free % columns, free // columns]
        after = map_annotations(stage['map'], stage['design'])
        self.assertEqual(set(map(tuple, after['buildCells'])),
                         {(i % columns, i // columns) for i, tile in enumerate(stage['map']['tiles']) if tile == 'build'})
        self.assertIn(added, after['buildCells'])
        stage['map']['path'].pop()
        after = map_annotations(stage['map'], stage['design'])
        self.assertEqual(after['pathTiles'], len(stage['map']['path']))
        self.assertEqual(after['walkingEdges'], len(stage['map']['path']) - 1)


if __name__ == '__main__':
    unittest.main()
