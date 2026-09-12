"""추가 환경 원본 7종과 기존 식물 비교칸의 Blender 정지 렌더. 원본 저장 없음."""
from pathlib import Path
import hashlib
import json

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
if not bpy.app.background:
    raise RuntimeError('편집 중인 장면 보호: 별도 background Blender에서 실행하세요.')
specs = [
    ('organic/organic-masters.blend', '01 Wildflower Master', '01  작은 흰 꽃', '가는 줄기 · 작은 꽃송이'),
    ('rocks/rock-masters.blend', '02 Mossy Boulder Master', '02  이끼 바위', '회색 노출 면 · 비대칭 이끼'),
    ('rocks/rock-masters.blend', '03 Flat Stone Master', '03  납작한 돌', '낮은 높이 · 넓은 깨진 면'),
    ('rocks/rock-masters.blend', '04 Pebbles Master', '04  작은 돌멩이', '크기와 방향이 다른 잔돌'),
    ('organic/organic-masters.blend', '05 Moss Patch Master', '05  낮게 퍼진 이끼', '불규칙한 가장자리 · 낮은 볼륨'),
    ('organic/organic-masters.blend', '06 Trailing Vine Master', '06  늘어진 덩굴', '가장자리 아래로 흐르는 잎'),
    ('organic/organic-masters.blend', '07 Exposed Root Master', '07  드러난 뿌리', '갈라지고 비틀린 짧은 뿌리'),
]
sources = {HERE / entry[0] for entry in specs}
sources.add(HERE.parent / 'plant_library/forest-plant-masters.blend')
hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
loaded = {}
for source in sources:
    with bpy.data.libraries.load(str(source), link=False) as (available, result):
        result.scenes = list(available.scenes)
    loaded[str(source)] = {scene.name: scene for scene in result.scenes}
view_rotation = (-Vector((5, -13, 27))).to_track_quat('-Z', 'Y').inverted().to_matrix().to_4x4()


def read_meshes(scene):
    bpy.context.window.scene = scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    meshes = []
    for obj in scene.objects:
        if obj.type != 'MESH':
            continue
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
        mesh.transform(view_rotation @ obj.matrix_world)
        mesh.calc_loop_triangles()
        meshes.append((obj.name, mesh))
    assert meshes, scene.name
    points = [v.co for _, mesh in meshes for v in mesh.vertices]
    center = Vector(((min(v.x for v in points) + max(v.x for v in points)) / 2,
                     (min(v.y for v in points) + max(v.y for v in points)) / 2, 0))
    for _, mesh in meshes:
        mesh.transform(Matrix.Translation(-center))
    return meshes


assets = []
for source, scene_name, title, subtitle in specs:
    meshes = read_meshes(loaded[str(HERE / source)][scene_name])
    assets.append({'source': source, 'scene': scene_name, 'title': title, 'subtitle': subtitle,
                   'meshes': meshes, 'triangles': sum(len(m.loop_triangles) for _, m in meshes)})
plant_source = str(HERE.parent / 'plant_library/forest-plant-masters.blend')
plants = [(label, read_meshes(loaded[plant_source][scene])) for label, scene in (
    ('풀', '01 Grass Master'), ('고사리', '02 Fern Master'),
    ('넓은 잎', '03 Broadleaf Master'), ('지피', '04 Groundcover Master'))]

scene = bpy.data.scenes.new('Companion assets — still review')
bpy.context.window.scene = scene
font = bpy.data.fonts.load('/System/Library/Fonts/Supplemental/AppleGothic.ttf')
ink = bpy.data.materials.new('Review lettering')
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


def place(meshes, x, y, scale=1):
    for name, mesh in meshes:
        obj = bpy.data.objects.new(name + ' / review', mesh)
        scene.collection.objects.link(obj)
        obj.location = (x, y, 0)
        obj.scale = (scale,) * 3


width, height, resolution = 6.8, 3.8, 3400
label('시안의 숲바닥 장식 · 추가 독립 에셋 7종', -3.19, 1.64, .145)
label('저장된 실제 Blender 메시 촬영  /  새 에셋은 동일 배율  /  게임·맵 적용 전 검수', -3.18, 1.46, .055)
for index, asset in enumerate(assets):
    row, col = divmod(index, 4)
    x, y = -2.55 + col * 1.7, .68 - row * 1.55
    label(asset['title'], x - .72, y + .55, .085)
    label(asset['subtitle'], x - .72, y + .43, .046)
    place(asset['meshes'], x, y - .03)
    place(asset['meshes'], x + .54, y - .57, 120 / (resolution / width))
    label(f"{asset['triangles']:,} 삼각형", x - .72, y - .59, .039)
    label('축소', x + .23, y - .59, .034)
x, y = 2.55, -.87
label('기존 식물 4종', x - .72, y + .55, .085)
label('색·형태를 함께 보는 축소 비교', x - .72, y + .43, .046)
for index, (name, meshes) in enumerate(plants):
    row, col = divmod(index, 2)
    px, py = x - .34 + col * .7, y + .12 - row * .47
    place(meshes, px, py, .40)
    label(name, px - .13, py - .23, .039)
label('큰 그림: 게임과 같은 카메라 방향의 확대 검수  ·  작은 그림: 1타일 = 120px  ·  기존 식물 칸: 별도 축소', -3.18, -1.68, .044)
label('Blender 제작 렌더이며 실제 게임 캡처가 아닙니다.', -3.18, -1.79, .044)
scene.world = bpy.data.worlds.new('Neutral review world')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.75, .76, .72, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .7
for name, direction, energy, color in (
    ('Warm key', (-4, -6, 10), 2.0, (1, .96, .88)),
    ('Cool fill', (6, 2, 8), .55, (.83, .91, 1)),
):
    light = bpy.data.lights.new(name, 'SUN')
    light.energy, light.angle, light.color = energy, .3, color
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.rotation_euler = (-(view_rotation.to_3x3() @ Vector(direction))).to_track_quat('-Z', 'Y').to_euler()
camera_data = bpy.data.cameras.new('Review camera')
camera = bpy.data.objects.new('Review camera', camera_data)
scene.collection.objects.link(camera)
camera.location = (0, 0, 20)
camera_data.type, camera_data.ortho_scale = 'ORTHO', width
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = resolution, round(resolution * height / width)
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.view_settings.view_transform, scene.view_settings.exposure = 'AgX', .3
scene.render.filepath = str(HERE / 'companion-masters-review.png')
bpy.ops.render.render(write_still=True)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest() == digest for p, digest in hashes.items())
(HERE / 'capture-verification.json').write_text(json.dumps({
    'source_hashes': hashes, 'source_unchanged': True, 'camera_direction': [5, -13, 27],
    'small_pixels_per_tile': 120, 'assets': [{k: v for k, v in a.items() if k != 'meshes'} for a in assets],
}, ensure_ascii=False, indent=2) + '\n')
print('COMPANION_CAPTURE_READY', scene.render.filepath)
