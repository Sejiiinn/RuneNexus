"""Normalize UI/start scene without rendering; run in separate background Blender."""
import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
s=bpy.data.scenes['Medium_Guardian_Walk']
for w in bpy.context.window_manager.windows:w.scene=s
for o in list(bpy.data.scenes):
    if o!=s and not o.objects:bpy.data.scenes.remove(o)
r=s.objects['Guardian_Walk_Rig'];r.animation_data.action.name='Walk'
bpy.ops.object.select_all(action='DESELECT');r.select_set(True);bpy.context.view_layer.objects.active=r
s.frame_set(1);s.render.resolution_x=720;s.render.resolution_y=720;s.cycles.samples=24
s.camera.location=(6.4,-11,6);s.camera.rotation_euler=(Vector((0,0,2.29))-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=5.7
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=7.5;area.spaces.active.region_3d.view_location=Vector((0,0,2.3));area.spaces.active.region_3d.view_rotation=s.camera.rotation_euler.to_quaternion()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'medium-guardian-walk.blend'),compress=True)
print('PROJECT_NORMALIZED',s.name,len(s.objects),r.animation_data.action.name)
