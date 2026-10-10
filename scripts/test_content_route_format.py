#!/usr/bin/env python3
"""Route-aware storage, map references and Python/Godot wire-format parity."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from content_compiler import ROOT, queue_for, read_json
from content_runtime_format import decode_runtime, encode_runtime, schedule_digest
from run_godot_native_regressions import godot_executable


def route_domain():
    """Keep real metadata while isolating this contract from catalog progression."""
    runtime = read_json(ROOT / 'godot/content/game_content.json')
    runtime['stages'] = runtime['stages'][:1]
    stage = runtime['stages'][0]
    stage['waves'] = stage['waves'][:1]
    wave = stage['waves'][0]
    runtime['spawnSchedules'] = {wave['spawnSchedule']: runtime['spawnSchedules'][wave['spawnSchedule']]}
    domain = decode_runtime(runtime)
    # This helper deliberately exercises the pre-metadata fixture contract.
    domain.pop('schedulingPolicy', None)
    for item in domain['stages'][0]['waves']: item.pop('groupDispatch', None)
    stage = domain['stages'][0]
    upper = [[0, 0], [1, 0], [2, 0], [2, 1]]
    lower = [[0, 1], [1, 1], [2, 1]]
    stage['map'] = {
        'columns': 3, 'rows': 3,
        'tiles': ['spawn', 'path', 'path', 'spawn', 'path', 'core', 'build', 'blocked', 'build'],
        'path': upper,
        'routes': [
            {'id': 'upper', 'label': 'Upper route', 'path': upper},
            {'id': 'lower', 'label': 'Lower route', 'path': lower},
        ],
    }
    wave = stage['waves'][0]
    wave['groups'] = [
        {'enemyType': 'normal', 'count': 2, 'interval': 0.5, 'startDelay': 0.0, 'routeId': 'upper'},
        {'enemyType': 'fast', 'count': 2, 'interval': 0.5, 'startDelay': 0.25, 'routeId': 'lower'},
    ]
    wave['spawnQueue'] = queue_for(wave['groups'])
    return domain


def malformed_maps(domain):
    mutations = [
        lambda m: m.update(routes=None),
        lambda m: m.update(routes=[]),
        lambda m: m.update(routes=m['routes'][:1]),
        lambda m: m['routes'][1].update(id='upper'),
        lambda m: m['routes'][1].update(id=''),
        lambda m: m['routes'][1].update(id=' lower'),
        lambda m: m['routes'][1].update(id=1),
        lambda m: m['routes'][1].update(label=''),
        lambda m: m['routes'][1].update(label=1),
        lambda m: m['routes'][1].update(unknown=True),
        lambda m: m['routes'][1].update(path=[[0, 1], [2, 1]]),
        lambda m: m['routes'][1]['path'][1].__setitem__(0, 99),
        lambda m: m['routes'][1]['path'][1].__setitem__(0, True),
        lambda m: m['routes'][1].update(path=[[0, 1], [1, 1], [1, 0], [2, 0]]),
        lambda m: m['routes'][1].update(path=[[0, 1], [1, 1], [0, 1], [1, 1], [2, 1]]),
        lambda m: m['tiles'].__setitem__(3, 'path'),
        lambda m: m['tiles'].__setitem__(4, 'build'),
        lambda m: m['tiles'].__setitem__(5, 'path'),
        lambda m: m.update(path=m['routes'][1]['path']),
        lambda m: m['routes'][1].update(teleportPairs=[{'color': 'blue', 'entrance': [0, 1], 'exit': [1, 1]}]),
    ]
    invalids = []
    for mutate in mutations:
        invalid = copy.deepcopy(domain)
        mutate(invalid['stages'][0]['map'])
        invalids.append(invalid)
    return invalids


def teleport_domain():
    domain = route_domain()
    upper = [[0, 0], [1, 0], [2, 0], [3, 0], [3, 1]]
    lower = [[0, 2], [1, 2], [2, 1], [3, 1]]
    domain['stages'][0]['map'] = {
        'columns': 4, 'rows': 3,
        'tiles': ['spawn', 'path', 'path', 'path', 'blocked', 'build', 'path', 'core', 'spawn', 'path', 'blocked', 'build'],
        'path': upper,
        'routes': [
            {'id': 'upper', 'label': 'Upper route', 'path': upper},
            {'id': 'lower', 'label': 'Lower portal', 'path': lower,
             'teleportPairs': [{'color': 'blue', 'entrance': [1, 2], 'exit': [2, 1]}]},
        ],
    }
    return domain


def invalid_runtime_references(runtime):
    invalids = []
    for target in ('group', 'spawn'):
        for value in (None, '', ' missing ', 'missing', 1, [], True):
            invalid = copy.deepcopy(runtime)
            wave = invalid['stages'][0]['waves'][0]
            if target == 'group':
                wave['groups'][0]['routeId'] = value
            else:
                invalid['spawnSchedules'][wave['spawnSchedule']][0][2] = value
            invalids.append(invalid)
        invalid = copy.deepcopy(runtime)
        wave = invalid['stages'][0]['waves'][0]
        if target == 'group':
            del wave['groups'][0]['routeId']
        else:
            invalid['spawnSchedules'][wave['spawnSchedule']][0].pop()
        invalids.append(invalid)
    return invalids


class RouteFormatTests(unittest.TestCase):
    def test_legacy_and_route_digest_golden_bytes(self):
        queue = [{'enemyType': 'normal', 'delay': 0.0}, {'enemyType': '보스', 'delay': 0.18}]
        self.assertEqual(schedule_digest(queue), '2f91495c2bc87c3034a7cbc229176db3507b4a771688542b83542771db5afc36')
        queue[0]['routeId'] = '상단'
        self.assertEqual(schedule_digest(queue), 'bf56e977e2aee163dca295a155a560e86f0b5be6820bc2b319e46f8f0ff380fc')
        queue[1]['routeId'] = 'lower'
        self.assertEqual(schedule_digest(queue), '0a67cf5e514eb0c785279d2b1bb15d723a8dfd123cb84829154afad740dd416a')
        queue[1]['routeId'] = 'upper'
        self.assertNotEqual(schedule_digest(queue), '0a67cf5e514eb0c785279d2b1bb15d723a8dfd123cb84829154afad740dd416a')
        for value in (None, '', ' upper ', 1, [], True):
            queue[1]['routeId'] = value
            with self.subTest(route_id=value), self.assertRaises(ValueError):
                schedule_digest(queue)

    def test_route_rows_roundtrip_and_shared_schedule_ownership(self):
        domain = route_domain()
        second = copy.deepcopy(domain['stages'][0]['waves'][0])
        second['round'] = 2
        domain['stages'][0]['waves'].append(second)
        runtime = encode_runtime(domain)
        self.assertEqual(runtime['runtimeFormat']['spawnColumns'], ['enemyType', 'delay'])
        self.assertEqual(len(runtime['spawnSchedules']), 1)
        rows = next(iter(runtime['spawnSchedules'].values()))
        self.assertEqual([row[2] for row in rows], ['upper', 'lower', 'upper', 'lower'])
        restored = decode_runtime(runtime)
        self.assertEqual(restored, domain)
        restored['stages'][0]['waves'][0]['spawnQueue'][0]['routeId'] = 'lower'
        self.assertEqual(restored['stages'][0]['waves'][1]['spawnQueue'][0]['routeId'], 'upper')
        self.assertEqual(decode_runtime(runtime), domain)

    def test_routes_require_valid_traversable_paths_and_explicit_references(self):
        domain = route_domain()
        for index, invalid in enumerate(malformed_maps(domain)):
            with self.subTest(map=index), self.assertRaises(ValueError):
                encode_runtime(invalid)
        runtime = encode_runtime(domain)
        for index, invalid in enumerate(invalid_runtime_references(runtime)):
            with self.subTest(reference=index), self.assertRaises(ValueError):
                decode_runtime(invalid)
        invalid = copy.deepcopy(domain)
        invalid['stages'][0]['waves'][0]['spawnQueue'][0]['routeId'] = 'missing'
        with self.assertRaisesRegex(ValueError, 'routeId'):
            encode_runtime(invalid)
        invalid = copy.deepcopy(domain)
        invalid['stages'][0]['waves'][0]['spawnQueue'][0].pop('routeId')
        with self.assertRaisesRegex(ValueError, 'routeId'):
            encode_runtime(invalid)
        invalid = copy.deepcopy(domain)
        invalid['stages'][0]['map'].pop('routes')
        with self.assertRaisesRegex(ValueError, 'routeId'):
            encode_runtime(invalid)

    def test_valid_schedule_cannot_be_reused_on_incompatible_map(self):
        domain = route_domain()
        runtime = encode_runtime(domain)
        foreign = copy.deepcopy(runtime['stages'][0])
        foreign['id'] += 1
        foreign['map']['routes'][1]['id'] = 'other'
        for group in foreign['waves'][0]['groups']:
            if group['routeId'] == 'lower': group['routeId'] = 'other'
        runtime['stages'].append(foreign)
        with self.assertRaisesRegex(ValueError, 'routeId'):
            decode_runtime(runtime)

    def test_route_specific_teleport_jump_is_validated_independently(self):
        domain = teleport_domain()
        self.assertEqual(decode_runtime(encode_runtime(domain)), domain)
        domain['stages'][0]['map']['routes'][1].pop('teleportPairs')
        with self.assertRaisesRegex(ValueError, 'Disconnected'):
            encode_runtime(domain)

    def test_godot_codec_parity_and_validation(self):
        domain = route_domain()
        runtime = encode_runtime(domain)
        invalids = invalid_runtime_references(runtime)
        for invalid in malformed_maps(domain):
            compact = copy.deepcopy(runtime)
            compact['stages'][0]['map'] = invalid['stages'][0]['map']
            invalids.append(compact)
        legacy = copy.deepcopy(domain)
        legacy['stages'][0]['map'].pop('routes')
        for group in legacy['stages'][0]['waves'][0]['groups']: group.pop('routeId')
        for entry in legacy['stages'][0]['waves'][0]['spawnQueue']: entry.pop('routeId')
        with tempfile.TemporaryDirectory(prefix='route-format-') as directory:
            temporary = Path(directory)
            for name in ('content/runtime_content_format.gd', 'combat/teleport_pairs.gd', 'app/save_json.gd'):
                target = temporary / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / 'godot' / name, target)
            (temporary / 'project.godot').write_text('[application]\nconfig/name="Route format regression"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            (temporary / 'fixtures.json').write_text(json.dumps({'runtime': runtime, 'domain': domain, 'teleport': encode_runtime(teleport_domain()), 'legacy': encode_runtime(legacy), 'invalids': invalids}, ensure_ascii=False))
            (temporary / 'verify.gd').write_text(GODOT_CHECK)
            environment = {**os.environ, 'HOME': directory, 'XDG_DATA_HOME': directory, 'XDG_CACHE_HOME': directory, 'XDG_CONFIG_HOME': directory}
            process = subprocess.run([godot_executable(), '--headless', '--path', directory, '--script', 'res://verify.gd'],
                                     env=environment, text=True, capture_output=True, timeout=30)
            output = process.stdout + '\n' + process.stderr
            self.assertEqual(process.returncode, 0, output)
            self.assertNotIn('SCRIPT ERROR:', output)
            self.assertNotIn('ERROR:', output)
            self.assertIn('PASS route content format:', output)


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
    check(Format.validate(fixture.runtime).is_empty(), "accept routed runtime: " + Format.validate(fixture.runtime))
    check(Format.validate(fixture.legacy).is_empty(), "accept legacy runtime")
    check(Format.validate(fixture.teleport).is_empty(), "accept route-specific portal")
    var invalid_portal: Dictionary = fixture.teleport.duplicate(true)
    invalid_portal.stages[0].map.routes[1].erase("teleportPairs")
    check(not Format.validate(invalid_portal).is_empty(), "reject unregistered route portal jump")
    check(Format.expand_content(fixture.runtime) == fixture.domain, "expand preserves route fields")
    check(Format.compact_fixture(fixture.domain) == fixture.runtime, "compact matches Python rows and identities")
    check(Format.schedule_digest([["normal", 0.0], ["보스", 0.18]]) == "2f91495c2bc87c3034a7cbc229176db3507b4a771688542b83542771db5afc36", "legacy binary digest")
    check(Format.schedule_digest([["normal", 0.0, "상단"], ["보스", 0.18]]) == "bf56e977e2aee163dca295a155a560e86f0b5be6820bc2b319e46f8f0ff380fc", "mixed Unicode digest")
    check(Format.schedule_digest([["normal", 0.0, "상단"], ["보스", 0.18, "lower"]]) == "0a67cf5e514eb0c785279d2b1bb15d723a8dfd123cb84829154afad740dd416a", "routed Unicode digest")
    var first: Dictionary = Format.expand_content(fixture.runtime)
    first.stages[0].waves[0].spawnQueue[0].routeId = "changed"
    check(Format.expand_content(fixture.runtime) == fixture.domain, "expanded route ownership")
    for index in range(fixture.invalids.size()):
        check(not Format.validate(fixture.invalids[index]).is_empty(), "reject invalid route fixture " + str(index))
    if failures.is_empty():
        print("PASS route content format: ", checks, " checks")
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)
'''


if __name__ == '__main__':
    unittest.main()
