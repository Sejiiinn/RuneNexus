"""Approved low levitation/C-curl exit. Rigid FK poses, baked offline; no dissolve.
Run against approved gallop-kick-v9 blend in an isolated background Blender.
"""
import bpy,math,json,hashlib,shutil
from pathlib import Path
from mathutils import Matrix,Vector
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'run/gallop-kick-v9/fast-rune-hound-run.blend'
s=bpy.data.scenes['Fast_Hound_Run'];s.name='Fast_Hound_Death'
for w in bpy.context.window_manager.windows:w.scene=s
rig=s.objects['Fast_Hound_Run_Rig'];rig.name='Fast_Hound_Death_Rig'
rig.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
R={b.name:b.matrix_local.copy() for b in rig.data.bones}
H={b.name:b.head_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
def smooth(v):
    v=max(0.,min(1.,v));return v*v*(3-2*v)
def around(p,a):return Matrix.Translation(p)@Matrix.Rotation(math.radians(a),4,'X')@Matrix.Translation(-p)
def pose(t):
    curl=smooth(t/.37);limb=smooth((t-.02)/.35);tail=smooth((t-.02)/.37)
    # Each local articulation is rigid; parent transformations retain joint continuity.
    angles={'body':15*curl,'waist':-25*curl,'pelvis':-55*curl,'neck':35*curl,'head':50*curl,'tail_base':-55*tail,'tail_tip':-80*tail}
    for side in ['L','R']:
        f=smooth((t-(.025 if side=='R' else .04))/.35)
        angles.update({'scapula.'+side:0,'front_upper.'+side:45*f,'front_lower.'+side:-105*f,'front_paw.'+side:95*f,'rear_upper.'+side:-12*limb,'rear_lower.'+side:35*limb,'rear_paw.'+side:-35*limb,'rear_foot.'+side:-35*limb})
    transforms={}
    for b in rig.pose.bones:
        n=b.name;p=parents[n];parent=transforms[p] if p else Matrix.Identity(4)
        transforms[n]=parent@around(H[n],angles.get(n,0))
        if n=='root':transforms[n]=Matrix.Translation((0,0,.42*smooth(t/.22)))
        b.rotation_mode='QUATERNION';b.matrix=transforms[n]@R[n];bpy.context.view_layer.update()
s.render.fps=60;s.frame_start=1;s.frame_end=34
for i in range(133):
    f=1+i/4;t=i/240
    pose(t)
    for b in rig.pose.bones:
        b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
a=rig.animation_data.action;a.name='Death'
for layer in a.layers:
 for strip in layer.strips:
  for slot in a.slots:
   bag=strip.channelbag(slot)
   if bag:
    for fc in bag.fcurves:
     for kp in fc.keyframe_points:kp.interpolation='LINEAR'
     fc.extrapolation='CONSTANT'
for mark in list(s.timeline_markers):s.timeline_markers.remove(mark)
for frame,name in [(1,'Start'),(7,'Levitation'),(20,'Curl'),(34,'Curled hold / engine fade complete')]:s.timeline_markers.new(name,frame=frame)
contract={'clip':'Death','cycle_seconds':.55,'duration_seconds':.55,'fps':60,'frames_per_cycle':33,'loop':False,'source_width':1.91560959815979,'normalized_ground_offset':.014982159223757006,'author_ground_z':-.02869996801018715,'runtime_presentation_scale':.432,'normalized_runtime_width':1.,'root_motion':'No planar translation; baked vertical levitation 0.42 author units','dissolve':'Godot controls body fade; no alpha, particle, scale animation in GLB','source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'pose':'Low levitation with progressive C curl; head to chest, forelegs inward, hind legs to abdomen, tail curls forward','geometry':'Original 102 rigid source meshes / 20214 triangles / 24 bones; original PBR atlas reused'}
(OUT/'motion-contract.json').write_text(json.dumps(contract,indent=2))
shutil.copy2(OUT.parent/'run/gallop-kick-v9/rig-map.json',OUT/'rig-map.json')
s.camera.animation_data_clear();target=Vector((0,.1,1.35));s.camera.location=(5,-7,4);s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=5.5
s.frame_set(1);bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fast-rune-hound-death.blend'),compress=True)
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=24;s.render.resolution_x=640;s.render.resolution_y=480;s.render.resolution_percentage=100
for frame,label in [(1,'start'),(20.2,'curl'),(34,'end')]:
 s.frame_set(int(frame),subframe=frame%1);s.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
print('DEATH_BUILT',flush=True)
