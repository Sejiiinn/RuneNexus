import bpy,json,shutil
from pathlib import Path
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
root=Path('/Users/sejin/Documents/Codex/RuneNexus/design/stage1_3d/cannon_impact/v2')
shutil.copy2(root/'cannon_impact_cinematic.blend',root/'production/.source-import.blend')
for old in list(bpy.data.scenes):
 if old.name.startswith('ProductionCannon'):bpy.data.scenes.remove(old)
with bpy.data.libraries.load(str(root/'production/.source-import.blend'),link=False) as (src,dst):dst.scenes=['CannonImpactV2','CannonGroundV2']
body,ground=dst.scenes;body.name='ProductionCannonBody';ground.name='ProductionCannonGround'
shutil.copy2(root/'preview/impact-review.blend',root/'production/.review-import.blend')
with bpy.data.libraries.load(str(root/'production/.review-import.blend'),link=False) as (src,dst):dst.objects=['Review camera','Review soft key','Impact reflected light']
cam,key,flash=dst.objects
body.collection.objects.link(cam);body.collection.objects.link(key);body.collection.objects.link(flash);body.camera=cam
for light in [key,flash]:ground.collection.objects.link(light)
ground.camera.location=(0,0,10);ground.camera.rotation_euler=(0,0,0);ground.camera.data.type='ORTHO';ground.camera.data.ortho_scale=4.9
for scene in [body,ground]:
 scene.render.engine='CYCLES';scene.cycles.device='GPU';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8';scene.frame_set(8)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for device in prefs.devices:device.use=device.type=='METAL'
bpy.context.window.scene=body
bpy.context.view_layer.update()
cam.matrix_world=Matrix.LocRotScale(cam.location,cam.rotation_euler.to_quaternion(),cam.scale)
v=world_to_camera_view(body,body.camera,Vector((0,0,0)));metadata={'frame_count':32,'frame_width':256,'frame_height':256,'columns':8,'rows':4,'duration_seconds':1.1,'body_pivot_bottom_left':[v.x,v.y],'body_pivot_top_left':[v.x,1-v.y],'ground_pivot':[.5,.5],'body_camera_location':list(cam.location),'body_ortho_scale':cam.data.ortho_scale}
(root/'production/export_metadata.json').write_text(json.dumps(metadata,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(root/'production/cannon_export.blend'));print(metadata)

for temp in ['.source-import.blend','.review-import.blend']:(root/'production'/temp).unlink(missing_ok=True)
