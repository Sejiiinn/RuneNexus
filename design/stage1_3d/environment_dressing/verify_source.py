"""마스터 연결, 실제 표면 방향, 건설·이동 여유와 공유 바람 계약 검사."""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import math

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
scene = bpy.context.scene
root = bpy.data.objects['stage1_dressing']
tiles = list(root['tileTypes'])
columns, rows = root['columns'], root['rows']
slots = {index: slot for slot, index in enumerate(i for i, tile in enumerate(tiles) if tile == 'build')}
foliage = [obj for obj in root.children if obj.get('dressingGroup') == 'foliage']
assembly = json.loads((HERE / 'master-assembly-manifest.json').read_text())
placements = json.loads((HERE / 'placement_manifest.json').read_text())
placement_by_name = {item['name']: item for item in placements['placements']}
failures, source_hashes = [], {}
for relative, expected in assembly['sourceMasterFiles'].items():
    source_hashes[relative] = hashlib.sha256((HERE / relative).read_bytes()).hexdigest()
    if source_hashes[relative] != expected:
        failures.append(f'마스터가 조립 이후 변경됨: {relative}')
asset_ids = {item['assetId'] for item in assembly['sources']}
if {obj.get('sourceAssetId') for obj in root.children} != asset_ids or len(asset_ids) != 11:
    failures.append('11종 원본과 맵 인스턴스 연결 불일치')

down_facing_faces = triangle_count = closed_boundary_edges = front_mismatches = 0
surface_counts = defaultdict(int)
hanging, all_weights = [], []
phases, removable_slots = set(), set()
for obj in root.children:
    mesh = obj.data
    mesh.update()
    mesh.calc_loop_triangles()
    triangle_count += len(mesh.loop_triangles)
    placement = placement_by_name.get(obj.name)
    if not placement or obj.get('sourceMasterSha256') != source_hashes.get(obj.get('sourceMasterFile')):
        failures.append(f'원본 연결 정보 누락/불일치: {obj.name}')
    elif len(mesh.loop_triangles) != placement['lodTriangles']:
        failures.append(f'배치 triangle 기록 불일치: {obj.name}')
    if any(not math.isfinite(value) for vertex in mesh.vertices for value in vertex.co):
        failures.append(f'유효하지 않은 정점: {obj.name}')
    if any(triangle.area <= 1e-12 for triangle in mesh.loop_triangles):
        failures.append(f'퇴화 삼각형: {obj.name}')
    color = mesh.color_attributes.get('Color')
    if color is None or color.domain != 'POINT' or len(color.data) != len(mesh.vertices):
        failures.append(f'정점색 누락: {obj.name}')
    elif any(abs(item.color[3] - 1) > 1e-6 or any(not math.isfinite(c) or c < 0 or c > 1 for c in item.color) for item in color.data):
        failures.append(f'유효하지 않은 불투명 정점색: {obj.name}')
    reference, roles = mesh.attributes.get('SourceFront'), mesh.attributes.get('SourceSurfaceRole')
    if reference is None or roles is None:
        failures.append(f'원본 표면 방향/역할 누락: {obj.name}')
        continue
    edges = defaultdict(list)
    for polygon in mesh.polygons:
        role = roles.data[polygon.index].value
        surface_counts[{1: 'leaf', 2: 'petal', 3: 'closed_solid'}[role]] += 1
        if obj.get('dressingGroup') == 'foliage' and polygon.normal.z < -.0001:
            down_facing_faces += 1
        # 원본 앞면과 비교. 곡면 잎·꽃·덩굴은 아래쪽을 향할 수도 있음.
        if role in (1, 2) and polygon.normal.dot(reference.data[polygon.index].vector) < -.05:
            front_mismatches += 1
        indices = list(polygon.vertices)
        for a, b in zip(indices, indices[1:] + indices[:1]):
            edges[tuple(sorted((a, b)))].append((1 if a < b else -1, role))
    if any(len(entries) == 2 and entries[0][0] == entries[1][0] for entries in edges.values()):
        failures.append(f'인접 면의 winding 불일치: {obj.name}')
    boundary_count = sum(len(entries) != 2 for entries in edges.values() if all(role == 3 for _, role in entries))
    closed_boundary_edges += boundary_count
    if boundary_count:
        failures.append(f'닫힌 줄기/돌 표면의 열린 경계: {obj.name}: {boundary_count}')
    wind, occupancy = mesh.uv_layers.get('Wind'), mesh.uv_layers.get('Occupancy')
    if wind is None or occupancy is None or mesh.uv_layers[0].name != 'Wind':
        failures.append(f'Wind/Occupancy UV 계약 누락: {obj.name}')
        continue
    weights = {}
    owner_column, owner_row = obj['tile']
    slot = slots[owner_row * columns + owner_column]
    removable = bool(obj.get('removableOnBuild'))
    if removable:
        removable_slots.add(slot)
    for loop in mesh.loops:
        uv, removal = wind.data[loop.index].uv, occupancy.data[loop.index].uv
        if not 0 <= uv.x <= 1 or not -.00001 <= 1 - uv.y <= math.tau + .00001:
            failures.append(f'바람 UV 범위: {obj.name}')
            break
        if abs(removal.x - slot) > .00001 or abs(removal.y - (0 if removable else 1)) > .00001:
            failures.append(f'제거 슬롯/flag 불일치: {obj.name}')
            break
        weights[loop.vertex_index] = uv.x
        if obj.get('dressingGroup') == 'foliage':
            all_weights.append(uv.x)
            phases.add(round(1 - uv.y, 4))
    margin = .022 * max(weights.values(), default=0) ** 2
    if obj.get('sourceAssetId') == 'trailing_vine':
        normal, anchor = Vector(obj['wallOutward']), Vector(obj['hangingAnchor'])
        neighbor_c, neighbor_r = owner_column + int(normal.x), owner_row - int(normal.y)
        exposed = not (0 <= neighbor_c < columns and 0 <= neighbor_r < rows) or tiles[neighbor_r * columns + neighbor_c] == 'blocked'
        distances = [vertex.co.dot(normal) - obj['wallFaceCoordinate'] for vertex in mesh.vertices]
        fixed = [vertex.co for index, vertex in enumerate(mesh.vertices) if weights.get(index, 0) == 0]
        downward = anchor.z - min(vertex.co.z for vertex in mesh.vertices)
        # 음수 Z도 검사: 벽 안쪽 침범, 떨어진 걸침점, 아래로 내려오지 않는 배치 방지.
        if not exposed or min(distances) < -.025 or not fixed or min((point - anchor).length for point in fixed) > .045 or downward < .20:
            failures.append(f'늘어진 덩굴의 외곽 벽 부착 불일치: {obj.name}')
        hanging.append({'name': obj.name, 'downwardExtent': downward, 'wallDistanceRange': [min(distances), max(distances)],
                        'fixedAnchorVertices': len(fixed), 'exposedFace': exposed})
    for index, vertex in enumerate(mesh.vertices):
        world = obj.matrix_world @ vertex.co
        c, r = math.floor(world.x + columns / 2), math.floor(rows / 2 - world.y)
        if removable and weights.get(index, 0) == 0 and (c, r) != (owner_column, owner_row):
            failures.append(f'제거 식생의 고정점이 다른 칸에 있음: {obj.name}')
            break
        if world.z <= .003:
            continue
        if 0 <= c < columns and 0 <= r < rows and tiles[r * columns + c] == 'build':
            local = world - Vector((c - 3.5, 4.5 - r, 0))
            own_removable = removable and (c, r) == (owner_column, owner_row)
            if not own_removable and abs(local.x) < .35 + margin and abs(local.y) < .35 + margin:
                failures.append(f'건설칸 중앙 침범: {obj.name} → {c},{r}')
                break
        crossed = False
        for dx, dy in ((0, 0), (-margin * .92, -margin * .39), (margin * .92, margin * .39),
                       (-margin * .92, margin * .39), (margin * .92, -margin * .39)):
            c, r = math.floor(world.x + dx + 4), math.floor(5 - world.y - dy)
            if 0 <= c < columns and 0 <= r < rows and tiles[r * columns + c] in ('path', 'spawn', 'core'):
                crossed = True
                break
        if crossed:
            failures.append(f'이동 경로와 바람 여유 침범: {obj.name}')
            break
if front_mismatches:
    failures.append(f'원본 단면 앞면 방향 불일치: {front_mismatches}')
if not all_weights or min(all_weights) != 0 or max(all_weights) != 1 or len(phases) < 8:
    failures.append('바람 가중치 0/1 또는 위상 다양성 누락')
if not {0, 16}.issubset(removable_slots):
    failures.append('slot 0/16 중앙 식생 회귀 검사 대상 누락')
maximum_shift = maximum_root_shift = 0.0
for frame in (1, 20, 40, 70, 110, 160, 210):
    scene.frame_set(frame)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in foliage:
        evaluated = obj.evaluated_get(depsgraph).data
        weights = {loop.vertex_index: obj.data.uv_layers['Wind'].data[loop.index].uv.x for loop in obj.data.loops}
        for index, (actual, basis) in enumerate(zip(evaluated.vertices, obj.data.vertices)):
            shift = (actual.co - basis.co).length
            maximum_shift = max(maximum_shift, shift)
            if abs(weights[index]) < .00001:
                maximum_root_shift = max(maximum_root_shift, shift)
if maximum_shift > .02201 or maximum_shift < .005:
    failures.append(f'바람 변위 범위 오류: {maximum_shift}')
if maximum_root_shift > .00001:
    failures.append(f'고정 뿌리/걸침점 이동: {maximum_root_shift}')
scene.frame_set(1)
result = {'failures': failures, 'revision': root['artDirectionRevision'], 'masterAssetCount': len(asset_ids),
          'masterSourcesUnchanged': not any('마스터가 조립 이후 변경됨' in error for error in failures),
          'sourceMasterHashes': source_hashes, 'mapTriangles': triangle_count, 'foliageClusters': len(foliage),
          'removableCenterClusters': sum(bool(obj.get('removableOnBuild')) for obj in foliage),
          'sampledFrames': 7, 'maximumShift': maximum_shift, 'maximumRootShift': maximum_root_shift,
          'buildClearHalfWidth': .35, 'windEnvelope': .022, 'surfaceRoleFaceCounts': dict(surface_counts),
          'sourceFrontMismatches': front_mismatches, 'closedSolidBoundaryEdges': closed_boundary_edges,
          'downFacingFoliageFaces': down_facing_faces, 'downFacingFoliageFacesAreDiagnostic': True,
          'hangingVines': hanging, 'neighborBuildTilesChecked': True, 'removableNeighborBuildClearanceChecked': True,
          'pathWindEnvelopeChecked': True, 'removableSlots': sorted(removable_slots), 'windPhases': len(phases)}
(HERE / 'source-verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print('SOURCE_VERIFICATION', json.dumps(result, ensure_ascii=False))
assert not failures, failures
