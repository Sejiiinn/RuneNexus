"""Finished irregular flame volumes; parent-local Z up, front -Y."""
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
    noise.inputs['Scale'].default_value = 5.6 if core else 7.2
    noise.inputs['Detail'].default_value = 3.0
    noise.inputs['Roughness'].default_value = .66
    links.new(coord.outputs['Generated'], noise.inputs['Vector'])
    sparse = nodes.new('ShaderNodeValToRGB')
    sparse.color_ramp.elements[0].position = .23
    sparse.color_ramp.elements[0].color = (0, 0, 0, 1)
    sparse.color_ramp.elements[1].position = .65
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
    edge.color_ramp.elements[0].position = .27
    edge.color_ramp.elements[0].color = (1, 1, 1, 1)
    edge.color_ramp.elements[1].position = .72
    edge.color_ramp.elements[1].color = (0, 0, 0, 1)
    links.new(radius, edge.inputs[0])
    field = math_node('MULTIPLY', sparse.outputs['Color'], edge.outputs['Color'])
    power = math_node('MULTIPLY', field, 76.0 if core else 60.0)
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
    rings, sides = 40, 20
    verts, faces = [], []
    for i in range(rings):
        t = i / rings
        # One shallow S, circular volume, and a short terminal point.
        x = width * bend * (math.sin(t * math.pi * 2 + phase) - math.sin(phase)) * t ** .7
        y = width * .12 * math.sin(t * math.pi * 1.8 + phase) * t
        c = Vector((x, y, length * t))
        radius = width * .5 * (1 - t ** 1.35) ** .76
        radius *= .84 + .16 * math.sin(math.pi * t) + .065 * math.sin(t * 13 + phase)
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
    verts.append((0, width * .12 * math.sin(math.pi * 1.8 + phase), length))
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



def build_finished_flames(collection, parent, top_origin, muzzle_origin):
    """Create 5 top tongues, 3 muzzle tongues and 5 tiny solid ember slivers.

    No scene edits beyond adding owned objects/materials. Returns created objects.
    """
    outer = _flame_material('Flame_Finish_OrangeVolume')
    core = _flame_material('Flame_Finish_GoldenVolume', core=True)
    top, muzzle = Vector(top_origin), Vector(muzzle_origin)
    result = []

    def add(name, origin, direction, length, width, bend, phase, material):
        obj = _tongue(collection, parent, name, origin, direction,
                      length, width, bend, phase, material)
        result.append(obj)
        return obj

    # Different heights, offset crests and opposing bends avoid a three-prong crown.
    add('Flame_Finish_Top_Main', top, (.04, .01, 1),
        .252, .096, .57, .2, outer)
    add('Flame_Finish_Top_Left', top + Vector((-.029, .006, .007)),
        (-.13, .015, 1), .178, .063, -.60, -.5, outer)
    add('Flame_Finish_Top_Right', top + Vector((.021, .016, .004)),
        (.04, -.02, 1), .214, .060, .65, 1.0, outer)
    add('Flame_Finish_Top_Core', top + Vector((.008, -.025, .001)),
        (.03, -.02, 1), .192, .070, .49, .3, core)
    add('Flame_Finish_Top_Front', top + Vector((-.022, -.018, .002)),
        (-.07, -.015, 1), .137, .060, -.5, .1, core)

    add('Flame_Finish_Muzzle_Main', muzzle, (0, -1, .17),
        .236, .061, .56, .3, outer)
    add('Flame_Finish_Muzzle_Core', muzzle + Vector((.003, -.002, .006)),
        (.005, -1, .16), .198, .046, .50, .4, core)
    add('Flame_Finish_Muzzle_Lick', muzzle + Vector((-.010, -.049, .010)),
        (-.025, -1, .22), .161, .045, -.58, .0, outer)

    ember = bpy.data.materials.new('Flame_Finish_EmberGlow')
    ember.use_nodes = True
    nodes = ember.node_tree.nodes
    nodes.clear()
    emission = nodes.new('ShaderNodeEmission')
    emission.inputs['Color'].default_value = (1, .095, .001, 1)
    emission.inputs['Strength'].default_value = 3.0
    output = nodes.new('ShaderNodeOutputMaterial')
    ember.node_tree.links.new(emission.outputs[0], output.inputs['Surface'])
    # Short curved, solid slivers: true 3D embers rather than spheres/billboards.
    for i, (offset, length, width, lean) in enumerate([
        ((-.052, .004, .218), .016, .0050, -.30),
        ((.047, -.005, .250), .013, .0040, .22),
        ((.004, .008, .289), .012, .0035, -.20),
        ((-.038, -.020, .279), .009, .0032, .30),
    ]):
        add('Flame_Finish_Ember_Top_%02d' % i, top + Vector(offset),
            (lean, .05, 1), length, width, .35, .3, ember)
    add('Flame_Finish_Ember_Muzzle', muzzle + Vector((.006, -.266, .057)),
        (.1, -1, .35), .012, .004, .3, .4, ember)
    return result
