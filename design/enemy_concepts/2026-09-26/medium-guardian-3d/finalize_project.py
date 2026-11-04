"""Normalize a libraries.write concept into a directly openable Blender project.
Run only in a separate background process, after build/render finish:
Blender --background medium-guardian.blend --python finalize_project.py
Does not touch the already open Blender instance or unrelated scenes.
"""
import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Medium_Guardian_Concept']
for window in bpy.context.window_manager.windows:window.scene=scene
for other in list(bpy.data.scenes):
    if other!=scene and not other.objects:bpy.data.scenes.remove(other)
root=scene.objects['Medium_Guardian_ROOT']
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.region_3d.view_distance=7.5;space.region_3d.view_location=Vector((0,0,2.3));space.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion();space.clip_end=300
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'medium-guardian.blend'),compress=True)
print('FINAL_PROJECT',bpy.context.scene.name,len(bpy.context.scene.objects))
