"""Bake the E2 support core's procedural metals and export the game GLB.

Blender -b ../blender/support-core-E2.blend --factory-startup --python export_game.py [-- --install]
Meshes are the evaluated design source (no decimation; about 10.7k triangles), joined per control node:
support_core_root (body) and core_crystal (floating crystal, animated in game). Metals share one
1024 colour/roughness/normal atlas, as the flame and poison turrets do. Glow materials stay plain PBR with
emission at strength 1; the game raises their energy. Each arm's glow materials are separate
("... | arm <i>") so the game lights only connected arms. --install copies the GLB to
assets/images/stage1_3d/turrets/support_core.glb.
"""
import bpy, json, math, hashlib, shutil, struct, sys
import numpy as np
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
ASSET = OUT / 'support-core-game.glb'
GAME = ROOT / 'assets/images/stage1_3d/turrets/support_core.glb'
SIZE = 1024
BODY = ('01 ', '02 ', '03 ')
CONTROLS = ('support_core_root', 'core_crystal')
METALS = ('Iron |', 'Bronze |', 'Recess |', 'Steel |')
# Arm glow parts end with the arm index (conduit_arm_<i>, rotated i * 90 degrees about Z).
ARM_GLOW = ('Channel glow ', 'Cap pane ', 'Cap window ')
# name prefix: base colour (linear), emission colour, roughness, metallic[, alpha]
PLAIN = {
    'Runes |': ((.01, .5, .43), (.01, .5, .43), .3, 0),
    'Crown |': ((.01, .5, .43), (.01, .5, .43), .3, 0),
    'Crystal | cap panes': ((.04, .58, .52), (.05, .79, .67), .06, 0),
    'Crystal | floating core sides': ((.04, .58, .52), (.012, .17, .145), .06, 0),
    # The floating crystal's shell exports as a plain fallback; the game swaps in a glass shader
    # (support_core_crystal.gdshader), since glTF transmission would need an extension.
    'Crystal | floating core': ((.04, .58, .52), (.3, .95, .88), .06, 0, .42),
    'Crystal | floating heart': ((.3, .95, .88), (.35, 1, .92), .06, 0),
}


def control_of(o):
    p = o
    while p and p.name not in CONTROLS: p = p.parent
    return p


def setup():
    source = bpy.context.scene
    bpy.context.view_layer.update(); deps = bpy.context.evaluated_depsgraph_get()
    keep = [o for c in source.collection.children if c.name.startswith(BODY) for o in c.all_objects
            if o.type == 'MESH' and not o.hide_render]
    target = bpy.data.scenes.new('Support Core Game Export')
    controls = {}
    for n in CONTROLS:
        o = source.objects[n]; c = bpy.data.objects.new(n + '__export', None)
        target.collection.objects.link(c); c.matrix_world = o.matrix_world.copy(); controls[n] = (o, c)
    world = controls['core_crystal'][1].matrix_world.copy()
    controls['core_crystal'][1].parent = controls['support_core_root'][1]
    controls['core_crystal'][1].matrix_world = world
    mats, objects = {}, []
    for o in keep:
        data = bpy.data.meshes.new_from_object(o.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
        clone = bpy.data.objects.new(o.name + '__export', data); clone['source_object'] = o.name
        # Each arm's channel and cap panes get their own glow materials, so the game can light only the
        # arms that face a connected turret.
        arm = next((o.name.rsplit(' ', 1)[1] for prefix in ARM_GLOW if o.name.startswith(prefix)), None)
        # Boolean cutters add an empty slot for their faces; those walls take the body's own material.
        main = next(m for m in data.materials if m)
        for i, m in enumerate(data.materials):
            m = m or main
            key = (m, arm)
            if key not in mats:
                mats[key] = m.copy()
                if arm is not None: mats[key].name = m.name + ' | arm ' + arm
            data.materials[i] = mats[key]
        target.collection.objects.link(clone); clone.matrix_world = o.matrix_world.copy()
        world = clone.matrix_world.copy(); clone.parent = controls[control_of(o).name][1]; clone.matrix_world = world
        objects.append(clone)
    bpy.context.window.scene = target
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    # Only the baked metals need atlas space; glow and crystal faces are flat colours. Unwrapping just the
    # metal faces and repacking them at one texel density fills the atlas instead of leaving half of it empty.
    for o in objects:
        for f in o.data.polygons:
            m = o.data.materials[f.material_index]
            f.select = m is not None and m.name.startswith(METALS)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.004)
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=.003, shape_method='CONCAVE')
    bpy.ops.object.mode_set(mode='OBJECT')
    target.render.engine = 'CYCLES'; target.cycles.samples = 8; target.cycles.device = 'CPU'
    target.render.bake.use_clear = False; target.render.bake.margin = 5
    target.render.bake.use_pass_direct = False; target.render.bake.use_pass_indirect = False
    target.render.bake.use_pass_color = True
    metals = [m for (orig, _), m in mats.items() if orig.name.startswith(METALS)]
    plain = [m for (orig, _), m in mats.items() if not orig.name.startswith(METALS)]
    images = {}
    for name in ('color', 'roughness', 'normal', 'ao'):
        im = bpy.data.images.new('Support core atlas ' + name, width=SIZE, height=SIZE, alpha=False)
        if name != 'color': im.colorspace_settings.name = 'Non-Color'
        im.filepath_raw = str(OUT / ('support-core-' + name + '.png')); im.file_format = 'PNG'; images[name] = im
    for m in metals:
        n = m.node_tree.nodes.new('ShaderNodeTexImage'); n.name = 'Bake Target'; m.node_tree.nodes.active = n
    bake_objects = [o for o in objects if any(m in metals for m in o.data.materials)]
    bpy.ops.object.select_all(action='DESELECT')
    for o in bake_objects: o.select_set(True)
    bpy.context.view_layer.objects.active = bake_objects[0]
    return target, controls, objects, metals, plain, images


# Share of the baked occlusion multiplied into the colour: crevices and contact edges darken as in the
# painted concept, which the game's mobile lighting would not add on its own.
AO_STRENGTH = .85


def bake(metals, images):
    for name, kind in [('ao', 'AO'), ('color', 'EMIT'), ('roughness', 'ROUGHNESS'), ('normal', 'NORMAL')]:
        for m in metals: m.node_tree.nodes['Bake Target'].image = images[name]
        scene = bpy.context.scene
        if kind == 'AO':
            # Short reach: crevices and contact seams darken, broad faces stay clean.
            if scene.world is None: scene.world = bpy.data.worlds.new('Bake occlusion')
            scene.world.light_settings.distance = .05
        scene.cycles.samples = 96 if kind == 'AO' else 8
        rewired = []
        if name == 'color':
            # Raw base colour (incl. edge wear): diffuse baking would darken metals.
            for m in metals:
                nodes, links = m.node_tree.nodes, m.node_tree.links
                bs = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
                out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
                em = nodes.new('ShaderNodeEmission')
                source = bs.inputs['Base Color']
                if source.links: links.new(source.links[0].from_socket, em.inputs['Color'])
                else: em.inputs['Color'].default_value = source.default_value
                links.new(em.outputs[0], out.inputs['Surface']); rewired.append((m, bs, out, em))
        bpy.ops.object.bake(type=kind)
        for m, bs, out, em in rewired:
            m.node_tree.links.new(bs.outputs[0], out.inputs['Surface']); m.node_tree.nodes.remove(em)
        if name == 'color':
            # The colour image lands in the GLB; the occlusion pass only shades it.
            colour, ao = np.array(images['color'].pixels[:]), np.array(images['ao'].pixels[:])
            shade = 1 - AO_STRENGTH * (1 - ao.reshape(-1, 4)[:, :1])
            rgb = colour.reshape(-1, 4); rgb[:, :3] *= shade
            images['color'].pixels.foreach_set(rgb.ravel().astype(np.float32))
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
        # Longest prefix first: the floating core and its sides share a prefix.
        key = max((k for k in PLAIN if m.name.startswith(k)), key=len)
        col, emit, rough, metal, *alpha = PLAIN[key]
        m.node_tree.nodes.clear(); nodes, links = m.node_tree.nodes, m.node_tree.links
        bs = nodes.new('ShaderNodeBsdfPrincipled'); out = nodes.new('ShaderNodeOutputMaterial')
        links.new(bs.outputs[0], out.inputs['Surface'])
        bs.inputs['Base Color'].default_value = (*col, 1)
        bs.inputs['Emission Color'].default_value = (*emit, 1); bs.inputs['Emission Strength'].default_value = 1
        bs.inputs['Roughness'].default_value = rough; bs.inputs['Metallic'].default_value = metal
        # The clear crystal shell exports as alphaMode BLEND (no glTF extension).
        if alpha: bs.inputs['Alpha'].default_value = alpha[0]


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
    return before


def glb_report():
    raw = ASSET.read_bytes(); n = struct.unpack_from('<I', raw, 12)[0]; g = json.loads(raw[20:20 + n])
    tris = sum(g['accessors'][p['indices']]['count'] // 3 for mesh in g['meshes'] for p in mesh['primitives'])
    nodes = {x['name']: x for x in g['nodes']}
    return {'glb_bytes': len(raw), 'glb_sha256': hashlib.sha256(raw).hexdigest(), 'glb_triangles': tris,
            'glb_meshes': len(g['meshes']), 'glb_images': len(g.get('images', [])),
            'materials': {m['name']: m.get('alphaMode', 'OPAQUE') for m in g['materials']},
            'extensions_used': g.get('extensionsUsed', []),
            'control_nodes': {k: [g['nodes'][i]['name'] for i in nodes[k].get('children', [])] for k in CONTROLS if k in nodes},
            'crystal_local_translation': nodes['core_crystal'].get('translation')}


if __name__ == '__main__':
    target, controls, objects, metals, plain, images = setup()
    bake(metals, images); plain_materials(plain)
    triangles = join_and_export(controls, objects)
    report = {'source': 'support-core-E2.blend', 'triangles': triangles, 'atlas_size': SIZE, **glb_report()}
    assert report['glb_triangles'] == triangles and not report['extensions_used'], report
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'support-core-game-baked.blend'), compress=True)
    if '--install' in sys.argv:
        shutil.copy2(ASSET, GAME); report['installed'] = str(GAME.relative_to(ROOT))
    (OUT / 'export-check.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('SUPPORT_CORE_EXPORT', json.dumps(report, ensure_ascii=False))
