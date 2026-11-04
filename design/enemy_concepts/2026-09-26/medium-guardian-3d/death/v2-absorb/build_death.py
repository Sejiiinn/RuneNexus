"""Deterministic 0.85-second rigid-stone death. Execute through Blender MCP.
Preserves approved geometry/materials and every existing source/walk scene.
"""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
OUT=Path(__file__).resolve().parent;NAME='Medium_Guardian_Death_Absorb'
if bpy.data.scenes.get(NAME):
    old=bpy.data.scenes[NAME]
    for o in list(old.objects):bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
source=bpy.data.scenes['Medium_Guardian_Walk_V3'];s=source.copy();s.name=NAME
for c in list(s.collection.children):s.collection.children.unlink(c)
model=bpy.data.collections.new('Death_Absorb_MODEL');studio=bpy.data.collections.new('Death_Absorb_STUDIO');dust=bpy.data.collections.new('Death_Absorb_DUST')
for c in [model,studio,dust]:s.collection.children.link(c)
mp={}
for old in source.objects:
    o=old.copy()
    if old.data:o.data=old.data.copy()
    o.name='Death_Absorb_'+old.name.removeprefix('V3_');o.animation_data_clear()
    (model if old.type not in {'LIGHT','CAMERA'} and 'studio ground' not in old.name else studio).objects.link(o);mp[old]=o
for old,o in mp.items():
    if old.parent:o.parent=mp[old.parent]
    o.matrix_parent_inverse=old.matrix_parent_inverse.copy();o.matrix_basis=old.matrix_basis.copy()
s.camera=mp[source.camera];s.world=source.world.copy();bpy.context.window.scene=s
rig=next(o for o in model.objects if o.type=='ARMATURE');rig.name='Guardian_Death_Absorb_Rig';root=rig.parent;root.name='Death_Absorb_ROOT'
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4);b.rotation_mode='QUATERNION'
bpy.context.view_layer.update()
R={b.name:b.matrix_local.copy() for b in rig.data.bones};H={b.name:b.head_local.copy() for b in rig.data.bones};T={b.name:b.tail_local.copy() for b in rig.data.bones}
# Connector stubs stay with the torso when head and whole arms detach.
for o in model.objects:
    if o.type=='MESH' and ('neck spindle' in o.name or 'SHOULDER ' in o.name):
        w=o.matrix_world.copy();o.parent_bone='torso';o.matrix_parent_inverse=(R['torso']@Matrix.Translation((0,rig.data.bones['torso'].length,0))).inverted();o.matrix_basis=w
bpy.context.view_layer.update()
meshes=[o for o in model.objects if o.type=='MESH'];restworld={o.name:o.matrix_world.copy() for o in meshes}
# Private materials only: original shared materials are never animated or changed.
private={}
for o in meshes:
    if any(k in o.name for k in ['round plum eye','round plum chest heart','continuous recessed plum spiral']):
        for slot in o.material_slots:
            old=slot.material
            if old not in private:
                mat=old.copy();mat.name='Death_Absorb fade - '+old.name;private[old]=mat
                node=mat.node_tree.nodes.get('Principled BSDF');base=tuple(node.inputs['Base Color'].default_value);rough=node.inputs['Roughness'].default_value
                for f,factor,r in [(1,1,rough),(2.2,.65,.55),(5.8,.035,.96),(52,.035,.96)]:
                    node.inputs['Base Color'].default_value=tuple(v*factor for v in base[:3])+(base[3],);node.inputs['Base Color'].keyframe_insert('default_value',frame=f)
                    node.inputs['Roughness'].default_value=r;node.inputs['Roughness'].keyframe_insert('default_value',frame=f)
                if 'Emission Strength' in node.inputs:node.inputs['Emission Strength'].default_value=0
            slot.material=private[old]
points={}
for group in ['head','L','R']:
    bones=['head'] if group=='head' else ['upper_arm.'+group,'forearm.'+group]
    points[group]=[o.matrix_world@v.co for o in meshes if o.parent_bone in bones for v in o.data.vertices]
def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
def rot(axis,a):return Matrix.Rotation(math.radians(a),4,axis)
def around(p,r):return Matrix.Translation(p)@r@Matrix.Translation(-p)
def torso_transform(t):
    recoil=smooth(t/.08) if t<.08 else 1-smooth((t-.08)/.10)
    fall=smooth((t-.08)/.20)
    body=Matrix.Translation((0,.035*recoil+.12*fall,-.025*recoil-.63*fall))@around(H['pelvis'],rot('X',-4*recoil+12*fall))
    chest=body@around(H['torso'],rot('X',-5*recoil+23*fall))
    return body,chest,recoil,fall
C={'head':Vector((0,0,3.59)),'L':Vector((-1.42,-.05,2.05)),'R':Vector((1.42,-.05,2.05))}
landing_rotation={'head':rot('Z',10)@rot('Y',-8)@rot('X',32),'L':rot('Z',-15)@rot('Y',10)@rot('X',-62),'R':rot('Z',12)@rot('Y',-8)@rot('X',-53)}
landing_xy={'head':(.20,-1.38),'L':(-1.62,-.05),'R':(1.78,.12)}
bend={'L':around(H['forearm.L'],rot('X',25)),'R':around(H['forearm.R'],rot('X',18))}
for side in ['L','R']:
    points[side]=[(bend[side]@p if o.parent_bone=='forearm.'+side else p) for o in meshes if o.parent_bone in ['upper_arm.'+side,'forearm.'+side] for v in o.data.vertices for p in [o.matrix_world@v.co]]
landing={}
for group in C:
    m=landing_rotation[group];bottom=min((m@(p-C[group])).z for p in points[group]);x,y=landing_xy[group]
    landing[group]=Vector((x,y,.035-bottom))
def rigid_chunk(group,t):
    release=.105 if group=='head' else (.125 if group=='L' else .135);land=.27 if group=='head' else (.25 if group=='L' else .275)
    body,chest,recoil,fall=torso_transform(min(t,release))
    attach=chest if group=='head' else chest@around(H['upper_arm.'+group],rot('X',-4*recoil))
    if t<=release:return attach
    u=max(0,min(1,(t-release)/(land-release)));start=attach@C[group];end=landing[group]
    q=attach.to_quaternion().slerp(landing_rotation[group].to_quaternion(),smooth(u));m=q.to_matrix().to_4x4()
    pos=Vector((start.x+(end.x-start.x)*smooth(u),start.y+(end.y-start.y)*smooth(u),start.z+(end.z-start.z)*u*u))
    if group in ['L','R']:pos.x+=(-1 if group=='L' else 1)*.14*math.sin(math.pi*u)
    bottom=min((m@(p-C[group])).z for p in points[group]);pos.z=max(pos.z,.035-bottom)
    return Matrix.Translation(pos)@m@Matrix.Translation(-C[group])
def align(name,a,b):
    q=(T[name]-H[name]).rotation_difference(b-a)
    return Matrix.Translation(a)@q.to_matrix().to_4x4()@Matrix.Translation(-H[name])@R[name]
def leg(hip,ankle,side,fall):
    a=(T['thigh.'+side]-H['thigh.'+side]).length;b=(T['shin.'+side]-H['shin.'+side]).length
    d=ankle-hip;length=d.length;v=d.normalized();assert abs(a-b)<length<a+b+1e-5,(side,length)
    restpole=H['shin.'+side]-H['thigh.'+side];restpole=(restpole-v*restpole.dot(v)).normalized()
    forward=Vector((0,-1,0));forward=(forward-v*forward.dot(v)).normalized()
    pole=(restpole*(1-fall)+forward*fall).normalized();along=(a*a-b*b+length*length)/(2*length)
    return hip+v*along+pole*math.sqrt(max(0,a*a-along*along))
for sample in range(511):
    f=1+sample/10;t=(f-1)/60;body,chest,recoil,fall=torso_transform(t)
    sink=Matrix.Translation((0,0,-2.16*smooth((t-.40)/.45)))
    mats={'root':R['root'],'pelvis':body@R['pelvis'],'torso':chest@R['torso'],'head':rigid_chunk('head',t)@R['head']}
    for side in ['L','R']:
        arm=rigid_chunk(side,t)
        mats['upper_arm.'+side]=arm@R['upper_arm.'+side]
        release=.125 if side=='L' else .135;land=.25 if side=='L' else .275
        elbow=around(H['forearm.'+side],rot('X',(25 if side=='L' else 18)*smooth((t-release)/(land-release))))
        mats['forearm.'+side]=arm@elbow@R['forearm.'+side]
        hip=body@H['thigh.'+side];ankle=H['foot.'+side];knee=leg(hip,ankle,side,fall)
        mats['thigh.'+side]=align('thigh.'+side,hip,knee);mats['shin.'+side]=align('shin.'+side,knee,ankle);mats['foot.'+side]=R['foot.'+side]
    for b in rig.pose.bones:
        b.matrix=sink@mats[b.name];bpy.context.view_layer.update();b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
rig.animation_data.action.name='Death_Absorb';rig.animation_data.action.use_fake_user=True
for layer in rig.animation_data.action.layers:
    for strip in layer.strips:
        for slot in rig.animation_data.action.slots:
            bag=strip.channelbag(slot)
            if bag:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:kp.interpolation='LINEAR'
# Tiny genuine 3D dust puffs at the ground; do not cover the character silhouette.
for i,(x,y,r) in enumerate([(-2.1,-.30,.21),(2.25,-.20,.23),(-.4,-2.25,.23),(.65,-2.10,.18),(-1.25,-1.45,.20),(-1.9,-.65,.18),(2.05,-.65,.21),(.6,.6,.16)]):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
    o=bpy.context.object;o.name=f'Death_Absorb_dust_{i:02}'
    for c in list(o.users_collection):c.objects.unlink(o)
    dust.objects.link(o);o.parent=root
    mat=bpy.data.materials.new(f'Death_Absorb dust volume {i:02}');mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Color'].default_value=(.42,.33,.23,1);mat.node_tree.links.new(v.outputs['Volume'],out.inputs['Volume']);o.data.materials.append(mat)
    for t,fac,dens in [(0,0,0),(.255,0,0),(.30,1,12),(.36,1.35,6),(.45,1.55,0)]:
        f=1+t*60;o.location=(x*(1+.08*fac),y*(1+.04*fac),.08+.08*fac);o.scale=(r*fac,)*3;o.keyframe_insert('location',frame=f);o.keyframe_insert('scale',frame=f);v.inputs['Density'].default_value=dens;v.inputs['Density'].keyframe_insert('default_value',frame=f)
s.render.fps=60;s.frame_start=1;s.frame_end=52;s.frame_set(1);s.render.resolution_x=720;s.render.resolution_y=720
rig['duration_seconds']=.85;rig['start_frame']=1;rig['end_frame']=52;rig['method']='Deterministic rigid bone keys, no physics';rig['sink_start_seconds']=.40
for f,n in [(1,'Hit'),(5.8,'Lens and rune dark'),(7.3,'Head release'),(8.5,'Left arm release'),(9.1,'Right arm release'),(17.2,'Head lands'),(17.8,'Landed'),(25,'Absorb start'),(52,'Gone')]:s.timeline_markers.new(n,frame=round(f))
(OUT/'death-contract.json').write_text(json.dumps({'duration_seconds':.85,'fps':60,'start_frame':1,'end_frame':52,'original_meshes':len(meshes),'landing_centers_model':{k:list(v) for k,v in landing.items()},'material_copies':[m.name for m in private.values()],'dust_puffs':8,'source_scene':source.name},indent=2))
bpy.data.libraries.write(str(OUT/'medium-guardian-death.blend'),{s},fake_user=True,compress=True)
print('DEATH_BUILT',len(meshes),dict((k,list(v)) for k,v in landing.items()))
