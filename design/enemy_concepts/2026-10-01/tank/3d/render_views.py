"""Render saved tank scene. Run in Blender; VIEWS optionally selects views.
Real orthographic front/side/back/top, plus representative three-quarter.
"""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Tank_WideChest_Concept']
bpy.context.window.scene=scene
camera=scene.camera
h=scene.objects['Tank_WideChest_ROOT']['tank_height'];target=Vector((0,0,h*.5))
views={'three-quarter':((h*2.3*math.sin(math.radians(25)),-h*2.3*math.cos(math.radians(25)),h*.5+h*2.3*math.tan(math.radians(22))),h*1.36),'front':((0,-18,h*.5),h*1.3),'side':((18,0,h*.5),h*1.3),'back':((0,18,h*.5),h*1.3),'top':((0,0,20),h*1.3),'high-angle':((7,-12,15),h*1.36)}
scene.cycles.samples=64
conditions_path=OUT/'render-conditions.json'
previous=json.loads(conditions_path.read_text()) if conditions_path.exists() else {}
view_data=previous.get('views',{}).copy()
rendered_views=list(globals().get('VIEWS',views))
for name in rendered_views:
    loc,scale=views[name];camera.location=loc
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
    scene.render.filepath=str(OUT/('preview-'+name+'.png'))
    bpy.ops.render.render(write_still=True)
    view_data[name]={'camera_location':list(camera.location),'target':list(target),'orthographic_scale':scale,'resolution':[scene.render.resolution_x,scene.render.resolution_y],'cycles_samples':scene.cycles.samples}
    (OUT/'render-progress.log').write_text('RENDER_READY '+name+'\n')
    print('RENDER_READY',name)
(OUT/'render-conditions.json').write_text(json.dumps({'blender':bpy.app.version_string,'engine':scene.render.engine,'view_transform':scene.view_settings.view_transform,'look':scene.view_settings.look,'views':view_data,'model_inputs':{'build_source_sha256':hashlib.sha256((OUT/'build_tank.py').read_bytes()).hexdigest(),'normal_source_sha256':hashlib.sha256((OUT.parents[2]/'2026-09-26/medium-guardian-3d/medium-guardian.blend').read_bytes()).hexdigest(),'frame_revision':scene.objects['Tank_WideChest_ROOT'].get('frame_revision','')},'last_rendered_views':rendered_views},indent=2))
loc,scale=views['three-quarter'];camera.location=loc
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
scene.render.filepath=str(OUT/'preview-three-quarter.png')
bpy.data.libraries.write(str(OUT/'tank-wide-chest.blend'),{scene},fake_user=True,compress=True)
(OUT/'render-progress.log').write_text('COMPLETE_RENDERED '+','.join(rendered_views)+'\n')
