"""Normalize directly opened scene/UI in a separate background process only."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
traversal='--traversal' in sys.argv
s=bpy.data.scenes['Tank_Walk_Traversal' if traversal else 'Tank_WideChest_Walk']
for w in bpy.context.window_manager.windows:
    w.scene=s
for other in list(bpy.data.scenes):
    if other!=s and not other.objects:
        bpy.data.scenes.remove(other)
rig=s.objects['Traversal_Tank_Walk_Rig' if traversal else 'Tank_Walk_Rig']
rig.animation_data.action.name='Tank_Traversal_WeightShift' if traversal else 'Tank_Walk_WeightShift'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
s.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=10
            area.spaces.active.region_3d.view_location=Vector((0,0,2.7))
            area.spaces.active.region_3d.view_rotation=s.camera.rotation_euler.to_quaternion()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/('tank-walk-traversal.blend' if traversal else 'tank-walk.blend')),compress=True)
print('DIRECT_OPEN_READY',s.name,rig.animation_data.action.name)
