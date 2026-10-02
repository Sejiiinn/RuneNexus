"""Create editable rigid heavy-collapse libraries through the existing Blender MCP.

Saved Walk inputs and opened/unsaved scenes are preserved. Runtime atlas, mesh
topology, bind and scale are reused exactly; only the new Death action changes.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent
WALK = OUT.parent / 'walk' / 'tank-walk.blend'
RUNTIME = OUT.parent / 'game-export' / 'tank-walk-runtime.blend'
previous = bpy.context.window.scene
with bpy.data.libraries.load(str(RUNTIME), link=False) as (src, dst):
    dst.scenes = ['Tank_Walk_Runtime']
scene = dst.scenes[0]
scene.name = 'Tank_Death_Runtime'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.name = 'Tank_Death_Rig'
scene.frame_set(0)
bpy.context.view_layer.update()
initial = {b.name: b.matrix.copy() for b in rig.pose.bones}
rig.animation_data_clear()
R = {b.name: b.matrix_local.copy() for b in rig.data.bones}
H = {b.name: b.head_local.copy() for b in rig.data.bones}
T = {b.name: b.tail_local.copy() for b in rig.data.bones}
points = {b: [] for b in R}
triangles = 0
for obj in scene.objects:
    if obj.type != 'MESH': continue
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
    for v in obj.data.vertices:
        for g in v.groups:
            if g.weight > .5:
                points[obj.vertex_groups[g.group].name].append(v.co.copy())
assert triangles == 21664

def rot(axis, degrees): return Matrix.Rotation(math.radians(degrees), 4, axis)
def around(p, rotation): return Matrix.Translation(p) @ rotation @ Matrix.Translation(-p)
def align(name, a, b):
    q = (T[name]-H[name]).rotation_difference(b-a)
    return Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Translation(-H[name]) @ R[name]
def smooth(a, b, t):
    u = max(0, min(1, (t-a)/(b-a)))
    return u*u*(3-2*u)
def curve(t, anchors):
    for (a,x),(b,y) in zip(anchors, anchors[1:]):
        if t <= b: return x+(y-x)*smooth(a,b,t)
    return anchors[-1][1]
def joint(a, c, l1, l2, pole):
    delta = c-a
    distance = max(abs(l1-l2)+.001, min(l1+l2-.001, delta.length))
    direction = delta.normalized()
    c = a+direction*distance
    along = (l1*l1-l2*l2+distance*distance)/(2*distance)
    pole = (pole-direction*pole.dot(direction)).normalized()
    return a+direction*along+pole*math.sqrt(max(0,l1*l1-along*along)), c
def ground(name, matrix):
    # Contact is solved in the model's raw coordinates before normalization.
    transform = matrix @ R[name].inverted()
    low = min((transform @ p).z for p in points[name]) if points[name] else 0
    if low < 0: matrix = Matrix.Translation((0,0,-low)) @ matrix
    return matrix

def pose(t):
    drop = curve(t, [(0,.15),(.10,.12),(.15,.16),(.27,1.10),(.40,1.12),(.70,1.15)])
    back = curve(t, [(0,0),(.15,.035),(.27,.62),(.40,.68),(.70,.71)])
    pitch = curve(t, [(0,2.8),(.10,-7),(.15,-4),(.40,33),(.57,59),(.70,76)])
    body = Matrix.Translation((0,back,-drop))
    chest = body @ around(H['torso'],rot('X',pitch))
    mats = {'root':R['root'], 'pelvis':body@R['pelvis'], 'torso':chest@R['torso']}
    mats['head'] = chest @ around(H['head'],rot('X',curve(t,[(0,0),(.15,3),(.40,9),(.70,12)]))) @ R['head']
    for side, sign in [('L',-1),('R',1)]:
        thigh, link, foot = 'thigh.'+side, 'ankle_link.'+side, 'foot.'+side
        hip = body @ H[thigh]
        ankle = H[foot]
        knee, ankle = joint(hip,ankle,(T[thigh]-H[thigh]).length,(T[link]-H[link]).length,Vector((0,-1,0)))
        mats[thigh], mats[link] = align(thigh,hip,knee), align(link,knee,ankle)
        mats[foot] = Matrix.Translation(ankle-H[foot]) @ R[foot]
        upper, fore = 'upper_arm.'+side, 'forearm.'+side
        shoulder = chest @ H[upper]
        wrist = chest @ T[fore]
        if side == 'R':
            hand = wrist.lerp(Vector((1.43,-.25,.14)),smooth(.15,.27,t))
            release = smooth(.41,.70,t)
            hand += Vector((.30,-.30,-.06))*release
        else:
            hand = wrist + Vector((-.10,-.10,-.20))*smooth(.15,.4,t)
        elbow, hand = joint(shoulder,hand,(T[upper]-H[upper]).length,(T[fore]-H[fore]).length,Vector((sign,.05,.05)))
        if side == 'R' and .27 <= t <= .41:
            # Solve the actual palm geometry, preserving both original arm lengths.
            for iteration in range(8):
                matrix = align(fore,elbow,hand) @ R[fore].inverted()
                contact = min((matrix @ p).z for p in points[fore])
                if abs(contact) < .00005: break
                hand.z -= contact
                elbow,hand=joint(shoulder,hand,(T[upper]-H[upper]).length,(T[fore]-H[fore]).length,Vector((sign,.05,.05)))
        mats[upper], mats[fore] = align(upper,shoulder,elbow), align(fore,elbow,hand)
    release = smooth(.43,.68,t)
    # Four original large rigid clusters loosen and fall. No small fragment spray.
    for name, drift, angle in [
        ('upper_arm.L',(-.42,.08,-.48),-28),('forearm.L',(-.52,-.28,-.38),34),
        ('upper_arm.R',(.35,.12,-.38),22),('forearm.R',(.22,-.30,-.06),-18)]:
        p = mats[name] @ R[name].inverted() @ H[name]
        mats[name] = Matrix.Translation(Vector(drift)*release) @ around(p,rot('Y',angle*release)) @ mats[name]
    # Last 0.1s is a short weighted settling, with no bounce or ground tunneling.
    for name in list(mats):
        if name != 'root': mats[name] = ground(name,mats[name])
    if t == 0: return initial
    blend = smooth(0,.12,t)
    for name in mats:
        p0,q0,s0 = initial[name].decompose()
        p1,q1,s1 = mats[name].decompose()
        mats[name] = Matrix.LocRotScale(p0.lerp(p1,blend),q0.slerp(q1,blend),s0.lerp(s1,blend))
    return mats

samples = []
for frame in range(43):
    mats = pose(frame/60)
    samples.append(mats)
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.matrix = mats[bone.name]
        bpy.context.view_layer.update()
        for prop in ['location','rotation_quaternion','scale']:
            bone.keyframe_insert(prop,frame=frame,group=bone.name)
action = rig.animation_data.action
action.name = 'Death'
for layer in action.layers:
    for strip in layer.strips:
        for slot in action.slots:
            bag = strip.channelbag(slot)
            if bag:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points: key.interpolation = 'LINEAR'
scene.frame_start, scene.frame_end = 0,42
scene.render.fps = 60
scene.frame_set(0)
scene['scope'] = '0.7s heavy collapse; 1.4s combat-clock presentation lifetime; no gameplay state.'
scene['source'] = '../game-export/tank-walk-runtime.blend'
bpy.data.libraries.write(str(OUT/'tank-death-runtime.blend'),{scene},fake_user=True,compress=True)

# The original 38 separate meshes remain editable in a separate authoring library.
with bpy.data.libraries.load(str(WALK),link=False) as (src,dst):
    dst.scenes = ['Tank_WideChest_Walk']
author = dst.scenes[0]
author.name = 'Tank_Heavy_Death'
bpy.context.window.scene = author
arig = next(o for o in author.objects if o.type == 'ARMATURE')
arig.animation_data_clear()
for frame,mats in enumerate(samples):
    for bone in arig.pose.bones:
        bone.rotation_mode='QUATERNION'
        bone.matrix=mats[bone.name]
        bpy.context.view_layer.update()
        for prop in ['location','rotation_quaternion','scale']:
            bone.keyframe_insert(prop,frame=frame,group=bone.name)
arig.animation_data.action.name='Tank_Heavy_Death'
author.frame_start,author.frame_end=0,42
author.render.fps=60
author.frame_set(0)
author['scope']=scene['scope']
for frame,name in [(0,'Impact'),(6,'Core flash'),(9,'Core off'),(24,'Right palm supports'),(33,'Arm gives way'),(42,'Heavy rest')]:
    author.timeline_markers.new(name,frame=frame)
bpy.data.libraries.write(str(OUT/'tank-death.blend'),{author},fake_user=True,compress=True)
floor = {}
for frame,mats in enumerate(samples):
    floor[str(frame)] = min((mats[n]@R[n].inverted()@p).z for n in points for p in points[n])
report = {'walk_sha256':hashlib.sha256(WALK.read_bytes()).hexdigest(),'runtime_walk_sha256':hashlib.sha256(RUNTIME.read_bytes()).hexdigest(),'triangles':triangles,'bones':len(R),'runtime_meshes':3,'author_meshes':38,'collapse_seconds':.7,'presentation_lifetime_seconds':1.4,'normalization':rig.scale.x,'min_floor_raw':min(floor.values()),'detached_original_clusters':['upper_arm.L','forearm.L','upper_arm.R','forearm.R']}
(OUT/'death-contract.json').write_text(json.dumps(report,indent=2)+'\n')
(OUT/'local'/'authoring-floor-frames.json').write_text(json.dumps(floor,indent=2)+'\n')
bpy.context.window.scene = previous
print('TANK_DEATH_BUILT',json.dumps(report))
