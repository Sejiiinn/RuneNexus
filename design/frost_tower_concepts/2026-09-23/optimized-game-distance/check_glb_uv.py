"""Independently parse GLB bytes and validate UVs selected by every texture slot."""
from pathlib import Path
import struct, json, hashlib, math
OUT=Path(__file__).resolve().parent
data=(OUT/'frost-optimized.glb').read_bytes()
json_size=struct.unpack_from('<I',data,12)[0]
gltf=json.loads(data[20:20+json_size])
binary_start=20+json_size+8
binary=data[binary_start:]
sizes={5126:4,5125:4,5123:2,5121:1}
codes={5126:'f',5125:'I',5123:'H',5121:'B'}
def accessor(index):
    ac=gltf['accessors'][index];view=gltf['bufferViews'][ac['bufferView']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[ac['type']]
    stride=view.get('byteStride',width*sizes[ac['componentType']])
    offset=view.get('byteOffset',0)+ac.get('byteOffset',0)
    fmt='<'+codes[ac['componentType']]*width
    return [struct.unpack_from(fmt,binary,offset+i*stride) for i in range(ac['count'])]
records=[]
for mi,mesh in enumerate(gltf['meshes']):
    for pi,primitive in enumerate(mesh['primitives']):
        mat=gltf['materials'][primitive['material']]
        slots={}
        for key,value in mat.items():
            if key.endswith('Texture') and isinstance(value,dict):slots[key]=value
        for key,value in mat.get('pbrMetallicRoughness',{}).items():
            if key.endswith('Texture') and isinstance(value,dict):slots['pbr.'+key]=value
        for slot,tex in slots.items():
            uv_index=tex.get('extensions',{}).get('KHR_texture_transform',{}).get('texCoord',tex.get('texCoord',0))
            attribute='TEXCOORD_'+str(uv_index)
            values=accessor(primitive['attributes'][attribute])
            unique=len(set(values))
            bounds=[[min(v[i] for v in values),max(v[i] for v in values)] for i in (0,1)]
            finite=all(math.isfinite(c) for v in values for c in v)
            passed=finite and unique>1 and any(b[1]-b[0]>1e-6 for b in bounds)
            records.append({'mesh':mi,'primitive':pi,'material':mat['name'],'texture_slot':slot,'selected_uv':attribute,'vertex_count':len(values),'unique_uvs':unique,'uv_bounds':bounds,'pass':passed})
report={'sha256':hashlib.sha256(data).hexdigest(),'textured_slot_checks':len(records),'pass':bool(records) and all(r['pass'] for r in records),'checks':records}
(OUT/'glb_uv_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='checks'}))
assert report['pass'],report
