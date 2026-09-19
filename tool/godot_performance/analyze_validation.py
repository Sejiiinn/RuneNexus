#!/usr/bin/env python3
"""Parse chunked Flutter and native logs; preserve distinct timing domains."""
import json
from pathlib import Path
import sys

def parse(path):
    records, buffer = [], ''
    for line in path.read_text(errors='replace').splitlines():
        if 'RN_VALIDATION_CHUNK ' in line:
            kind, text = line.split('RN_VALIDATION_CHUNK ',1)[1].split(' ',1)
            buffer = text if kind == 'START' else buffer + text
        elif 'RN_VALIDATION_END' in line and buffer:
            records.append(json.loads(buffer)); buffer = ''
        elif 'RN_NATIVE ' in line:
            try: records.append(json.loads(line.split('RN_NATIVE ',1)[1]))
            except json.JSONDecodeError: pass
    return records

if __name__ == '__main__':
    source = Path(sys.argv[1])
    records = parse(source)
    source.with_suffix('.json').write_text(json.dumps(records,indent=2,ensure_ascii=False))
    fixtures = Path(__file__).parent/'native/fixtures'
    fixtures.mkdir(exist_ok=True)
    for record in records:
        if record.get('event') == 'snapshot' and '--fixtures' in sys.argv:
            frame = record['frame']
            frame['path_tiles'] = record.get('path_tiles',[])
            frame['capture_metadata'] = {k:v for k,v in record.items() if k not in ['frame','path_tiles']}
            (fixtures/(record['scenario']+'.json')).write_text(json.dumps(frame,ensure_ascii=False))
    for record in records:
        if record.get('event') in ['end','complete','error']:
            print(json.dumps(record,ensure_ascii=False))
