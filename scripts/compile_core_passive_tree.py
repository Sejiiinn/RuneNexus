#!/usr/bin/env python3
"""Compile the approved v5 graph and preserved v4 catalog to client/server contracts."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EFFECT_KEYS = {
    'core_recovery': 'cooldownRecoveryRate', 'core_power': 'coreSkillPowerMultiplier',
    'third_core_power': 'thirdCoreSkillPowerMultiplier', 'core_sync_rate': 'turretAttackRateAmplification',
    'direct_inc': 'directDamageIncrease', 'area_radius_inc': 'splashRadiusIncrease',
    'dot_inc': 'damageOverTimeIncrease', 'control_duration_inc': 'controlDurationIncrease',
    'slow_strength_pp': 'slowStrengthBonus', 'dot_duration_inc': 'burnDurationIncrease',
    'hp_mult': 'nexusMaxHpMultiplier', 'build_mult': 'buildCostMultiplier',
    'impact_reduction': 'impactDispersionRate', 'wave_heal': 'roundRecoveryRate',
    'level_cost_mult': 'turretLevelUpCostMultiplier', 'link_mult': 'linkCostMultiplier',
    'wave_gold_mult': 'roundClearGoldMultiplier', 'crit_chance_pp': 'criticalChanceBonus',
    'projectile_speed_inc': 'projectileSpeedIncrease', 'area_hit_inc': 'splashDamageIncrease',
    'chain_hit_inc': 'lightningChainDamageIncrease', 'range_inc': 'rangeIncrease',
    'threat_weakening': 'threatWeakeningRate', 'level_damage_inc': 'turretLevelDamageIncrease',
    'starting_gold_mult': 'startingGoldMultiplier', 'trait_mult': 'traitShardCostMultiplier',
    'crit_damage_pp': 'criticalDamageBonus', 'chain_range_inc': 'lightningChainRangeIncrease',
    'attack_rate_inc': 'attackRateIncrease', 'damage_restoration': 'damageRestorationRate',
    'refund_pp': 'turretRefundBonusRate',
}
NEW_DEFAULTS = {
    **{v: (1.0 if v.endswith('Multiplier') else 0.0) for v in EFFECT_KEYS.values()},
    'killCoreChargeRate': 0.0, 'hasStockpileFire': False,
    'stockpileAimSpeedMultiplier': 1.0, 'stockpileCooldownRecoveryMultiplier': 1.0,
    'damageOverTimeSpeedMultiplier': 1.0, 'splashSecondaryDamageBonus': 0.0,
    'maxTurretLevelBonus': 0, 'equippedGemDamageAmplificationPerGem': 0.0,
    'firstControlDurationMultiplier': 1.0, 'hasIndomitableFortress': False,
    'nexusAdditionalHpRate': 0.0,
}
LABELS = {
    'cooldownRecoveryRate': '코어 재사용 회복 속도', 'coreSkillPowerMultiplier': '코어 위력',
    'thirdCoreSkillPowerMultiplier': '매 세 번째 코어 위력', 'turretAttackRateAmplification': '코어 발동 시 공격 속도',
    'directDamageIncrease':'직접 피해', 'splashRadiusIncrease':'범위 반경', 'damageOverTimeIncrease':'지속 피해',
    'controlDurationIncrease':'제어 지속시간', 'slowStrengthBonus':'둔화 강도', 'burnDurationIncrease':'지속 피해 지속시간',
    'nexusMaxHpMultiplier':'넥서스 최대 체력', 'buildCostMultiplier':'건설 비용', 'impactDispersionRate':'피격 피해 감소',
    'roundRecoveryRate':'웨이브 종료 체력 회복', 'turretLevelUpCostMultiplier':'포탑 레벨업 비용', 'linkCostMultiplier':'링크 비용',
    'roundClearGoldMultiplier':'웨이브 골드', 'criticalChanceBonus':'치명타 확률', 'projectileSpeedIncrease':'투사체 속도',
    'splashDamageIncrease':'범위 피해', 'lightningChainDamageIncrease':'연쇄 피해', 'rangeIncrease':'사거리',
    'threatWeakeningRate':'위협 약화', 'turretLevelDamageIncrease':'레벨당 피해 증가량', 'startingGoldMultiplier':'시작 골드',
    'traitShardCostMultiplier':'특성 젬 파편 비용', 'criticalDamageBonus':'치명타 피해', 'lightningChainRangeIncrease':'연쇄 거리',
    'attackRateIncrease':'공격 속도', 'damageRestorationRate':'피해 후 회복', 'turretRefundBonusRate':'철거 환급률',
    'nexusAdditionalHpRate':'회복 불가 추가 체력',
}

def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

def validate_graph(source):
    nodes = {n['id']: n for n in source['nodes']}
    assert len(nodes) == len(source['nodes']) == 60
    assert source['starting_nodes'] == [f'S{i}' for i in range(1, 7)]
    edges = {tuple(sorted(edge)) for edge in source['edges']}
    assert len(edges) == len(source['edges']) == 89
    assert len(edges) - (len(nodes) + 1) + 1 == 29
    reachable = {'CORE'}
    while True:
        previous = len(reachable)
        for a, b in edges:
            assert a in nodes or a == 'CORE'
            assert b in nodes or b == 'CORE'
            if a in reachable: reachable.add(b)
            if b in reachable: reachable.add(a)
        if len(reachable) == previous: break
    assert len(reachable) == 61
    for key, node in nodes.items():
        assert len(node['rank_costs']) == node['max_rank']
        assert all(type(cost) is int and cost > 0 for cost in node['rank_costs'])
        actual = {a if b == key else b for a, b in edges if key in (a, b)} - {'CORE'}
        assert actual == set(node['neighbors']), key
        assert node.get('terminal', False) == (node['type'] == 'keystone')
        for effect in node['effects']:
            assert len(effect['values_by_rank']) == node['max_rank'] + 1, key
            assert effect['key'] in EFFECT_KEYS or effect['key'] in NEW_DEFAULTS, effect['key']
    return nodes

def compile_catalog(source, legacy):
    validate_graph(source)
    defaults = next(iter(legacy['nodes'].values()))['effects'][0].copy()
    defaults.update(NEW_DEFAULTS)
    result = {'revision': 5, 'startingNodes': source['starting_nodes'], 'canvas': source['canvas'],
              'edges': source['edges'], 'effectDefaults': defaults, 'verificationCases': [], 'nodes': {}}
    for n in source['nodes']:
        effects = [{} for _ in range(n['max_rank'] + 1)]
        for effect in n['effects']:
            name = EFFECT_KEYS.get(effect['key'], effect['key'])
            for rank, value in enumerate(effect['values_by_rank']):
                effects[rank][name] = value
                # The established field is TOTAL power on the third activation.
                if name == 'coreSkillPowerMultiplier': effects[rank]['thirdCoreSkillPowerMultiplier'] = value
        display = []
        for rank in range(n['max_rank'] + 1):
            if n['type'] == 'keystone':
                display.append('미투자' if rank == 0 else n['effect_summary'])
            else:
                text = []
                for effect in n['effects']:
                    name = EFFECT_KEYS.get(effect['key'], effect['key']); val = effect['values_by_rank'][rank]
                    if name.endswith('Multiplier'): value = f'×{val:g}'
                    else: value = f'+{val * 100:g}%' + ('p' if name.endswith('Bonus') or name == 'turretRefundBonusRate' else '')
                    text.append(f'{LABELS.get(name, name)} {value}')
                if n['id'] == 'C12': text.append('스테이지 시작 1회 · 소모 후 회복 불가')
                display.append(' · '.join(text))
        result['nodes'][n['id']] = {
            'name': n['name'], 'category': n['category'], 'type': n['type'], 'position': n['position'],
            'maxRank': n['max_rank'], 'rankCosts': n['rank_costs'], 'neighbors': n['neighbors'],
            'terminal': n.get('terminal', False), 'activationRank': n.get('activation_rank'),
            'effects': effects, 'effectSummary': n['effect_summary'], 'displayEffects': n['display_effects'],
            'displayEffectsByRank': display,
        }
    return result

def registry(catalog):
    return {'startingNodes': catalog['startingNodes'], 'nodes': {
        key: {field: node.get(field, False if field == 'terminal' else []) for field in ('maxRank','rankCosts','neighbors','terminal')}
        for key,node in catalog['nodes'].items()}}

def render_gd(catalogs):
    content=json.dumps(catalogs,ensure_ascii=False,separators=(',',':'))
    return '# Generated by scripts/compile_core_passive_tree.py; DO NOT EDIT.\nextends RefCounted\nconst CURRENT_REVISION := 5\nconst CATALOGS = '+content+'\n'

def defense_contract(growth, current):
    return {'baseNexusHp': growth['constants']['baseNexusHp'],
            'maxNexusHpUpgradeLevel': growth['permanentUpgrades']['nexusHp']['maxLevel'],
            'additionalHpRates': [rank['nexusAdditionalHpRate'] for rank in current['nodes']['C12']['effects']]}

def render_go(catalogs, defense):
    lines=['// Code generated by scripts/compile_core_passive_tree.py; DO NOT EDIT.','package coretree','',
           'const CurrentRevision = 5',
           f'const BaseNexusHP = {float(defense["baseNexusHp"])}',
           f'const MaxNexusHPUpgradeLevel = {defense["maxNexusHpUpgradeLevel"]}',
           'var additionalHPRates = [...]float64{'+','.join(str(float(v)) for v in defense['additionalHpRates'])+'}',
           'func AdditionalHPRate(rank int) float64 { if rank < 0 || rank >= len(additionalHPRates) { return 0 }; return additionalHPRates[rank] }',
           'type Node struct { MaxRank int; RankCosts []int; Neighbors []string; Terminal bool }',
           'type Catalog struct { StartingNodes []string; Nodes map[string]Node }','var Catalogs = map[int]Catalog{']
    for revision, catalog in catalogs.items():
        strings=lambda values: '[]string{'+','.join(json.dumps(v) for v in values)+'}'
        lines += [f'{revision}: {{StartingNodes: {strings(catalog["startingNodes"])}, Nodes: map[string]Node{{']
        for key,n in catalog['nodes'].items():
            lines.append(json.dumps(key)+': {MaxRank: '+str(n['maxRank'])+', RankCosts: []int{'+','.join(map(str,n['rankCosts']))+'}, Neighbors: '+strings(n['neighbors'])+', Terminal: '+str(n['terminal']).lower()+'},')
        lines += ['}},']
    lines += ['}','']
    raw='\n'.join(lines)
    # Source generation is deterministic and does not require a Go toolchain.
    return raw

def compile_core_tree(root: Path = ROOT, check: bool = False):
    legacy=load(root/'godot/content/source/core_passive_tree_v4.json')
    current=compile_catalog(load(root/'godot/content/source/core_passive_tree_v5.json'),legacy)
    growth_path=root/'godot/content/growth_content.json'; growth=load(growth_path)
    growth['core']=current; growth['legacyCore']=legacy; growth['defaultProgression']['corePassiveTreeRevision']=5
    catalogs={'4':registry(legacy),'5':registry(current)}
    outputs={growth_path:json.dumps(growth,ensure_ascii=False,indent=2)+'\n',
             root/'godot/content/generated_core_tree.gd':render_gd(catalogs),
             root/'server/internal/coretree/generated.go':render_go(catalogs, defense_contract(growth,current))}
    stale=[]
    for path, text in outputs.items():
        if check:
            if not path.exists() or path.read_text()!=text: stale.append(str(path.relative_to(root)))
        else:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,encoding='utf-8')
    if stale: raise ValueError('Stale core tree outputs: '+', '.join(stale)+'; run scripts/compile_core_passive_tree.py')

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); parser.add_argument('--root', type=Path, default=ROOT); args=parser.parse_args()
    compile_core_tree(args.root, args.check)
    print('PASS core tree catalog: 60 nodes + CORE, 89 edges, 29 cycles; preserved v4')
if __name__=='__main__': main()
