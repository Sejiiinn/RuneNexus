"""Chapter 3 floating broken girders. Independent background Blender; no runtime export.

Run: Blender --background --python build_girders.py [-- --render] [--game]
--game writes the lightweight game-distance copy (floating-girders-game.blend) with the
same seeds, outline and damage, and fewer bevel/slice/cylinder segments.
Reuses the approved chapter 3 tile materials (chapter3-thick-tiles.blend) and the
prop library's bevel/normal conventions. Source concept:
../../environment_concepts/outrigger-floating/stage11-outrigger-floating-v1.png
"""
import bpy, bmesh, math, json, random, sys
from pathlib import Path
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
TILES = HERE.parents[1] / 'tiles/chapter3-thick-tiles.blend'
CONCEPT = 'design/chapter3_3d/environment_concepts/outrigger-floating/stage11-outrigger-floating-v1.png'
PI = math.pi
M = {}
# Source vs game-distance detail. Shape, seeds and damage are identical in both.
Q = {'bevel_segments': 2, 'slices': 16, 'tip_slices': 5, 'hole_vertices': 20, 'rivet_vertices': 12}
GAME_Q = {'bevel_segments': 1, 'slices': 8, 'tip_slices': 3, 'hole_vertices': 10, 'rivet_vertices': 8}

# I-beam section in tile units (1 = one battlefield tile).
H, B, TF, TW = .17, .112, .022, .017


def finish(o, mat, parent, bev=.004):
    o.parent = parent
    o.data.materials.append(mat)
    o.data.materials.append(M['edge'])
    if bev:
        m = o.modifiers.new('Rounded worn steel edges', 'BEVEL')
        m.width = bev; m.segments = Q['bevel_segments']; m.material = 1; m.limit_method = 'ANGLE'
    o.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    return o


def bm_object(name, bm, mat, parent, bev=.004):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    return finish(o, mat, parent, bev)


def prism(outline, plane, t0, t1):
    """Extrude a closed 2D outline. plane 'xz': thickness along Y; 'xy': along Z."""
    bm = bmesh.new()
    p3 = (lambda a, b, t: (a, t, b)) if plane == 'xz' else (lambda a, b, t: (a, b, t))
    lo = [bm.verts.new(p3(a, b, t0)) for a, b in outline]
    hi = [bm.verts.new(p3(a, b, t1)) for a, b in outline]
    bm.faces.new(lo); bm.faces.new(hi)
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return bm


def slice_along_x(bm, xs):
    for x in xs:
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(x, 0, 0), plane_no=(1, 0, 0))


def torn_edge(x, a, b, rng, outward):
    """Jagged fracture from a to b across the section at length x; outward is +1/-1."""
    pts = []
    steps = 5
    slant = rng.uniform(.03, .07) * rng.choice((-1, 1))  # torn diagonally, not sawn square
    for i in range(1, steps):
        t = i / steps
        tooth = (.03 if i % 2 else -.012) * rng.uniform(.3, 1.0)
        pts.append((x + outward * (tooth - abs(slant) * .5 + slant * (t - .5)), a + (b - a) * t))
    return pts


def curl(bm, start, amount, pivot_z):
    """Peel the torn tip away from the web: rotate verts beyond x=start about a Y axis."""
    for v in bm.verts:
        d = v.co.x - start
        if d > 0:
            pivot = Vector((start, v.co.y, pivot_z))
            v.co = pivot + Matrix.Rotation(-amount * d * math.copysign(1, pivot_z), 3, 'Y') @ (v.co - pivot)


def beam_part(name, kind, x0, x1, torn0, torn1, rng, parent, tip_curl, slices):
    """kind: 'web' | 'top' | 'bottom'. Fracture faces get the cooling-heat slot."""
    a, b = (-H / 2 + TF - .001, H / 2 - TF + .001) if kind == 'web' else (-B / 2, B / 2)
    if torn1:
        end = [(x1 - rng.uniform(0, .03), a)] + torn_edge(x1, a, b, rng, 1) + [(x1 - rng.uniform(0, .03), b)]
    else:
        end = [(x1, a), (x1, b)]
    if torn0:
        start = [(x0 + rng.uniform(0, .03), b)] + list(reversed(torn_edge(x0, a, b, rng, -1))) + [(x0 + rng.uniform(0, .03), a)]
    else:
        start = [(x0, b), (x0, a)]
    outline = end + start
    if kind == 'web':
        bm = prism(outline, 'xz', -TW / 2, TW / 2)
    elif kind == 'top':
        bm = prism(outline, 'xy', H / 2 - TF, H / 2)
    else:
        bm = prism(outline, 'xy', -H / 2, -H / 2 + TF)
    slice_along_x(bm, slices + [x1 - .12 + i * .12 / Q['tip_slices'] for i in range(Q['tip_slices'])])
    if tip_curl and torn1 and kind != 'web':
        curl(bm, x1 - .12, tip_curl, H / 2 if kind == 'top' else -H / 2)
    bm.normal_update()
    o = bm_object(name, bm, M['beam'], parent)
    o.data.materials.append(M['torn'])
    for f in o.data.polygons:
        c = f.center
        torn_face = (torn1 and c.x > x1 - .06) or (torn0 and c.x < x0 + .06)
        if torn_face and abs(f.normal.x) > .3:
            f.material_index = 2
    return o


def holes(o, xs, r=.017):
    """Real through holes in the web (boolean), applied before bevel/normals."""
    bpy.context.view_layer.objects.active = o
    for i, x in enumerate(xs):
        bpy.ops.mesh.primitive_cylinder_add(vertices=Q['hole_vertices'], radius=r, depth=.08, location=(x, 0, 0), rotation=(PI / 2, 0, 0))
        c = bpy.context.object
        bpy.context.view_layer.objects.active = o
        b = o.modifiers.new('Web bolt hole %d' % i, 'BOOLEAN'); b.operation = 'DIFFERENCE'; b.object = c; b.solver = 'EXACT'
        while o.modifiers.find(b.name) > 0:
            bpy.ops.object.modifier_move_up(modifier=b.name)
        bpy.ops.object.modifier_apply(modifier=b.name)
        bpy.data.objects.remove(c, do_unlink=True)
    # The cutter brings an empty slot; hole walls use the beam steel.
    empty = [i for i, m in enumerate(o.data.materials) if m is None]
    for f in o.data.polygons:
        if f.material_index in empty:
            f.material_index = 0
    for i in reversed(empty):
        o.data.materials.pop(index=i)


def cyl(name, c, r, d, mat, parent, axis=(0, 0, 1), n=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=r, depth=d, location=c)
    o = bpy.context.object; o.name = name
    o.rotation_euler = Vector(axis).to_track_quat('Z', 'Y').to_euler()
    return finish(o, mat, parent, .0012)


def end_plate(parent, x):
    bm = bmesh.new()
    w, h, t = B / 2 + .014, H / 2 + .014, .016
    vs = [bm.verts.new((x + dx, dy, dz)) for dx in (0, t) for dy in (-w, w) for dz in (-h, h)]
    for f in [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]:
        bm.faces.new([vs[i] for i in f])
    bm_object('girder clean-cut bolted end plate', bm, M['plate'], parent, .003)
    for dy in (-.035, .035):
        for dz in (-.052, .052):
            cyl('end plate bolt', (x - .005, dy, dz), .012, .01, M['bolt'], parent, (-1, 0, 0), 6)


def girder(name, length, seed, torn_both, tip_curl, bend, twist, hole_xs):
    rng = random.Random(seed)
    root = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(root)
    root['approved_reference'] = CONCEPT
    root['contract'] = 'floating_debris_v1: origin at beam centre, no mount, 1 unit = 1 tile'
    x0, x1 = -length / 2, length / 2
    slices = [x0 + length * i / Q['slices'] for i in range(1, Q['slices'])] if (bend or twist) else []
    bottom_x0 = x0 + (rng.uniform(.01, .04) if torn_both else 0)
    parts = [
        beam_part(name + ' web', 'web', x0 + .004, x1 - .03, torn_both, True, rng, root, 0, slices),
        beam_part(name + ' top flange', 'top', x0, x1, torn_both, True, rng, root, tip_curl, slices),
        beam_part(name + ' bottom flange', 'bottom', bottom_x0, x1 - .05, torn_both, True, rng, root, tip_curl * .7, slices),
    ]
    if hole_xs:
        holes(parts[0], hole_xs)
    if not torn_both:
        end_plate(root, x0 - .016)
    rx = x0 + .07
    while rx < x1 - .17:
        for side in (-1, 1):
            cyl('flange rivet head', (rx, side * .032, H / 2 + .004), .011, .008, M['bolt'], root, (0, 0, 1), Q['rivet_vertices'])
        rx += .15
    # Impact damage baked into the editable meshes in root space (bevel stays live).
    if bend or twist:
        radius = length / bend if bend else 0
        for o in [c for c in root.children if c.type == 'MESH']:
            basis = o.matrix_basis.copy(); inv = basis.inverted()
            for v in o.data.vertices:
                q = basis @ v.co
                if twist:
                    q = Matrix.Rotation(twist * q.x / length, 3, 'X') @ q
                if bend:
                    t = q.x / radius
                    q = Vector(((radius - q.z) * math.sin(t), q.y, radius - (radius - q.z) * math.cos(t)))
                v.co = inv @ q
            o.data.update()
    return root


def materials():
    with bpy.data.libraries.load(str(TILES), link=False) as (src, dst):
        dst.materials = src.materials
    mats = bpy.data.materials
    M.update({
        # Beam body uses the build-tile blue graphite so it reads as lit steel, not a black hole.
        'beam': mats['Construction plate | blue graphite'],
        'plate': mats['Flanges | dark forged iron'],
        'edge': mats['Exposed worn iron edges'],
        'bolt': mats['Forged steel fasteners'],
    })
    m = bpy.data.materials.new('Torn steel | cooling heat'); m.use_nodes = True
    n = m.node_tree.nodes; l = m.node_tree.links; p = n.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (.06, .035, .022, 1)
    p.inputs['Metallic'].default_value = .7; p.inputs['Roughness'].default_value = .55
    # Thin glowing seams only: the noise mask keeps most of the fracture dark.
    tc = n.new('ShaderNodeTexCoord'); nz = n.new('ShaderNodeTexNoise')
    nz.inputs['Scale'].default_value = 38; nz.inputs['Detail'].default_value = 6
    l.new(tc.outputs['Object'], nz.inputs['Vector'])
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .57; ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = .64; ramp.color_ramp.elements[1].color = (1, .19, .015, 1)
    l.new(nz.outputs['Fac'], ramp.inputs[0]); l.new(ramp.outputs[0], p.inputs['Emission Color'])
    p.inputs['Emission Strength'].default_value = 1.1
    M['torn'] = m


def library():
    roots = [
        # A: long beam, bolted clean end, torn far end with peeled flange tips.
        girder('girder_long_torn', .92, 7, False, 1.6, 0.0, 0.0, [-.30, -.22]),
        # B: medium beam ripped at both ends, bent by impact.
        girder('girder_bent_ripped', .66, 21, True, 1.1, math.radians(24), 0.0, [.02]),
        # C: short stub ripped at both ends, twisted.
        girder('girder_twisted_stub', .42, 33, True, 2.0, 0.0, math.radians(28), []),
    ]
    for i, r in enumerate(roots):
        r.location = (12, (i - 1) * 1.1, 0)
    return roots


def stats(root):
    dg = bpy.context.evaluated_depsgraph_get()
    pts, tris = [], 0
    inv = root.matrix_world.inverted()
    for o in root.children:
        e = o.evaluated_get(dg); me = e.to_mesh()
        pts += [inv @ o.matrix_world @ v.co for v in me.vertices]
        me.calc_loop_triangles(); tris += len(me.loop_triangles); e.to_mesh_clear()
    lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
    return {'min': lo, 'max': hi, 'dimensions': [h - l for l, h in zip(lo, hi)], 'triangles': tris, 'objects': len(root.children)}


def copy_children(src, parent):
    for ob in src.children:
        c = ob.copy(); bpy.context.scene.collection.objects.link(c)
        c.parent = parent; c.matrix_parent_inverse = ob.matrix_parent_inverse.copy()
        copy_children(ob, c)


def review_scene(roots, render):
    s = bpy.context.scene
    s.render.engine = 'CYCLES'; s.cycles.samples = 64; s.cycles.use_denoising = True
    s.view_settings.view_transform = 'AgX'; s.view_settings.look = 'AgX - Medium High Contrast'
    s.world = bpy.data.worlds.new('Deep space review'); s.world.use_nodes = True
    # Dark space for camera rays, neutral ambient for lighting (stands in for Godot sky/ambient).
    wn = s.world.node_tree.nodes; wl = s.world.node_tree.links
    bg = wn.get('Background'); bg.inputs[0].default_value = (.010, .012, .022, 1); bg.inputs[1].default_value = 1.0
    amb = wn.new('ShaderNodeBackground'); amb.inputs[0].default_value = (.55, .58, .66, 1); amb.inputs[1].default_value = .9
    lp = wn.new('ShaderNodeLightPath'); mix = wn.new('ShaderNodeMixShader')
    wl.new(lp.outputs['Is Camera Ray'], mix.inputs[0]); wl.new(amb.outputs[0], mix.inputs[1]); wl.new(bg.outputs[0], mix.inputs[2])
    wl.new(mix.outputs[0], wn.get('World Output').inputs['Surface'])
    # Game forge sun: Godot rotation (-48,-125,0) -> Blender travel direction below.
    d = bpy.data.lights.new('Game forge sun', 'SUN'); d.energy = 4.6; d.angle = math.radians(4)
    o = bpy.data.objects.new('Game forge sun', d); s.collection.objects.link(o)
    o.rotation_euler = Vector((.548, -.384, -.743)).to_track_quat('-Z', 'Y').to_euler()
    d = bpy.data.lights.new('Soft fill', 'AREA'); d.energy = 260; d.size = 6
    o = bpy.data.objects.new('Soft fill', d); s.collection.objects.link(o); o.location = (5, -8, 8)
    o.rotation_euler = (-o.location).to_track_quat('-Z', 'Y').to_euler()
    review = bpy.data.objects.new('REVIEW layout (not library)', None); s.collection.objects.link(review)
    # Scale reference: copies of the approved tiles (tile source untouched).
    with bpy.data.libraries.load(str(TILES), link=False) as (src, dst):
        dst.objects = list(src.objects)
    loaded = {o.name: o for o in dst.objects if o}
    for i, t in enumerate(loaded[n] for n in ('01_Cast_iron_plate', '03_Construction_foundation')):
        holder = bpy.data.objects.new('review tile %d' % i, None); s.collection.objects.link(holder)
        holder.parent = review; holder.location = (i - .5, 0, 0)
        copy_children(t, holder)
    # Floating poses around the tile pair at concept-like distances and tilts.
    poses = [((-1.55, -.6, .25), (.25, .35, .9)), ((1.3, -1.05, .05), (-.35, .2, -.6)), ((.25, 1.2, .45), (.5, -.3, 2.1))]
    for r, (loc, rot) in zip(roots, poses):
        holder = bpy.data.objects.new(r.name + ' review pose', None); s.collection.objects.link(holder)
        holder.parent = review; holder.location = loc; holder.rotation_euler = rot
        copy_children(r, holder)
    cam_d = bpy.data.cameras.new('Game angled camera'); cam = bpy.data.objects.new('Game angled camera', cam_d); s.collection.objects.link(cam)
    s.camera = cam; cam_d.type = 'ORTHO'
    # Godot forge angled pose (5,20,13) -> Blender (5,-13,20), looking at the origin.
    game_pose = ((5, -13, 20), Vector((0, 0, 0)), 4.4)
    def pose(loc, target, scale):
        cam.location = loc; cam.rotation_euler = (target - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); cam_d.ortho_scale = scale
    pose(*game_pose)
    s.render.resolution_x = 1400; s.render.resolution_y = 1100; s.render.image_settings.file_format = 'PNG'
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / ('floating-girders-game.blend' if GAME else 'floating-girders.blend')))
    if render:
        suffix = '-game' if GAME else ''
        s.render.filepath = str(HERE / ('review-game-angle%s.png' % suffix)); bpy.ops.render.render(write_still=True)
        # Close 3/4 look at the library pieces themselves.
        pose((12 + 3.0, -5.5, 4.2), Vector((12, 0, 0)), 2.9)
        s.render.resolution_x = 1600; s.render.resolution_y = 1000
        s.render.filepath = str(HERE / ('review-studio%s.png' % suffix)); bpy.ops.render.render(write_still=True)


GAME = '--game' in sys.argv


def main():
    assert bpy.app.background
    if GAME:
        Q.update(GAME_Q)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials()
    roots = library()
    bpy.context.view_layer.update()
    report = {'reference': CONCEPT, 'blender': bpy.app.version_string, 'girders': {r.name: stats(r) for r in roots}}
    report['detail'] = dict(Q)
    (HERE / ('geometry-check-game.json' if GAME else 'geometry-check.json')).write_text(json.dumps(report, indent=2))
    review_scene(roots, '--render' in sys.argv)
    print('GIRDERS_READY', flush=True)


if __name__ == '__main__':
    main()
