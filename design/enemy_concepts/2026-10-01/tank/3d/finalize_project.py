"""Make the isolated scene library a directly openable .blend.
Run only in an independent background process; leaves the live Blender untouched.
Blender --background tank-wide-chest.blend --python finalize_project.py
"""
import bpy,sys,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
comparison='--comparison' in sys.argv
scene=bpy.data.scenes['Tank_Normal_Size_Comparison' if comparison else 'Tank_WideChest_Concept']
for window in bpy.context.window_manager.windows:window.scene=scene
for other in list(bpy.data.scenes):
    if other!=scene and not other.objects:bpy.data.scenes.remove(other)
root=scene.objects['Tank_WideChest_ROOT'] if not comparison else next(o for o in scene.objects if o.type=='MESH')
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
h=root['tank_height'] if not comparison else json.loads((OUT/'size-comparison.json').read_text())['tank_height']
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.region_3d.view_distance=h*1.8;space.region_3d.view_location=Vector((0,0,h*.5));space.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion();space.clip_end=300
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/('tank-normal-size-comparison.blend' if comparison else 'tank-wide-chest.blend')),compress=True)
print('FINAL_PROJECT',bpy.context.scene.name,len(bpy.context.scene.objects))
