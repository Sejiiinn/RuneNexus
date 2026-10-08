"""Stage approved GLB clips without resampling its mesh, skin or animation buffers."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[4]
SOURCE = Path('/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/normal-multiview-20261007-v3/animation-rig-v2/exports/stonegolem-rig-walk-death-v2.glb')
SOURCE_SHA = 'bfbc450101e547ad162c58c62cc22bc429ac8be051eae0d4a40b06f6813b750b'
WALK_SOURCE = Path('/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/normal-multiview-20261007-v3/animation-ingame-v1/exports/stonegolem-ingame-walk-v1.glb')
WALK_SHA = '8bda2628b6800db14b9337eeaad23603f49504b45b16302e5ef1be401e9ec0ef'
# Preserve the previous normal rest height with a uniform import root transform.
NORMALIZATION = 1.0977294454351068 / (1.0017364025115967 + 0.0015829503536224365)


def stage(source: Path, target: Path, clip: str, expected_sha: str) -> dict:
    blob = source.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == expected_sha, 'Authorized source changed'
    count = struct.unpack_from('<I', blob, 12)[0]
    data = json.loads(blob[20:20 + count])
    tail = blob[20 + count:]
    data['animations'] = [a for a in data['animations'] if a['name'] == clip]
    assert len(data['animations']) == 1
    # All animation channels and binary payloads are unchanged. The common root
    # transform scales every skinned vertex, bone and motion consistently.
    for scene in data['scenes']:
        node = len(data['nodes'])
        data['nodes'].append({'name': 'Normal_Game_Normalization',
                              'scale': [NORMALIZATION] * 3,
                              'children': scene['nodes']})
        scene['nodes'] = [node]
    encoded = json.dumps(data, separators=(',', ':')).encode()
    encoded += b' ' * ((-len(encoded)) % 4)
    output = struct.pack('<III', 0x46546C67, 2, 20 + len(encoded) + len(tail))
    output += struct.pack('<II', len(encoded), 0x4E4F534A) + encoded + tail
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(output)
    return {'path': str(target.relative_to(ROOT)), 'clip': clip,
            'sha256': hashlib.sha256(output).hexdigest(), 'bytes': len(output),
            'source_binary_payload_exact': tail == blob[20 + count:]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--walk-source', type=Path, default=WALK_SOURCE,
                        help='Authorized game retarget; Death continues using the approved source')
    parser.add_argument('--walk-sha', default=WALK_SHA, help='Pinned SHA256 for the authorized game Walk export')
    parser.add_argument('--stride', type=float, default=0.44,
                        help='Authored native contact distance per Walk cycle')
    args = parser.parse_args()
    walk_source = args.walk_source or args.source
    walk_sha = args.walk_sha or SOURCE_SHA
    if args.walk_source is not None:
        assert args.walk_sha, 'Pin the authorized retarget source SHA256'
    assert args.stride > 0
    target = ROOT / 'assets/images/stage1_3d/enemies'
    exports = [stage(walk_source, target / 'normal.glb', 'Walk', walk_sha),
               stage(args.source, target / 'normal_death.glb', 'Death', SOURCE_SHA)]
    receipt = {'source': str(args.source), 'source_sha256': SOURCE_SHA,
               'walk_source': str(walk_source), 'walk_source_sha256': walk_sha,
               'normalization': NORMALIZATION, 'forward': '+Z', 'up': '+Y',
               'native_stride': args.stride, 'exports': exports}
    Path(__file__).with_name('runtime-contract.json').write_text(
        json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(receipt, ensure_ascii=False))
