"""이전 군락 생성 기록. 현재 맵 조립은 assemble_master_dressing.py를 사용."""
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


GRASS = [linear_color(c) for c in ("657735", "7c873f", "53682e", "88914b", "a19b58")]
FERN = [linear_color(c) for c in ("687a3d", "7c8748", "536b35", "8b9050")]
BROADLEAF = [linear_color(c) for c in ("62783b", "748446", "88904c", "536b36")]
UNDERSTORY = [linear_color(c) for c in ("354e28", "435b2d", "526531")]
ROCK = linear_color("848579")
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
        if material.name.endswith("foliage"):
            # 잎의 윗면 winding 통일. Godot 양면 조명에서 뒤집힌 잎의 암부 방지.
            self.faces = [face if (Vector(self.vertices[face[1]]) - Vector(self.vertices[face[0]])).cross(
                Vector(self.vertices[face[2]]) - Vector(self.vertices[face[0]])).z >= 0 else tuple(reversed(face))
                for face in self.faces]
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


def broad_leaf(geometry, base, angle, height, reach, width, color, phase):
    """위로 솟았다 처지는 잎맥·말린 비대칭 가장자리. 작은 화면에서도 읽히는 면적."""
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    across = Vector((-direction.y, direction.x, 0))
    start = Vector(base)
    handedness = RNG.choice((-1, 1))
    rings = []
    for t, breadth in ((0, .06), (.25, .66), (.49, 1.0), (.73, .82), (.90, .34)):
        center = start + direction * (reach * t ** 1.30) + across * (handedness * width * .18 * t * t)
        center.z += height * (2.6 * t - 1.95 * t * t)
        ring = []
        for side in (-1, 0, 1):
            point = center + across * (width * breadth * side * (.43 if side == handedness else .52))
            # 잎맥의 능선과 서로 다른 양쪽 말림으로 평평한 종이 모양 방지.
            point.z += width * breadth * (.19 if side == 0 else -.12 + side * handedness * .10 * t)
            tint = (.46 + .54 * math.sin(t * 1.65)) * (1.07 if side == 0 else .78 if side == -1 else .96)
            ring.append(geometry.vertex(point, tuple(c * tint for c in color), t, phase))
        rings.append(ring)
    for low, high in zip(rings, rings[1:]):
        geometry.faces.extend(((low[0], low[1], high[1], high[0]), (low[1], low[2], high[2], high[1])))
    tip_point = start + direction * reach + across * (handedness * width * .18) + Vector((0, 0, height * .56))
    tip = geometry.vertex(tip_point, tuple(c * .96 for c in color), 1, phase)
    geometry.faces.extend(((rings[-1][0], rings[-1][1], tip), (rings[-1][1], rings[-1][2], tip)))


def fern_frond(geometry, base, angle, length, color, phase, height_scale=1.0):
    """굽은 잎축과 엇갈린 소엽. 길이·좌우 크기·잎끝 방향이 다른 부채 윤곽."""
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    across = Vector((-direction.y, direction.x, 0))
    start = Vector(base)
    bend = RNG.uniform(-.14, .14)
    lift = RNG.uniform(.88, 1.16)
    tiers = RNG.choice((5, 6, 7))
    def spine(t):
        return start + direction * (length * .72 * t ** 1.2) + across * (length * bend * t * t) + Vector((0, 0, length * lift * (1.55 * t - 1.12 * t * t) * height_scale))
    for segment in range(6):
        points = []
        for t in (segment / 6, (segment + 1) / 6):
            points.append([geometry.vertex(spine(t) + across * side * .0035 * (1 - .6 * t),
                tuple(c * (.46 + .48 * t) for c in color), t, phase) for side in (-1, 1)])
        geometry.faces.append((points[0][0], points[0][1], points[1][1], points[1][0]))
    for tier in range(1, tiers + 1):
        for side in (-1, 1):
            t = (tier + (.21 if side > 0 else 0)) / (tiers + 1.5)
            center = spine(t)
            spread = length * .235 * math.sin(math.pi * t) ** .65 * RNG.uniform(.78, 1.12)
            tip = center + across * side * spread + direction * spread * RNG.uniform(.25, .52)
            tip.z += spread * (.28 - .60 * t)
            mid = center.lerp(tip, .52)
            shade = .54 + .46 * t
            ids = [geometry.vertex(p, tuple(c * shade * tint for c in color), min(1, t + weight), phase)
                   for p, weight, tint in ((center, 0, .82),
                       (mid - direction * spread * .30, .10, .83),
                       (mid + Vector((0, 0, spread * .22)), .13, 1.14),
                       (mid + direction * spread * .40, .10, 1.00), (tip, .20, 1.12))]
            geometry.faces.extend(((ids[0], ids[1], ids[2]), (ids[0], ids[2], ids[3]),
                                   (ids[1], ids[4], ids[2]), (ids[2], ids[4], ids[3])))


def plant_group(geometry, base, axis, scale, kind, phase):
    """한쪽으로 겹치는 군락의 높이층. 완성 메시를 원본에서 개별 편집 가능."""
    direction = Vector((math.cos(axis), math.sin(axis), 0))
    tangent = Vector((-direction.y, direction.x, 0))
    if kind == "fern":
        for offset, length in ((-.62, .49), (-.16, .64), (.38, .52), (.86, .40), (.09, .42)):
            foot = base + tangent * RNG.uniform(-.055, .045)
            fern_frond(geometry, foot, axis + offset, length * scale, RNG.choice(FERN), phase)
    elif kind == "broadleaf":
        for offset, height, reach in ((-.84, .195, .28), (-.38, .245, .36), (.22, .215, .38),
                                     (.73, .17, .33), (-.17, .14, .29), (.50, .11, .25), (-.64, .13, .225)):
            foot = base + tangent * RNG.uniform(-.08, .07) - direction * RNG.uniform(0, .013)
            broad_leaf(geometry, foot, axis + offset, height * scale, reach * scale,
                       RNG.uniform(.11, .155) * scale, RNG.choice(BROADLEAF), phase)
    elif kind == "grass":
        for i in range(11):
            foot = base + tangent * RNG.uniform(-.065, .065) + direction * RNG.uniform(-.012, .018)
            blade(geometry, foot, axis + RNG.uniform(-1.1, 1.1), RNG.uniform(.23, .43) * scale,
                  RNG.uniform(.065, .15) * scale, RNG.uniform(.026, .045) * scale,
                  GRASS[-1] if i == 0 else RNG.choice(GRASS[:4]), phase)
    elif kind == "ground":
        for i in range(8):
            foot = base + tangent * RNG.uniform(-.10, .10) + direction * RNG.uniform(-.006, .04)
            broad_leaf(geometry, foot, axis + RNG.uniform(-1.0, .95), RNG.uniform(.075, .13) * scale,
                       RNG.uniform(.13, .21) * scale, RNG.uniform(.065, .105) * scale,
                       RNG.choice(UNDERSTORY), phase)


def focal_canopy(geometry, center, normal, tangent, phase, variant):
    """타일 안쪽까지 채우는 교차 부채·넓은 잎·기저. 중앙은 설치 시 전체 제거."""
    axis = math.atan2(-normal.y, -normal.x)
    base = center + normal * .22 - tangent * .03
    # 긴 잎을 낮게 굽혀 높이 증가보다 수평 피복을 확보.
    fronds = ((-.95, .76), (-.48, .92), (.02, .98), (.44, .83), (.92, .69), (.22, .74))
    for index, (offset, length) in enumerate(fronds):
        foot = base + normal * RNG.uniform(-.035, .06) + tangent * RNG.uniform(-.085, .085)
        fern_frond(geometry, foot, axis + offset + variant * .045, length,
                   tuple(c * (.81 if index in (1, 3) else .64) for c in FERN[index % 3]), phase, .64)

    # 서로 다른 세 밑동의 중층 잎. 돌 밑에서 중앙으로 갈라져 큰 한 덩어리 구성.
    for stand, normal_offset, along, heading in ((0, .265, -.19, -.25), (1, .12, .19, .34), (2, -.025, -.03, -.18)):
        foot = center + normal * normal_offset + tangent * along
        for index, offset in enumerate((-.85, -.39, -.06, .28, .68, 1.02)):
            start = foot + tangent * RNG.uniform(-.055, .055) + normal * RNG.uniform(-.025, .025)
            broad_leaf(geometry, start, axis + heading + offset,
                       RNG.uniform(.17, .275) if stand < 2 else RNG.uniform(.11, .19),
                       RNG.uniform(.36, .55), RNG.uniform(.155, .235),
                       tuple(c * (.90 if index in (1, 4) else .69) for c in BROADLEAF[(stand + index) % 4]), phase)

    # 식물 사이 맨바닥을 연결하는 낮은 잎. 제거 후 지형에 암부 흔적이 남지 않음.
    for index in range(14):
        foot = center + normal * RNG.uniform(-.05, .29) + tangent * RNG.uniform(-.24, .24)
        broad_leaf(geometry, foot, axis + RNG.uniform(-1.15, 1.22),
                   RNG.uniform(.055, .115), RNG.uniform(.23, .38), RNG.uniform(.13, .19),
                   UNDERSTORY[index % 3], phase)

    # 자기 타일 안의 넓은 윤곽. 바람 여유까지 이웃의 중앙 설치 영역과 분리.
    outward = [(Vector(v) - center).dot(normal) for v in geometry.vertices]
    sideways = [(Vector(v) - center).dot(tangent) for v in geometry.vertices]
    near, far = min(outward), max(outward)
    left, right = min(sideways), max(sideways)
    for index, vertex in enumerate(geometry.vertices):
        point = Vector(vertex)
        n = -.37 + (outward[index] - near) / (far - near) * .81
        t = -.455 + (sideways[index] - left) / (right - left) * .91
        geometry.vertices[index] = tuple(center + normal * n + tangent * t + Vector((0, 0, point.z - center.z)))


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
        # 높은 둥근 꼭짓점을 비스듬한 면으로 깎아 납작한 석재 무게감 확보.
        top = min(co.z * irregular, .72 + co.x * .17 - co.y * .09) if radii[2] > .012 else co.z * irregular
        point = (center[0] + x * math.cos(angle) - y * math.sin(angle),
                 center[1] + x * math.sin(angle) + y * math.cos(angle),
                 center[2] + top * radii[2])
        tint = RNG.uniform(.91, 1.09) * (.61 + .39 * max(0, min(1, (co.z + .7) / 1.6)))
        # 상단의 연속된 이끼와 어두운 돌 하부. 무작위 밝은 삼각형 얼룩 억제.
        base_color = MOSS[0] if moss and co.z > .52 and co.x + co.y > .30 else color
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
    if SOURCE.exists():
        raise RuntimeError("현재 편집 원본 보호: 이전 생성기로 덮어쓰지 않습니다. 저장 원본 출력은 export_dressing.py, 마스터 재조립은 assemble_master_dressing.py를 사용하세요.")
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
    parent["artDirectionRevision"] = "lush-canopy-20260912"
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

    # 권역별로 직접 정한 초점과 빈 면. 모든 경계를 같은 간격으로 채우지 않음.
    edges = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0)}
    placements, foliage_objects, static_objects = [], [], []

    def place(geometry, name, column, row, kind, edge=None, removable=False):
        group = "rocks" if kind in ("rocks", "roots", "inner_rocks") else "foliage"
        obj = geometry.object(name, materials[group], source_collection, parent)
        obj["dressingGroup"], obj["tile"] = group, [column, row]
        obj["plantFamily"] = kind
        if removable:
            obj["removableOnBuild"] = True
        if group == "foliage":
            wind_preview(obj)
            foliage_objects.append(obj)
        else:
            static_objects.append(obj)
        item = {"name": name, "tile": [column, row], "kind": kind}
        if edge:
            item["edge"] = edge
        if removable:
            item["removableOnBuild"] = True
        placements.append(item)

    focal_specs = (
        (3, 0, "N", -.04, 1.00, "fern"),
        (5, 1, "E", .02, 1.04, "fern"),
        (7, 4, "E", -.08, .98, "broadleaf"),
        (7, 7, "E", .00, .86, "grass"),
        (0, 7, "W", -.11, .96, "fern"),
        (0, 9, "W", .06, .92, "broadleaf"),
    )
    for column, row, edge, along, scale, family in focal_specs:
        dc, dr = edges[edge]
        normal = Vector((dc, -dr, 0))
        tangent = Vector((-normal.y, normal.x, 0))
        axis = math.atan2(normal.y, normal.x)
        center = Vector((column - 3.5, 4.5 - row, -.008))
        base = center + normal * .455 + tangent * along
        # 뒤의 높은 부채, 돌 옆 넓은 잎, 틈을 덮는 낮은 층의 겹침.
        for layer, offset, depth, layer_scale in (
            (family, -.07, .005, scale),
            ("broadleaf", .12, -.004, scale * .90),
            ("grass", -.19, -.012, scale * .86),
            ("ground", .03, .002, scale * 1.02),
        ):
            geometry = Geometry()
            plant_group(geometry, base + tangent * offset + normal * depth,
                        axis, layer_scale, layer, RNG.uniform(0, math.tau))
            # 같은 광원 아래 높은 잎·중간 잎·기저가 다른 명도로 읽히는 층 구분.
            shade = .78 if layer == "fern" else .69 if layer == "broadleaf" else .86
            geometry.colors = [tuple(c * shade for c in color[:3]) + (1.0,) for color in geometry.colors]
            place(geometry, f"{layer}_c{column}_r{row}_{edge}_{len(placements)}", column, row, layer, edge)
        # 돌 뒤와 옆을 이어 주는 중간높이 잎 덩어리. 다른 타일의 난수 배치 보존.
        saved_random = RNG.getstate()
        RNG.seed(42000 + row * columns + column)
        bank = Geometry()
        bank_phase = RNG.uniform(0, math.tau)
        for leaf, along_leaf in enumerate((-.28, -.21, -.17, -.105, -.055, .015, .065, .115, .165, .21, .255, .29)):
            foot = base + tangent * (along_leaf * scale) - normal * .012
            broad_leaf(bank, foot, axis + RNG.uniform(-.72, .79),
                       RNG.uniform(.15, .27) * scale, RNG.uniform(.22, .34) * scale,
                       RNG.uniform(.10, .155) * scale,
                       UNDERSTORY[leaf % 3] if leaf % 4 != 0 else BROADLEAF[0], bank_phase)
        place(bank, f"understory_bank_c{column}_r{row}_{edge}", column, row, "broadleaf", edge)
        RNG.setstate(saved_random)
        stone = Geometry()
        # 비대칭 큰 돌과 낮은 받침돌. 중앙은 비우고 바깥 윤곽만 충분히 확보.
        for offset, tangent_size, normal_size, height in ((.08, .205, .105, .175), (-.18, .125, .079, .102)):
            location = center + normal * .493 + tangent * (along + offset)
            location.z = height * .60
            radii = (normal_size, tangent_size, height) if dc else (tangent_size, normal_size, height)
            add_rock(stone, location, radii, ROCK, moss=True)
            cap = location + tangent * (-tangent_size * .58)
            cap.z += height * .60
            radii = (.032, tangent_size * .37, .006) if dc else (tangent_size * .37, .032, .006)
            add_rock(stone, cap, radii, MOSS[1])
        place(stone, f"moss_stones_c{column}_r{row}_{edge}", column, row, "rocks", edge)
        roots = Geometry()
        for offset, length in ((-.15, .31), (.20, .20)):
            start = center + normal * .467 + tangent * (along + offset)
            start.z = .001
            points = [start + normal * (.012 * i) + tangent * (math.sin(i * 1.1) * .021)
                      - Vector((0, 0, length * i / 5)) for i in range(6)]
            root_branch(roots, points, .010)
        place(roots, f"roots_c{column}_r{row}_{edge}", column, row, "roots", edge)

    # 모서리를 돌아가는 작은 동반 군락과 빈 면 사이의 불규칙한 연결점.
    rim_specs = (
        (3, 0, "E", .18, .78, "broadleaf"), (3, 0, "N", .32, .62, "grass"),
        (5, 1, "N", -.14, .80, "broadleaf"), (4, 1, "N", -.27, .70, "grass"),
        (7, 4, "N", -.22, .79, "fern"), (7, 5, "E", -.21, .62, "ground"),
        (7, 7, "S", .07, .86, "broadleaf"), (6, 7, "S", -.28, .64, "grass"),
        (0, 7, "N", -.12, .72, "broadleaf"), (0, 8, "W", .20, .65, "ground"),
        (0, 9, "S", .12, .76, "grass"),
        (0, 1, "W", .10, .61, "broadleaf"), (6, 2, "E", -.11, .60, "ground"),
        (1, 3, "S", -.10, .69, "broadleaf"), (2, 4, "W", -.10, .62, "grass"),
        (3, 5, "W", .16, .60, "ground"), (3, 8, "E", -.19, .61, "broadleaf"),
        (7, 6, "E", .21, .56, "grass"), (5, 3, "E", -.20, .63, "grass"),
    )
    for column, row, edge, along, scale, family in rim_specs:
        dc, dr = edges[edge]
        adjacent_c, adjacent_r = column + dc, row + dr
        assert not (0 <= adjacent_c < columns and 0 <= adjacent_r < rows) or tiles[adjacent_r * columns + adjacent_c] == "blocked"
        normal = Vector((dc, -dr, 0))
        tangent = Vector((-normal.y, normal.x, 0))
        center = Vector((column - 3.5, 4.5 - row, -.006))
        geometry = Geometry()
        plant_group(geometry, center + normal * .454 + tangent * along,
                    math.atan2(normal.y, normal.x), scale, family, RNG.uniform(0, math.tau))
        place(geometry, f"rim_{family}_c{column}_r{row}_{edge}", column, row, family, edge)

    # 내부 틈은 세 대표 모서리와 일부 연결점만 선택. 잎이 틈을 따라 겹침.
    seam_specs = (
        (2, 0, "E", -.24, .63, "broadleaf"), (2, 0, "S", .17, .59, "ground"),
        (2, 3, "E", -.21, .62, "broadleaf"), (2, 3, "S", .18, .56, "grass"),
        (2, 7, "E", -.23, .60, "broadleaf"), (2, 7, "S", .21, .60, "ground"),
        (3, 1, "E", .21, .46, "grass"), (5, 2, "S", .12, .44, "ground"),
        (3, 4, "S", -.17, .50, "broadleaf"), (3, 5, "E", .11, .46, "grass"),
        (5, 7, "E", -.24, .52, "ground"), (7, 4, "S", .24, .48, "ground"),
    )
    for column, row, edge, along, scale, family in seam_specs:
        dc, dr = edges[edge]
        assert tiles[(row + dr) * columns + column + dc] == "build"
        normal = Vector((dc, -dr, 0))
        tangent = Vector((-normal.y, normal.x, 0))
        center = Vector((column - 3.5, 4.5 - row, -.017))
        base = center + normal * .50 + tangent * along
        geometry = Geometry()
        plant_group(geometry, base, math.atan2(tangent.y, tangent.x), scale, family, RNG.uniform(0, math.tau))
        # 0.256타일 이음새 띠에 맞춘 횡폭 조정. 잎의 종방향 굽힘·높이는 보존.
        transverse = [abs((Vector(v) - base).dot(normal)) for v in geometry.vertices]
        factor = min(1.0, .102 / max(transverse))
        geometry.vertices = [tuple(Vector(v) - normal * ((Vector(v) - base).dot(normal) * (1 - factor))) for v in geometry.vertices]
        place(geometry, f"seam_{family}_c{column}_r{row}_{edge}", column, row, family, edge)
    for column, row in ((2, 0), (2, 3), (2, 7)):
        center = Vector((column - 3.5, 4.5 - row, 0))
        stone = Geometry()
        for offset, radius in ((-.035, .094), (.068, .054)):
            add_rock(stone, center + Vector((.50 + offset, -.50, radius * .45)),
                     (radius, radius * .72, radius * .83), ROCK, moss=True)
        place(stone, f"inner_moss_stones_c{column}_r{row}", column, row, "inner_rocks", "SE")

    # 빈칸 안쪽은 가까운 틈에서 들어오는 비대칭 군락. slot 0/16 회귀 검사 유지.
    focal_tiles = {(c, r): (edge, along, scale, family) for c, r, edge, along, scale, family in focal_specs}
    connector_tiles = {(2, 0): "E", (4, 1): "E", (5, 2): "N", (7, 5): "N",
                       (0, 8): "N", (2, 3): "S", (2, 7): "E"}
    for tile_index, slot in build_slots.items():
        column, row = tile_index % columns, tile_index // columns
        connector = connector_tiles.get((column, row))
        focal = focal_tiles.get((column, row))
        if not focal and not connector and slot not in (0, 16) and (column * 3 + row * 5) % 7 in (0, 1):
            continue
        choices = [(edge, dc, dr) for edge, (dc, dr) in edges.items()
                   if not (0 <= column + dc < columns and 0 <= row + dr < rows)
                   or tiles[(row + dr) * columns + column + dc] in ("build", "blocked")]
        edge, dc, dr = choices[(column + row) % len(choices)]
        if focal or connector:
            edge = focal[0] if focal else connector
            dc, dr = edges[edge]
        normal = Vector((dc, -dr, 0))
        tangent = Vector((-normal.y, normal.x, 0))
        center = Vector((column - 3.5, 4.5 - row, -.010))
        base = center + normal * .30 + tangent * RNG.uniform(-.13, .13)
        geometry = Geometry()
        phase = RNG.uniform(0, math.tau)
        axis = math.atan2(-normal.y, -normal.x)
        family = "broadleaf" if slot % 4 in (0, 1) else "grass" if slot % 4 == 2 else "ground"
        if focal:
            focal_canopy(geometry, center, normal, tangent, phase, column % 3 - 1)
        elif connector:
            # 선택한 이웃 칸의 관목형 연결 패치. 큰 군락 사이에 중간 밀도 형성.
            base = center + normal * .275 + tangent * .04
            plant_group(geometry, base, axis - .14, 1.08, "broadleaf", phase)
            plant_group(geometry, base - normal * .12 - tangent * .105,
                        axis + .36, .96, "ground", phase)
            for offset, length in ((-.39, .52), (.41, .44)):
                fern_frond(geometry, base + normal * .015, axis + offset, length,
                           tuple(c * .73 for c in FERN[0]), phase, .72)
        else:
            plant_group(geometry, base, axis + .18, .76 if family == "broadleaf" else .72, family, phase)
        # 이음새 쪽 낮은 잎과 안쪽으로 솟는 중심을 이어 독립된 별 무늬 제거.
        for offset, size in ((-.07, .16), (.055, .19), (.12, .12)):
            foot = base + tangent * offset + normal * .025
            broad_leaf(geometry, foot, axis + offset * 3, size * .52, size, size * .50,
                       RNG.choice(BROADLEAF), phase)
        place(geometry, f"center_vegetation_c{column}_r{row}", column, row, "center_vegetation", edge, True)

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
    camera.location = (5, -13, 27)  # Godot (5, 27, 13)의 Blender 좌표
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
        "source": SOURCE.name, "seed": 120926, "revision": "lush-canopy-20260912", "windMaximumDisplacement": .022,
        "buildClearHalfWidth": .35, "foliageClusters": len(foliage_objects),
        "staticClusters": len(static_objects),
        "removableClusters": sum(bool(obj.get("removableOnBuild")) for obj in foliage_objects),
        "placements": placements,
    }, ensure_ascii=False, indent=2) + "\n")
    print("DRESSING_SOURCE", len(foliage_objects), len(static_objects), str(SOURCE))


if __name__ == "__main__":
    main()
