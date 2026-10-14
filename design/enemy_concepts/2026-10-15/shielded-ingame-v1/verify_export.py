"""Verify actual GLB binary corner attributes and final baked idle trajectory in Blender."""
import bpy,math,json,struct,hashlib
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
R=Path('/Users/sejin/Documents/Codex/RuneNexus');D=R/'design/enemy_concepts/2026-10-15/shielded-ingame-v1';A=Path('/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/shielded-01-20261014');O=A/'previews/sv-ingame-v1';meta=json.loads((D/'asset-contract.json').read_text());native=Path(meta['native']['path']);GLB=Path(meta['glb']['path']);bpy.ops.wm.open_mainfile(filepath=str(native));s=bpy.context.scene;parts=[o for o in s.objects if o.type=='MESH'];s.frame_set(1)
raw=GLB.read_bytes();ln,tp=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+ln]);bo=20+ln;bl,bt=struct.unpack_from('<II',raw,bo);buf=raw[bo+8:bo+8+bl]
def acc(i):
 a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dt={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',np.dtype(dt).itemsize*n)
 return np.ndarray((a['count'],n),dtype=dt,buffer=buf,offset=offset,strides=(stride,np.dtype(dt).itemsize)).copy()
maxp=maxuv=maxn=0.;triangles=0
for node in g['nodes']:
 if 'mesh' not in node:continue
 ob=bpy.data.objects[node['name']];me=ob.data;primitive=g['meshes'][node['mesh']]['primitives'][0];at=primitive['attributes'];p=acc(at['POSITION']);uv=acc(at['TEXCOORD_0']);uv[:,1]=1-uv[:,1];n=acc(at['NORMAL']);idx=acc(primitive['indices']).ravel().reshape(-1,3);triangles+=len(idx)
 assert len(idx)==len(me.polygons)
 for ids,poly in zip(idx,me.polygons):
  # Exporter keeps face order; all corner data must match in that oriented order.
  sp=np.array([tuple(me.vertices[me.loops[li].vertex_index].co) for li in poly.loop_indices]);su=np.array([tuple(me.uv_layers.active.data[li].uv) for li in poly.loop_indices]);sn=np.array([tuple(me.corner_normals[li].vector) for li in poly.loop_indices])
  errors=[np.max(np.abs(p[np.roll(ids,k)]-sp)) for k in range(3)];k=int(np.argmin(errors));ii=np.roll(ids,k);maxp=max(maxp,float(errors[k]));maxuv=max(maxuv,float(np.max(np.abs(uv[ii]-su))));maxn=max(maxn,float(np.max(np.abs(n[ii]-sn))))
assert triangles==9757 and maxp<1e-7 and maxuv<1.2e-7 and maxn<1e-4,(triangles,maxp,maxuv,maxn)
# Embedded original PNG bytes must match the adopted source PNG bytes exactly.
ad=json.loads((A/'manifests/single-view-textured-adopted-v1.json').read_text());pngsha={}
for im in g['images']:
 v=g['bufferViews'][im['bufferView']];chunk=buf[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']];pngsha[im['name']]=hashlib.sha256(chunk).hexdigest()
assert ad['albedo']['sha256'] in pngsha.values() and ad['normal']['sha256'] in pngsha.values(),pngsha
assert 'KHR_lights_punctual' not in g.get('extensions',{}) and not g.get('cameras')
an=g['animations'][0];assert an['name']=='Idle';time_ranges=[(float(acc(x['input']).min()),float(acc(x['input']).max())) for x in an['samplers']];assert all(lo==0 and hi==24 for lo,hi in time_ranges),time_ranges;dur=24.0
# Verify source-native no geometry changes plus actual final trajectory for all 577 frames.
collisions={};rest={o.name:np.array(o.matrix_world) for o in parts}
for f in range(1,578):
 s.frame_set(f);trees={o.name:BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],all_triangles=True) for o in parts}
 for i,o in enumerate(parts):
  for p in parts[i+1:]:
   pairs=trees[o.name].overlap(trees[p.name])
   if pairs:collisions.setdefault(o.name+'/'+p.name,[]).append({'frame':f,'pairs':len(pairs)})
end={o.name:np.array(o.matrix_world) for o in parts};loop=max(float(np.max(np.abs(rest[k]-end[k]))) for k in rest)
# Save compact validation only; raw trajectories stay local and are not needed.
report={'actual_glb_sha256':hashlib.sha256(raw).hexdigest(),'triangles':triangles,'meshes':len(parts),'oriented_corner_position_max_error':maxp,'UV_max_error':maxuv,'corner_normal_max_error':maxn,'original_png_bytes_exact':True,'embedded_image_sha256':pngsha,'animation_seconds':dur,'full_trajectory_frames_checked':577,'intersections':collisions,'loop_world_matrix_max_error':loop,'camera_light_exports':False,'validation':'PASS' if not collisions and loop<1e-5 else 'FAIL'}
(O/'export-validation.json').write_text(json.dumps(report,indent=2));s.frame_set(1);print(json.dumps(report))
