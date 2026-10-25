"""Support core (concept E2) — Blender design source.
Blender -b --factory-startup --python build_support_core.py [-- --no-render]
Inside a live Blender: exec the file, then build_all().

Concept: ../2026-10-25/E2-short-obelisk-conduit.png (packed into the .blend).
A short square obelisk with a bronze crown and a floating cyan crystal, sitting on four thick conduit
arms that end in bronze caps with cyan crystal panes at the tile edges. Four-fold symmetric.
Coordinates: Z up, arms along +X, -X, +Y, -Y, tile width 1.0 (arm caps end at .46).
The forged-metal finish is shared with the rune flame turret (finish_materials.py).
"""
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix
from pathlib import Path

try:
    OUT = Path(__file__).resolve().parent
except NameError:
    OUT = Path('/Users/sejin/Documents/Codex/RuneNexus/design/support_core_concepts/blender')
REF = OUT.parent / '2026-10-25' / 'E2-short-obelisk-conduit.png'
FIRE_FINISH = OUT.parents[1] / 'fire_tower_concepts' / 'runic_3d' / 'finish_materials.py'

CYAN = (.05, .79, .67)           # #3FE6D6 in linear
PLINTH_S, PLINTH_H = .215, .045   # central square slab half side / height
ARM_W, ARM_TOP = .21, .13        # conduit beam width / top height
ARM_IN, ARM_OUT = .10, .355      # beam runs from inside the obelisk to the collar
COLLAR = (.348, .374)
CAP = (.37, .46)                 # end cap reaches the tile edge
CAP_W, CAP_H = .25, .18
OB_Z0, OB_Z1 = PLINTH_H, .37     # obelisk body
OB_R0, OB_R1 = .17, .08        # half side at foot / top
OB_CH = .26                      # corner chamfer as a fraction of the half side
CROWN_Z = (.35, .41)
CRYSTAL_Z, CRYSTAL_UP, CRYSTAL_DN, CRYSTAL_R = .55, .115, .07, .046


# ---------------------------------------------------------------- helpers
def collection(name):
    c = bpy.data.collections.new(name); scene.collection.children.link(c); return c

def empty(name, coll, parent=None, rot_z=0):
    o = bpy.data.objects.new(name, None); coll.objects.link(o); o.parent = parent; o.rotation_euler.z = rot_z; return o

def finish(o, mat, bevel, segments=3, angle=35):
    if mat: o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new('Machined bevel', 'BEVEL'); b.width = bevel; b.segments = segments
        b.limit_method = 'ANGLE'; b.angle_limit = math.radians(angle)
        w = o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL'); w.keep_sharp = True; w.weight = 40
    return o

def from_bm(name, bm, mat, coll, parent=None, bevel=0, **kw):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = bpy.data.meshes.new(name); bm.to_mesh(m); bm.free()
    o = bpy.data.objects.new(name, m); coll.objects.link(o); o.parent = parent
    return finish(o, mat, bevel, **kw)

def box(name, x, y, z, mat, coll, parent=None, bevel=.006, **kw):
    """Axis-aligned box from (min, max) ranges in the parent's space."""
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(x[1] - x[0], y[1] - y[0], z[1] - z[0]), verts=bm.verts)
    bmesh.ops.translate(bm, vec=((x[0] + x[1]) / 2, (y[0] + y[1]) / 2, (z[0] + z[1]) / 2), verts=bm.verts)
    return from_bm(name, bm, mat, coll, parent, bevel, **kw)

def prism(name, pts, axis, a0, a1, mat, coll, parent=None, bevel=.006, **kw):
    """Extrude a 2D loop. axis 'Y': pts are (x, z) over y in [a0, a1]; 'X': (y, z) over x; 'Z': (x, y) over z."""
    def p3(u, v, a): return {'Y': (u, a, v), 'X': (a, u, v), 'Z': (u, v, a)}[axis]
    bm = bmesh.new()
    lo = [bm.verts.new(p3(u, v, a0)) for u, v in pts]; hi = [bm.verts.new(p3(u, v, a1)) for u, v in pts]
    n = len(pts); bm.faces.new(lo); bm.faces.new(list(reversed(hi)))
    for i in range(n):
        j = (i + 1) % n; bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return from_bm(name, bm, mat, coll, parent, bevel, **kw)

def loft(name, sections, mat, coll, parent=None, bevel=.006, cap=True, **kw):
    """Loft equal-length closed loops of 3D points."""
    bm = bmesh.new(); rings = [[bm.verts.new(p) for p in s] for s in sections]; n = len(sections[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n; bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap: bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    return from_bm(name, bm, mat, coll, parent, bevel, **kw)

def octagon(r, ch, z):
    """Square of half side r with chamfered corners (ch * r), faces facing the arms."""
    c = r * (1 - ch); pts = []
    for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        if sx * sy > 0: pts += [(sx * r, sy * c, z), (sx * c, sy * r, z)]
        else: pts += [(sx * c, sy * r, z), (sx * r, sy * c, z)]
    return pts

def ridge(name, half, d0, d1, crest, za, zb, apex, mat, coll, parent, bevel=.008, **kw):
    """Bronze pillar whose outer face folds to a centre ridge. Local X runs outward (d), Y across (half).
    Flat end at za, straight section to zb, then a pyramid to apex (above or below); apex=None gives a flat end."""
    sec = [(d0, -half), (d1, -half), (d1 + crest, 0), (d1, half), (d0, half)]
    bm = bmesh.new()
    ra = [bm.verts.new((d, u, za)) for d, u in sec]; rb = [bm.verts.new((d, u, zb)) for d, u in sec]
    for k in range(5):
        j = (k + 1) % 5; bm.faces.new((ra[k], ra[j], rb[j], rb[k]))
    bm.faces.new(ra)
    if apex is None: bm.faces.new(rb)
    else:
        tip = bm.verts.new(((d0 + d1 + crest) / 2, 0, apex))
        for k in range(5): bm.faces.new((rb[k], rb[(k + 1) % 5], tip))
    return from_bm(name, bm, mat, coll, parent, bevel, **kw)

def strip(name, a, b, width, depth, frame, mat, coll, parent=None, lift=0.0):
    """Straight groove/inlay segment on a face. frame=(origin, u, v, n): a, b are (u, v); depth goes along -n."""
    o, u, v, n = frame
    pa = o + u * a[0] + v * a[1]; pb = o + u * b[0] + v * b[1]
    t = (pb - pa).normalized(); s = n.cross(t).normalized() * (width / 2)
    ext = t * (width / 2)
    top = n * lift; bot = -n * depth
    quad = [pa - ext - s, pb + ext - s, pb + ext + s, pa - ext + s]
    bm = bmesh.new()
    lo = [bm.verts.new(q + bot) for q in quad]; hi = [bm.verts.new(q + top) for q in quad]
    bm.faces.new(list(reversed(lo))); bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4; bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return from_bm(name, bm, mat, coll, parent)

def cut(target, cutters):
    b = target.modifiers.new('Rune recesses', 'BOOLEAN'); b.operation = 'DIFFERENCE'
    b.operand_type = 'COLLECTION'; b.collection = cutters; b.solver = 'EXACT'
    for c in cutters.all_objects: c.display_type = 'WIRE'; c.hide_render = True
    # Bevel first, then cut, so grooves stay crisp (same order as the turret sources).
    target.modifiers.move(target.modifiers.find(b.name), 1 if 'Machined bevel' in target.modifiers else 0)
    # The exact solver leaves a few zero-area slivers where grooves meet bevel loops; weld them away.
    w = target.modifiers.new('Weld boolean slivers', 'WELD'); w.merge_threshold = .0003
    target.modifiers.move(target.modifiers.find(w.name), target.modifiers.find(b.name) + 1)

def cutter_coll(name):
    c = bpy.data.collections.new(name); cutters_root.children.link(c); return c


# ---------------------------------------------------------------- materials
def node_mat(name):
    m = bpy.data.materials.new(name)
    try: m.use_nodes = True
    except Exception: pass
    return m, next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')

def plain_metal(name, col, metallic, rough):
    """Placeholder; the shared forged-metal finish replaces the node tree."""
    m, p = node_mat(name)
    p.inputs['Base Color'].default_value = (*col, 1); p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = rough; return m

def emissive(name, col, strength, rough=.3):
    m, p = node_mat(name)
    p.inputs['Base Color'].default_value = (*col, 1); p.inputs['Emission Color'].default_value = (*col, 1)
    p.inputs['Emission Strength'].default_value = strength; p.inputs['Roughness'].default_value = rough; return m

def crystal_mat(name, strength, glow=CYAN, clear=False):
    """Faceted cyan crystal: glossy coat over an inner glow so facets still read. clear: a transmissive cyan
    gem (refracts what is behind it); the game gives it the matching glass shader."""
    m, p = node_mat(name)
    p.inputs['Base Color'].default_value = (.04, .58, .52, 1); p.inputs['Roughness'].default_value = .05
    p.inputs['Coat Weight'].default_value = 1; p.inputs['Coat Roughness'].default_value = .02
    p.inputs['Emission Color'].default_value = (*glow, 1); p.inputs['Emission Strength'].default_value = strength
    if clear:
        p.inputs['Base Color'].default_value = (.32, .95, .88, 1); p.inputs['Roughness'].default_value = .02
        p.inputs['Transmission Weight'].default_value = 1; p.inputs['IOR'].default_value = 1.6
    return m

def apply_metal_finish():
    ns = {}; exec(compile(FIRE_FINISH.read_text(), str(FIRE_FINISH), 'exec'), ns)
    # Concept E2 bronze is a muted olive-tan, darker than the flame turret's warm alloy.
    ns['PROFILES']['Bronze | worn warm alloy'].update({
        'low': (.13, .068, .024, 1), 'high': (.34, .2, .07, 1), 'wear': (.68, .47, .24, 1), 'rough': (.5, .7),
        'metal': .62, 'crack': .0005, 'edge': .007})
    # Its arm and obelisk stone is a lighter slate than the turret's charcoal iron.
    ns['PROFILES']['Iron | forged charcoal'].update({'low': (.05, .055, .065, 1), 'high': (.12, .13, .15, 1), 'wear': (.28, .29, .31, 1), 'crack': .0004})
    result = ns['apply_material_finish'](scene)
    # The cap and arm faces are much larger than turret plates; full-strength crevice patina read as cracked mud.
    # Bronze keeps a little more so its faces do not read as polished brass at game distance.
    for m, shade in ((bronze, .74), (iron, .84)):
        r = m.node_tree.nodes.get('Shallow crevice patina')
        if r: r.color_ramp.elements[0].color = (shade, shade, shade, 1)
    # E2 bronze shows brightly worn edges against the broad faces.
    r = bronze.node_tree.nodes.get('Restrained bright worn edge')
    if r: r.color_ramp.elements[0].color = (.95, .95, .95, 1); r.color_ramp.elements[0].position = .76
    return result


# ---------------------------------------------------------------- parts
def setup():
    global scene, root, base_col, ob_col, crown_col, studio_col, cutters_root
    global iron, bronze, dark, edge, rune, pane, crystal, crystal_side, crystal_heart, disk
    scene = bpy.context.scene; scene.name = 'Support Core E2 — Design'
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections): bpy.data.collections.remove(c)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for d in list(block):
            if d.users == 0: block.remove(d)
    base_col = collection('01 Base & Conduit Arms'); ob_col = collection('02 Obelisk')
    crown_col = collection('03 Crown & Crystal'); studio_col = collection('90 Studio')
    cutters_root = collection('99 Recess Cutters'); cutters_root.hide_render = True
    root = empty('support_core_root', base_col)
    iron = plain_metal('Iron | forged charcoal', (.06, .066, .078), .8, .52)
    bronze = plain_metal('Bronze | worn warm alloy', (.5, .26, .1), .78, .45)
    dark = plain_metal('Recess | dark gunmetal', (.015, .02, .026), .67, .5)
    edge = plain_metal('Steel | polished bevel detail', (.12, .14, .16), .88, .3)
    rune = emissive('Runes | support cyan', (.01, .5, .43), .9)
    pane = crystal_mat('Crystal | cap panes', .8)
    # Paler cyan than the channels so the floating crystal stays separate where it overlaps an arm from above.
    # A clear shell over a bright heart, like the concept's crystal lit from inside.
    crystal = crystal_mat('Crystal | floating core', .25, (.3, .95, .88), clear=True)
    crystal_side = crystal_mat('Crystal | floating core sides', .08, clear=True)
    crystal_heart = crystal_mat('Crystal | floating heart', 5.0, (.35, 1.0, .92))
    disk = emissive('Crown | glow well', (.01, .5, .43), .6)

def build_base():
    plinth = box('Central plinth slab', (-PLINTH_S, PLINTH_S), (-PLINTH_S, PLINTH_S), (0, PLINTH_H), iron, base_col, root, .012)
    cuts = cutter_coll('cutters | plinth')
    # Single seam ring on the slab top so it reads as a fitted stone, not a bare box.
    top = (Vector((0, 0, PLINTH_H)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    r = PLINTH_S - .035
    for a, b in (((-r, -r), (r, -r)), ((r, -r), (r, r)), ((r, r), (-r, r)), ((-r, r), (-r, -r))):
        strip('plinth seam', a, b, .007, .006, top, None, cuts, None, .01)
    cut(plinth, cuts)

def build_arm(i):
    arm = empty('conduit_arm_%d' % i, base_col, root, i * math.pi / 2)
    hw = ARM_W / 2
    beam = box('Conduit beam %d' % i, (ARM_IN, ARM_OUT), (-hw, hw), (.02, ARM_TOP), iron, base_col, arm, .01)
    # Bronze footing strips along both lower edges (concept: thin bronze line at the ground).
    for s in (-1, 1):
        box('Footing strip %d%s' % (i, 'LR'[s > 0]), (.29, COLLAR[0] + .005), sorted((s * (hw - .006), s * (hw + .016))),
            (0, .036), bronze, base_col, arm, .005)
    box('Footing plate %d' % i, (.18, CAP[0]), (-hw - .006, hw + .006), (0, .022), dark, base_col, arm, .004)
    cuts = cutter_coll('cutters | arm %d' % i)
    # Wide glowing channel on the beam top: one closed outline that jogs diagonally and narrows toward the
    # obelisk, sunk inside a slightly wider shallow lip so a dark rim frames the light.
    def channel(d):
        a, b, c, xe, xr = .035 + d, .017 + d, .017, ARM_OUT + .03, .17 - d
        return [(xe, -a), (xe, a), (.27, a), (.25, c + b), (xr, c + b), (xr, c - b), (.235, c - b), (.262, -a)]
    prism('channel lip cut', channel(.007), 'Z', ARM_TOP - .005, ARM_TOP + .02, None, cuts, arm, 0)
    prism('channel cut', channel(0), 'Z', ARM_TOP - .018, ARM_TOP + .02, None, cuts, arm, 0)
    prism('Channel glow %d' % i, channel(-.003), 'Z', ARM_TOP - .03, ARM_TOP - .01, rune, base_col, arm, 0)
    # Rune engraving on both side faces: a long bowtie (X between two uprights) and a mid seam.
    for s in (-1, 1):
        side = (Vector((0, s * hw, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, s, 0)))
        x0, x1, z0, z1 = .235, .335, .058, .108
        for a, b in (((x0, z0), (x1, z1)), ((x0, z1), (x1, z0)), ((x0, z0), (x0, z1)), ((x1, z0), (x1, z1))):
            strip('rune cut', a, b, .008, .006, side, None, cuts, arm, .01)
        strip('seam cut', (.215, .03), (.215, ARM_TOP + .01), .006, .006, side, None, cuts, arm, .01)
    cut(beam, cuts)
    # Root clamps: bronze ears on both beam edges where the arm leaves the obelisk, continuing as a low band
    # along the beam so they bind the arm instead of standing as loose wedges.
    for s in (-1, 1):
        prism('Root clamp %d%s' % (i, 'LR'[s > 0]), [(.13, .015), (.30, .015), (.30, .05), (.21, .05), (.21, ARM_TOP + .012), (.13, ARM_TOP + .042)],
              'Y', *sorted((s * (hw - .034), s * (hw + .016))), bronze, base_col, arm, .009, segments=1)
    build_cap(i, arm)

def build_cap(i, arm):
    """Layered end cap: a binding rim against the beam, two heavy side slabs, a sill and lintel framing a dark
    crystal housing, with a large outward pane and a wide top window."""
    hw = CAP_W / 2; x0, x1 = CAP; inner = .069
    box('Cap binding rim %d' % i, (x0 - .024, x0 + .022), (-hw + .004, hw - .004), (0, CAP_H - .022), bronze, base_col, arm, .012, segments=1)
    for s in (-1, 1):
        box('Cap side slab %d%s' % (i, 'LR'[s > 0]), (x0 + .012, x1), sorted((s * (inner - .001), s * hw)), (0, CAP_H),
            bronze, base_col, arm, .011, segments=1)
    # Sill and lintel run into the side slabs so the shell reads as one bowl around the housing.
    box('Cap sill %d' % i, (x0 + .02, x1), (-inner - .02, inner + .02), (0, .038), bronze, base_col, arm, .008, segments=1)
    box('Cap lintel %d' % i, (x1 - .018, x1), (-inner - .02, inner + .02), (CAP_H - .03, CAP_H - .004), bronze, base_col, arm, .006, segments=1)
    box('Crystal housing %d' % i, (x0 + .02, x1 - .012), (-inner, inner), (.036, CAP_H - .012), dark, base_col, arm, .004)
    # Faceted crystal panes: low pyramids so highlights break across facets.
    pz = (.038 + CAP_H - .03) / 2
    facet('Cap pane %d' % i, Vector((x1 - .012, 0, pz)), Vector((1, 0, 0)), Vector((0, 1, 0)), .052, .048, .016, arm)
    facet('Cap window %d' % i, Vector(((x0 + .02 + x1 - .018) / 2, 0, CAP_H - .012)), Vector((0, 0, 1)), Vector((0, 1, 0)), .05, .022, .012, arm)

def facet(name, centre, n, u, half_u, half_v, height, parent):
    """Rectangular crystal pane: bevelled frame ring plus a shallow pyramid face."""
    v = n.cross(u); bm = bmesh.new()
    corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
    outer = [bm.verts.new(centre + u * a * half_u + v * b * half_v) for a, b in corners]
    mid = [bm.verts.new(centre + n * (height * .6) + u * a * half_u * .55 + v * b * half_v * .55) for a, b in corners]
    tip = bm.verts.new(centre + n * height)
    for k in range(4):
        j = (k + 1) % 4
        bm.faces.new((outer[k], outer[j], mid[j], mid[k])); bm.faces.new((mid[k], mid[j], tip))
    bm.faces.new(list(reversed(outer)))
    return from_bm(name, bm, pane, base_col, parent)

def build_obelisk():
    slope = (OB_R0 - OB_R1) / (OB_Z1 - OB_Z0)
    # The buried foot continues the same slope so the rune frames (based at OB_Z0) sit on the real face.
    body = loft('Obelisk body', [octagon(OB_R0 + slope * .01, OB_CH, OB_Z0 - .01), octagon(OB_R1, OB_CH, OB_Z1)], iron, ob_col, root, .008)
    cuts = cutter_coll('cutters | obelisk')
    for i in range(4):
        rot = Matrix.Rotation(i * math.pi / 2, 3, 'Z')
        # Face frame: u across the face, v up the slanted face, n outward.
        v = (rot @ Vector((-slope, 0, 1))).normalized(); n = (rot @ Vector((1, 0, slope))).normalized()
        u = n.cross(v).normalized()
        o = rot @ Vector((OB_R0, 0, OB_Z0))
        frame = (o, u, v, n); glow = (o - n * .007, u, v, n)
        d = .044; zc = .185
        segs = [((0, .1), (0, zc - d)), ((0, zc + d), (0, .295)),
                ((0, zc - d), (d * .8, zc)), ((d * .8, zc), (0, zc + d)), ((0, zc + d), (-d * .8, zc)), ((-d * .8, zc), (0, zc - d))]
        for a, b in segs:
            strip('face rune cut', a, b, .016, .014, frame, None, cuts, None, .01)
            strip('Face rune glow %d' % i, a, b, .012, .006, glow, rune, ob_col, root)
        # Horizontal course seams across the face.
        for zz in (.07, .265):
            w = OB_R0 - slope * zz
            strip('course seam', (-w * .62, zz), (w * .62, zz), .006, .006, frame, None, cuts, None, .01)
    cut(body, cuts)
    # Bronze buttresses on the four corners: pointed shields leaning on the obelisk.
    for i in range(4):
        corner = empty('corner_buttress_%d' % i, ob_col, root, math.pi / 4 + i * math.pi / 2)
        r0 = OB_R0 * (1 - OB_CH / 2) * math.sqrt(2) * .78
        ridge('Corner buttress %d' % i, .034, r0 - .03, r0 + .032, .016, .13, .235, .285, bronze, ob_col, corner, .008, segments=1)
        ridge('Buttress foot %d' % i, .043, r0 - .02, r0 + .052, .02, PLINTH_H - .005, .135, None, bronze, ob_col, corner, .01, segments=1)

def build_crown():
    z0, z1 = CROWN_Z
    ring = loft('Crown collar', [octagon(.076, .3, z0), octagon(.079, .3, z1)], dark, crown_col, root, .006)
    cuts = cutter_coll('cutters | crown')
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=.05, radius2=.05, depth=.06)
    bmesh.ops.translate(bm, vec=(0, 0, z1), verts=bm.verts); from_bm('well cut', bm, None, cuts)
    # Bronze band tying the crown blocks into one ring.
    # Tall enough that the blocks rise from one continuous bronze rim instead of standing apart.
    loft('Crown band', [octagon(.094, .3, z0 - .004), octagon(.094, .3, z1 - .006)], bronze, crown_col, root, .006, segments=1)
    cut(ring, cuts)
    # Low faceted glow gem seated on the rim instead of a flat disc, so its shoulders show under the crystal.
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=.046, radius2=.012, depth=.022)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.pi / 8, 3, 'Z'))
    bmesh.ops.translate(bm, vec=(0, 0, z1 + .012), verts=bm.verts); from_bm('Crown glow well', bm, disk, crown_col, root)
    # Eight chunky bronze blocks: large pointed shields on the corners, short blocks over the arm faces.
    for i in range(4):
        big = empty('crown_shield_%d' % i, crown_col, root, math.pi / 4 + i * math.pi / 2)
        r = .088 * (1 - .15) * math.sqrt(2)
        ridge('Crown shield %d' % i, .042, r - .035, r + .02, .014, z1 + .014, z0, z0 - .026, bronze, crown_col, big, .007, segments=1)
        small = empty('crown_block_%d' % i, crown_col, root, i * math.pi / 2)
        box('Crown block %d' % i, (.066, .116), (-.04, .04), (z0 + .006, z1 + .01), bronze, crown_col, small, .009, segments=1)

def gem(name, r, up, dn, tiers, mat, parent, twist=0.0, bevel=0):
    """Faceted bipyramid. tiers: (z, corner radius, edge-midpoint radius) rings from bottom to top; corners
    point along the diagonals (like the obelisk), midpoints sit between them, so each side breaks into two
    facets per tier and catches separate highlights."""
    bm = bmesh.new()
    rings = []
    for z, rc, rm in tiers:
        ring = []
        for k in range(8):
            a = math.pi / 4 + k * math.pi / 4 + twist
            rr = (rc if k % 2 == 0 else rm) * r
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    bot = bm.verts.new((0, 0, -dn)); top = bm.verts.new((0, 0, up))
    for k in range(8):
        j = (k + 1) % 8
        bm.faces.new((rings[0][j], rings[0][k], bot)); bm.faces.new((rings[-1][k], rings[-1][j], top))
        for lo, hi in zip(rings, rings[1:]): bm.faces.new((lo[k], lo[j], hi[j], hi[k]))
    o = from_bm(name, bm, mat, crown_col, parent, bevel, segments=1, angle=12)
    return o

def build_crystal():
    # Elongated bipyramid as in the concept: a tall crown of two facet tiers over a short girdle band and a
    # shorter pavilion. The shell is clear; a bright heart inside lights it, and three small shards float
    # around it (they spin with the crystal in game).
    r, up, dn = CRYSTAL_R, CRYSTAL_UP, CRYSTAL_DN
    tiers = [(-dn * .5, .58, .5), (0, 1, .84), (.018, .95, .8), (up * .45, .6, .5)]
    o = gem('core_crystal', r, up, dn, tiers, crystal, root); o.location.z = CRYSTAL_Z
    # Girdle and lower facets glow less than the crown facets so the crystal keeps an outline over the arms.
    o.data.materials.append(crystal_side)
    for f in o.data.polygons: f.material_index = 1 if f.center.z < .012 else 0
    # The heart turns half a facet against the shell so its edges show between the shell's.
    gem('Crystal heart', r * .56, up * .62, dn * .66, [(0, 1, .8), (up * .22, .62, .5)], crystal_heart, o, twist=math.pi / 8)
    for k, (angle, z, tilt) in enumerate([(25, .03, .5), (145, -.025, -.4), (265, .005, .3)]):
        a = math.radians(angle)
        s = gem('Crystal shard %d' % k, r * .26, up * .26, dn * .26, [(0, 1, .8)], crystal, o, twist=a)
        s.location = (.088 * math.cos(a), .088 * math.sin(a), z)
        s.rotation_euler = (tilt * math.sin(a), -tilt * math.cos(a), 0)
        s.data.materials.append(crystal_side)
        for f in s.data.polygons: f.material_index = 1 if f.center.z < 0 else 0

# ---------------------------------------------------------------- studio
def studio():
    scene.render.engine = 'CYCLES'; scene.cycles.samples = 128; scene.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences; prefs.compute_device_type = 'METAL'; prefs.get_devices()
        for d in prefs.devices: d.use = True
        scene.cycles.device = 'GPU'
    except Exception as e: print('GPU unavailable, CPU render:', e)
    w = bpy.data.worlds.new('Dark blue-gray studio'); scene.world = w
    try: w.use_nodes = True
    except Exception: pass
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND'); bg.inputs[0].default_value = (.02, .03, .055, 1); bg.inputs[1].default_value = .5
    gm, p = node_mat('Studio | blue-gray floor')
    p.inputs['Base Color'].default_value = (.012, .02, .045, 1); p.inputs['Roughness'].default_value = .9
    p.inputs['Specular IOR Level'].default_value = 0   # grazing light reflections turned the navy floor gray
    box('Studio floor', (-100, 100), (-100, 100), (-.02, 0), gm, studio_col, None, 0)
    def light(name, pos, power, size, col):
        d = bpy.data.lights.new(name, 'AREA'); d.energy = power; d.shape = 'DISK'; d.size = size; d.color = col
        o = bpy.data.objects.new(name, d); studio_col.objects.link(o); o.location = pos
        o.rotation_euler = (Vector((0, 0, .2)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    light('Large warm key', (-3.2, -1.4, 4), 470, 2.6, (1, .9, .78))
    light('Soft neutral fill', (1.2, -3.2, 2.5), 130, 2.8, (.72, .83, 1))
    light('Bronze rim', (2.6, 2.6, 3), 230, 2, (1, .85, .70))
    d = bpy.data.cameras.new('Camera'); cam = bpy.data.objects.new('Camera', d); studio_col.objects.link(cam); scene.camera = cam
    scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'; scene.view_settings.exposure = -.5
    scene.render.image_settings.file_format = 'PNG'
    if 'REFERENCE — approved concept E2' not in bpy.data.images:
        img = bpy.data.images.load(str(REF), check_existing=True); img.name = 'REFERENCE — approved concept E2'; img.pack(); img.use_fake_user = True
    note = bpy.data.texts.get('START HERE — 지원 코어 E2') or bpy.data.texts.new('START HERE — 지원 코어 E2')
    note.clear()
    note.write('지원 코어 E2 시안의 Blender 디자인 원본. 게임 이관 없음.\n'
               '01 Base & Conduit Arms(팔 4개는 conduit_arm_0~3 아래, 같은 치수) / 02 Obelisk / 03 Crown & Crystal(core_crystal).\n'
               '좌표 Z 위, 팔은 ±X·±Y, 타일 폭 1.0(끝 캡 바깥면 .46).\n'
               '금속 재질은 화염 포탑 finish_materials.py의 단조 마감을 공유한다. 청록 #3FE6D6.\n')

# elevation 40 degrees; azimuth 45 puts an obelisk corner toward the camera like the concept.
def _orbit(az, el, dist, target=(0, 0, .19)):
    t = Vector(target); a, e = math.radians(az), math.radians(el)
    return tuple(t + Vector((-math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist), target

VIEWS = {
    'hero': (*_orbit(45, 38, 3.6), 110, 'PERSP'),
    'axis': (*_orbit(0, 30, 3.6), 110, 'PERSP'),
    'game': ((0, -2.6, 4.2), (0, .0, .15), 1.25, 'ORTHO'),
    'crystal': (*_orbit(45, 24, 1.6, (0, 0, .54)), 160, 'PERSP'),
}

def camera(view, res=1200, path=None):
    loc, target, scale, proj = VIEWS[view]; cam = scene.camera
    cam.location = loc; cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if proj == 'PERSP':
        cam.data.type = 'PERSP'; cam.data.lens = scale; cam.data.sensor_fit = 'HORIZONTAL'; cam.data.sensor_width = 36
    else:
        cam.data.type = 'ORTHO'; cam.data.ortho_scale = scale
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.filepath = str(path or OUT / ('support-core-%s.png' % view))

def triangles():
    dg = bpy.context.evaluated_depsgraph_get(); t = 0
    for o in scene.objects:
        if o.type == 'MESH' and not o.hide_render and o.name != 'Studio floor' and not o.users_collection[0].name.startswith('cutters'):
            e = o.evaluated_get(dg); m = e.to_mesh(); m.calc_loop_triangles(); t += len(m.loop_triangles); e.to_mesh_clear()
    return t

def build_all():
    setup(); build_base()
    for i in range(4): build_arm(i)
    build_obelisk(); build_crown(); build_crystal(); studio(); apply_metal_finish()
    camera('hero')

if __name__ == '__main__':
    build_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'support-core-E2.blend'), compress=True)
    print('TRIANGLES', triangles())
    if '--no-render' not in sys.argv:
        views = [a for a in sys.argv[sys.argv.index('--') + 1:] if a in VIEWS] if '--' in sys.argv else []
        for v in views or ['hero', 'axis', 'game', 'crystal']:
            camera(v); bpy.ops.render.render(write_still=True)
        if not views:
            camera('hero', 160, OUT / 'support-core-hero-160.png'); scene.cycles.samples = 48; bpy.ops.render.render(write_still=True)
        camera('hero')
    print('SUPPORT CORE E2 DONE')
