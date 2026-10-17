#!/usr/bin/env python3
"""Resize approved source art without cropping or changing the established gem IDs."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUTPUT = ROOT / 'assets/images/gems/simplified'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Compare generated pixels without writing files')
    args = parser.parse_args()
    records = []
    for source in sorted((HERE / 'source').glob('*.png')):
        image = Image.open(source)
        assert image.mode == 'RGBA', source
        assert image.getchannel('A').getextrema() == (0, 255), source
        target = OUTPUT / source.name
        assert target.is_file(), f'Unknown runtime gem: {source.stem}'
        small = image.resize((128, 128), Image.Resampling.LANCZOS)
        if args.check:
            current = Image.open(target)
            assert current.mode == 'RGBA' and current.size == (128, 128), target
            assert current.tobytes() == small.tobytes(), f'Stale runtime art: {target}'
        else:
            small.save(target, optimize=True)
        records.append({'id': source.stem, 'source': str(source.relative_to(ROOT)),
                        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                        'runtime': str(target.relative_to(ROOT)),
                        'runtime_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                        'runtime_size': [128, 128]})
    if not args.check:
        (HERE / 'manifest.json').write_text(json.dumps({'resize': 'Pillow LANCZOS; full canvas; no crop', 'gems': records}, indent=2) + '\n')
    print(f'PASS: {len(records)} approved gem sources match 128px runtime images')

if __name__ == '__main__':
    main()
