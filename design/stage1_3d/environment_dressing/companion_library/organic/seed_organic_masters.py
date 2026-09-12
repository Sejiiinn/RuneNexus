"""시안의 꽃·이끼·덩굴·뿌리를 최초 작성. 저장된 편집 원본은 덮어쓰지 않음."""
from pathlib import Path
import json
import math

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
TARGET = HERE / 'organic-masters.blend'


def rgb(code):
    values = [int(code[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values)


LEAVES = [rgb(value) for value in ('657840', '536d37', '758346', '586e3a', '83904d')]
MOSS = [rgb(value) for value in ('63783c', '7c8d49', '536c36', '8b9650', '60743a')]
VINE = [rgb(value) for value in ('536a38', '6c7c43', '475f34', '78864a')]
WOOD = [rgb(value) for value in ('736d50', '85795a', '615e49', '938265', '68624c')]


def point_on(points, t):
    """개별 명시 제어점을 통과하는 Catmull–Rom 경로."""
    points = [Vector(point) for point in points]
    u = min(max(t, 0), 1) * (len(points) - 1)
    i = min(int(u), len(points) - 2)
    f = u - i
    a, b = points[max(0, i - 1)], points[i]
    c, d = points[i + 1], points[min(len(points) - 1, i + 2)]
    return .5 * ((2 * b) + (-a + c) * f + (2 * a - 5 * b + 4 * c - d) * f * f
                 + (-a + 3 * b - 3 * c + d) * f ** 3)


def mesh_object(name, vertices, faces, colors, material, collection, root, role):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(material)
    attribute = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
    mesh.color_attributes.active_color = attribute
    for datum, color in zip(attribute.data, colors):
        datum.color = (*color, 1)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = root
    obj['editableMaster'] = True
    obj['partRole'] = role
    return obj


def tube(name, controls, radii, material, collection, root, *, segments=8, sides=5,
         color=None, role='stem', bark=False):
    """개별 반경과 축 방향 비틀림을 가진 연속 메시. 뿌리는 마디 양끝까지 가늘어짐."""
    color = color or LEAVES[0]
    points = [point_on(controls, i / segments) for i in range(segments + 1)]
    vertices, colors, faces = [], [], []
    side = None
    for i, point in enumerate(points):
        t = i / segments
        tangent = (points[min(i + 1, segments)] - points[max(i - 1, 0)]).normalized()
        if side is None:
            side = tangent.cross(Vector((0, 0, 1)))
            if side.length < .05:
                side = tangent.cross(Vector((0, 1, 0)))
        side = (side - tangent * side.dot(tangent)).normalized()
        normal = tangent.cross(side).normalized()
        f = t * (len(radii) - 1)
        at = min(int(f), len(radii) - 2)
        radius = radii[at] * (1 - (f - at)) + radii[at + 1] * (f - at)
        for j in range(sides):
            angle = j * math.tau / sides + (.55 * math.sin(t * 3.2) if bark else 0)
            ridge = 1 + (.105 * math.cos(angle * 3 + t * 6.5) if bark else 0)
            local = side * math.cos(angle) + normal * math.sin(angle) * (.69 if bark else 1)
            vertices.append(tuple(point + local * radius * ridge))
            if bark:
                shade = .68 + .25 * (math.sin(angle * 2.0 + t * 4.0) + 1) / 2
                base = WOOD[(j + i // 4) % len(WOOD)]
            else:
                shade, base = .64 + .32 * t, color
            colors.append(tuple(c * shade for c in base))
        if i:
            for j in range(sides):
                a = (i - 1) * sides + j
                b = (i - 1) * sides + (j + 1) % sides
                c = i * sides + (j + 1) % sides
                faces.append((a, b, c, i * sides + j))
    faces.extend((tuple(reversed(range(sides))), tuple(range(segments * sides, (segments + 1) * sides))))
    return mesh_object(name, vertices, faces, colors, material, collection, root, role)


def blade(name, controls, width, material, collection, root, *, color, stations=7,
          columns=3, roll=0.0, cup=.08, normal_hint=(0, 0, 1), role='leaf'):
    """잎맥 능선·가장자리 말림을 실제 곡면으로 만든 불투명 잎."""
    vertices, colors, faces = [], [], []
    for i in range(stations):
        t = i / (stations - 1)
        point = point_on(controls, t)
        tangent = (point_on(controls, min(1, t + .015)) - point_on(controls, max(0, t - .015))).normalized()
        across = Vector(normal_hint).cross(tangent)
        if across.length < .05:
            across = Vector((1, 0, 0)).cross(tangent)
        across.normalize()
        normal = tangent.cross(across).normalized()
        angle = roll * (t * t - .15)
        across = across * math.cos(angle) + normal * math.sin(angle)
        normal = tangent.cross(across).normalized()
        breadth = (.10 + .90 * math.sin(math.pi * t) ** .78) * (1 - .12 * t)
        if i == stations - 1:
            breadth = 0
        for j in range(columns):
            u = -1 + 2 * j / (columns - 1)
            lateral = width * .5 * breadth * u * (1 + .13 * u * math.sin(t * 4.0))
            ridge = width * breadth * (.055 * (1 - abs(u)) + cup * abs(u) ** 1.5)
            vertices.append(tuple(point + across * lateral + normal * ridge))
            shade = (.68 + .30 * math.sin(t * 1.5 + .12)) * (1.02 if j == columns // 2 else .87)
            colors.append(tuple(c * shade for c in color))
        if i:
            for j in range(columns - 1):
                a, b = (i - 1) * columns + j, i * columns + j
                faces.append((a, b, b + 1, a + 1))
    tip = len(vertices) - columns
    vertices = vertices[:-columns] + [vertices[-1]]
    colors = colors[:-columns] + [colors[-1]]
    faces = [tuple(dict.fromkeys(tip if v >= tip else v for v in face)) for face in faces]
    faces = [face for face in faces if len(face) >= 3]
    return mesh_object(name, vertices, faces, colors, material, collection, root, role)


def wildflowers(materials, collection, root):
    # 종명을 추정하지 않은 작은 흰 꽃송이. 지름 .04~.055타일, 줄기 7개의 서로 다른 높이.
    flower_heads = [
        ((-.045, .018, .004), (-.072, .044, .115), (-.114, .062, .245), .022, (-.15, -.09, 1)),
        ((.018, .008, .003), (.026, .030, .185), (.084, .045, .362), .023, (.22, -.08, 1)),
        ((-.018, -.028, .004), (-.070, -.069, .13), (-.155, -.081, .186), .019, (-.24, -.18, 1)),
        ((.032, -.018, .005), (.080, -.054, .10), (.148, -.103, .262), .021, (.14, -.27, 1)),
        ((-.006, .021, .004), (-.012, .077, .16), (-.031, .141, .318), .0225, (-.12, .18, 1)),
        ((.019, .026, .004), (.068, .090, .12), (.157, .145, .214), .0185, (.28, .19, 1)),
        ((.004, -.018, .004), (.010, -.034, .21), (-.010, -.062, .403), .0245, (.07, -.15, 1)),
    ]
    for i, (a, b, c, radius, tilt) in enumerate(flower_heads):
        tube(f'Wildflower.stalk_{i + 1:02}', (a, b, c), (.0038, .0025, .0019),
             materials['foliage'], collection, root, segments=7, sides=5, color=LEAVES[1])
        normal = Vector(tilt).normalized()
        xaxis = normal.cross(Vector((0, 1, 0))).normalized()
        yaxis = normal.cross(xaxis).normalized()
        center = Vector(c)
        for petal in range(5):
            angle = petal * math.tau / 5 + .39 * i
            direction = xaxis * math.cos(angle) + yaxis * math.sin(angle)
            across = normal.cross(direction)
            length = radius * (.92 + .06 * ((petal + i) % 3))
            vertices, colors, faces = [], [], []
            for row in range(6):
                t = row / 5
                width = radius * .60 * math.sin(t * math.pi) ** .62
                for col in range(5):
                    u = -1 + col * .5
                    rise = radius * (.10 + .24 * math.sin(t * 2.6) + .11 * u * u * math.sin(t * math.pi))
                    vertices.append(tuple(center + direction * (.003 + length * t)
                                          + across * width * .5 * u + normal * rise))
                    shade = .81 + .18 * t - .025 * abs(u)
                    colors.append(tuple(value * shade for value in rgb('eeeede')))
                if row:
                    for col in range(4):
                        start, end = (row - 1) * 5 + col, row * 5 + col
                        faces.append((start, end, end + 1, start + 1))
            # 꽃잎 양끝의 중복 정점을 병합해 끝과 밑부분의 퇴화면 제거.
            indices, merged_vertices, merged_colors = {}, [], []
            mapping = {}
            for index, vertex in enumerate(vertices):
                key = tuple(round(value, 9) for value in vertex)
                if key not in indices:
                    indices[key] = len(merged_vertices)
                    merged_vertices.append(vertex)
                    merged_colors.append(colors[index])
                mapping[index] = indices[key]
            faces = [tuple(dict.fromkeys(mapping[v] for v in face)) for face in faces]
            faces = [face for face in faces if len(face) >= 3]
            mesh_object(f'Wildflower.bloom_{i + 1:02}.petal_{petal + 1}', merged_vertices, faces,
                        merged_colors, materials['bloom'], collection, root, 'bloom')
        # 작은 노란 중심은 평판 원 대신 얕은 실제 부피.
        ring = [center + (xaxis * math.cos(j * math.tau / 8) + yaxis * math.sin(j * math.tau / 8)) * .0045
                + normal * .004 for j in range(8)]
        vertices = [tuple(value) for value in ring] + [tuple(center + normal * .0075), tuple(center + normal * .001)]
        faces = [(j, (j + 1) % 8, 8) for j in range(8)] + [((j + 1) % 8, j, 9) for j in range(8)]
        mesh_object(f'Wildflower.bloom_{i + 1:02}.center', vertices, faces,
                    [rgb('bdaf65')] * 10, materials['bloom'], collection, root, 'bloom')
        for leaf_index, progress in enumerate((.24, .51)):
            join = point_on((a, b, c), progress)
            angle = .80 * i + (0 if leaf_index else math.pi)
            direction = Vector((math.cos(angle), math.sin(angle), .18))
            length = .12 if leaf_index == 0 else .092
            end = join + direction * length
            controls = (join, join.lerp(end, .43) + Vector((0, 0, .020)), end)
            blade(f'Wildflower.leaf_{i + 1:02}_{leaf_index}', controls, .022 if leaf_index else .029,
                  materials['foliage'], collection, root, color=LEAVES[(i + leaf_index) % 5], roll=(-.4 if i % 2 else .5))


def moss_patch(materials, collection, root):
    # 각각 다른 갈라짐과 낮은 굴곡을 가진 크고 작은 여섯 이끼섬.
    islands = [
        ((-.19, -.07), ((-.17, -.055), (-.12, -.13), (-.025, -.14), (.03, -.084), (.14, -.075), (.16, .013), (.08, .061), (-.026, .046), (-.10, .092), (-.162, .023)), .028),
        ((.12, .10), ((-.13, -.10), (-.042, -.11), (.02, -.055), (.132, -.060), (.16, .012), (.076, .081), (.014, .058), (-.039, .12), (-.12, .061)), .034),
        ((.23, -.155), ((-.08, -.045), (-.025, -.082), (.06, -.075), (.095, -.012), (.038, .041), (-.006, .024), (-.054, .062)), .023),
        ((-.20, .205), ((-.073, -.058), (.006, -.042), (.064, -.009), (.032, .067), (-.019, .082), (-.086, .029)), .026),
        ((-.035, -.265), ((-.069, -.019), (-.007, -.068), (.062, -.046), (.087, .002), (.032, .043), (-.034, .023)), .019),
        ((.324, .237), ((-.044, -.038), (.028, -.047), (.066, .008), (.027, .047), (-.035, .024)), .021),
    ]
    anchors = ((-.050, -.019), (.028, -.029), (.057, .014), (-.009, .040), (-.064, .033))
    for i, ((cx, cy), outline, height) in enumerate(islands):
        count = len(outline)
        vertices, colors, faces = [], [], []
        for ring in range(3):
            for j, (x, y) in enumerate(outline):
                if ring == 0:
                    vertex = (cx + x, cy + y, .003)
                elif ring == 1:
                    vertex = (cx + x, cy + y, .006 + height * (.15 + .13 * ((j + i) % 3)))
                else:
                    vertex = (cx + x * .52 + .006, cy + y * .52 - .003,
                              height * (.79 + .17 * ((j + i) % 3)))
                vertices.append(vertex)
                color = MOSS[(i + j // 3) % 5]
                colors.append(tuple(c * (.56 if ring == 0 else .70 if ring == 1 else .93) for c in color))
        vertices.append((cx + .009, cy - .012, height * 1.03))
        colors.append(MOSS[(i + 1) % 5])
        for j in range(count):
            nxt = (j + 1) % count
            faces.extend(((j, nxt, count + nxt, count + j),
                          (count + j, count + nxt, 2 * count + nxt, 2 * count + j),
                          (2 * count + j, 2 * count + nxt, 3 * count)))
        faces.append(tuple(reversed(range(count))))
        mesh_object(f'Moss.island_{i + 1:02}.woven_base', vertices, faces, colors,
                    materials['foliage'], collection, root, 'moss_support')
        for tuft, (offset_x, offset_y) in enumerate(anchors):
            scale = .64 if i in (2, 3, 4, 5) else 1
            base = Vector((cx + offset_x * scale, cy + offset_y * scale, height * .91))
            for leaf in range(3):
                angle = i * 1.14 + tuft * 2.26 + leaf * 1.84
                length = .036 + .010 * ((leaf + 2 * tuft + i) % 3)
                direction = Vector((math.cos(angle), math.sin(angle), 0))
                end = base + direction * length + Vector((0, 0, .008 + .005 * leaf))
                controls = (base, base.lerp(end, .46) + Vector((0, 0, .023)), end)
                blade(f'Moss.island_{i + 1:02}.tuft_{tuft + 1}.leaf_{leaf + 1}', controls,
                      .013 + .002 * ((tuft + i) % 2), materials['foliage'], collection, root,
                      color=MOSS[(i + tuft + leaf) % 5], stations=5, roll=.75 * math.sin(angle), cup=.13)


def trailing_vine(materials, collection, root):
    # 벽 위 걸침점에서 내려오는 세 갈래. 잎자루와 작은 잎이 겹치는 세로 구조.
    runners = [((0, .025, .007), (-.033, -.008, -.055), (.001, -.069, -.208), (-.070, -.080, -.404), (-.025, -.111, -.663)),
               ((-.013, .022, .005), (-.118, -.025, -.070), (-.190, -.065, -.23), (-.257, -.086, -.410), (-.202, -.115, -.540)),
               ((.016, .019, .004), (.113, -.020, -.056), (.171, -.061, -.205), (.298, -.077, -.352), (.293, -.119, -.476))]
    layout = [
        ((.08, -1, .075), (.16, 1, .098), (.20, -1, .095), (.28, 1, .080), (.34, -1, .115), (.39, -1, .088), (.46, 1, .101), (.54, -1, .087), (.60, 1, .102), (.68, -1, .082), (.74, 1, .095), (.81, 1, .076), (.87, -1, .076), (.94, 1, .061)),
        ((.07, -1, .070), (.14, 1, .079), (.22, -1, .097), (.27, 1, .082), (.35, -1, .092), (.43, 1, .092), (.50, -1, .078), (.56, 1, .077), (.65, -1, .092), (.72, 1, .079), (.78, -1, .071), (.84, -1, .064), (.91, 1, .067)),
        ((.09, 1, .078), (.15, -1, .089), (.23, 1, .100), (.30, -1, .074), (.36, 1, .095), (.43, -1, .082), (.52, 1, .082), (.58, 1, .074), (.65, -1, .085), (.74, 1, .072), (.81, -1, .075), (.88, 1, .066), (.94, -1, .055)),
    ]
    for runner, controls in enumerate(runners):
        tube(f'Vine.runner_{runner + 1:02}', controls, (.007, .0057, .004, .003, .0012),
             materials['foliage'], collection, root, segments=12, sides=5, color=rgb('647049'))
        for leaf, (t, side, length) in enumerate(layout[runner]):
            node = point_on(controls, t)
            start = node + Vector((side * .018, -.010, -.006))
            end = start + Vector((side * length * .71, -.026 - .005 * (leaf % 3), -length * .56))
            tube(f'Vine.runner_{runner + 1:02}.petiole_{leaf + 1:02}', (node, start), (.0023, .0014),
                 materials['foliage'], collection, root, segments=2, sides=3, color=VINE[1])
            points = (start, start.lerp(end, .43) + Vector((0, -.018, .012)), end)
            blade(f'Vine.runner_{runner + 1:02}.leaf_{leaf + 1:02}', points, length * (.46 + .05 * (leaf % 2)),
                  materials['foliage'], collection, root, color=VINE[(runner + leaf) % 4],
                  roll=side * (.30 + .10 * (leaf % 3)), cup=.07, normal_hint=(0, -1, .25))


def exposed_roots(materials, collection, root):
    # 시작점과 끝점은 흙으로 들어가는 얇은 형태. 두꺼운 절단면·통나무 실루엣은 만들지 않음.
    roots = [
        (((-.49, .16, -.014), (-.29, .11, .017), (-.105, .043, .073), (.115, .019, .069), (.32, -.083, .018), (.57, -.18, -.017)), (.0016, .028, .066, .057, .030, .0010), 20, 9),
        (((-.108, .05, .041), (-.152, -.075, .073), (-.12, -.22, .037), (-.254, -.369, -.010)), (.037, .035, .024, .0013), 13, 8),
        (((.08, .02, .055), (.105, .17, .073), (.026, .32, .022), (.09, .45, -.018)), (.032, .029, .018, .0010), 13, 8),
        (((.29, -.07, .025), (.36, .036, .049), (.47, .068, .020), (.58, .024, -.010)), (.022, .019, .013, .0007), 10, 7),
        (((-.135, -.20, .032), (-.033, -.267, .041), (.068, -.281, .011), (.157, -.366, -.012)), (.018, .015, .009, .0007), 10, 7),
        (((.027, .31, .018), (-.096, .332, .032), (-.201, .411, -.008)), (.012, .009, .0005), 8, 6),
        (((-.291, .117, .016), (-.317, .268, .018), (-.425, .314, -.012)), (.015, .011, .0007), 8, 6),
    ]
    for index, (controls, radii, segments, sides) in enumerate(roots):
        tube(f'Root.branch_{index + 1:02}', controls, radii, materials['bark'], collection, root,
             segments=segments, sides=sides, bark=True, role='root')


def main():
    if not bpy.app.background or bpy.data.filepath:
        raise RuntimeError('최초 작성 전용입니다. 별도 Blender --background --factory-startup에서 실행하세요.')
    if TARGET.exists():
        raise FileExistsError('저장된 원본 보호: 기존 organic-masters.blend는 재생성하지 않습니다. 해당 원본을 직접 편집하세요.')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    original = bpy.context.scene
    materials = {}
    for key, roughness in (('foliage', .90), ('bloom', .81), ('bark', .95)):
        material = bpy.data.materials.new('Companion_' + key)
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get('Principled BSDF')
        attribute = material.node_tree.nodes.new('ShaderNodeVertexColor')
        attribute.layer_name = 'Color'
        material.node_tree.links.new(attribute.outputs['Color'], bsdf.inputs['Base Color'])
        bsdf.inputs['Roughness'].default_value = roughness
        bsdf.inputs['Specular IOR Level'].default_value = .12
        material.use_backface_culling = False
        material.diffuse_color = (*LEAVES[0], 1)
        materials[key] = material
    records = []
    definitions = (
        ('01 Wildflower Master', '01 Wildflower', 'wildflower_clump', wildflowers),
        ('05 Moss Patch Master', '05 Moss Patch', 'creeping_moss', moss_patch),
        ('06 Trailing Vine Master', '06 Trailing Vine', 'trailing_vine', trailing_vine),
        ('07 Exposed Root Master', '07 Exposed Root', 'exposed_root', exposed_roots),
    )
    for scene_name, collection_name, asset_id, builder in definitions:
        scene = bpy.data.scenes.new(scene_name)
        scene.unit_settings.system = 'METRIC'
        scene.unit_settings.scale_length = 1
        collection = bpy.data.collections.new(collection_name)
        scene.collection.children.link(collection)
        root = bpy.data.objects.new(asset_id + '_root', None)
        collection.objects.link(root)
        root['assetId'] = asset_id
        root['plantAssetId'] = asset_id
        root['tileUnits'] = 1.0
        root['sourceRole'] = 'independent_editable_master'
        root['productionMethod'] = 'individual authored control points and mesh geometry; initial Python seed'
        builder(materials, collection, root)
        meshes = [obj for obj in collection.objects if obj.type == 'MESH']
        for obj in meshes:
            obj.data.calc_loop_triangles()
            if not all(math.isfinite(value) for vertex in obj.data.vertices for value in vertex.co):
                raise RuntimeError(f'유효하지 않은 정점: {obj.name}')
            if any(triangle.area <= 1e-12 for triangle in obj.data.loop_triangles):
                raise RuntimeError(f'퇴화 삼각형: {obj.name}')
        triangles = sum(len(obj.data.loop_triangles) for obj in meshes)
        bounds = {'min': [min(vertex.co[i] for obj in meshes for vertex in obj.data.vertices) for i in range(3)],
                  'max': [max(vertex.co[i] for obj in meshes for vertex in obj.data.vertices) for i in range(3)]}
        records.append({'assetId': asset_id, 'plantAssetId': asset_id, 'scene': scene.name,
                        'collection': collection.name, 'root': root.name, 'meshObjects': len(meshes),
                        'triangles': triangles, 'bounds': bounds,
                        'parts': {role: sum(obj['partRole'] == role for obj in meshes)
                                  for role in sorted({obj['partRole'] for obj in meshes})}})
        scene.world = bpy.data.worlds.new(collection_name + ' Preview World')
        scene.world.color = (.12, .15, .12)
        scene.view_settings.view_transform = 'AgX'
    bpy.data.scenes.remove(original)
    bpy.context.window.scene = bpy.data.scenes['01 Wildflower Master']
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.type = 'MATERIAL'
            region = area.spaces.active.region_3d
            region.view_distance = 1.6
            region.view_location = (0, 0, .12)
            region.view_rotation = Vector((1.2, -2, 1.4)).to_track_quat('Z', 'Y')
    text = bpy.data.texts.new('README - Editable Organic Masters')
    text.write('시안 보완 환경 에셋 4종\n\n상단 Scene에서 흰꽃·이끼·늘어지는 덩굴·짧은 뿌리를 선택합니다.\n모든 root는 원점0, 단위1=게임1타일입니다. 덩굴은 벽 위 걸침점을 원점으로 아래쪽 Z로 내려갑니다.\n종명을 추정하지 않고 시안에서 읽히는 형태·색·크기에 맞춰 작성했습니다.\n최초 형태는 seed_organic_masters.py의 개별 명시 제어점과 메시 조형으로 작성했습니다.\n각 줄기·잎·꽃잎·이끼섬·뿌리 가지는 일반 Edit Mode에서 직접 편집할 수 있습니다.\nseed는 저장된 이 원본을 덮어쓰지 않습니다. 캡처와 내보내기는 저장된 원본을 읽습니다.\n맵 배치·게임 GLB와 분리된 형태 검수용 원본입니다. 텍스처·투명도·애니메이션은 사용하지 않습니다.\n')
    manifest = {'source': TARGET.name, 'units': '1 Blender unit = 1 game tile',
                'production': 'individual explicit control points and editable mesh geometry',
                'masters': records, 'totalTriangles': sum(item['triangles'] for item in records),
                'textures': 0, 'materials': 3, 'animations': 0,
                'scope': 'independent asset masters only; no map placement or game export'}
    if manifest['totalTriangles'] > 9000:
        raise RuntimeError(f'원본 메시 예산 점검 필요: {manifest["totalTriangles"]}')
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    (HERE / 'organic_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('ORGANIC_MASTERS_READY', json.dumps(manifest, ensure_ascii=False))


if __name__ == '__main__':
    main()
