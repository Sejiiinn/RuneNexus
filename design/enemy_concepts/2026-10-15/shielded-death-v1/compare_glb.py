"""Compare shielded.glb before/after adding Death: mesh/image bytes and Idle keys must be identical."""
import json, struct, sys, hashlib
from array import array

def load(path):
    raw = open(path, 'rb').read()
    ln, _ = struct.unpack_from('<II', raw, 12)
    g = json.loads(raw[20:20 + ln])
    bl, _ = struct.unpack_from('<II', raw, 20 + ln)
    return g, raw[28 + ln:28 + ln + bl]

def view_bytes(g, b, view):
    v = g['bufferViews'][view]
    return b[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]

def acc_bytes(g, b, i):
    a = g['accessors'][i]
    size = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']] * {5126: 4, 5125: 4, 5123: 2, 5121: 1}[a['componentType']]
    v = g['bufferViews'][a['bufferView']]
    off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    return b[off:off + size * a['count']]

def channels(g, b, name):
    an = next(a for a in g['animations'] if a['name'] == name)
    out = {}
    for ch in an['channels']:
        s = an['samplers'][ch['sampler']]
        key = (g['nodes'][ch['target']['node']]['name'], ch['target']['path'])
        out[key] = (acc_bytes(g, b, s['input']), acc_bytes(g, b, s['output']), s.get('interpolation', 'LINEAR'))
    return out

ga, ba = load(sys.argv[1]); gb, bb = load(sys.argv[2])
report = {}
ma = {n['name']: n for n in ga['nodes']}; mb = {n['name']: n for n in gb['nodes']}
mesh_equal = True
for name, na in ma.items():
    if 'mesh' not in na: continue
    nb = mb[name]
    pa, pb = ga['meshes'][na['mesh']]['primitives'], gb['meshes'][nb['mesh']]['primitives']
    for x, y in zip(pa, pb):
        for attr in x['attributes']:
            mesh_equal &= acc_bytes(ga, ba, x['attributes'][attr]) == acc_bytes(gb, bb, y['attributes'][attr])
        mesh_equal &= acc_bytes(ga, ba, x['indices']) == acc_bytes(gb, bb, y['indices'])
report['mesh_attributes_identical'] = mesh_equal
report['images_identical'] = sorted(hashlib.sha256(view_bytes(ga, ba, i['bufferView'])).hexdigest() for i in ga['images']) == sorted(hashlib.sha256(view_bytes(gb, bb, i['bufferView'])).hexdigest() for i in gb['images'])
report['materials_identical'] = ga['materials'] == gb['materials']
rest = lambda g: {n['name']: {k: n.get(k) for k in ('translation', 'rotation', 'scale', 'children')} for n in g['nodes']}
ra, rb = rest(ga), rest(gb)
report['node_rest_differences'] = {k: (ra[k], rb.get(k)) for k in ra if {kk: vv for kk, vv in ra[k].items() if kk != 'children'} != {kk: vv for kk, vv in rb.get(k, {}).items() if kk != 'children'}}
ia, ib = channels(ga, ba, 'Idle'), channels(gb, bb, 'Idle')
report['idle_channels'] = [len(ia), len(ib)]
max_diff = 0.0
for k in ia:
    if k not in ib: report.setdefault('idle_missing', []).append(k); continue
    ta, tb = array('f', ia[k][0]), array('f', ib[k][0]); oa, ob = array('f', ia[k][1]), array('f', ib[k][1])
    assert len(ta) == len(tb) and len(oa) == len(ob), k
    max_diff = max(max_diff, max(abs(x - y) for x, y in zip(ta, tb)), max(abs(x - y) for x, y in zip(oa, ob)))
report['idle_max_abs_diff'] = max_diff
report['idle_extra_channels'] = [k for k in ib if k not in ia]
report['animations_after'] = {a['name']: len(a['channels']) for a in gb['animations']}
print(json.dumps(report, indent=1, default=str))
