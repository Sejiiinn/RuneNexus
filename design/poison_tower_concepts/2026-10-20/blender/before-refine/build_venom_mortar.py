"""Venom mortar (poison turret concept A) — independent Blender design source. No game export.
Blender -b --factory-startup --python build_venom_mortar.py
Coordinates: Z up, -Y forward (same as the rune flame turret). Base diameter .86.
"""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
from pathlib import Path

OUT = Path(__file__).resolve().parent
REF = OUT.parent / 'A-venom-mortar.png'
PITCH = math.radians(35)          # fixed mortar elevation
PIVOT = Vector((0, .0, .56))       # trunnion axis height
LIFT = .07                         # tank floor height above the barrel top
random.seed(7)

# ---------------------------------------------------------------- helpers
def collection(name):
    c = bpy.data.collections.new(name); scene.collection.children.link(c); return c

def empty(name, coll, parent=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None); coll.objects.link(o); o.parent = parent; o.location = loc; return o

def finish(o, mat, bevel, smooth_quads=False):
    if mat: o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new('Machined bevel', 'BEVEL'); b.width = bevel; b.segments = 3
        b.limit_method = 'ANGLE'; b.angle_limit = math.radians(35)
        w = o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL'); w.keep_sharp = True; w.weight = 40
    if smooth_quads:
        for p in o.data.polygons: p.use_smooth = len(p.vertices) == 4
    return o

def from_bm(name, bm, mat, coll, parent=None, bevel=0, smooth_quads=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = bpy.data.meshes.new(name); bm.to_mesh(m); bm.free()
    o = bpy.data.objects.new(name, m); coll.objects.link(o); o.parent = parent
    return finish(o, mat, bevel, smooth_quads)

def mesh(name, verts, faces, mat, coll, parent=None, bevel=0):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces: bm.faces.new([vs[i] for i in f])
    return from_bm(name, bm, mat, coll, parent, bevel)

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

def ring(name, ro, ri, depth, loc, mat, coll, parent=None, n=48, axis='Z', bevel=.003, phase=0):
    vs = []
    for z, r in [(-depth / 2, ro), (depth / 2, ro), (-depth / 2, ri), (depth / 2, ri)]:
        for i in range(n):
            a = 2 * math.pi * i / n + phase; p = (r * math.cos(a), r * math.sin(a), z)
            if axis == 'Y': p = (p[0], -p[2], p[1])
            if axis == 'X': p = (p[2], p[0], p[1])
            vs.append(p)
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs += [(i, j, n + j, n + i), (2 * n + j, 2 * n + i, 3 * n + i, 3 * n + j), (n + i, n + j, 3 * n + j, 3 * n + i), (j, i, 2 * n + i, 2 * n + j)]
    o = mesh(name, vs, fs, mat, coll, parent, bevel); o.location = loc
    if n > 12:
        for p in o.data.polygons: p.use_smooth = True
    return o

def prism_x(name, pts, thickness, x, mat, coll, parent=None, bevel=.006):
    """Extrude a (y, z) outline along X."""
    n = len(pts); vs = [(xx, y, z) for xx in [x - thickness / 2, x + thickness / 2] for y, z in pts]
    fs = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, vs, fs, mat, coll, parent, bevel)

def loft(name, sections, mat, coll, parent=None, bevel=.008):
    """Eight-sided section loft along Y; each section is (y, half width, half height)."""
    vs = []
    for y, w, h in sections:
        vs += [(x, y, z) for x, z in [(-w * .45, h), (w * .45, h), (w, h * .45), (w, -h * .45), (w * .45, -h), (-w * .45, -h), (-w, -h * .45), (-w, h * .45)]]
    fs = [tuple(reversed(range(8))), tuple(range(len(vs) - 8, len(vs)))]
    for k in range(len(sections) - 1):
        for j in range(8): fs.append((k * 8 + j, k * 8 + (j + 1) % 8, (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
    return mesh(name, vs, fs, mat, coll, parent, bevel)

def ribbon(name, pts, width, depth, frame, mat, coll, parent=None, closed=True, lift=0.0):
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
    o = mesh(name, [tuple(v_) for v_ in vs], fs, mat, coll, parent, 0)
    if mat is None: o.display_type = 'WIRE'; o.hide_render = True
    return o

def cut(target, cutters_coll):
    b = target.modifiers.new('Rune recesses', 'BOOLEAN'); b.operation = 'DIFFERENCE'
    b.operand_type = 'COLLECTION'; b.collection = cutters_coll; b.solver = 'EXACT'
    # Boolean before bevel so recess edges stay crisp.
    while target.modifiers[0] != b:
        target.modifiers.move(target.modifiers.find(b.name), 0)

def gun_to_head(p):
    return PIVOT + Matrix.Rotation(-PITCH, 3, 'X') @ Vector(p)

# ---------------------------------------------------------------- materials
def node_mat(name):
    m = bpy.data.materials.new(name)
    try: m.use_nodes = True
    except Exception: pass
    return m, m.node_tree.nodes, m.node_tree.links, m.node_tree.nodes.get('Principled BSDF')

def metal(name, col, metallic, rough):
    m, ns, lk, p = node_mat(name); p.inputs['Metallic'].default_value = metallic
    tex = ns.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = 35; tex.inputs['Detail'].default_value = 3; tex.inputs['Roughness'].default_value = .7
    ramp = ns.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position = .15; ramp.color_ramp.elements[1].position = .85
    ramp.color_ramp.elements[0].color = tuple(c * .7 for c in col) + (1,)
    ramp.color_ramp.elements[1].color = tuple(c * 1.22 for c in col) + (1,)
    lk.new(tex.outputs['Fac'], ramp.inputs[0]); lk.new(ramp.outputs[0], p.inputs['Base Color'])
    rm = ns.new('ShaderNodeMapRange'); rm.inputs['To Min'].default_value = rough - .08; rm.inputs['To Max'].default_value = rough + .09
    lk.new(tex.outputs['Fac'], rm.inputs[0]); lk.new(rm.outputs[0], p.inputs['Roughness'])
    fine = ns.new('ShaderNodeTexNoise'); fine.inputs['Scale'].default_value = 240; fine.inputs['Detail'].default_value = 2
    bump = ns.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .2; bump.inputs['Distance'].default_value = .001
    lk.new(fine.outputs['Fac'], bump.inputs['Height']); lk.new(bump.outputs[0], p.inputs['Normal'])
    return m

def emissive(name, col, strength, rough=.35):
    m, ns, lk, p = node_mat(name)
    p.inputs['Base Color'].default_value = (*col, 1); p.inputs['Emission Color'].default_value = (*col, 1)
    p.inputs['Emission Strength'].default_value = strength; p.inputs['Roughness'].default_value = rough; return m

def glass(name):
    m, ns, lk, p = node_mat(name)
    p.inputs['Base Color'].default_value = (.85, 1, .9, 1); p.inputs['Roughness'].default_value = .04
    p.inputs['Transmission Weight'].default_value = 1; p.inputs['IOR'].default_value = 1.45
    try: m.surface_render_method = 'BLENDED'
    except Exception: pass
    return m

def venom(name, strength):
    """Glossy translucent venom: lime body, faint inner glow, clear coat."""
    m, ns, lk, p = node_mat(name)
    p.inputs['Base Color'].default_value = (.22, .85, .02, 1); p.inputs['Roughness'].default_value = .12
    p.inputs['Subsurface Weight'].default_value = .4; p.inputs['Subsurface Radius'].default_value = (.4, 1, .1)
    p.inputs['Coat Weight'].default_value = 1; p.inputs['Coat Roughness'].default_value = .05
    p.inputs['Emission Color'].default_value = (.3, 1, .02, 1); p.inputs['Emission Strength'].default_value = strength
    return m

# ---------------------------------------------------------------- scene
def setup():
    global scene, base_col, head_col, gun_col, tank_col, fx_col, studio_col, cut_brace, cut_barrel, cut_base
    global root, head, gun, iron, bronze, dark, edge, rune, glass_m, liquid, bubble, glob
    scene = bpy.context.scene; scene.name = 'Venom Mortar — Design'
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    base_col = collection('01 Fixed Base'); head_col = collection('02 Rotating Carriage')
    gun_col = collection('03 Mortar Barrel'); tank_col = collection('04 Venom Tank'); fx_col = collection('05 Venom Glob')
    studio_col = collection('90 Studio')
    cutters = collection('99 Recess Cutters'); cutters.hide_render = True
    cut_brace = bpy.data.collections.new('cutters | brace'); cutters.children.link(cut_brace)
    cut_barrel = bpy.data.collections.new('cutters | barrel'); cutters.children.link(cut_barrel)
    cut_base = bpy.data.collections.new('cutters | base'); cutters.children.link(cut_base)
    root = empty('turret_root', base_col); head = empty('turret_head', head_col, root)
    gun = empty('turret_barrel', gun_col, head, PIVOT); gun.rotation_euler.x = -PITCH
    iron = metal('Iron | forged charcoal', (.052, .062, .078), .72, .54)
    bronze = metal('Bronze | worn warm alloy', (.43, .235, .086), .72, .43)
    dark = metal('Recess | dark gunmetal', (.012, .017, .021), .5, .61)
    edge = metal('Steel | polished bevel detail', (.11, .13, .15), .8, .36)
    rune = emissive('Runes | venom lime', (.16, 1, .02), 2.0)
    glass_m = glass('Glass | tank wall')
    liquid = venom('Venom | tank liquid', 1.4)
    bubble = emissive('Venom | bubbles', (.65, 1, .3), 2.2, .1)
    glob = venom('Venom | muzzle glob', 2.4)

def build_base():
    # Twelve-sided plinth (fire turret is round) with three-step profile.
    cyl('Foundation lower armor', .43, .13, (0, 0, .065), iron, base_col, root, 12, bevel=.014, phase=math.pi / 12)
    cyl('Foundation dark rim', .405, .03, (0, 0, .145), dark, base_col, root, 12, bevel=.006, phase=math.pi / 12)
    for i in range(12):
        a = i * math.pi / 6
        cube('Foundation panel seam %02d' % i, (.43 * math.sin(a), -.43 * math.cos(a), .068), (.006, .006, .1), dark, base_col, root, .0, (0, 0, a))
    # Four chunky trapezoid bronze shoes on the diagonals of the barrel axis.
    for i in range(4):
        shoe_y = [(-.36, .0), (-.47, .0), (-.47, .135), (-.455, .19), (-.40, .2), (-.33, .17)]
        o = prism_x('Foundation bronze shoe %02d' % i, shoe_y, .16, 0, bronze, base_col, root, .012)
        o.rotation_euler.z = i * math.pi / 2
        cube('Shoe bolt %02d' % i, (0, -.475, .085), (.035, .012, .035), dark, base_col, o, .003)
    # Turntable and pedestal (rotate with the head).
    cyl('Turntable', .33, .08, (0, 0, .2), iron, head_col, head, 48, bevel=.014)
    ring('Turntable bronze seam', .318, .305, .012, (0, 0, .24), bronze, head_col, head)
    cyl('Pedestal', .22, .11, (0, 0, .29), dark, head_col, head, 32, bevel=.01)
    ring('Pedestal bronze collar', .232, .21, .026, (0, 0, .262), bronze, head_col, head, 32)
    cyl('Pedestal front boss', .03, .02, (0, -.226, .30), bronze, head_col, head, 24, 'Y', .004)

def build_braces():
    # A-frame braces: wide foot, leaning front edge, rounded crown around the trunnion.
    crown = [(.075 * math.cos(a), PIVOT.z + .075 * math.sin(a)) for a in [math.radians(d) for d in range(0, 181, 30)]]
    pts = [(-.165, .24), (.15, .24), (.105, .46)] + [(PIVOT.y + y, z) for y, z in crown] + [(-.10, .44)]
    for sign in [-1, 1]:
        x = sign * .265
        side = 'Right' if sign > 0 else 'Left'
        o = prism_x(side + ' bronze A-brace', pts, .055, x, bronze, head_col, head, .01)
        cyl(side + ' trunnion stub', .048, .11, (sign * .2, PIVOT.y, PIVOT.z), iron, head_col, head, 16, 'X', .004)
        cyl(side + ' trunnion dark ring', .072, .05, (sign * .228, PIVOT.y, PIVOT.z), dark, head_col, head, 32, 'X', .006)
        cyl(side + ' trunnion bronze hub', .052, .045, (sign * .31, PIVOT.y, PIVOT.z), bronze, head_col, head, 8, 'X', .006, phase=math.pi / 8)
        cyl(side + ' trunnion cap', .028, .02, (sign * .338, PIVOT.y, PIVOT.z), edge, head_col, head, 24, 'X', .003)
        cyl(side + ' brace foot bolt', .022, .014, (sign * .296, -.12, .28), bronze, head_col, head, 16, 'X', .003)
        # Carved diamond + two chevrons on the outer face (recessed, glowing floor).
        xo = x + sign * .0275
        fr = (Vector((xo, 0, 0)), Vector((0, -sign, 0)) * -1, Vector((0, 0, 1)), Vector((sign, 0, 0)))
        motifs = [([(0, .465), (.03, .435), (0, .405), (-.03, .435)], True),
                  ([(-.045, .385), (0, .345), (.045, .385)], False),
                  ([(-.045, .335), (0, .295), (.045, .335)], False)]
        for pts2, closed in motifs:
            ribbon('Brace rune cutter', pts2, .024, .03, fr, None, cut_brace, head, closed)
            ribbon('Brace rune glow', pts2, .02, .004, fr, rune, head_col, head, closed, lift=-.011)
        b = o.modifiers.new('Rune recesses', 'BOOLEAN'); b.operation = 'DIFFERENCE'; b.operand_type = 'COLLECTION'
        b.collection = cut_brace; b.solver = 'EXACT'; o.modifiers.move(o.modifiers.find(b.name), 0)

def build_barrel():
    global body
    # Short, fat mortar tube. Local -Y is the muzzle direction before pitch.
    body = loft('Octagonal mortar tube', [(.21, .12, .12), (.17, .172, .172), (-.21, .172, .172), (-.25, .164, .164)], iron, gun_col, gun, .009)
    cyl('Breech dark cap', .09, .04, (0, .23, 0), dark, gun_col, gun, 8, 'Y', .006, phase=math.pi / 8)
    cyl('Breech bronze knob', .045, .04, (0, .26, 0), bronze, gun_col, gun, 8, 'Y', .005, phase=math.pi / 8)
    ring('Rear bronze band', .186, .16, .04, (0, .14, 0), bronze, gun_col, gun, 8, 'Y', .005, math.pi / 8)
    # Heavy octagonal muzzle with dark sleeve.
    ring('Muzzle eight-sided bronze jacket', .225, .138, .12, (0, -.31, 0), bronze, gun_col, gun, 8, 'Y', .012, math.pi / 8)
    ring('Muzzle dark inner sleeve', .142, .12, .13, (0, -.30, 0), dark, gun_col, gun, 32, 'Y', .002)
    ring('Muzzle venom glow ring', .121, .112, .008, (0, -.368, 0), rune, gun_col, gun, 32, 'Y', .001)
    cyl('Muzzle dark throat', .118, .01, (0, -.24, 0), dark, gun_col, gun, 32, 'Y', .001)
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4
        cube('Muzzle jacket seam %02d' % i, (.18 * math.cos(a), -.31, .18 * math.sin(a)), (.006, .124, .02), dark, gun_col, gun, 0, (0, -a, 0)).rotation_euler = (0, -a + math.pi / 2, 0)
    # Recessed lime runes on both upper diagonal faces and top.
    h = .172; w = .172
    for sign in [-1, 1]:
        a2 = Vector((sign * w * .45, 0, h)); b2 = Vector((sign * w, 0, h * .45))
        mid = (a2 + b2) / 2; tang = (b2 - a2).normalized(); nrm = Vector((sign * -tang.z, 0, sign * tang.x))
        if nrm.z < 0: nrm = -nrm
        fr = (mid, Vector((0, -1, 0)), tang * (1 if sign > 0 else 1), nrm)
        dia = [(.03, 0), (.10, .036), (.17, 0), (.10, -.036)]
        ribbon('Barrel rune cutter', dia, .018, .03, fr, None, cut_barrel, gun)
        ribbon('Barrel rune glow', dia, .015, .004, fr, rune, gun_col, gun, lift=-.011)
        # Vertical side face: long angular rune toward the muzzle.
        fr2 = (Vector((sign * w, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((sign, 0, 0)))
        line = [(.03, .05), (.11, .05), (.15, .0), (.19, .0)]
        ribbon('Barrel side rune cutter', line, .018, .03, fr2, None, cut_barrel, gun, closed=False)
        ribbon('Barrel side rune glow', line, .015, .004, fr2, rune, gun_col, gun, closed=False, lift=-.011)
    cut(body, cut_barrel)
    empty('muzzle', gun_col, gun, (0, -.38, 0))

def build_tank():
    # Upright caged glass reservoir standing on the breech, fed into the barrel by a bronze pipe.
    base = gun_to_head((0, .12, .16)); base.z += .0
    cx, cy, z0 = 0, base.y + .02, base.z + LIFT
    tank = empty('venom_tank', tank_col, head, (cx, cy, z0))
    # Cradle bottom follows the 35-degree barrel top so the tank stands level without a tall pillar.
    sad = cyl('Tank cradle', .118, .2, (0, 0, -.07), iron, tank_col, tank, 8, bevel=.008, phase=math.pi / 8)
    slope = math.tan(PITCH)
    for v in sad.data.vertices:
        if v.co.z < 0: v.co.z = -slope * v.co.y - LIFT - .02 + .07
    ring('Tank cradle bronze rim', .126, .1, .028, (0, 0, .02), bronze, tank_col, tank, 8, bevel=.005, phase=math.pi / 8)
    cyl('Tank saddle dark plate', .106, .02, (0, 0, .035), dark, tank_col, tank, 32, bevel=.003)
    cyl('Tank glass wall', .094, .25, (0, 0, .17), glass_m, tank_col, tank, 48, bevel=0)
    cyl('Tank venom liquid', .086, .13, (0, 0, .115), liquid, tank_col, tank, 48, bevel=0)
    for i in range(14):
        a = random.uniform(0, 2 * math.pi); r = random.uniform(.0, .068)
        sphere('Tank bubble %02d' % i, random.uniform(.006, .014), (r * math.cos(a), r * math.sin(a), random.uniform(.06, .18)), bubble, tank_col, tank, 12)
    cyl('Tank top cap', .112, .045, (0, 0, .315), dark, tank_col, tank, 32, bevel=.006)
    ring('Tank top bronze rim', .12, .097, .03, (0, 0, .3), bronze, tank_col, tank, 8, bevel=.005, phase=math.pi / 8)
    cyl('Tank top octagonal plug', .045, .05, (0, 0, .36), bronze, tank_col, tank, 8, bevel=.006, phase=math.pi / 8)
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        s = cube('Tank cage strap %02d' % i, (.105 * math.cos(a), .105 * math.sin(a), .17), (.026, .016, .29), bronze, tank_col, tank, .004)
        s.rotation_euler.z = a + math.pi / 2
        cube('Strap rivet %02d' % i, (.115 * math.cos(a), .115 * math.sin(a), .235), (.016, .012, .016), dark, tank_col, tank, .002, (0, 0, a + math.pi / 2))
    ring('Tank mid band', .11, .097, .02, (0, 0, .2), bronze, tank_col, tank, 32, bevel=.002)
    # Feed pipe: out of the tank's front, over and down into the barrel top.
    entry = gun_to_head((0, -.03, .17)) - Vector((cx, cy, z0))
    curve = bpy.data.curves.new('Feed pipe', 'CURVE'); curve.dimensions = '3D'
    curve.bevel_depth = .022; curve.bevel_resolution = 4; curve.use_fill_caps = True
    sp = curve.splines.new('BEZIER'); sp.bezier_points.add(2)
    pts = [Vector((0, -.09, .25)), Vector((0, -.15, .23)), entry + Vector((0, 0, .025))]
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    sp.bezier_points[0].handle_left_type = sp.bezier_points[0].handle_right_type = 'VECTOR'
    o = bpy.data.objects.new('Feed pipe', curve); tank_col.objects.link(o); o.parent = tank; curve.materials.append(bronze)
    cyl('Pipe tank collar', .032, .03, (0, -.095, .25), dark, tank_col, tank, 24, 'Y', .003)
    cyl('Pipe barrel collar', .034, .03, tuple(entry + Vector((0, 0, .01))), dark, tank_col, tank, 24, bevel=.003)

def build_glob():
    # Venom glob seated in the muzzle; separate object for later animation/flipbook decisions.
    g = sphere('Venom glob', .11, (0, -.30, 0), glob, fx_col, gun, 48)
    g.scale = (1, .92, 1)

def studio():
    scene.render.engine = 'CYCLES'; scene.cycles.samples = 96; scene.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences; prefs.compute_device_type = 'METAL'; prefs.get_devices()
        for d in prefs.devices: d.use = True
        scene.cycles.device = 'GPU'
    except Exception as e: print('GPU unavailable, CPU render:', e)
    scene.render.resolution_x = scene.render.resolution_y = 1200
    w = bpy.data.worlds.new('Muted studio atmosphere'); scene.world = w
    try: w.use_nodes = True
    except Exception: pass
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (.12, .16, .18, 1); bg.inputs[1].default_value = .4
    ground = metal('Studio | desaturated forest', (.015, .032, .026), 0, .92)
    cube('Studio floor', (0, 0, -.011), (200, 200, .02), ground, studio_col, None, 0)
    def light(name, pos, power, size, col):
        d = bpy.data.lights.new(name, 'AREA'); d.energy = power; d.shape = 'DISK'; d.size = size; d.color = col
        o = bpy.data.objects.new(name, d); studio_col.objects.link(o); o.location = pos
        o.rotation_euler = (Vector((0, 0, .4)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    light('Large warm key', (-2, -3, 4), 250, 3, (1, .88, .74))
    light('Soft neutral fill', (3, -1, 2.5), 150, 2.8, (.72, .83, 1))
    light('Bronze rim', (.2, 3, 3), 240, 2, (1, .69, .40))
    d = bpy.data.cameras.new('Camera'); cam = bpy.data.objects.new('Camera', d); studio_col.objects.link(cam)
    d.type = 'ORTHO'; scene.camera = cam
    scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'; scene.view_settings.exposure = -.55
    scene.render.image_settings.file_format = 'PNG'
    img = bpy.data.images.load(str(REF), check_existing=True); img.name = 'REFERENCE — approved concept A'; img.pack(); img.use_fake_user = True
    note = bpy.data.texts.new('START HERE — 독액 박격포')
    note.write('독 포탑 A안(독액 박격포) Blender 디자인 원본. 게임 이관 없음.\n'
               '01 Fixed Base / 02 Rotating Carriage / 03 Mortar Barrel / 04 Venom Tank / 05 Venom Glob 별도 편집.\n'
               '좌표 Z 위, -Y 전방, 받침 지름 .86(화염 포탑과 동일). 포신 고정 앙각 35도.\n'
               '룬 홈은 99 Recess Cutters 컬렉션을 쓰는 비적용 Boolean 모디파이어입니다.\n')

VIEWS = {
    'hero': ((3.2, -3, 2.6), (0, -.035, .50), 1.62),     # same as rune flame turret hero
    'rear': ((-3.0, 3.1, 2.6), (0, .0, .50), 1.62),
    'game': ((0, -2.6, 4.2), (0, 0, .42), 1.3),           # steep game-like view
}

def camera(view, res=1200, path=None):
    loc, target, scale = VIEWS[view]; cam = scene.camera
    cam.location = loc; cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = scale
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.filepath = str(path or OUT / ('venom-mortar-%s.png' % view))

if __name__ == '__main__':
    setup(); build_base(); build_braces(); build_barrel(); build_tank(); build_glob(); studio()
    camera('hero')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'venom-mortar-A.blend'), compress=True)
    import sys
    if '--no-render' not in sys.argv:
        for v in ['hero', 'rear', 'game']:
            camera(v); bpy.ops.render.render(write_still=True)
        camera('hero', 160, OUT / 'venom-mortar-hero-160.png'); scene.cycles.samples = 48; bpy.ops.render.render(write_still=True)
    print('VENOM MORTAR DONE')
