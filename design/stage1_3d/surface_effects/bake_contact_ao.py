"""정적 석재 형상의 근거리 차폐를 기존 cavity와 함께 ORM에 베이크."""
from pathlib import Path

import bpy

WORK = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(WORK / "terrain-surface.blend"))
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.render.bake.use_clear = False
root = bpy.data.objects["stage1_environment"]
authored = set(root.children_recursive)
for obj in scene.objects:
    if obj.type == "MESH":
        obj.hide_render = obj not in authored

for key in ("build", "path"):
    material = bpy.data.materials["stage1_authored_" + key]
    nodes, links = material.node_tree.nodes, material.node_tree.links
    output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
    original = output.inputs["Surface"].links[0].from_socket
    settings = next(node for node in nodes if node.type == "GROUP" and "Occlusion" in node.inputs)
    cavity = settings.inputs["Occlusion"].links[0].from_node
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.35
    ao.samples = 16
    multiply = nodes.new("ShaderNodeMath")
    multiply.operation = "MULTIPLY"
    links.new(ao.outputs["AO"], multiply.inputs[0])
    links.new(cavity.outputs["Color"], multiply.inputs[1])
    emission = nodes.new("ShaderNodeEmission")
    links.new(multiply.outputs[0], emission.inputs["Color"])
    links.new(emission.outputs[0], output.inputs["Surface"])
    image = bpy.data.images.new("stage1_contact_" + key, width=2048, height=2048, alpha=False)
    image.colorspace_settings.name = "Non-Color"
    image.generated_color = (1, 1, 1, 1)
    target = nodes.new("ShaderNodeTexImage")
    target.image = image
    nodes.active = target
    bpy.ops.object.select_all(action="DESELECT")
    for obj in authored:
        if obj.type == "MESH" and material in list(obj.data.materials):
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=4, use_clear=False)
    image.filepath_raw = str(WORK / "maps" / (image.name + ".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()
    links.new(original, output.inputs["Surface"])
    links.new(target.outputs["Color"], settings.inputs["Occlusion"])
    for node in (ao, multiply, emission):
        nodes.remove(node)
    print("CONTACT_AO_READY", key, flush=True)

# 라이브러리의 타일 원본도 계속 출력하며 검수에서만 숨겼던 상태를 복원.
for obj in scene.objects:
    obj.hide_render = False
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(WORK / "terrain-candidate.glb"), export_format="GLB",
    use_selection=True, export_yup=True, export_materials="EXPORT", export_extras=True,
    export_cameras=False, export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK / "terrain-surface.blend"))
print("CONTACT_EXPORT_READY", flush=True)
