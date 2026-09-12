"""저장된 이끼 메시의 높이·덩어리 간격·작은 잎 분포를 직접 보정."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import struct

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'organic-masters.blend'
BACKUP = HERE / 'organic-masters.before-moss-refine.blend'
REVISION = 'low-woven-moss-20260912'


def fingerprint(scene):
    digest = hashlib.sha256()
    for obj in sorted(scene.objects, key=lambda value: value.name):
        digest.update(obj.name.encode())
        if obj.type != 'MESH':
            continue
        for row in obj.matrix_world:
            digest.update(struct.pack('<4f', *row))
        for vertex in obj.data.vertices:
            digest.update(struct.pack('<3f', *vertex.co))
        for polygon in obj.data.polygons:
            digest.update(struct.pack('<' + 'I' * len(polygon.vertices), *polygon.vertices))
        for datum in obj.data.color_attributes['Color'].data:
            digest.update(struct.pack('<4f', *datum.color))
    return digest.hexdigest()


def inside_polygon(x, y, polygon):
    inside = False
    for i, point in enumerate(polygon):
        previous = polygon[i - 1]
        if (point.y > y) != (previous.y > y):
            cross = (previous.x - point.x) * (y - point.y) / (previous.y - point.y) + point.x
            if x < cross:
                inside = not inside
    return inside


def main():
    if not bpy.app.background or Path(bpy.data.filepath).resolve() != SOURCE:
        raise RuntimeError('저장된 organic-masters.blend를 background Blender로 먼저 열어야 합니다.')
    root = bpy.data.objects['creeping_moss_root']
    if root.get('refinementRevision') or BACKUP.exists():
        raise RuntimeError('이미 보정되었거나 백업이 있습니다. 보정을 중복 적용하지 않습니다.')
    preserved = {name: fingerprint(bpy.data.scenes[name]) for name in
                 ('01 Wildflower Master', '06 Trailing Vine Master', '07 Exposed Root Master')}
    collection = bpy.data.collections['05 Moss Patch']
    old_centers = ((-.19, -.07), (.12, .10), (.23, -.155), (-.20, .205), (-.035, -.265), (.324, .237))
    new_centers = ((-.105, -.038), (.080, .046), (.100, -.118), (-.142, .088), (-.030, -.152), (.195, .128))
    counts = (72, 66, 32, 32, 24, 24)
    for island in range(1, 7):
        prefix = f'Moss.island_{island:02}'
        support = bpy.data.objects[prefix + '.woven_base']
        old_center = Vector((*old_centers[island - 1], 0))
        new_center = Vector((*new_centers[island - 1], 0))
        ring_count = (len(support.data.vertices) - 1) // 3
        original_height = max(vertex.co.z for vertex in support.data.vertices)
        for index, vertex in enumerate(support.data.vertices):
            ring = index // ring_count
            relative = vertex.co - old_center
            vertex.co.x = new_center.x + relative.x * .88
            vertex.co.y = new_center.y + relative.y * .88
            if ring == 0:
                vertex.co.z = .0008
            elif ring == 1:
                vertex.co.z = .0017 + .00045 * math.sin(index * 2.1 + island)
            else:
                vertex.co.z *= .31 * (1 + .12 * math.sin(index * 2.4 + island))
        for datum in support.data.color_attributes['Color'].data:
            color = datum.color
            datum.color = (color[0] * .76, color[1] * .78, color[2] * .75, 1)
        support.data.update()
        outline = [vertex.co.copy() for vertex in support.data.vertices[:ring_count]]
        templates = sorted([obj for obj in collection.objects if obj.name.startswith(prefix + '.tuft_')], key=lambda obj: obj.name)
        positions = [[vertex.co.copy() for vertex in obj.data.vertices] for obj in templates]
        # 덩어리 중앙의 큰 싹을 제거하고, 외곽까지 작은 잎이 고르게 이어지는 분포.
        left, right = min(point.x for point in outline), max(point.x for point in outline)
        bottom, top = min(point.y for point in outline), max(point.y for point in outline)
        anchors = []
        candidate = 1
        while len(anchors) < counts[island - 1]:
            u = (candidate * .61803398875 + island * .117) % 1
            v = (candidate * .75487766625 + island * .091) % 1
            x, y = left + (right - left) * u, bottom + (top - bottom) * v
            candidate += 1
            if inside_polygon(x, y, outline):
                anchors.append((x, y))
        for number, (x, y) in enumerate(anchors):
            template_index = number % len(templates)
            if number < len(templates):
                obj = templates[number]
            else:
                obj = templates[template_index].copy()
                obj.data = templates[template_index].data.copy()
                obj.name = f'{prefix}.woven_leaf_{number + 1:03}'
                collection.objects.link(obj)
            old_positions = positions[template_index]
            old_base = sum(old_positions[:3], Vector()) / 3
            # 이끼섬 실제 윗면 높이에 맞춘 부착점. 외곽의 얇은 부분도 덮임 유지.
            distances = [((point.x - x) ** 2 + (point.y - y) ** 2, point.z)
                         for point in [vertex.co for vertex in support.data.vertices[ring_count:]]]
            nearest = sorted(distances)[:3]
            weight_sum = sum(1 / max(distance, 1e-6) for distance, _ in nearest)
            height = sum(z / max(distance, 1e-6) for distance, z in nearest) / weight_sum
            base = Vector((x, y, height + .0007))
            angle = number * 2.3999632297 + island * .48
            cosine, sine = math.cos(angle), math.sin(angle)
            xy_scale = .61 + .05 * ((number + island) % 3)
            for vertex, position in zip(obj.data.vertices, old_positions):
                delta = position - old_base
                vertex.co = base + Vector(((delta.x * cosine - delta.y * sine) * xy_scale,
                                           (delta.x * sine + delta.y * cosine) * xy_scale,
                                           delta.z * .40))
            obj.data.update()
            obj['refinementRevision'] = REVISION
    for name, before in preserved.items():
        if fingerprint(bpy.data.scenes[name]) != before:
            raise RuntimeError(f'보존할 원본이 달라졌습니다: {name}')
    meshes = [obj for obj in collection.objects if obj.type == 'MESH']
    for obj in meshes:
        obj.data.calc_loop_triangles()
        assert all(math.isfinite(value) for vertex in obj.data.vertices for value in vertex.co)
        assert all(triangle.area > 1e-12 for triangle in obj.data.loop_triangles)
    manifest = json.loads((HERE / 'organic_manifest.json').read_text())
    entry = next(item for item in manifest['masters'] if item['assetId'] == 'creeping_moss')
    entry.update({'meshObjects': len(meshes), 'triangles': sum(len(obj.data.loop_triangles) for obj in meshes),
                  'parts': {'leaf': sum(obj['partRole'] == 'leaf' for obj in meshes), 'moss_support': 6},
                  'bounds': {'min': [min(vertex.co[i] for obj in meshes for vertex in obj.data.vertices) for i in range(3)],
                             'max': [max(vertex.co[i] for obj in meshes for vertex in obj.data.vertices) for i in range(3)]}})
    manifest['totalTriangles'] = sum(item['triangles'] for item in manifest['masters'])
    manifest['refinement'] = {'revision': REVISION, 'scope': 'moss only',
                              'method': 'direct saved mesh height/position editing and copies of existing small leaves',
                              'unchangedMasterFingerprints': preserved}
    root['refinementRevision'] = REVISION
    shutil.copy2(SOURCE, BACKUP)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    (HERE / 'organic_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('MOSS_MASTER_REFINED', json.dumps(manifest, ensure_ascii=False))


if __name__ == '__main__':
    main()
