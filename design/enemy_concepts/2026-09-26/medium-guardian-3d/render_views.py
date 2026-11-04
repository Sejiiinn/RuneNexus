"""Render the saved concept in Blender; no scene or model changes beyond camera.
Run with exec(compile(open(path).read(),path,'exec'), {'__file__':path}).
Set VIEWS before exec for a selected subset, otherwise all five are rendered.
"""
import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Medium_Guardian_Concept']
bpy.context.window.scene=scene
camera=scene.camera
views={
    'front':((0,-12,3.15),5.35),
    'side':((12,0,3.15),5.35),
    'back':((0,12,3.15),5.35),
    'three-quarter':((6.4,-11,6.0),5.7),
    'high-angle':((5.2,-8.6,10.4),5.7),
    'drone-25':((2.4128568906,-3.9904940883,12.29),5.6),
}
scene.cycles.samples=48;scene.render.resolution_percentage=100
for name in globals().get('VIEWS',views):
    loc,scale=views[name];camera.location=loc
    camera.rotation_euler=(Vector((0,0,2.29))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
    scene.render.filepath=str(OUT/('preview-'+name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('RENDER_READY',name)
loc,scale=views['three-quarter'];camera.location=loc
camera.rotation_euler=(Vector((0,0,2.29))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
scene.render.filepath=str(OUT/'preview-three-quarter.png')
bpy.data.libraries.write(str(OUT/'medium-guardian.blend'),{scene},fake_user=True,compress=True)
