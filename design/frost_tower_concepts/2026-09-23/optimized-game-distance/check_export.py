"""Byte-level baseline/candidate checks. Does not install or alter game assets."""
from pathlib import Path
import json,struct,hashlib,subprocess,runpy
OUT=Path(__file__).resolve().parent
BASELINE_COMMIT='0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047'
original=subprocess.check_output(['git','show',BASELINE_COMMIT+':assets/images/stage1_3d/turrets/frost.glb'])
candidate=(OUT/'frost-optimized.glb').read_bytes()
def parse(data):
 n=struct.unpack_from('<I',data,12)[0];return json.loads(data[20:20+n]),data[28+n:]
def images(j,data):
 return sorted(hashlib.sha256(data[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]).hexdigest() for im in j['images'] for v in [j['bufferViews'][im['bufferView']]])
g,x=parse(original);h,y=parse(candidate)
assert hashlib.sha256(original).hexdigest()=='e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544'
assert images(g,x)==images(h,y)
assert sorted(m['name'] for m in g['materials'])==sorted(m['name'] for m in h['materials'])
for name in ['turret_root','turret_head','turret_barrel','muzzle']:
 n=next(n for n in g['nodes'] if n['name']==name);m=next(n for n in h['nodes'] if n['name']==name)
 assert {k:v for k,v in n.items() if k not in ['children','mesh']}=={k:v for k,v in m.items() if k not in ['children','mesh']}
runpy.run_path(str(OUT/'check_glb_uv.py'))
report={'baseline_git_commit':BASELINE_COMMIT,'baseline_sha256':hashlib.sha256(original).hexdigest(),'optimized_sha256':hashlib.sha256(candidate).hexdigest(),'embedded_image_bytes_identical':True,'material_names_identical':True,'rig_transforms_identical':True,'triangles':sum(h['accessors'][p['indices']]['count']//3 for m in h['meshes'] for p in m['primitives']),'uv_slots_pass':json.load(open(OUT/'glb_uv_validation.json'))['pass']}
(OUT/'export-check.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
