"""Bake the game-distance venom mortar's procedural metals and export the game GLB.

Blender -b venom-mortar-game.blend --factory-startup --python export_game.py [-- --install]
Meshes are the evaluated game build (no rebuild, no decimation), joined per control node
(turret_root / turret_head / turret_barrel). Metals share one 1024 colour/roughness/normal atlas.
Glass and venom become plain alpha-blended PBR because Godot has no transmission.
--install also copies the GLB to assets/images/stage1_3d/turrets/poison.glb.
"""
import bpy, json, math, hashlib, shutil, struct, sys
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
ASSET = OUT / 'venom-mortar-game.glb'
GAME = ROOT / 'assets/images/stage1_3d/turrets/poison.glb'
SIZE = 1024
EDGE_WEAR = .15  # rev5: .5
BODY = ('01 ', '02 ', '03 ', '04 ', '05 ')
CONTROLS = ('turret_root', 'turret_head', 'turret_barrel')
METALS = ('Iron |', 'Bronze |', 'Recess |', 'Steel |')
# name prefix: base colour (linear), alpha, emission colour, emission strength, roughness
PLAIN = {
    'Runes |': ((.24, .64, .006), 1, (.32, 1, .009), .85, .3),
    'Glass |': ((.85, .95, .88), .16, (0, 0, 0), 0, .08),
    'Venom | tank liquid': ((.23, .70, .01), .82, (.18, .65, .003), .35, .09),
    'Venom | muzzle glob': ((.23, .70, .005), .80, (.18, .65, .003), .5, .085),
    'Venom | bubbles': ((.73, .95, .23), 1, (.5, .9, .2), .15, .06),
}


def control_of(o):
    p = o.parent
    while p and p.name not in CONTROLS: p = p.parent
    return p


def setup():
    source = bpy.context.scene
    source.objects['turret_head'].rotation_euler.z = 0
    bpy.context.view_layer.update(); deps = bpy.context.evaluated_depsgraph_get()
    keep = [o for c in source.collection.children if c.name.startswith(BODY) for o in c.all_objects
            if o.type in ('MESH', 'CURVE') and not o.hide_render]
    target = bpy.data.scenes.new('Venom Mortar Game Export')
    controls = {}
    for n in CONTROLS + ('muzzle',):
        o = source.objects[n]; c = bpy.data.objects.new(n + '__export', None)
        target.collection.objects.link(c); c.matrix_world = o.matrix_world.copy(); controls[n] = (o, c)
    for n, (o, c) in controls.items():
        parent = control_of(o) if n == 'muzzle' else o.parent
        if parent:
            world = c.matrix_world.copy(); c.parent = controls[parent.name][1]; c.matrix_world = world
    mats, objects = {}, []
    for o in keep:
        data = bpy.data.meshes.new_from_object(o.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
        clone = bpy.data.objects.new(o.name + '__export', data); clone['source_object'] = o.name
        # Boolean cutters add an empty slot for their faces; those walls take the body's own material.
        main = next(m for m in data.materials if m)
        for i, m in enumerate(data.materials):
            m = m or main
            if m not in mats: mats[m] = m.copy()
            data.materials[i] = mats[m]
        target.collection.objects.link(clone); clone.matrix_world = o.matrix_world.copy()
        world = clone.matrix_world.copy(); clone.parent = controls[control_of(o).name][1]; clone.matrix_world = world
        objects.append(clone)
    bpy.context.window.scene = target
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.006)
    bpy.ops.object.mode_set(mode='OBJECT')
    target.render.engine = 'CYCLES'; target.cycles.samples = 8; target.cycles.device = 'CPU'
    target.render.bake.use_clear = False; target.render.bake.margin = 5
    target.render.bake.use_pass_direct = False; target.render.bake.use_pass_indirect = False
    target.render.bake.use_pass_color = True
    metals = [m for orig, m in mats.items() if orig.name.startswith(METALS)]
    for m in metals:
        # Low-poly Pointiness spreads rev5's convex-edge wear over whole bronze faces.
        wear = m.node_tree.nodes.get('Warm edge wear strength')
        if wear: wear.inputs[1].default_value = EDGE_WEAR
    plain = [m for orig, m in mats.items() if not orig.name.startswith(METALS)]
    images = {}
    for name in ('color', 'roughness', 'normal'):
        im = bpy.data.images.new('Venom atlas ' + name, width=SIZE, height=SIZE, alpha=False)
        if name != 'color': im.colorspace_settings.name = 'Non-Color'
        im.filepath_raw = str(OUT / ('venom-' + name + '.png')); im.file_format = 'PNG'; images[name] = im
    for m in metals:
        n = m.node_tree.nodes.new('ShaderNodeTexImage'); n.name = 'Bake Target'; m.node_tree.nodes.active = n
    bake_objects = [o for o in objects if any(m in metals for m in o.data.materials)]
    bpy.ops.object.select_all(action='DESELECT')
    for o in bake_objects: o.select_set(True)
    bpy.context.view_layer.objects.active = bake_objects[0]
    return target, controls, objects, metals, plain, images


def bake(metals, images):
    for name, kind in [('color', 'EMIT'), ('roughness', 'ROUGHNESS'), ('normal', 'NORMAL')]:
        for m in metals: m.node_tree.nodes['Bake Target'].image = images[name]
        rewired = []
        if name == 'color':
            # Raw base colour (incl. Pointiness edge wear): diffuse baking would darken metals.
            for m in metals:
                nodes, links = m.node_tree.nodes, m.node_tree.links
                bs = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
                out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
                em = nodes.new('ShaderNodeEmission')
                links.new(bs.inputs['Base Color'].links[0].from_socket, em.inputs['Color'])
                links.new(em.outputs[0], out.inputs['Surface']); rewired.append((m, bs, out, em))
        bpy.ops.object.bake(type=kind)
        for m, bs, out, em in rewired:
            m.node_tree.links.new(bs.outputs[0], out.inputs['Surface']); m.node_tree.nodes.remove(em)
        images[name].save(); images[name].pack()
    for m in metals:
        metal = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED').inputs['Metallic'].default_value
        m.node_tree.nodes.clear(); nodes, links = m.node_tree.nodes, m.node_tree.links
        bs = nodes.new('ShaderNodeBsdfPrincipled'); bs.inputs['Metallic'].default_value = metal
        out = nodes.new('ShaderNodeOutputMaterial'); links.new(bs.outputs[0], out.inputs['Surface'])
        for name, socket in [('color', 'Base Color'), ('roughness', 'Roughness'), ('normal', 'Normal')]:
            n = nodes.new('ShaderNodeTexImage'); n.image = images[name]
            if name == 'normal':
                nm = nodes.new('ShaderNodeNormalMap'); links.new(n.outputs['Color'], nm.inputs['Color'])
                links.new(nm.outputs[0], bs.inputs[socket])
            else: links.new(n.outputs['Color'], bs.inputs[socket])


def plain_materials(plain):
    for m in plain:
        key = next(k for k in PLAIN if m.name.startswith(k))
        col, alpha, emit, strength, rough = PLAIN[key]
        m.node_tree.nodes.clear(); nodes, links = m.node_tree.nodes, m.node_tree.links
        bs = nodes.new('ShaderNodeBsdfPrincipled'); out = nodes.new('ShaderNodeOutputMaterial')
        links.new(bs.outputs[0], out.inputs['Surface'])
        bs.inputs['Base Color'].default_value = (*col, 1); bs.inputs['Alpha'].default_value = alpha
        bs.inputs['Emission Color'].default_value = (*emit, 1); bs.inputs['Emission Strength'].default_value = strength
        bs.inputs['Roughness'].default_value = rough; bs.inputs['Metallic'].default_value = 0
        m.surface_render_method = 'BLENDED' if alpha < 1 else 'DITHERED'
        m.use_backface_culling = alpha >= 1


def join_and_export(controls, objects):
    def signature(obs):
        t = 0
        for o in obs: o.data.calc_loop_triangles(); t += len(o.data.loop_triangles)
        return t
    before = signature(objects); groups = {}
    for o in objects: groups.setdefault(o.parent, []).append(o)
    merged = []
    for parent, group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group: o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]; bpy.ops.object.join()
        o = bpy.context.object; o.name = parent.name.removesuffix('__export') + '_geometry'; merged.append(o)
    after = signature(merged); assert before == after, (before, after)
    for n, (orig, clone) in controls.items():
        orig.name = n + '__design_source'; clone.name = n
    for o in merged:
        mod = o.modifiers.new('Explicit export triangulation', 'TRIANGULATE'); mod.quad_method = 'FIXED'; mod.ngon_method = 'BEAUTY'
        if hasattr(mod, 'keep_custom_normals'): mod.keep_custom_normals = True
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(ASSET), export_format='GLB', use_selection=True, use_active_scene=True,
                              export_apply=True, export_normals=True, export_texcoords=True, export_tangents=True,
                              export_animations=False, export_cameras=False, export_lights=False, export_extras=True)
    return before, merged


def glb_report():
    raw = ASSET.read_bytes(); n = struct.unpack_from('<I', raw, 12)[0]; g = json.loads(raw[20:20 + n])
    tris = sum(g['accessors'][p['indices']]['count'] // 3 for mesh in g['meshes'] for p in mesh['primitives'])
    nodes = {x['name']: x for x in g['nodes']}
    return {'glb_bytes': len(raw), 'glb_sha256': hashlib.sha256(raw).hexdigest(), 'glb_triangles': tris,
            'glb_meshes': len(g['meshes']), 'glb_images': len(g.get('images', [])),
            'materials': {m['name']: m.get('alphaMode', 'OPAQUE') for m in g['materials']},
            'extensions_used': g.get('extensionsUsed', []),
            'control_nodes': {k: nodes[k].get('children', []) for k in ('turret_root', 'turret_head', 'turret_barrel') if k in nodes},
            'muzzle_local_translation': nodes['muzzle'].get('translation')}


if __name__ == '__main__':
    target, controls, objects, metals, plain, images = setup()
    bake(metals, images); plain_materials(plain)
    triangles, merged = join_and_export(controls, objects)
    report = {'source': 'venom-mortar-game.blend', 'triangles': triangles, 'atlas_size': SIZE, **glb_report()}
    assert report['glb_triangles'] == triangles and not report['extensions_used'], report
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'venom-mortar-game-baked.blend'), compress=True)
    if '--install' in sys.argv:
        shutil.copy2(ASSET, GAME); report['installed'] = str(GAME.relative_to(ROOT))
    (OUT / 'export-check.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('POISON_EXPORT', json.dumps(report, ensure_ascii=False))
