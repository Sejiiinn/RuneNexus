"""Bake the lightweight floating girders into one native PBR GLB; never edits the source.

Adapts ../../environment_props/optimized-game-distance/export_optimized.py (raw-channel
EMIT bake, one shared material, reimport check). Run with a separate background Blender
after `build_girders.py -- --game`.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
SOURCE = OUT / 'floating-girders-game.blend'
ASSET = OUT / 'chapter3-floating-girders.glb'
NAMES = ('girder_long_torn', 'girder_bent_ripped', 'girder_twisted_stub')
SIZE = 512


def points(objects):
    return [o.matrix_world @ v.co for o in objects for v in o.data.vertices]


def error(a, b):
    tree = KDTree(len(b))
    for i, p in enumerate(b):
        tree.insert(p, i)
    tree.balance()
    return max(tree.find(p)[2] for p in a)


def main():
    assert bpy.app.background
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    original = bpy.context.scene
    target = bpy.data.scenes.new('Chapter 3 floating girders native PBR')
    mats = {}; groups = {}; checks = {}
    for name in NAMES:
        root = bpy.data.objects[name]; root.name = name + '__source'; group = []
        for ob in [o for o in root.children if o.type == 'MESH']:
            transform = root.matrix_world.inverted() @ ob.matrix_world
            bpy.context.view_layer.update(); dg = bpy.context.evaluated_depsgraph_get()
            mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
            clone = bpy.data.objects.new(ob.name + '__native', mesh); target.collection.objects.link(clone); clone.matrix_world = transform
            coord = bpy.data.objects.new(ob.name + ' bake coordinates', None); target.collection.objects.link(coord); coord.matrix_world = transform
            for i, mat in enumerate(mesh.materials):
                key = (mat, ob)
                if key not in mats:
                    copied = mat.copy(); mats[key] = copied
                    for node in copied.node_tree.nodes:
                        if node.type == 'TEX_COORD':
                            node.object = coord
                mesh.materials[i] = mats[key]
            group.append(clone)
        groups[name] = group
    bpy.context.window.scene = target
    merged = []
    for name, group in groups.items():
        before = points(group)
        tris = 0
        for o in group:
            o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]; bpy.ops.object.join()
        o = bpy.context.object; o.name = name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        after = points([o]); o.data.calc_loop_triangles()
        deviation = max(error(before, after), error(after, before)); assert deviation < 1e-6
        assert tris == len(o.data.loop_triangles)
        checks[name] = {'source_parts': len(group), 'triangles': tris, 'max_position_error': deviation,
                        'bounds': [[min(p[i] for p in after), max(p[i] for p in after)] for i in range(3)]}
        merged.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in merged:
        o.select_set(True)
    bpy.context.view_layer.objects.active = merged[0]
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    target.render.engine = 'CYCLES'; target.cycles.samples = 4
    target.render.bake.use_clear = False; target.render.bake.margin = 4
    images = {}
    for channel in ('basecolor', 'roughness', 'normal', 'metallic', 'emission'):
        im = bpy.data.images.new('Girders ' + channel, width=SIZE, height=SIZE, alpha=False)
        if channel not in ('basecolor', 'emission'):
            im.colorspace_settings.name = 'Non-Color'
        im.filepath_raw = str(OUT / ('girders-' + channel + '.png')); im.file_format = 'PNG'; images[channel] = im
    for m in mats.values():
        n = m.node_tree.nodes.new('ShaderNodeTexImage'); n.name = 'Bake Target'; m.node_tree.nodes.active = n
    for channel in images:
        restore = []
        for m in mats.values():
            nodes = m.node_tree.nodes; links = m.node_tree.links
            nodes['Bake Target'].image = images[channel]
            if channel == 'normal':
                continue
            bs = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED'); out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
            em = nodes.new('ShaderNodeEmission')
            socket = bs.inputs[{'basecolor': 'Base Color', 'roughness': 'Roughness', 'metallic': 'Metallic', 'emission': 'Emission Color'}[channel]]
            if socket.is_linked:
                links.new(socket.links[0].from_socket, em.inputs['Color'])
            else:
                val = socket.default_value
                em.inputs['Color'].default_value = (val, val, val, 1) if isinstance(val, float) else val
            if channel == 'emission':
                strength = bs.inputs['Emission Strength']
                if strength.is_linked:
                    links.new(strength.links[0].from_socket, em.inputs['Strength'])
                else:
                    em.inputs['Strength'].default_value = strength.default_value / 2.2
            links.new(em.outputs[0], out.inputs['Surface']); restore.append((m, bs, out, em))
        bpy.ops.object.bake(type='NORMAL' if channel == 'normal' else 'EMIT')
        for m, bs, out, em in restore:
            m.node_tree.links.new(bs.outputs[0], out.inputs['Surface']); m.node_tree.nodes.remove(em)
        images[channel].save(); images[channel].pack()
        print('BAKED', channel, flush=True)
    material = bpy.data.materials.new('Chapter3 floating girders native PBR'); material.use_nodes = True
    nodes = material.node_tree.nodes; links = material.node_tree.links; bs = nodes.get('Principled BSDF')
    for channel, socket in [('basecolor', 'Base Color'), ('roughness', 'Roughness'), ('metallic', 'Metallic'), ('normal', 'Normal'), ('emission', 'Emission Color')]:
        n = nodes.new('ShaderNodeTexImage'); n.image = images[channel]
        if channel == 'normal':
            norm = nodes.new('ShaderNodeNormalMap'); links.new(n.outputs['Color'], norm.inputs['Color']); links.new(norm.outputs[0], bs.inputs[socket])
        else:
            links.new(n.outputs['Color'], bs.inputs[socket])
    bs.inputs['Emission Strength'].default_value = 2.2
    for o in merged:
        o.data.materials.clear(); o.data.materials.append(material)
        for face in o.data.polygons:
            face.material_index = 0
        tri = o.modifiers.new('Explicit export triangulation', 'TRIANGULATE')
        if hasattr(tri, 'keep_custom_normals'):
            tri.keep_custom_normals = True
        o['contract'] = 'floating_debris_v1'; o['source'] = str(SOURCE.relative_to(ROOT))
    bpy.ops.export_scene.gltf(filepath=str(ASSET), export_format='GLB', use_selection=True, use_active_scene=True, export_apply=True,
                              export_normals=True, export_texcoords=True, export_tangents=True, export_animations=False,
                              export_cameras=False, export_lights=False, export_extras=True)
    checkscene = bpy.data.scenes.new('GLB reimport verification'); bpy.context.window.scene = checkscene
    bpy.ops.import_scene.gltf(filepath=str(ASSET))
    imported = [o for o in checkscene.objects if o.type == 'MESH']
    reimport = {}
    for src in merged:
        ob = next(o for o in imported if o.name.split('.')[0] == src.name)
        deviation = max(error(points([src]), points([ob])), error(points([ob]), points([src])))
        assert deviation < 2e-6, (src.name, deviation)
        ob.data.calc_loop_triangles()
        reimport[src.name] = {'max_position_error': deviation, 'surfaces': len(ob.data.materials), 'triangles': len(ob.data.loop_triangles)}
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
    report = {'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': source_hash, 'source_unchanged': True, 'girders': checks,
              'reimport': reimport, 'atlas_size': SIZE, 'channels': list(images), 'glb_bytes': ASSET.stat().st_size,
              'glb_sha256': hashlib.sha256(ASSET.read_bytes()).hexdigest()}
    (OUT / 'export-check.json').write_text(json.dumps(report, indent=2) + '\n')
    print('EXPORT_READY', json.dumps({k: v['triangles'] for k, v in reimport.items()}), report['glb_bytes'], flush=True)


if __name__ == '__main__':
    main()
