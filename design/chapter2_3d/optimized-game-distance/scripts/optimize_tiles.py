"""Reduce approved chapter-two tile GLBs by index selection only.

Run with Blender bundled Python (numpy). prepare_baseline.py exports tracked
native sources into checks after a fresh checkout. --asset selects the original
geometry contract and rejects altered or already reduced input. No baking, UV
changes, source overwrite, or vertex motion.
"""
import ctypes as c
import hashlib
import json
import struct
import argparse
import os
from collections import Counter
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parents[1]
ROOT = OUT.parents[2]
BASE = OUT / 'checks/chapter2_tiles-before.glb'
LIB = Path(os.environ.get('MESHOPTIMIZER_LIBRARY','/Volumes/KIOXIA_MAC/AI-3D/apps/Blender.app/Contents/Resources/lib/libmeshoptimizer.dylib'))
DTYPES = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5122: '<i2', 5121: 'u1', 5120: 'i1'}
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
    weights = np.array([.03,.03,.03, 1.,1.],np.float32)
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

def main():
    global LIB
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--asset',choices=list(json.loads((OUT/'baseline-contract.json').read_text())),required=True)
    parser.add_argument('--library',type=Path,default=LIB)
    parser.add_argument('--error',type=float,default=.0015)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();LIB=args.library.resolve()
    contract=json.loads((OUT/'baseline-contract.json').read_text())[args.asset]
    doc,blob=read_glb(args.source)
    budgets=[[len(accessor(doc,blob,p['indices']))//3 for p in m['primitives']] for m in doc['meshes']]
    assert budgets==contract['primitive_triangles'],'Input is not original full geometry; do not simplify reduced output'
    assert geometry_contract(doc,blob)==contract['primitive_geometry_sha256'],'Changed source geometry or attributes'
    assert runtime_contract(doc,blob)==contract['runtime_contract_sha256'],'Changed roots, materials or texture payloads'
    assert not doc['asset'].get('extras',{}).get('runeNexusGeometryReduced'),'Input already reduced'
    before_doc=json.loads(json.dumps(doc));fn,*_=init();replacements={};records=[]
    doc['accessors']=[];doc['bufferViews']=[]
    def emit(content,target=None):
        i=len(doc['bufferViews']);v={'buffer':0,'byteLength':len(content)}
        if target is not None:v['target']=target
        doc['bufferViews'].append(v);replacements[i]=content;return i
    for image in doc['images']:
        view=before_doc['bufferViews'][image['bufferView']];offset=view.get('byteOffset',0)
        image['bufferView']=emit(blob[offset:offset+view['byteLength']])
    mesh_nodes={n['mesh']:n.get('name') for n in doc['nodes'] if 'mesh' in n}
    for mi,mesh in enumerate(doc['meshes']):
      for si,prim in enumerate(mesh['primitives']):
        sourceprim=before_doc['meshes'][mi]['primitives'][si]
        arrays={name:accessor(before_doc,blob,i) for name,i in sourceprim['attributes'].items()}
        indices=accessor(before_doc,blob,sourceprim['indices']).reshape(-1,3);pos=arrays['POSITION']
        # Material surfaces are processed independently. Boundary locks preserve
        # every material join, retained exposed side, removed-face cut, and
        # geometric component; extrema preserve tile dimensions exactly.
        key=np.column_stack((pos,arrays['TEXCOORD_0']))
        _,first,inv=np.unique(key,axis=0,return_index=True,return_inverse=True)
        aa={k:v[first] for k,v in arrays.items()}
        normals=np.zeros((len(first),3),np.float32);np.add.at(normals,inv,arrays['NORMAL']);normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-20);aa['NORMAL']=normals
        _,geo=np.unique(pos,axis=0,return_inverse=True)
        sourcefaces=geo[indices];counts=Counter(tuple(sorted((int(t[i]),int(t[(i+1)%3])))) for t in sourcefaces for i in range(3))
        protected={v for edge,count in counts.items() if count!=2 for v in edge}
        locks=np.zeros(len(first),np.uint8);locks[np.isin(geo[first],list(protected))]=1
        locks[np.any((aa['POSITION']==pos.min(0))|(aa['POSITION']==pos.max(0)),axis=1)]=1
        # Preserve additional attributes at seams: position/UV welding must not
        # bridge different colors, secondary UVs, skin data or custom tuples.
        extra=[k for k in arrays if k not in ('POSITION','NORMAL','TANGENT','TEXCOORD_0')]
        candidates=[[] for _ in first]
        for old,new in enumerate(inv):candidates[new].append(old)
        for vi,choices in enumerate(candidates):
            if any(len(np.unique(arrays[k][choices],axis=0))>1 for k in extra):locks[vi]=1
        faces,actual=simplify(fn,aa,inv[indices],args.error,locks=locks)
        q=aa['POSITION'][faces];geometric=np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]);geometric/=np.maximum(np.linalg.norm(geometric,axis=1)[:,None],1e-20)
        original=np.empty_like(faces)
        for ti,tri in enumerate(faces):
          for ci,vi in enumerate(tri):
            choices=candidates[vi];original[ti,ci]=choices[int(np.argmax(arrays['NORMAL'][choices]@geometric[ti]))]
        used,newindices=np.unique(original,return_inverse=True);newindices=np.ascontiguousarray(newindices.reshape(-1,1),np.uint32)
        prim['attributes']={}
        for name,aci in sourceprim['attributes'].items():
            ac=json.loads(json.dumps(before_doc['accessors'][aci]));assert ac.get('byteOffset',0)==0
            arr=np.ascontiguousarray(arrays[name][used]);ac['bufferView']=emit(arr.tobytes(),34962);ac['count']=len(arr)
            if 'min' in ac:ac['min']=arr.min(0).tolist()
            if 'max' in ac:ac['max']=arr.max(0).tolist()
            prim['attributes'][name]=len(doc['accessors']);doc['accessors'].append(ac)
        # Keep 16-bit indices where possible; reduction is a geometry operation,
        # not an unrequested index-buffer enlargement.
        ac=json.loads(json.dumps(before_doc['accessors'][sourceprim['indices']]));assert ac.get('byteOffset',0)==0
        dtype=np.uint16 if len(used)<=65535 else np.uint32
        newindices=newindices.astype(dtype);ac['bufferView']=emit(newindices.tobytes(),34963);ac['count']=len(newindices);ac['componentType']=5123 if dtype==np.uint16 else 5125
        ac.pop('min',None);ac.pop('max',None);prim['indices']=len(doc['accessors']);doc['accessors'].append(ac)
        before=geometry_topology(pos,indices);after=geometry_topology(pos,original)
        assert before['boundary_edges']==after['boundary_edges'] and before['components']==after['components'] and after['nonmanifold_edges']<=before['nonmanifold_edges'],(mi,si,before,after)
        afterfaces=geo[original];aftercounts=Counter(tuple(sorted((int(t[i]),int(t[(i+1)%3])))) for t in afterfaces for i in range(3))
        assert {e for e,cnt in counts.items() if cnt==1}=={e for e,cnt in aftercounts.items() if cnt==1},'Changed geometric boundary'
        assert np.array_equal(pos.min(0),pos[used].min(0)) and np.array_equal(pos.max(0),pos[used].max(0))
        records.append(dict(node=mesh_nodes[mi],mesh=mi,surface=si,material=prim['material'],before_triangles=len(indices),after_triangles=len(faces),before_vertices=len(pos),after_vertices=len(used),temporary_position_uv_vertices=len(first),locked_vertices=int(locks.sum()),actual_error=actual,topology_before=before,topology_after=after,bounds_exact=True,export_attributes_source_tuple_subset=True))
    for field in ('nodes','scenes','scene','materials','textures','samplers'):
        assert doc.get(field)==before_doc.get(field),field
    doc['asset'].setdefault('extras',{})['runeNexusGeometryReduced']=True
    args.output.parent.mkdir(parents=True,exist_ok=True);write_glb(doc,blob,replacements,args.output)
    report=dict(asset=args.asset,baseline=str(args.source),baseline_sha256=hashlib.sha256(args.source.read_bytes()).hexdigest(),output_sha256=hashlib.sha256(args.output.read_bytes()).hexdigest(),before_bytes=args.source.stat().st_size,after_bytes=args.output.stat().st_size,before_triangles=sum(x['before_triangles'] for x in records),after_triangles=sum(x['after_triangles'] for x in records),method='meshopt_simplifyWithAttributes options0; exact position+UV temporary weld; source tuple subset; no positions/UV/pixels moved',relative_error_limit=args.error,normal_weights=[.03]*3,uv_weights=[1.]*2,library=str(LIB),library_sha256=hashlib.sha256(LIB.read_bytes()).hexdigest(),records=records,geometry_check_status='PASS',visual_status='PENDING')
    args.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='records'}),flush=True)
if __name__=='__main__':main()
