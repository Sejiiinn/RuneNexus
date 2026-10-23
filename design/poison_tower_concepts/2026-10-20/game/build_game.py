"""Game-distance version of the chosen venom mortar (quality rev5).

Blender -b --factory-startup --python build_game.py
Re-runs the rev5 build with lower circumference / sphere / pipe / bevel tessellation only.
Same profiles, positions, hierarchy and materials; no Decimate. Output: venom-mortar-game.blend
and optimization-manifest.json (triangles, max deviation vs rev5).
"""
import bpy, json, math, hashlib, importlib.util
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent
QUALITY = Path('/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/poison-mortar-quality-20261021')
REV5 = QUALITY / 'asset/source/venom-mortar-quality-rev5.blend'
REV5_SCRIPT = QUALITY / 'scripts/build_quality_variant5.py'
CONTROLS = ['turret_root', 'turret_head', 'turret_barrel', 'muzzle']
BODY = ('01 ', '02 ', '03 ', '04 ', '05 ')

RING = {128: 48, 96: 24, 64: 24, 48: 24, 32: 16, 24: 12, 16: 12}
SPHERE = {64: 24, 48: 16, 24: 8, 12: 8}


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def body_objects(scene):
    return [o for c in scene.collection.children if c.name.startswith(BODY)
            for o in c.all_objects if o.type in ('MESH', 'CURVE') and not o.hide_render]


def tri(o, dg):
    e = o.evaluated_get(dg); m = e.to_mesh(); m.calc_loop_triangles(); n = len(m.loop_triangles); e.to_mesh_clear(); return n


def points(scene):
    """World-space finite vertices, triangles (finite only) and non-finite vertex count."""
    bpy.context.view_layer.update(); dg = bpy.context.evaluated_depsgraph_get(); vs, tris, bad = [], [], 0
    for o in body_objects(scene):
        e = o.evaluated_get(dg); m = e.to_mesh(); m.calc_loop_triangles(); base = len(vs)
        local = [o.matrix_world @ v.co for v in m.vertices]; ok = [all(math.isfinite(c) for c in p) for p in local]
        bad += ok.count(False); vs += local
        tris += [tuple(base + i for i in t.vertices) for t in m.loop_triangles if all(ok[i] for i in t.vertices)]
        e.to_mesh_clear()
    return (vs, tris), bad


def deviation(a, b):
    """Max distance from a's used vertices to b's surface (m)."""
    tree = BVHTree.FromPolygons(b[0], b[1]); used = {i for t in a[1] for i in t}
    return max((a[0][i] - tree.find_nearest(a[0][i])[0]).length for i in used)


def controls(scene):
    return {n: [list(r) for r in scene.objects[n].matrix_world] for n in CONTROLS}


# 1. Reference: rev5 as saved (head yaw neutral).
bpy.ops.wm.open_mainfile(filepath=str(REV5))
s = bpy.context.scene; s.objects['turret_head'].rotation_euler.z = 0
dg = bpy.context.evaluated_depsgraph_get()
rev5_tris = sum(tri(o, dg) for o in body_objects(s))
rev5_points, rev5_nan = points(s); rev5_controls = controls(s)

# 2. Rebuild rev5 with reduced tessellation.
bpy.ops.wm.read_factory_settings(use_empty=True)
spec = importlib.util.spec_from_file_location('venom_rev5', REV5_SCRIPT)
v5 = importlib.util.module_from_spec(spec); spec.loader.exec_module(v5)
b = v5.b
lathe0, cyl0, sphere0, finish0, pipe0, elbow0 = b.lathe, b.cyl, b.sphere, b.finish, b.pipe, b.elbow


POLE_FIXED = []


def lathe(name, prof, n, *a, **kw):
    # rev5 defect: Bevel on a zero-radius pole fan evaluates to NaN vertices (foundation, 3072 verts).
    # A 2 mm pole ring sits under the covering part above, so the bevel stays finite.
    if kw.get('bevel', a[4] if len(a) > 4 else .006) and any(abs(r) < 1e-12 for r, _ in prof):
        prof = [(.002 if abs(r) < 1e-12 else r, h) for r, h in prof]; POLE_FIXED.append(name)
    return lathe0(name, prof, RING.get(n, n), *a, **kw)


def cyl(name, radius, depth, loc, mat, coll, parent=None, n=48, *a, **kw):
    return cyl0(name, radius, depth, loc, mat, coll, parent, RING.get(n, n), *a, **kw)


def sphere(name, radius, loc, mat, coll, parent=None, seg=32):
    return sphere0(name, radius, loc, mat, coll, parent, SPHERE.get(seg, seg))


def finish(o, mat, bevel, smooth_quads=False, segments=3, angle=35):
    return finish0(o, mat, bevel, smooth_quads, 1, angle)


def pipe(name, pts, radius, mat, coll, parent):
    o = pipe0(name, pts, radius, mat, coll, parent); o.data.bevel_resolution = 2; return o


def elbow(a, corner, c, radius, steps=8):
    return elbow0(a, corner, c, radius, max(4, steps // 2))


b.lathe, b.cyl, b.sphere, b.finish, b.pipe, b.elbow = lathe, cyl, sphere, finish, pipe, elbow

# Game model only (2026-10-22/23 requests): venom tank 30% larger than rev5, moved toward the
# turret centre and leaned back 8 degrees so the breech nests into its lower front.
# The head-mounted links (bracket, feed and drain pipes) are rebuilt to reach the moved tank.
TANK_SCALE = 1.3
TANK_Y = .19  # rev5 .218
TANK_TILT = math.radians(-8)  # negative X rotation: top leans away from the barrel
TANK_LINKS = ('Tank breech bracket', 'Upper bronze elbow feed', 'Feed barrel dark coupling',
              'Feed tank dark coupling', 'Lower bronze drain elbow', 'Drain flange')
build_tank0 = v5.build_tank


def build_tank():
    s, o = TANK_SCALE, b.TANK_ORIGIN.copy()
    T = b.TANK_ORIGIN = Vector((o.x, TANK_Y, o.z))
    build_tank0()
    t = bpy.data.objects['venom_tank']; t.scale = (s, s, s); t.rotation_euler.x = TANK_TILT
    tilt = Matrix.Rotation(TANK_TILT, 4, 'X')
    M = Matrix.Translation(T) @ tilt @ Matrix.Diagonal((s, s, s, 1))
    for n in TANK_LINKS: bpy.data.objects.remove(bpy.data.objects[n])
    front, back = o.y - .165, (M @ Vector((0, -.015, 0))).y
    b.cube('Tank breech bracket', (0, (front + back) / 2, T.z + .015), (.105, back - front, .044),
           b.bronze, b.tank_col, b.head, .006)
    start = b.axis_to_head((0, -.035, b.HOUSING * b.SQUASH - .010))
    entry = M @ Vector((0, -.108, .281))
    b.pipe('Upper bronze elbow feed', b.elbow(start, Vector((0, start.y, entry.z)), entry, .033, 12),
           .023, b.bronze, b.tank_col, b.head)
    b.cyl('Feed barrel dark coupling', .034, .027, tuple(start + Vector((0, 0, .008))),
          b.dark, b.tank_col, b.head, 32, bevel=.003)
    c = b.cyl('Feed tank dark coupling', .035, .024, tuple(entry + Vector((0, -.005, 0))),
              b.dark, b.tank_col, b.head, 32, 'Y', .003)
    c.rotation_euler = (tilt.to_3x3() @ c.rotation_euler.to_matrix()).to_euler()
    a = M @ Vector((0, .015, -.01)); low = T.z - .092
    b.pipe('Lower bronze drain elbow', b.elbow(a, Vector((0, a.y, low)), Vector((0, .09, low)), .042, 12),
           .022, b.bronze, b.tank_col, b.head)
    b.cyl('Drain flange', .033, .022, tuple(a), b.dark, b.tank_col, b.head, 32, bevel=.003)


v5.build_tank = build_tank
v5.build_all(save=False)
s = bpy.context.scene; s.objects['turret_head'].rotation_euler.z = 0
dg = bpy.context.evaluated_depsgraph_get()
parts = {o.name: tri(o, dg) for o in body_objects(s)}
low_points, low_nan = points(s); assert low_nan == 0, low_nan; low_controls = controls(s)
control_error = max(abs(rev5_controls[n][i][j] - low_controls[n][i][j]) for n in CONTROLS for i in range(4) for j in range(4))
assert control_error < 1e-6, control_error
manifest = {
    'source_blend': str(REV5), 'source_sha256': sha(REV5), 'source_script_sha256': sha(REV5_SCRIPT),
    'source_triangles': rev5_tris, 'game_triangles': sum(parts.values()),
    'max_deviation_low_to_source_m': deviation(low_points, rev5_points),
    'max_deviation_source_to_low_m': deviation(rev5_points, low_points),
    'max_control_matrix_error': control_error,
    'source_nonfinite_vertices': rev5_nan, 'pole_ring_fixed': POLE_FIXED,
    'tessellation': {'ring_sides': RING, 'sphere_segments': SPHERE, 'bevel_segments': 1,
                     'pipe_bevel_resolution': 2, 'elbow_steps': 'half, min 4'},
    'decimate_used': False, 'tank_scale': TANK_SCALE, 'tank_y': TANK_Y, 'tank_tilt_deg': math.degrees(TANK_TILT), 'parts': dict(sorted(parts.items(), key=lambda kv: -kv[1])),
}
(OUT / 'optimization-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'venom-mortar-game.blend'), compress=True)
print('POISON_GAME', rev5_tris, manifest['game_triangles'], manifest['max_deviation_low_to_source_m'], manifest['max_deviation_source_to_low_m'])
