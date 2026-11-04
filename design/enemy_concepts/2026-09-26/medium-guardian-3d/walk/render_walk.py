"""Render the final real Blender scene. -- draft renders selected contact poses only.
Blender --background medium-guardian-walk.blend --python render_walk.py -- draft
Omit draft to render both cameras, one cycle (36 frames).
"""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Medium_Guardian_Walk']
for win in bpy.context.window_manager.windows:win.scene=scene
for other in list(bpy.data.scenes):
    if other!=scene and not other.objects:bpy.data.scenes.remove(other)
rig=scene.objects['Guardian_Walk_Rig'];bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=7.5;area.spaces.active.region_3d.view_location=Vector((0,0,2.3));area.spaces.active.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion()
rig.animation_data.action.name='Walk'
scene.frame_set(1);bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'medium-guardian-walk.blend'),compress=True)
print('NORMAL_PROJECT',bpy.context.scene.name,len(scene.objects),flush=True)
draft='draft' in sys.argv
scene.cycles.samples=8 if draft else 24
scene.render.resolution_x=384 if draft else 720;scene.render.resolution_y=scene.render.resolution_x
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='METAL'
    scene.cycles.device='GPU'
except Exception as e:print('GPU fallback',e)
views={'three-quarter':((6.4,-11,6),5.7),'drone-25':((2.4128568906,-3.9904940883,12.29),5.6)}
for name,(loc,scale) in views.items():
    scene.camera.location=loc;scene.camera.rotation_euler=(Vector((0,0,2.29))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=scale
    folder=OUT/('draft' if draft else 'frames')/name;folder.mkdir(parents=True,exist_ok=True)
    for f in ([1,10,19,28] if draft else range(1,37)):
        scene.frame_set(f);scene.render.filepath=str(folder/f'{f:04}.png');bpy.ops.render.render(write_still=True)
        print('FRAME_DONE',name,f,flush=True)
print('RENDER_FINISHED',flush=True)
