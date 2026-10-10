"""Preserve every original component and fin thickness; meshoptimizer only.

Output is geometry plus original face/material ownership inputs for rebaking.
No source mutation. Blender source recreation uses exact original positions.
"""
import numpy as np,json,hashlib
from pathlib import Path
import meshopt_common as o
OUT=Path(__file__).resolve().parents[1];ROOT=OUT.parents[3]
(OUT/'checks').mkdir(exist_ok=True)
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from source_input import materialize_original
source=materialize_original()
assert hashlib.sha256(source.read_bytes()).hexdigest()=='7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39'
doc,blob=o.read_glb(source);fn,*_=o.init();o.NORMAL_WEIGHT=.025;o.UV_WEIGHT=0.;records=[]
for mi,mesh in enumerate(doc['meshes']):
    arrays={k:[] for k in ('POSITION','NORMAL','TEXCOORD_0')};ff=[];mats=[];offset=0
    for prim in mesh['primitives']:
        pp={k:o.accessor(doc,blob,i) for k,i in prim['attributes'].items()}
        faces=o.accessor(doc,blob,prim['indices']).reshape(-1,3)
        for k in arrays:arrays[k].append(pp[k])
        ff.append(faces+offset);mats.extend([prim['material']]*len(faces));offset+=len(pp['POSITION'])
    arrays={k:np.concatenate(v) for k,v in arrays.items()};hf=np.concatenate(ff);hm=np.array(mats,np.int32)
    pos,first,inv=np.unique(arrays['POSITION'],axis=0,return_index=True,return_inverse=True);gf=inv[hf]
    aa={k:v[first] for k,v in arrays.items()};norm=np.zeros_like(pos);np.add.at(norm,inv,arrays['NORMAL']);norm/=np.maximum(np.linalg.norm(norm,axis=1)[:,None],1e-20);aa['NORMAL']=norm
    parent=np.arange(len(pos))
    def find(x):
        while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
        return x
    for t in gf:
        for a,b in ((t[0],t[1]),(t[0],t[2])):
            a,b=find(int(a)),find(int(b))
            if a!=b:parent[a]=b
    groups={}
    for ti,t in enumerate(gf):groups.setdefault(find(int(t[0])),[]).append(ti)
    output=[];lowgroups=[];highgroups=np.empty(len(hf),np.int32);grecord=[]
    for ci,tids in enumerate(groups.values()):
        highgroups[tids]=ci;comp=gf[tids];used,local=np.unique(comp,return_inverse=True);local=local.reshape(-1,3);a={k:v[used] for k,v in aa.items()};v=a['POSITION'];materialset=set(map(int,hm[tids]));fin=mi==0 and 2 in materialset
        locks=np.zeros(len(v),np.uint8)
        # Representative extrema per physical component retain fin thickness,
        # shutter thickness, feet and lens depth without locking entire planes.
        for axis in range(3):locks[np.argmin(v[:,axis])]=1;locks[np.argmax(v[:,axis])]=1
        if fin:
            # Four original cap points per side prevent top/bottom cap loss.
            for side in (v[:,1].min(),v[:,1].max()):
                ids=np.flatnonzero(v[:,1]==side)
                for axis in (0,2):locks[ids[np.argmin(v[ids,axis])]]=1;locks[ids[np.argmax(v[ids,axis])]]=1
        target=48 if fin else max(4,int(len(local)*.14))
        if materialset in ({9},{12}):target=192
        if mi==2 and materialset=={4,5} and len(local)==956:target=144
        if mi==2 and materialset=={1} and len(local)==476:target=72
        if mi==2 and len(local)<=12:target=len(local)
        if len(local)==384 and materialset=={3}:target=96
        error=.025 if fin else .03
        before=o.geometry_topology(v,local)
        for attempt in range(18):
            nf,actual=o.simplify(fn,a,local,error,target_ratio=target/len(local),locks=locks)
            after=o.geometry_topology(v,nf)
            enough=len(nf)>=(4 if before['boundary_edges']==0 and len(local)>=4 else 1)
            if enough and before['euler']==after['euler'] and before['components']==after['components'] and after['nonmanifold_edges']<=before['nonmanifold_edges'] and after['zero_area_faces']<=before['zero_area_faces']:break
            error*=.5
        else:nf=local;error=0.;actual=0.
        assert np.array_equal(v.min(0),v[nf].reshape(-1,3).min(0)) and np.array_equal(v.max(0),v[nf].reshape(-1,3).max(0))
        output.append(used[nf]);lowgroups.extend([ci]*len(nf));grecord.append({'component':ci,'materials':sorted(materialset),'fin':fin,'before':len(local),'target':target,'after':len(nf),'effective_error':error,'actual_error':actual,'bounds_exact':True})
    lf=np.concatenate(output).astype(np.int32);lg=np.array(lowgroups,np.int32)
    np.savez_compressed(OUT/'checks'/f'mesh{mi}-geometry.npz',positions=pos,low_faces=lf,low_groups=lg,high_positions=arrays['POSITION'],high_faces=hf,high_normals=arrays['NORMAL'],high_uv=arrays['TEXCOORD_0'],high_materials=hm,high_groups=highgroups)
    records.append({'mesh':mi,'before':len(hf),'after':len(lf),'components':len(groups),'fin_components':sum(x['fin'] for x in grecord),'parts':grecord})
report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'before_triangles':47912,'after_triangles':sum(x['after'] for x in records),'method':'meshopt_simplifyWithAttributes options0; no position movement; per-component representative extrema and fin cap anchors','library_sha256':hashlib.sha256(o.LIB.read_bytes()).hexdigest(),'records':records}
(OUT/'geometry-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='records'}),flush=True)
