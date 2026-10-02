"""Background bake/export of the approved rigid tank. Run after stage_runtime.py.

Production input: ../walk/tank-walk.blend. No reduction of source triangles.
Procedural object-space stone is baked; the two actual core spheres stay 3D.
"""
import bpy
import json
import math
import struct
import hashlib
import sys
from pathlib import Path
from mathutils import Vector, Quaternion

OUT = Path(__file__).resolve().parent
SIZE, TOL = 2048, .00015
REUSE_ATLAS = '--reuse-atlas' in sys.argv
scene = bpy.data.scenes['Tank_Walk_Runtime']
for window in bpy.context.window_manager.windows:
    window.scene = scene
rig = scene.objects['Tank_Runtime_Rig']
body = scene.objects['Tank_Runtime_body']
mesh_objects = [o for o in scene.objects if o.type == 'MESH']
samples = json.loads((OUT / 'local' / 'pose-samples.json').read_text())
frames, poses = samples['frames'], samples['poses']
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.render.bake.use_clear = False
scene.render.bake.margin = 8
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
images = {}
for name in ['color', 'roughness', 'metallic', 'normal', 'emission']:
    image = bpy.data.images.load(str(OUT / ('tank-' + name + '.png'))) if REUSE_ATLAS else bpy.data.images.new('Tank atlas ' + name, width=SIZE, height=SIZE, alpha=False)
    if name != 'color' and name != 'emission':
        image.colorspace_settings.name = 'Non-Color'
    image.filepath_raw = str(OUT / ('tank-' + name + '.png'))
    image.file_format = 'PNG'
    images[name] = image
materials = list(dict.fromkeys(body.data.materials))
for material in materials:
    target = material.node_tree.nodes.new('ShaderNodeTexImage')
    target.name = 'Bake Target'
    material.node_tree.nodes.active = target
for name, bake_type in [('color', 'EMIT'), ('roughness', 'ROUGHNESS'), ('metallic', 'EMIT'), ('normal', 'NORMAL'), ('emission', 'EMIT')]:
    if REUSE_ATLAS:
        images[name].pack()
        continue
    restore = []
    for material in materials:
        nodes, links = material.node_tree.nodes, material.node_tree.links
        nodes['Bake Target'].image = images[name]
        if name in ['color', 'metallic', 'emission']:
            bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
            output = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
            emission = nodes.new('ShaderNodeEmission')
            socket = bsdf.inputs[{'color': 'Base Color', 'metallic': 'Metallic', 'emission': 'Emission Color'}[name]]
            if socket.is_linked:
                links.new(socket.links[0].from_socket, emission.inputs['Color'])
            else:
                value = socket.default_value
                emission.inputs['Color'].default_value = (value, value, value, 1) if name == 'metallic' else tuple(value)
            emission.inputs['Strength'].default_value = bsdf.inputs['Emission Strength'].default_value if name == 'emission' else 1
            links.new(emission.outputs[0], output.inputs['Surface'])
            restore.append((material, bsdf, output, emission))
    bpy.ops.object.bake(type=bake_type)
    for material, bsdf, output, emission in restore:
        material.node_tree.links.new(bsdf.outputs[0], output.inputs['Surface'])
        material.node_tree.nodes.remove(emission)
    images[name].save()
    images[name].pack()
    print('TANK_BAKED', name, flush=True)
atlas = bpy.data.materials.new('Tank_WeatheredStone_PBR')
atlas.use_nodes = True
nodes, links = atlas.node_tree.nodes, atlas.node_tree.links
bsdf = nodes.get('Principled BSDF')
for name, socket in [('color','Base Color'), ('roughness','Roughness'), ('metallic','Metallic'), ('normal','Normal'), ('emission','Emission Color')]:
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = images[name]
    if name == 'normal':
        normal = nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = 1
        links.new(texture.outputs['Color'], normal.inputs['Color'])
        links.new(normal.outputs[0], bsdf.inputs[socket])
    else:
        links.new(texture.outputs['Color'], bsdf.inputs[socket])
bsdf.inputs['Emission Strength'].default_value = 1
body.data.materials.clear()
body.data.materials.append(atlas)
for polygon in body.data.polygons:
    polygon.material_index = 0
# These actual nested spheres preserve volume and remain separate from the stone.
# Alpha supplies the Godot realtime glass fallback; source transmission stays set.
shell = scene.objects['Tank_Runtime_shell']
shell.data.materials[0].name = 'Tank_AmberShell_crystal'
shell_bsdf = next(n for n in shell.data.materials[0].node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
shell_bsdf.inputs['Alpha'].default_value = .38
shell.data.materials[0].surface_render_method = 'DITHERED'
nucleus = scene.objects['Tank_Runtime_nucleus']
nucleus.data.materials[0].name = 'Tank_AmberNucleus_crystal'
nucleus_bsdf = next(n for n in nucleus.data.materials[0].node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
# The authoring Layer Weight node is camera dependent and unsupported by glTF.
# Preserve the orange body and moderate inner light as an engine PBR material.
for link in list(nucleus_bsdf.inputs['Emission Color'].links):
    nucleus.data.materials[0].node_tree.links.remove(link)
# The same unsupported camera ramp also feeds Base Color; glTF otherwise
# silently exports white. Preserve its authored amber fallback color explicitly.
for link in list(nucleus_bsdf.inputs['Base Color'].links):
    nucleus.data.materials[0].node_tree.links.remove(link)
nucleus_bsdf.inputs['Emission Color'].default_value = (1, .36, .022, 1)
nucleus_bsdf.inputs['Emission Strength'].default_value = .72
rig.data.pose_position = 'POSE'
kept, errors = {}, {}
for bone in rig.pose.bones:
    points = [rig.data.bones[bone.name].matrix_local.inverted() @ vertex.co for mesh in mesh_objects for vertex in mesh.data.vertices if any(mesh.vertex_groups[g.group].name == bone.name and g.weight > .5 for g in vertex.groups)]
    radius = max([p.length for p in points] + [.1])
    values = [(Vector(p), Quaternion(q), Vector(s)) for p,q,s in poses[bone.name]]
    def error(index, first, last):
        u = (frames[index] - frames[first]) / (frames[last] - frames[first])
        p,q,s = values[index]
        p0,q0,s0 = values[first]
        p1,q1,s1 = values[last]
        angle = q.rotation_difference(q0.slerp(q1,u)).angle
        return (p-p0.lerp(p1,u)).length + radius * (min(angle, 2*math.pi-angle) + (s-s0.lerp(s1,u)).length)
    keep, pending = {0,len(frames)-1}, [(0,len(frames)-1)]
    while pending:
        first,last = pending.pop()
        if last-first <= 1: continue
        deviation,index = max((error(i,first,last),i) for i in range(first+1,last))
        if deviation > TOL:
            keep.add(index)
            pending.extend([(first,index),(index,last)])
    keys = sorted(keep)
    # Support-chain sampling is cheap (eight bones) and contact matters more
    # than compressing a few KB beside the PBR atlas. Retain the dense samples.
    if bone.name in ['root','pelvis','thigh.L','thigh.R','ankle_link.L','ankle_link.R','foot.L','foot.R']:
        keys = list(range(len(frames)))
    kept[bone.name] = len(keys)
    errors[bone.name] = max([error(i,a,z) for a,z in zip(keys,keys[1:]) for i in range(a+1,z)] + [0])
    for index in keys:
        bone.location, bone.rotation_quaternion, bone.scale = values[index]
        bone.rotation_mode = 'QUATERNION'
        for prop in ['location','rotation_quaternion','scale']:
            # glTF sampler input must start at t=0, including the closure key.
            bone.keyframe_insert(prop, frame=frames[index] - 1, group=bone.name)
action = rig.animation_data.action
action.name = 'Walk'
action.use_fake_user = True
for layer in action.layers:
    for strip in layer.strips:
        for slot in action.slots:
            bag = strip.channelbag(slot)
            if bag:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
rig.scale = (samples['source_root_scale'] / samples['normal_reference_width'],)*3
scene.frame_start, scene.frame_end = 0, 26
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in mesh_objects: obj.select_set(True)
bpy.context.view_layer.objects.active = rig
path = OUT / 'tank-walk.glb'
bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, use_active_scene=True, export_animations=True, export_force_sampling=False, export_animation_mode='ACTIVE_ACTIONS', export_cameras=False, export_lights=False, export_extras=True, export_skins=True, export_morph=False)
raw = path.read_bytes()
length = struct.unpack_from('<I',raw,12)[0]
doc = json.loads(raw[20:20+length])
assert len(doc['animations']) == 1
doc['animations'][0]['name'] = 'Walk'
encoded = json.dumps(doc,separators=(',',':')).encode()
encoded += b' '*((-len(encoded))%4)
tail = raw[20+length:]
path.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(tail)) + struct.pack('<I4s',len(encoded),b'JSON') + encoded + tail)
triangles = 0
for obj in mesh_objects:
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
assert triangles == 21664
report = {'source_sha256': hashlib.sha256((OUT.parent/'walk'/'tank-walk.blend').read_bytes()).hexdigest(), 'source_meshes':38, 'runtime_meshes':3, 'runtime_materials':3, 'runtime_triangles':triangles, 'rigid_bones':14, 'clip':'Walk', 'duration_seconds':26/60, 'cycle_distance_preview_tiles':.284375, 'cycle_distance_game_tiles':.284375*1.15, 'root_normalization':rig.scale.x, 'normal_reference_width':samples['normal_reference_width'], 'source_root_scale':samples['source_root_scale'], 'tank_content_presentation_scale':.65, 'tank_runtime_visual_factor':.55/.65*1.15, 'common_display_scale':1.15, 'rest_height_ratio':1.25, 'pose_key_count':kept, 'max_rdp_model_error':max(errors.values()), 'atlas_resolution':SIZE, 'glb_bytes':path.stat().st_size}
(OUT/'runtime-contract.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tank-walk-runtime.blend'), compress=True)
print('TANK_RUNTIME_DONE', json.dumps(report), flush=True)
