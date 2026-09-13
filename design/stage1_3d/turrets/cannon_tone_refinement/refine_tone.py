"""Change only the orange paint multiplier; retain the original GLB BIN chunk."""
from pathlib import Path
import struct,json,hashlib
root=Path('/Users/sejin/Documents/Codex/RuneNexus');asset=root/'assets/images/stage1_3d/turrets/cannon.glb'
b=asset.read_bytes();json_length=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+json_length]);tail=b[20+json_length:]
paint=next(m for m in g['materials'] if 'matte_orange' in m['name']);before=dict(paint['pbrMetallicRoughness']);paint['pbrMetallicRoughness']['baseColorFactor']=[.82,.96,1.0,1.0]
encoded=json.dumps(g,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);result=struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(tail))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+tail;asset.write_bytes(result)
record={'material':paint['name'],'before':before,'after':paint['pbrMetallicRoughness'],'binaryChunkSha256':hashlib.sha256(tail).hexdigest(),'binaryChunkUnchanged':result[20+len(encoded):]==tail,'bytes':len(result)}
(root/'design/stage1_3d/turrets/cannon_tone_refinement/change.json').write_text(json.dumps(record,indent=2));print(json.dumps(record))
