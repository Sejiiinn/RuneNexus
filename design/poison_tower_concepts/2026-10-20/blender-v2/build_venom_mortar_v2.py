"""Venom mortar v2 (poison turret concept A) — Blender design source rebuilt on the generated 3D reference.
Blender -b --factory-startup --python build_venom_mortar_v2.py [-- --no-render]
Inside a live Blender (MCP): exec the file, then build_all(); load_reference() + ref_compare(dir) score the
silhouettes against the generated reference mesh (front / side / back / top, IoU per view).

Reference: Pixal3D multiview seed 42 raw1024 after Metal layer denoise (external SSD asset
poison-mortar-A-v2-20261021), mapped to Blender axes (x=-raw_x, y=raw_z, z=raw_y), base centred,
base width scaled to .82 (other turrets: .77-.82). The reference supplies proportions only; every part here is
clean hard-surface geometry, split into turret_root / turret_head / turret_barrel for the game's head yaw.
Coordinates: Z up, -Y forward. Helpers and the shared fire-turret metal finish are copied from
../blender/build_venom_mortar.py (v1).
"""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
from pathlib import Path

try:
    OUT = Path(__file__).resolve().parent
except NameError:
    OUT = Path('/Users/sejin/Documents/Codex/RuneNexus/design/poison_tower_concepts/2026-10-20/blender-v2')
REF = OUT.parent / 'A-venom-mortar.png'
FIRE_FINISH = OUT.parents[2] / 'fire_tower_concepts' / 'runic_3d' / 'finish_materials.py'
AI3D = Path('/Volumes/KIOXIA_MAC/AI-3D')
REF_MESH = AI3D / 'projects/ComfySessions/PixalUltraTex/20261020T235251Z-metal-denoise-5c84af22/results/metal/mesh-noise-clean-geometry-clean.npz'
REF_COLLECTION = 'REF | generated reference'

# Proportions: concept A first (silhouette, parts, runes), inside the game budget (footprint .77-.82, height <= .78).
# The generated reference mesh only informed depth and side proportions the concept does not show.
PITCH = math.radians(22)            # mortar elevation (concept A / side views read about 22 degrees)
PIVOT = Vector((0, -.01, .38))      # trunnion / side bearing centre
H_AXIS = .055                       # bore axis above the trunnion, in barrel space
BARREL_R, BARREL_H = .14, .127      # octagonal body half width / half height (long, slimmer barrel as in concept A)
SQUASH = BARREL_H / BARREL_R        # muzzle ring uses the same width:height
HOUSING = .165                      # breech housing half width
MUZZLE_Y, MUZZLE_D = -.44, .1       # muzzle front face (barrel axis space) and ring depth
MUZZLE_R, MUZZLE_RI = .178, .108    # ring corner radii
BREECH_Y = .045                     # short breech so the tank can sit right behind it
BAND_Y = -.105
DIAMOND_Y = -.235                   # barrel side rune centre (diamond channel; its arm ends under the band)
TANK_ORIGIN = Vector((0, .215, .37))
PLINTH_R, PLINTH_TOP = .38, .118    # round plinth radius and top
TIER_R, TIER_TOP = .345, .155       # dark upper tier carrying the A-frame feet
DRUM_R = .23                        # rotating drum
BRACE_X = .24                       # A-frame plate centre (before the wedge taper)
BRACE_T = .045                      # A-frame plate thickness before the taper
BRACE_FOOT = (.19, .29)             # inner / outer face of the A-frame at the foot (front view reads as a wedge)
BRACE_TOP = (.195, .25)             # inner / outer face at the crown
BRACE_FOOT_Y = .13                  # half the foot length along Y (narrow, tall arch)
ARCH_R = .09                        # round crown around the bearing
BRACE_Z = (TIER_TOP, PIVOT.z + ARCH_R)
OPEN_TOP = PIVOT.z - .075           # tip of the pointed opening, just under the bearing ring
LUG_W = .21
HERO_YAW = math.radians(-11)
TANK_LEAN = 0
# ---------------------------------------------------------------- helpers
def collection(name):
    c = bpy.data.collections.new(name); scene.collection.children.link(c); return c

def empty(name, coll, parent=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None); coll.objects.link(o); o.parent = parent; o.location = loc; return o

def finish(o, mat, bevel, smooth_quads=False, segments=3, angle=35):
    if mat: o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new('Machined bevel', 'BEVEL'); b.width = bevel; b.segments = segments
        b.limit_method = 'ANGLE'; b.angle_limit = math.radians(angle)
        w = o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL'); w.keep_sharp = True; w.weight = 40
    if smooth_quads:
        for p in o.data.polygons: p.use_smooth = len(p.vertices) == 4
    return o

def from_bm(name, bm, mat, coll, parent=None, bevel=0, smooth_quads=False, **kw):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = bpy.data.meshes.new(name); bm.to_mesh(m); bm.free()
    o = bpy.data.objects.new(name, m); coll.objects.link(o); o.parent = parent
    return finish(o, mat, bevel, smooth_quads, **kw)

def mesh(name, verts, faces, mat, coll, parent=None, bevel=0, **kw):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces: bm.faces.new([vs[i] for i in f])
    return from_bm(name, bm, mat, coll, parent, bevel, **kw)

def cyl(name, radius, depth, loc, mat, coll, parent=None, n=48, axis='Z', bevel=.006, r2=None, phase=0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=radius, radius2=radius if r2 is None else r2, depth=depth)
    if phase: bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(phase, 3, 'Z'))
    if axis == 'X': bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.pi / 2, 3, 'Y'))
    if axis == 'Y': bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.pi / 2, 3, 'X'))
    o = from_bm(name, bm, mat, coll, parent, bevel, smooth_quads=n > 12); o.location = loc; return o

def sphere(name, radius, loc, mat, coll, parent=None, seg=32):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=radius)
    o = from_bm(name, bm, mat, coll, parent)
    for p in o.data.polygons: p.use_smooth = True
    o.location = loc; return o

def cube(name, loc, dims, mat, coll, parent=None, bevel=.008, rot=None):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=dims, verts=bm.verts)
    o = from_bm(name, bm, mat, coll, parent, bevel); o.location = loc
    if rot: o.rotation_euler = rot
    return o

def _axis(axis, r, a, h):
    x, y = r * math.cos(a), r * math.sin(a)
    return {'Y': (x, h, y), 'Z': (x, y, h), 'X': (h, x, y)}[axis]

def lathe(name, prof, n, mat, coll, parent=None, axis='Y', loc=(0, 0, 0), bevel=.006, phase=0, smooth=None, **kw):
    """Revolve a closed (radius, height) profile loop n times around the local axis."""
    m = len(prof); vs = []
    for i in range(n):
        a = phase + 2 * math.pi * i / n
        vs += [_axis(axis, r, a, h) for r, h in prof]
    fs = []
    for i in range(n):
        j = (i + 1) % n
        for k in range(m):
            l = (k + 1) % m
            fs.append((i * m + k, i * m + l, j * m + l, j * m + k))
    o = mesh(name, vs, fs, mat, coll, parent, bevel, **kw); o.location = loc
    if smooth if smooth is not None else n > 12:
        for p in o.data.polygons: p.use_smooth = True
    return o

def sector(name, prof, a0, a1, mat, coll, parent=None, axis='Y', loc=(0, 0, 0), bevel=.008, **kw):
    """One flat-faced block of a profile swept from angle a0 to a1 (capped both ends)."""
    m = len(prof)
    vs = [_axis(axis, r, a0, h) for r, h in prof] + [_axis(axis, r, a1, h) for r, h in prof]
    fs = [tuple(range(m)), tuple(reversed(range(m, 2 * m)))] + [(k, (k + 1) % m, m + (k + 1) % m, m + k) for k in range(m)]
    o = mesh(name, vs, fs, mat, coll, parent, bevel, **kw); o.location = loc; return o

def ring(name, ro, ri, depth, loc, mat, coll, parent=None, n=48, axis='Z', bevel=.003, phase=0):
    d = depth / 2
    return lathe(name, [(ro, -d), (ro, d), (ri, d), (ri, -d)], n, mat, coll, parent, axis, loc, bevel, phase)

def prism_x(name, pts, thickness, x, mat, coll, parent=None, bevel=.006):
    """Extrude a (y, z) outline along X."""
    n = len(pts); vs = [(xx, y, z) for xx in [x - thickness / 2, x + thickness / 2] for y, z in pts]
    fs = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, vs, fs, mat, coll, parent, bevel)

def plate(name, pts, thick, frame, mat, coll, parent=None, bevel=.006, lift=0):
    """Extrude a 2D outline (in frame u, v) along the frame normal."""
    o_, u, v, nrm = frame; n = len(pts)
    vs = [tuple(o_ + u * x + v * y + nrm * (lift + h)) for h in (0, thick) for x, y in pts]
    fs = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, vs, fs, mat, coll, parent, bevel)

def octo(w, h):
    return [(-w * .42, h), (w * .42, h), (w, h * .42), (w, -h * .42), (w * .42, -h), (-w * .42, -h), (-w, -h * .42), (-w, h * .42)]

def loft(name, sections, mat, coll, parent=None, bevel=.008):
    """Eight-sided section loft along Y; each section is (y, half width, half height)."""
    vs = []
    for y, w, h in sections:
        vs += [(x, y, z) for x, z in octo(w, h)]
    fs = [tuple(reversed(range(8))), tuple(range(len(vs) - 8, len(vs)))]
    for k in range(len(sections) - 1):
        for j in range(8): fs.append((k * 8 + j, k * 8 + (j + 1) % 8, (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
    return mesh(name, vs, fs, mat, coll, parent, bevel)

def ribbon(name, pts, width, depth, frame, mat, coll, parent=None, closed=True, lift=0.0, bevel=0):
    """Mitered strip along a 2D polyline placed on a face frame (origin, u, v, normal)."""
    o_, u, v, nrm = frame; P = [Vector(p) for p in pts]; k = len(P)
    def left(d): return Vector((-d.y, d.x))
    offs = []
    for i in range(k):
        if closed or 0 < i < k - 1:
            d0 = (P[i] - P[i - 1]).normalized(); d1 = (P[(i + 1) % k] - P[i]).normalized()
            n0, n1 = left(d0), left(d1); m = (n0 + n1); m = m / max(.25, 1 + n0.dot(n1))
        else:
            d = (P[1] - P[0]).normalized() if i == 0 else (P[-1] - P[-2]).normalized(); m = left(d)
        offs.append(m)
    def to3(p2, h): return o_ + u * p2.x + v * p2.y + nrm * (h + lift)
    vs = []
    for i in range(k):
        for h in [-depth / 2, depth / 2]:
            vs += [to3(P[i] + offs[i] * width / 2, h), to3(P[i] - offs[i] * width / 2, h)]
    fs = []
    segs = k if closed else k - 1
    for i in range(segs):
        a, b = i * 4, ((i + 1) % k) * 4
        fs += [(a, b, b + 2, a + 2), (a + 1, a + 3, b + 3, b + 1), (a, a + 1, b + 1, b), (a + 2, b + 2, b + 3, a + 3)]
    if not closed:
        e = (k - 1) * 4; fs += [(0, 2, 3, 1), (e, e + 1, e + 3, e + 2)]
    o = mesh(name, [tuple(v_) for v_ in vs], fs, mat, coll, parent, bevel)
    if mat is None: o.display_type = 'WIRE'; o.hide_render = True
    return o

def pipe(name, pts, radius, mat, coll, parent):
    curve = bpy.data.curves.new(name, 'CURVE'); curve.dimensions = '3D'
    curve.bevel_depth = radius; curve.bevel_resolution = 4; curve.use_fill_caps = True
    sp = curve.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts): p.co = (*c, 1)
    o = bpy.data.objects.new(name, curve); coll.objects.link(o); o.parent = parent; curve.materials.append(mat)
    return o

def elbow(a, corner, b, radius, steps=8):
    """Polyline a -> corner -> b with the corner rounded by a circular-ish fillet."""
    a, c, b = Vector(a), Vector(corner), Vector(b)
    p0 = c + (a - c).normalized() * radius; p1 = c + (b - c).normalized() * radius
    pts = [a]
    for i in range(steps + 1):
        t = i / steps; pts.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * c + t ** 2 * p1)
    return pts + [b]

def cut(target, cutters_coll):
    b = target.modifiers.new('Rune recesses', 'BOOLEAN'); b.operation = 'DIFFERENCE'
    b.operand_type = 'COLLECTION'; b.collection = cutters_coll; b.solver = 'EXACT'
    for c in cutters_coll.objects: c.display_type = 'WIRE'; c.hide_render = True
    # Cut after the bevel: beveling the boolean result folded the surface back over parts of the grooves
    # (half of a barrel rune disappeared). Grooves stay crisp; weighted normals run last.
    want = 1 if 'Machined bevel' in target.modifiers else 0
    target.modifiers.move(target.modifiers.find(b.name), want)

def gun_to_head(p):
    return PIVOT + Matrix.Rotation(-PITCH, 3, 'X') @ Vector(p)

def tank_to_head(p):
    return TANK_ORIGIN + Matrix.Rotation(-TANK_LEAN, 3, 'X') @ Vector(p)

def side_frame(sign):
    """Vertical side face of the tube; u runs toward the muzzle."""
    return (Vector((sign * BARREL_R, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((sign, 0, 0)))

def lower_frame(sign):
    """Lower diagonal face of the tube; u runs toward the muzzle."""
    r = BARREL_R; hw = r * .42
    a = Vector((sign * r, 0, -hw)); b = Vector((sign * hw, 0, -r))
    t = (b - a).normalized(); n = Vector((sign * abs(t.z), 0, -abs(t.x)))
    return ((a + b) / 2, Vector((0, -1, 0)), t, n)

# ---------------------------------------------------------------- materials
def node_mat(name):
    m = bpy.data.materials.new(name)
    try: m.use_nodes = True
    except Exception: pass
    return m, m.node_tree.nodes, m.node_tree.links, next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')

def plain_metal(name, col, metallic, rough):
    """Placeholder; the shared forged-metal finish replaces the node tree (see apply_metal_finish)."""
    m, ns, lk, p = node_mat(name)
    p.inputs['Base Color'].default_value = (*col, 1); p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = rough; return m

def emissive(name, col, strength, rough=.35):
    m, ns, lk, p = node_mat(name)
    p.inputs['Base Color'].default_value = (*col, 1); p.inputs['Emission Color'].default_value = (*col, 1)
    p.inputs['Emission Strength'].default_value = strength; p.inputs['Roughness'].default_value = rough; return m

def glass(name):
    m, ns, lk, p = node_mat(name)
    p.inputs['Base Color'].default_value = (.9, 1, .93, 1); p.inputs['Roughness'].default_value = .03
    # Low IOR approximates a thin wall; full 1.45 turned the air gap into dark, blotchy reflections.
    p.inputs['Transmission Weight'].default_value = 1; p.inputs['IOR'].default_value = 1.08
    p.inputs['Coat Weight'].default_value = .3; p.inputs['Coat Roughness'].default_value = .04
    try: m.surface_render_method = 'BLENDED'
    except Exception: pass
    return m

def venom(name, strength, base=(.20, .80, .02)):
    """Glossy translucent venom: lime body, inner glow, clear coat."""
    m, ns, lk, p = node_mat(name)
    p.inputs['Base Color'].default_value = (*base, 1); p.inputs['Roughness'].default_value = .1
    p.inputs['Subsurface Weight'].default_value = .5; p.inputs['Subsurface Radius'].default_value = (.4, 1, .1)
    p.inputs['Transmission Weight'].default_value = .35
    p.inputs['Coat Weight'].default_value = 1; p.inputs['Coat Roughness'].default_value = .03
    p.inputs['Emission Color'].default_value = (.32, 1, .03, 1); p.inputs['Emission Strength'].default_value = strength
    return m

def apply_metal_finish():
    """Reuse the approved rune flame turret forged-metal shader so both turrets share one material language."""
    ns = {}; exec(compile(FIRE_FINISH.read_text(), str(FIRE_FINISH), 'exec'), ns)
    # Concept A bronze reads slightly more copper than the flame turret; keep the same structure.
    ns['PROFILES']['Bronze | worn warm alloy'].update({
        'low': (.33, .148, .052, 1), 'high': (.58, .29, .12, 1), 'wear': (.78, .47, .25, 1), 'rough': (.4, .55)})
    return ns['apply_material_finish'](scene)


# ---------------------------------------------------------------- v2 parts (dimensions read from the generated reference)
def setup():
    global scene, base_col, head_col, gun_col, tank_col, fx_col, studio_col, cut_brace, cut_barrel, cut_base
    global root, head, gun, axis, iron, bronze, dark, edge, rune, glass_m, liquid, bubble, glob, glob_core
    scene = bpy.context.scene; scene.name = 'Venom Mortar v2 — Design'
    for o in list(bpy.data.objects):
        if not o.name.startswith('REF |'): bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        if c.name != REF_COLLECTION: bpy.data.collections.remove(c)
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for d in list(block):
            if d.users == 0: block.remove(d)
    base_col = collection('01 Fixed Base'); head_col = collection('02 Rotating Carriage')
    gun_col = collection('03 Mortar Barrel'); tank_col = collection('04 Venom Tank'); fx_col = collection('05 Venom Glob')
    studio_col = collection('90 Studio')
    cutters = collection('99 Recess Cutters'); cutters.hide_render = True
    cut_brace = bpy.data.collections.new('cutters | brace'); cutters.children.link(cut_brace)
    cut_barrel = bpy.data.collections.new('cutters | barrel'); cutters.children.link(cut_barrel)
    cut_base = bpy.data.collections.new('cutters | base'); cutters.children.link(cut_base)
    root = empty('turret_root', base_col); head = empty('turret_head', head_col, root)
    gun = empty('turret_barrel', gun_col, head, PIVOT); gun.rotation_euler.x = -PITCH
    axis = empty('barrel_axis', gun_col, gun, (0, 0, H_AXIS))      # bore axis sits above the trunnion
    iron = plain_metal('Iron | forged charcoal', (.06, .066, .078), .8, .52)
    bronze = plain_metal('Bronze | worn warm alloy', (.5, .26, .1), .78, .45)
    dark = plain_metal('Recess | dark gunmetal', (.015, .02, .026), .67, .5)
    edge = plain_metal('Steel | polished bevel detail', (.12, .14, .16), .88, .3)
    rune = emissive('Runes | venom lime', (.2, 1, .02), 3.2)
    glass_m = glass('Glass | tank wall')
    liquid = venom('Venom | tank liquid', 1.1)
    bubble = emissive('Venom | bubbles', (.7, 1, .35), 1.6, .08)
    glob = venom('Venom | muzzle glob', 1.6, (.22, .85, .03))
    glob_core = emissive('Venom | glob core', (.35, 1, .05), 4)

def axis_to_head(p):
    return PIVOT + Matrix.Rotation(-PITCH, 3, 'X') @ (Vector(p) + Vector((0, 0, H_AXIS)))

def build_base():
    # Round plinth (concept A): near-vertical wall with a rounded top chamfer and 16 seams, a wide dark upper tier
    # that carries the A-frame feet, and four upright bronze buttress lugs on the diagonals standing proud of the wall.
    plinth = lathe('Foundation armor ring', [(0, 0), (PLINTH_R, 0), (PLINTH_R, .095), (PLINTH_R - .01, .112), (PLINTH_R - .025, PLINTH_TOP), (0, PLINTH_TOP)],
                   64, iron, base_col, root, 'Z', bevel=.006, smooth=True)
    for i in range(16):
        a = i * math.pi / 8 + math.pi / 16
        cube('Plinth seam cutter %02d' % i, (PLINTH_R * math.cos(a), PLINTH_R * math.sin(a), .06), (.03, .007, .2), None, cut_base, root, 0, (0, 0, a))
    cut(plinth, cut_base)
    lathe('Foundation dark upper tier', [(0, PLINTH_TOP - .005), (TIER_R, PLINTH_TOP - .005), (TIER_R, TIER_TOP - .008), (TIER_R - .008, TIER_TOP), (0, TIER_TOP)],
          64, dark, base_col, root, 'Z', bevel=.004, smooth=True)
    # Buttress: inner face outside the head's sweep (A-frame feet reach r .32), outer face upright, faceted cap.
    lug = [(-.345, 0), (-.44, 0), (-.44, .12), (-.425, .162), (-.39, .18), (-.348, .175)]
    for i in range(4):
        o = prism_x('Foundation bronze lug %02d' % i, lug, LUG_W, 0, bronze, base_col, root, .012)
        for v in o.data.vertices:                      # cap a little narrower than the foot
            v.co.x *= 1 - .13 * max(0, v.co.z - .11) / .07
        o.rotation_euler.z = math.pi / 4 + i * math.pi / 2

def build_carriage():
    # Rotating drum with a tall bronze crown, stepped dark rings and the front boss (head space).
    z0 = TIER_TOP
    cyl('Turntable drum', DRUM_R, .085, (0, 0, z0 + .0425), iron, head_col, head, 48, bevel=.012)
    ring('Turntable bronze crown', DRUM_R + .006, DRUM_R - .045, .03, (0, 0, z0 + .085 + .015), bronze, head_col, head, 48, bevel=.006)
    cyl('Turntable dark step', DRUM_R - .05, .02, (0, 0, z0 + .085 + .03 + .01), dark, head_col, head, 48, bevel=.005)
    cyl('Turntable neck', .12, .05, (0, 0, z0 + .085 + .03 + .02 + .025), dark, head_col, head, 32, bevel=.006)
    cyl('Drum front boss', .028, .03, (0, -DRUM_R - .008, z0 + .045), bronze, head_col, head, 24, 'Y', .008)

def build_braces():
    # Concept A: narrow bronze Λ-arches. Legs from the dark tier up to a round crown wrapping the trunnion bearing;
    # a pointed opening under the bearing holds a recessed dark panel with a solid diamond over a double chevron.
    pc = Vector((PIVOT.y, PIVOT.z)); z0, z1 = BRACE_Z
    arc = [(pc.x + ARCH_R * math.cos(a), pc.y + ARCH_R * math.sin(a)) for a in [math.radians(d) for d in range(-25, 206, 15)]]
    outer = [(BRACE_FOOT_Y, z0)] + arc + [(-BRACE_FOOT_Y + 2 * pc.x, z0)]
    hole = [(-.075 + pc.x, z0 - .02), (.075 + pc.x, z0 - .02), (.07 + pc.x, OPEN_TOP - .06), (pc.x, OPEN_TOP), (-.07 + pc.x, OPEN_TOP - .06)]
    panel = [(-.085 + pc.x, z0), (.085 + pc.x, z0), (.08 + pc.x, OPEN_TOP - .055), (pc.x, OPEN_TOP + .012), (-.08 + pc.x, OPEN_TOP - .055)]
    def faces(z):                                  # inner / outer face x at height z (front view reads as a wedge)
        t = min(1, max(0, (z - z0) / (z1 - z0)))
        return [a + (b - a) * t for a, b in zip(BRACE_FOOT, BRACE_TOP)]
    lean = math.atan2(BRACE_FOOT[1] - BRACE_TOP[1], z1 - z0)
    for sign in [-1, 1]:
        x = sign * BRACE_X; side = 'Right' if sign > 0 else 'Left'
        frame = prism_x(side + ' bronze A-frame', outer, BRACE_T, x, bronze, head_col, head, .01)
        cutter = prism_x(side + ' A-frame opening cutter', hole, .2, x, None, cut_brace, head, 0); cutter.display_type = 'WIRE'
        pnl = prism_x(side + ' A-frame dark rune panel', panel, .03, x - sign * .012, dark, head_col, head, .004)
        for o in (frame, cutter, pnl):
            for v in o.data.vertices:
                u = sign * (v.co.x - x) / BRACE_T + .5; xi, xo = faces(v.co.z)
                v.co.x = sign * (xi + u * (xo - xi))
        def at(z): xi, xo = faces(z); return sign * (xi + .58 * (xo - xi))
        def fr(z): return (Vector((at(z), 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((sign, 0, 0)))
        cy = pc.x; zt = OPEN_TOP
        dia = [(cy, zt - .02), (cy + .021, zt - .041), (cy, zt - .062), (cy - .021, zt - .041)]
        plate(side + ' brace rune diamond', dia, .008, fr(zt - .041), rune, head_col, head, 0, lift=-.004)
        for k, (w, zc) in enumerate([(.058, zt - .088), (.064, zt - .124)]):
            ribbon(side + ' brace rune chevron %d' % k, [(cy - w, zc + .012), (cy, zc - .014), (cy + w, zc + .012)], .022, .008,
                   fr(zc), rune, head_col, head, closed=False, lift=0)
        # Round trunnion bearing on the leaning outer face of the crown.
        xo = faces(PIVOT.z)[1]; n = Vector((sign * math.cos(lean), 0, math.sin(lean)))
        base = Vector((sign * xo, PIVOT.y, PIVOT.z))
        cyl(side + ' trunnion stub', .05, .12, (sign * (xo - .06), PIVOT.y, PIVOT.z), iron, head_col, head, 16, 'X', .004)
        for nm, r_, d_, off, mat_, bev in [(' bearing dark ring', .066, .028, .012, dark, .008), (' bearing bronze cap', .045, .036, .03, bronze, .01),
                                          (' bearing pin hole', .016, .014, .049, dark, .003)]:
            o = cyl(side + nm, r_, d_, tuple(base + n * off), mat_, head_col, head, 32, 'X', bev)
            o.rotation_euler.y = -sign * lean
    for o in [o for o in head_col.objects if o.name.endswith('A-frame')]:
        cut(o, cut_brace)

def build_barrel():
    global body
    r, rh = BARREL_R, BARREL_H; hs, hh = HOUSING, HOUSING * SQUASH
    # One continuous octagonal body from the muzzle shoulder to the breech housing (local -Y = muzzle).
    y_front, y_house0, y_house1, y_end = MUZZLE_Y + MUZZLE_D, -.075, -.045, BREECH_Y
    body = loft('Octagonal mortar body', [(y_front, r, rh), (y_house0, r, rh), (y_house1, hs, hh), (y_end - .025, hs, hh), (y_end, hs * .84, hh * .84)],
                iron, gun_col, axis, .012)
    cyl('Breech dark cap', .1, .02, (0, y_end + .008, 0), dark, gun_col, axis, 8, 'Y', .006, phase=math.pi / 8)
    # Seam line just behind the muzzle ring (clear of the side rune).
    ring('Barrel seam cutter', r * 1.3, r * .975 / math.cos(math.pi / 8), .006, (0, y_front + .009, 0), None, cut_barrel, axis, 8, 'Y', 0, math.pi / 8)
    # Bronze band standing proud on every face (octagon with the body's own width:height).
    b0, b1, p = BAND_Y - .028, BAND_Y + .028, .017
    loft('Barrel bronze band', [(b0, r + .006, rh + .006), (b0 + .008, r + p, rh + p), (b1 - .008, r + p, rh + p), (b1, r + .006, rh + .006)],
         bronze, gun_col, axis, .005)
    # Muzzle: eight bronze blocks flaring forward; the rear edge starts at the body's corner radius (no step).
    rv = r * 1.084
    R, ri, y0, y1 = MUZZLE_R, MUZZLE_RI, MUZZLE_D / 2, -MUZZLE_D / 2
    prof = [(ri, y0), (rv, y0), (R * .93, y0 - .025), (R, y1 + .02), (R - .018, y1), (ri + .014, y1), (ri, y1 + .014)]
    ringp = empty('muzzle_ring', gun_col, axis); ringp.scale.z = SQUASH      # same width:height as the body
    for i in range(8):
        a0 = math.pi / 8 + i * math.pi / 4
        sector('Muzzle bronze block %d' % i, prof, a0 + .004, a0 + math.pi / 4 - .004, bronze, gun_col, ringp, 'Y',
               (0, MUZZLE_Y + MUZZLE_D / 2, 0), bevel=.005, angle=30)
    mc = MUZZLE_Y + MUZZLE_D / 2
    ring('Muzzle dark backing ring', R * .9, ri * .95, MUZZLE_D * .8, (0, mc + .005, 0), dark, gun_col, ringp, 8, 'Y', .004, math.pi / 8)
    ring('Muzzle dark inner lip', ri * .99, ri * .8, .03, (0, MUZZLE_Y + .02, 0), dark, gun_col, ringp, 8, 'Y', .005, math.pi / 8)
    ring('Muzzle dark sleeve', ri * .9, ri * .8, .14, (0, mc + .04, 0), dark, gun_col, ringp, 8, 'Y', .002, math.pi / 8)
    cyl('Muzzle dark throat', ri * .85, .01, (0, mc + .105, 0), dark, gun_col, ringp, 8, 'Y', .001, phase=math.pi / 8)
    lo = -.42 * rh; L = math.hypot(.58 * r, .58 * rh)
    for sign in [-1, 1]:
        fr = side_frame(sign); fl = lower_frame(sign)
        # Concept A side rune: a recessed glowing diamond channel around a raised dark island; the rear corner runs on
        # as an arm to the band. u = toward the muzzle, v = up.
        c, cv, hu, hv, arm = -DIAMOND_Y, .004, .042, .044, .012
        ju = c - hu * (1 - arm / hv)
        outer = [(c + hu, cv), (c, cv + hv), (ju, cv + arm), (c - .1, cv + arm), (c - .1, cv - arm), (ju, cv - arm), (c, cv - hv)]
        island = [(c + .022, cv), (c, cv + .024), (c - .022, cv), (c, cv - .024)]
        plate('Barrel diamond rune cutter', outer, .03, fr, None, cut_barrel, axis, 0, lift=-.012)
        plate('Barrel diamond rune glow', outer, .004, fr, rune, gun_col, axis, 0, lift=-.012)
        plate('Barrel diamond rune island', island, .012, fr, iron, gun_col, axis, .003, lift=-.012)
        # Bronze cradle (concept A): a long thick plate holding the lower barrel from the breech housing forward,
        # its top edge running just under the side rune, front end cut back at an angle.
        plate('Barrel bronze cradle side', [(.07, lo), (.07, .036), (.095, .036), (.12, -.043), (.27, -.043), (.285, lo)], .025, fr, bronze, gun_col, axis, .007)
        plate('Barrel bronze cradle bevel', [(.07, -L / 2), (.285, -L / 2), (.293, 0), (.28, L / 2), (.07, L / 2)], .025, fl, bronze, gun_col, axis, .007)
        # Lower rune: a short recessed slot on the lower bevel just ahead of the cradle.
        slot = [(.3, -.022), (.328, -.022), (.328, .022), (.3, .022)]
        plate('Barrel lower rune cutter', slot, .03, fl, None, cut_barrel, axis, 0, lift=-.01)
        plate('Barrel lower rune glow', slot, .004, fl, rune, gun_col, axis, 0, lift=-.01)
    bottom = (Vector((0, 0, -rh)), Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, -1)))
    plate('Barrel bronze cradle bottom', [(.07, -.42 * r), (.28, -.42 * r), (.28, .42 * r), (.07, .42 * r)], .025, bottom, bronze, gun_col, axis, .007)
    ribbon('Barrel bottom rune cutter', [(-mc - .07, -.03), (-mc - .07, .03)], .016, .02, bottom, None, cut_barrel, axis, closed=False)
    ribbon('Barrel bottom rune glow', [(-mc - .07, -.03), (-mc - .07, .03)], .012, .004, bottom, rune, gun_col, axis, closed=False, lift=-.005)
    cut(body, cut_barrel)
    empty('muzzle', gun_col, axis, (0, MUZZLE_Y - .05, 0))

def build_tank():
    # Slender glass reservoir right behind the breech (concept A): wide riveted bronze collar, glass about 60% full,
    # flat bronze straps on the diagonals running over the rim to the knob. Held by a bracket off the breech and the
    # lower pipe that drops from its base into the barrel underside.
    t = empty('venom_tank', tank_col, head, TANK_ORIGIN)
    lathe('Tank bronze base collar', [(.08, 0), (.105, 0), (.11, .01), (.11, .042), (.105, .052), (.08, .052)], 48, bronze, tank_col, t, 'Z', bevel=.004)
    cyl('Tank dark base plate', .095, .016, (0, 0, -.006), dark, tank_col, t, 48, bevel=.004)
    ring('Tank glass wall', .092, .086, .26, (0, 0, .18), glass_m, tank_col, t, 48, bevel=0)
    lq = lathe('Tank venom liquid', [(0, .052), (.0855, .052), (.0855, .2), (0, .2)], 48, liquid, tank_col, t, 'Z', bevel=0)
    for p_ in lq.data.polygons: p_.use_smooth = abs(p_.normal.z) < .5      # flat liquid surface, smooth wall
    rng = random.Random(7)
    for i in range(14):
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(.02, .07)
        sphere('Tank bubble %02d' % i, rng.uniform(.005, .012), (rr * math.cos(a), rr * math.sin(a), rng.uniform(.07, .18)), bubble, tank_col, t, 12)
    lathe('Tank top bronze rim', [(.08, .305), (.105, .305), (.11, .313), (.11, .327), (.105, .335), (.08, .335)], 48, bronze, tank_col, t, 'Z', bevel=.004)
    cyl('Tank top dark cap', .1, .02, (0, 0, .345), dark, tank_col, t, 48, bevel=.006)
    cyl('Tank top bronze knob', .04, .04, (0, 0, .375), bronze, tank_col, t, 8, bevel=.009, phase=math.pi / 8)
    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        d = Vector((math.cos(ang), math.sin(ang), 0)); tg = Vector((-math.sin(ang), math.cos(ang), 0))
        rs, w, th = .11, .034, .012
        plate('Tank strap %d' % k, [(-w / 2, .0), (w / 2, .0), (w / 2, .367), (-w / 2, .367)], th, (d * rs, tg, Vector((0, 0, 1)), d), bronze, tank_col, t, .003)
        plate('Tank strap top %d' % k, [(.03, -w / 2), (rs + th, -w / 2), (rs + th, w / 2), (.03, w / 2)], th, (Vector((0, 0, .355)), d, tg, Vector((0, 0, 1))),
              bronze, tank_col, t, .003)
        for z in [.026, .32]:
            p = d * (rs + th)
            o = cyl('Strap rivet', .008, .008, (p.x, p.y, z), dark, tank_col, t, 12, 'X', .002); o.rotation_euler.z = ang
    # Bracket from the collar front onto the breech end (hidden mostly under the tank).
    cube('Tank breech bracket', (0, TANK_ORIGIN.y - .1, TANK_ORIGIN.z + .022), (.09, .14, .045), bronze, tank_col, head, .008)
    # Feed pipe: rises from the barrel top and turns straight back into the upper glass.
    start = axis_to_head((0, -.04, HOUSING * SQUASH - .012))
    top = TANK_ORIGIN.z + .27; entry = Vector((0, TANK_ORIGIN.y - .09, top))
    pipe('Feed pipe', elbow(start, Vector((0, start.y, top)), entry, .03), .022, bronze, tank_col, head)
    cyl('Pipe barrel collar', .034, .028, tuple(start + Vector((0, 0, .01))), dark, tank_col, head, 24, bevel=.004)
    cyl('Pipe tank flange', .034, .02, tuple(entry + Vector((0, -.003, 0))), dark, tank_col, head, 24, 'Y', .004)
    # Lower pipe: drops from the tank base and bends forward into the barrel underside behind the bearing.
    a = Vector((0, TANK_ORIGIN.y + .01, TANK_ORIGIN.z - .01)); low = TANK_ORIGIN.z - .085
    b = Vector((0, .09, low))
    pipe('Lower drain pipe', elbow(a, Vector((0, a.y, low)), b, .04), .022, bronze, tank_col, head)
    cyl('Drain tank flange', .034, .018, tuple(a + Vector((0, 0, .004))), dark, tank_col, head, 24, bevel=.004)

def build_glob():
    mc = MUZZLE_Y + MUZZLE_D / 2
    g = sphere('Venom glob', MUZZLE_RI * .9, (0, mc + .03, 0), glob, fx_col, axis, 48); g.scale = (1, .7, SQUASH)
    sphere('Venom glob inner glow', MUZZLE_RI * .45, (0, mc + .035, 0), glob_core, fx_col, axis, 24)
    rng = random.Random(3)
    for i in range(5):
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(.015, MUZZLE_RI * .6)
        sphere('Glob bubble %02d' % i, rng.uniform(.005, .01), (rr * math.cos(a), mc - .025 - rng.uniform(0, .01), rr * math.sin(a)), bubble, fx_col, axis, 12)

def side_frame(sign):
    return (Vector((sign * BARREL_R, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((sign, 0, 0)))

def lower_frame(sign):
    r, rh = BARREL_R, BARREL_H
    a = Vector((sign * r, 0, -.42 * rh)); b = Vector((sign * .42 * r, 0, -rh))
    t = (b - a).normalized(); n = Vector((sign * abs(t.z), 0, -abs(t.x)))
    return ((a + b) / 2, Vector((0, -1, 0)), t, n)

# ---------------------------------------------------------------- studio, cameras
def studio():
    scene.render.engine = 'CYCLES'; scene.cycles.samples = 128; scene.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences; prefs.compute_device_type = 'METAL'; prefs.get_devices()
        for d in prefs.devices: d.use = True
        scene.cycles.device = 'GPU'
    except Exception as e: print('GPU unavailable, CPU render:', e)
    scene.render.resolution_x = scene.render.resolution_y = 1200
    w = bpy.data.worlds.new('Muted studio atmosphere'); scene.world = w
    try: w.use_nodes = True
    except Exception: pass
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND'); bg.inputs[0].default_value = (.12, .16, .18, 1); bg.inputs[1].default_value = .4
    gm, ns, lk, p = node_mat('Studio | desaturated forest')
    p.inputs['Base Color'].default_value = (.020, .050, .039, 1); p.inputs['Roughness'].default_value = .92
    cube('Studio floor', (0, 0, -.011), (200, 200, .02), gm, studio_col, None, 0)
    def light(name, pos, power, size, col):
        d = bpy.data.lights.new(name, 'AREA'); d.energy = power; d.shape = 'DISK'; d.size = size; d.color = col
        o = bpy.data.objects.new(name, d); studio_col.objects.link(o); o.location = pos
        o.rotation_euler = (Vector((0, 0, .35)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    light('Large warm key', (-2, -3, 4), 350, 3, (1, .91, .8))
    light('Soft neutral fill', (3, -1, 2.5), 220, 2.8, (.72, .83, 1))
    light('Bronze rim', (.2, 3, 3), 160, 2, (1, .85, .70))
    d = bpy.data.cameras.new('Camera'); cam = bpy.data.objects.new('Camera', d); studio_col.objects.link(cam)
    d.type = 'ORTHO'; scene.camera = cam
    scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'; scene.view_settings.exposure = -.35
    scene.render.image_settings.file_format = 'PNG'
    if 'REFERENCE — approved concept A' not in bpy.data.images:
        img = bpy.data.images.load(str(REF), check_existing=True); img.name = 'REFERENCE — approved concept A'; img.pack(); img.use_fake_user = True
    note = bpy.data.texts.get('START HERE — 독액 박격포 v2') or bpy.data.texts.new('START HERE — 독액 박격포 v2')
    note.clear()
    note.write('독 포탑 A안(독액 박격포) v2 Blender 디자인 원본. 게임 이관 없음.\n'
               'Pixal3D 멀티뷰 생성 메시(seed 42, 1024, 층상 제거)를 비율 기준으로 삼아 깔끔한 하드서피스로 다시 만들었다.\n'
               '01 Fixed Base / 02 Rotating Carriage(turret_head) / 03 Mortar Barrel(turret_barrel) / 04 Venom Tank / 05 Venom Glob.\n'
               '좌표 Z 위, -Y 전방, 받침 폭 .82. 포신 고정 앙각 14도.\n'
               '기준 메시 비교: build_venom_mortar_v2.py의 load_reference() 후 ref_compare(폴더).\n'
               '금속 재질은 화염 포탑 finish_materials.py의 단조 마감을 공유한다(청동만 약간 구리 쪽).\n')

VIEWS = {
    # loc, target, ortho scale (or lens mm with 'PERSP'), head yaw[, projection]
    'hero': ((1.62, -1.62, 1.08), (-.02, -.02, .32), 62, HERO_YAW, 'PERSP'),
    'rear': ((-2.8, 2.9, 2.3), (0, .0, .36), 1.38, HERO_YAW),
    'game': ((0, -2.6, 4.2), (0, .04, .36), 1.25, 0),
    'front': ((0, -4, .4), (0, 0, .4), 1.0, 0),
    'side': ((4, 0, .4), (0, 0, .4), 1.0, 0),
}

def camera(view, res=1200, path=None):
    loc, target, scale, yaw, *proj = VIEWS[view]; cam = scene.camera
    cam.location = loc; cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if proj and proj[0] == 'PERSP':
        cam.data.type = 'PERSP'; cam.data.lens = scale; cam.data.sensor_fit = 'HORIZONTAL'; cam.data.sensor_width = 36
    else:
        cam.data.type = 'ORTHO'; cam.data.ortho_scale = scale
    scene.objects['turret_head'].rotation_euler.z = yaw
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.filepath = str(path or OUT / ('venom-mortar-v2-%s.png' % view))

# ---------------------------------------------------------------- generated reference comparison
def load_reference():
    """Bring the generated reference into a hidden-from-render collection (not saved with the design file)."""
    import numpy as np
    ex = [o for o in bpy.data.objects if o.name.startswith('REF |')]
    if ex: return ex[0]
    with np.load(REF_MESH, allow_pickle=False) as a:
        v = a['vertices'].astype(np.float64); f = np.ascontiguousarray(a['faces'], np.int32)
    b = np.stack([-v[:, 0], v[:, 2], v[:, 1]], 1)
    b[:, 2] -= b[:, 2].min(); low = b[b[:, 2] < .03]
    b[:, 0] -= (low[:, 0].min() + low[:, 0].max()) / 2; b[:, 1] -= (low[:, 1].min() + low[:, 1].max()) / 2
    b *= .82 / max(np.ptp(low[:, 0]), np.ptp(low[:, 1]))
    me = bpy.data.meshes.new('REF | generated seed42 denoised'); me.vertices.add(len(b)); me.vertices.foreach_set('co', b.astype(np.float32).ravel())
    me.loops.add(f.size); me.loops.foreach_set('vertex_index', f.ravel()); me.polygons.add(len(f))
    me.polygons.foreach_set('loop_start', np.arange(len(f), dtype=np.int32) * 3); me.polygons.foreach_set('loop_total', np.full(len(f), 3, np.int32)); me.update()
    c = bpy.data.collections.get(REF_COLLECTION) or bpy.data.collections.new(REF_COLLECTION)
    if c.name not in scene.collection.children: scene.collection.children.link(c)
    o = bpy.data.objects.new(me.name, me); c.objects.link(o); o.hide_render = True
    return o

CMP_VIEWS = {'front': ((0, -3, .4), 1.0), 'side': ((3, 0, .4), 1.0), 'back': ((0, 3, .4), 1.0), 'top': ((0, 0, 3), 1.0)}

def _silhouette(path, res):
    import numpy as np
    scene.render.filepath = path; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path); w, h = im.size
    a = np.array(im.pixels[:], np.float32).reshape(h, w, 4)[::-1, :, 3] > .5; bpy.data.images.remove(im); return a

def ref_compare(out_dir, res=500):
    """Per-view silhouette IoU of the model against the generated reference; writes <view>-diff.png
    (red: reference only, blue: model only, grey: both) and compare.png with all views."""
    import numpy as np
    out = Path(out_dir); out.mkdir(parents=True, exist_ok=True)
    ref = load_reference(); cam = scene.camera
    state = (scene.render.engine, scene.render.film_transparent, scene.render.resolution_x, cam.data.type, cam.data.ortho_scale,
             tuple(cam.location), tuple(cam.rotation_euler), scene.objects['turret_head'].rotation_euler.z)
    scene.render.engine = 'BLENDER_WORKBENCH'; scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = res; cam.data.type = 'ORTHO'
    scene.objects['turret_head'].rotation_euler.z = 0
    model = [o for o in scene.objects if o.type in ('MESH', 'CURVE') and not o.name.startswith('REF |') and o.name != 'Studio floor' and not o.hide_render]
    floor = scene.objects.get('Studio floor'); floor_hidden = floor.hide_render if floor else True
    if floor: floor.hide_render = True
    result, panels = {}, []
    for view, (loc, scale) in CMP_VIEWS.items():
        cam.location = loc; cam.data.ortho_scale = scale
        cam.rotation_euler = (0, 0, 0) if view == 'top' else (Vector((0, 0, loc[2])) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        ref_png = out / f'ref-{view}.png'
        for o in model: o.hide_render = True
        ref.hide_render = False; r = _silhouette(str(ref_png), res); ref.hide_render = True
        for o in model: o.hide_render = False
        m = _silhouette(str(out / f'model-{view}.png'), res)
        iou = float((r & m).sum() / max(1, (r | m).sum())); result[view] = round(iou, 3)
        d = np.zeros(r.shape + (3,), np.float32) + .12
        d[r & m] = .62; d[r & ~m] = (1, .2, .15); d[m & ~r] = (.2, .45, 1)
        panels.append(d)
    img = np.concatenate(panels, 1); h, w = img.shape[:2]
    rgba = np.concatenate([img, np.ones((h, w, 1), np.float32)], 2)[::-1]
    im = bpy.data.images.new('cmp', w, h, alpha=True); im.pixels[:] = rgba.ravel()
    im.filepath_raw = str(out / 'compare.png'); im.file_format = 'PNG'; im.save(); bpy.data.images.remove(im)
    (scene.render.engine, scene.render.film_transparent, rx, cam.data.type, cam.data.ortho_scale, loc, rot, yaw) = state
    scene.render.resolution_x = scene.render.resolution_y = rx; cam.location = loc; cam.rotation_euler = rot
    scene.objects['turret_head'].rotation_euler.z = yaw
    if floor: floor.hide_render = floor_hidden
    result['mean'] = round(sum(result.values()) / 4, 3)
    return result

def triangles():
    dg = bpy.context.evaluated_depsgraph_get(); t = 0
    for o in scene.objects:
        if o.type in ('MESH', 'CURVE') and not o.hide_render and o.name != 'Studio floor' and not o.name.startswith('REF |'):
            e = o.evaluated_get(dg); m = e.to_mesh(); m.calc_loop_triangles(); t += len(m.loop_triangles); e.to_mesh_clear()
    return t

def build_all():
    setup(); build_base(); build_carriage(); build_braces(); build_barrel(); build_tank(); build_glob(); studio(); apply_metal_finish()
    camera('hero')

if __name__ == '__main__':
    import sys
    build_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'venom-mortar-A-v2.blend'), compress=True)
    if '--no-render' not in sys.argv:
        for v in ['hero', 'rear', 'game']:
            camera(v); bpy.ops.render.render(write_still=True)
        camera('hero', 160, OUT / 'venom-mortar-v2-hero-160.png'); scene.cycles.samples = 48; bpy.ops.render.render(write_still=True)
        camera('hero')
    print('VENOM MORTAR V2 DONE')
