"""Render actual saved geometry; VIEWS environment or --views=a,b selects subset."""
import bpy,math,json,hashlib,sys,os
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Relic_Marshal_Concept']
for w in bpy.context.window_manager.windows:w.scene=scene
camera=scene.camera;h=scene.objects['Relic_Marshal_ROOT']['height_m'];target=Vector((0,0,h*.50))
views={'three-quarter':((h*2.9*math.sin(math.radians(24)),-h*2.9*math.cos(math.radians(24)),h*.5+h*2.9*math.tan(math.radians(14))),8.1),'front':((0,-22,h*.5),8.1),'side':((22,0,h*.5),8.1),'back':((0,22,h*.5),8.1),'top':((0,0,25),8.1)}
selected=next((a.split('=',1)[1].split(',') for a in sys.argv if a.startswith('--views=')),list(views))
scene.cycles.samples=64
conditions_path=OUT/'render-conditions.json';conditions=json.loads(conditions_path.read_text()) if conditions_path.exists() else {};vd=conditions.get('views',{})
for name in selected:
    scene.cycles.samples=32
    scene.render.resolution_x=1100 if name=='three-quarter' else 1000;scene.render.resolution_y=scene.render.resolution_x
    scene.objects['Relic_Marshal_ground'].hide_render=name in ('front','side','back')
    loc,scale=views[name];camera.location=loc;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
    scene.render.filepath=str(OUT/('preview-'+name+'.png'));bpy.ops.render.render(write_still=True)
    vd[name]={'camera':list(camera.location),'target':list(target),'ortho_scale':scale,'resolution':[scene.render.resolution_x,scene.render.resolution_y],'samples':scene.cycles.samples,'ground_visible':not scene.objects['Relic_Marshal_ground'].hide_render}
    (OUT/'local'/'render-progress.log').write_text('RENDER_READY '+name+'\n');print('RENDER_READY',name,flush=True)
scene.objects['Relic_Marshal_ground'].hide_render=False
scene.cycles.samples=32;scene.render.resolution_x=1100;scene.render.resolution_y=1100
loc,scale=views['three-quarter'];camera.location=loc;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale;scene.render.filepath=str(OUT/'preview-three-quarter.png')
conditions={'blender':bpy.app.version_string,'engine':scene.render.engine,'view_transform':scene.view_settings.view_transform,'look':scene.view_settings.look,'exposure':scene.view_settings.exposure,'model_revision':scene.objects['Relic_Marshal_ROOT']['revision'],'build_source_sha256':hashlib.sha256((OUT/'build_relic_marshal.py').read_bytes()).hexdigest(),'reference_sha256':hashlib.sha256((OUT.parent/'16-relic-marshal-unarmed.png').read_bytes()).hexdigest(),'views':vd,'postprocessing':'none; actual Blender Cycles PNG'}
conditions_path.write_text(json.dumps(conditions,indent=2))
bpy.data.libraries.write(str(OUT/'relic-marshal.blend'),{scene},fake_user=True,compress=True)
print('RENDER_COMPLETE',','.join(selected),flush=True)
