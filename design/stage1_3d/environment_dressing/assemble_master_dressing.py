"""저장된 11종 마스터를 읽어 맵용 LOD 복사본과 비대칭 환경 군락을 조립."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import math
import shutil
import struct
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = HERE / 'environment-dressing.blend'
REVISION = 'master-assembly-20260912'
BACKUP = HERE / 'before-master-assembly-20260912'
ASSETS = (
    ('arched_grass', 'plant_library/forest-plant-masters.blend', '01 Grass Master', 'foliage'),
    ('layered_fern', 'plant_library/forest-plant-masters.blend', '02 Fern Master', 'foliage'),
    ('broadleaf_herb', 'plant_library/forest-plant-masters.blend', '03 Broadleaf Master', 'foliage'),
    ('creeping_groundcover', 'plant_library/forest-plant-masters.blend', '04 Groundcover Master', 'foliage'),
    ('wildflower_clump', 'companion_library/organic/organic-masters.blend', '01 Wildflower Master', 'foliage'),
    ('creeping_moss', 'companion_library/organic/organic-masters.blend', '05 Moss Patch Master', 'foliage'),
    ('trailing_vine', 'companion_library/organic/organic-masters.blend', '06 Trailing Vine Master', 'foliage'),
    ('exposed_root', 'companion_library/organic/organic-masters.blend', '07 Exposed Root Master', 'rocks'),
    ('mossy_boulder', 'companion_library/rocks/rock-masters.blend', '02 Mossy Boulder Master', 'rocks'),
    ('flat_stone', 'companion_library/rocks/rock-masters.blend', '03 Flat Stone Master', 'rocks'),
    ('pebble_scatter', 'companion_library/rocks/rock-masters.blend', '04 Pebbles Master', 'rocks'),
)
EDGES = {'N': (0, 1, 0), 'E': (1, 0, 0), 'S': (0, -1, 0), 'W': (-1, 0, 0)}


def geometry_hash(vertices, faces, colors):
    digest = hashlib.sha256()
    for point in vertices:
        digest.update(struct.pack('<3f', *point))
    for face in faces:
        digest.update(struct.pack('<I', len(face)))
        digest.update(struct.pack('<' + 'I' * len(face), *face))
    for color in colors:
        digest.update(struct.pack('<4f', *color))
    return digest.hexdigest()


def selected_geometry(vertices, colors, indices, faces):
    return [vertices[index].copy() for index in indices], faces, [colors[index] for index in indices]


def leaf_lod(vertices, colors, columns, detailed=False, tiny=False):
    rows = (len(vertices) - 1) // columns
    if detailed:
        stations = sorted(set((0, round(rows * .25), round(rows * .50), round(rows * .78))))
        across = (0, columns // 2, columns - 1)
        indices = [row * columns + column for row in stations for column in across] + [len(vertices) - 1]
        faces = []
        for row in range(len(stations) - 1):
            for column in range(2):
                a, b = row * 3 + column, (row + 1) * 3 + column
                faces.append((a, b, b + 1, a + 1))
        last = (len(stations) - 1) * 3
        tip = len(indices) - 1
        faces.extend(((last, tip, last + 1), (last + 1, tip, last + 2)))
    else:
        widest = max(range(1, rows), key=lambda row: (vertices[row * columns + columns - 1] - vertices[row * columns]).length)
        indices = [columns // 2, widest * columns, widest * columns + columns // 2,
                   widest * columns + columns - 1, len(vertices) - 1]
        # 원본 잎의 양쪽 최대 폭·능선·밑동·끝 유지. 고사리의 승인된 폭도 그대로 사용.
        if tiny:
            indices = [indices[index] for index in (0, 1, 3, 4)]
            faces = [(0, 1, 3), (0, 3, 2)]
        else:
            faces = [(0, 1, 2), (0, 2, 3), (1, 4, 2), (2, 4, 3)]
    return selected_geometry(vertices, colors, indices, faces)


def tube_lod(vertices, faces, colors, ring_target, side_target):
    sides = len(faces[-1])
    if sides < 3 or len(vertices) % sides:
        raise RuntimeError('원본 튜브 토폴로지를 판독할 수 없습니다.')
    rings = len(vertices) // sides
    selected_rings = sorted(set(round(index * (rings - 1) / (min(ring_target, rings) - 1))
                                for index in range(min(ring_target, rings))))
    selected_sides = sorted(set(round(index * sides / min(side_target, sides)) % sides
                                for index in range(min(side_target, sides))))
    count = len(selected_sides)
    indices = [ring * sides + side for ring in selected_rings for side in selected_sides]
    output_faces = []
    for ring in range(len(selected_rings) - 1):
        for side in range(count):
            a, b = ring * count + side, ring * count + (side + 1) % count
            output_faces.append((a, b, b + count, a + count))
    output_faces.extend((tuple(reversed(range(count))), tuple(range(len(indices) - count, len(indices)))))
    return selected_geometry(vertices, colors, indices, output_faces)


def decimated_geometry(vertices, faces, colors, ratio, collection):
    mesh = bpy.data.meshes.new('Temporary LOD source')
    mesh.from_pydata(vertices, [], faces)
    attribute = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
    for item, color in zip(attribute.data, colors):
        item.color = color
    obj = bpy.data.objects.new('Temporary LOD source', mesh)
    collection.objects.link(obj)
    modifier = obj.modifiers.new('Map LOD', 'DECIMATE')
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    bpy.context.view_layer.update()
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    simplified = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                               depsgraph=bpy.context.evaluated_depsgraph_get())
    result = ([vertex.co.copy() for vertex in simplified.vertices],
              [tuple(polygon.vertices) for polygon in simplified.polygons],
              [tuple(item.color) for item in simplified.color_attributes['Color'].data])
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    bpy.data.meshes.remove(simplified)
    return result


def load_prototypes(collection):
    assembly_scene = bpy.context.scene
    loaded_scenes = []
    files = {relative: hashlib.sha256((HERE / relative).read_bytes()).hexdigest()
             for _, relative, _, _ in ASSETS}
    for relative in files:
        names = [scene for _, path, scene, _ in ASSETS if path == relative]
        with bpy.data.libraries.load(str(HERE / relative), link=False) as (available, appended):
            appended.scenes = names
        loaded_scenes.extend(appended.scenes)
    prototypes, records = {}, []
    for asset_id, relative, scene_name, group in ASSETS:
        source_scene = next(scene for scene in loaded_scenes if scene.name == scene_name)
        # append 직후 아직 평가되지 않은 원본의 저장된 개별 이동·회전까지 반영.
        bpy.context.window.scene = source_scene
        bpy.context.view_layer.update()
        source_matrices = {obj.name: obj.matrix_world.copy() for obj in source_scene.objects}
        bpy.context.window.scene = assembly_scene
        bpy.context.view_layer.update()
        vertices, faces, colors, front_normals, surface_roles, parts = [], [], [], [], [], []
        original_triangles = 0
        moss_index = 0
        for obj in sorted(source_scene.objects, key=lambda value: value.name):
            if obj.type != 'MESH':
                continue
            original = obj.data
            original.calc_loop_triangles()
            points = [source_matrices[obj.name] @ vertex.co for vertex in original.vertices]
            polygons = [tuple(polygon.vertices) for polygon in original.polygons]
            rgba = [tuple(item.color) for item in original.color_attributes['Color'].data]
            original_triangles += len(original.loop_triangles)
            part_role = obj.get('partRole', 'moss' if 'moss' in obj.name.lower() else 'stone')
            method = 'source geometry retained'
            skipped = False
            if 'midrib_' in obj.name:
                skipped, method = True, 'subpixel separate midrib omitted; leaf surface ridge retained'
            elif asset_id == 'creeping_moss' and part_role == 'leaf':
                skipped = moss_index % 5 != 0
                moss_index += 1
                method = 'distributed 1-in-5 existing microleaves; low island outline retained'
            part = {'name': obj.name, 'role': part_role, 'sourceTriangles': len(original.loop_triangles),
                    'sourceGeometrySha256': geometry_hash(points, polygons, rgba), 'lodMethod': method}
            if skipped:
                part['lodTriangles'] = 0
                parts.append(part)
                continue
            reference = BVHTree.FromPolygons(points, polygons)
            surface = 1 if part_role == 'leaf' else 2 if part_role == 'bloom' and '.petal_' in obj.name else 3
            if part_role == 'leaf':
                columns = 5 if asset_id in ('broadleaf_herb', 'creeping_groundcover') else 3
                points_lod, faces_lod, colors_lod = leaf_lod(points, rgba, columns,
                    detailed=asset_id in ('arched_grass', 'broadleaf_herb'), tiny=asset_id == 'creeping_moss')
                method += '; source boundary/crease samples' if method != 'source geometry retained' else '; longitudinal and cross-section samples'
            elif part_role == 'bloom' and '.petal_' in obj.name:
                # 병합된 원본 꽃잎은 밑동 1점, 내부 4×5점, 끝 1점.
                rows = (len(points) - 2) // 5
                widest = max(range(rows), key=lambda row: (points[1 + row * 5 + 4] - points[1 + row * 5]).length)
                indices = [0, 1 + widest * 5, 1 + widest * 5 + 2, 1 + widest * 5 + 4, len(points) - 1]
                points_lod, faces_lod, colors_lod = selected_geometry(points, rgba, indices,
                    [(0, 1, 2), (0, 2, 3), (1, 4, 2), (2, 4, 3)])
                method = 'all 7 flower heads and 5 petals retained; petal interior tessellation reduced'
            elif part_role in ('stem', 'root'):
                # 잔잎·잎자루 접합점이 있는 주줄기의 모든 원본 링을 유지.
                ring_target = (2 if 'petiole' in obj.name or 'sheath' in obj.name else
                               6 if part_role == 'root' else len(points) // len(polygons[-1]))
                side_target = 5 if part_role == 'root' else 3
                points_lod, faces_lod, colors_lod = tube_lod(points, polygons, rgba, ring_target, side_target)
                method = f'existing tube sampled at {ring_target} rings / {side_target} sides; branch endpoints retained'
            elif asset_id == 'pebble_scatter':
                points_lod, faces_lod, colors_lod = points, polygons, rgba
            else:
                ratio = .30 if asset_id == 'mossy_boulder' else .18 if asset_id == 'flat_stone' else .38 if asset_id == 'creeping_moss' else .25
                points_lod, faces_lod, colors_lod = decimated_geometry(points, polygons, rgba, ratio, collection)
                method = f'existing solid mesh collapse LOD {ratio:.2f}; source vertex colors retained'
            if surface in (1, 2):
                # 큰 비틀림을 건너뛰는 단순화는 해당 잎만 원본 세분 유지. 일괄 법선 반전 금지.
                for face in faces_lod:
                    center = sum((points_lod[index] for index in face), Vector()) / len(face)
                    _, expected, _, _ = reference.find_nearest(center)
                    actual = (points_lod[face[1]] - points_lod[face[0]]).cross(points_lod[face[2]] - points_lod[face[0]]).normalized()
                    if expected is not None and actual.dot(expected) < -.05:
                        points_lod, faces_lod, colors_lod = points, polygons, rgba
                        method += '; original curved part retained where simplification changed surface orientation'
                        break
            offset = len(vertices)
            vertices.extend(points_lod)
            colors.extend(colors_lod)
            for face in faces_lod:
                center = sum((points_lod[index] for index in face), Vector()) / len(face)
                _, normal, _, _ = reference.find_nearest(center)
                faces.append(tuple(index + offset for index in face))
                front_normals.append(normal if normal is not None else Vector((0, 0, 1)))
                surface_roles.append(surface)
            part.update({'lodMethod': method, 'lodTriangles': sum(len(face) - 2 for face in faces_lod)})
            parts.append(part)
        mesh = bpy.data.meshes.new('Master LOD / ' + asset_id)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        attribute = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
        mesh.color_attributes.active_color = attribute
        for item, color in zip(attribute.data, colors):
            item.color = color
        reference_attribute = mesh.attributes.new(name='SourceFront', type='FLOAT_VECTOR', domain='FACE')
        role_attribute = mesh.attributes.new(name='SourceSurfaceRole', type='INT', domain='FACE')
        for index, (normal, role) in enumerate(zip(front_normals, surface_roles)):
            reference_attribute.data[index].vector = normal
            role_attribute.data[index].value = role
        for polygon in mesh.polygons:
            polygon.use_smooth = group == 'foliage'
        mesh.calc_loop_triangles()
        if any(triangle.area <= 1e-12 for triangle in mesh.loop_triangles):
            raise RuntimeError(f'LOD 퇴화 삼각형: {asset_id}')
        bad_front = [polygon.index for polygon in mesh.polygons
                     if surface_roles[polygon.index] in (1, 2)
                     and polygon.normal.dot(front_normals[polygon.index]) < -.05]
        if bad_front:
            raise RuntimeError(f'원본 표면 방향과 어긋난 LOD: {asset_id}: {bad_front[:12]}')
        maximum_distance = max(point.length for point in vertices)
        weights = []
        for point in vertices:
            if asset_id == 'creeping_moss':
                weight = 0.0
            elif asset_id == 'trailing_vine':
                weight = min(1.0, max(0.0, (-point.z - .025) / .62))
            else:
                weight = min(1.0, max(0.0, (point.length - .045) / (maximum_distance - .045)))
                if asset_id == 'creeping_groundcover':
                    weight *= .30
            weights.append(weight)
        records.append({'assetId': asset_id, 'sourceFile': relative, 'sourceSha256': files[relative],
                        'sourceScene': scene_name, 'sourceTriangles': original_triangles,
                        'lodTriangles': len(mesh.loop_triangles), 'lodRatio': len(mesh.loop_triangles) / original_triangles,
                        'sourcePartCount': len(parts), 'parts': parts})
        prototypes[asset_id] = {'mesh': mesh, 'group': group, 'weights': weights, 'record': records[-1]}
    for scene in loaded_scenes:
        for obj in list(scene.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(scene)
    return prototypes, files, records


def wind_preview(obj):
    """기존 공유 셰이더와 같은 두 사인파. 내보내기에는 Basis만 포함."""
    weights = {}
    for loop in obj.data.loops:
        weights[loop.vertex_index] = obj.data.uv_layers['Wind'].data[loop.index].uv.copy()
    obj.shape_key_add(name='Basis', from_mix=False)
    for harmonic, speed, amplitude, phase_scale in ((0, .95, .72, 1), (1, 1.71, .28, 1.37)):
        for function in ('sin', 'cos'):
            key = obj.shape_key_add(name=f'Wind_{harmonic}_{function}', from_mix=False)
            key.slider_min, key.slider_max = -1, 1
            for index, uv in weights.items():
                phase = (1 - uv.y) * phase_scale
                coefficient = math.cos(phase) if function == 'sin' else math.sin(phase)
                shift = .022 * amplitude * uv.x ** 2 * coefficient
                key.data[index].co.x += .92 * shift
                key.data[index].co.y -= .39 * shift
            key.driver_add('value').driver.expression = f'{function}(frame / 30 * {speed})'


def main():
    if not bpy.app.background or bpy.data.filepath:
        raise RuntimeError('마스터 보호: 별도 --background --factory-startup 프로세스에서 실행하세요.')
    if BACKUP.exists() and '--rebuild' not in sys.argv:
        raise RuntimeError('기존 조립 원본 보호: 의도적인 재조립은 -- --rebuild로 실행하세요.')
    payload = (ROOT / 'assets/images/stage1_3d/environment/terrain.glb').read_bytes()
    document = json.loads(payload[20:20 + struct.unpack_from('<I', payload, 12)[0]])
    terrain_manifest = next(node['extras'] for node in document['nodes'] if node.get('name') == 'stage1_environment')
    tiles, columns, rows = terrain_manifest['tileTypes'], terrain_manifest['columns'], terrain_manifest['rows']
    slots = {index: slot for slot, index in enumerate(i for i, kind in enumerate(tiles) if kind == 'build')}
    assert len(slots) == 32
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    scene = bpy.context.scene
    scene.name = 'Stage1EnvironmentDressing'
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    scene.render.fps = 30
    scene.frame_start, scene.frame_end = 1, 240
    collection = bpy.data.collections.new('10 Dressing - editable master instances')
    scene.collection.children.link(collection)
    root = bpy.data.objects.new('stage1_dressing', None)
    collection.objects.link(root)
    for key in ('columns', 'rows', 'tileTypes', 'tileSize', 'gridCenterConvention'):
        root[key] = terrain_manifest[key]
    root['windMaximumDisplacement'] = .022
    root['buildClearHalfWidth'] = .35
    root['buildTileCount'] = len(slots)
    root['removableCenterVegetation'] = True
    root['artDirectionRevision'] = REVISION
    root['sourceConcept'] = 'environment_concepts/01-overgrown-stone-edges.png'
    materials = {}
    for group in ('foliage', 'rocks'):
        material = bpy.data.materials.new('Stage1Dressing_' + group)
        material.use_nodes = True
        color = material.node_tree.nodes.new('ShaderNodeVertexColor')
        color.layer_name = 'Color'
        shader = material.node_tree.nodes.get('Principled BSDF')
        material.node_tree.links.new(color.outputs['Color'], shader.inputs['Base Color'])
        shader.inputs['Roughness'].default_value = .92
        shader.inputs['Specular IOR Level'].default_value = .12
        material.use_backface_culling = group == 'rocks'
        materials[group] = material
    prototypes, source_hashes, source_records = load_prototypes(collection)
    root['masterSources'] = json.dumps(source_hashes, sort_keys=True)
    root['sourceNormalContract'] = 'SourceFront face vectors preserve original surfaces; closed stems and hanging leaves may face down'
    placements = []

    def place(asset_id, column, row, edge, along, distance, scale, angle=0, removable=False, region='connector'):
        prototype = prototypes[asset_id]
        normal = Vector(EDGES[edge])
        tangent = Vector((normal.y, -normal.x, 0))
        center = Vector((column - 3.5, 4.5 - row, .001))
        assert tiles[row * columns + column] == 'build'
        adjacent_column, adjacent_row = column + int(normal.x), row - int(normal.y)
        outside = not (0 <= adjacent_column < columns and 0 <= adjacent_row < rows)
        exposed = outside or tiles[adjacent_row * columns + adjacent_column] == 'blocked'
        if asset_id == 'trailing_vine' and not exposed:
            raise RuntimeError('덩굴은 실제 외곽 벽에서만 내려와야 합니다.')
        if not removable and not outside and tiles[adjacent_row * columns + adjacent_column] in ('path', 'spawn', 'core'):
            raise RuntimeError(f'영구 장식의 선택 경계가 이동 경로입니다: {column},{row},{edge}')
        orientation = math.atan2(tangent.y, tangent.x) + math.radians(angle)
        if asset_id == 'trailing_vine':
            orientation += math.pi
        requested_scale = (scale,) * 3 if isinstance(scale, (float, int)) else scale
        transform = Matrix.Rotation(orientation, 4, 'Z') @ Matrix.Diagonal((*requested_scale, 1))
        transformed = [transform @ vertex.co for vertex in prototype['mesh'].vertices]
        base = center + tangent * along + normal * distance
        if asset_id in ('mossy_boulder', 'flat_stone'):
            base.z = -.014 if asset_id == 'mossy_boulder' else -.009
        clearance_fit = 1.0
        if removable:
            offset = base - center
            # 같은 실루엣의 균등 크기 조정으로 이동 경로와 타일 경계를 비움.
            for axis in (0, 1):
                low, high = min(point[axis] for point in transformed), max(point[axis] for point in transformed)
                if high > 0:
                    clearance_fit = min(clearance_fit, (.474 - offset[axis]) / high)
                if low < 0:
                    clearance_fit = min(clearance_fit, (-.474 - offset[axis]) / low)
            if clearance_fit <= 0:
                raise RuntimeError('타일 내부 배치 여유가 없습니다.')
            transform = transform @ Matrix.Diagonal((clearance_fit, clearance_fit, clearance_fit, 1))
        obj = bpy.data.objects.new(f'{len(placements):03}_{asset_id}_c{column}_r{row}', prototype['mesh'].copy())
        collection.objects.link(obj)
        obj.parent = root
        # 좌표·바람은 월드 축에서 동일하게 계산. 오브젝트 Transform은 원점 항등값 유지.
        normal_matrix = transform.to_3x3().inverted().transposed()
        for vertex in obj.data.vertices:
            vertex.co = base + transform @ vertex.co
        reference = obj.data.attributes['SourceFront']
        for item in reference.data:
            item.vector = (normal_matrix @ item.vector).normalized()
        obj.data.materials.clear()
        obj.data.materials.append(materials[prototype['group']])
        obj['dressingGroup'] = prototype['group']
        obj['plantFamily'] = asset_id
        obj['sourceAssetId'] = asset_id
        obj['sourceMasterSha256'] = prototype['record']['sourceSha256']
        obj['sourceMasterFile'] = prototype['record']['sourceFile']
        obj['sourceMasterScene'] = prototype['record']['sourceScene']
        obj['lodMethod'] = 'source-boundary sampling and existing-mesh solid decimation; see master-assembly-manifest.json'
        obj['tile'] = [column, row]
        obj['edge'] = edge
        obj['region'] = region
        obj['removableOnBuild'] = removable
        obj['sourceFrontChecked'] = True
        if asset_id == 'trailing_vine':
            obj['hangingAnchor'] = tuple(base)
            obj['wallOutward'] = tuple(normal)
            obj['wallFaceCoordinate'] = (center + normal * .5).dot(normal)
        phase = (len(placements) * 2.399963229728653) % math.tau
        wind = obj.data.uv_layers.new(name='Wind')
        occupancy = obj.data.uv_layers.new(name='Occupancy')
        for loop in obj.data.loops:
            weight = prototype['weights'][loop.vertex_index] if prototype['group'] == 'foliage' else 0
            wind.data[loop.index].uv = (weight, 1 - phase)
            occupancy.data[loop.index].uv = (slots[row * columns + column], 0 if removable else 1)
        obj.data.update()
        obj.data.calc_loop_triangles()
        if prototype['group'] == 'foliage':
            wind_preview(obj)
        placements.append({'name': obj.name, 'tile': [column, row], 'edge': edge, 'region': region,
                           'sourceAssetId': asset_id, 'sourceMasterFile': prototype['record']['sourceFile'],
                           'sourceMasterSha256': prototype['record']['sourceSha256'],
                           'sourceTriangles': prototype['record']['sourceTriangles'],
                           'lodTriangles': len(obj.data.loop_triangles), 'lodRatio': prototype['record']['lodRatio'],
                           'lodMethod': obj['lodMethod'], 'removableOnBuild': removable,
                           'translation': tuple(base), 'scale': tuple(value * clearance_fit for value in requested_scale),
                           'rotationZDegrees': math.degrees(orientation), 'uniformClearanceFit': clearance_fit,
                           'windPhase': phase, 'buildSlot': slots[row * columns + column]})

    # 여섯 권역은 높이·주종·빈 공간이 다름. 뒤의 돌과 안쪽 잎이 이어지는 군락.
    focal = ((3, 0, 'N'), (5, 1, 'E'), (7, 4, 'E'), (7, 7, 'E'), (0, 7, 'W'), (0, 9, 'W'))
    for index, (c, r, edge) in enumerate(focal):
        region = f'focal_{c}_{r}'
        if index in (0, 1, 3, 4):
            place('layered_fern', c, r, edge, (-.05, -.08, 0, .07, -.03, 0)[index], .08,
                  (.68, .66, .5, .60, .64, .5)[index], (18, -22, 0, 37, -13, 0)[index], True, region)
        if index != 3:
            place('broadleaf_herb', c, r, edge, (-.18, .21, -.06, 0, .20, -.06)[index], .16 if index in (0, 1, 4) else .04,
                  (.49, .48, .78, .5, .50, .80)[index], -17 + index * 19, True, region)
        if index in (0, 3, 4):
            place('arched_grass', c, r, edge, (.26, 0, 0, -.21, -.26, 0)[index], .50, .27,
                  11 + index * 29, False, region)
        else:
            place('arched_grass', c, r, edge, .20, .22, .50 if index != 5 else .56, -31 + index * 17, True, region)
        stone = 'flat_stone' if index in (2, 5) else 'mossy_boulder'
        stone_scales = ((.62, .54, .44), (.59, .56, .47), (.64, .57, .43),
                        (.58, .55, .43), (.64, .53, .46), (.59, .59, .48))
        place(stone, c, r, edge, .13 if index % 2 == 0 else -.16,
              (.515, .520, .508, .510, .514, .506)[index], stone_scales[index],
              (-7, 8, -6, -4, 7, 5)[index], False, region)
        place('creeping_moss', c, r, edge, -.19 if index % 2 == 0 else .18, .487,
              (.62, .45, .70), 3 if index % 2 else -5, False, region)
        if index in (1, 3, 5):
            place('creeping_groundcover', c, r, edge, -.16, .06, .44, 37 - index * 21, True, region)
        if index in (2, 4, 5):
            place('wildflower_clump', c, r, edge, .17, -.14, .84 if index == 4 else .76, 17 * index, True, region)
    # 벽 아래로 내려오는 덩굴은 실제 외곽 면 4곳에만 부착.
    for c, r, edge, along, scale in ((3, 0, 'N', -.08, .48), (7, 7, 'E', .05, .54),
                                    (0, 7, 'W', .07, .53), (0, 9, 'S', -.03, .47)):
        place('trailing_vine', c, r, edge, along, .505, scale, 0, False, 'outer_wall')
    for c, r, edge, along in ((3, 0, 'N', -.12), (5, 1, 'E', .12), (7, 7, 'E', -.09)):
        place('pebble_scatter', c, r, edge, along, .490, (.58, .32, .72), 0, False, 'stone_companion')
    for c, r, along in ((2, 0, -.17), (2, 3, .12), (2, 7, -.13)):
        place('exposed_root', c, r, 'E', along, .50, (.47, .16, .60), 0, False, 'selected_seam')
    # 모든 빈 칸을 채우지 않고 대표 군락 사이에 선택한 연결점만 둠. slot 0/16을 포함.
    connectors = (
        ('broadleaf_herb', 2, 0, 'N', .03, .09, .66, 28),
        ('arched_grass', 3, 5, 'W', .04, .10, .59, 48),
        ('creeping_groundcover', 3, 5, 'W', -.18, .16, .43, 19),
        ('arched_grass', 5, 2, 'N', -.07, .11, .53, -27),
        ('creeping_groundcover', 7, 5, 'E', -.03, .15, .57, 37),
        ('arched_grass', 0, 8, 'W', -.04, .12, .51, -16),
        ('broadleaf_herb', 2, 3, 'S', .05, .12, .58, 35),
        ('arched_grass', 2, 7, 'E', -.03, .12, .58, -37),
        ('creeping_groundcover', 5, 7, 'S', .02, .11, .55, 21),
    )
    for asset_id, c, r, edge, along, distance, scale, angle in connectors:
        place(asset_id, c, r, edge, along, distance, scale, angle, True)
    for asset_id, c, r, edge, along, scale in (
        ('arched_grass', 0, 1, 'W', -.09, .25),
        ('broadleaf_herb', 1, 3, 'S', .07, .24), ('arched_grass', 3, 8, 'E', -.10, .25),
        ('arched_grass', 6, 7, 'S', .17, .25),
    ):
        place(asset_id, c, r, edge, along, .51, scale, 8, False, 'sparse_rim')
    place('creeping_moss', 2, 3, 'E', -.19, .5, (.48, .42, .70), 0, False, 'low_seam')
    place('flat_stone', 2, 3, 'E', .17, .50, (.45, .46, .42), 0, False, 'selected_stone')
    triangle_count = sum(item['lodTriangles'] for item in placements)
    if triangle_count > 24000:
        raise RuntimeError(f'24,000 삼각형 예산 초과: {triangle_count}')
    # 저장 전 배치 검사. 정상 음수 Z 덩굴은 아래 별도 벽 부착 검사로 다룸.
    failures = []
    for obj in root.children:
        owner_c, owner_r = obj['tile']
        margin = .022 * max((item.uv.x for item in obj.data.uv_layers['Wind'].data), default=0) ** 2
        for vertex in obj.data.vertices:
            world = vertex.co
            if obj.get('sourceAssetId') == 'trailing_vine':
                normal = Vector(obj['wallOutward'])
                if world.dot(normal) < obj['wallFaceCoordinate'] - .025:
                    failures.append(f'벽 안쪽 덩굴: {obj.name}')
                    break
            if world.z <= .003:
                continue
            c, r = math.floor(world.x + 4), math.floor(5 - world.y)
            if 0 <= c < columns and 0 <= r < rows and tiles[r * columns + c] == 'build':
                local = world - Vector((c - 3.5, 4.5 - r, 0))
                removable = obj.get('removableOnBuild') and (c, r) == (owner_c, owner_r)
                if not removable and abs(local.x) < .35 + margin and abs(local.y) < .35 + margin:
                    failures.append(f'영구 건설 중앙 침범: {obj.name} → {c},{r}')
                    break
            if any(0 <= (cc := math.floor(world.x + dx + 4)) < columns and
                   0 <= (rr := math.floor(5 - world.y - dy)) < rows and
                   tiles[rr * columns + cc] in ('path', 'spawn', 'core')
                   for dx, dy in ((0, 0), (-margin, -margin), (-margin, margin), (margin, -margin), (margin, margin))):
                failures.append(f'이동 경로 침범: {obj.name}')
                break
    if failures:
        raise RuntimeError('\n'.join(failures))
    reference_collection = bpy.data.collections.new('00 Terrain - linked reference (not exported)')
    scene.collection.children.link(reference_collection)
    terrain_source = ROOT / 'design/stage1_3d/environment/terrain-approved.blend'
    with bpy.data.libraries.load(str(terrain_source), link=True) as (available, linked):
        linked.objects = [name for name in available.objects if name == 'stage1_environment' or name.startswith('stage1_static_')]
    for obj in linked.objects:
        reference_collection.objects.link(obj)
    scene.world = bpy.data.worlds.new('Stage1 Dressing Studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.09, .13, .15, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .40
    camera_data = bpy.data.cameras.new('Dressing Overview')
    camera = bpy.data.objects.new('Dressing Overview', camera_data)
    scene.collection.objects.link(camera)
    camera.location = (5, -13, 27)
    camera.rotation_euler = (-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.type, camera_data.ortho_scale = 'ORTHO', 16
    scene.camera = camera
    for name, position, power, size, tint in (
        ('Key', (-4, 2, 10), 1500, 7, (1, .92, .78)), ('Fill', (6, -3, 8), 1050, 6, (.70, .82, 1)),
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
    scene.render.resolution_x, scene.render.resolution_y = 1080, 1440
    scene.view_settings.view_transform = 'AgX'
    scene.frame_set(1)
    text = bpy.data.texts.new('README - Environment Dressing')
    text.write('독립 마스터 11종을 조립한 스테이지1 환경 장식\n\n10 Dressing에서 맵용 개별 메시를 편집합니다.\n마스터 원본은 별도 plant_library/companion_library에 보존하며 이 파일의 수정으로 변경되지 않습니다.\nassemble_master_dressing.py는 저장된 마스터를 다시 읽고 LOD·배치를 조립합니다. 의도적 재조립은 --rebuild이며 이전 조립 원본을 백업합니다.\n맵용 메시 직접 수정 뒤에는 export_dressing.py로 저장된 Basis를 내보냅니다.\nWind·Occupancy·Color·SourceFront 계약과 sourceAssetId를 보존하세요.\n단면 잎의 윗면 Z를 강제로 뒤집지 않습니다. SourceFront는 실제 원본 표면의 방향입니다.\n덩굴은 벽 위 걸침점을 고정하고 음수 Z로 내려갑니다. 지형은 연결 참조이며 출력하지 않습니다.\n')
    for library in bpy.data.libraries:
        library.filepath = bpy.path.relpath(library.filepath, start=str(HERE))
    for relative, before in source_hashes.items():
        assert hashlib.sha256((HERE / relative).read_bytes()).hexdigest() == before
    if not BACKUP.exists():
        BACKUP.mkdir()
        for name in ('environment-dressing.blend', 'build_dressing.py', 'export_dressing.py', 'verify_source.py',
                     'placement_manifest.json', 'export_manifest.json', 'source-verification.json', 'README.md'):
            if (HERE / name).exists():
                shutil.copy2(HERE / name, BACKUP / name)
        shutil.copy2(ROOT / 'assets/images/stage1_3d/environment/dressing.glb', BACKUP / 'dressing.glb')
    elif SOURCE.exists():
        from datetime import datetime
        shutil.copy2(SOURCE, BACKUP / ('assembly-before-rebuild-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.blend'))
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    summary = {'source': SOURCE.name, 'revision': REVISION, 'sourceConcept': root['sourceConcept'],
               'windMaximumDisplacement': .022, 'buildClearHalfWidth': .35,
               'foliageClusters': sum(obj['dressingGroup'] == 'foliage' for obj in root.children),
               'staticClusters': sum(obj['dressingGroup'] == 'rocks' for obj in root.children),
               'removableClusters': sum(bool(obj.get('removableOnBuild')) for obj in root.children),
               'totalTriangles': triangle_count, 'sourceMasterFiles': source_hashes,
               'sourceAssetCounts': dict(Counter(item['sourceAssetId'] for item in placements)), 'placements': placements}
    (HERE / 'placement_manifest.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    (HERE / 'master-assembly-manifest.json').write_text(json.dumps({'revision': REVISION,
        'sourceMasterFiles': source_hashes, 'mastersUnchanged': True, 'sources': source_records,
        'mapTriangleCount': triangle_count, 'mapInstanceCount': len(placements),
        'lodPolicy': 'retain whole plant and branch arrangement; sample existing boundary/crease; reduce tube cross sections and covered microleaves'},
        ensure_ascii=False, indent=2) + '\n')
    print('MASTER_DRESSING_READY', json.dumps({key: value for key, value in summary.items() if key != 'placements'}))


if __name__ == '__main__':
    main()
