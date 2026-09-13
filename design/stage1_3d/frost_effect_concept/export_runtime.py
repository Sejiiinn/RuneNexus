"""Bake the approved procedural rime and export surface-attached overlays.
Run in an isolated Blender background process; the approved .blend stays intact.
"""
import bpy
import json
import array
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
RUNTIME = OUT / 'per_kind_archive'
RUNTIME.mkdir(parents=True, exist_ok=True)
BAKES = OUT / 'bakes'
BAKES.mkdir(exist_ok=True)
source = (OUT / 'build_concept.py').read_text().split("floor = principled(")[0]
report = {}
for kind in ('tank', 'normal', 'armored', 'shielded', 'fast', 'boss'):
    # Reuse the approved geometry, seed, raycasts, and material node network.
    namespace = {'__file__': str(OUT / 'build_concept.py')}
    exec(compile(source.replace("dst.objects = ['tank']", f"dst.objects = ['{kind}']"), str(OUT / 'build_concept.py'), 'exec'), namespace)
    scene, coat, frost = (namespace[k] for k in ('scene', 'coat', 'frost'))
    crystals = namespace['crystals']
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.render.bake.margin = 8
    bpy.ops.object.select_all(action='DESELECT')
    coat.select_set(True)
    bpy.context.view_layer.objects.active = coat
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.1519, island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    nodes, links = frost.node_tree.nodes, frost.node_tree.links
    output = nodes.get('Material Output')
    target = nodes.new('ShaderNodeTexImage')
    nodes.active = target
    emission = nodes.new('ShaderNodeEmission')
    links.new(emission.outputs[0], output.inputs['Surface'])
    images = {}
    for label, socket in [('color', namespace['color'].outputs['Color']), ('mask', namespace['mask'].outputs['Color'])]:
        image = bpy.data.images.new(kind + '_' + label, width=512, height=512, alpha=True)
        if label == 'mask':
            image.colorspace_settings.name = 'Non-Color'
        target.image = image
        links.new(socket, emission.inputs['Color'])
        bpy.ops.object.bake(type='EMIT')
        images[label] = image
    color = images['color']
    rgba = array.array('f', [0.0]) * (512 * 512 * 4)
    mask = array.array('f', [0.0]) * len(rgba)
    color.pixels.foreach_get(rgba)
    images['mask'].pixels.foreach_get(mask)
    for i in range(3, len(rgba), 4):
        rgba[i] = mask[i - 3]
    color.pixels.foreach_set(rgba)
    color.filepath_raw = str(BAKES / f'{kind}_rime.png')
    color.file_format = 'PNG'
    color.save()
    normal = bpy.data.images.new(kind + '_normal', width=512, height=512, alpha=False)
    normal.colorspace_settings.name = 'Non-Color'
    target.image = normal
    links.new(namespace['p'].outputs[0], output.inputs['Surface'])
    bpy.ops.object.bake(type='NORMAL')
    normal.filepath_raw = str(BAKES / f'{kind}_normal.png')
    normal.file_format = 'PNG'
    normal.save()
    baked = bpy.data.materials.new('FrostCoat')
    baked.use_nodes = True
    baked.surface_render_method = 'DITHERED'
    n, l = baked.node_tree.nodes, baked.node_tree.links
    p = n.get('Principled BSDF')
    p.inputs['Roughness'].default_value = .56
    p.inputs['IOR'].default_value = 1.31
    tex = n.new('ShaderNodeTexImage'); tex.image = color
    l.new(tex.outputs['Color'], p.inputs['Base Color'])
    l.new(tex.outputs['Alpha'], p.inputs['Alpha'])
    texn = n.new('ShaderNodeTexImage'); texn.image = normal
    norm = n.new('ShaderNodeNormalMap')
    l.new(texn.outputs['Color'], norm.inputs['Color'])
    l.new(norm.outputs['Normal'], p.inputs['Normal'])
    coat.data.materials.clear(); coat.data.materials.append(baked)
    coat.name = 'FrostCoat'
    # Consolidate 135 independent Blender pieces to one mesh, retaining all
    # original vertices, facet normals, and three original optical materials.
    bpy.ops.object.select_all(action='DESELECT')
    crystal_objects = list(crystals.objects)
    for obj in crystal_objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = crystal_objects[0]
    bpy.ops.object.join()
    ice = bpy.context.object
    ice.name = 'AttachedIce'
    for mat, name in zip(namespace['ice_materials'], ('IceClear', 'IcePale', 'IceTips')):
        mat.name = name
    coat.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(RUNTIME / f'{kind}.glb'), export_format='GLB', use_selection=True,
                              export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False, export_apply=True)
    scene['approved_source'] = 'enemy-frost-concept.blend'
    scene['runtime_enemy_kind'] = kind
    for image in (color, normal): image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f'runtime-{kind}.blend'))
    report[kind] = {'coat_faces': len(coat.data.polygons), 'crystal_faces': len(ice.data.polygons),
                    'crystal_objects_before_join': len(crystal_objects), 'bytes': (RUNTIME / f'{kind}.glb').stat().st_size}
    print('EXPORTED_FROST', kind, report[kind], flush=True)
(OUT / 'runtime-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
