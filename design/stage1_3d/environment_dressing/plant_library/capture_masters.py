"""저장된 네 식물 마스터를 읽어 정지 검수 이미지 생성. 원본 저장·재생성 없음."""
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


HERE = Path(__file__).resolve().parent
SOURCE = HERE / "forest-plant-masters.blend"
if not bpy.app.background or Path(bpy.data.filepath).resolve() != SOURCE.resolve():
    raise RuntimeError("별도 background Blender에서 forest-plant-masters.blend를 먼저 여세요.")
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
specs = [
    ("01 Grass Master", "arched_grass", "01  휘어진 풀 포기", "가는 잎 · 높낮이와 방향의 변화"),
    ("02 Fern Master", "layered_fern", "02  다층 고사리", "휘어진 중심 줄기 · 겹치는 잎층"),
    ("03 Broadleaf Master", "broadleaf_herb", "03  넓은 잎 식물", "줄기와 잎자루 · 접히고 비틀린 잎"),
    ("04 Groundcover Master", "creeping_groundcover", "04  낮은 지피", "옆으로 뻗는 줄기 · 낮은 잎의 연결"),
]
view_rotation = (-Vector((5, -13, 27))).to_track_quat('-Z', 'Y').inverted().to_matrix().to_4x4()
assets = []
for scene_name, asset_id, title, description in specs:
    source_scene = bpy.data.scenes[scene_name]
    bpy.context.window.scene = source_scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    meshes = []
    triangles = 0
    for obj in source_scene.objects:
        if obj.type != 'MESH':
            continue
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
        mesh.transform(obj.matrix_world)
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        meshes.append((obj.name, mesh))
    assert meshes, asset_id
    points = [v.co.copy() for _, mesh in meshes for v in mesh.vertices]
    lower = Vector(tuple(min(v[i] for v in points) for i in range(3)))
    upper = Vector(tuple(max(v[i] for v in points) for i in range(3)))
    for _, mesh in meshes:
        mesh.transform(view_rotation)
    projected = [v.co.copy() for _, mesh in meshes for v in mesh.vertices]
    center = Vector(((min(v.x for v in projected) + max(v.x for v in projected)) / 2,
                     (min(v.y for v in projected) + max(v.y for v in projected)) / 2, 0))
    for _, mesh in meshes:
        mesh.transform(Matrix.Translation(-center))
    assets.append({"id": asset_id, "title": title, "description": description,
                   "meshes": meshes, "triangles": triangles, "dimensions": list(upper - lower)})

scene = bpy.data.scenes.new("Plant masters — static review")
bpy.context.window.scene = scene
font = bpy.data.fonts.load('/System/Library/Fonts/Supplemental/AppleGothic.ttf')
ink = bpy.data.materials.new("Review lettering")
ink.use_nodes = True
nodes = ink.node_tree.nodes
nodes.clear()
emission = nodes.new('ShaderNodeEmission')
emission.inputs['Color'].default_value = (.025, .035, .030, 1)
output = nodes.new('ShaderNodeOutputMaterial')
ink.node_tree.links.new(emission.outputs[0], output.inputs[0])


def label(body, x, y, size):
    curve = bpy.data.curves.new(body, 'FONT')
    curve.body, curve.font, curve.size = body, font, size
    curve.materials.append(ink)
    obj = bpy.data.objects.new(body, curve)
    scene.collection.objects.link(obj)
    obj.location = (x, y, 3)


width, height = 3.6, 3.52
pixels_per_tile = 2400 / width
label("숲바닥 식물 · 독립 에셋 4종", -1.65, 1.53, .135)
label("Blender 원본 정지 렌더  /  모든 큰 그림 동일 배율  /  맵 적용 전 형태 검수", -1.64, 1.38, .052)
for index, asset in enumerate(assets):
    row, col = divmod(index, 2)
    x, y = -.88 + col * 1.78, .63 - row * 1.41
    label(asset["title"], x - .75, y + .54, .079)
    label(asset["description"], x - .75, y + .43, .043)
    for name, mesh in asset["meshes"]:
        obj = bpy.data.objects.new(name + " / large", mesh)
        scene.collection.objects.link(obj)
        obj.location = (x, y -.04, 0)
        # 작은 검수상은 같은 메시를 공유하며 1타일=120px 배율 적용.
        small = bpy.data.objects.new(name + " / small", mesh)
        scene.collection.objects.link(small)
        small.scale = (120 / pixels_per_tile,) * 3
        small.location = (x + .54, y - .56, .1)
    label(f"{asset['triangles']:,} 삼각형", x - .75, y - .56, .044)
    label("축소", x + .19, y - .58, .035)
label("큰 그림: 게임과 같은 카메라 방향의 확대 검수  ·  작은 그림: 1타일 = 120px", -1.64, -1.55, .047)
label("실제 식물 메시 촬영이며 게임 화면 캡처는 아닙니다.", -1.64, -1.65, .043)

scene.world = bpy.data.worlds.new("Neutral plant review")
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.75, .76, .72, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .7
for name, direction, energy, color in (
    ("Soft warm key", (-4, -6, 10), 2.0, (1, .96, .88)),
    ("Soft cool fill", (6, 2, 8), .55, (.83, .91, 1)),
):
    light = bpy.data.lights.new(name, 'SUN')
    light.energy, light.angle, light.color = energy, .3, color
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.rotation_euler = (-(view_rotation.to_3x3() @ Vector(direction))).to_track_quat('-Z', 'Y').to_euler()
camera_data = bpy.data.cameras.new("Review orthographic")
camera = bpy.data.objects.new("Review orthographic", camera_data)
scene.collection.objects.link(camera)
camera.location = (0, 0, 20)
camera_data.type, camera_data.ortho_scale = 'ORTHO', width
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = 2400
scene.render.resolution_y = round(2400 * height / width)
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.view_settings.view_transform = 'AgX'
scene.view_settings.exposure = .3
scene.render.filepath = str(HERE / 'plant-masters-review.png')
bpy.ops.render.render(write_still=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash, "원본 변경 감지"
(HERE / 'capture-verification.json').write_text(json.dumps({
    "source": SOURCE.name, "source_sha256": source_hash,
    "image": "plant-masters-review.png", "source_unchanged": True,
    "camera_direction": [5, -13, 27], "small_pixels_per_tile": 120,
    "assets": [{k: v for k, v in asset.items() if k != "meshes"} for asset in assets],
}, ensure_ascii=False, indent=2) + '\n')
print("PLANT_MASTERS_CAPTURE", scene.render.filepath)
