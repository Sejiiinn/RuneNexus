"""Read-only structural checks on the saved tank. No project writes.
Blender --background tank-wide-chest.blend --python check_tank.py
"""
import bpy,json,bmesh
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Tank_WideChest_Concept']
for w in bpy.context.window_manager.windows:w.scene=scene
bpy.context.view_layer.update()
root=scene.objects['Tank_WideChest_ROOT'];col=bpy.data.collections['Tank_WideChest_MODEL']
deps=bpy.context.evaluated_depsgraph_get();points=[];triangles=0;entries=[]
for o in col.objects:
    if o.type!='MESH':continue
    ev=o.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles();triangles+=len(me.loop_triangles)
    pts=[ev.matrix_world@v.co for v in me.vertices];points+=pts
    assert len(me.vertices)>3,o.name
    assert not o.hide_render,o.name
    bm=bmesh.new();bm.from_mesh(me);open_edges=sum(not e.is_manifold for e in bm.edges);bm.free()
    entries.append({'name':o.name,'vertices':len(me.vertices),'triangles':len(me.loop_triangles),'non_manifold_edges':open_edges})
    ev.to_mesh_clear()
mn=[min(p[i] for p in points) for i in range(3)];mx=[max(p[i] for p in points) for i in range(3)]
h=mx[2]-mn[2]
assert abs(h/root['normal_height']-1.25)<1e-5
assert 18000<=triangles<=22000,triangles
assert abs(mn[2])<1e-5
head=scene.objects['Tank_WideChest_large round chamfered monolithic head']
assert len(head.data.vertices)>2000
headpts=[head.matrix_world@v.co for v in head.data.vertices];headheight=max(p.z for p in headpts)-min(p.z for p in headpts)
assert .34<headheight/h<.44,headheight/h
assert sum('single broad unsegmented back' in o.name for o in col.objects)==1
assert sum('single pelvis keystone including rear' in o.name for o in col.objects)==1
assert sum('broad chest slab' in o.name for o in col.objects)==2
assert sum('single spherical amber front core' in o.name for o in col.objects)==1
assert sum('turquoise spherical eye' in o.name for o in col.objects)==2
assert sum('continuous physically recessed turquoise spiral' in o.name for o in col.objects)==1
assert not any(o.type=='ARMATURE' for o in scene.objects)
assert sum(e['non_manifold_edges'] for e in entries)==0,'Non-manifold model geometry'
result={'result':'PASS structural only; visual acceptance separately','blender':bpy.app.version_string,'scene':scene.name,'model_mesh_objects':len(entries),'bounds':{'min':mn,'max':mx},'tank_height':h,'normal_height':root['normal_height'],'height_ratio':h/root['normal_height'],'head_height_fraction':headheight/h,'triangles':triangles,'non_manifold_edges':sum(e['non_manifold_edges'] for e in entries),'details':entries}
print('TANK_STRUCTURAL_CHECK',json.dumps(result,ensure_ascii=False))
