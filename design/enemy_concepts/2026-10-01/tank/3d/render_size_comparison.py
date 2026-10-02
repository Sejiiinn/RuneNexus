"""Render native normal beside tank with exactly the same orthographic camera.
Run after build_tank in Blender or open tank-wide-chest.blend in background.
Both soles are at Z=0; no display multiplier is baked into either model.
"""
import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
source=bpy.data.scenes['Tank_WideChest_Concept']
scene=bpy.data.scenes.get('Tank_Normal_Size_Comparison')
if scene:
    for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
else:scene=bpy.data.scenes.new('Tank_Normal_Size_Comparison')
bpy.context.window.scene=scene
with bpy.data.libraries.load(str(OUT.parents[2]/'2026-09-26/medium-guardian-3d/medium-guardian.blend'),link=False) as (a,b):b.collections=['Medium_Guardian_MODEL']
normal=b.collections[0];scene.collection.children.link(normal);bpy.context.view_layer.update()
size=json.loads((OUT/'size-comparison.json').read_text())
for col,offset in [(normal,Vector((-3.4,0,-size['normal_bounds']['min'][2]))),(bpy.data.collections['Tank_WideChest_MODEL'],Vector((2.8,0,0)))]:
    for o in col.objects:
        if o.type!='MESH':continue
        cp=o.copy();cp.data=o.data;cp.name='Comparison_'+o.name;cp.parent=None;cp.matrix_world=o.matrix_world.copy();cp.location+=offset;scene.collection.objects.link(cp)
scene.collection.children.unlink(normal)
for o in source.objects:
    if o.type=='LIGHT' or 'studio floor' in o.name:
        cp=o.copy();cp.data=o.data;scene.collection.objects.link(cp)
scene.world=source.world
cd=bpy.data.cameras.new('Size comparison orthographic camera');cam=bpy.data.objects.new('Size comparison orthographic camera',cd);scene.collection.objects.link(cam)
h=size['tank_height'];cam.location=(0,-20,h*.5);cam.rotation_euler=(Vector((0,0,h*.5))-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=13.4;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform=source.view_settings.view_transform;scene.view_settings.look=source.view_settings.look
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'preview-normal-tank-125.png')
bpy.data.libraries.write(str(OUT/'tank-normal-size-comparison.blend'),{scene},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
conditions_path=OUT/'render-conditions.json'
conditions=json.loads(conditions_path.read_text()) if conditions_path.exists() else {}
conditions['normal_tank_comparison']={'camera_location':list(cam.location),'target':[0,0,h*.5],'orthographic_scale':cd.ortho_scale,'resolution':[scene.render.resolution_x,scene.render.resolution_y],'cycles_samples':scene.cycles.samples,'normal_x_offset':-3.4,'tank_x_offset':2.8,'height_ratio':size['height_ratio'],'both_soles_z':0}
conditions_path.write_text(json.dumps(conditions,indent=2))
bpy.context.window.scene=source
(OUT/'render-progress.log').write_text('COMPLETE size-comparison\n')
print('SIZE_COMPARISON_READY')
