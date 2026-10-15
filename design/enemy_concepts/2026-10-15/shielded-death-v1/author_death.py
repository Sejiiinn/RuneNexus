"""Author the shielded enemy Death clip and re-export shielded.glb with Idle + Death.

Run in background Blender against the adopted in-game native blend:
  Blender -b <native.blend> --python author_death.py
The adopted native blend is never overwritten. A new authoring blend is saved next to it.

Clip: keyed stagger (power failing: drops, jolts, ring/stone wobble) followed by a
baked rigid-body fall (body topples, ring and stones drop, bounce and settle).
Geometry, UV, normals, materials and embedded PNG bytes stay identical; Idle keys
are re-exported from the same actions.
"""
import bpy, json, math, hashlib, struct
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion, Euler
from mathutils.bvhtree import BVHTree

ROOT = Path('/Users/sejin/Documents/Codex/RuneNexus')
A = Path('/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/shielded-01-20261014')
D = ROOT / 'design/enemy_concepts/2026-10-15/shielded-death-v1'
CONTRACT = json.loads((ROOT / 'design/enemy_concepts/2026-10-15/shielded-ingame-v1/asset-contract.json').read_text())
NATIVE = Path(CONTRACT['native']['path'])
DEST = A / 'blender/shielded-01-single-view-ingame-death-v1.blend'
GLB = ROOT / 'assets/images/stage1_3d/enemies/shielded.glb'
REPORT = ROOT / 'build/ignored/shielded-death/author-report.json'

FPS = 24
STAGGER_END = 17            # frame where hover power cuts out and the rigid fall begins
SIM_END = 180               # long enough for the damped stage to come to rest
GROUND_Y = -0.61            # game MODEL_LIFT: path surface in model space
# Measured upright axis used by the game (shielded_presentation.gd BODY_LONG_AXIS).
BODY_LONG_AXIS = Vector((.02246770748806868, .8929408223784795, .44961304457308127))
PARTS = ['Body', 'Ring', 'StoneLowerLeft', 'StoneUpperRight', 'StoneLowerRight', 'StoneUpperLeft']


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


assert Path('/Volumes/KIOXIA_MAC').is_mount()
assert sha(NATIVE) == CONTRACT['native']['sha256'], 'adopted native blend changed'
if bpy.data.filepath != str(NATIVE):
    bpy.ops.wm.open_mainfile(filepath=str(NATIVE))

s = bpy.context.scene
s.render.fps = FPS
hover = bpy.data.objects['HoverRoot']
meshes = [bpy.data.objects[n] for n in PARTS]
pivots = [m.parent for m in meshes]
animated = [hover] + pivots


def euler_q(x=0., y=0., z=0.):
    return Euler((math.radians(x), math.radians(y), math.radians(z)), 'XYZ').to_quaternion()


# ── 1. Move Idle into an NLA track so each track exports as one glTF animation ──
def push_track(obj, track_name):
    ad = obj.animation_data
    action = ad.action
    slot = ad.action_slot if hasattr(ad, 'action_slot') else None
    track = ad.nla_tracks.new()
    track.name = track_name
    strip = track.strips.new(track_name, int(action.frame_range[0]), action)
    if slot is not None and hasattr(strip, 'action_slot'):
        strip.action_slot = slot
    ad.action = None
    return strip


for o in animated:
    if o.animation_data and o.animation_data.action:
        push_track(o, 'Idle')

# Rest pose for Death authoring: Idle frame 1 with the game's upright body.
s.frame_set(1)
for o in animated:
    o.animation_data_create()
    o.rotation_mode = 'QUATERNION'
rest = {o.name: (o.location.copy(), o.rotation_quaternion.copy()) for o in animated}
UPRIGHT = BODY_LONG_AXIS.normalized().rotation_difference(Vector((0, 1, 0)))
rest['BodyPivot'] = (rest['BodyPivot'][0], UPRIGHT)
# The NLA Idle would otherwise keep driving these objects while authoring Death.
for o in animated:
    for t in o.animation_data.nla_tracks:
        t.mute = True


def key(o, frame, loc=None, rot=None):
    o.location = loc if loc is not None else rest[o.name][0]
    o.rotation_quaternion = rot if rot is not None else rest[o.name][1]
    o.keyframe_insert('location', frame=frame)
    o.keyframe_insert('rotation_quaternion', frame=frame)


# ── 2. Keyed stagger: the hover field fails in jolts before the drop ──
# (frame, drop, pitch, roll, yaw) for HoverRoot. Jolts coincide with game spark bursts.
HOVER_KEYS = [
    (1, 0.0, 0, 0, 0), (3, .018, 6, -4, 3), (5, .004, -4, 5, -2), (8, .022, 8, 3, 5),
    (10, .006, -3, -6, 1), (13, .016, 5, -10, -4), (15, .008, 3, -13, -2), (STAGGER_END, .012, 7, -17, -5),
]
for f, dy, px, rz, yw in HOVER_KEYS:
    loc0, q0 = rest['HoverRoot']
    key(hover, f, loc0 + Vector((0, dy, 0)), euler_q(px, yw, rz) @ q0)

# Body twitches inside the failing field (relative to the upright rest).
for f, ax, ay, az in [(1, 0, 0, 0), (4, 3, -6, 2), (7, -2, 5, -3), (11, 4, -8, 3), (14, -3, 6, -4), (STAGGER_END, 2, -3, 5)]:
    key(pivots[0], f, rot=euler_q(ax, ay, az) @ rest['BodyPivot'][1])

# Ring loses its orbit: wobbling tilt and sag.
for f, dy, ax, az in [(1, 0, 0, 0), (4, -.006, 4, -2), (8, -.01, -3, 4), (12, -.016, 6, 3), (STAGGER_END, -.022, 8, -4)]:
    loc0, q0 = rest['RingPivot']
    key(pivots[1], f, loc0 + Vector((0, dy, 0)), euler_q(ax, 0, az) @ q0)

# Stones twitch and sag individually, always drifting away from the body.
body_center = rest['BodyPivot'][0]
for i, o in enumerate(pivots[2:]):
    loc0, q0 = rest[o.name]
    out = loc0 - body_center
    out.y = 0
    out.normalize()
    phase = i * 1.7
    for k, f in enumerate([1, 4, 7, 10, 13, STAGGER_END]):
        if f == 1:
            key(o, f); continue
        drift = out * (.006 * k + .006 * math.sin(phase + k * 2.1)) + Vector((0, -.006 * k, 0))
        key(o, f, loc0 + drift, euler_q(math.sin(phase + k) * 18, k * 7 * (1 if i % 2 else -1), math.cos(phase + k) * 14) @ q0)


def check_frames(frames):
    hits, low = {}, []
    for f in frames:
        s.frame_set(f)
        trees = {}
        for m in meshes:
            verts = [m.matrix_world @ v.co for v in m.data.vertices]
            trees[m.name] = BVHTree.FromPolygons(verts, [list(p.vertices) for p in m.data.polygons], all_triangles=True)
            lo = min(v.y for v in verts)
            if lo < GROUND_Y - .004:
                low.append({'frame': f, 'part': m.name, 'min_y': round(lo, 4)})
        for i, a in enumerate(meshes):
            for b in meshes[i + 1:]:
                pairs = trees[a.name].overlap(trees[b.name])
                if pairs:
                    hits.setdefault(a.name + '/' + b.name, []).append({'frame': f, 'pairs': len(pairs)})
    return hits, low


s.frame_set(1)
print('REST_BODY_MIN_Y', round(min((meshes[0].matrix_world @ v.co).y for v in meshes[0].data.vertices), 4))
stagger_hits, stagger_low = check_frames(range(1, STAGGER_END + 1))
print('STAGGER_CHECK', json.dumps({'collisions': stagger_hits, 'below_ground': stagger_low}))
assert not stagger_hits and not stagger_low, 'stagger pose interpenetrates; adjust keys before simulating'

# ── 3. Rigid-body fall from the stagger end pose ──
s.frame_set(STAGGER_END)
dg = bpy.context.evaluated_depsgraph_get()
W_mesh = {m.name: m.matrix_world.copy() for m in meshes}
W_piv = {p.name: p.matrix_world.copy() for p in pivots}
H_end = hover.matrix_world.copy()

if s.rigidbody_world is None:
    bpy.ops.rigidbody.world_add()
rbw = s.rigidbody_world
s.use_gravity = True
s.gravity = (0.0, -9.81, 0.0)
rbw.substeps_per_frame = 20
rbw.solver_iterations = 40
rbw.point_cache.frame_start = STAGGER_END
rbw.point_cache.frame_end = SIM_END
sim_col = bpy.data.collections.new('DeathSim')
s.collection.children.link(sim_col)
if rbw.collection is None:
    rbw.collection = bpy.data.collections.new('RigidBodyWorld')


def add_body(obj, kind, shape, mass=1.0, friction=.8, bounce=.2, lin_damp=.15, ang_damp=.35, margin=.002):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.rigidbody.object_add(type=kind)
    rb = obj.rigid_body
    rb.collision_shape = shape
    rb.mass = mass
    rb.friction = friction
    rb.restitution = bounce
    rb.use_margin = True
    rb.collision_margin = margin
    rb.linear_damping = lin_damp
    rb.angular_damping = ang_damp
    # Slow parts fall asleep instead of jittering on contact.
    rb.use_deactivation = kind == 'ACTIVE'
    rb.deactivate_linear_velocity = .08
    rb.deactivate_angular_velocity = .3


# BOX shapes are centered on the object origin, so the slab's origin is its center.
ground_me = bpy.data.meshes.new('DeathGround')
ground_me.from_pydata([(x, y, z) for y in (.5, -.5) for x, z in ((-6, -6), (6, -6), (6, 6), (-6, 6))], [],
                      [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
ground = bpy.data.objects.new('DeathGround', ground_me)
ground.location = (0, GROUND_Y - .5, 0)
sim_col.objects.link(ground)
add_body(ground, 'PASSIVE', 'BOX', friction=.9, bounce=.3)

proxies, centers = {}, {}
for m in meshes:
    me = m.data.copy()
    me.name = m.name + '_SimMesh'
    c = sum((v.co for v in me.vertices), Vector()) / len(me.vertices)
    me.transform(Matrix.Translation(-c))
    p = bpy.data.objects.new(m.name + '_Sim', me)
    sim_col.objects.link(p)
    p.matrix_world = W_mesh[m.name] @ Matrix.Translation(c)
    centers[m.name] = c
    proxies[m.name] = p
    m.hide_render = False
# Heavy damping keeps the wreck on its tile and lets the ring stop rattling quickly.
add_body(proxies['Body'], 'ACTIVE', 'CONVEX_HULL', mass=3.0, friction=1.0, bounce=.12, lin_damp=.35, ang_damp=.7)
# The mesh-shape margin keeps the thin ring band from sinking into the slab.
add_body(proxies['Ring'], 'ACTIVE', 'MESH', mass=1.2, friction=1.0, bounce=.15, lin_damp=.3, ang_damp=.8, margin=.012)
for n in PARTS[2:]:
    add_body(proxies[n], 'ACTIVE', 'CONVEX_HULL', mass=.3, friction=.9, bounce=.3, lin_damp=.25, ang_damp=.5)
# The fall starts at rest; the stagger's final lean decides the toppling side.
sim = {n: {} for n in PARTS}


def bake(start, end):
    # Step forward from the cache start so Bullet initializes from current transforms.
    rbw.point_cache.frame_start = start
    rbw.point_cache.frame_end = end
    s.frame_set(start - 1)
    for f in range(start, end + 1):
        s.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        for n in PARTS:
            sim[n][f] = proxies[n].evaluated_get(dg).matrix_world.copy() @ Matrix.Translation(-centers[n])


# Stage 1: free fall, topple and first impacts.
SETTLE_FROM = 36
bake(STAGGER_END, SETTLE_FROM)
# Stage 2: restart from the impact pose with heavy damping, so the wreck slumps
# into rest within a few frames instead of rocking for seconds.
for n, p in proxies.items():
    p.matrix_world = sim[n][SETTLE_FROM] @ Matrix.Translation(centers[n])
    rb = p.rigid_body
    rb.linear_damping, rb.angular_damping, rb.restitution = .7, .93, .05
bake(SETTLE_FROM, SIM_END)

# GImpact mesh contacts let the ring dip ~1.5 cm; lift that frame's ring to the surface.
ring_verts = [v.co.copy() for v in meshes[1].data.vertices]
ring_lift = {}
for f, M in sim['Ring'].items():
    lo = min((M @ v).y for v in ring_verts)
    if lo < GROUND_Y:
        ring_lift[f] = GROUND_Y - lo
        sim['Ring'][f] = Matrix.Translation((0, GROUND_Y - lo, 0)) @ M

# Settle: keep the real fall and first impacts, then ease from the live simulation into
# the fully settled rest pose (last simulated frame). Rocking/contact jitter never shows.
def motion(a, b):
    return (a.translation - b.translation).length, a.to_quaternion().rotation_difference(b.to_quaternion()).angle


SETTLE_BLEND = 12
DEATH_END = SETTLE_FROM + SETTLE_BLEND
# Rest pose: the quietest late frame (GImpact contacts may keep sub-mm jitter).
REST_FRAME = min(range(SIM_END - 40, SIM_END), key=lambda f: max(motion(sim[n][f], sim[n][f + 1])[0] for n in PARTS))
rest_motion = max(motion(sim[n][REST_FRAME], sim[n][REST_FRAME + 1])[0] for n in PARTS)
assert rest_motion < 5e-3, f'simulation not at rest by frame {SIM_END}: {rest_motion}'
for n in PARTS:
    R = sim[n][REST_FRAME]
    for f in range(SETTLE_FROM + 1, DEATH_END + 1):
        u = (f - SETTLE_FROM) / SETTLE_BLEND
        w = u * u * (3 - 2 * u)
        M = sim[n][f]
        loc = M.translation.lerp(R.translation, w)
        q = M.to_quaternion().slerp(R.to_quaternion(), w)
        sim[n][f] = Matrix.Translation(loc) @ q.to_matrix().to_4x4()

# ── 4. Convert simulated mesh world matrices into pivot-local Death keys ──
for i, (m, p) in enumerate(zip(meshes, pivots)):
    C = W_piv[p.name].inverted() @ W_mesh[m.name]
    parent_basis = (H_end @ p.matrix_parent_inverse).inverted()
    prev = None
    for f in range(STAGGER_END + 1, DEATH_END + 1):
        world_pivot = sim[m.name][f] @ C.inverted()
        loc, q, _ = (parent_basis @ world_pivot).decompose()
        if prev is not None and prev.dot(q) < 0:
            q = -q
        prev = q.copy()
        key(p, f, loc, q)
# HoverRoot holds its last stagger pose while parts fall freely.
key(hover, DEATH_END, rest['HoverRoot'][0] + Vector((0, HOVER_KEYS[-1][1], 0)),
    euler_q(HOVER_KEYS[-1][2], HOVER_KEYS[-1][4], HOVER_KEYS[-1][3]) @ rest['HoverRoot'][1])

# Remove simulation helpers from the export/authoring result.
s.frame_set(1)
for p in list(proxies.values()) + [ground]:
    bpy.data.objects.remove(p, do_unlink=True)
bpy.data.collections.remove(sim_col)
bpy.ops.rigidbody.world_remove()

for o in animated:
    ad = o.animation_data
    if ad.action is None:
        continue
    ad.action.name = 'Death_' + o.name
    for fc in [c for layer in ad.action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]:
        for kp in fc.keyframe_points:
            kp.interpolation = 'LINEAR' if kp.co[0] > STAGGER_END else 'BEZIER'
    push_track(o, 'Death')
for o in animated:
    for t in o.animation_data.nla_tracks:
        t.mute = False

# ── 5. Validate Death trajectory: no part interpenetration or ground penetration ──
def eval_death(frame):
    for o in animated:
        for t in o.animation_data.nla_tracks:
            t.mute = t.name != 'Death'
            t.is_solo = False
    s.frame_set(frame)


collisions, below = {}, []
for f in range(1, DEATH_END + 1):
    eval_death(f)
    trees = {}
    for m in meshes:
        verts = [m.matrix_world @ v.co for v in m.data.vertices]
        trees[m.name] = BVHTree.FromPolygons(verts, [list(p.vertices) for p in m.data.polygons], all_triangles=True)
        lo = min(v.y for v in verts)
        if lo < GROUND_Y - .004:
            below.append({'frame': f, 'part': m.name, 'min_y': round(lo, 4)})
    for i, a in enumerate(meshes):
        for b in meshes[i + 1:]:
            pairs = trees[a.name].overlap(trees[b.name])
            if pairs:
                collisions.setdefault(a.name + '/' + b.name, []).append({'frame': f, 'pairs': len(pairs)})
final = {}
eval_death(DEATH_END)
for m in meshes:
    verts = [m.matrix_world @ v.co for v in m.data.vertices]
    final[m.name] = {'min': [round(min(v[k] for v in verts), 4) for k in range(3)], 'max': [round(max(v[k] for v in verts), 4) for k in range(3)]}
for o in animated:
    for t in o.animation_data.nla_tracks:
        t.mute = False

s.frame_start, s.frame_end = 1, 577
s.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(DEST), compress=True)

# ── 6. Export Idle + Death (one glTF animation per NLA track) ──
bpy.ops.object.select_all(action='DESELECT')
for o in [hover] + pivots + meshes + [bpy.data.objects['RuneFront'], bpy.data.objects['RuneBack']]:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', use_selection=True, export_yup=False, export_normals=True,
                          export_tangents=True, export_materials='EXPORT', export_cameras=False, export_lights=False,
                          export_extras=True, export_animations=True, export_animation_mode='NLA_TRACKS',
                          export_force_sampling=True, export_frame_range=False, export_frame_step=1,
                          export_optimize_animation_size=False, export_optimize_animation_keep_anim_object=True)
# Shift each animation's input times so the clip starts at 0 s; outputs and all other bytes stay as exported.
raw = GLB.read_bytes()
length, ctype = struct.unpack_from('<II', raw, 12)
g = json.loads(raw[20:20 + length])
bo = 20 + length
binlength, bintype = struct.unpack_from('<II', raw, bo)
binary = bytearray(raw[bo + 8:bo + 8 + binlength])
assert sorted(a['name'] for a in g['animations']) == ['Death', 'Idle'], [a['name'] for a in g['animations']]
done = set()
for an in g['animations']:
    inputs = sorted({x['input'] for x in an['samplers']})
    spans = []
    for ai in inputs:
        acc = g['accessors'][ai]
        view = g['bufferViews'][acc['bufferView']]
        off = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
        spans.append((ai, off, np.frombuffer(binary, dtype='<f4', count=acc['count'], offset=off).copy()))
    origin = min(float(t[0]) for _, _, t in spans)
    for ai, off, times in spans:
        assert ai not in done
        done.add(ai)
        shifted = (times.astype(np.float64) - origin).astype('<f4')
        binary[off:off + shifted.nbytes] = shifted.tobytes()
        g['accessors'][ai]['min'] = [float(shifted.min())]
        g['accessors'][ai]['max'] = [float(shifted.max())]
# Keep the adopted rest pose: Death keys own BodyPivot's upright rotation, rest stays identity.
for node in g['nodes']:
    if node['name'] == 'BodyPivot':
        node.pop('rotation', None)
j = json.dumps(g, separators=(',', ':')).encode()
j += b' ' * (-len(j) % 4)
tail = struct.pack('<II', len(binary), bintype) + binary
GLB.write_bytes(struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(j) + len(tail)) + struct.pack('<II', len(j), ctype) + j + tail)

report = {
    'source': {'path': str(NATIVE), 'sha256': CONTRACT['native']['sha256']},
    'native': {'path': str(DEST), 'sha256': sha(DEST)},
    'glb': {'path': str(GLB), 'sha256': sha(GLB), 'bytes': GLB.stat().st_size},
    'fps': FPS, 'stagger_end_frame': STAGGER_END, 'impact_frame': SETTLE_FROM, 'death_end_frame': DEATH_END, 'rest_frame': REST_FRAME, 'rest_motion': rest_motion,
    'death_seconds': (DEATH_END - 1) / FPS, 'ground_y': GROUND_Y,
    'collisions': collisions, 'below_ground': below, 'ring_lift_max': max(ring_lift.values(), default=0.0), 'final_bounds': final,
    'animations': {a['name']: [g['accessors'][x['input']]['max'][0] for x in a['samplers']][:1] for a in g['animations']},
}
report['clip'] = {'name': 'Death', 'stagger': 'keyed jolts frames 1-17', 'fall': 'Bullet rigid bodies from frame 17, impact frame 36',
                  'settle': f'ease into simulated rest frame {REST_FRAME} over frames 37-48', 'time_origin_normalization': 'per-animation input shift to 0 s'}
report['idle'] = 'Re-exported from the adopted Idle actions via NLA track; BodyPivot rest rotation kept identity'
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(report, indent=2))
(D / 'asset-contract.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print('DEATH_REPORT', json.dumps(report))
