"""Compare the existing 60-second integrated runner with its prior record."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tool/godot_performance'))
from summarize_results import histogram_stats

old = json.loads((ROOT / 'docs/analysis/godot_validation_20260916/fire-after-final.json').read_text())
new = json.loads((OUT / 'projectile-final.json').read_text())
assert not any(r.get('event') == 'error' for r in new)
report = {}
for name in ['normal', 'fire']:
    samples = [r for r in new if r.get('scenario') == name and r.get('event') == 'sample']
    assert len(samples) == 60
    before = next(r for r in old if r.get('event') == 'end' and r.get('scenario') == name)
    after = next(r for r in new if r.get('event') == 'end' and r.get('scenario') == name)
    assert all(r['enemies'] == 3 and r['turrets'] == 6 for r in samples)
    snapshot = next(r for r in new if r.get('event') == 'snapshot' and r.get('scenario') == name)
    assert 'projectileEvents' in snapshot['frame']
    layers = []
    text = (OUT / f'projectile-{name}-surfaceflinger.txt').read_text()
    for part in text.split('layerName = ')[1:]:
        layer = part.splitlines()[0]
        if 'com.example.rune_nexus.godotpreview/' not in layer:
            continue
        fps = re.search(r'^averageFPS = ([\d.]+)', part, re.M)
        hist = re.search(r'present2present histogram is as below:\s*\n([^\n]+)', part)
        buckets = {int(k): int(v) for k,v in re.findall(r'(\d+)ms=(\d+)',hist[1])} if hist else {}
        layers.append({'name':layer, 'fps':float(fps[1]) if fps else None, 'present_intervals':histogram_stats(buckets)})
    report[name] = {
        'before':before, 'after':after,
        'flutter_update_fps_change_percent':(after['flutter_update_fps']/before['flutter_update_fps']-1)*100,
        'godot_fps_sample_mean':sum(r['metrics']['fps'] for r in samples)/len(samples),
        'surfaceflinger_layers':layers,
        'event_path_confirmed':True,
    }
(OUT / 'comparison.json').write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n')
for name,r in report.items():
    a=r['after']
    print(name, f"{r['before']['flutter_update_fps']:.2f} -> {a['flutter_update_fps']:.2f} ({r['flutter_update_fps_change_percent']:+.1f}%)", 'p95', a['flutter_update_gap_us']['p95']/1000, 'p99', a['flutter_update_gap_us']['p99']/1000)
