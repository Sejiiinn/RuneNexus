#!/usr/bin/env python3
"""Approved 3-6..3-10 geometry, deterministic routing and authored pacing contracts."""
import copy
from content_test_helpers import without_dispatch_metadata
import unittest
from collections import Counter
from content_compiler import ROOT, compile_content, read_json, typed_digest, validate_map, validate_wave_routes
from stage_progression import load_progression


class ChapterThreeContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.content = compile_content()
        cls.stages = {s['id']: s for s in cls.content['stages']}

    def test_existing_twenty_five_stages_are_bit_exact(self):
        baseline = read_json(ROOT / 'test/fixtures/content_source_baseline.json')
        self.assertEqual({str(i): typed_digest(without_dispatch_metadata(self.stages[i])) for i in range(1, 26)}, baseline['stageDigests'])

    def test_progression_appends_without_renumbering(self):
        registry = load_progression()
        self.assertEqual(registry['order'][-6:], [15, 26, 27, 28, 29, 30])
        self.assertEqual([(s['id'], s['chapter'], s['chapterStage']) for s in registry['stages'][-5:]],
                         [(i, 3, i-20) for i in range(26,31)])

    def test_approved_geometry_fingerprints(self):
        expected = GEOMETRY_DIGESTS
        for i, digest in expected.items():
            self.assertEqual(typed_digest(without_dispatch_metadata(self.stages[i]['map'])), digest)
        expected_moves = {26:[60],27:[37],28:[16,20],29:[29],30:[17,19]}
        for i, moves in expected_moves.items():
            m = self.stages[i]['map']
            paths = [r['path'] for r in m.get('routes', [])] or [m['path']]
            self.assertEqual([sum(abs(a[0]-b[0])+abs(a[1]-b[1]) == 1 for a,b in zip(p,p[1:])) for p in paths], moves)
            self.assertEqual(m['tiles'].count('build'), {26:10,27:10,28:13,29:11,30:14}[i])
        a,b = self.stages[28]['map']['routes']
        self.assertEqual(a['path'][:2], [[0,4],[1,4]])
        self.assertEqual(a['path'][:2], b['path'][:2])
        self.assertNotEqual(a['path'][2], b['path'][2])
        self.assertEqual(self.stages[27]['map']['teleportPairs'],
                         [{'color':'blue','entrance':[11,1],'exit':[10,7]}])

    def test_forty_rounds_boss_milestones_and_distinct_phase_timing(self):
        for i in range(26,31):
            waves = self.stages[i]['waves']
            self.assertEqual([w['round'] for w in waves], list(range(1,41)))
            self.assertEqual([w['round'] for w in waves if any(g['enemyType']=='forgeBoss' for g in w['groups'])], [10,20,30,40])
            self.assertEqual([next(g['startDelay'] for g in waves[r-1]['groups'] if g['enemyType']=='forgeBoss') for r in [10,20,30,40]], [0.0,6.0,4.0,1.0])
            signatures = [{(g['enemyType'],g['startDelay']) for g in waves[r-1]['groups']} for r in [1,11,21,31]]
            self.assertEqual(len({str(sorted(x)) for x in signatures}),4)
            for w in waves:
                self.assertEqual(Counter(q['enemyType'] for q in w['spawnQueue']), Counter({k:sum(g['count'] for g in w['groups'] if g['enemyType']==k) for k in {g['enemyType'] for g in w['groups']}}))
                self.assertTrue(all(b['delay']-a['delay'] >= .18-1e-8 for a,b in zip(w['spawnQueue'],w['spawnQueue'][1:])))

    def test_route_choices_and_announcements(self):
        both = {22,25,28,30,33,35,38,40}
        for w in self.stages[30]['waves']:
            ids = {g['routeId'] for g in w['groups']}
            self.assertEqual(ids, {'west','northeast'} if w['round'] in both else {'west' if w['round']%2 else 'northeast'})
            self.assertIn('A+B 동시' if w['round'] in both else '단독', w['previewText'])
        for w in self.stages[28]['waves']:
            for j,g in enumerate(w['groups']):
                self.assertIn(f'({g["startDelay"]:g}초)', w['previewText'])
            self.assertEqual(Counter(q['routeId'] for q in w['spawnQueue']), Counter({k:sum(g['count'] for g in w['groups'] if g['routeId']==k) for k in ['north','south']}))

    def test_route_validation_rejects_ambiguous_or_invalid_inputs(self):
        m = self.stages[28]['map']
        for edit in [lambda x:x.update(routes=None), lambda x:x['routes'][1].update(id='north'),
                     lambda x:x['routes'][1]['path'].__setitem__(0,[0,0]),
                     lambda x:x['routes'][1]['path'].__setitem__(-1,[11,6])]:
            bad=copy.deepcopy(m);edit(bad)
            with self.assertRaises(ValueError):validate_map(bad)
        for g in [{}, {'routeId':None}, {'routeId':[]}, {'routeId':'missing'}]:
            with self.assertRaises(ValueError):validate_wave_routes(m,[g])

GEOMETRY_DIGESTS = {26: '9df2ebef05f6cafe9d7e203932fa7cd58f5e57d3495b81351f30ab881ec94e10', 27: 'b30c538b2987a614e0719d9e8d5a1155101689a5cf104a97e5ddbf36fa7bef22', 28: '438044e9c6ba1c5b278315e7a681eb749be3426ca213d3262e0636cd198fa711', 29: 'b8ce95017433b0865b27b7ad49ccf228276014e0b3da2fb66b1786a1c85286af', 30: '7597abbc3924056fd4d975a07b0d05791aaf25a62a99799276b3e592fda48b4c'}
if __name__ == '__main__': unittest.main()
