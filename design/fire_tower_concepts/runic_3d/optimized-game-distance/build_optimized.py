"""Optimize the finished approved body, verifying its 90% form against native source.
No original build rerun, no decimation, no game/VFX output writes.
"""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils.kdtree import KDTree
OUT=Path(__file__).resolve().parent
BASE=OUT.parent
NATIVE=BASE/'scale-90/runic-native-90.blend'
EDITABLE=BASE/'runic-flame-turret.blend'
GAME=BASE.parents[2]/'assets/images/stage1_3d/turrets/magic.glb'
CONTROLS=['turret_root','turret_head','turret_barrel','muzzle','upper_flame_port']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def control_state():
    return {n:{'world_matrix':[list(row) for row in bpy.data.objects[n].matrix_world],'local_location':list(bpy.data.objects[n].location),'scale':list(bpy.data.objects[n].scale),'parent':bpy.data.objects[n].parent.name if bpy.data.objects[n].parent else None} for n in CONTROLS}
def points(objects):
    bpy.context.view_layer.update();d=bpy.context.evaluated_depsgraph_get()
    return [o.matrix_world@v.co for o in objects if o.type=='MESH' for v in o.evaluated_get(d).data.vertices]
def deviation(a,b):
    t=KDTree(len(b))
    for i,p in enumerate(b):t.insert(p,i)
    t.balance();return max(t.find(p)[2] for p in a)
def tri(o):
    d=bpy.context.evaluated_depsgraph_get();e=o.evaluated_get(d);m=e.to_mesh();m.calc_loop_triangles();n=len(m.loop_triangles);e.to_mesh_clear();return n
bpy.ops.wm.open_mainfile(filepath=str(NATIVE))
bpy.context.view_layer.update();native_controls=control_state();native_points=points(bpy.context.scene.objects)
native_tris=sum(tri(o) for o in bpy.context.scene.objects if o.type=='MESH')
bpy.ops.wm.open_mainfile(filepath=str(EDITABLE))
s=bpy.context.scene
bpy.data.objects['turret_root'].scale=(.9,.9,.9)
objects=[o for c in s.collection.children if c.name.startswith(('01 ','02 ','03 ')) for o in c.objects]
original_points=points(objects);source_error=max(deviation(original_points,native_points),deviation(native_points,original_points))
assert source_error<1e-6,source_error
before={o.name:tri(o) for o in objects if o.type=='MESH'}
assert sum(before.values())==native_tris==46795
def replace(o,vs,fs,smooth=False):
    old=o.data;n=bpy.data.meshes.new(old.name+' reduced');n.from_pydata(vs,[],fs);n.update()
    for m in old.materials:n.materials.append(m)
    for p in n.polygons:p.use_smooth=smooth and len(p.vertices)==4
    o.data=n
rings={'Turntable bronze seam':32,'Pedestal lower collar':32,'Pedestal upper bronze inlay':32,'Spindle warm metal collar':16,'Muzzle inner black sleeve':16,'Muzzle ignition ring':16}
cylinders={'Foundation lower armor':32,'Foundation rim':32,'Sloped turntable':32,'Rotating pedestal':24,'Head spindle':16,'Muzzle dark throat':16,'Foot bolt recessed dark socket':16,'Single bronze foot fastener':16,'Trunnion finished iron ring':16,'Trunnion bronze centre':16,'Axle recessed socket':12,'Pedestal rivet':12}
changes=[]
for o in objects:
    if o.type!='MESH':continue
    for m in list(o.modifiers):
        if m.type=='BEVEL':
            old=m.segments;m.segments=1;changes.append([o.name,'bevel_segments',old,1])
    n=next((n for key,n in rings.items() if o.name.startswith(key)),None)
    if n:
        oldn=len(o.data.vertices)//4;stride=oldn//n
        vs=[tuple(o.data.vertices[g*oldn+i*stride].co) for g in range(4) for i in range(n)];fs=[]
        for i in range(n):
            j=(i+1)%n;fs.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(n+i,n+j,3*n+j,3*n+i),(j,i,2*n+i,2*n+j)])
        replace(o,vs,fs);changes.append([o.name,'circumference',oldn,n])
    else:
        n=next((n for key,n in cylinders.items() if o.name.startswith(key)),None)
        if not n:continue
        oldvs=[v.co.copy() for v in o.data.vertices];oldn=len(oldvs)//2
        levels=sorted(set(round(v.z,7) for v in oldvs));assert len(levels)==2,(o.name,levels)
        vs=[]
        for z in levels:
            rr=sorted([v for v in oldvs if abs(v.z-z)<1e-6],key=lambda v:math.atan2(v.y,v.x))
            vs.extend(tuple(rr[i*(oldn//n)]) for i in range(n))
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        replace(o,vs,fs,True);changes.append([o.name,'circumference',oldn,n])
# Static body comparison only: keep the existing VFX collection untouched but hidden.
for c in s.collection.children:
    if c.name.startswith('04 '):c.hide_render=True;c.hide_viewport=True
bpy.context.view_layer.update();after={o.name:tri(o) for o in objects if o.type=='MESH'};newpoints=points(objects)
controls=control_state();control_error=max(abs(native_controls[n]['world_matrix'][i][j]-controls[n]['world_matrix'][i][j]) for n in CONTROLS for i in range(4) for j in range(4))
assert control_error<1e-6
# Match native rune export factor; original procedural metals remain intact for baking.
for m in {m for o in objects if o.type=='MESH' for m in o.data.materials}:
    if m.name.startswith('Runes'):
        next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Emission Strength'].default_value=.8
def bounds(pp):return [[min(p[i] for p in pp) for i in range(3)],[max(p[i] for p in pp) for i in range(3)]]
manifest={'baseline_game_asset':str(GAME),'baseline_game_sha256':sha(GAME),'baseline_native_source':str(NATIVE),'baseline_native_sha256':sha(NATIVE),'editable_finished_source':str(EDITABLE),'editable_finished_sha256':sha(EDITABLE),'baseline_triangles':native_tris,'finished_source_scaled_09_to_native_max_error':source_error,'optimized_triangles':sum(after.values()),'parts_before':before,'parts_after':after,'changes':changes,'linear_root_scale':list(bpy.data.objects['turret_root'].scale),'controls':controls,'native_controls':native_controls,'max_control_matrix_error':control_error,'bounds_before':bounds(native_points),'bounds_after':bounds(newpoints),'decimate_used':False,'source_regenerated':False,'vfx_changed':False,'game_files_changed':False,'material_policy':'Finished original procedural materials retained; native exporter rune strength .8. Reuse native atlas bake workflow.'}
(OUT/'optimization-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'runic-fire-optimized.blend'))
print('FIRE_OPTIMIZED',native_tris,sum(after.values()),'SOURCE_EQUIVALENCE',source_error)
