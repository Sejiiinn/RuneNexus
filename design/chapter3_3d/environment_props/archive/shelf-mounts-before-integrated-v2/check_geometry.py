import bpy,bmesh,json
from pathlib import Path
from mathutils import Vector
H=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(H/'foundry-props.blend'))
report=json.loads((H/'geometry-check.json').read_text())
for rootname,entry in report['props'].items():
 r=bpy.data.objects[rootname];bad=[]
 for o in r.children:
  if o.type!='MESH':continue
  bm=bmesh.new();bm.from_mesh(o.data)
  n=sum(not e.is_manifold for e in bm.edges)
  if n:bad.append([o.name,n])
  bm.free()
 entry['non_manifold_source_meshes']=bad
 entry['identity_root']=all(abs(v)<1e-6 for v in r.location) and all(abs(v)<1e-6 for v in r.rotation_euler) and all(abs(v-1)<1e-6 for v in r.scale)
def ray(rootname,origin,direction):
 hits=[];origin=Vector(origin);direction=Vector(direction)
 for o in bpy.data.objects[rootname].children:
  if o.type!='MESH':continue
  inv=o.matrix_world.inverted();hit,loc,no,idx=o.ray_cast(inv@origin,(inv.to_3x3()@direction).normalized())
  if hit:hits.append(((o.matrix_world@loc-origin).length,o.name,list(o.matrix_world@loc)))
 return sorted(hits)[:1]
report['bore_ray_tests']={'conduit_axis_clear':ray('side_conduit',(-1,0,0),(1,0,0)),'exhaust_open_depth':ray('exhaust_vent',(0,0,.70),(0,0,-1)),'elbow_front_depth':ray('elbow_pipe',(0,-.6,.357),(0,1,0))}
assert not report['bore_ray_tests']['conduit_axis_clear']
assert report['bore_ray_tests']['exhaust_open_depth'][0][0]>.5
assert report['bore_ray_tests']['elbow_front_depth'][0][0]>.4
assert all(e['identity_root'] and not e['non_manifold_source_meshes'] for e in report['props'].values())
report['geometry_status']='PASS'
(H/'geometry-check.json').write_text(json.dumps(report,indent=2)+'\n')
print('GEOMETRY_PASS',flush=True)
