"""Background-only: make isolated library directly open to the intended scene."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Relic_Marshal_Concept']
for w in bpy.context.window_manager.windows:w.scene=scene
for other in list(bpy.data.scenes):
    if other!=scene and not other.objects:bpy.data.scenes.remove(other)
bpy.ops.object.select_all(action='DESELECT');root=scene.objects['Relic_Marshal_ROOT'];root.select_set(True);bpy.context.view_layer.objects.active=root
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.region_3d.view_location=Vector((0,0,3.37));s.region_3d.view_distance=11;s.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion();s.clip_end=300;s.shading.type='MATERIAL'
# Remove unused Boolean-created empty material slots, with no visible face changes.
for o in bpy.data.collections['Relic_Marshal_MODEL'].objects:
    if o.type!='MESH':continue
    used={p.material_index for p in o.data.polygons}
    for i in reversed(range(len(o.data.materials))):
        if o.data.materials[i] is None:
            assert i not in used,(o.name,i)
            o.data.materials.pop(index=i)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'relic-marshal.blend'),compress=True)
print('FINAL_PROJECT',bpy.context.scene.name,len(scene.objects))

conditions_path=OUT/'render-conditions.json'
if conditions_path.exists():
    conditions=json.loads(conditions_path.read_text())
    conditions['lights']=[{'name':o.name,'type':o.data.type,'position':list(o.location),'energy_w':o.data.energy,'color':list(o.data.color),'size_m':o.data.size} for o in scene.objects if o.type=='LIGHT']
    conditions['build_source_sha256']=hashlib.sha256((OUT/'build_relic_marshal.py').read_bytes()).hexdigest()
    conditions['nonvisual_finalize']='Removed only unused empty material slots; no rendered face changed.'
    conditions['world_strength']=scene.world.node_tree.nodes.get('Background').inputs[1].default_value
    conditions['blend_sha256']=hashlib.sha256((OUT/'relic-marshal.blend').read_bytes()).hexdigest()
    conditions_path.write_text(json.dumps(conditions,indent=2))
