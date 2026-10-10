"""Compiler-owned dispatch identity, explicit spawn portals, and exact compatibility."""
import copy
import unittest
from unittest.mock import patch
from content_compiler import (ROOT, SCHEDULING_POLICY, compile_content, group_dispatch_for,
                              read_json, schedule_for, typed_digest, validate_group_dispatch, validate_map)
from content_test_helpers import without_dispatch_metadata


class GroupDispatchCompilerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.game=compile_content()

    def test_all_gameplay_values_remain_bit_exact(self):
        self.assertEqual(typed_digest(without_dispatch_metadata(self.game)),
                         'c164ac0e6172888d7fcbd12430bf0753ddcaaf3799cf5e9bb3bfec4b10a0228b')
        fixture=read_json(ROOT/'test/fixtures/content_source_baseline.json')
        old={str(s['id']):typed_digest(without_dispatch_metadata(s)) for s in self.game['stages'][:25]}
        self.assertEqual(old,fixture['stageDigests'])

    def test_all_1200_metadata_rows_cover_precise_queue_once(self):
        self.assertEqual(self.game['schedulingPolicy'],SCHEDULING_POLICY)
        total=0
        for stage in self.game['stages']:
            for wave in stage['waves']:
                validate_group_dispatch(wave,stage['map'])
                self.assertEqual(sorted(i for row in wave['groupDispatch'] for i in row['spawnIndices']),
                                 list(range(len(wave['spawnQueue']))))
                self.assertEqual(len({r['groupId'] for r in wave['groupDispatch']}),len(wave['groups']))
                total+=1
        self.assertEqual(total,1200)

    def test_same_request_uses_source_identity_and_chronological_rows(self):
        groups=[dict(id='later',enemyType='normal',count=2,interval=0.2,startDelay=1.0),
                dict(id='first',enemyType='normal',count=2,interval=0.2,startDelay=0.0),
                dict(id='second',enemyType='normal',count=2,interval=0.2,startDelay=0.0)]
        q,indices,starts=schedule_for(groups)
        wave=dict(groups=groups,spawnQueue=q)
        wave['groupDispatch']=group_dispatch_for(wave,{},indices,starts)
        validate_group_dispatch(wave,{})
        self.assertEqual([r['groupId'] for r in wave['groupDispatch']],['first','second','later'])
        self.assertEqual([r['groupIndex'] for r in wave['groupDispatch']],[1,2,0])
        self.assertEqual(wave['groupDispatch'][0]['spawnIndices'],[0,2])
        self.assertEqual(wave['groupDispatch'][1]['spawnIndices'],[1,3])
        self.assertEqual(wave['groupDispatch'][1]['firstDispatch'],0.18)

    def test_compiler_normalizes_each_wave_once_and_codec_does_not_reschedule(self):
        from content_runtime_format import encode_runtime
        with patch('content_compiler.schedule_for', wraps=schedule_for) as normalizer:
            game=compile_content()
            self.assertEqual(normalizer.call_count,1200)
            encode_runtime(game)
            self.assertEqual(normalizer.call_count,1200)

    def test_explicit_route_portal_relationships(self):
        for sid in [26,27,28,29,30]:
            m=self.game['stages'][sid-1]['map'];validate_map(m)
            self.assertEqual([p['id'] for p in m['spawnPortals']],['A','B'] if sid==30 else ['A'])
        m=self.game['stages'][29]['map']
        for edit in [lambda x:x['routes'][0].update(spawnPortalId='B'),
                     lambda x:x['spawnPortals'][0].update(cell=[1,2]),
                     lambda x:x['spawnPortals'][1].update(id='A'),
                     lambda x:x.update(spawnPortals=x['spawnPortals'][:1])]:
            bad=copy.deepcopy(m);edit(bad)
            with self.assertRaises(ValueError):validate_map(bad)

    def test_bad_dispatch_or_duplicate_source_ids_rejected(self):
        stage=self.game['stages'][29];original=stage['waves'][21]
        for edit in [lambda w:w['groupDispatch'][0].update(groupId='missing'),
                     lambda w:w['groupDispatch'][0].update(spawnPortalId='B'),
                     lambda w:w['groupDispatch'][0].update(requestedDispatch=0.1),
                     lambda w:w['groupDispatch'][0].update(firstDispatch=0.1),
                     lambda w:w['groupDispatch'][0]['spawnIndices'].__setitem__(0,1),
                     lambda w:w['groupDispatch'].reverse()]:
            bad=copy.deepcopy(original);edit(bad)
            with self.assertRaises(ValueError):validate_group_dispatch(bad,stage['map'])
        groups=copy.deepcopy(original['groups']);groups[1]['id']=groups[0]['id']
        with self.assertRaises(ValueError):schedule_for(groups)


if __name__=='__main__':unittest.main()
