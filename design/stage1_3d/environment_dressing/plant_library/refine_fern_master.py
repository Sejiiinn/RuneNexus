"""저장된 고사리 메시의 잔잎을 직접 보정. 다른 식물과 기존 잎축은 보존."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import struct

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'forest-plant-masters.blend'
BACKUP = HERE / 'forest-plant-masters.before-fern-refine.blend'
REVISION = 'slender-dense-pinnae-20260912'


def mesh_fingerprint(scene):
    digest = hashlib.sha256()
    for obj in sorted(scene.objects, key=lambda item: item.name):
        digest.update(obj.name.encode())
        if obj.type != 'MESH':
            continue
        for row in obj.matrix_world:
            digest.update(struct.pack('<4f', *row))
        for vertex in obj.data.vertices:
            digest.update(struct.pack('<3f', *vertex.co))
        for polygon in obj.data.polygons:
            digest.update(struct.pack('<' + 'I' * len(polygon.vertices), *polygon.vertices))
        for color in obj.data.color_attributes['Color'].data:
            digest.update(struct.pack('<4f', *color.color))
    return digest.hexdigest()


def rail_point(centers, t):
    """저장된 잎축 링 중심에서 복원한 부드러운 위치. 원본 잎축 메시는 수정하지 않음."""
    u = min(max(t, 0), 1) * (len(centers) - 1)
    i = min(int(u), len(centers) - 2)
    f = u - i
    a, b = centers[max(0, i - 1)], centers[i]
    c, d = centers[i + 1], centers[min(len(centers) - 1, i + 2)]
    return .5 * ((2 * b) + (-a + c) * f + (2 * a - 5 * b + 4 * c - d) * f * f
                 + (-a + 3 * b - 3 * c + d) * f ** 3)


def main():
    if not bpy.app.background or Path(bpy.data.filepath).resolve() != SOURCE:
        raise RuntimeError('저장된 forest-plant-masters.blend를 별도 background Blender로 먼저 열어야 합니다.')
    root = bpy.data.objects['layered_fern_root']
    if root.get('refinementRevision'):
        raise RuntimeError('이미 보정된 마스터입니다. 보정을 중복 적용하지 않습니다.')
    if BACKUP.exists():
        raise FileExistsError('보정 전 백업이 이미 있습니다. 기존 검수 기록을 덮어쓰지 않습니다.')
    preserved = {name: mesh_fingerprint(bpy.data.scenes[name]) for name in
                 ('01 Grass Master', '03 Broadleaf Master', '04 Groundcover Master')}
    collection = bpy.data.collections['02 Fern']
    original_positions = {
        obj.name: [vertex.co.copy() for vertex in obj.data.vertices]
        for obj in collection.objects if obj.type == 'MESH'
    }
    # 아래쪽은 짧게 시작하고 중간에서 넓어진 뒤 끝까지 연속해서 좁아지는 잎축 외곽.
    tiers = (.17, .235, .30, .365, .43, .495, .56, .625, .69, .755, .82, .885, .947)
    spread = (.54, .73, .89, 1.02, 1.05, 1.01, .90, .79, .66, .53, .39, .24, .08)
    for frond in range(1, 7):
        prefix = f'Fern.frond_{frond:02}'
        rachis = bpy.data.objects[prefix + '.rachis']
        rail = original_positions[rachis.name]
        centers = [sum(rail[i:i + 5], Vector()) / 5 for i in range(0, len(rail), 5)]
        # 추가할 세 쌍도 기존 잔잎의 실제 곡면·색상·편집 가능한 메시를 복사해 보정.
        for n in range(10, 13):
            for side_name in ('L', 'R'):
                template = bpy.data.objects[f'{prefix}.pinna_{n - 2:02}_{side_name}']
                duplicate = template.copy()
                duplicate.data = template.data.copy()
                duplicate.name = f'{prefix}.pinna_{n + 1:02}_{side_name}'
                collection.objects.link(duplicate)
        for n, t in enumerate(tiers):
            source_n = n if n < 10 else n - 3
            for side, side_name in ((-1, 'L'), (1, 'R')):
                obj = bpy.data.objects[f'{prefix}.pinna_{n + 1:02}_{side_name}']
                old_name = f'{prefix}.pinna_{source_n + 1:02}_{side_name}'
                positions = original_positions[old_name]
                # 잎 몸체 중심을 기준으로 길이·폭·말림 좌표를 분리한 직접 정점 변형.
                old_origin = sum(positions[:3], Vector()) / 3
                old_axis = positions[-1] - old_origin
                old_length = old_axis.length
                old_axis.normalize()
                old_across = Vector((0, 0, 1)).cross(old_axis).normalized()
                old_normal = old_axis.cross(old_across).normalized()
                old_width = max((p - old_origin).dot(old_across) for p in positions)
                old_width -= min((p - old_origin).dot(old_across) for p in positions)
                progress = t + (.008 if side > 0 else -.004)
                origin = rail_point(centers, progress)
                forward = (rail_point(centers, min(1, progress + .01))
                           - rail_point(centers, max(0, progress - .01))).normalized()
                across_rachis = Vector((0, 0, 1)).cross(forward).normalized() * side
                reach = .18 * spread[n] * (1 if frond in (1, 3, 6) else .90)
                reach *= (1 if side < 0 else .92 + .035 * ((n + frond) % 3))
                end = origin + across_rachis * reach + forward * reach * .34
                end.z -= reach * (.07 + .22 * progress)
                axis = end - origin
                length = axis.length
                axis.normalize()
                across_leaf = Vector((0, 0, 1)).cross(axis).normalized()
                normal = axis.cross(across_leaf).normalized()
                width_scale = reach * .205 / old_width
                length_scale = length / old_length
                curve_scale = math.sqrt(width_scale * length_scale)
                for vertex, position in zip(obj.data.vertices, positions):
                    delta = position - old_origin
                    along = delta.dot(old_axis)
                    u = min(max(along / old_length, 0), 1)
                    bend = (-.011 if (n + frond + side) % 4 == 0 else .003) * u ** 3
                    bend *= min(reach / .12, 1)
                    vertex.co = (origin + axis * along * length_scale
                                 + across_leaf * delta.dot(old_across) * width_scale
                                 + normal * (delta.dot(old_normal) * curve_scale + bend))
                obj.data.update()
                obj['refinementRevision'] = REVISION
    for name, before in preserved.items():
        if mesh_fingerprint(bpy.data.scenes[name]) != before:
            raise RuntimeError(f'보존 대상 메시가 달라졌습니다: {name}')
    manifest = json.loads((HERE / 'master_manifest.json').read_text())
    meshes = [obj for obj in collection.objects if obj.type == 'MESH']
    for obj in meshes:
        obj.data.calc_loop_triangles()
    entry = next(item for item in manifest['masters'] if item['plantAssetId'] == 'layered_fern')
    entry.update({
        'meshObjects': len(meshes),
        'triangles': sum(len(obj.data.loop_triangles) for obj in meshes),
        'leafObjects': sum(obj['partRole'] == 'leaf' for obj in meshes),
        'bounds': {
            'min': [min(vertex.co[i] for obj in meshes for vertex in obj.data.vertices) for i in range(3)],
            'max': [max(vertex.co[i] for obj in meshes for vertex in obj.data.vertices) for i in range(3)],
        },
    })
    root['refinementRevision'] = REVISION
    manifest['totalTriangles'] = sum(item['triangles'] for item in manifest['masters'])
    manifest['refinement'] = {
        'revision': REVISION,
        'scope': 'mature fern pinnae only; 13 slender pairs per frond',
        'method': 'direct saved-mesh vertex editing and 3 additional pairs copied from existing pinnae',
        'unchangedMasterFingerprints': preserved,
    }
    shutil.copy2(SOURCE, BACKUP)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    (HERE / 'master_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('FERN_MASTER_REFINED', json.dumps(manifest, ensure_ascii=False))


if __name__ == '__main__':
    main()
