"""Expose actual recessed heat behind aperture at game's 55-degree view."""
import bpy,math
from mathutils import Vector
from pathlib import Path
HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'chapter3-thick-tiles.blend'
assert bpy.app.background
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
root=bpy.data.objects['06_Panel_vent']
for ob in root.children:
 if ob.name.startswith('Recessed vent heat core'):
  for v in ob.data.vertices:
   if v.co.z<-.34:v.co.z=-.398
 if ob.name.startswith('Vent cavity back'):
  for v in ob.data.vertices:
   if v.co.z<-.34:v.co.z=-.400
s=bpy.context.scene;cam=s.camera
# Source assembled preview is made from linked source meshes.
cam.location=(0,-7,7*math.tan(math.radians(55))-.18)
cam.rotation_euler=(Vector((0,0,-.18))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=5.25;s.cycles.samples=32;s.render.resolution_x=1800;s.render.resolution_y=950
s.render.filepath=str(HERE/'vent-55deg-source.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.render.render(write_still=True)
print('VENT_55_SOURCE_READY',flush=True)
