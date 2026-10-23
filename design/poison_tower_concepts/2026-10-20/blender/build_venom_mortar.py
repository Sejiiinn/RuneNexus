"""Venom mortar (poison turret concept A) — independent Blender design source. No game export.
Blender -b --factory-startup --python build_venom_mortar.py [-- --no-render]
Also runnable inside a live Blender (MCP): exec the file, then call build_all().
Coordinates: Z up, -Y forward (same as the rune flame turret). Base diameter .86.

Rebuilt against concept A with the concept image overlaid on a matched camera (overlay('concept')).
Earlier versions are kept in before-refine/ (first model) and before-rebuild/ (patched model).
"""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
from pathlib import Path

try:
    OUT = Path(__file__).resolve().parent
except NameError:
    OUT = Path('/Users/sejin/Documents/Codex/RuneNexus/design/poison_tower_concepts/2026-10-20/blender')
REF = OUT.parent / 'A-venom-mortar.png'
FIRE_FINISH = OUT.parents[2] / 'fire_tower_concepts' / 'runic_3d' / 'finish_materials.py'
PITCH = math.radians(19)          # fixed mortar elevation
PIVOT = Vector((0, .05, .525))     # trunnion at the tube's rear end, on the rear leg of the A-frame (concept A)
BARREL_R = .205                   # octagonal tube apothem: short, fat mortar body (close to the muzzle ring)
HOUSING = 1.06                    # breech block half size relative to BARREL_R
TANK_ORIGIN = Vector((0, .27, .47))  # tank stands low behind the breech on a dark column (head space)
TANK_LEAN = math.radians(6)       # nearly upright, leaning back slightly
BRACE_X = .262                    # A-frame centre plane
HERO_YAW = math.radians(-11)      # review pose (tuned against the concept overlay)

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

# ---------------------------------------------------------------- scene
def setup():
    global scene, base_col, head_col, gun_col, tank_col, fx_col, studio_col, cut_brace, cut_barrel, cut_base
    global root, head, gun, iron, bronze, dark, edge, rune, glass_m, liquid, bubble, glob, glob_core
    scene = bpy.context.scene; scene.name = 'Venom Mortar — Design'
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections): bpy.data.collections.remove(c)
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

def build_base():
    # Tall round segmented plinth (concept A: about a fifth of the turret height).
    plinth = lathe('Foundation armor ring', [(0, 0), (.43, 0), (.43, .135), (.418, .158), (.4, .165), (0, .165)], 64, iron, base_col, root, 'Z', bevel=.008, smooth=True)
    for i in range(16):
        a = (i + .5) * math.pi / 8
        cube('Plinth seam cutter %02d' % i, (.43 * math.cos(a), .43 * math.sin(a), .08), (.05, .012, .24), None, cut_base, root, 0, (0, 0, a))
    cut(plinth, cut_base)
    ring('Foundation dark top rim', .392, .27, .014, (0, 0, .17), dark, base_col, root, 64, bevel=.004)
    # Four big cast bronze shoes on the diagonals (one faces the hero camera, as in the concept).
    shoe = [(-.29, .0), (-.49, .0), (-.49, .17), (-.47, .228), (-.41, .245), (-.29, .2)]
    for i in range(4):
        o = prism_x('Foundation bronze shoe %02d' % i, shoe, .21, 0, bronze, base_col, root, .015)
        o.rotation_euler.z = math.pi / 4 + i * math.pi / 2
        for v in o.data.vertices:
            if v.co.y < -.45: v.co.x *= .82
    # Large turntable drum (rotates with the head) with a bronze crown ring and bosses.
    cyl('Turntable drum', .265, .125, (0, 0, .2275), iron, head_col, head, 64, bevel=.014)
    ring('Turntable bronze crown', .272, .222, .03, (0, 0, .283), bronze, head_col, head, 64, bevel=.005)
    ring('Turntable dark groove band', .268, .25, .016, (0, 0, .205), dark, head_col, head, 64, bevel=.002)
    for a in [-math.pi / 2, math.pi / 6, 5 * math.pi / 6]:
        b = cyl('Drum bronze boss', .036, .03, (.268 * math.cos(a), .268 * math.sin(a), .235), bronze, head_col, head, 24, 'Y', .007)
        b.rotation_euler.z = a + math.pi / 2
    ring('Pedestal bronze collar', .18, .14, .018, (0, 0, .305), bronze, head_col, head, 48, bevel=.003)  # the fat tube sits right on the drum

def build_braces():
    # Bronze A-frames (concept A): two legs from the drum up to an apex beside the barrel band, an open
    # centre filled by a recessed dark panel carrying the glowing diamond + chevrons, trunnion on the rear leg.
    outer = [(-.215, .29), (.2, .29), (.035, .69), (-.06, .69)]
    hole = [(-.163, .25), (.145, .25), (-.012, .635)]
    panel = [(-.175, .29), (.157, .29), (-.012, .65)]
    for sign in [-1, 1]:
        x = sign * BRACE_X; side = 'Right' if sign > 0 else 'Left'
        frame = prism_x(side + ' bronze A-frame', outer, .062, x, bronze, head_col, head, .013)
        cutter = prism_x(side + ' A-frame opening cutter', hole, .2, x, None, cut_brace, head, 0)
        cutter.display_type = 'WIRE'
        px = x - sign * .012
        prism_x(side + ' A-frame dark rune panel', panel, .03, px, dark, head_col, head, .004)
        fr = (Vector((px + sign * .015, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((sign, 0, 0)))
        cy = -.012
        motifs = [([(cy, .5), (cy + .034, .466), (cy, .432), (cy - .034, .466)], True),
                  ([(cy - .058, .41), (cy, .366), (cy + .058, .41)], False),
                  ([(cy - .078, .348), (cy, .304), (cy + .078, .348)], False)]
        for pts2, closed in motifs:
            ribbon(side + ' brace rune glow', pts2, .024, .008, fr, rune, head_col, head, closed, lift=.002)
        # Trunnion stub hidden inside the apex; the round bearing hub sits on the rear leg as in the concept.
        cyl(side + ' trunnion stub', .055, .1, (sign * (BRACE_X - .04), PIVOT.y, PIVOT.z), iron, head_col, head, 16, 'X', .004)
        hy, hz = .1, .45
        cyl(side + ' bearing dark ring', .072, .03, (sign * (BRACE_X + .04), hy, hz), dark, head_col, head, 32, 'X', .008)
        cyl(side + ' bearing bronze cap', .054, .045, (sign * (BRACE_X + .07), hy, hz), bronze, head_col, head, 32, 'X', .012)
        cyl(side + ' bearing pin', .022, .02, (sign * (BRACE_X + .095), hy, hz), dark, head_col, head, 24, 'X', .004)
    for o in [o for o in head_col.objects if o.name.endswith('A-frame')]:
        cut(o, cut_brace)

def build_barrel():
    global body
    r = BARREL_R; hs = HOUSING * r
    # Short fat octagonal mortar body; local -Y is the muzzle.
    body = loft('Octagonal mortar tube', [(-.44, r, r), (-.05, r, r), (.05, r, r)], iron, gun_col, gun, .014)
    # Short breech block behind the trunnion (the tube ends here; the tank stands behind it).
    loft('Breech block', [(.03, hs, hs), (.09, hs, hs), (.13, hs * .78, hs * .78)], iron, gun_col, gun, .014)
    ring('Breech bronze lip', hs + .01, r * .9, .03, (0, .03, 0), bronze, gun_col, gun, 8, 'Y', .005, math.pi / 8)
    cyl('Breech dark cap', .11, .03, (0, .14, 0), dark, gun_col, gun, 8, 'Y', .008, phase=math.pi / 8)
    # Panel seam ahead of the trunnion.
    ring('Barrel seam cutter', r * 1.25, r * .975 / math.cos(math.pi / 8), .01, (0, -.02, 0), None, cut_barrel, gun, 8, 'Y', 0, math.pi / 8)
    # Wide bronze band where the A-frames lean in.
    lathe('Barrel bronze band', [(r * .99, -.065), (r * 1.05, -.052), (r * 1.07, -.03), (r * 1.07, .035), (r * 1.05, .055), (r * .99, .065)],
          8, bronze, gun_col, gun, 'Y', (0, -.165, 0), bevel=.007, phase=math.pi / 8)
    # Segmented muzzle: eight bronze blocks only a lip wider than the tube. The rear edge starts at the
    # tube's own corner radius and slopes out, so the ring grows out of the body instead of capping it.
    rv = r * 1.084                          # octagon corner radius of the tube (see octo)
    R, ri, y0, y1 = .236, .146, .055, -.055   # wide flat bronze front face, short sides
    prof = [(ri, y0), (rv, y0), (R, y0 - .035), (R, y1 + .02), (R - .02, y1), (ri + .015, y1), (ri, y1 + .015)]
    gap = .005
    for i in range(8):
        a0 = math.pi / 8 + i * math.pi / 4
        sector('Muzzle bronze block %d' % i, prof, a0 + gap, a0 + math.pi / 4 - gap, bronze, gun_col, gun, 'Y', (0, -.48, 0), bevel=.006, angle=30)
    ring('Muzzle dark backing ring', R * .9, ri * .95, .08, (0, -.47, 0), dark, gun_col, gun, 8, 'Y', .004, math.pi / 8)
    ring('Muzzle dark inner lip', ri * .98, ri * .84, .03, (0, -.525, 0), dark, gun_col, gun, 8, 'Y', .006, math.pi / 8)
    ring('Muzzle dark sleeve', ri * .9, ri * .8, .12, (0, -.46, 0), dark, gun_col, gun, 8, 'Y', .002, math.pi / 8)
    cyl('Muzzle dark throat', ri * .85, .01, (0, -.41, 0), dark, gun_col, gun, 8, 'Y', .001, phase=math.pi / 8)
    for sign in [-1, 1]:
        # Diamond outline (dark centre) on the side face between muzzle and band.
        fr = side_frame(sign)
        dia = [(.315, .068), (.382, 0), (.315, -.068), (.248, 0)]
        ribbon('Barrel diamond rune cutter', dia, .026, .03, fr, None, cut_barrel, gun)
        ribbon('Barrel diamond rune glow', dia, .022, .004, fr, rune, gun_col, gun, lift=-.008)
        # Pointed bronze plate on the lower side ahead of the band, small trapezoid rune in front of it.
        fl = lower_frame(sign)
        plate('Barrel lower bronze plate', [(.23, .05), (.27, .05), (.295, 0), (.27, -.05), (.23, -.05)], .016, fl, bronze, gun_col, gun, .005)
        trap = [(.32, .03), (.36, .03), (.374, -.028), (.306, -.028)]
        ribbon('Barrel lower rune cutter', trap, .02, .02, fl, None, cut_barrel, gun)
        ribbon('Barrel lower rune glow', trap, .017, .004, fl, rune, gun_col, gun, lift=-.005)
    cut(body, cut_barrel)
    empty('muzzle', gun_col, gun, (0, -.56, 0))

def build_tank():
    # Big upright reservoir standing low behind the breech on a dark column from the drum (concept A),
    # leaning back slightly; two bronze straps hook over the cap and drop to riveted brackets.
    tank = empty('venom_tank', tank_col, head, TANK_ORIGIN); tank.rotation_euler.x = -TANK_LEAN
    # Short dark seat on the drum's rear edge (kept small: a tall column read as an extra pillar).
    seat_y, seat_bot = TANK_ORIGIN.y - .04, .28
    cyl('Tank seat column', .1, TANK_ORIGIN.z - seat_bot, (0, seat_y, (TANK_ORIGIN.z + seat_bot) / 2), iron, tank_col, head, 8, bevel=.012, phase=math.pi / 8)
    cyl('Tank seat cradle', .138, .07, (0, TANK_ORIGIN.y, TANK_ORIGIN.z - .02), iron, tank_col, head, 8, bevel=.012, r2=.142, phase=math.pi / 8)
    cyl('Tank dark foot ring', .127, .035, (0, 0, .045), dark, tank_col, tank, 48, bevel=.006)
    ring('Tank glass wall', .108, .101, .27, (0, 0, .195), glass_m, tank_col, tank, 48, bevel=0)
    lathe('Tank venom liquid', [(0, .062), (.1, .062), (.1, .19), (.091, .199), (0, .195)], 48, liquid, tank_col, tank, 'Z', bevel=0)
    rng = random.Random(7)
    for i in range(22):
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(.03, .088)
        sphere('Tank bubble %02d' % i, rng.uniform(.006, .016), (rr * math.cos(a), rr * math.sin(a), rng.uniform(.08, .195)), bubble, tank_col, tank, 12)
    ring('Tank top bronze rim', .129, .104, .028, (0, 0, .335), bronze, tank_col, tank, 48, bevel=.006)
    cyl('Tank top dark cap', .124, .05, (0, 0, .37), dark, tank_col, tank, 48, bevel=.01)
    cyl('Tank top dark ring', .085, .02, (0, 0, .403), dark, tank_col, tank, 32, bevel=.004)
    cyl('Tank top bronze knob', .062, .07, (0, 0, .445), bronze, tank_col, tank, 8, bevel=.012, phase=math.pi / 8)
    for k, ang in enumerate([math.radians(60), math.radians(240)]):
        u = Vector((math.cos(ang), math.sin(ang), 0)); n = Vector((-math.sin(ang), math.cos(ang), 0))
        fr = (Vector((0, 0, 0)), u, Vector((0, 0, 1)), n)
        rs = .137
        ribbon('Tank strap %d' % k, [(rs, -.075), (rs, .37), (rs - .05, .405)], .024, .048, fr, bronze, tank_col, tank, closed=False, bevel=.006)
        for z in [.07, .2, .32]:
            p = u * (rs + .013)
            cyl('Strap rivet', .011, .008, (p.x, p.y, z), dark, tank_col, tank, 12, bevel=.002).rotation_euler = (math.pi / 2, 0, ang + math.pi / 2)
        p = u * (rs - .005)
        cube('Strap bracket %d' % k, (p.x, p.y, -.06), (.06, .07, .07), bronze, tank_col, tank, .01, (0, 0, ang))
    # Feed pipe (head space): rises from the barrel top behind the band and turns into the tank side.
    start = gun_to_head((0, -.02, BARREL_R - .01))
    end = tank_to_head((0, -.108, .29))
    corner = Vector((0, start.y, end.z))
    pipe('Feed pipe', elbow(start, corner, end, .055), .025, bronze, tank_col, head)
    cyl('Pipe barrel collar', .038, .04, tuple(start + Vector((0, 0, .015))), dark, tank_col, head, 24, bevel=.005)
    fl = cyl('Pipe tank flange', .038, .03, (0, -.115, .29), dark, tank_col, tank, 24, 'Y', .005)

def build_glob():
    # Venom glob seated in the muzzle; separate object for later animation/flipbook decisions.
    g = sphere('Venom glob', .135, (0, -.465, 0), glob, fx_col, gun, 48); g.scale = (1, .72, 1)  # stays inside the ring
    sphere('Venom glob inner glow', .07, (0, -.46, 0), glob_core, fx_col, gun, 24)
    rng = random.Random(3)
    for i in range(6):
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(.02, .085)
        sphere('Glob bubble %02d' % i, rng.uniform(.006, .013), (rr * math.cos(a), -.54 - rng.uniform(0, .01), rr * math.sin(a)), bubble, fx_col, gun, 12)

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
    # Same studio as the finished rune flame turret (finish_scene.py) so the two renders compare directly.
    gm, ns, lk, p = node_mat('Studio | desaturated forest')
    p.inputs['Base Color'].default_value = (.020, .050, .039, 1); p.inputs['Roughness'].default_value = .92
    cube('Studio floor', (0, 0, -.011), (200, 200, .02), gm, studio_col, None, 0)
    def light(name, pos, power, size, col):
        d = bpy.data.lights.new(name, 'AREA'); d.energy = power; d.shape = 'DISK'; d.size = size; d.color = col
        o = bpy.data.objects.new(name, d); studio_col.objects.link(o); o.location = pos
        o.rotation_euler = (Vector((0, 0, .4)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    light('Large warm key', (-2, -3, 4), 350, 3, (1, .91, .8))
    light('Soft neutral fill', (3, -1, 2.5), 220, 2.8, (.72, .83, 1))
    light('Bronze rim', (.2, 3, 3), 160, 2, (1, .85, .70))
    d = bpy.data.cameras.new('Camera'); cam = bpy.data.objects.new('Camera', d); studio_col.objects.link(cam)
    d.type = 'ORTHO'; scene.camera = cam
    scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'; scene.view_settings.exposure = -.35
    scene.render.image_settings.file_format = 'PNG'
    if 'REFERENCE — approved concept A' not in bpy.data.images:
        img = bpy.data.images.load(str(REF), check_existing=True); img.name = 'REFERENCE — approved concept A'; img.pack(); img.use_fake_user = True
    note = bpy.data.texts.get('START HERE — 독액 박격포') or bpy.data.texts.new('START HERE — 독액 박격포')
    note.clear()
    note.write('독 포탑 A안(독액 박격포) Blender 디자인 원본. 게임 이관 없음.\n'
               '01 Fixed Base / 02 Rotating Carriage / 03 Mortar Barrel / 04 Venom Tank / 05 Venom Glob 별도 편집.\n'
               '좌표 Z 위, -Y 전방, 받침 지름 .86(화염 포탑과 동일). 포신 고정 앙각 22도, 독액통은 거의 수직(8도).\n'
               '시안 겹침 확인: build_venom_mortar.py의 overlay(). concept 카메라에서 시안 위에 렌더 윤곽을 겹친다.\n'
               '금속 재질은 화염 포탑 finish_materials.py의 단조 마감을 공유한다(청동만 약간 구리 쪽).\n'
               '룬 홈·받침 이음매·지지대 개구부는 99 Recess Cutters 컬렉션의 비적용 Boolean입니다.\n')

VIEWS = {
    # loc, target, ortho scale (or lens in mm with 'PERSP'), head yaw[, projection]
    # The concept reads as a mild perspective (near muzzle large, far tank small), so its overlay view is PERSP.
    'concept': ((1.821, -1.765, 1.268), (-.03, -.03, .345), 62, HERO_YAW, 'PERSP'),
    'hero': ((1.821, -1.765, 1.268), (-.03, -.03, .345), 62, HERO_YAW, 'PERSP'),  # same as 'concept'
    'flame-hero': ((3.2, -3, 2.6), (0, -.035, .50), 1.62, HERO_YAW),  # rune flame turret hero camera (ortho)
    'rear': ((-3.0, 3.1, 2.6), (0, .0, .50), 1.62, HERO_YAW),
    'game': ((0, -2.6, 4.2), (0, .06, .48), 1.45, 0),            # steep game-like view
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
    scene.render.filepath = str(path or OUT / ('venom-mortar-%s.png' % view))

def concept_mask(px):
    """Turret silhouette in the concept: everything that is not the teal backdrop (teal = G and B clearly
    above R with G close to B). Cleaned with a small open/close. px: (H, W, 4) bottom-up float array."""
    import numpy as np
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    teal = (g - r > .035) & (b - r > .03) & (np.abs(g - b) < .07) & (g < .42)
    m = ~teal
    def grow(x, n, op):
        for _ in range(n):
            y = x.copy()
            for ax in (0, 1):
                for s in (1, -1):
                    y = op(y, np.roll(x, s, ax))
            x = y
        return x
    m = grow(grow(m, 2, np.logical_and), 2, np.logical_or)      # open: drop specks
    m = grow(grow(m, 4, np.logical_or), 4, np.logical_and)      # close: fill glints and seams
    m[:200] = False                                             # floor glow under the plinth is not turret
    return m

def overlay(out_path, view='concept', samples=24, mix=.5):
    """Design check against the concept. Renders the matched camera at the concept's size and writes
    out_path (blend + magenta render outline) and out_path-diff (red: concept only, blue: model only).
    Returns IoU and per-band extents. Keep outputs outside the repository."""
    import numpy as np
    ref = bpy.data.images.load(str(REF), check_existing=True); W, H = ref.size
    camera(view, W); scene.render.film_transparent = True; old = scene.cycles.samples; scene.cycles.samples = samples
    floor = scene.objects['Studio floor']; floor.hide_render = True
    tmp = str(Path(out_path).with_suffix('.render.png')); scene.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    scene.render.film_transparent = False; scene.cycles.samples = old; floor.hide_render = False
    ren = bpy.data.images.load(tmp); a = np.array(ref.pixels[:], np.float32).reshape(H, W, 4)
    b = np.array(ren.pixels[:], np.float32).reshape(H, W, 4); bpy.data.images.remove(ren)
    al = b[..., 3:4] * mix
    outp = a.copy(); outp[..., :3] = a[..., :3] * (1 - al) + b[..., :3] * al
    m = b[..., 3] > .5
    edge = m ^ np.roll(m, 1, 0) | m ^ np.roll(m, 1, 1) | m ^ np.roll(m, 2, 0) | m ^ np.roll(m, 2, 1)
    outp[edge] = (1, .1, .9, 1)
    def save(arr, path):
        im = bpy.data.images.new('overlay', W, H, alpha=True); im.pixels[:] = arr.ravel()
        im.filepath_raw = path; im.file_format = 'PNG'; im.save(); bpy.data.images.remove(im)
    save(outp, out_path)
    c = concept_mask(a)
    d = np.zeros_like(a); d[..., 3] = 1
    gray = a[..., :3].mean(-1, keepdims=True) * .5
    d[..., :3] = gray
    d[c & ~m] = (1, .15, .1, 1); d[m & ~c] = (.15, .45, 1, 1); d[c & m, :3] = d[c & m, :3] + .25
    save(d, str(Path(out_path).with_name(Path(out_path).stem + '-diff.png')))
    iou = float((c & m).sum() / max(1, (c | m).sum()))
    rows = {}
    for top in range(100, 1100, 100):                       # bands counted from the image top
        y0, y1 = H - top - 100, H - top                     # pixel arrays are bottom-up
        def ext(mm):
            xs = np.where(mm[y0:y1].any(0))[0]
            return (int(xs.min()), int(xs.max())) if len(xs) else None
        rows[top] = {'concept': ext(c), 'model': ext(m)}
    def bbox(mm):
        ys, xs = np.where(mm); return (int(xs.min()), int(H - 1 - ys.max()), int(xs.max()), int(H - 1 - ys.min()))
    camera('hero')
    return {'iou': round(iou, 3), 'concept_bbox': bbox(c), 'model_bbox': bbox(m), 'rows': rows}

def build_all():
    setup(); build_base(); build_braces(); build_barrel(); build_tank(); build_glob(); studio(); apply_metal_finish()
    camera('hero')

if __name__ == '__main__':
    import sys
    build_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'venom-mortar-A.blend'), compress=True)
    if '--no-render' not in sys.argv:
        for v in ['hero', 'rear', 'game']:
            camera(v); bpy.ops.render.render(write_still=True)
        camera('hero', 160, OUT / 'venom-mortar-hero-160.png'); scene.cycles.samples = 48; bpy.ops.render.render(write_still=True)
        camera('hero')
    print('VENOM MORTAR DONE')
