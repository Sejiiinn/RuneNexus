"""Venom mortar (poison turret concept A) — independent Blender design source. No game export.
Blender -b --factory-startup --python build_venom_mortar.py [-- --no-render]
Also runnable inside a live Blender (MCP): exec the file, then call build_all().
Coordinates: Z up, -Y forward (same as the rune flame turret). Base diameter .86.
The previous (pre-refine) version is kept in before-refine/.

RECONSTRUCTED copy of the patched model (before-rebuild). The original file was overwritten before it was
backed up; this text was rebuilt from the session's edit history and checked against venom-mortar-A.blend
in this folder by triangle count. Running __main__ here writes into this folder, so call build_all() instead.
"""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
from pathlib import Path

try:
    OUT = Path(__file__).resolve().parent
except NameError:
    OUT = Path('/Users/sejin/Documents/Codex/RuneNexus/design/poison_tower_concepts/2026-10-20/blender/before-rebuild')
REF = OUT.parents[1] / 'A-venom-mortar.png'
FIRE_FINISH = OUT.parents[3] / 'fire_tower_concepts' / 'runic_3d' / 'finish_materials.py'
PITCH = math.radians(22)          # fixed elevation: long, shallow tube as in concept A
PIVOT = Vector((0, 0, .56))       # trunnion axis height
BARREL_R = .165                   # octagonal tube apothem (concept A: thick body)
CHAMBER = 1.08                    # breech chamber half size relative to BARREL_R (tank seat)
TANK_Y = .2                       # tank axis position along the tube (gun local)
HERO_YAW = math.radians(-20)      # review pose: barrel swung left so its length reads like the concept

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

def lathe(name, prof, n, mat, coll, parent=None, axis='Y', loc=(0, 0, 0), bevel=.006, phase=0, smooth=None, **kw):
    """Revolve a closed (radius, height) profile loop n times around the local axis."""
    m = len(prof); vs = []
    for i in range(n):
        a = phase + 2 * math.pi * i / n
        for r, h in prof:
            x, y = r * math.cos(a), r * math.sin(a)
            vs.append({'Y': (x, h, y), 'Z': (x, y, h), 'X': (h, x, y)}[axis])
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

def ring(name, ro, ri, depth, loc, mat, coll, parent=None, n=48, axis='Z', bevel=.003, phase=0):
    d = depth / 2
    return lathe(name, [(ro, -d), (ro, d), (ri, d), (ri, -d)], n, mat, coll, parent, axis, loc, bevel, phase)

def prism_x(name, pts, thickness, x, mat, coll, parent=None, bevel=.006):
    """Extrude a (y, z) outline along X."""
    n = len(pts); vs = [(xx, y, z) for xx in [x - thickness / 2, x + thickness / 2] for y, z in pts]
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
    # (half of the barrel diamond disappeared). Grooves stay crisp; weighted normals run last.
    want = 1 if 'Machined bevel' in target.modifiers else 0
    target.modifiers.move(target.modifiers.find(b.name), want)

def gun_to_head(p):
    return PIVOT + Matrix.Rotation(-PITCH, 3, 'X') @ Vector(p)

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
    # Round, segmented gunmetal plinth (concept A) with a soft top chamfer.
    plinth = lathe('Foundation armor ring', [(0, 0), (.43, 0), (.43, .11), (.415, .135), (0, .135)], 64, iron, base_col, root, 'Z', bevel=.008, smooth=True)
    for i in range(16):
        a = (i + .5) * math.pi / 8
        cube('Plinth seam cutter %02d' % i, (.43 * math.cos(a), .43 * math.sin(a), .07), (.05, .012, .2), None, cut_base, root, 0, (0, 0, a)).hide_render = True
    for o in cut_base.objects: o.display_type = 'WIRE'
    cut(plinth, cut_base)
    ring('Foundation dark top rim', .395, .30, .016, (0, 0, .14), dark, base_col, root, 64, bevel=.004)
    # Four chunky trapezoid bronze shoes on the diagonals (front / left / right in the hero view).
    shoe = [(-.30, .0), (-.475, .0), (-.475, .16), (-.455, .215), (-.395, .228), (-.30, .175)]
    for i in range(4):
        o = prism_x('Foundation bronze shoe %02d' % i, shoe, .19, 0, bronze, base_col, root, .014)
        o.rotation_euler.z = math.pi / 4 + i * math.pi / 2
        # Taper the outer face so each shoe reads as a cast trapezoid, not a box.
        for v in o.data.vertices:
            if v.co.y < -.44: v.co.x *= .82
    # Turntable drum and pedestal rotate with the head.
    cyl('Turntable drum', .29, .1, (0, 0, .19), iron, head_col, head, 64, bevel=.012)
    ring('Turntable bronze rim', .297, .25, .022, (0, 0, .235), bronze, head_col, head, 64, bevel=.004)
    cyl('Pedestal', .205, .05, (0, 0, .265), dark, head_col, head, 48, bevel=.01)  # low: clears the breech chamber
    ring('Pedestal bronze collar', .215, .19, .022, (0, 0, .262), bronze, head_col, head, 48, bevel=.003)
    for a in [-math.pi / 2, math.pi / 2 + math.pi / 3, math.pi / 2 - math.pi / 3]:
        b = cyl('Drum bronze boss', .034, .03, (.29 * math.cos(a), .29 * math.sin(a), .185), bronze, head_col, head, 24, 'Y', .006)
        b.rotation_euler.z = a + math.pi / 2

def build_braces():
    # A-frame braces: wide foot on the drum, leaning front edge, rounded crown around the trunnion.
    crown = [(PIVOT.y + .092 * math.cos(a), PIVOT.z + .092 * math.sin(a)) for a in [math.radians(d) for d in range(0, 181, 20)]]
    pts = [(-.2, .24), (.18, .24), (.13, .47)] + crown + [(-.125, .45)]
    bx = BARREL_R + .05                     # brace centre clears the thick tube
    for sign in [-1, 1]:
        x = sign * bx
        side = 'Right' if sign > 0 else 'Left'
        o = prism_x(side + ' bronze A-brace', pts, .062, x, bronze, head_col, head, .012)
        cyl(side + ' trunnion stub', .055, .1, (sign * (bx - .035), PIVOT.y, PIVOT.z), iron, head_col, head, 16, 'X', .004)
        cyl(side + ' trunnion dark ring', .08, .04, (sign * (bx + .045), PIVOT.y, PIVOT.z), dark, head_col, head, 32, 'X', .008)
        cyl(side + ' trunnion bronze hub', .06, .05, (sign * (bx + .075), PIVOT.y, PIVOT.z), bronze, head_col, head, 8, 'X', .008, phase=math.pi / 8)
        cyl(side + ' trunnion cap', .032, .02, (sign * (bx + .105), PIVOT.y, PIVOT.z), dark, head_col, head, 24, 'X', .004)
        cyl(side + ' trunnion pin', .014, .012, (sign * (bx + .118), PIVOT.y, PIVOT.z), edge, head_col, head, 16, 'X', .002)
        # Carved diamond + two chevrons on the outer face (recessed, glowing floor).
        xo = x + sign * .031
        fr = (Vector((xo, 0, 0)), Vector((0, sign, 0)), Vector((0, 0, 1)), Vector((sign, 0, 0)))
        cy = -.005
        motifs = [([(cy, .45), (cy + .034, .418), (cy, .386), (cy - .034, .418)], True),
                  ([(cy - .055, .37), (cy, .325), (cy + .055, .37)], False),
                  ([(cy - .055, .315), (cy, .27), (cy + .055, .315)], False)]
        for pts2, closed in motifs:
            ribbon('Brace rune cutter', pts2, .026, .03, fr, None, cut_brace, head, closed)
            ribbon('Brace rune glow', pts2, .022, .004, fr, rune, head_col, head, closed, lift=-.012)
        cut(o, cut_brace)

def face_frame(sign, lower=False):
    """Frame on an upper (or lower) diagonal face of the octagonal tube; u runs toward the muzzle."""
    r = BARREL_R; hw = r * .42
    a = Vector((sign * hw, 0, -r if lower else r)); b = Vector((sign * r, 0, -hw if lower else hw))
    t = (b - a).normalized(); n = Vector((sign * abs(t.z), 0, (-1 if lower else 1) * abs(t.x)))
    return ((a + b) / 2, Vector((0, -1, 0)), t, n)

def build_barrel():
    global body
    r = BARREL_R
    # Thick octagonal tube (concept A: body nearly as wide as the muzzle ring); local -Y is the muzzle.
    c = CHAMBER * r
    body = loft('Octagonal mortar tube', [(-.37, r * .97, r * .97), (.07, r, r), (.1, c, c), (.32, c, c), (.36, c * .78, c * .78)], iron, gun_col, gun, .008)
    cyl('Breech dark cap', .1, .04, (0, .375, 0), dark, gun_col, gun, 8, 'Y', .008, phase=math.pi / 8)
    cyl('Breech bronze knob', .052, .035, (0, .405, 0), bronze, gun_col, gun, 8, 'Y', .006, phase=math.pi / 8)
    # Panel seams: shallow circumferential grooves split the tube into forged plates.
    for y in [.04]:
        ring('Barrel seam cutter', r * 1.25, r * .975 / math.cos(math.pi / 8), .01, (0, y, 0), None, cut_barrel, gun, 8, 'Y', 0, math.pi / 8)
    # Bronze collar just ahead of the braces: chamfered octagonal band.
    lathe('Front bronze collar', [(r * .99, -.06), (r * 1.08, -.048), (r * 1.1, -.03), (r * 1.1, .035), (r * 1.08, .05), (r * .99, .06)],
          8, bronze, gun_col, gun, 'Y', (0, -.13, 0), bevel=.007, phase=math.pi / 8)
    ring('Chamber front dark lip', r * CHAMBER + .008, r * .9, .03, (0, .1, 0), dark, gun_col, gun, 8, 'Y', .004, math.pi / 8)
    # Heavy octagonal muzzle: chamfered front, deep bore.
    R, ri, y0, y1 = .205, .125, .07, -.075
    lathe('Muzzle eight-sided bronze jacket', [(R * .9, y0), (R, y0 - .025), (R, y1 + .035), (R - .035, y1), (ri + .03, y1), (ri, y1 + .03), (ri, y0)],
          8, bronze, gun_col, gun, 'Y', (0, -.42, 0), bevel=.01, phase=math.pi / 8, angle=30)
    ring('Muzzle dark inner sleeve', ri * .99, ri * .82, .15, (0, -.405, 0), dark, gun_col, gun, 8, 'Y', .002, math.pi / 8)
    cyl('Muzzle dark throat', ri * .9, .01, (0, -.34, 0), dark, gun_col, gun, 8, 'Y', .001, phase=math.pi / 8)
    # Recessed lime runes: a bold diamond outline (dark centre) on each vertical side face, the face that
    # meets the hero camera as in concept A; a small trapezoid outline on the lower diagonal faces.
    # Shallow grooves keep the glow visible at oblique angles (deep ones hid half the outline).
    r = BARREL_R
    for sign in [-1, 1]:
        fr = (Vector((sign * r, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((sign, 0, 0)))
        dia = [(.267, .05), (.325, 0), (.267, -.05), (.209, 0)]
        ribbon('Barrel diamond rune cutter', dia, .026, .03, fr, None, cut_barrel, gun)
        ribbon('Barrel diamond rune glow', dia, .022, .004, fr, rune, gun_col, gun, lift=-.008)
        fr3 = face_frame(sign, lower=True)
        # Closed trapezoid outline as in concept A (an open bracket read as a broken fragment); extra shallow
        # because this face is seen at a grazing angle from above.
        trap = [(.228, .03), (.296, .03), (.318, -.028), (.206, -.028)]
        ribbon('Barrel lower rune cutter', trap, .02, .02, fr3, None, cut_barrel, gun)
        ribbon('Barrel lower rune glow', trap, .017, .004, fr3, rune, gun_col, gun, lift=-.005)
    cut(body, cut_barrel)
    empty('muzzle', gun_col, gun, (0, -.5, 0))

def build_tank():
    # Large caged reservoir growing out of the breech chamber, perpendicular to the tube (leans back with the
    # pitch). A flared cradle and a bronze band around the chamber tie tank and tube into one piece.
    r = BARREL_R; cr = CHAMBER * r; ty = TANK_Y
    tank = empty('venom_tank', tank_col, gun, (0, ty, cr))
    # Dark cradle flaring down into the chamber (its foot sits inside the chamber silhouette).
    cyl('Tank cradle', .175, .1, (0, 0, -.035), iron, tank_col, tank, 8, bevel=.01, r2=.15, phase=math.pi / 8)
    ring('Tank base bronze band', .152, .114, .04, (0, 0, .035), bronze, tank_col, tank, 8, bevel=.008, phase=math.pi / 8)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        cyl('Base band rivet %02d' % i, .012, .01, (.153 * math.cos(a), .153 * math.sin(a), .035), dark, tank_col, tank, 12, bevel=.002).rotation_euler = (math.pi / 2, 0, a + math.pi / 2)
    # Thin-walled tube (a solid glass cylinder refracts the liquid into looking full).
    ring('Tank glass wall', .114, .107, .28, (0, 0, .195), glass_m, tank_col, tank, 48, bevel=0)
    lathe('Tank venom liquid', [(0, .055), (.106, .055), (.106, .215), (.097, .224), (0, .22)], 48, liquid, tank_col, tank, 'Z', bevel=0)
    rng = random.Random(7)
    for i in range(20):
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(.025, .093)
        sphere('Tank bubble %02d' % i, rng.uniform(.005, .013), (rr * math.cos(a), rr * math.sin(a), rng.uniform(.075, .21)), bubble, tank_col, tank, 12)
    cyl('Tank top dark cap', .132, .055, (0, 0, .36), dark, tank_col, tank, 48, bevel=.009)
    ring('Tank top bronze rim', .142, .114, .03, (0, 0, .343), bronze, tank_col, tank, 8, bevel=.007, phase=math.pi / 8)
    cyl('Tank top hex plug', .055, .06, (0, 0, .415), bronze, tank_col, tank, 6, bevel=.009)
    cyl('Tank top plug collar', .066, .018, (0, 0, .393), dark, tank_col, tank, 32, bevel=.003)
    # Cage strap up both sides of the glass and over the cap, angled so it frames the glass in the hero
    # view; it lands on the base band, and a bronze band wraps the chamber below to tie tank and tube.
    ang = math.radians(60)
    u = Vector((math.cos(ang), math.sin(ang), 0)); n = Vector((-math.sin(ang), math.cos(ang), 0))
    fr = (Vector((0, 0, 0)), u, Vector((0, 0, 1)), n)
    rs, top = .126, .392
    loop = [(-rs, .02), (-rs, .34), (-rs + .03, top), (rs - .03, top), (rs, .34), (rs, .02)]
    ribbon('Tank cage strap', loop, .02, .04, fr, bronze, tank_col, tank, closed=False, bevel=.005)
    for s in [-1, 1]:
        p = u * (s * (rs + .01))
        for z in [.13, .28]:
            cyl('Strap rivet', .01, .008, (p.x, p.y, z), dark, tank_col, tank, 12, bevel=.002).rotation_euler = (math.pi / 2, 0, ang + math.pi / 2)
    ring('Chamber bronze strap band', cr + .02, cr * .95, .04, (0, ty, 0), bronze, gun_col, gun, 8, 'Y', .006, math.pi / 8)
    # Feed pipe: rises from the tube top behind the collar and turns back into the tank front.
    start = Vector((0, -ty, r - cr)); entry_z = .24
    pipe('Feed pipe', elbow(start, Vector((0, start.y, entry_z)), Vector((0, -.11, entry_z)), .05), .022, bronze, tank_col, tank)
    cyl('Pipe tube collar', .036, .035, (0, start.y, start.z + .012), dark, tank_col, tank, 24, bevel=.004)
    cyl('Pipe tank flange', .036, .03, (0, -.118, entry_z), dark, tank_col, tank, 24, 'Y', .004)

def build_glob():
    # Venom glob seated deep in the muzzle; separate object for later animation/flipbook decisions.
    g = sphere('Venom glob', .102, (0, -.44, 0), glob, fx_col, gun, 48); g.scale = (1, .9, 1)
    sphere('Venom glob inner glow', .055, (0, -.43, 0), glob_core, fx_col, gun, 24)
    rng = random.Random(3)
    for i in range(5):
        a = rng.uniform(0, 2 * math.pi); rr = rng.uniform(.02, .06)
        sphere('Glob bubble %02d' % i, rng.uniform(.006, .012), (rr * math.cos(a), -.49 - rng.uniform(0, .02), rr * math.sin(a)), bubble, fx_col, gun, 12)

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
               '좌표 Z 위, -Y 전방, 받침 지름 .86(화염 포탑과 동일). 포신 고정 앙각 22도, 독액통은 포신에 직각.\n'
               '금속 재질은 화염 포탑 finish_materials.py의 단조 마감을 공유한다(청동만 약간 구리 쪽).\n'
               '룬 홈·받침 이음매는 99 Recess Cutters 컬렉션을 쓰는 비적용 Boolean 모디파이어입니다.\n'
               'hero 렌더만 turret_head를 -20도 돌려 시안처럼 포신 길이가 보이게 찍습니다.\n')

VIEWS = {
    'hero': ((3.2, -3, 2.6), (0, -.035, .50), 1.62, HERO_YAW),  # flame turret hero camera, head yawed
    'rear': ((-3.0, 3.1, 2.6), (0, .0, .50), 1.62, HERO_YAW),
    'game': ((0, -2.6, 4.2), (0, .06, .48), 1.45, 0),            # steep game-like view (wider: tall tank)
}

def camera(view, res=1200, path=None):
    loc, target, scale, yaw = VIEWS[view]; cam = scene.camera
    cam.location = loc; cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = scale
    scene.objects['turret_head'].rotation_euler.z = yaw
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.filepath = str(path or OUT / ('venom-mortar-%s.png' % view))

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
