"""Reusable GLB access, meshoptimizer options0 and topology helpers."""
import ctypes as c
import hashlib
import json
import struct
import os
from collections import Counter
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parents[1]
ROOT = OUT.parents[3]
LIB = Path(os.environ.get('MESHOPTIMIZER_LIBRARY','/Volumes/KIOXIA_MAC/AI-3D/apps/Blender.app/Contents/Resources/lib/libmeshoptimizer.dylib'))
DTYPES = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5122: '<i2', 5121: 'u1', 5120: 'i1'}
NORMAL_WEIGHT = .03
UV_WEIGHT = 1.
WIDTH = {'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'SCALAR': 1}

def read_glb(path):
    data = path.read_bytes()
    assert struct.unpack_from('<III', data) == (0x46546c67, 2, len(data))
    size, tag = struct.unpack_from('<II', data, 12)
    assert tag == 0x4e4f534a
    doc = json.loads(data[20:20+size])
    start = 20+size
    length, tag = struct.unpack_from('<II', data, start)
    assert tag == 0x004e4942
    return doc, data[start+8:start+8+length]

def accessor(doc, blob, i):
    ac = doc['accessors'][i]
    view = doc['bufferViews'][ac['bufferView']]
    assert 'byteStride' not in view and 'sparse' not in ac
    return np.frombuffer(blob, DTYPES[ac['componentType']], count=ac['count']*WIDTH[ac['type']], offset=view.get('byteOffset',0)+ac.get('byteOffset',0)).reshape(ac['count'], WIDTH[ac['type']]).copy()

def geometry_contract(doc,blob):
    records=[]
    for mesh in doc['meshes']:
        surfaces=[]
        for prim in mesh['primitives']:
            h=hashlib.sha256()
            for name,i in sorted({**prim['attributes'],'INDICES':prim['indices']}.items()):
                ac=doc['accessors'][i]
                h.update(json.dumps([name,ac['componentType'],ac['type'],ac.get('normalized',False)],separators=(',',':')).encode())
                h.update(accessor(doc,blob,i).tobytes())
            surfaces.append(h.hexdigest())
        records.append(surfaces)
    return records

def runtime_contract(doc,blob):
    fields=('nodes','scenes','scene','materials','textures','samplers')
    structure={k:doc.get(k) for k in fields};images=[]
    for image in doc['images']:
        v=doc['bufferViews'][image['bufferView']];a=v.get('byteOffset',0)
        images.append(dict(name=image.get('name'),mimeType=image.get('mimeType'),sha256=hashlib.sha256(blob[a:a+v['byteLength']]).hexdigest()))
    structure['images']=images
    return hashlib.sha256(json.dumps(structure,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def init():
    pi, pf, pb = c.POINTER(c.c_uint), c.POINTER(c.c_float), c.POINTER(c.c_ubyte)
    fn = c.CDLL(str(LIB)).meshopt_simplifyWithAttributes
    fn.argtypes=[pi,pi,c.c_size_t,pf,c.c_size_t,c.c_size_t,pf,c.c_size_t,pf,c.c_size_t,pb,c.c_size_t,c.c_float,c.c_uint,pf]
    fn.restype=c.c_size_t
    return fn, pi, pf, pb

def simplify(fn, arrays, indices, error, target_ratio=.1, locks=None):
    _, pi, pf, pb = init()
    positions = np.ascontiguousarray(arrays['POSITION'], np.float32)
    faces = np.ascontiguousarray(indices, np.uint32).reshape(-1,3)
    attrs = np.ascontiguousarray(np.column_stack((arrays['NORMAL'], arrays['TEXCOORD_0'])),np.float32)
    weights = np.array([NORMAL_WEIGHT]*3+[UV_WEIGHT]*2,np.float32)
    if locks is None:locks = np.zeros(len(positions),np.uint8)
    result = np.empty(faces.size,np.uint32)
    actual = c.c_float()
    count = fn(result.ctypes.data_as(pi),faces.ctypes.data_as(pi),faces.size,positions.ctypes.data_as(pf),len(positions),12,attrs.ctypes.data_as(pf),attrs.shape[1]*4,weights.ctypes.data_as(pf),len(weights),locks.ctypes.data_as(pb),int(len(faces)*target_ratio)*3,error,0,c.byref(actual))
    return result[:count].reshape(-1,3), actual.value

def write_glb(doc, blob, replacements, path):
    chunks=[];cursor=0
    for i,view in enumerate(doc['bufferViews']):
        content=replacements.get(i,blob[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
        pad=(-cursor)%4
        chunks.append(b'\0'*pad);cursor+=pad
        view['byteOffset']=cursor;view['byteLength']=len(content)
        chunks.append(content);cursor+=len(content)
    binary=b''.join(chunks);doc['buffers'][0]['byteLength']=len(binary)
    binary+=b'\0'*((-len(binary))%4)
    encoded=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode()
    encoded+=b' '*((-len(encoded))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)

def geometry_topology(positions, faces):
    _,inv=np.unique(positions,axis=0,return_inverse=True)
    ff=inv[faces]
    edges=Counter(tuple(sorted((int(t[i]),int(t[(i+1)%3])))) for t in ff for i in range(3))
    parent={int(i):int(i) for i in np.unique(ff)}
    def root(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for a,b in edges:
        ra,rb=root(a),root(b)
        if ra!=rb:parent[ra]=rb
    q=positions[faces];zero=np.linalg.norm(np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]),axis=1)<1e-18
    return {'geometric_vertices':len(np.unique(ff)), 'edges':len(edges),'faces':len(faces),'euler':len(np.unique(ff))-len(edges)+len(faces),'boundary_edges':sum(v==1 for v in edges.values()),'nonmanifold_edges':sum(v>2 for v in edges.values()),'components':len({root(i) for i in parent}),'zero_area_faces':int(zero.sum())}
