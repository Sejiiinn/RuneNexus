#!/usr/bin/env python3
"""Additive dispatch metadata, exact queue ownership, and Godot wire parity."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from content_compiler import (ROOT, SCHEDULING_POLICY, compile_content,
                              group_dispatch_for, schedule_for)
from content_runtime_format import decode_runtime, encode_runtime, schedule_digest
from run_godot_native_regressions import godot_executable


def dispatch_domain():
    domain = compile_content()
    domain['stages'] = domain['stages'][:1]
    stage = domain['stages'][0]
    stage['waves'] = stage['waves'][:1]
    upper = [[0, 0], [1, 0], [2, 0], [2, 1]]
    lower = [[0, 1], [1, 1], [2, 1]]
    stage['map'] = {
        'columns': 3, 'rows': 3,
        'tiles': ['spawn', 'path', 'path', 'spawn', 'path', 'core', 'build', 'blocked', 'build'],
        'path': upper,
        'spawnPortals': [
            {'id': 'north', 'label': 'North portal', 'cell': upper[0]},
            {'id': 'south', 'label': 'South portal', 'cell': lower[0]},
        ],
        'routes': [
            {'id': 'upper', 'label': 'Upper route', 'path': upper, 'spawnPortalId': 'north'},
            {'id': 'lower', 'label': 'Lower route', 'path': lower, 'spawnPortalId': 'south'},
        ],
    }
    wave = stage['waves'][0]
    wave['groups'] = [
        {'id': 'late-north', 'enemyType': 'normal', 'count': 2, 'interval': 0.2, 'startDelay': 1.0, 'routeId': 'upper'},
        {'enemyType': 'fast', 'count': 3, 'interval': 0.01, 'startDelay': 0.0, 'routeId': 'lower'},
        {'id': 'relative-north', 'enemyType': 'normal', 'count': 2, 'interval': 0.25, 'startDelay': 0.0,
         'startAfterPrevious': True, 'followDelay': 0.0, 'routeId': 'upper'},
    ]
    wave['spawnQueue'], ownership, requested = schedule_for(wave['groups'])
    wave['groupDispatch'] = group_dispatch_for(wave, stage['map'], ownership, requested)
    return domain


def malformed_runtime(runtime):
    def wave(item): return item['stages'][0]['waves'][0]
    def row(item): return wave(item)['groupDispatch'][0]
    def map_data(item): return item['stages'][0]['map']
    mutations = [
        lambda item: item.pop('schedulingPolicy'),
        lambda item: item['schedulingPolicy'].update(version=True),
        lambda item: item['schedulingPolicy'].update(version=1.0),
        lambda item: item['schedulingPolicy'].update(scope='per-route'),
        lambda item: item['schedulingPolicy'].update(minimumInterval=0.2),
        lambda item: item['schedulingPolicy'].update(tieBreak='enemy-type'),
        lambda item: item['schedulingPolicy'].update(dispatchTimeBasis='after-initial-delay'),
        lambda item: item['schedulingPolicy'].update(extra=True),
        lambda item: wave(item).pop('groupDispatch'),
        lambda item: wave(item).update(groupDispatch=[]),
        lambda item: wave(item)['groupDispatch'].reverse(),
        lambda item: row(item).update(groupIndex=True),
        lambda item: row(item).update(groupIndex=1.0),
        lambda item: row(item).update(groupIndex=-1),
        lambda item: row(item).update(groupIndex=3),
        lambda item: row(item).update(groupId='unknown'),
        lambda item: row(item).update(groupId=[]),
        lambda item: row(item).update(enemyType='normal'),
        lambda item: row(item).update(count=True),
        lambda item: row(item).update(count=2),
        lambda item: row(item).update(routeId='upper'),
        lambda item: row(item).update(spawnPortalId='north'),
        lambda item: row(item).update(requestedDispatch=0),
        lambda item: row(item).update(requestedDispatch=3.0),
        lambda item: wave(item)['groupDispatch'][1].update(requestedDispatch=0.01),
        lambda item: row(item).update(firstDispatch=0),
        lambda item: row(item).update(firstDispatch=0.01),
        lambda item: row(item).update(lastDispatch=3.0),
        lambda item: row(item).update(extra=True),
        lambda item: row(item).update(spawnIndices=[]),
        lambda item: row(item)['spawnIndices'].__setitem__(0, True),
        lambda item: row(item)['spawnIndices'].__setitem__(0, 0.0),
        lambda item: row(item)['spawnIndices'].__setitem__(0, -1),
        lambda item: row(item)['spawnIndices'].__setitem__(0, 999),
        lambda item: row(item)['spawnIndices'].__setitem__(1, 0),
        lambda item: wave(item)['groupDispatch'][1].update(groupIndex=row(item)['groupIndex']),
        lambda item: wave(item)['groups'][2].update(id='late-north'),
        lambda item: wave(item)['groups'][0].update(id=' late-north'),
        lambda item: map_data(item).update(spawnPortals=[]),
        lambda item: map_data(item)['spawnPortals'][1].update(id='north'),
        lambda item: map_data(item)['spawnPortals'][1].update(id=' south'),
        lambda item: map_data(item)['spawnPortals'][1].update(label=''),
        lambda item: map_data(item)['spawnPortals'][1].update(cell=[0, 0]),
        lambda item: map_data(item)['spawnPortals'][1].update(cell=[1, 1]),
        lambda item: map_data(item)['spawnPortals'][1].update(cell=[0, True]),
        lambda item: map_data(item)['spawnPortals'][1].update(extra=True),
        lambda item: map_data(item)['routes'][1].update(spawnPortalId='north'),
        lambda item: map_data(item)['routes'][1].pop('spawnPortalId'),
        lambda item: map_data(item).pop('spawnPortals'),
        lambda item: map_data(item)['tiles'].__setitem__(6, 'spawn'),
    ]
    result = []
    for mutate in mutations:
        invalid = copy.deepcopy(runtime)
        mutate(invalid)
        result.append(invalid)
    return result


class DispatchFormatTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.domain = dispatch_domain()
        cls.runtime = encode_runtime(cls.domain)

    def test_dispatch_roundtrip_ownership_and_chronological_identity(self):
        self.assertEqual(self.domain['schedulingPolicy'], SCHEDULING_POLICY)
        wave = self.domain['stages'][0]['waves'][0]
        self.assertEqual([row['groupIndex'] for row in wave['groupDispatch']], [1, 2, 0])
        self.assertEqual([row['groupId'] for row in wave['groupDispatch']], ['g02', 'relative-north', 'late-north'])
        self.assertEqual(wave['groupDispatch'][1]['requestedDispatch'], 0.02)
        self.assertEqual(wave['groupDispatch'][1]['firstDispatch'], 0.54)
        self.assertEqual(decode_runtime(self.runtime), self.domain)
        self.assertEqual(self.runtime['runtimeFormat']['spawnColumns'], ['enemyType', 'delay'])
        self.assertEqual(self.runtime['stages'][0]['waves'][0]['spawnSchedule'],
                         'schedule_' + schedule_digest(wave['spawnQueue']))
        expanded = decode_runtime(self.runtime)
        expanded['stages'][0]['waves'][0]['groupDispatch'][0]['spawnIndices'].append(999)
        self.assertEqual(decode_runtime(self.runtime), self.domain)

    def test_metadata_and_portal_corruption_is_rejected(self):
        for index, invalid in enumerate(malformed_runtime(self.runtime)):
            with self.subTest(index=index), self.assertRaises(ValueError):
                decode_runtime(invalid)

    def test_legacy_fixture_is_additive_without_schedule_reconstruction(self):
        legacy = copy.deepcopy(self.domain)
        legacy.pop('schedulingPolicy')
        wave = legacy['stages'][0]['waves'][0]
        wave.pop('groupDispatch')
        # Legacy test fixtures may intentionally vary composition independently.
        wave['groups'][0]['count'] = 10
        self.assertEqual(decode_runtime(encode_runtime(legacy)), legacy)
        implicit = copy.deepcopy(self.domain)
        map_data = implicit['stages'][0]['map']
        map_data.pop('spawnPortals')
        for route in map_data['routes']: route.pop('spawnPortalId')
        for row in implicit['stages'][0]['waves'][0]['groupDispatch']: row['spawnPortalId'] = 'default'
        self.assertEqual(decode_runtime(encode_runtime(implicit)), implicit)

    def test_godot_metadata_codec_parity_and_validation(self):
        legacy = copy.deepcopy(self.domain)
        legacy.pop('schedulingPolicy')
        legacy['stages'][0]['waves'][0].pop('groupDispatch')
        implicit = copy.deepcopy(self.domain)
        implicit['stages'][0]['map'].pop('spawnPortals')
        for route in implicit['stages'][0]['map']['routes']: route.pop('spawnPortalId')
        for row in implicit['stages'][0]['waves'][0]['groupDispatch']: row['spawnPortalId'] = 'default'
        with tempfile.TemporaryDirectory(prefix='dispatch-format-') as directory:
            temporary = Path(directory)
            for name in ('content/runtime_content_format.gd', 'combat/teleport_pairs.gd', 'app/save_json.gd'):
                target = temporary / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / 'godot' / name, target)
            (temporary / 'project.godot').write_text('[application]\nconfig/name="Dispatch format regression"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            (temporary / 'fixtures.json').write_text(json.dumps({
                'runtime': self.runtime, 'domain': self.domain, 'legacy': legacy,
                'implicit': encode_runtime(implicit), 'invalids': malformed_runtime(self.runtime),
                'catalog': encode_runtime(compile_content()),
            }, ensure_ascii=False))
            (temporary / 'verify.gd').write_text(GODOT_CHECK)
            environment = {**os.environ, 'HOME': directory, 'XDG_DATA_HOME': directory, 'XDG_CACHE_HOME': directory, 'XDG_CONFIG_HOME': directory}
            process = subprocess.run([godot_executable(), '--headless', '--path', directory, '--script', 'res://verify.gd'],
                                     env=environment, text=True, capture_output=True, timeout=30)
            output = process.stdout + '\n' + process.stderr
            self.assertEqual(process.returncode, 0, output)
            self.assertNotIn('SCRIPT ERROR:', output)
            self.assertNotIn('ERROR:', output)
            self.assertIn('PASS dispatch content format:', output)


GODOT_CHECK = '''extends SceneTree
const Format = preload("res://content/runtime_content_format.gd")
const TypedJson = preload("res://app/save_json.gd")
var failures := []
var checks := 0
func check(value: bool, label: String):
    checks += 1
    if not value: failures.append(label)
func _initialize():
    var fixture: Dictionary = TypedJson.parse(FileAccess.get_file_as_string("res://fixtures.json"))
    check(Format.validate(fixture.catalog).is_empty(), "accept complete compiled catalog: " + Format.validate(fixture.catalog))
    check(Format.validate(fixture.runtime).is_empty(), "accept dispatch runtime: " + Format.validate(fixture.runtime))
    check(Format.validate(fixture.implicit).is_empty(), "accept implicit legacy portal identity")
    check(Format.validate(Format.compact_fixture(fixture.legacy)).is_empty(), "accept old fixture without synthesizing dispatch")
    check(Format.expand_content(fixture.runtime) == fixture.domain, "expand preserves dispatch values")
    check(Format.compact_fixture(fixture.domain) == fixture.runtime, "compact preserves compiled dispatch")
    var first: Dictionary = Format.expand_content(fixture.runtime)
    first.stages[0].waves[0].groupDispatch[0].spawnIndices.append(999)
    check(Format.expand_content(fixture.runtime) == fixture.domain, "expanded dispatch ownership")
    for index in range(fixture.invalids.size()):
        check(not Format.validate(fixture.invalids[index]).is_empty(), "reject invalid dispatch fixture " + str(index))
    if failures.is_empty():
        print("PASS dispatch content format: ", checks, " checks")
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)
'''


if __name__ == '__main__':
    unittest.main()
