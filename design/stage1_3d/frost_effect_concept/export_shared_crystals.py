"""Export the approved crystals once, with surface attachments for each enemy.

Run with Blender --background --python <this file>. The original concept and
enemy blend files are read only. Unit geometry keeps the original seeded twist
and facet material assignments; attachment transforms carry size and placement.
"""
import json
import hashlib
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, Quaternion

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
WORK = OUT / 'shared_crystals'
RUNTIME = ROOT / 'assets/images/stage1_3d/effects/enemy_frost'
WORK.mkdir(exist_ok=True)
RUNTIME.mkdir(parents=True, exist_ok=True)
KINDS = ('tank', 'normal', 'armored', 'shielded', 'fast', 'boss')
SOURCE = OUT / 'build_concept.py'
source = SOURCE.read_text().split('floor = principled(')[0]
# Capture the exact transform chosen by the approved generator, without
# changing its random number consumption or its raycast/material decisions.
source = source.replace('    return o\n\n# Asymmetric', '''    o['shared_base'] = list(base)
    o['shared_rotation'] = list(q)
    o['shared_width'] = width
    o['shared_length'] = length
    o['shared_twist'] = twist
    return o

# Asymmetric''')
assert "o['shared_width']" in source
conversion = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
inverse_conversion = conversion.inverted()
templates = {}
attachments = {}
verification = {}
variants = []

def packed_transform(transform):
    godot = conversion @ transform @ inverse_conversion
    return [float(godot[row][column]) for column in range(4) for row in range(3)]

for kind in KINDS:
    namespace = {'__file__': str(SOURCE)}
    exec(compile(source.replace("dst.objects = ['tank']", f"dst.objects = ['{kind}']"), str(SOURCE), 'exec'), namespace)
    entries = []
    max_error = 0.0
    shard_index = 0
    for obj in namespace['crystals'].objects:
        if 'shared_width' in obj:
            name = f'FrostShard{shard_index:02d}'
            shard_index += 1
            transform = Matrix.LocRotScale(Vector(obj['shared_base']), Quaternion(obj['shared_rotation']),
                                           Vector((obj['shared_width'], obj['shared_width'], obj['shared_length'])))
            local_vertices = [transform.inverted() @ vertex.co for vertex in obj.data.vertices]
            material_indices = [polygon.material_index for polygon in obj.data.polygons]
        else:
            name = 'FrostGrain'
            radius = max(vertex.co.length for vertex in obj.data.vertices)
            transform = Matrix.Translation(obj.location) @ Matrix.Diagonal((radius, radius, radius, 1))
            local_vertices = [vertex.co / radius for vertex in obj.data.vertices]
            material_indices = [2] * len(obj.data.polygons)
        faces = [list(polygon.vertices) for polygon in obj.data.polygons]
        if name not in templates:
            templates[name] = {'vertices': [list(v) for v in local_vertices], 'faces': faces,
                               'material_indices': material_indices}
            if name != 'FrostGrain':
                variants.append({'mesh': name, 'twist': float(obj['shared_twist']),
                                 'face_materials': material_indices})
        template = templates[name]
        assert template['faces'] == faces, (kind, name, 'topology changed')
        assert template['material_indices'] == material_indices, (kind, name, 'seeded facet colors changed')
        for original, normalized in zip(obj.data.vertices, template['vertices']):
            world_original = obj.matrix_world @ original.co
            # Grain primitive operators may leave matrix_world pending update.
            if name == 'FrostGrain':
                world_original = obj.location + original.co
            error = ((transform @ Vector(normalized)) - world_original).length
            max_error = max(max_error, error)
        entry = {'mesh': 'FrostShard' if name != 'FrostGrain' else name,
                 'transform': packed_transform(transform)}
        if name != 'FrostGrain':
            entry['variant'] = shard_index - 1
        entries.append(entry)
    assert shard_index == 40 and len(entries) == 135, (kind, shard_index, len(entries))
    assert max_error < 0.00001, (kind, max_error)
    attachments[kind] = entries
    verification[kind] = {'shards': shard_index, 'grains': len(entries) - shard_index,
                          'max_reconstruction_error': max_error}

# A single library scene contains identity-transform unit meshes. GLTF exports
# these to Godot's Y-up coordinates; JSON uses the same coordinate conversion.
bpy.ops.wm.read_factory_settings(use_empty=True)
materials = []
for name, color, roughness, transmission in [
    ('IceClear', (.29, .70, .87), .16, .72),
    ('IcePale', (.65, .89, .97), .24, .38),
    ('IceTips', (.87, .97, 1), .44, .16),
]:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    p = material.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = namespace['rgba'](color)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Transmission Weight'].default_value = transmission
    p.inputs['IOR'].default_value = 1.31
    materials.append(material)
for name, template in templates.items():
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(template['vertices'], [], template['faces'])
    mesh.update()
    for material in materials:
        mesh.materials.append(material)
    for polygon, material_index in zip(mesh.polygons, template['material_indices']):
        polygon.material_index = material_index
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.select_set(name == 'FrostGrain')
# Optional single-mesh shader path: rotate ring vertices by the variant twist,
# leave the tip fixed, and choose optical properties with the face palette.
# Keep exact variant meshes in this library too as a numerical/visual reference.
canonical_vertices = []
for z, radius in [(0, .76), (.68, 1)]:
    for i in range(6):
        a = i * math.tau / 6
        canonical_vertices.append((math.cos(a) * radius, math.sin(a) * .68 * radius, z))
canonical_vertices.append((.24, -.15, 1))
canonical_error = 0.0
for variant in variants:
    cosine, sine = math.cos(variant['twist']), math.sin(variant['twist'])
    for i, (x, y, z) in enumerate(canonical_vertices):
        # Equivalent to the Godot shader's Y-up ring rotation, before the
        # attachment transform scales and rotates it onto the enemy surface.
        rotated = Vector((cosine * x - sine * y / .68,
                          .68 * sine * x + cosine * y, z)) if i != 12 else Vector((x, y, z))
        canonical_error = max(canonical_error,
                              (rotated - Vector(templates[variant['mesh']]['vertices'][i])).length)
assert canonical_error < .00002, canonical_error
mesh = bpy.data.meshes.new('FrostShard')
mesh.from_pydata(canonical_vertices, [], templates['FrostShard00']['faces'])
mesh.update()
mesh.materials.append(materials[0])
uv = mesh.uv_layers.new(name='FaceAndTip')
for polygon in mesh.polygons:
    for loop_index in polygon.loop_indices:
        vertex_index = mesh.loops[loop_index].vertex_index
        # glTF flips Blender's V coordinate. Exported UV.y is 1 only for tip.
        uv.data[loop_index].uv = (polygon.index / 13.0, 0.0 if vertex_index == 12 else 1.0)
obj = bpy.data.objects.new('FrostShard', mesh)
bpy.context.scene.collection.objects.link(obj)
obj.select_set(True)
bpy.context.scene['asset_contract'] = 'Shared unit crystals; attachments.json supplies Godot local transforms'
bpy.ops.export_scene.gltf(filepath=str(RUNTIME / 'crystals.glb'), export_format='GLB', use_selection=True,
                          export_yup=True, export_animations=False, export_cameras=False,
                          export_lights=False, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK / 'shared-crystals.blend'))
attachments['_variants'] = variants
attachments['_schema'] = {'version': 1, 'transform': 'Godot Transform3D basis columns then origin',
                          'custom_data': '[variant index, cos(twist), sin(twist), 0]',
                          'face_materials': ['IceClear', 'IcePale', 'IceTips']}
(RUNTIME / 'attachments.json').write_text(json.dumps(attachments, separators=(',', ':')) + '\n')
report = {'generator_source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'shared_mesh_count': 2, 'mesh_names': ['FrostShard', 'FrostGrain'],
          'design_reference_meshes': list(templates),
          'coordinate_contract': 'Godot Y-up; Transform3D columns: basis.x, basis.y, basis.z, origin',
          'materials': [material.name for material in materials], 'enemies': verification,
          'glb_bytes': (RUNTIME / 'crystals.glb').stat().st_size,
          'attachments_bytes': (RUNTIME / 'attachments.json').stat().st_size}
report['canonical_mesh'] = 'FrostShard'
report['canonical_vertex_contract'] = 'Godot x,z ring coordinates undo z factor -0.68, rotate by twist, then restore; tip UV.y=1 stays fixed; UV.x=face_index/13'
report['variants'] = variants
report['canonical_shader_max_unit_vertex_error'] = canonical_error
(WORK / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print('SHARED_CRYSTALS_VERIFIED', json.dumps(report), flush=True)
