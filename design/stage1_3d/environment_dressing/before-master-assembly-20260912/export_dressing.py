"""현행 Blender 원본의 장식을 애니메이션 없는 두 메시로 합쳐 GLB 출력."""
from pathlib import Path
import json

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TARGET = ROOT / "assets/images/stage1_3d/environment/dressing.glb"


def export():
    source_root = bpy.data.objects.get("stage1_dressing")
    if source_root is None or not source_root.children:
        raise RuntimeError("environment-dressing.blend 원본을 먼저 여세요.")
    original_scene = bpy.context.scene
    export_scene = bpy.data.scenes.new("Dressing Export (temporary)")
    root = bpy.data.objects.new("stage1_dressing_export", None)
    export_scene.collection.objects.link(root)
    for key, value in source_root.items():
        root[key] = value
    summary = {"meshes": [], "extraTextureBytes": 0, "windMaximumDisplacement": .022}
    try:
        bpy.context.window.scene = export_scene
        for group in ("foliage", "rocks"):
            vertices, faces, colors, uvs, occupancy_uvs = [], [], [], [], []
            for obj in source_root.children:
                if obj.get("dressingGroup") != group or obj.type != 'MESH':
                    continue
                mesh = obj.data
                offset = len(vertices)
                # Basis 좌표로 출력. Blender 미리보기 Shape Key와 드라이버는 제외.
                vertices.extend(tuple(obj.matrix_world @ vertex.co) for vertex in mesh.vertices)
                faces.extend(tuple(index + offset for index in polygon.vertices) for polygon in mesh.polygons)
                color = mesh.color_attributes.get("Color")
                colors.extend(tuple(item.color) for item in color.data)
                uvs.extend(tuple(item.uv) for item in mesh.uv_layers[0].data)
                occupancy_uvs.extend(tuple(item.uv) for item in mesh.uv_layers["Occupancy"].data)
            mesh = bpy.data.meshes.new("stage1_dressing_" + group)
            mesh.from_pydata(vertices, [], faces)
            mesh.materials.append(bpy.data.materials["Stage1Dressing_" + group])
            if group == "foliage":
                for polygon in mesh.polygons:
                    polygon.use_smooth = True
            color = mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='POINT')
            mesh.color_attributes.active_color = color
            for item, rgba in zip(color.data, colors):
                item.color = rgba
            uv = mesh.uv_layers.new(name="Wind")
            for item, value in zip(uv.data, uvs):
                item.uv = value
            occupancy = mesh.uv_layers.new(name="Occupancy")
            for item, value in zip(occupancy.data, occupancy_uvs):
                item.uv = value
            mesh.update()
            mesh.calc_loop_triangles()
            obj = bpy.data.objects.new("stage1_dressing_" + group, mesh)
            export_scene.collection.objects.link(obj)
            obj.parent = root
            minimum = tuple(min(v[i] for v in vertices) for i in range(3))
            maximum = tuple(max(v[i] for v in vertices) for i in range(3))
            summary["meshes"].append({"name": obj.name, "vertices": len(vertices),
                                      "triangles": len(mesh.loop_triangles), "boundsBlender": [minimum, maximum]})
        root["runtimeMeshCount"] = 2
        root["runtimeTriangleCount"] = sum(m["triangles"] for m in summary["meshes"])
        assert root["runtimeTriangleCount"] <= 24000, summary
        original_name = source_root.name
        source_root.name = "stage1_dressing_authoring"
        root.name = "stage1_dressing"
        try:
            bpy.ops.object.select_all(action='SELECT')
            bpy.ops.export_scene.gltf(filepath=str(TARGET), export_format='GLB', use_selection=True, use_active_scene=True,
                export_yup=True, export_materials='EXPORT', export_extras=True, export_cameras=False,
                export_lights=False, export_animations=False, export_morph=False)
        finally:
            root.name = "stage1_dressing_export"
            source_root.name = original_name
        summary["glbBytes"] = TARGET.stat().st_size
        (HERE / "export_manifest.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
        print("DRESSING_EXPORTED", json.dumps(summary))
    finally:
        for obj in list(export_scene.objects):
            mesh = obj.data if obj.type == 'MESH' else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh is not None:
                bpy.data.meshes.remove(mesh)
        bpy.context.window.scene = original_scene
        bpy.data.scenes.remove(export_scene)


if __name__ == "__main__":
    export()
