"""Procedural forged-metal finish; execute apply_material_finish(scene) in Blender.

Only the four named material node trees are edited. No geometry, render settings,
external textures, or scene objects are created. Units match the .86 m plinth.
"""
import bpy


PROFILES = {
    'Iron | forged charcoal': {
        'low': (.037, .042, .050, 1), 'high': (.076, .082, .095, 1),
        'wear': (.19, .205, .225, 1), 'metal': .82, 'rough': (.48, .60),
        'relief': .0009, 'crack': .0010, 'edge': .0022,
    },
    'Bronze | worn warm alloy': {
        'low': (.34, .173, .057, 1), 'high': (.56, .33, .14, 1),
        'wear': (.72, .47, .235, 1), 'metal': .78, 'rough': (.41, .54),
        'relief': .0008, 'crack': .0008, 'edge': .0018,
    },
    'Steel | polished bevel detail': {
        'low': (.072, .086, .104, 1), 'high': (.18, .205, .235, 1),
        'wear': (.32, .345, .38, 1), 'metal': .88, 'rough': (.25, .36),
        'relief': .0008, 'crack': .00025, 'edge': .0015,
    },
    'Recess | dark gunmetal': {
        'low': (.007, .010, .014, 1), 'high': (.021, .028, .035, 1),
        'wear': (.048, .059, .071, 1), 'metal': .67, 'rough': (.43, .57),
        'relief': .0008, 'crack': .0002, 'edge': .001,
    },
}


def _finish(material, p):
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    nodes, links = tree.nodes, tree.links

    def node(kind, label, x, y):
        n = nodes.new(kind)
        n.name = n.label = label
        n.location = (x, y)
        return n

    def wire(source, socket, target, inlet):
        links.new(source.outputs[socket], target.inputs[inlet])

    def ramp(label, source, socket, stops, x, y):
        n = node('ShaderNodeValToRGB', label, x, y)
        n.color_ramp.interpolation = 'EASE'
        for e, (position, color) in zip(n.color_ramp.elements, stops):
            e.position, e.color = position, color
        wire(source, socket, n, 'Fac')
        return n

    coord = node('ShaderNodeTexCoord', 'Object coordinates — physical scale', -1400, 300)
    # Object coordinates preserve physical feature size across the model's meshes;
    # unlike Generated coordinates they do not stretch to each part's bounding box.
    warp = node('ShaderNodeTexNoise', 'Broad irregular forging flow', -1190, 480)
    warp.inputs['Scale'].default_value = 9
    warp.inputs['Detail'].default_value = 2
    warp.inputs['Roughness'].default_value = .65
    wire(coord, 'Object', warp, 'Vector')
    distortion = node('ShaderNodeVectorMath', 'Subtle distortion in metres', -980, 550)
    distortion.operation = 'SCALE'
    distortion.inputs['Scale'].default_value = .019
    wire(warp, 'Color', distortion, 0)
    vector = node('ShaderNodeVectorMath', 'Warped object position', -780, 500)
    vector.operation = 'ADD'
    wire(coord, 'Object', vector, 0)
    wire(distortion, 'Vector', vector, 1)

    hammer = node('ShaderNodeTexVoronoi', 'Broad shallow hammer impressions', -580, 660)
    hammer.feature = 'SMOOTH_F1'
    hammer.inputs['Scale'].default_value = 27
    hammer.inputs['Smoothness'].default_value = .62
    wire(vector, 'Vector', hammer, 'Vector')
    forge = ramp('Soft broad forged planes', hammer, 'Distance',
                 [(.13, (.12, .12, .12, 1)), (.7, (.84, .84, .84, 1))], -360, 650)

    cells = node('ShaderNodeTexVoronoi', 'Irregular medium-scale fissure network', -580, 340)
    cells.feature = 'DISTANCE_TO_EDGE'
    cells.inputs['Scale'].default_value = 39
    wire(vector, 'Vector', cells, 'Vector')
    fissure = ramp('Hairline incisions, not painted spots', cells, 'Distance',
                   [(.006, (0, 0, 0, 1)), (.026, (1, 1, 1, 1))], -360, 330)
    # Only some network stretches survive; avoids uniform all-over cracked clay.
    gate = ramp('Discontinuous fissure coverage', warp, 'Fac',
                [(.38, (1, 1, 1, 1)), (.61, (0, 0, 0, 1))], -360, 100)
    broken = node('ShaderNodeMath', 'Broken restrained crack height', -100, 290)
    broken.operation = 'MAXIMUM'
    wire(fissure, 'Color', broken, 0)
    wire(gate, 'Color', broken, 1)

    tint = ramp('Charcoal / warm alloy material variation', warp, 'Fac',
                [(.18, p['low']), (.82, p['high'])], -360, -140)
    crack_tint = ramp('Shallow crevice patina', broken, 'Value',
                     [(0, (.63, .63, .63, 1)), (1, (1, 1, 1, 1))], 100, 100)
    patina = node('ShaderNodeMixRGB', 'Patina belongs inside relief', 330, -60)
    patina.blend_type = 'MULTIPLY'
    patina.inputs[0].default_value = .5
    wire(tint, 'Color', patina, 1)
    wire(crack_tint, 'Color', patina, 2)

    bevel = node('ShaderNodeBevel', 'Soft physical edge rounding', 100, 650)
    bevel.samples = 4
    bevel.inputs['Radius'].default_value = p['edge']
    geometry = node('ShaderNodeNewGeometry', 'Original surface normal', -110, -400)
    dot = node('ShaderNodeVectorMath', 'Bevel deviation', 110, -380)
    dot.operation = 'DOT_PRODUCT'
    wire(geometry, 'Normal', dot, 0)
    wire(bevel, 'Normal', dot, 1)
    edge = ramp('Restrained bright worn edge', dot, 'Value',
                [(.86, (.55, .55, .55, 1)), (.999, (0, 0, 0, 1))], 330, -360)
    wear = node('ShaderNodeMixRGB', 'Exposed alloy at rounded edges', 570, -20)
    wire(edge, 'Color', wear, 0)
    wire(patina, 'Color', wear, 1)
    wear.inputs[2].default_value = p['wear']

    broad_bump = node('ShaderNodeBump', 'Actual shallow forged surface normals', 350, 650)
    broad_bump.inputs['Strength'].default_value = .32
    broad_bump.inputs['Distance'].default_value = p['relief']
    wire(forge, 'Color', broad_bump, 'Height')
    wire(bevel, 'Normal', broad_bump, 'Normal')
    crack_bump = node('ShaderNodeBump', 'Fine recessed fracture normals', 570, 540)
    crack_bump.inputs['Strength'].default_value = .28
    crack_bump.inputs['Distance'].default_value = p['crack']
    wire(broken, 'Value', crack_bump, 'Height')
    wire(broad_bump, 'Normal', crack_bump, 'Normal')
    rough = node('ShaderNodeMapRange', 'Mid-gloss forged roughness', 560, -240)
    rough.inputs['To Min'].default_value = p['rough'][0]
    rough.inputs['To Max'].default_value = p['rough'][1]
    wire(warp, 'Fac', rough, 'Value')
    bsdf = node('ShaderNodeBsdfPrincipled', 'Forged metal finish', 840, 230)
    bsdf.inputs['Metallic'].default_value = p['metal']
    wire(wear, 'Color', bsdf, 'Base Color')
    wire(rough, 'Result', bsdf, 'Roughness')
    wire(crack_bump, 'Normal', bsdf, 'Normal')
    output = node('ShaderNodeOutputMaterial', 'Material Output', 1160, 230)
    wire(bsdf, 'BSDF', output, 'Surface')
    material.diffuse_color = p['high']
    material['finish_version'] = 'forged_surface_v1'


def apply_material_finish(scene):
    """Edit existing scene-used named materials in place; safe to run repeatedly."""
    used = {slot.material for obj in scene.objects for slot in obj.material_slots
            if slot.material is not None}
    updated, missing = [], []
    for name, profile in PROFILES.items():
        materials = [m for m in used if m.name == name or
                     (m.name.startswith(name + '.') and m.name[len(name) + 1:].isdigit())]
        if not materials:
            missing.append(name)
        for material in materials:
            _finish(material, profile)
            updated.append(material.name)
    return {'updated_materials': sorted(updated), 'missing_materials': missing,
            'coordinate_space': 'Object, metre-scale model coordinates',
            'geometry_changed': False, 'render_settings_changed': False}
