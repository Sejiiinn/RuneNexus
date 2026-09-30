#!/usr/bin/env python3
"""Materialize approved expansion maps and schedules with immutable old IDs."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def apply():
    path = ROOT / 'godot/content/game_content.json'
    game = json.loads(path.read_text())
    original = [s for s in game['stages'] if s['id'] <= 15]
    expanded = []
    for chapter, first_id in ((1,16),(2,21)):
        folder = ROOT / f'design/chapter{chapter}_map_expansion'
        maps = json.loads((folder / 'maps.json').read_text())['maps']
        schedules = json.loads((folder / 'rounds/rounds.json').read_text())['stages']
        by_label = {s['chapterStage']:s for s in schedules}
        for offset, approved in enumerate(maps):
            schedule = by_label[approved['chapterStage']]
            game_map = {k:copy.deepcopy(approved[k]) for k in ('columns','rows','tileTheme','tiles','path')}
            if approved.get('teleportPairs'): game_map['teleportPairs'] = copy.deepcopy(approved['teleportPairs'])
            waves = []
            for wave in schedule['rounds']:
                factor = 2 ** ((wave['round']-1)/10) * 1.15 ** (schedule['progressionOrdinal']-1)
                waves.append({'round':wave['round'],'previewText':wave['label'],
                              'clearRewardGold':wave['clearRewardGold'],
                              'groups':copy.deepcopy(wave['groups']),
                              'spawnQueue':copy.deepcopy(wave['spawnQueue']),
                              'enemyDurability':{kind:{field:float(definition[field]*factor) for field in ('maxHp','maxShield','maxArmor')} for kind,definition in game['enemyDefinitions'].items()}})
            expanded.append({'id':first_id+offset,'name':approved['name'],
                             'firstClearCorePointReward':2,'firstClearTurretModuleTicketReward':0,
                             'map':game_map,'waves':waves})
    game['stages'] = original + expanded
    path.write_text(json.dumps(game,ensure_ascii=False,indent=2)+'\n')

if __name__ == '__main__': apply()
