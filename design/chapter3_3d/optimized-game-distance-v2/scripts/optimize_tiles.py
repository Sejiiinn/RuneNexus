"""Produce a new reduced GLB by index selection, never moving source attributes.

Run with Blender's bundled Python (numpy). The default baseline lives in
../checks/chapter3_tiles-before.glb; prepare_baseline.py recreates it from the
tracked native source. --source accepts another original full geometry GLB.
No baking or source overwrite.
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
BASE = OUT / 'checks/chapter3_tiles-before.glb'
LIB = Path(os.environ.get('MESHOPTIMIZER_LIBRARY','/Volumes/KIOXIA_MAC/AI-3D/apps/Blender.app/Contents/Resources/lib/libmeshoptimizer.dylib'))
DTYPES = {5126: '<f4', 5125: '<u4', 5123: '<u2'}
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
    global BASE,LIB
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,default=BASE,help='Original full geometry GLB; use prepare_baseline.py if absent')
    parser.add_argument('--library',type=Path,default=LIB,help='Library exporting meshopt_simplifyWithAttributes')
    parser.add_argument('--error',type=float,default=.002)
    parser.add_argument('--root-errors',type=str,default='{}',help='JSON root-name to relative error override; unspecified roots use --error')
    parser.add_argument('--protect',type=Path,help='JSON root to spheres [{center:[x,y,z],radius:...}] whose original vertices remain locked')
    parser.add_argument('--output',type=Path,default=OUT/'checks/chapter3_tiles-candidate.glb')
    args=parser.parse_args()
    BASE=args.source.resolve();LIB=args.library.resolve()
    assert BASE!=args.output.resolve(),'Output must not overwrite the full input source'
    root_errors=json.loads(args.root_errors)
    protection=json.loads(args.protect.read_text()) if args.protect else {}
    assert all(n in ('path_tile','grate_tile','build_tile','plain_build_tile','panel_solid','panel_vent') and isinstance(e,(int,float)) and 0<e<1 for n,e in root_errors.items())
    if not BASE.exists():
        parser.error('Original GLB missing. Run background Blender --python scripts/prepare_baseline.py to export the tracked native source without rebaking.')
    doc, blob = read_glb(BASE)
    fn,*_ = init()
    replacements={};records=[]
    expected={'path_tile':24416,'grate_tile':30320,'build_tile':24916,'plain_build_tile':16276,'panel_solid':2660,'panel_vent':4048}
    assert {n['name'] for n in doc['nodes']}==set(expected),'Unexpected root contract'
    for node in doc['nodes']:
        prim = doc['meshes'][node['mesh']]['primitives'][0]
        arrays = {name:accessor(doc,blob,i) for name,i in prim['attributes'].items()}
        indices = accessor(doc,blob,prim['indices'])
        assert len(indices)//3==expected[node['name']],'Input is not the original full geometry; do not reduce the reduced output again'
        pos=arrays['POSITION']
        # Only exact position+UV matches are temporarily connected. Actual UV
        # island seams remain split. Flat corner normals are a soft attribute,
        # not topological seams; the final GLB uses untouched source corners.
        key=np.column_stack((arrays['POSITION'],arrays['TEXCOORD_0']))
        _,first,inv=np.unique(key,axis=0,return_index=True,return_inverse=True)
        aa={k:v[first] for k,v in arrays.items()}
        normals=np.zeros((len(first),3),np.float32);np.add.at(normals,inv,arrays['NORMAL']);normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-20)
        aa['NORMAL']=normals
        ff=inv[indices]
        _,geo=np.unique(pos,axis=0,return_inverse=True)
        sourcefaces=geo[indices.reshape(-1,3)]
        counts=Counter(tuple(sorted((int(t[i]),int(t[(i+1)%3])))) for t in sourcefaces for i in range(3))
        protected={v for edge,count in counts.items() if count!=2 for v in edge}
        locks=np.zeros(len(first),np.uint8)
        locks[np.isin(geo[first],list(protected))]=1
        extrema=np.any((aa['POSITION']==pos.min(0))|(aa['POSITION']==pos.max(0)),axis=1)
        locks[extrema]=1
        additional=np.zeros(len(first),bool)
        for sphere in protection.get(node['name'],[]):
            additional |= np.linalg.norm(aa['POSITION']-np.array(sphere['center'],np.float32),axis=1)<=sphere['radius']
        locks[additional]=1
        root_error=root_errors.get(node['name'],args.error)
        faces,actual=simplify(fn,aa,ff,root_error,locks=locks)
        candidates=[[] for _ in first]
        for oldid,newid in enumerate(inv):candidates[newid].append(oldid)
        # Select the source split corner whose geometric normal best agrees
        # with the new face. Copy its entire original position/UV/normal/tangent
        # tuple; never average export normals or recalculate tangent vectors.
        q=aa['POSITION'][faces]
        geometric=np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0])
        geometric/=np.maximum(np.linalg.norm(geometric,axis=1)[:,None],1e-20)
        original=np.empty_like(faces)
        for ti,tri in enumerate(faces):
            for ci,vi in enumerate(tri):
                choices=candidates[vi]
                original[ti,ci]=choices[int(np.argmax(arrays['NORMAL'][choices]@geometric[ti]))]
        used,newindices=np.unique(original,return_inverse=True)
        newindices=np.ascontiguousarray(newindices.reshape(-1,1),np.uint32)
        for name,aci in prim['attributes'].items():
            ac=doc['accessors'][aci];arr=np.ascontiguousarray(arrays[name][used])
            replacements[ac['bufferView']]=arr.tobytes();ac['count']=len(arr)
            if 'min' in ac:ac['min']=arr.min(0).tolist()
            if 'max' in ac:ac['max']=arr.max(0).tolist()
        ac=doc['accessors'][prim['indices']]
        replacements[ac['bufferView']]=newindices.tobytes();ac['count']=len(newindices);ac['componentType']=5125
        before=geometry_topology(pos,indices.reshape(-1,3));after=geometry_topology(pos,original)
        assert before['boundary_edges']==after['boundary_edges'] and before['components']==after['components'] and after['nonmanifold_edges']<=before['nonmanifold_edges'],(node['name'],before,after)
        assert np.array_equal(pos.min(0),pos[used].min(0)) and np.array_equal(pos.max(0),pos[used].max(0)),node['name']
        record={'root':node['name'],'before_triangles':len(indices)//3,'after_triangles':len(faces),'before_vertices':len(pos),'after_vertices':len(used),'temporary_position_uv_vertices':len(first),'locked_nonmanifold_or_extrema_vertices':int(locks.sum()),'extra_locked_vertices':int(additional.sum()),'relative_error_limit':root_error,'actual_error':actual,'topology_before':before,'topology_after':after,'bounds_exact':True,'export_attributes_source_tuple_subset':True}
        records.append(record);print(json.dumps(record),flush=True)
    write_glb(doc,blob,replacements,args.output)
    def display_path(p):
        try:return str(p.relative_to(ROOT))
        except ValueError:return str(p)
    report={'baseline':display_path(BASE),'baseline_sha256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'output':display_path(args.output),'output_sha256':hashlib.sha256(args.output.read_bytes()).hexdigest(),'before_triangles':sum(r['before_triangles'] for r in records),'after_triangles':sum(r['after_triangles'] for r in records),'method':'meshopt_simplifyWithAttributes options0; exact position+UV temporary weld; original source corner attribute tuple export; no pixel changes','library':str(LIB),'library_sha256':hashlib.sha256(LIB.read_bytes()).hexdigest(),'protection':protection,'root_errors':root_errors,'normal_weights':[.03]*3,'uv_weights':[1.]*2,'records':records,'geometry_check_status':'PASS','visual_status':'PENDING'}
    args.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':
    main()
