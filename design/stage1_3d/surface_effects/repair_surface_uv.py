"""상면 atlas를 보존하면서 평면 투영으로 붕괴한 슬랩 측면 UV를 복구."""
from pathlib import Path

import bpy

WORK = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(WORK / "terrain-surface.blend"))
root = bpy.data.objects["stage1_environment"]
for obj in root.children_recursive:
    if obj.type != "MESH" or not obj.data.materials:
        continue
    material = obj.data.materials[0]
    if material.name not in ("stage1_authored_build", "stage1_authored_path"):
        continue
    side_name = "C1_mossy_PBR_stone" if material.name.endswith("build") else "C1_worn_earth_cobbles"
    side = bpy.data.materials[side_name]
    if side not in list(obj.data.materials):
        obj.data.materials.append(side)
    side_index = list(obj.data.materials).index(side)
    uv = obj.data.uv_layers.active
    count = 0
    for face in obj.data.polygons:
        if abs(face.normal.z) >= 0.5:
            continue
        face.material_index = side_index
        axis = 0 if abs(face.normal.x) > abs(face.normal.y) else 1
        for loop in face.loop_indices:
            point = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (point.y if axis == 0 else point.x, point.z + 0.041)
        count += 1
    print("SIDE_UV_REPAIRED", obj.name, count, flush=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(WORK / "terrain-candidate.glb"), export_format="GLB",
    use_selection=True, export_yup=True, export_materials="EXPORT", export_extras=True,
    export_cameras=False, export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK / "terrain-surface.blend"))
print("SURFACE_UV_EXPORT_READY", flush=True)
