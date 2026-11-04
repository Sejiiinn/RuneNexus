"""실제 Blender 원본의 건설·이동 여유와 바람 변위 검사."""
from pathlib import Path
import json
import math

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
scene = bpy.context.scene
root = bpy.data.objects["stage1_dressing"]
tiles = list(root["tileTypes"])
foliage = [obj for obj in root.children if obj.get("dressingGroup") == "foliage"]
failures = []
down_facing_faces = sum(polygon.normal.z < -.0001 for obj in foliage for polygon in obj.data.polygons)
if down_facing_faces:
    failures.append(f"잎 윗면 법선 뒤집힘: {down_facing_faces}")
for obj in root.children:
    owner_column, owner_row = obj["tile"]
    margin = .022 if obj.get("dressingGroup") == "foliage" else 0
    for vertex in obj.data.vertices:
        world = obj.matrix_world @ vertex.co
        c, r = math.floor(world.x + 4), math.floor(5 - world.y)
        # 옆 타일로 퍼진 잎도 그 타일의 설치 여유를 검사.
        if world.z > .003 and 0 <= c < 8 and 0 <= r < 10 and tiles[r * 8 + c] == "build":
            local = world - Vector((c - 3.5, 4.5 - r, 0))
            own_removable = obj.get("removableOnBuild", False) and c == owner_column and r == owner_row
            if not own_removable and abs(local.x) < .35 + margin and abs(local.y) < .35 + margin:
                failures.append(f"건설칸 중앙 침범: {obj.name} → {c},{r}")
                break
        if world.z <= .003:
            continue
        # 공유 바람의 최대 x/y 변위까지 경로·포털·코어 여유 확인.
        crossed = False
        for dx, dy in ((0, 0), (-margin * .92, -margin * .39), (margin * .92, margin * .39),
                       (-margin * .92, margin * .39), (margin * .92, -margin * .39)):
            c, r = math.floor(world.x + dx + 4), math.floor(5 - world.y - dy)
            if 0 <= c < 8 and 0 <= r < 10 and tiles[r * 8 + c] in ("path", "spawn", "core"):
                crossed = True
                break
        if crossed:
            failures.append(f"이동 경로와 바람 여유 침범: {obj.name}")
            break

maximum_shift = 0.0
maximum_root_shift = 0.0
for frame in (1, 20, 40, 70, 110, 160, 210):
    scene.frame_set(frame)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in foliage:
        evaluated = obj.evaluated_get(depsgraph).data
        weights = {}
        for loop in obj.data.loops:
            weights[loop.vertex_index] = obj.data.uv_layers[0].data[loop.index].uv.x
        for index, (actual, basis) in enumerate(zip(evaluated.vertices, obj.data.vertices)):
            shift = (actual.co - basis.co).length
            maximum_shift = max(maximum_shift, shift)
            if abs(weights[index]) < .00001:
                maximum_root_shift = max(maximum_root_shift, shift)
if maximum_shift > .02201 or maximum_shift < .005:
    failures.append(f"바람 변위 범위 오류: {maximum_shift}")
if maximum_root_shift > .00001:
    failures.append(f"고정 뿌리 이동: {maximum_root_shift}")
scene.frame_set(1)
result = {"failures": failures, "foliageClusters": len(foliage),
          "removableCenterClusters": sum(bool(obj.get("removableOnBuild")) for obj in foliage), "sampledFrames": 7,
          "maximumShift": maximum_shift, "maximumRootShift": maximum_root_shift,
          "buildClearHalfWidth": .35, "windEnvelope": .022,
          "downFacingFoliageFaces": down_facing_faces,
          "neighborBuildTilesChecked": True, "removableNeighborBuildClearanceChecked": True,
          "pathWindEnvelopeChecked": True}
(HERE / "source-verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print("SOURCE_VERIFICATION", json.dumps(result, ensure_ascii=False))
assert not failures, failures
