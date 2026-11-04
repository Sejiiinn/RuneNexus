"""Create a rigid stone walking rig, preserving the existing model and open scenes.
Run via Blender MCP with exec(compile(...), {'__file__': ...}).
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
OUT=Path(__file__).resolve().parent
SOURCE='Medium_Guardian_Concept'; NAME='Medium_Guardian_Walk'; PREFIX='Medium_Guardian_'
if bpy.data.scenes.get(NAME):
    old=bpy.data.scenes[NAME]
    old_rig=old.objects.get('Guardian_Walk_Rig')
    old_action=old_rig.animation_data.action if old_rig and old_rig.animation_data else None
    for o in list(old.objects):bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
    if old_action and old_action.users<=1:bpy.data.actions.remove(old_action)
src=bpy.data.scenes[SOURCE]
scene=src.copy();scene.name=NAME
# Own all objects, meshes, camera, light data; original geometry/materials untouched.
for c in list(scene.collection.children):scene.collection.children.unlink(c)
model=bpy.data.collections.new('Walk_MODEL');studio=bpy.data.collections.new('Walk_STUDIO')
scene.collection.children.link(model);scene.collection.children.link(studio)
objects={};rest={}
for old in src.objects:
    o=old.copy()
    if old.data:o.data=old.data.copy()
    o.name='Walk_'+old.name.removeprefix(PREFIX)
    o.parent=None;o.matrix_world=old.matrix_world.copy()
    (model if old.parent or old.name.endswith('ROOT') else studio).objects.link(o)
    objects[old.name.removeprefix(PREFIX)]=o;rest[o.name]=old.matrix_world.copy()
scene.camera=objects['Camera'];scene.world=src.world.copy()
bpy.context.window.scene=scene
root=objects['ROOT'];root['scope']='Editable rigid skeletal Walk; in-place; no game integration.'
arm=bpy.data.armatures.new('Guardian_Walk_Skeleton');rig=bpy.data.objects.new('Guardian_Walk_Rig',arm);model.objects.link(rig)
rig.show_in_front=True;arm.display_type='STICK';rig.parent=root
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
    b=arm.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=arm.edit_bones[parent]
    return b
bone('root',(0,0,0),(0,0,.3));bone('pelvis',(0,0,1.47),(0,0,1.85),'root');bone('torso',(0,0,1.85),(0,0,2.68),'pelvis');bone('head',(0,.04,2.68),(0,.04,3.6),'torso')
for side,s in [('L',-1),('R',1)]:
    bone('upper_arm.'+side,(s*.98,.01,2.55),(s*1.44,-.01,2.06),'torso')
    bone('forearm.'+side,(s*1.44,-.01,2.06),(s*1.62,-.10,1.62),'upper_arm.'+side)
    bone('thigh.'+side,(s*.49,.04,1.47),(s*.75,-.015,.79),'pelvis')
    bone('shin.'+side,(s*.75,-.015,.79),(s*.79,-.13,.35),'thigh.'+side)
    bone('foot.'+side,(s*.79,-.13,.35),(s*.79,-.48,.35),'shin.'+side)
bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update()
assign={}
for name,o in objects.items():
    if o.type!='MESH' or o not in list(model.objects):continue
    b='torso'
    if 'pelvis' in name:b='pelvis'
    if any(k in name for k in ['head','eye','spiral','moss','neck']):b='head'
    if name[:2] in ['L ','R ']:
        side=name[0]
        if any(k in name for k in ['SHOULDER','shoulder']):b='upper_arm.'+side
        elif any(k in name for k in ['ELBOW','forearm','knuckle','thumb']):b='forearm.'+side
        elif any(k in name for k in ['HIP','thigh']):b='thigh.'+side
        elif 'KNEE' in name:b='shin.'+side
        elif 'boot' in name:b='foot.'+side
    w=o.matrix_world.copy();o.parent=rig;o.parent_type='BONE';o.parent_bone=b
    tail=Matrix.Translation((0,arm.bones[b].length,0))
    o.matrix_parent_inverse=(arm.bones[b].matrix_local@tail).inverted()
    o.matrix_basis=w
    assign[name]=b
bpy.context.view_layer.update()
rest_error=max(max(abs(o.matrix_world[i][j]-rest[o.name][i][j]) for i in range(4) for j in range(4)) for o in objects.values())
assert rest_error<1e-5,rest_error
rig['front_axis']='-Y';rig['cycle_seconds']=1.2;rig['contact_fraction']=.6;rig['stance_travel']=.42;rig['matched_speed_units_per_second']=.42/(.6*1.2)
rig['binding']='Rigid bone parenting, original mesh coordinates and materials; no stone deformation.'
scene.render.fps=30;scene.frame_start=1;scene.frame_end=36
R={b.name:b.matrix_local.copy() for b in arm.bones};H={b.name:b.head_local.copy() for b in arm.bones};T={b.name:b.tail_local.copy() for b in arm.bones}
def rotation(axis,angle):return Matrix.Rotation(angle,4,axis)
def around(p,rot):return Matrix.Translation(p)@rot@Matrix.Translation(-p)
def foot_path(q):
    q%=1
    if q<=.6:return -.21+.42*q/.6,0.0,True
    u=(q-.6)/.4;u2=u*u;u3=u2*u
    y=(2*u3-3*u2+1)*.21+(u3-2*u2+u)*(.42/.6*.4)+(-2*u3+3*u2)*(-.21)+(u3-u2)*(.42/.6*.4)
    return y,.16*math.sin(math.pi*u)**2,False

def align(name,a,b):
    # rigid rotate rest direction onto target direction, retain bone length
    q=(T[name]-H[name]).rotation_difference(b-a)
    return Matrix.Translation(a)@q.to_matrix().to_4x4()@Matrix.Translation(-H[name])@R[name]
def solve_knee(hip,ankle,side):
    l1=(T['thigh.'+side]-H['thigh.'+side]).length;l2=(T['shin.'+side]-H['shin.'+side]).length
    d=ankle-hip;dist=d.length;v=d.normalized();assert dist<l1+l2
    along=(l1*l1-l2*l2+dist*dist)/(2*dist)
    pole=Vector((0,-1,0));pole=(pole-v*pole.dot(v)).normalized()
    return hip+v*along+pole*math.sqrt(max(0,l1*l1-along*along))
for sample in range(361):
    f=1+sample/10
    q=(f-1)/36;angle=2*math.pi*q
    shift=Vector((-.036*math.sin(angle),0,-.075+.017*math.cos(2*angle)))
    body=Matrix.Translation(shift)@around(H['pelvis'],rotation('Y',math.radians(.7)*math.sin(angle)))
    mats={'root':R['root'],'pelvis':body@R['pelvis']}
    chest=body@around(H['torso'],rotation('Z',math.radians(1.1)*math.sin(angle)))
    mats['torso']=chest@R['torso']
    neck=chest@H['head'];head=Matrix.Translation(neck)@rotation('Y',math.radians(.25)*math.sin(angle))@Matrix.Translation(-H['head'])
    mats['head']=head@R['head']
    for side,s,p in [('L',-1,q),('R',1,q+.5)]:
        # Opposite arm to leg: forward leg means its arm swings backwards.
        swing=math.radians(9.0)*math.cos(2*math.pi*p)
        upper=chest@around(H['upper_arm.'+side],rotation('X',swing))
        mats['upper_arm.'+side]=upper@R['upper_arm.'+side]
        lower=upper@around(H['forearm.'+side],rotation('Y',s*math.radians(2.0)*(1-math.cos(2*math.pi*p))))
        mats['forearm.'+side]=lower@R['forearm.'+side]
        y,z,contact=foot_path(p)
        ankle=H['foot.'+side]+Vector((0,y,z));hip=body@H['thigh.'+side]
        knee=solve_knee(hip,ankle,side)
        mats['thigh.'+side]=align('thigh.'+side,hip,knee)
        mats['shin.'+side]=align('shin.'+side,knee,ankle)
        mats['foot.'+side]=Matrix.Translation(ankle-H['foot.'+side])@R['foot.'+side]
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION';b.matrix=mats[b.name]
        bpy.context.view_layer.update()
        b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
action=rig.animation_data.action;action.name='Walk';action.use_fake_user=True
for layer in action.layers:
    for strip in layer.strips:
        for slot in action.slots:
            bag=strip.channelbag(slot)
            if bag:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:kp.interpolation='LINEAR'
                    fc.modifiers.new('CYCLES')
for f,n in [(1,'L contact'),(4,'L support / R toe-off'),(12,'R swing apex'),(19,'R contact'),(22,'R support / L toe-off'),(30,'L swing apex'),(37,'Loop closure (exclude from playback)')]:scene.timeline_markers.new(n,frame=f)
scene.frame_set(1);scene.render.resolution_x=720;scene.render.resolution_y=720;scene.cycles.samples=24
scene['walk_readme']='walk/README.md';scene['source_model']='../medium-guardian.blend'
(OUT/'rig-map.json').write_text(json.dumps({'rigid_mesh_count':len(assign),'rest_matrix_error':rest_error,'assignments':assign},indent=2))
bpy.data.libraries.write(str(OUT/'medium-guardian-walk.blend'),{scene},fake_user=True,compress=True)
print('WALK_BUILT',len(assign),rest_error)
