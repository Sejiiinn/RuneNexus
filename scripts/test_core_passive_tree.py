"""Focused compiler and generated client/server parity contracts."""
import copy
import json
from pathlib import Path
import unittest
from compile_core_passive_tree import ROOT, compile_catalog, load, registry, render_gd, render_go, validate_graph, defense_contract

class CorePassiveTreeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = load(ROOT/'godot/content/source/core_passive_tree_v5.json')
        cls.legacy = load(ROOT/'godot/content/source/core_passive_tree_v4.json')
        cls.current = compile_catalog(cls.source, cls.legacy)

    def test_generated_catalog_and_both_registries_are_current(self):
        growth = load(ROOT/'godot/content/growth_content.json')
        self.assertEqual(growth['core'], self.current)
        self.assertEqual(growth['legacyCore'], self.legacy)
        catalogs = {'4': registry(self.legacy), '5': registry(self.current)}
        self.assertEqual((ROOT/'godot/content/generated_core_tree.gd').read_text(), render_gd(catalogs))
        self.assertEqual((ROOT/'server/internal/coretree/generated.go').read_text(), render_go(catalogs, defense_contract(growth,self.current)))
        self.assertEqual(growth['defaultProgression']['corePassiveTreeRevision'], 5)

    def test_fixed_topology_and_incremental_prices(self):
        nodes=validate_graph(self.source)
        self.assertEqual(len(nodes),60)
        self.assertEqual(len(self.source['edges']),89)
        self.assertEqual(89-61+1,29)
        self.assertEqual(len(self.source['starting_nodes']),6)
        self.assertEqual(sum(n['type']=='keystone' for n in nodes.values()),8)
        self.assertEqual(sum(nodes['S1']['rank_costs']),9)
        self.assertEqual(sum(nodes['C12']['rank_costs']),10)
        self.assertEqual(sum(nodes['K1']['rank_costs']),5)

    def test_keystones_only_approved_positive_effects(self):
        expected={
          'K1':{'killCoreChargeRate':.1},
          'K2':{'hasStockpileFire':True,'stockpileAimSpeedMultiplier':1.5,'stockpileCooldownRecoveryMultiplier':1.5},
          'K3':{'damageOverTimeSpeedMultiplier':1.5},'K4':{'splashSecondaryDamageBonus':.15},
          'K5':{'maxTurretLevelBonus':1},'K6':{'equippedGemDamageAmplificationPerGem':.05},
          'K7':{'firstControlDurationMultiplier':2.0},'K8':{'hasIndomitableFortress':True}}
        for key,effects in expected.items():
            self.assertEqual(self.current['nodes'][key]['effects'][1],effects,key)
            self.assertTrue(self.current['nodes'][key]['terminal'])
        for key in ('S3','A06','C10'):
            self.assertIn('controlDurationIncrease',self.current['nodes'][key]['effects'][-1])
            self.assertIn('제어 지속시간',self.current['nodes'][key]['effectSummary'])
        self.assertEqual(self.current['nodes']['C12']['effects'],[{'nexusAdditionalHpRate':x} for x in (0,.05,.1,.15)])

    def test_each_display_rank_is_explicit(self):
        for key,node in self.current['nodes'].items():
            self.assertEqual(len(node['displayEffectsByRank']),node['maxRank']+1,key)
            self.assertTrue(all(node['displayEffectsByRank']),key)

    def test_bad_graph_is_rejected(self):
        invalid=copy.deepcopy(self.source)
        invalid['edges'].append(invalid['edges'][0])
        with self.assertRaises(AssertionError): validate_graph(invalid)

    def test_actual_point_supply_metadata_and_stage_rewards(self):
        self.assertEqual(self.source['points']['natural_total'],60)
        self.assertTrue(self.source['points']['preserve_actual_saved_total'])
        files=list((ROOT/'godot/content/source/stages').glob('*.json'))
        stages=[load(path) for path in files]
        self.assertEqual(len(stages),30)
        self.assertEqual(sum(s['firstClearCorePointReward'] for s in stages),60)

if __name__=='__main__': unittest.main()
