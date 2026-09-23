import json
from pathlib import Path

base = Path(__file__).parent
data = json.loads((base / 'after-measurements.json').read_text())
checks, failures = 0, []

def check(ok, message):
    global checks
    checks += 1
    if not ok:
        failures.append(message)

for width in [440, 320]:
    states = [d for d in data if d['state'].startswith(str(width))]
    for state in states:
        level = state['items']['[0, 0, 0, 0, 0, 2, 1]']
        check(level['font'] == (13 if width == 440 else 9), state['state'] + ' level font')
        target = next(x for x in state['items'].values() if x['name'] == 'TurretTargetPriority')
        check(target['font'] == 11, state['state'] + ' target font')
    for name in ['TurretTargetPriority', 'TurretCategoryAndTarget', 'TurretActionPanel', 'TurretLevelAction', 'TurretTraitAction', 'TurretSellAction', 'TurretStatsTab', 'TurretGemsTab']:
        values = [x for state in states for x in state['items'].values() if x['name'] == name]
        check(all(x['rect'] == values[0]['rect'] for x in values), str(width) + ' geometry ' + name)
    for transition in ['preview', 'confirmed', 'level9-preview', 'level10-confirmed']:
        frames = [state['draw_frame'] for state in states if state['state'].startswith(f'{width}-{transition}-frame-')]
        check(len(frames) == 8 and all(b == a + 1 for a, b in zip(frames, frames[1:])), f'{width}-{transition} consecutive frames')

result = {'checks': checks, 'failures': failures, 'states': len(data)}
(base / 'result.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result))
raise SystemExit(bool(failures))
