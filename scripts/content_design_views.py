#!/usr/bin/env python3
"""Resolve expansion design manifests as source views, without output inputs."""
from __future__ import annotations
import argparse
import copy
from pathlib import Path
from content_compiler import ROOT, compile_content, load_sources, read_json, record_json


def map_annotations(map_data: dict, annotations: dict) -> dict:
    """Recompute summaries after geometry edits, retaining approved build-cell order."""
    result = copy.deepcopy(annotations)
    cols, tiles, path = map_data['columns'], map_data['tiles'], map_data['path']
    cells = [[i % cols, i // cols] for i, tile in enumerate(tiles) if tile == 'build']
    ordered = []
    for cell in result.get('buildCells', []):
        if cell in cells and cell not in ordered: ordered.append(cell)
    result['buildCells'] = ordered + [cell for cell in cells if cell not in ordered]
    result['pathTiles'] = len(path)
    result['travelEdges'] = len(path) - 1
    pairs = map_data.get('teleportPairs', [])
    jumps = {path.index(pair['entrance']): path.index(pair['exit']) for pair in pairs}
    segments, count, index = [], 0, 0
    while index < len(path) - 1:
        if index in jumps:
            segments.append(count)
            count, index = 0, jumps[index]
        else:
            count += 1
            index += 1
    segments.append(count)
    result['walkingSegments'] = segments
    result['walkingEdges'] = sum(segments)
    gaps = []
    for pair in pairs:
        start, end = pair['entrance'], pair['exit']
        if start[0] != end[0] and start[1] != end[1]:
            continue
        dx = (end[0] > start[0]) - (end[0] < start[0])
        dy = (end[1] > start[1]) - (end[1] < start[1])
        x, y = start[0] + dx, start[1] + dy
        while [x, y] != end:
            if tiles[y * cols + x] == 'blocked': gaps.append([x, y])
            x, y = x + dx, y + dy
    result['portalGapCells'] = gaps
    return result


def load_design_view(path: Path, root: Path = ROOT) -> dict:
    manifest = read_json(path)
    if not isinstance(manifest, dict):
        raise ValueError('Design view manifest must be an object')
    chapter = manifest.get('chapter')
    expected_ids = list(range(16, 21) if chapter == 1 else range(21, 26))
    if (type(manifest.get('schemaVersion')) is not int or manifest.get('schemaVersion') != 1
            or type(chapter) is not int or chapter not in (1, 2)
            or manifest.get('stageIds') != expected_ids
            or manifest.get('view') not in ('chapter-expansion-maps', 'chapter-expansion-rounds')
            or not isinstance(manifest.get('metadata'), dict)):
        raise ValueError('Invalid expansion design view manifest')
    _, _, _, sources, ordinals = load_sources(root)
    authored = {s['id']: s for s in sources}
    compiled = {s['id']: s for s in compile_content(root)['stages']}
    result = copy.deepcopy(manifest['metadata'])
    if manifest['view'] == 'chapter-expansion-maps':
        result['maps'] = []
        for stage_id in expected_ids:
            stage = authored[stage_id]
            design = map_annotations(stage['map'], stage['design'])
            design.update({'progressionOrdinal': ordinals[stage_id], 'name': stage['name'],
                           **copy.deepcopy(stage['map'])})
            design.setdefault('teleportPairs', [])
            result['maps'].append(design)
    else:
        result['stages'] = []
        for stage_id in expected_ids:
            stage = authored[stage_id]
            waves = []
            for source, runtime in zip(stage['waves'], compiled[stage_id]['waves']):
                wave = copy.deepcopy(source.get('design', {}))
                wave.update({'round': runtime['round'], 'label': runtime['previewText'],
                             'clearRewardGold': runtime['clearRewardGold'],
                             'groups': runtime['groups'], 'spawnQueue': runtime['spawnQueue']})
                waves.append(wave)
            result['stages'].append({'chapterStage': stage['design']['chapterStage'],
                                     'name': stage['name'], 'progressionOrdinal': ordinals[stage_id],
                                     'rounds': waves})
    return result


def chapter_views(chapter: int, root: Path = ROOT):
    folder = root / f'design/chapter{chapter}_map_expansion'
    return (load_design_view(folder / 'maps.json', root),
            load_design_view(folder / 'rounds/rounds.json', root))


def export_chapter(chapter: int, root: Path = ROOT, output: Path | None = None):
    maps, rounds = chapter_views(chapter, root)
    destination = output or root / 'build/content_design_views' / f'chapter{chapter}'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'maps.json').write_text(record_json(maps), encoding='utf-8')
    (destination / 'rounds.json').write_text(record_json(rounds), encoding='utf-8')
    return destination


def main(chapter: int | None = None):
    parser = argparse.ArgumentParser(description=__doc__)
    if chapter is None:
        parser.add_argument('chapter', type=int, choices=(1, 2))
    parser.add_argument('--check', action='store_true', help='validate without writing')
    parser.add_argument('--output', type=Path, help='local export directory')
    args = parser.parse_args()
    selected = chapter if chapter is not None else args.chapter
    if args.check:
        maps, rounds = chapter_views(selected)
        if len(maps['maps']) != 5 or len(rounds['stages']) != 5 or any(
                len(s['rounds']) != 40 for s in rounds['stages']):
            raise ValueError('Expansion view requires five maps and 200 rounds')
        print(f'PASS chapter {selected} source view: 5 maps, 200 rounds; no generated input')
    else:
        print(f'Exported chapter {selected} source views to {export_chapter(selected, output=args.output)}')


if __name__ == '__main__':
    main()
