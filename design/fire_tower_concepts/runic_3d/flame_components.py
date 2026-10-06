"""Broad, closed flame volumes; parent-local Z up, front -Y."""
import math
import bpy
from mathutils import Vector


def _flame_material(name, core=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (1, .15, .002, 1)
    nodes = mat.node_tree.nodes
    nodes.clear()
    links = mat.node_tree.links
    out = nodes.new('ShaderNodeOutputMaterial')
    coord = nodes.new('ShaderNodeTexCoord')
    split = nodes.new('ShaderNodeSeparateXYZ')
    links.new(coord.outputs['Generated'], split.inputs[0])
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 6.8 if core else 8.0
    noise.inputs['Detail'].default_value = 3.0
    noise.inputs['Roughness'].default_value = .66
    links.new(coord.outputs['Generated'], noise.inputs['Vector'])
    sparse = nodes.new('ShaderNodeValToRGB')
    sparse.color_ramp.elements[0].position = .29
    sparse.color_ramp.elements[0].color = (0, 0, 0, 1)
    sparse.color_ramp.elements[1].position = .71
    sparse.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(noise.outputs['Fac'], sparse.inputs[0])

    def math_node(operation, first=None, second=None):
        n = nodes.new('ShaderNodeMath')
        n.operation = operation
        for i, value in enumerate((first, second)):
            if isinstance(value, (int, float)):
                n.inputs[i].default_value = value
            elif value is not None:
                links.new(value, n.inputs[i])
        return n.outputs[0]

    # Fade the volume through its width instead of outlining an opaque surface.
    x = math_node('SUBTRACT', split.outputs['X'], .5)
    y = math_node('SUBTRACT', split.outputs['Y'], .5)
    radius = math_node('SQRT', math_node('ADD',
        math_node('MULTIPLY', x, x), math_node('MULTIPLY', y, y)))
    edge = nodes.new('ShaderNodeValToRGB')
    edge.color_ramp.elements[0].position = .14
    edge.color_ramp.elements[0].color = (1, 1, 1, 1)
    edge.color_ramp.elements[1].position = .51
    edge.color_ramp.elements[1].color = (0, 0, 0, 1)
    links.new(radius, edge.inputs[0])
    field = math_node('MULTIPLY', sparse.outputs['Color'], edge.outputs['Color'])
    power = math_node('MULTIPLY', field, 70.0 if core else 48.0)
    density = math_node('MULTIPLY', field, .10)
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .06
    ramp.color_ramp.elements[0].color = (1, .38 if core else .23, .004, 1)
    ramp.color_ramp.elements[1].position = .91
    ramp.color_ramp.elements[1].color = (1, .055 if core else .025, .0002, 1)
    links.new(split.outputs['Z'], ramp.inputs[0])
    volume = nodes.new('ShaderNodeVolumePrincipled')
    volume.inputs['Color'].default_value = (1, .16, .003, 1)
    volume.inputs['Anisotropy'].default_value = .1
    links.new(density, volume.inputs['Density'])
    links.new(power, volume.inputs['Emission Strength'])
    links.new(ramp.outputs['Color'], volume.inputs['Emission Color'])
    links.new(volume.outputs['Volume'], out.inputs['Volume'])
    return mat


def _tongue(collection, parent, name, origin, direction, length, width,
            bend, phase, material):
    rings, sides = 28, 20
    verts, faces = [], []
    for i in range(rings):
        t = i / rings
        # One shallow S, circular volume, and a short terminal point.
        x = width * bend * math.sin(t * math.pi * 1.5 + phase) * t
        y = width * .055 * math.sin(t * math.pi)
        c = Vector((x, y, length * t))
        radius = width * .5 * (1 - t ** 1.7) ** .72
        radius *= .83 + .17 * math.sin(math.pi * t)
        for j in range(sides):
            a = 2 * math.pi * j / sides
            r = radius * (1 + .045 * math.sin(3 * a + t * 2))
            verts.append(tuple(c + Vector((math.cos(a) * r, math.sin(a) * r * .88, 0))))
    for i in range(rings - 1):
        for j in range(sides):
            k = i * sides + j
            n = i * sides + (j + 1) % sides
            faces.append((k, n, n + sides, k + sides))
    verts.append((0, 0, 0))
    bottom = len(verts) - 1
    verts.append((width * bend * math.sin(math.pi * 1.5 + phase), 0, length))
    tip = len(verts) - 1
    last = (rings - 1) * sides
    for j in range(sides):
        n = (j + 1) % sides
        faces.append((bottom, n, j))
        faces.append((last + j, last + n, tip))
    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj.location = Vector(origin)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector(direction).to_track_quat('Z', 'Y')
    obj.data.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj['component'] = 'Broad closed flame tongue'
    return obj


def build_flames(collection, parent, top_origin, muzzle_origin):
    """Return independent Flame_* meshes. Both origins use parent-local coords."""
    outer = _flame_material('Flame_RedOrange_Volume')
    core = _flame_material('Flame_YellowOrange_Core', core=True)
    top, muzzle = Vector(top_origin), Vector(muzzle_origin)
    result = []

    def add(name, origin, direction, length, width, bend, phase, material):
        result.append(_tongue(collection, parent, name, origin, direction,
                              length, width, bend, phase, material))

    add('Flame_Top_Main', top, (0, 0, 1), .28, .112, .35, .15, outer)
    add('Flame_Top_Left', top + Vector((-.027, 0, .005)),
        (-.10, 0, 1), .19, .070, -.30, .3, outer)
    add('Flame_Top_Core', top + Vector((.013, -.044, .003)),
        (.04, 0, 1), .19, .065, .28, .05, core)
    add('Flame_Muzzle_Main', muzzle, (0, -1, .10),
        .17, .052, .45, .1, outer)
    add('Flame_Muzzle_Core', muzzle + Vector((.006, -.003, .012)),
        (.01, -1, .1), .125, .036, .32, .2, core)
    add('Flame_Top_BackLick', top + Vector((.024, .020, .008)),
        (.1, .03, 1), .215, .058, -.32, .5, outer)
    add('Flame_Top_FrontLick', top + Vector((-.020, -.020, .002)),
        (-.1, -.02, 1), .16, .057, .32, .2, core)
    add('Flame_Muzzle_Lick', muzzle + Vector((-.010, -.03, .008)),
        (-.1, -1, .25), .105, .032, -.38, .4, outer)
    return result
