"""Build a reusable genuine 3D placement-dust puff in a new Blender scene.
Execute via Blender MCP. Never reset/open/save over the currently open project.
"""
from pathlib import Path
import bpy
import json
import math
from mathutils import Vector, noise

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SCENE_NAME = 'PlacementDust3D'
if bpy.data.scenes.get(SCENE_NAME):
    raise RuntimeError('PlacementDust3D already exists; edit that scene instead of regenerating it.')
scene = bpy.data.scenes.new(SCENE_NAME)
previous = bpy.context.window.scene
try:
    bpy.context.window.scene = scene
    field = bpy.data.metaballs.new('Placement dust editable union')
    field.resolution = 0.055
    field.render_resolution = 0.055
    field.threshold = 0.7
    source = bpy.data.objects.new('PlacementDust_EditableField', field)
    scene.collection.objects.link(source)
    # Substantial overlap yields one soft, continuous volume, never separate beads.
    for xyz, radius in [((0,0,0),.48), ((-.23,.03,.04),.34),
                        ((.20,-.10,-.02),.33), ((.02,.20,.07),.31),
                        ((.13,.15,-.08),.28), ((-.15,-.16,-.05),.29)]:
        element = field.elements.new()
        element.co = xyz
        element.radius = radius
        element.stiffness = 1.7
    source.scale = (1, .84, .37)
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.convert(target='MESH')
    puff = bpy.context.object
    puff.name = 'placement_dust_puff'
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    vertices = puff.data.vertices
    lo = Vector(tuple(min(v.co[i] for v in vertices) for i in range(3)))
    hi = Vector(tuple(max(v.co[i] for v in vertices) for i in range(3)))
    center = (lo + hi) / 2
    width = max(hi.x-lo.x, hi.y-lo.y)
    for vertex in vertices:
        vertex.co = (vertex.co-center) / width
        # Small spatial undulations preserve fused shoulders while avoiding a sphere.
        p = vertex.co
        perturb = noise.noise_vector(p*7.4 + Vector((2.7,8.1,4.6)), noise_basis='PERLIN_ORIGINAL')
        vertex.co += Vector((perturb.x*.014,perturb.y*.014,perturb.z*.007))
    puff.data.update()
    for polygon in puff.data.polygons: polygon.use_smooth = True
    color = puff.data.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
    for vertex in vertices:
        density = max(.55, min(1, .78 + .22 * noise.noise(vertex.co*9.0+Vector((7.1,3.2,1.8)), noise_basis='PERLIN_ORIGINAL')))
        variation = .86 + .14 * noise.noise(vertex.co*5.0+Vector((2.3,8.2,4.1)),noise_basis='PERLIN_ORIGINAL')
        color.data[vertex.index].color = (.53*variation, .485*variation, .405*variation, density)
    puff.data.color_attributes.active_color = color
    material = bpy.data.materials.new('PlacementDust_SoftGreyBrown')
    material.use_nodes = True
    material.diffuse_color = (.53,.485,.405,.32)
    principled = material.node_tree.nodes.get('Principled BSDF')
    principled.inputs['Base Color'].default_value = (.53,.485,.405,1)
    vertex_color=material.node_tree.nodes.new('ShaderNodeVertexColor')
    vertex_color.layer_name='Color'
    material.node_tree.links.new(vertex_color.outputs['Color'],principled.inputs['Base Color'])
    principled.inputs['Roughness'].default_value = 1
    principled.inputs['Metallic'].default_value = 0
    principled.inputs['Specular IOR Level'].default_value = 0
    principled.inputs['Alpha'].default_value = .32
    material.surface_render_method = 'BLENDED'
    material.use_transparency_overlap = False
    puff.data.materials.append(material)
    puff['coordinate_contract'] = 'Blender Z up; glTF/Godot Y up; center origin; approximately 1 unit maximum width'
    puff['runtime'] = 'Native MultiMesh; 360 degree base-level radial dust; 0.58-0.65 s; alpha and normal-dependent edge softness'
    puff['COLOR_0'] = 'RGB grey-brown variation; A 0.55..1 spatial density; not baked lighting'
    scene['representation'] = 'One continuous non-camera-facing closed 3D mesh; no texture/quad/flipbook; smooth normals'
    scene['source_editing'] = 'Editable mesh; build_source.py reconstructs the fused initial metaball field. Use export.py after edits.'
    scene.world = bpy.data.worlds.new('PlacementDust neutral world')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.17,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    text=bpy.data.texts.new('PlacementDust_RuntimeContract')
    text.write('Single low asymmetric puff, real closed 3D geometry. Native material handles lifetime, opacity, edge softness and spatial density. Source RGB is dust variation; alpha carries spatial density. Do not face the mesh toward the camera.\n')
    text.use_fake_user=True
    for vertex in vertices: assert all(math.isfinite(v) for v in vertex.co)
    exec(compile((HERE/'animate_source.py').read_text(),str(HERE/'animate_source.py'),'exec'), {'__file__':str(HERE/'animate_source.py'),'__name__':'__main__'})
    exec(compile((HERE/'build_volume.py').read_text(),str(HERE/'build_volume.py'),'exec'), {'__file__':str(HERE/'build_volume.py'),'__name__':'__main__'})
    exec(compile((HERE/'export.py').read_text(), str(HERE/'export.py'), 'exec'), {'__file__':str(HERE/'export.py'), '__name__':'__main__'})
    bpy.data.libraries.write(str(HERE/'placement-dust.blend'), {scene,text}, fake_user=True)
    print('PLACEMENT_DUST_SOURCE '+str(HERE/'placement-dust.blend'))
finally:
    bpy.context.window.scene = previous
