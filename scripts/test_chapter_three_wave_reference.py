"""The review table uses normalized dispatch times including startup delay."""
import unittest
from chapter_three_wave_reference import ROOT, TARGET, group_dispatches, reference_text
from content_compiler import compile_content, schedule_for, group_dispatch_for


class ChapterThreeWaveReferenceTests(unittest.TestCase):
    def test_equal_request_groups_keep_identity_and_global_spacing(self):
        groups = [dict(enemyType='normal',count=2,interval=0.2,startDelay=0.0,routeId='A'),
                  dict(enemyType='normal',count=2,interval=0.2,startDelay=0.0,routeId='B')]
        queue,indices,starts=schedule_for(groups)
        wave = dict(groups=groups,spawnQueue=queue)
        wave['groupDispatch']=group_dispatch_for(wave,{},indices,starts)
        dispatches = group_dispatches(wave,0.7)
        self.assertEqual([d['group']['routeId'] for d in dispatches],['A','B'])
        self.assertAlmostEqual(dispatches[0]['requested'],0.7)
        self.assertAlmostEqual(dispatches[1]['requested'],0.7)
        self.assertAlmostEqual(dispatches[0]['first'],0.7)
        self.assertAlmostEqual(dispatches[1]['first'],0.88)
        self.assertAlmostEqual(dispatches[0]['last'],1.06)
        self.assertAlmostEqual(dispatches[1]['last'],1.24)

    def test_all_200_waves_use_every_normalized_dispatch_once(self):
        game = compile_content()
        count=0
        for stage in game['stages'][25:]:
            for wave in stage['waves']:
                dispatches=group_dispatches(wave,game['defaults']['initialDelay'])
                self.assertEqual(sorted(i for d in dispatches for i in d['spawnIndices']),
                                 list(range(len(wave['spawnQueue']))))
                for item in dispatches:
                    self.assertEqual(len(item['spawnIndices']),item['group']['count'])
                    self.assertGreaterEqual(item['first']+1e-8,item['requested'])
                count+=1
        self.assertEqual(count,200)

    def test_checked_in_reference_is_current(self):
        self.assertEqual((ROOT/TARGET).read_text(encoding='utf-8'),reference_text())


if __name__=='__main__':unittest.main()
