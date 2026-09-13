"""승인 지형의 색·형태를 보존하며 전체맵 cavity와 소재별 거칠기를 베이크한다."""
from pathlib import Path
import json

import bpy


ROOT = Path(__file__).resolve().parents[3]
WORK = Path(__file__).resolve().parent
ENVIRONMENT = ROOT / "design/stage1_3d/environment"
SOURCE = ROOT / "design/stage1_3d/actor_refinement/stage1-actors-refined.blend"
MAPS = WORK / "maps"
MAPS.mkdir(exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=str(ENVIRONMENT / "terrain-approved.blend"))
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 8
scene.render.bake.use_clear = False
original_objects = set(scene.objects)
runtime_materials = {key: bpy.data.materials["stage1_authored_" + key] for key in ("build", "path")}

# 원본 UV와 월드 위치에서 사진맵·이끼 마스크를 평가한다.
with bpy.data.libraries.load(str(SOURCE), link=False) as (source, target):
    target.objects = [name for name in source.objects
                      if name.startswith(("moss covered build stone", "worn earth path"))]
groups = {"build": [], "path": []}
for obj in target.objects:
    scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    key = "build" if obj.name.startswith("moss covered") else "path"
    groups[key].append(obj)
    material = obj.data.materials[0]
    if not material.get("surface_source_uv"):
        uv = material.node_tree.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "UVMap"
        for link in list(material.node_tree.links):
            if link.from_node.type == "TEX_COORD" and link.from_socket.name == "UV":
                material.node_tree.links.new(uv.outputs["UV"], link.to_socket)
        material["surface_source_uv"] = True
    atlas = obj.data.uv_layers.new(name="SurfaceAtlas")
    for face in obj.data.polygons:
        for loop in face.loop_indices:
            point = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
            atlas.data[loop].uv = ((point.x + 8.5) / 17, (point.y + 10.5) / 21)
    obj.data.uv_layers["UVMap"].active_render = True

manifest = {}
for key, objects in groups.items():
    material = objects[0].data.materials[0]
    nodes, links = material.node_tree.nodes, material.node_tree.links
    output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
    height = next(node for node in nodes if node.type == "TEX_IMAGE" and node.image and "_disp_" in node.image.name)
    roughness = next(node for node in nodes if node.type == "TEX_IMAGE" and node.image and "_rough_" in node.image.name)
    cavity = nodes.new("ShaderNodeMapRange")
    cavity.clamp = True
    threshold = .55 if key == "build" else .30
    cavity.inputs["From Min"].default_value = threshold * .5
    cavity.inputs["From Max"].default_value = threshold
    cavity.inputs["To Min"].default_value = .55
    cavity.inputs["To Max"].default_value = 1.0
    links.new(height.outputs["Color"], cavity.inputs["Value"])

    dry = nodes.new("ShaderNodeMapRange")
    dry.clamp = True
    # 돌의 넓고 완만한 반응을 남긴다. 원본 roughness와 이끼 마스크는
    # 그대로 평가하며, 높은 공통 거칠기로 모든 면이 마르는 것을 피한다.
    dry.inputs["To Min"].default_value = .40
    dry.inputs["To Max"].default_value = .70
    links.new(roughness.outputs["Color"], dry.inputs["Value"])
    rough_output = dry.outputs["Result"]
    if key == "build":
        # 원본 색상과 같은 마스크로 돌보다 이끼의 거칠기를 높인다.
        color_mix = nodes.get("Mix (Legacy).001")
        moss = nodes.new("ShaderNodeMixRGB")
        links.new(color_mix.inputs[0].links[0].from_socket, moss.inputs[0])
        links.new(rough_output, moss.inputs[1])
        moss.inputs[2].default_value = (.90, .90, .90, 1)
        rough_output = moss.outputs["Color"]

    emission = nodes.new("ShaderNodeEmission")
    links.new(emission.outputs[0], output.inputs["Surface"])
    target_node = nodes.new("ShaderNodeTexImage")
    images = {}
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    for channel, socket in (("cavity", cavity.outputs["Result"]), ("roughness", rough_output)):
        image = bpy.data.images.new("stage1_surface_" + key + "_" + channel, width=2048, height=2048, alpha=False)
        image.colorspace_settings.name = "Non-Color"
        image.generated_color = (1, 1, 1, 1)
        target_node.image = image
        nodes.active = target_node
        links.new(socket, emission.inputs["Color"])
        bpy.ops.object.bake(type="EMIT", uv_layer="SurfaceAtlas", margin=4, use_clear=False)
        image.file_format = "PNG"
        image.filepath_raw = str(MAPS / (image.name + ".png"))
        image.save()
        image.pack()
        images[channel] = image
        print("SURFACE_BAKED", key, channel, flush=True)

    runtime = runtime_materials[key]
    rn, rl = runtime.node_tree.nodes, runtime.node_tree.links
    principled = rn.get("Principled BSDF")
    old_rough = principled.inputs["Roughness"].links[0].from_node
    old_rough.image = images["roughness"]
    # cavity를 ORM R에 넣고 기존 G 거칠기와 한 이미지로 내보낸다.
    from io_scene_gltf2.blender.com.material_helpers import create_settings_group
    settings = rn.new("ShaderNodeGroup")
    settings.node_tree = bpy.data.node_groups.get("glTF Material Output") or create_settings_group("glTF Material Output")
    occlusion = rn.new("ShaderNodeTexImage")
    occlusion.image = images["cavity"]
    occlusion.extension = old_rough.extension
    rl.new(occlusion.outputs["Color"], settings.inputs["Occlusion"])
    manifest[key] = {"sourceObjects": len(objects), "cavity": [.55, 1], "stoneRoughness": [.40, .70], "mossRoughness": .90 if key == "build" else None}

for obj in list(scene.objects):
    if obj not in original_objects:
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in original_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(obj for obj in original_objects if obj.type == "MESH")
bpy.ops.export_scene.gltf(filepath=str(WORK / "terrain-candidate.glb"), export_format="GLB", use_selection=True,
                          export_yup=True, export_materials="EXPORT", export_extras=True,
                          export_cameras=False, export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK / "terrain-surface.blend"))
(WORK / "surface-maps.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("SURFACE_MAPS_READY", flush=True)
