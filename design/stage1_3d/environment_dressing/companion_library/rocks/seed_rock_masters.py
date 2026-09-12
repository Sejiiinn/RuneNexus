"""바위 독립 원본의 최초 생성. 저장된 원본은 재생성하지 않고 Blender에서 편집."""

from pathlib import Path
import json
import math
import random
import sys

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree


HERE = Path(__file__).resolve().parent
TARGET = HERE / "rock-masters.blend"
MANIFEST = HERE / "rock-masters-manifest.json"
CONCEPT = "design/stage1_3d/environment_concepts/01-overgrown-stone-edges.png"


def linear(hex_color):
    values = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in values)


def make_material(name, roughness):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*linear("777d6d" if "Moss" in name else "888b83"), 1)
    nodes = material.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Color"
    material.node_tree.links.new(attribute.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = .17 if "Stone" in name else .10
    material.use_backface_culling = True
    return material


def finish_mesh(scene, root, name, vertices, faces, material, role, bevel=0.0):
    mesh = bpy.data.meshes.new(name + " Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = root
    obj["partRole"] = role
    obj["editableMasterPart"] = True
    mesh.materials.append(material)
    # 공유 정점의 바깥쪽 법선. 정점색은 면취 적용 뒤 부여.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    if bevel:
        bpy.context.window.scene = scene
        for other in scene.objects:
            other.select_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("작은 파손 모서리 — 적용 완료", 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        modifier.affect = 'EDGES'
        modifier.limit_method = 'ANGLE'
        modifier.angle_limit = math.radians(12)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.update()
    return obj


def paint_stone(obj, hex_color, seed, layered=False):
    """미세 텍스처 없이 넓은 광물 면·접지 암부·낮은 층리 명암."""
    base = linear(hex_color)
    mesh = obj.data
    color = mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='POINT')
    mesh.color_attributes.active_color = color
    z_min = min(v.co.z for v in mesh.vertices)
    z_max = max(v.co.z for v in mesh.vertices)
    rng = random.Random(seed)
    for vertex, entry in zip(mesh.vertices, color.data):
        x, y, z = vertex.co
        height = (z - z_min) / max(.001, z_max - z_min)
        base_occlusion = .54 + .46 * min(1, height / .65)
        mineral = .93 + .045 * math.sin(x * 19 + y * 11 + seed) + .035 * math.cos(y * 23 - x * 6)
        strata = 1.0 - (.10 if layered and .28 < height < .46 else 0)
        warmth = rng.uniform(-.018, .018)
        entry.color = tuple(max(.002, min(1, c * base_occlusion * mineral * strata + warmth * (.25 if i == 2 else .35)))
                            for i, c in enumerate(base)) + (1,)
    # 큰 석재 면의 평면성 보존. 작게 면취된 가장자리만 부드러운 윤곽.
    for polygon in mesh.polygons:
        polygon.use_smooth = False


def authored_hull(scene, root, name, points, material, bevel, color, seed):
    """구형 기본체 대신 손으로 정한 어깨·능선·깨진 모서리의 볼록 외피."""
    bm = bmesh.new()
    for point in points:
        bm.verts.new(point)
    bm.verts.ensure_lookup_table()
    bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.verts.ensure_lookup_table()
    mapping = {vertex: index for index, vertex in enumerate(bm.verts)}
    vertices = [tuple(vertex.co) for vertex in bm.verts]
    faces = [tuple(mapping[vertex] for vertex in face.verts) for face in bm.faces]
    bm.free()
    obj = finish_mesh(scene, root, name, vertices, faces, material, "stone", bevel)
    paint_stone(obj, color, seed)
    return obj


def moss_patch(scene, root, substrate, name, center, radii, rotation, seed, material, thickness=.012):
    """석재 표면에 투영한 불규칙 닫힌 이끼 껍질. 가장자리도 양의 간격 확보."""
    mesh = substrate.data
    vertices = [v.co.copy() for v in mesh.vertices]
    polygons = [tuple(p.vertices) for p in mesh.polygons]
    tree = BVHTree.FromPolygons(vertices, polygons)
    rng = random.Random(seed)
    samples = 24
    cos_a, sin_a = math.cos(rotation), math.sin(rotation)
    outer = []
    for index in range(samples):
        angle = index * math.tau / samples
        radius = 1 + .16 * math.sin(angle * 3 + .8) + .09 * math.cos(angle * 7 + seed)
        x = math.cos(angle) * radii[0] * radius
        y = math.sin(angle) * radii[1] * radius
        outer.append(Vector((x * cos_a - y * sin_a, x * sin_a + y * cos_a)))
    top_vertices, weights, surface_heights = [], [], []
    for fraction in (0.0, .38, .73, 1.0):
        indices = range(1) if fraction == 0 else range(samples)
        for index in indices:
            xy = Vector(center) + outer[index] * fraction
            hit, normal, _, _ = tree.ray_cast(Vector((xy.x, xy.y, 1)), Vector((0, 0, -1)), 2)
            if hit is None:
                raise RuntimeError(f"이끼 경계가 바위 밖으로 벗어남: {name}, {tuple(xy)}")
            cushion = thickness * (1 - fraction ** 1.6) * (.88 + .12 * math.sin(index * 1.7))
            clearance = .0012 + cushion
            top_vertices.append((xy.x, xy.y, hit.z + clearance))
            surface_heights.append(hit.z)
            weights.append(1 - fraction)
    faces = []
    for index in range(samples):
        faces.append((0, 1 + index, 1 + (index + 1) % samples))
    for ring in range(2):
        low, high = 1 + ring * samples, 1 + (ring + 1) * samples
        for index in range(samples):
            following = (index + 1) % samples
            faces.append((low + index, high + index, high + following, low + following))
    # 얇은 측벽과 석재에 살짝 매입한 바닥. 돌과 동일 평면인 폴리곤 없음.
    start = len(top_vertices)
    for index in range(samples):
        point = top_vertices[1 + 2 * samples + index]
        top_vertices.append((point[0], point[1], surface_heights[1 + 2 * samples + index] - .0008))
        weights.append(0)
    rim = 1 + 2 * samples
    for index in range(samples):
        following = (index + 1) % samples
        faces.append((rim + index, start + index, start + following, rim + following))
    faces.append(tuple(reversed(range(start, start + samples))))
    obj = finish_mesh(scene, root, name, top_vertices, faces, material, "moss")
    # 능선을 가로지르는 삼각형의 중간도 석재 위에 유지하는 최소 두께.
    obj.data.calc_loop_triangles()
    minimum_gap = 1.0
    for triangle in obj.data.loop_triangles:
        if obj.data.polygons[triangle.polygon_index].index >= samples * 3:
            continue
        points = [obj.data.vertices[index].co for index in triangle.vertices]
        for i in range(7):
            for j in range(7 - i):
                a, b = i / 6, j / 6
                point = points[0] * a + points[1] * b + points[2] * (1 - a - b)
                hit, _, _, _ = tree.ray_cast(Vector((point.x, point.y, 1)), Vector((0, 0, -1)), 2)
                if hit:
                    minimum_gap = min(minimum_gap, point.z - hit.z)
    added_thickness = max(0, .0012 - minimum_gap)
    for vertex in obj.data.vertices[:start]:
        vertex.co.z += added_thickness
    obj.data.update()
    color = obj.data.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='POINT')
    obj.data.color_attributes.active_color = color
    dark, light = linear("4b5f31"), linear("7d8848")
    for entry, weight, point in zip(color.data, weights, top_vertices):
        mixed = .28 + .43 * weight + .12 * math.sin(point[0] * 29 + point[1] * 23)
        shade = .84 + rng.uniform(-.018, .018)
        entry.color = tuple((a * (1 - mixed) + b * mixed) * shade for a, b in zip(dark, light)) + (1,)
    for polygon in obj.data.polygons:
        polygon.use_smooth = polygon.normal.z > .35
    obj["surfaceClearanceMin"] = .0012
    obj["ridgeThicknessCorrection"] = added_thickness
    obj["undersideEmbedDepth"] = .0008
    obj["underlyingStone"] = substrate.name
    return obj


def make_scene(name, asset_id, label):
    scene = bpy.data.scenes.new(name)
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    root = bpy.data.objects.new(asset_id, None)
    scene.collection.objects.link(root)
    root["assetId"] = asset_id
    root["displayName"] = label
    root["tileUnits"] = 1.0
    root["sourceConcept"] = CONCEPT
    root["masterRole"] = "static_environment"
    root["editableMaster"] = True
    scene["assetId"] = asset_id
    scene["sourceScene"] = name
    return scene, root


def build_boulder(stone, moss):
    scene, root = make_scene("02 Mossy Boulder Master", "mossy_boulder", "비대칭 이끼 바위")
    # 아래는 평평한 부러진 지지면, 위는 오른쪽으로 비틀린 긴 능선.
    points = [
        (-.235, -.155, 0), (-.075, -.224, 0), (.170, -.193, 0), (.294, -.073, 0),
        (.258, .121, 0), (.106, .228, 0), (-.159, .187, 0), (-.298, .041, 0),
        (-.310, -.065, .106), (-.247, -.177, .159), (-.061, -.241, .168), (.185, -.188, .146),
        (.309, -.033, .128), (.249, .130, .196), (.081, .239, .174), (-.199, .189, .137),
        (-.227, -.092, .291), (-.069, -.154, .321), (.113, -.115, .356), (.229, .010, .294),
        (.134, .146, .323), (-.045, .166, .276), (-.206, .102, .237),
        (-.055, -.041, .348), (.061, .054, .372),
    ]
    obj = authored_hull(scene, root, "Boulder — twisted exposed rock faces", points, stone, .006, "858a83", 27)
    moss_patch(scene, root, obj, "Boulder — upper-left moss mantle", (-.089, .057), (.128, .116), -.18, 14, moss, .013)
    moss_patch(scene, root, obj, "Boulder — rear moss tongue", (.079, .135), (.072, .046), .34, 71, moss, .008)
    moss_patch(scene, root, obj, "Boulder — separated shoulder moss", (-.211, -.052), (.040, .047), -.52, 3, moss, .007)
    return scene, root


def build_flat_stone(stone, moss):
    scene, root = make_scene("03 Flat Stone Master", "flat_stone", "낮고 넓은 층리돌")
    outline = [(-.285, -.112), (-.118, -.208), (.099, -.195), (.292, -.088),
               (.308, .040), (.194, .160), (-.039, .211), (-.235, .135), (-.310, .023)]
    # 층마다 좌우로 어긋나는 얇은 퇴적 판. 높이마다 다른 작은 파손면.
    layers = [(0, .82, (-.005, 0)), (.025, 1.0, (0, 0)), (.053, .97, (.003, -.002)),
              (.063, .91, (.008, -.006)), (.090, .94, (.008, -.007)),
              (.115, .82, (.011, -.012)), (.142, .60, (.030, -.011))]
    vertices = []
    count = len(outline)
    for level, (height, scale, offset) in enumerate(layers):
        for index, (x, y) in enumerate(outline):
            dz = 0 if level == 0 else .006 * math.sin(index * 1.5 + .8) + x * .011
            vertices.append((x * scale + offset[0], y * scale + offset[1], height + dz))
    faces = [tuple(reversed(range(count)))]
    for layer in range(len(layers) - 1):
        for index in range(count):
            following = (index + 1) % count
            faces.append((layer * count + index, layer * count + following,
                          (layer + 1) * count + following, (layer + 1) * count + index))
    faces.append(tuple(range((len(layers) - 1) * count, len(layers) * count)))
    obj = finish_mesh(scene, root, "Flat Stone — broken offset strata", vertices, faces, stone, "stone", .0028)
    paint_stone(obj, "898d84", 9, layered=True)
    moss_patch(scene, root, obj, "Flat Stone — narrow moss shoulder", (-.035, .055), (.079, .045), -.35, 6, moss, .007)
    return scene, root


def build_pebbles(stone, moss):
    scene, root = make_scene("04 Pebbles Master", "pebble_scatter", "작은 돌멩이 여섯 개")
    # 크기·장축·높이가 다른 여섯 돌과 빈 틈. 개별 오브젝트로 이동·삭제 가능.
    settings = [(-.213, -.051, .146, .110, .076, -.30, "858b81"),
                (-.086, .112, .109, .079, .054, .65, "747d75"),
                (.063, -.036, .148, .092, .080, -.55, "92958a"),
                (.203, .073, .126, .104, .065, .23, "80887e"),
                (.236, -.100, .065, .057, .043, -.08, "9a9b8e"),
                (-.035, -.133, .083, .063, .050, .42, "747b72")]
    for index, (x, y, width, depth, height, angle, color) in enumerate(settings):
        # 낮은 육각 밑면·어긋난 어깨·잘린 능선. 구형 메시 사용 없음.
        normalized = [(-.40, -.29, 0), (-.02, -.46, 0), (.45, -.21, 0), (.40, .31, 0),
                      (-.03, .45, 0), (-.47, .11, 0),
                      (-.50, -.09, .45), (-.22, -.50, .52), (.32, -.36, .56), (.50, .12, .39),
                      (.18, .50, .49), (-.35, .34, .62),
                      (-.18, -.07, .91), (.18, .10, 1.0), (.29, -.12, .76)]
        points = [(px * width, py * depth, pz * height) for px, py, pz in normalized]
        obj = authored_hull(scene, root, f"Pebble {index + 1:02d} — individual chipped stone", points, stone, 0, color, 100 + index)
        obj.location = (x, y, 0)
        obj.rotation_euler.z = angle
        obj["pebbleIndex"] = index + 1
    return scene, root


def describe(scene, root):
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    objects, bounds = [], []
    for obj in root.children:
        mesh = obj.data
        mesh.calc_loop_triangles()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        non_manifold = sum(not edge.is_manifold for edge in bm.edges)
        volume = bm.calc_volume(signed=False)
        bm.free()
        if non_manifold or volume <= 0:
            raise RuntimeError(f"닫힌 원본 메시 검사 실패: {obj.name}, {non_manifold}, {volume}")
        if obj.modifiers:
            raise RuntimeError(f"미적용 modifier: {obj.name}")
        color = mesh.color_attributes.get("Color")
        if color is None or len(color.data) != len(mesh.vertices) or any(abs(c.color[3] - 1) > .00001 for c in color.data):
            raise RuntimeError(f"불투명 정점색 누락: {obj.name}")
        points = [obj.matrix_local @ vertex.co for vertex in mesh.vertices]
        bounds.extend(points)
        objects.append({"name": obj.name, "role": obj["partRole"], "vertices": len(mesh.vertices),
                        "triangles": len(mesh.loop_triangles), "closedMesh": True, "unappliedModifiers": 0})
        if obj["partRole"] == "moss":
            surface = bpy.data.objects[obj["underlyingStone"]].data
            tree = BVHTree.FromPolygons([v.co for v in surface.vertices], [tuple(p.vertices) for p in surface.polygons])
            clearance = []
            for triangle in mesh.loop_triangles:
                if mesh.polygons[triangle.polygon_index].normal.z <= .3:
                    continue
                points = [mesh.vertices[i].co for i in triangle.vertices]
                for a, b, c in ((1/3, 1/3, 1/3), (.5, .5, 0), (.5, 0, .5), (0, .5, .5)):
                    point = points[0] * a + points[1] * b + points[2] * c
                    hit, _, _, _ = tree.ray_cast(Vector((point.x, point.y, 1)), Vector((0, 0, -1)), 2)
                    if hit:
                        clearance.append(point.z - hit.z)
            objects[-1]["sampledTopClearanceMin"] = min(clearance)
    minimum = [min(point[i] for point in bounds) for i in range(3)]
    maximum = [max(point[i] for point in bounds) for i in range(3)]
    return {"assetId": root["assetId"], "sourceScene": scene.name, "rootObject": root.name,
            "tileUnits": 1, "rootOrigin": list(root.location), "bounds": [minimum, maximum],
            "dimensions": [maximum[i] - minimum[i] for i in range(3)],
            "triangles": sum(item["triangles"] for item in objects), "objects": objects}


def main():
    if TARGET.exists():
        raise RuntimeError("rock-masters.blend가 이미 있습니다. seed 재실행 대신 저장된 독립 원본을 편집하세요.")
    if bpy.data.filepath:
        raise RuntimeError("다른 원본 보호: --background --factory-startup에서만 최초 생성하세요.")
    HERE.mkdir(parents=True, exist_ok=True)
    startup = list(bpy.data.scenes)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for material in list(bpy.data.materials):
        if material.users == 0:
            bpy.data.materials.remove(material)
    stone = make_material("Companion Stone — vertex color", .91)
    moss = make_material("Companion Moss — vertex color", .97)
    assets = [build_boulder(stone, moss), build_flat_stone(stone, moss), build_pebbles(stone, moss)]
    bpy.context.window.scene = assets[0][0]
    for scene in startup:
        bpy.data.scenes.remove(scene)
    for scene, _ in assets:
        scene.view_settings.view_transform = 'AgX'
        scene.render.engine = 'CYCLES'
        scene.render.fps = 30
    bpy.context.view_layer.update()
    results = [describe(scene, root) for scene, root in assets]
    summary = {"source": TARGET.name, "sourceConcept": CONCEPT, "role": "editable_independent_rock_masters",
               "seedOnly": True, "existingSourceProtected": True, "extraTextures": 0,
               "materials": [stone.name, moss.name], "assets": results,
               "totalTriangles": sum(asset["triangles"] for asset in results)}
    text = bpy.data.texts.new("README — Rock Masters")
    text.write("시안에서 식별한 독립 바위 원본 3종\n\n각 Scene의 assetId 루트 아래 석재·이끼를 직접 편집합니다.\n"
               "원점은 바닥 중앙, 한 단위는 한 타일입니다. 돌멩이는 여섯 독립 메시로 배치했습니다.\n"
               "Color 정점색과 불투명 Stone/Moss 재질을 유지합니다. 바위와 이끼는 별도 닫힌 메시입니다.\n"
               "seed 스크립트는 최초 생성 전용이며 저장된 원본을 덮어쓰지 않습니다.\n"
               "카메라·광원·렌더 산출물·게임 배치는 이 파일에 포함하지 않습니다.\n")
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    MANIFEST.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print("ROCK_MASTERS_READY", json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    if "--check" in sys.argv:
        # 저장된 원본은 읽기만 한다. seed 생성·원본 저장 경로와 분리.
        result = [describe(scene, next(obj for obj in scene.objects if obj.get("assetId")))
                  for scene in bpy.data.scenes if scene.get("assetId")]
        print("ROCK_SOURCE_CHECK", json.dumps(result, ensure_ascii=False))
    else:
        main()
