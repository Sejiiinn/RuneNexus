"""저장된 고사리 잔잎의 폭만 보정. 잎축·길이·수·다른 식물 보존."""
from pathlib import Path
import json
import re
import shutil
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from refine_fern_master import mesh_fingerprint

SOURCE = HERE / 'forest-plant-masters.blend'
BACKUP = HERE / 'forest-plant-masters.before-fern-width.blend'
REVISION = 'fuller-pinna-width-20260912'
if not bpy.app.background or Path(bpy.data.filepath).resolve() != SOURCE:
    raise RuntimeError('별도 background Blender에서 저장된 식물 마스터를 먼저 여세요.')
root = bpy.data.objects['layered_fern_root']
if root.get('refinementRevision') != 'slender-dense-pinnae-20260912' or BACKUP.exists():
    raise RuntimeError('보정 기준이 다르거나 이미 보정했습니다. 중복 적용을 중단합니다.')
preserved = {name: mesh_fingerprint(bpy.data.scenes[name]) for name in
             ('01 Grass Master', '03 Broadleaf Master', '04 Groundcover Master')}
leaves = [obj for obj in bpy.data.collections['02 Fern'].objects
          if re.fullmatch(r'Fern\.frond_\d{2}\.pinna_\d{2}_[LR]', obj.name)]
assert len(leaves) == 156
for obj in leaves:
    vertices = obj.data.vertices
    assert (len(vertices) - 1) % 3 == 0
    # 잎 폭 방향만 확대. 밑동 첫 단면·중륵·끝점은 고정.
    for row in range(1, (len(vertices) - 1) // 3):
        left, center, right = vertices[row * 3:row * 3 + 3]
        across = (right.co - left.co).normalized()
        for vertex in (left, right):
            vertex.co += across * (vertex.co - center.co).dot(across) * .5
    obj.data.update()
    obj['refinementRevision'] = REVISION
for name, expected in preserved.items():
    assert mesh_fingerprint(bpy.data.scenes[name]) == expected, name
manifest = json.loads((HERE / 'master_manifest.json').read_text())
meshes = [obj for obj in bpy.data.collections['02 Fern'].objects if obj.type == 'MESH']
for obj in meshes:
    obj.data.calc_loop_triangles()
    assert all(triangle.area > 0 for triangle in obj.data.loop_triangles), obj.name
entry = next(item for item in manifest['masters'] if item['plantAssetId'] == 'layered_fern')
assert sum(len(obj.data.loop_triangles) for obj in meshes) == entry['triangles'] == 4326
entry['bounds'] = {
    'min': [min(v.co[i] for obj in meshes for v in obj.data.vertices) for i in range(3)],
    'max': [max(v.co[i] for obj in meshes for v in obj.data.vertices) for i in range(3)],
}
manifest['refinement'] = {
    'revision': REVISION, 'scope': 'mature fern pinna width only; 13 pairs retained',
    'method': '1.5x cross-section width; root, midrib, tip and length preserved',
    'unchangedMasterFingerprints': preserved,
}
shutil.copy2(SOURCE, BACKUP)
shutil.copy2(HERE / 'plant-masters-review.png', HERE / 'before-fern-width-review.png')
root['refinementRevision'] = REVISION
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
(HERE / 'master_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print('FERN_WIDTH_REFINED', len(leaves), 'leaves; unchanged triangles:', manifest['totalTriangles'])
