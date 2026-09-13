"""Bake Blender's approved procedural fields once for all enemy types.

Run only with an isolated `Blender -b --python` process. Source .blend and
per-enemy geometry are read-only. rime_mask.bin is R8 x-fastest, then y, then z.
"""
import bpy
import array
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PRODUCTION = OUT / 'shared_noise'
RUNTIME = ROOT / 'assets/images/stage1_3d/effects/enemy_frost'
PRODUCTION.mkdir(exist_ok=True)
RUNTIME.mkdir(parents=True, exist_ok=True)
SIZE = 64
DOMAIN_MIN = (-.7, -.7, -.1)
DOMAIN_MAX = (.7, .7, 1.3)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 1
scene.render.bake.margin = 0
scene.render.bake.use_clear = True
scene.render.bake.use_selected_to_active = False
bounds = {}
with bpy.data.libraries.load(str(ROOT / 'design/stage1_3d/enemies/chapter-one-enemies-refined.blend'), link=False) as (src, dst):
    dst.objects = ['normal', 'armored', 'shielded', 'fast', 'tank', 'boss']
for obj in dst.objects:
    lo = [min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in obj.data.vertices) for i in range(3)]
    bounds[obj.name] = {'min': lo, 'max': hi}
    assert all(lo[i] >= DOMAIN_MIN[i] and hi[i] <= DOMAIN_MAX[i] for i in range(3)), (obj.name, lo, hi)

# Copy the approved material nodes directly, preserving the Noise and ColorRamp
# settings, including Blender's default normalization/interpolation behavior.
with bpy.data.libraries.load(str(OUT / 'enemy-frost-concept.blend'), link=False) as (src, dst):
    dst.materials = ['Rime | granular white-blue ice']
material = dst.materials[0]
nodes, links = material.node_tree.nodes, material.node_tree.links
noise_nodes = [n for n in nodes if n.bl_idname == 'ShaderNodeTexNoise']
patch = next(n for n in noise_nodes if abs(n.inputs['Scale'].default_value - 5.3) < .001)
grain = next(n for n in noise_nodes if abs(n.inputs['Scale'].default_value - 145) < .001)
mask = next(link.to_node for link in links if link.from_node == patch)
attribute = nodes.new('ShaderNodeAttribute')
attribute.attribute_name = 'samplePosition'
links.new(attribute.outputs['Vector'], patch.inputs['Vector'])
links.new(attribute.outputs['Vector'], grain.inputs['Vector'])
emission = nodes.new('ShaderNodeEmission')
links.new(emission.outputs[0], nodes.get('Material Output').inputs['Surface'])
target = nodes.new('ShaderNodeTexImage')
nodes.active = target


def bake(label, tiles, vectors, socket):
    verts, faces, uvs, values = [], [], [], []
    for index, coords in enumerate(vectors):
        tx, ty = index % tiles, index // tiles
        start = len(verts)
        corners = [(tx, ty, 0), (tx + 1, ty, 0), (tx + 1, ty + 1, 0), (tx, ty + 1, 0)]
        verts.extend(corners)
        faces.append(tuple(range(start, start + 4)))
        uvs.extend([(v[0] / tiles, v[1] / tiles) for v in corners])
        values.extend(coords)
    mesh = bpy.data.meshes.new(label)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name='BakeUV')
    attr = mesh.attributes.new('samplePosition', 'FLOAT_VECTOR', 'CORNER')
    for i in range(len(uvs)):
        uv.data[i].uv = uvs[i]
        attr.data[i].vector = values[i]
    obj = bpy.data.objects.new(label, mesh)
    scene.collection.objects.link(obj)
    mesh.materials.append(material)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    image = bpy.data.images.new(label, width=512, height=512, alpha=False, float_buffer=True)
    image.colorspace_settings.name = 'Non-Color'
    target.image = image
    links.new(socket, emission.inputs['Color'])
    bpy.ops.object.bake(type='EMIT')
    pixels = array.array('f', [0]) * (512 * 512 * 4)
    image.pixels.foreach_get(pixels)
    obj.hide_render = True
    return image, pixels


vectors = []
for z in range(SIZE):
    zz = DOMAIN_MIN[2] + (z + .5) / SIZE * (DOMAIN_MAX[2] - DOMAIN_MIN[2])
    vectors.append([(DOMAIN_MIN[0], DOMAIN_MIN[1], zz), (DOMAIN_MAX[0], DOMAIN_MIN[1], zz),
                    (DOMAIN_MAX[0], DOMAIN_MAX[1], zz), (DOMAIN_MIN[0], DOMAIN_MAX[1], zz)])
atlas, pixels = bake('Rime mask — exact Blender field', 8, vectors, mask.outputs['Color'])
raw = bytearray()
for z in range(SIZE):
    tile_x, tile_y = z % 8, z // 8
    for y in range(SIZE):
        for x in range(SIZE):
            sample = pixels[((tile_y * SIZE + y) * 512 + tile_x * SIZE + x) * 4]
            raw.append(round(max(0, min(1, sample)) * 255))
assert len(raw) == SIZE ** 3
mask_path = RUNTIME / 'rime_mask.bin'
mask_path.write_bytes(raw)
atlas.filepath_raw = str(PRODUCTION / 'rime-mask-atlas.png')
atlas.file_format = 'PNG'
atlas.save()
grain.inputs['Scale'].default_value = 1.0
image, grain_pixels = bake('Shared rime grain', 1, [[(0, 0, 0), (8, 0, 0), (8, 8, 0), (0, 8, 0)]], grain.outputs['Fac'])
# PNG is non-color data: values remain linear and no display transform is baked.
grain_byte = bpy.data.images.new('Shared grain — runtime bytes', width=512, height=512, alpha=False, float_buffer=False)
grain_byte.colorspace_settings.name = 'Non-Color'
grain_byte.pixels.foreach_set(grain_pixels)
grain_byte.filepath_raw = str(RUNTIME / 'grain.png')
grain_byte.file_format = 'PNG'
grain_byte.save()
# Verify atlas interpolation and axis ordering against constant-coordinate bakes.
checks = []
for x, y, z in [(0, 0, 0), (17, 23, 41), (63, 63, 63)]:
    position = tuple(DOMAIN_MIN[i] + (v + .5) / SIZE * (DOMAIN_MAX[i] - DOMAIN_MIN[i])
                     for i, v in enumerate((x, y, z)))
    check_image, check_pixels = bake('Constant coordinate check', 1, [[position] * 4], mask.outputs['Color'])
    expected = check_pixels[(256 * 512 + 256) * 4]
    actual = raw[(z * SIZE + y) * SIZE + x] / 255
    assert abs(actual - expected) <= 1 / 255, (position, actual, expected)
    checks.append({'voxel': [x, y, z], 'blender_exact': expected, 'r8_sample': actual})
loaded_grain = bpy.data.images.load(str(RUNTIME / 'grain.png'), check_existing=False)
loaded_grain.colorspace_settings.name = 'Non-Color'
loaded_pixels = array.array('f', [0]) * (512 * 512 * 4)
loaded_grain.pixels.foreach_get(loaded_pixels)
max_grain_error = max(abs(a - b) for a, b in zip(grain_pixels[0::4], loaded_pixels[0::4]))
assert max_grain_error <= 1 / 255, max_grain_error
report = {
    'source': 'enemy-frost-concept.blend / Rime | granular white-blue ice',
    'blender': bpy.app.version_string,
    'mask': {'path': str(mask_path.relative_to(ROOT)), 'format': 'R8 unsigned normalized',
             'size': [SIZE] * 3, 'domain_min': DOMAIN_MIN, 'domain_max': DOMAIN_MAX,
             'coordinates': 'Blender local XYZ. Godot local (x,y,z) maps to Blender (x,-z,y).',
             'order': 'x fastest, then y, then z; each voxel samples (index + 0.5) / 64',
             'bytes': len(raw), 'min': min(raw), 'max': max(raw), 'mean': sum(raw) / len(raw),
             'sha256': hashlib.sha256(raw).hexdigest()},
    'grain': {'path': str((RUNTIME / 'grain.png').relative_to(ROOT)), 'size': [512, 512],
              'coordinates': 'Noise coordinate (8u, 8v, 0), Scale 1, Detail 2, Roughness 0.5',
              'color_space': 'Non-Color / linear, R channel',
              'min': min(grain_pixels[0::4]), 'max': max(grain_pixels[0::4])},
    'enemy_local_bounds': bounds,
    'verification': {'constant_coordinate_checks': checks, 'grain_png_max_linear_error': max_grain_error},
}
(PRODUCTION / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
