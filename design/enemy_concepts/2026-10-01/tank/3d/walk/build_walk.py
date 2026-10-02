"""Rigid tank walk from the approved r5 model; run in the existing Blender MCP.

Only Tank_WideChest_Walk and its own copied objects are rebuilt. The opened
main file, original static tank, and every other scene remain untouched.
Preview distance/cadence follow the normal guardian V3, not a game-stat change.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix

OUT = Path(__file__).resolve().parent
SOURCE = 'Tank_WideChest_Concept'
NAME = 'Tank_WideChest_Walk'
PREFIX = 'Tank_WideChest_'
SCALE = .55 / 4.12951922416687  # common production-model -> tile scale
SPEED = .65625
CYCLE_FRAMES = 26
FPS = 60
STANCE = .55

old = bpy.data.scenes.get(NAME)
if old:
    old_rig=old.objects.get('Tank_Walk_Rig')
    old_action=old_rig.animation_data.action if old_rig and old_rig.animation_data else None
    if bpy.context.window.scene == old:
        bpy.context.window.scene = bpy.data.scenes[SOURCE]
    for o in list(old.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
    if old_action and old_action.users<=1:
        bpy.data.actions.remove(old_action)
for unused in list(bpy.data.actions):
    if unused.name.startswith('Tank_Walk_WeightShift') and unused.users<=1:
        bpy.data.actions.remove(unused)
src = bpy.data.scenes[SOURCE]
bpy.context.window.scene = src
bpy.context.view_layer.update()
scene = src.copy()
scene.name = NAME
for c in list(scene.collection.children):
    scene.collection.children.unlink(c)
model = bpy.data.collections.new('Tank_Walk_MODEL')
studio = bpy.data.collections.new('Tank_Walk_STUDIO')
scene.collection.children.link(model)
scene.collection.children.link(studio)
mapping, objects, rest = {}, {}, {}
source_root = src.objects[PREFIX + 'ROOT']
for old in src.objects:
    o = old.copy()
    if old.data:
        o.data = old.data.copy()
    o.name = 'TankWalk_' + old.name.removeprefix(PREFIX)
    (model if old.parent == source_root or old == source_root else studio).objects.link(o)
    mapping[old] = o
    objects[old.name.removeprefix(PREFIX)] = o
    rest[o.name] = old.matrix_world.copy()
for old, o in mapping.items():
    o.parent = mapping.get(old.parent)
    o.matrix_parent_inverse = old.matrix_parent_inverse.copy()
    o.matrix_basis = old.matrix_basis.copy()
scene.camera = mapping[src.camera]
scene.world = src.world.copy()
bpy.context.window.scene = scene
root = mapping[source_root]
root['scope'] = 'Editable rigid walking concept; no game integration or stat changes.'
arm = bpy.data.armatures.new('Tank_Walk_Skeleton')
rig = bpy.data.objects.new('Tank_Walk_Rig', arm)
model.objects.link(rig)
rig.parent = root
rig.show_in_front = True
arm.display_type = 'STICK'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = arm.edit_bones[parent]
    return b
bone('root', (0,0,0), (0,0,.3))
bone('pelvis', (0,.08,1.47), (0,.08,1.94), 'root')
bone('torso', (0,.08,1.94), (0,.08,2.99), 'pelvis')
bone('head', (0,.08,2.99), (0,.08,3.75), 'torso')
for side, sign in [('L',-1), ('R',1)]:
    bone('upper_arm.'+side, (sign*1.22,.05,2.71), (sign*1.76,.07,2.18), 'torso')
    bone('forearm.'+side, (sign*1.76,.07,2.18), (sign*1.89,-.005,1.35), 'upper_arm.'+side)
    bone('thigh.'+side, (sign*.57,.10,1.57), (sign*.68,-.02,.77), 'pelvis')
    # This short virtual segment stays inside the original thigh/foot overlap.
    # It carries the existing recessed ankle connector, never a new thin shin.
    bone('ankle_link.'+side, (sign*.68,-.02,.77), (sign*.73,.02,.57), 'thigh.'+side)
    bone('foot.'+side, (sign*.73,.02,.57), (sign*.73,-.42,.57), 'ankle_link.'+side)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.view_layer.update()
assign = {}
root_inv = root.matrix_world.inverted()
for name, o in objects.items():
    if o.type != 'MESH' or o not in model.objects[:]:
        continue
    b = 'torso'
    if 'pelvis' in name:
        b = 'pelvis'
    if any(k in name for k in ['head', 'eye', 'spiral', 'neck']):
        b = 'head'
    if name[:2] in ['L ', 'R ']:
        side = name[0]
        if any(k in name for k in ['shoulder', 'upper arm']):
            b = 'upper_arm.'+side
        elif any(k in name for k in ['elbow', 'forearm', 'knuckle', 'thumb']):
            b = 'forearm.'+side
        elif any(k in name for k in ['hip', 'thigh']):
            b = 'thigh.'+side
        elif 'ankle connector' in name:
            b = 'ankle_link.'+side
        elif 'foot' in name:
            b = 'foot.'+side
    w = root_inv @ rest[o.name]
    o.parent, o.parent_type, o.parent_bone = rig, 'BONE', b
    tail = Matrix.Translation((0, arm.bones[b].length, 0))
    o.matrix_parent_inverse = (arm.bones[b].matrix_local @ tail).inverted()
    o.matrix_basis = w
    assign[name] = b
bpy.context.view_layer.update()
bind_error = max(max(abs(o.matrix_world[i][j]-rest[o.name][i][j]) for i in range(4) for j in range(4)) for o in mapping.values())
assert bind_error < 2e-6, bind_error

R = {b.name: b.matrix_local.copy() for b in arm.bones}
H = {b.name: b.head_local.copy() for b in arm.bones}
T = {b.name: b.tail_local.copy() for b in arm.bones}
RAW_TILE_SCALE = SCALE * root.scale.x
CYCLE_DISTANCE = SPEED*CYCLE_FRAMES/FPS
STANCE_TRAVEL = CYCLE_DISTANCE*STANCE/RAW_TILE_SCALE
def rotation(axis, angle):
    return Matrix.Rotation(angle, 4, axis)
def around(p, rot):
    return Matrix.Translation(p) @ rot @ Matrix.Translation(-p)
def foot_path(q):
    q %= 1
    # Mean ankle Y is the hip Y, giving the short legs balanced reach.
    centre = .08
    if q <= STANCE:
        return centre-STANCE_TRAVEL/2+STANCE_TRAVEL*q/STANCE, 0., True
    u = (q-STANCE)/(1-STANCE)
    tangent = STANCE_TRAVEL/STANCE*(1-STANCE)
    y = centre+(2*u**3-3*u*u+1)*STANCE_TRAVEL/2+(u**3-2*u*u+u)*tangent+(-2*u**3+3*u*u)*(-STANCE_TRAVEL/2)+(u**3-u*u)*tangent
    return y, .18*math.sin(math.pi*u)**2, False
def align(name, a, b):
    q = (T[name]-H[name]).rotation_difference(b-a)
    return Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Translation(-H[name]) @ R[name]
reach_margin = 1e9
def solve_knee(hip, ankle, side):
    global reach_margin
    l1 = (T['thigh.'+side]-H['thigh.'+side]).length
    l2 = (T['ankle_link.'+side]-H['ankle_link.'+side]).length
    d = ankle-hip
    dist, v = d.length, d.normalized()
    reach_margin = min(reach_margin, l1+l2-dist, dist-abs(l1-l2))
    assert abs(l1-l2) < dist < l1+l2, (side,dist,l1,l2)
    along = (l1*l1-l2*l2+dist*dist)/(2*dist)
    pole = Vector((0,-1,0))
    pole = (pole-v*pole.dot(v)).normalized()
    return hip+v*along+pole*math.sqrt(max(0,l1*l1-along*along))
def pose(q):
    angle = 2*math.pi*q
    shift = Vector((-.065*math.sin(angle), 0, -.14-.040*math.cos(2*angle-.30)))
    pelvis_roll = -math.radians(1.8)*math.sin(angle)
    body = Matrix.Translation(shift) @ around(H['pelvis'], rotation('Y',pelvis_roll))
    mats = {'root':R['root'], 'pelvis':body@R['pelvis']}
    def chest_angles(a):
        return (math.radians(1+1.8*math.cos(2*a-.30)), -math.radians(2.6)*math.sin(a), math.radians(3)*math.sin(a+.18))
    pitch,roll,yaw = chest_angles(angle)
    chest = body @ around(H['torso'], rotation('Z',yaw) @ rotation('Y',roll-pelvis_roll) @ rotation('X',pitch))
    mats['torso'] = chest @ R['torso']
    hp,hr,hy = chest_angles(angle-2*math.pi*.08)
    neck = chest @ H['head']
    head_rotation = rotation('Z',.30*yaw+.40*hy) @ rotation('Y',.30*roll+.40*hr) @ rotation('X',.40*pitch+.40*hp)
    head = Matrix.Translation(neck) @ head_rotation @ Matrix.Translation(-H['head'])
    mats['head'] = head @ R['head']
    for side, sign, p in [('L',-1,q), ('R',1,q+.5)]:
        swing = math.radians(15)*math.cos(2*math.pi*p)
        upper = chest @ around(H['upper_arm.'+side],rotation('X',swing))
        mats['upper_arm.'+side] = upper @ R['upper_arm.'+side]
        lower = upper @ around(H['forearm.'+side],rotation('Y',sign*math.radians(2)*(1-math.cos(2*math.pi*p))))
        mats['forearm.'+side] = lower @ R['forearm.'+side]
        y,z,contact = foot_path(p)
        ankle = H['foot.'+side]+Vector((0,y,z))
        hip = body @ H['thigh.'+side]
        knee = solve_knee(hip,ankle,side)
        mats['thigh.'+side] = align('thigh.'+side,hip,knee)
        mats['ankle_link.'+side] = align('ankle_link.'+side,knee,ankle)
        mats['foot.'+side] = Matrix.Translation(ankle-H['foot.'+side]) @ R['foot.'+side]
    return mats
for sample in range(CYCLE_FRAMES*10+1):
    f = 1+sample/10
    mats = pose((f-1)/CYCLE_FRAMES)
    for b in rig.pose.bones:
        b.rotation_mode = 'QUATERNION'
        b.matrix = mats[b.name]
        bpy.context.view_layer.update()
        b.keyframe_insert('location',frame=f,group=b.name)
        b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
action = rig.animation_data.action
action.name = 'Tank_Walk_WeightShift'
action.use_fake_user = True
for layer in action.layers:
    for strip in layer.strips:
        for slot in action.slots:
            bag = strip.channelbag(slot)
            if bag:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:
                        kp.interpolation = 'LINEAR'
                    fc.modifiers.new('CYCLES')
rig['front_axis'] = '-Y'
rig['cycle_frames'] = CYCLE_FRAMES
rig['fps'] = FPS
rig['cycle_seconds'] = CYCLE_FRAMES/FPS
rig['cycle_distance_tiles'] = CYCLE_DISTANCE
rig['preview_speed_tiles_per_second'] = SPEED
rig['contact_fraction'] = STANCE
rig['production_model_to_tile_scale'] = SCALE
rig['raw_model_to_tile_scale'] = RAW_TILE_SCALE
rig['stance_travel_raw_units'] = STANCE_TRAVEL
rig['head_response_delay_cycles'] = .08
rig['binding'] = 'Rigid bone parenting; original 38 meshes, geometry, modifiers and materials.'
rig['phase_contract'] = 'phase=(distance_travelled_tiles/0.284375)%1; speed/slow effects advance distance and phase together.'
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 1,CYCLE_FRAMES
for f,n in [(1,'L contact'),(8,'R swing'),(14,'R contact'),(21,'L swing'),(27,'Closure key; excluded from playback')]:
    scene.timeline_markers.new(n,frame=f)
scene.frame_set(1)
scene['source_model'] = '../tank-wide-chest.blend'
scene['scope'] = root['scope']
scene['preview_contract_is_game_stat_change'] = False
(OUT/'rig-map.json').write_text(json.dumps({'mesh_count':len(assign),'bind_world_matrix_error':bind_error,'assignments':assign,'minimum_ik_reach_margin_raw':reach_margin,'source_sha256':hashlib.sha256((OUT.parent/'tank-wide-chest.blend').read_bytes()).hexdigest(),'source_frame_revision':source_root['frame_revision'],'preview_speed_tiles_per_second':SPEED,'cycle_distance_tiles':CYCLE_DISTANCE,'production_model_to_tile_scale':SCALE,'source_root_scale':root.scale.x,'raw_model_to_tile_scale':RAW_TILE_SCALE,'stance_fraction':STANCE},ensure_ascii=False,indent=2))
bpy.data.libraries.write(str(OUT/'tank-walk.blend'),{scene},fake_user=True,compress=True)
print('TANK_WALK_BUILT',len(assign),bind_error,'reach_margin',reach_margin)
