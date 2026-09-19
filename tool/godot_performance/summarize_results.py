#!/usr/bin/env python3
"""Summarize separate engine, Flutter, and Android presentation measurements.

No third-party dependencies. The default excludes the pilot baseline.json.
SurfaceFlinger quantiles are bucket labels, not exact per-frame quantiles.
"""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

DEFAULT = Path('docs/analysis/godot_validation_20260915')


def histogram_stats(histogram: dict[int, int]) -> dict:
    count = sum(histogram.values())
    if not count:
        return {'samples': 0, 'histogram_ms': histogram}
    def percentile(fraction: float) -> int:
        rank = math.ceil(count * fraction)
        running = 0
        for bucket, frequency in sorted(histogram.items()):
            running += frequency
            if running >= rank:
                return bucket
        raise AssertionError('Invalid histogram')
    return {
        'samples': count,
        'p50_bucket_ms': percentile(.5),
        'p95_bucket_ms': percentile(.95),
        'p99_bucket_ms': percentile(.99),
        'mean_bucket_ms_approx': sum(k * v for k, v in histogram.items()) / count,
        'histogram_ms': histogram,
    }


def parse_surfaceflinger(path: Path) -> dict:
    content = path.read_text()
    layers = []
    # Do not use the global display histogram or another app's layer.
    for match in re.finditer(r'^layerName = (.+)$', content, re.MULTILINE):
        name = match.group(1)
        if 'SurfaceView[' not in name or 'GodotBenchmarkActivity]' not in name:
            continue
        tail = content[match.end():]
        next_layer = re.search(r'^layerName = ', tail, re.MULTILINE)
        block = tail[:next_layer.start()] if next_layer else tail
        fps = re.search(r'^averageFPS = ([0-9.]+)', block, re.MULTILINE)
        hist = re.search(r'^present2present histogram is as below:\s*\n([^\n]+)', block, re.MULTILINE)
        values = {} if not hist else {
            int(bucket): int(count)
            for bucket, count in re.findall(r'(\d+)ms=(\d+)', hist.group(1))
        }
        total = re.search(r'^totalFrames = (\d+)', block, re.MULTILINE)
        layers.append({
            'layer': name,
            'average_present_fps': float(fps.group(1)) if fps else None,
            'total_frames': int(total.group(1)) if total else None,
            'present_to_present': histogram_stats(values),
        })
    bounds = {
        key: int(value) for key, value in re.findall(
            r'^(statsStart|statsEnd|displayOnTime) = (\d+)', content, re.MULTILINE
        )
    }
    return {'source': path.name, 'window': bounds, 'layers': layers,
            'warning': None if layers else 'Matching Godot SurfaceView layer not found'}


def numeric_stats(values: list[float]) -> dict:
    if not values:
        return {'samples': 0}
    values = sorted(values)
    return {'samples': len(values), 'mean': sum(values) / len(values),
            'min': values[0], 'max': values[-1],
            'p95': values[math.ceil(len(values) * .95) - 1]}


def baseline_results(path: Path) -> dict:
    if not path.exists():
        return {'source': path.name, 'status': 'not_available', 'scenarios': {}}
    data = json.loads(path.read_text())
    records = data if isinstance(data, list) else data.get('records', [])
    records = [record for record in records if record.get('runner') == 'flutter_flame_godot']
    scenarios = {}
    for record in records:
        name = record.get('scenario')
        if not name:
            continue
        entry = scenarios.setdefault(name, {'native_fps_samples': []})
        event = record.get('event')
        if event == 'sample':
            metrics = record.get('metrics', {})
            fps = metrics.get('fps')
            if isinstance(fps, (int, float)):
                entry['native_fps_samples'].append(fps)
            entry.setdefault('workload_samples', []).append({
                key: record[key] for key in ('elapsed_ms', 'enemies', 'burning', 'projectiles', 'effects', 'rss_bytes')
                if key in record
            })
        elif event == 'begin':
            entry['conditions'] = record
        elif event == 'end':
            entry['flutter_measurement'] = record
    for entry in scenarios.values():
        entry['native_fps_sample_stats'] = numeric_stats(entry.pop('native_fps_samples'))
    return {'source': path.name,
            'status': 'complete' if any(r.get('event') == 'complete' for r in records) else 'incomplete',
            'errors': [r for r in records if r.get('event') == 'error'], 'scenarios': scenarios}


def collect(directory: Path, baseline: str) -> dict:
    native = []
    for path in sorted([*directory.glob('native*.json'), *directory.glob('optimized-*.json'), *directory.glob('sustain-*.json'), *directory.glob('repeat-*.json'), *directory.glob('acceptance-*.json'), *directory.glob('range1x-*.json'), *directory.glob('ranges-*.json'), *directory.glob('levels-*.json'), *directory.glob('cache-*-fire.json')]):
        data = json.loads(path.read_text())
        summary = data.get('summary', data) if isinstance(data, dict) else {}
        if summary.get('event') != 'complete' or 'frame_ms' not in summary:
            continue
        surface_path = path.with_name(path.stem + '-surfaceflinger.txt')
        surface = parse_surfaceflinger(surface_path) if surface_path.exists() else None
        native.append({'source': path.name,
                       'engine_process_measurement': summary,
                       'surface_presentation_measurement': surface})
    return {
        'schema': 1,
        'metadata': {
            'target_fps': 60,
            'acceptance_speed': 1,
            'stress_policy': '4x and 96-enemy runs are supplementary diagnostics, not acceptance requirements.',
            'environment': 'Android ARM64 emulator / Goldfish GFXStream Apple M4; not a physical device',
            'metric_definitions': {
                'engine_process_measurement': 'Godot process-entry wall-clock intervals; fps = 1000 / mean interval ms',
                'surface_presentation_measurement': 'Android SurfaceFlinger GodotBenchmarkActivity SurfaceView presentation cadence',
                'baseline_native_fps': 'One-second getMetrics fps samples; mean of samples, not pooled presentation FPS',
                'flutter_update_gap_us': 'Flame update-entry intervals, not Android presentation cadence',
                'flutter_raster_us': 'Flutter raster duration, not full-frame or GPU time',
                'surface_quantiles': 'Histogram bucket labels; approximate, not exact timestamp quantiles',
            },
            'limitations': [
                'Pilot baseline.json is excluded; baseline-final.json is the default final input.',
                'SurfaceFlinger and engine windows may differ; no sample-level matching is claimed.',
                'GPU time is unmeasured; zero or null values must not be treated as zero GPU cost.',
                'Native simulation and minimal HUD are not the full production battle rules or full Flutter HUD.',
                'Emulator findings cannot certify physical-device performance, thermals, or battery life.',
                'Native render_samples/counters may include different observation intervals; compare workload explicitly.',
            ],
        },
        'baseline': baseline_results(directory / baseline),
        'native_runs': native,
        'surfaceflinger_files': [parse_surfaceflinger(path) for path in sorted(directory.glob('native*-surfaceflinger.txt'))],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', type=Path, default=DEFAULT)
    parser.add_argument('--baseline', default='baseline-final.json')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = args.output or args.directory / 'results.json'
    result = collect(args.directory, args.baseline)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'{output}: {len(result["native_runs"])} native runs; baseline {result["baseline"]["status"]}')


if __name__ == '__main__':
    main()
