"""Camera-only renders of the final Blender concept; preserves source view."""
import bpy,math,json,time
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.data.scenes['Fast_Hound_Concept'];bpy.context.window.scene=scene
cam=scene.camera;target=Vector((0,.08,1.3))
# Drone angle is 25 degrees off vertical, matching existing guardian convention.
r=10*math.tan(math.radians(25))
views={
 'hero-three-quarter':((5,-7,4),5.3,1400,1200),
 'front':((0,-12,1.3),3.4,1200,1200),
 'side':((12,.08,1.3),5.2,1600,1050),
 'back':((0,12,1.3),3.4,1200,1200),
 'top':((0,.08,13),5.2,1200,1600),
 'drone-25':((r*.53,-r*.85,11.3),5.2,1400,1400),
}
original=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.render.filepath)
log={'status':'rendering','completed':[],'drone_definition':'25 degrees off vertical; orthographic'}
for name in globals().get('VIEWS',views):
 loc,scale,w,h=views[name];cam.location=loc;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(OUT/(name+'.png'))
 bpy.ops.render.render(write_still=True);log['completed'].append(name);(OUT/'render-status.json').write_text(json.dumps(log,indent=2));print('RENDER_READY',name,flush=True)
cam.location,cam.rotation_euler,cam.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.render.filepath=original
log['status']='complete';(OUT/'render-status.json').write_text(json.dumps(log,indent=2))
