"""Render selected orthographic views from the editable concept scene.

Run in Blender after build_guardian.py, or after opening the saved .blend.
Set VIEWS to e.g. ['front'] in globals before executing to render only one view.
"""
import bpy
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['C1_Guardian_Concept']
bpy.context.window.scene=scene
camera=scene.camera
target=Vector((0,0,2.30))
shots={'front':(0,-12,2.30),'side':(12,0,2.30),'back':(0,12,2.30),'three-quarter':(7,-11,6.2)}
for name in globals().get('VIEWS',list(shots)):
    camera.location=shots[name]
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=5.4
    scene.render.filepath=str(OUT/('preview-'+name+'.png'))
    next(o for o in scene.objects if 'studio ground' in o.name).hide_render=(name!='three-quarter')
    scene.cycles.samples=48
    bpy.ops.render.render(write_still=True)
    print('RENDERED',name)
next(o for o in scene.objects if 'studio ground' in o.name).hide_render=False
camera.location=shots['three-quarter']
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'preview-three-quarter.png')
bpy.data.libraries.write(str(OUT/'chapter1-normal-guardian.blend'),{scene},fake_user=True,compress=True)
