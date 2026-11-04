"""Blender 원본 생성: 외곽 식생 군락, 이끼돌, 뿌리. 수작업 수정 후에는 export_dressing.py만 실행."""
from pathlib import Path
import json
import math
import random
import struct

import bpy
import bmesh
from mathutils import Vector


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RNG = random.Random(120926)
SOURCE = HERE / "environment-dressing.blend"


def linear_color(hex_color):
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb)


GRASS = [linear_color(c) for c in ("697a35", "7e8c42", "596c30", "87934c", "a2a060")]
FERN = [linear_color(c) for c in ("697d3b", "78894a", "56713a")]
ROCK = linear_color("7a7d72")
MOSS = [linear_color(c) for c in ("596b31", "69773b", "7a874c")]
ROOT_COLOR = linear_color("635341")


class Geometry:
    """개별 편집 오브젝트의 정점색·바람 속성을 같은 토폴로지로 작성."""
    def __init__(self):
        self.vertices, self.faces, self.colors, self.wind = [], [], [], []

    def vertex(self, point, color, weight=0.0, phase=0.0):
        index = len(self.vertices)
        self.vertices.append(tuple(point))
        self.colors.append((*color, 1.0))
        self.wind.append((weight, 1.0 - phase))  # glTF의 V 반전 후 UV.y = 군락 위상
        return index

    def object(self, name, material, collection, parent):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.materials.append(material)
        if material.name.endswith("foliage"):
            for polygon in mesh.polygons:
                polygon.use_smooth = True
        color = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
        mesh.color_attributes.active_color = color
        for item, rgba in zip(color.data, self.colors):
            item.color = rgba
        wind = mesh.uv_layers.new(name="Wind")
        for loop in mesh.loops:
            wind.data[loop.index].uv = self.wind[loop.vertex_index]
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        obj.parent = parent
        return obj


def blade(geometry, base, angle, height, reach, width, color, phase):
    """중앙 접힘이 있는 입체 잎. 뿌리에서 끝으로 굽힘 가중치 증가."""
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    across = Vector((-direction.y, direction.x, 0))
    start = Vector(base)
    rings = []
    for t, breadth in ((0, .30), (.32, 1.0), (.70, .67)):
        center = start + direction * (reach * t * t) + Vector((0, 0, height * t))
        tint = tuple(c * (.62 + .38 * t) for c in color)
        ring = []
        for side in (-1, 0, 1):
            point = center + across * (width * breadth * side * .5)
            point.z += width * .22 * breadth if side == 0 else 0
            ring.append(geometry.vertex(point, tint, t, phase))
        rings.append(ring)
    for bottom, top in zip(rings, rings[1:]):
        geometry.faces.extend(((bottom[0], bottom[1], top[1], top[0]),
                               (bottom[1], bottom[2], top[2], top[1])))
    tip = geometry.vertex(start + direction * reach + Vector((0, 0, height)), color, 1, phase)
    geometry.faces.extend(((rings[-1][0], rings[-1][1], tip), (rings[-1][1], rings[-1][2], tip)))


def fern_frond(geometry, base, angle, length, color, phase):
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    across = Vector((-direction.y, direction.x, 0))
    start = Vector(base)
    # 가는 잎축과 좌우 작은 잎. 투명 판 대신 실제 잎 윤곽 메시.
    for segment in range(7):
        t0, t1 = segment / 7, (segment + 1) / 7
        points = []
        for t in (t0, t1):
            center = start + direction * (length * .72 * t) + Vector((0, 0, length * (.72 * t - .28 * t * t)))
            points.append([geometry.vertex(center + across * side * .003, color, t, phase) for side in (-1, 1)])
        geometry.faces.append((points[0][0], points[0][1], points[1][1], points[1][0]))
    for tier in range(1, 7):
        t = tier / 7
        center = start + direction * (length * .72 * t) + Vector((0, 0, length * (.72 * t - .28 * t * t)))
        leaflet_length = length * .26 * math.sin(math.pi * t) ** .65
        for side in (-1, 1):
            tip = center + across * side * leaflet_length + direction * leaflet_length * .30
            tip.z += leaflet_length * .20
            middle = center.lerp(tip, .50)
            ids = [geometry.vertex(p, color, min(1, t + k), phase) for p, k in (
                (center, 0), (middle - direction * leaflet_length * .24, .10),
                (middle + Vector((0, 0, leaflet_length * .13)), .12),
                (middle + direction * leaflet_length * .24, .10), (tip, .18))]
            geometry.faces.extend(((ids[0], ids[1], ids[2]), (ids[0], ids[2], ids[3]),
                                   (ids[1], ids[4], ids[2]), (ids[2], ids[4], ids[3])))


def add_rock(geometry, center, radii, color, moss=False):
    mesh = bmesh.new()
    bmesh.ops.create_icosphere(mesh, subdivisions=1 if radii[2] <= .012 else 2, radius=1.0)
    mesh.verts.ensure_lookup_table()
    indices = {}
    angle = RNG.uniform(-.20, .20)
    for vertex in mesh.verts:
        co = vertex.co
        irregular = RNG.uniform(.84, 1.13)
        x, y = co.x * radii[0] * irregular, co.y * radii[1] * irregular
        point = (center[0] + x * math.cos(angle) - y * math.sin(angle),
                 center[1] + x * math.sin(angle) + y * math.cos(angle),
                 center[2] + co.z * radii[2] * irregular)
        tint = RNG.uniform(.78, 1.12)
        base_color = RNG.choice(MOSS) if moss and co.z > .25 and RNG.random() < .72 else color
        indices[vertex] = geometry.vertex(point, tuple(min(c * tint, 1) for c in base_color))
    geometry.faces.extend(tuple(indices[v] for v in face.verts) for face in mesh.faces)
    mesh.free()


def root_branch(geometry, points, radius):
    rings = []
    for i, point in enumerate(points):
        scale = 1 - .85 * i / (len(points) - 1)
        rings.append([geometry.vertex(Vector(point) + Vector((math.cos(a * math.tau / 5) * radius * scale,
                                                              math.sin(a * math.tau / 5) * radius * scale, 0)), ROOT_COLOR)
                      for a in range(5)])
    for low, high in zip(rings, rings[1:]):
        geometry.faces.extend((low[j], low[(j + 1) % 5], high[(j + 1) % 5], high[j]) for j in range(5))


def wind_preview(obj):
    """런타임의 두 사인파를 네 Shape Key 기저로 미리보기. GLB 출력에서 제외."""
    mesh = obj.data
    weights = {}
    for loop in mesh.loops:
        weights[loop.vertex_index] = mesh.uv_layers[0].data[loop.index].uv.copy()
    obj.shape_key_add(name="Basis", from_mix=False)
    for harmonic, speed, amplitude, phase_scale in ((0, .95, .72, 1), (1, 1.71, .28, 1.37)):
        for function in ("sin", "cos"):
            key = obj.shape_key_add(name=f"Wind_{harmonic}_{function}", from_mix=False)
            key.slider_min, key.slider_max = -1, 1
            for index, uv in weights.items():
                phase = (1 - uv.y) * phase_scale
                coefficient = math.cos(phase) if function == "sin" else math.sin(phase)
                shift = .022 * amplitude * uv.x ** 2 * coefficient
                key.data[index].co.x += .92 * shift
                key.data[index].co.y -= .39 * shift
            driver = key.driver_add("value").driver
            driver.expression = f"{function}(frame / 30 * {speed})"


def main():
    glb = (ROOT / "assets/images/stage1_3d/environment/terrain.glb").read_bytes()
    document = json.loads(glb[20:20 + struct.unpack_from("<I", glb, 12)[0]])
    manifest = next(n["extras"] for n in document["nodes"] if n.get("name") == "stage1_environment")
    tiles, columns, rows = manifest["tileTypes"], manifest["columns"], manifest["rows"]
    # 다른 편집 원본 보호. 별도 --factory-startup 프로세스 또는 이 생성 원본에서만 실행.
    if bpy.data.filepath and Path(bpy.data.filepath).resolve() != SOURCE.resolve():
        raise RuntimeError("별도 Blender --background --factory-startup 프로세스에서 실행하세요.")
    scene = bpy.context.scene
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for other in list(bpy.data.scenes):
        if other != scene:
            bpy.data.scenes.remove(other)
    for collection in list(bpy.data.collections):
        if collection.library is None:
            bpy.data.collections.remove(collection)
    for material in list(bpy.data.materials):
        if material.name.startswith("Stage1Dressing_"):
            bpy.data.materials.remove(material)
    scene.name = "Stage1EnvironmentDressing"
    scene.render.fps = 30
    scene.frame_start, scene.frame_end = 1, 240
    scene.unit_settings.system = "METRIC"
    source_collection = bpy.data.collections.new("10 Dressing - editable clusters")
    scene.collection.children.link(source_collection)
    parent = bpy.data.objects.new("stage1_dressing", None)
    source_collection.objects.link(parent)
    for key in ("columns", "rows", "tileTypes", "tileSize", "gridCenterConvention"):
        parent[key] = manifest[key]
    parent["windMaximumDisplacement"] = .022
    parent["sourceConcept"] = "environment_concepts/01-overgrown-stone-edges.png"
    parent["buildClearHalfWidth"] = .35
    parent["removableCenterVegetation"] = True
    build_slots = {index: slot for slot, index in enumerate(i for i, tile in enumerate(tiles) if tile == "build")}
    parent["buildTileCount"] = len(build_slots)
    assert len(build_slots) == 32
    materials = {}
    for name in ("foliage", "rocks"):
        material = bpy.data.materials.new("Stage1Dressing_" + name)
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        color = material.node_tree.nodes.new("ShaderNodeVertexColor")
        color.layer_name = "Color"
        material.node_tree.links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = .92
        bsdf.inputs["Specular IOR Level"].default_value = .12
        material.use_backface_culling = name == "rocks"
        materials[name] = material

    # 외곽의 밀집 군락과 이를 잇는 드문 포인트.
    focal = {(3, 0), (5, 1), (7, 4), (7, 7), (0, 7), (0, 9)}
    edges = (("N", 0, -1), ("E", 1, 0), ("S", 0, 1), ("W", -1, 0))
    placements, foliage_objects, static_objects = [], [], []
    for row in range(rows):
        for column in range(columns):
            if tiles[row * columns + column] != "build":
                continue
            boundary = [(name, dc, dr) for name, dc, dr in edges
                        if not (0 <= column + dc < columns and 0 <= row + dr < rows)
                        or tiles[(row + dr) * columns + column + dc] == "blocked"]
            if not boundary:
                continue
            center = Vector((column - (columns - 1) / 2, (rows - 1) / 2 - row, .006))
            rich = (column, row) in focal
            for edge_index, (edge, dc, dr) in enumerate(boundary):
                normal = Vector((dc, -dr, 0))
                tangent = Vector((-normal.y, normal.x, 0))
                positions = (-.30, -.10, .15, .32) if rich else (-.25, .24)
                for tuft_index, along in enumerate(positions):
                    base = center + normal * RNG.uniform(.413, .451) + tangent * (along + RNG.uniform(-.03, .03))
                    phase = RNG.uniform(0, math.tau)
                    geometry = Geometry()
                    for _ in range(RNG.randint(9, 13) if rich else RNG.randint(6, 9)):
                        # 바깥쪽으로 벌어지는 풀. 중앙 건설 영역으로 휘지 않도록 제한.
                        foot = base + normal * RNG.uniform(-.012, .015) + tangent * RNG.uniform(-.029, .029)
                        angle = math.atan2(normal.y, normal.x) + RNG.uniform(-1.35, 1.35)
                        blade(geometry, foot, angle, RNG.uniform(.16, .285) if rich else RNG.uniform(.12, .21),
                              RNG.uniform(.030, .095), RNG.uniform(.016, .032), RNG.choices(GRASS, weights=(5, 4, 5, 4, 1))[0], phase)
                    obj = geometry.object(f"grass_c{column}_r{row}_{edge}_{tuft_index}", materials["foliage"], source_collection, parent)
                    obj["dressingGroup"] = "foliage"
                    obj["tile"] = [column, row]
                    wind_preview(obj)
                    foliage_objects.append(obj)
                    placements.append({"name": obj.name, "tile": [column, row], "edge": edge, "kind": "grass"})
                if rich:
                    fern_base = center + normal * .455 + tangent * (-.04 if edge_index == 0 else .26)
                    geometry = Geometry()
                    phase = RNG.uniform(0, math.tau)
                    for angle_offset in (-1.22, -.80, -.38, .08, .48, .95, 1.35):
                        fern_frond(geometry, fern_base, math.atan2(normal.y, normal.x) + angle_offset,
                                   RNG.uniform(.29, .39), RNG.choice(FERN), phase)
                    obj = geometry.object(f"fern_c{column}_r{row}_{edge}", materials["foliage"], source_collection, parent)
                    obj["dressingGroup"] = "foliage"
                    obj["tile"] = [column, row]
                    wind_preview(obj)
                    foliage_objects.append(obj)
                    placements.append({"name": obj.name, "tile": [column, row], "edge": edge, "kind": "fern"})

                    stone = Geometry()
                    for offset, size in ((.16, .145), (-.21, .090)):
                        location = center + normal * .480 + tangent * offset
                        location.z += size * .49
                        # 외곽 띠를 따르는 작은 돌. 건설칸 중앙 여유 보존.
                        radii = (.086, size, size * .84) if dc else (size, .086, size * .84)
                        add_rock(stone, location, radii, ROCK, moss=True)
                        for _ in range(3):
                            patch = location + tangent * RNG.uniform(-size * .65, size * .65)
                            patch.z += size * RNG.uniform(.35, .57)
                            add_rock(stone, patch, (.025, .030, .009), RNG.choice(MOSS))
                    obj = stone.object(f"moss_stones_c{column}_r{row}_{edge}", materials["rocks"], source_collection, parent)
                    obj["dressingGroup"] = "rocks"
                    obj["tile"] = [column, row]
                    static_objects.append(obj)
                    placements.append({"name": obj.name, "tile": [column, row], "edge": edge, "kind": "rocks"})

                roots = Geometry()
                for offset in ((-.19, .14) if rich else (.13,)):
                    start = center + normal * .463 + tangent * offset
                    points = [start + normal * (.01 * i) + tangent * (math.sin(i * 1.3) * .014)
                              - Vector((0, 0, .045 * i)) for i in range(6)]
                    root_branch(roots, points, .007 if rich else .005)
                obj = roots.object(f"roots_c{column}_r{row}_{edge}", materials["rocks"], source_collection, parent)
                obj["dressingGroup"] = "rocks"
                obj["tile"] = [column, row]
                static_objects.append(obj)

    # 안쪽 건설 타일의 공유 이음새. 모서리 군락을 연결해 전장 내부까지 식생 분산.
    inner_edges = []
    for row in range(rows):
        for column in range(columns):
            if tiles[row * columns + column] != "build":
                continue
            for edge, dc, dr in (("E", 1, 0), ("S", 0, 1)):
                if column + dc < columns and row + dr < rows and tiles[(row + dr) * columns + column + dc] == "build":
                    inner_edges.append((column, row, edge, dc, dr))
    for edge_index, (column, row, edge, dc, dr) in enumerate(inner_edges):
        if edge_index % 5 == 3:
            continue
        center = Vector((column - 3.5, 4.5 - row, .006))
        normal = Vector((dc, -dr, 0))
        tangent = Vector((-normal.y, normal.x, 0))
        # 이음새의 양끝에 치우친 배치와 한쪽만 있는 배치를 섞어 반복성 완화.
        offsets = (-.27, .23) if edge_index % 3 != 1 else (.04,)
        for tuft_index, along in enumerate(offsets):
            base = center + normal * .460 + tangent * (along + RNG.uniform(-.025, .025))
            geometry = Geometry()
            phase = RNG.uniform(0, math.tau)
            for _ in range(7 if edge_index % 3 == 0 else 5):
                foot = base + normal * RNG.uniform(-.012, .012) + tangent * RNG.uniform(-.025, .025)
                blade(geometry, foot, math.atan2(normal.y, normal.x) + RNG.uniform(-1.20, 1.20),
                      RNG.uniform(.13, .255), RNG.uniform(.025, .075), RNG.uniform(.021, .037),
                      RNG.choice(GRASS[:4]), phase)
            obj = geometry.object(f"inner_grass_c{column}_r{row}_{edge}_{tuft_index}", materials["foliage"], source_collection, parent)
            obj["dressingGroup"] = "foliage"
            obj["tile"] = [column, row]
            wind_preview(obj)
            foliage_objects.append(obj)
            placements.append({"name": obj.name, "tile": [column, row], "edge": edge, "kind": "inner_grass"})

    # 네 건설칸이 만나는 안쪽 틈의 낮은 이끼돌. 이동 경로와 포탑 중심에는 놓지 않음.
    for column, row in ((2, 0), (2, 3), (2, 7)):
        assert all(tiles[(row + dr) * columns + column + dc] == "build" for dr in (0, 1) for dc in (0, 1))
        center = Vector((column - 3.5, 4.5 - row, .006))
        stone = Geometry()
        for offset, radius in ((-.045, .066), (.064, .038)):
            location = center + Vector((.48 + offset, -.48, radius * .48))
            add_rock(stone, location, (radius, radius * .70, radius * .64), ROCK, moss=True)
        obj = stone.object(f"inner_moss_stones_c{column}_r{row}", materials["rocks"], source_collection, parent)
        obj["dressingGroup"] = "rocks"
        obj["tile"] = [column, row]
        static_objects.append(obj)
        placements.append({"name": obj.name, "tile": [column, row], "edge": "SE", "kind": "inner_rocks"})

    # 빈 타일 안쪽의 비대칭 풀무리. 확정 포탑이 있는 타일에서만 GPU가 이 군락을 숨김.
    for tile_index, slot in build_slots.items():
        column, row = tile_index % columns, tile_index // columns
        if (column * 3 + row * 5) % 7 in (0, 1):
            continue
        center = Vector((column - 3.5, 4.5 - row, .006))
        patch_center = center + Vector((RNG.uniform(-.22, .22), RNG.uniform(-.22, .22), 0))
        geometry = Geometry()
        phase = RNG.uniform(0, math.tau)
        if slot % 4 == 0:
            # 낮게 퍼진 넓은 잎으로 직립 풀의 반복을 완화.
            for leaf in range(7):
                blade(geometry, patch_center, leaf * math.tau / 7 + RNG.uniform(-.15, .15),
                      RNG.uniform(.085, .145), RNG.uniform(.075, .14), RNG.uniform(.042, .065),
                      RNG.choice(FERN), phase)
        else:
            for stand, count in ((0, 5), (1, 4)):
                base = patch_center + Vector((.065 * stand, -.045 * stand, 0))
                for _ in range(count):
                    foot = base + Vector((RNG.uniform(-.025, .025), RNG.uniform(-.025, .025), 0))
                    blade(geometry, foot, RNG.uniform(0, math.tau), RNG.uniform(.14, .295),
                          RNG.uniform(.030, .105), RNG.uniform(.022, .040), RNG.choice(GRASS[:4]), phase)
        obj = geometry.object(f"center_vegetation_c{column}_r{row}", materials["foliage"], source_collection, parent)
        obj["dressingGroup"] = "foliage"
        obj["tile"] = [column, row]
        obj["removableOnBuild"] = True
        wind_preview(obj)
        foliage_objects.append(obj)
        placements.append({"name": obj.name, "tile": [column, row], "kind": "center_vegetation", "removableOnBuild": True})

    for obj in parent.children:
        column, row = obj["tile"]
        slot = build_slots[row * columns + column]
        removable = bool(obj.get("removableOnBuild", False))
        occupancy = obj.data.uv_layers.new(name="Occupancy")
        for uv in occupancy.data:
            uv.uv = (slot, 0.0 if removable else 1.0)  # glTF V 반전 후 UV2.y = 제거 가능 플래그

    # 제작 장면은 기존 지형을 링크 참조. 신규 장식만 GLB 출력.
    reference = bpy.data.collections.new("00 Terrain - linked reference (not exported)")
    scene.collection.children.link(reference)
    terrain_source = ROOT / "design/stage1_3d/environment/terrain-approved.blend"
    with bpy.data.libraries.load(str(terrain_source), link=True) as (src, dst):
        dst.objects = [name for name in src.objects if name == "stage1_environment" or name.startswith("stage1_static_")]
    for obj in dst.objects:
        reference.objects.link(obj)
    scene.world = bpy.data.worlds.new("Stage1 Dressing Studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes.get("Background").inputs[0].default_value = (.09, .13, .15, 1)
    scene.world.node_tree.nodes.get("Background").inputs[1].default_value = .40
    camera_data = bpy.data.cameras.new("Dressing Overview")
    camera = bpy.data.objects.new("Dressing Overview", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (5, -13, 23)
    camera.rotation_euler = (-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.type, camera_data.ortho_scale = 'ORTHO', 16.0
    scene.camera = camera
    for name, position, power, size, tint in (
        ("Key", (-4, 2, 10), 1500, 7, (1, .92, .78)),
        ("Fill", (6, -3, 8), 1050, 6, (.70, .82, 1)),
    ):
        light = bpy.data.lights.new(name, 'AREA')
        light.energy, light.shape, light.size, light.color = power, 'DISK', size, tint
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (-obj.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1080, 1440, 100
    scene.view_settings.view_transform = 'AgX'
    scene.frame_set(1)
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type == 'VIEW_3D' and area.spaces.active.region_3d:
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
            area.spaces.active.shading.type = 'MATERIAL'
    text = bpy.data.texts.new("README - Environment Dressing")
    text.write("스테이지 1 환경 장식 원본\n\n10 Dressing 컬렉션의 군락별 메시를 편집합니다.\n00 Terrain은 기존 지형의 연결 참조이며 내보내지 않습니다.\n타임라인 1~240, 30fps: 바람 미리보기. 게임은 동일 수식의 정점 셰이더만 사용합니다.\n수작업 수정 뒤 export_dressing.py를 실행합니다. build_dressing.py 재실행은 생성 원본을 초기화합니다.\nUV Wind.x는 뿌리 0/끝 1, Wind.y는 1-위상. Color는 선형 정점색입니다.\nUV Occupancy.x는 건설 타일 순번, y는 영구 식생 1/설치 시 숨기는 중앙 식생 0입니다.\n중앙 풀은 removableOnBuild 속성이 있으며 게임에서 포탑 설치 시 숨고 철거 시 다시 나타납니다.\n영구 장식은 건설칸 중앙 0.7×0.7과 길을 비웁니다.\n")
    for library in bpy.data.libraries:
        library.filepath = bpy.path.relpath(library.filepath, start=str(HERE))
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    (HERE / "placement_manifest.json").write_text(json.dumps({
        "source": SOURCE.name, "seed": 120926, "windMaximumDisplacement": .022,
        "buildClearHalfWidth": .35, "foliageClusters": len(foliage_objects),
        "staticClusters": len(static_objects),
        "removableClusters": sum(bool(obj.get("removableOnBuild")) for obj in foliage_objects),
        "placements": placements,
    }, ensure_ascii=False, indent=2) + "\n")
    print("DRESSING_SOURCE", len(foliage_objects), len(static_objects), str(SOURCE))


if __name__ == "__main__":
    main()
