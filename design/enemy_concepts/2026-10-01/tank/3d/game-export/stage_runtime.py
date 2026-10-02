"""Run through Blender MCP; preserve the open mainfile and all authored scenes.

The background exporter consumes the resulting library. No saved authoring
geometry, materials, animation or current mainfile is modified.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Matrix

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent / 'walk' / 'tank-walk.blend'
WIDTH = 4.12951922416687

# Only our disposable staging scenes are rebuilt; opened authored scenes stay.
for stale in list(bpy.data.scenes):
    if stale.name.startswith('Tank_Walk_Runtime'):
        for obj in list(stale.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(stale)

# Load the approved saved scene rather than an unsaved working revision.
with bpy.data.libraries.load(str(SOURCE), link=False) as (src, dst):
    dst.scenes = ['Tank_WideChest_Walk']
source = dst.scenes[0]
source_rig = next(o for o in source.objects if o.type == 'ARMATURE')
previous_scene = bpy.context.window.scene
for window in bpy.context.window_manager.windows:
    window.scene = source
objects = [o for o in source.objects if o.type == 'MESH' and o.parent_type == 'BONE']
assert len(objects) == 38
frames = [1 + i / 10 for i in range(261)]
poses = {bone.name: [] for bone in source_rig.pose.bones}
for frame in frames:
    source.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    for bone in source_rig.pose.bones:
        p, q, s = bone.matrix_basis.decompose()
        poses[bone.name].append([list(p), list(q), list(s)])
source.frame_set(1)
source_rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
world_to_raw = source_rig.matrix_world.inverted()
root_scale = source_rig.matrix_world.to_scale().x
scene = bpy.data.scenes.new('Tank_Walk_Runtime')
scene.world = source.world.copy() if source.world else bpy.data.worlds.new('Tank_Runtime_World')
rig = source_rig.copy()
rig.data = source_rig.data.copy()
rig.parent = None
rig.name = 'Tank_Runtime_Rig'
rig.matrix_world = Matrix.Identity(4)
rig.animation_data_clear()
scene.collection.objects.link(rig)
materials = {}
fallback = bpy.data.materials.new('Tank unused cut-face fallback')
fallback.use_nodes = True
fallback.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (.8,.8,.8,1)
groups = {'body': [], 'shell': [], 'nucleus': []}
for old in objects:
    mesh = bpy.data.meshes.new_from_object(old.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
    attr = mesh.attributes.new('RestObject', 'FLOAT_VECTOR', 'POINT')
    for vertex in mesh.vertices:
        attr.data[vertex.index].vector = vertex.co
        vertex.co = world_to_raw @ old.matrix_world @ vertex.co
    obj = bpy.data.objects.new('Runtime_' + old.name, mesh)
    scene.collection.objects.link(obj)
    for index, material in enumerate(mesh.materials):
        if material is None:
            mesh.materials[index] = fallback
            continue
        if material not in materials:
            copy = material.copy()
            materials[material] = copy
            nodes, links = copy.node_tree.nodes, copy.node_tree.links
            attribute = nodes.new('ShaderNodeAttribute')
            attribute.attribute_name = 'RestObject'
            for node in list(nodes):
                if node.type == 'TEX_COORD':
                    for link in list(node.outputs['Object'].links):
                        links.new(attribute.outputs['Vector'], link.to_socket)
        mesh.materials[index] = materials[material]
    obj.vertex_groups.new(name=old.parent_bone).add(list(range(len(mesh.vertices))), 1, 'REPLACE')
    kind = 'shell' if 'single spherical amber front core' in old.name else ('nucleus' if 'small internal amber light volume' in old.name else 'body')
    groups[kind].append(obj)
source_rig.data.pose_position = 'POSE'
for window in bpy.context.window_manager.windows:
    window.scene = scene
for kind, objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = 'Tank_Runtime_' + kind
    obj.parent = rig
    obj.matrix_parent_inverse = Matrix.Identity(4)
    modifier = obj.modifiers.new('Approved rigid bone motion', 'ARMATURE')
    modifier.object = rig
    if kind == 'body':
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.003)
        bpy.ops.object.mode_set(mode='OBJECT')
scene.render.fps = 60
scene.frame_start, scene.frame_end = 1, 27
(OUT / 'local' / 'pose-samples.json').write_text(json.dumps({'frames': frames, 'poses': poses, 'source_root_scale': root_scale, 'normal_reference_width': WIDTH}))
bpy.data.libraries.write(str(OUT / 'local' / 'tank-runtime-staged.blend'), {scene}, fake_user=True, compress=True)
for window in bpy.context.window_manager.windows:
    window.scene = previous_scene
print('TANK_RUNTIME_STAGED', len(groups['body']), 'source rigid pieces; original mainfile preserved')
