"""Blender-only surface frost concept. Never exports or changes game assets."""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / 'design/stage1_3d/enemies/chapter-one-enemies-refined.blend'
rng = random.Random(914)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Frost — enemy surface study'

def collection(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c

subject = collection('01 Original enemy — unchanged mesh')
surface = collection('02 Frost coating — toggle to compare')
crystals = collection('03 Attached ice crystals')
studio = collection('04 Studio and cameras')

def move_to(o, c):
    for old in list(o.users_collection):
        old.objects.unlink(o)
    c.objects.link(o)
    return o

def rgba(rgb):
    return tuple(v / 12.92 if v <= 0.04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb) + (1,)

def principled(name, color, roughness, transmission=0, metallic=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = rgba(color)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Transmission Weight'].default_value = transmission
    p.inputs['IOR'].default_value = 1.31
    return m

with bpy.data.libraries.load(str(SOURCE), link=False) as (src, dst):
    dst.objects = ['tank']
enemy = dst.objects[0]
subject.objects.link(enemy)
enemy.parent = None
enemy.location = (0, 0, 0)
enemy.rotation_euler = (0, 0, 0)
enemy.scale = (1, 1, 1)
enemy.name = 'Tank — original gold armor and core'
enemy['source'] = str(SOURCE.relative_to(ROOT))

# A separate, offset shell carries frost. The original face colors and core
# remain intact underneath, and the core polygons are excluded from the shell.
vertices = [v.co + v.normal * .004 for v in enemy.data.vertices]
faces = [tuple(p.vertices) for p in enemy.data.polygons if p.material_index == 0]
mesh = bpy.data.meshes.new('Surface-bound frost shell')
mesh.from_pydata(vertices, [], faces)
mesh.update()
coat = bpy.data.objects.new('Patchy rime — surface attached', mesh)
surface.objects.link(coat)
frost = principled('Rime | granular white-blue ice', (.74, .91, .97), .56, .1)
n, links = frost.node_tree.nodes, frost.node_tree.links
p = n.get('Principled BSDF')
out = n.get('Material Output')
coord = n.new('ShaderNodeTexCoord')
patch = n.new('ShaderNodeTexNoise')
patch.inputs['Scale'].default_value = 5.3
patch.inputs['Detail'].default_value = 3.0
patch.inputs['Roughness'].default_value = .68
links.new(coord.outputs['Object'], patch.inputs['Vector'])
mask = n.new('ShaderNodeValToRGB')
mask.color_ramp.elements[0].position = .42
mask.color_ramp.elements[1].position = .56
links.new(patch.outputs['Fac'], mask.inputs['Fac'])
grain = n.new('ShaderNodeTexNoise')
grain.inputs['Scale'].default_value = 145
grain.inputs['Detail'].default_value = 2
links.new(coord.outputs['Object'], grain.inputs['Vector'])
bump = n.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .32
bump.inputs['Distance'].default_value = .013
links.new(grain.outputs['Fac'], bump.inputs['Height'])
links.new(bump.outputs['Normal'], p.inputs['Normal'])
color = n.new('ShaderNodeValToRGB')
color.color_ramp.elements[0].color = rgba((.35, .65, .78))
color.color_ramp.elements[1].color = rgba((.88, .97, 1))
links.new(grain.outputs['Fac'], color.inputs['Fac'])
links.new(color.outputs['Color'], p.inputs['Base Color'])
transparent = n.new('ShaderNodeBsdfTransparent')
mix = n.new('ShaderNodeMixShader')
links.new(mask.outputs['Color'], mix.inputs[0])
links.new(transparent.outputs[0], mix.inputs[1])
links.new(p.outputs[0], mix.inputs[2])
links.new(mix.outputs[0], out.inputs['Surface'])
coat.data.materials.append(frost)

ice_materials = [
    principled('Ice | clear blue interior', (.29, .70, .87), .16, .72),
    principled('Ice | pale fracture faces', (.65, .89, .97), .24, .38),
    principled('Ice | frosted broken tips', (.87, .97, 1), .44, .16),
]

# Cast onto the actual enemy surface rather than arranging a ring or a cage.
points = [v.co.copy() for v in enemy.data.vertices]
polygons = [tuple(p.vertices) for p in enemy.data.polygons if p.material_index == 0]
bvh = BVHTree.FromPolygons(points, polygons, all_triangles=False)
center = Vector((0, 0, .45))

def anchor(azimuth, elevation):
    direction = Vector((math.cos(azimuth) * math.cos(elevation),
                        math.sin(azimuth) * math.cos(elevation), math.sin(elevation)))
    hit, normal, _, _ = bvh.ray_cast(center + direction * 2, -direction, 3)
    return hit, normal

def shard(name, base, normal, length, width, tilt):
    direction = (normal + Vector(tilt)).normalized()
    q = direction.to_track_quat('Z', 'Y')
    twist = rng.uniform(0, math.tau)
    vs = []
    # A short hexagonal body with an offset, fractured termination.
    for z, radius in [(0, .76), (length * .68, 1)]:
        for i in range(6):
            a = i * math.tau / 6 + twist
            local = Vector((math.cos(a) * width * radius,
                            math.sin(a) * width * .68 * radius, z))
            vs.append(base + q @ local)
    vs.append(base + q @ Vector((width * .24, -width * .15, length)))
    fs = [tuple(reversed(range(6)))]
    for i in range(6):
        j = (i + 1) % 6
        fs.extend([(i, j, j + 6, i + 6), (i + 6, j + 6, 12)])
    data = bpy.data.meshes.new(name)
    data.from_pydata(vs, [], fs)
    data.update()
    o = bpy.data.objects.new(name, data)
    crystals.objects.link(o)
    for m in ice_materials:
        data.materials.append(m)
    for i, face in enumerate(data.polygons):
        face.material_index = 2 if i > 0 and i % 2 == 0 and rng.random() < .55 else rng.randrange(2)
    return o

# Asymmetric shoulder / back clusters leave the recessed front core readable.
clusters = [(2.75, .52, 15), (.08, .63, 12), (1.35, .93, 13)]
for cluster_index, (azimuth, elevation, count) in enumerate(clusters):
    for i in range(count):
        a = azimuth + rng.uniform(-.34, .34)
        e = elevation + rng.uniform(-.24, .23)
        hit, normal = anchor(a, e)
        if hit is None:
            continue
        length = rng.uniform(.055, .16) * (1.25 if i == 0 else 1)
        width = rng.uniform(.013, .038)
        shard(f'Shoulder rime {cluster_index:02d}.{i:02d}', hit - normal * .009,
              normal, length, width, (rng.uniform(-.22, .22), rng.uniform(-.22, .22), .08))

# Small faceted crust at the bases connects the larger ice to the armor.
for i in range(95):
    a, e, _ = clusters[i % len(clusters)]
    hit, normal = anchor(a + rng.uniform(-.45, .45), e + rng.uniform(-.32, .30))
    if hit is None:
        continue
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rng.uniform(.006, .014), location=hit + normal * .003)
    o = move_to(bpy.context.object, crystals)
    o.name = f'Attached hoarfrost grain {i:03d}'
    o.data.materials.append(ice_materials[2])

floor = principled('Studio | charcoal slate', (.095, .135, .16), .83)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.025))
ground = move_to(bpy.context.object, studio)
ground.name = 'Neutral ground — no gameplay asset'
ground.data.materials.append(floor)
world = bpy.data.worlds.new('Cold neutral studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.16, .22, .29, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .35
scene.world = world
for name, loc, energy, color, size in [
    ('Large warm key', (-3, -4, 6), 750, (1, .9, .77), 4),
    ('Cool edge', (2, 2, 3.5), 620, (.53, .79, 1), 2.8),
    ('Soft front fill', (0, -4, 2), 110, (.79, .88, 1), 3),
]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.color, data.size = energy, color, size
    o = bpy.data.objects.new(name, data)
    studio.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, .45)) - o.location).to_track_quat('-Z', 'Y').to_euler()

def camera(name, location, scale):
    data = bpy.data.cameras.new(name)
    data.type, data.ortho_scale = 'ORTHO', scale
    o = bpy.data.objects.new(name, data)
    studio.objects.link(o)
    o.location = location
    o.rotation_euler = (Vector((0, 0, .52)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    return o

hero = camera('Camera — material and attached volume', (2.4, -4.2, 3.05), 1.82)
game = camera('Camera — high battlefield angle', (3.8, -9, 18), 1.82)
scene.camera = hero
scene.render.engine = 'CYCLES'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 8
scene.cycles.transparent_max_bounces = 12
scene.render.resolution_x = 1200
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.render.film_transparent = False
scene.render.filepath = str(OUT / 'frost-hero.png')
scene['concept_status'] = 'Blender-only draft; not integrated into the game'
scene['design_intent'] = 'Surface-attached granular rime and short asymmetric ice, preserving enemy silhouette and core'
for image in bpy.data.images:
    if image.source == 'FILE' or image.has_data:
        try:
            image.pack()
        except RuntimeError:
            pass
bpy.ops.object.select_all(action='DESELECT')
enemy.select_set(True)
bpy.context.view_layer.objects.active = enemy
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'enemy-frost-concept.blend'))
bpy.ops.render.render(write_still=True)
scene.camera = game
scene.render.filepath = str(OUT / 'frost-high-angle.png')
bpy.ops.render.render(write_still=True)
scene.camera = hero
scene.render.filepath = str(OUT / 'frost-hero.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'enemy-frost-concept.blend'))
(OUT / 'manifest.json').write_text(json.dumps({
    'source_enemy': str(SOURCE.relative_to(ROOT)), 'enemy': 'tank',
    'blender_only': True, 'game_assets_modified': False,
    'frost_shell_faces': len(mesh.polygons), 'ice_objects': len(crystals.objects),
    'renders': ['frost-hero.png', 'frost-high-angle.png'],
}, indent=2) + '\n')
print('FROST_CONCEPT_COMPLETE', str(OUT))
