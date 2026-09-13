"""기존 A안 원본의 코어 결정만 길쭉한 단일 청록 유리로 보정."""
import bpy
import bmesh
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
if not bpy.app.background:
    raise RuntimeError('원본 보호를 위해 독립 Blender background 프로세스를 사용하세요.')
bpy.ops.wm.open_mainfile(filepath=str(HERE/'rune-landmarks.blend'))
bpy.context.window.scene = bpy.data.scenes['RuneLandmarks']
crystal = bpy.data.objects['core_crystal']

# 평면인 긴 다이아몬드 주면과 뾰족한 절단면. 중간 링의 반각 회전으로 면 경계 연결.
vertices = [(0, 0, -.42)]
radius = .13552
for z, ring_radius, offset in [(-.22, radius * math.cos(math.pi / 8), 0),
                              (0, radius, math.pi / 8),
                              (.19, radius * math.cos(math.pi / 8), 0)]:
    for index in range(8):
        angle = index * math.tau / 8 + .12 + offset
        vertices.append((ring_radius * math.cos(angle), ring_radius * math.sin(angle), z))
vertices.append((0, 0, .42))
faces = []
for index in range(8):
    following = (index + 1) % 8
    previous = (index - 1) % 8
    faces.extend([(0, 1 + following, 1 + index),
                  (1 + index, 1 + following, 9 + index),
                  (1 + index, 9 + index, 17 + index, 9 + previous),
                  (17 + index, 9 + index, 17 + following),
                  (25, 17 + index, 17 + following)])
cut = bpy.data.meshes.new('core_crystal_cut_geometry')
cut.from_pydata(vertices, [], faces)
cut.update()
old_mesh = crystal.data
crystal.data = cut
if old_mesh.users == 0:
    bpy.data.meshes.remove(old_mesh)
bm = bmesh.new()
bm.from_mesh(cut)
main_face = bm.faces.layers.int.new('main_facet')
for face in bm.faces:
    face[main_face] = 1
bevel = bmesh.ops.bevel(bm, geom=list(bm.edges), offset=.0025, segments=1, affect='EDGES')
for face in bevel['faces']:
    face[main_face] = 0
bm.to_mesh(cut)
bm.free()
# 모서리 가공 뒤에도 반복 실행 시 같은 치수·피벗 유지.
size = [max(v.co[i] for v in cut.vertices)-min(v.co[i] for v in cut.vertices) for i in range(3)]
for vertex in cut.vertices:
    for axis, target in enumerate((.27104, .27104, .84)):
        vertex.co[axis] *= target / size[axis]
crystal.location.z = .72
crystal['appearance'] = 'slender cut cyan crystal, beveled optical edges, no inner solid'

shell = bpy.data.materials['core_crystal_facets']
cut.materials.append(shell)
bsdf = shell.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Metallic'].default_value = 0.0
bsdf.inputs['Roughness'].default_value = .055
bsdf.inputs['IOR'].default_value = 1.46
bsdf.inputs['Alpha'].default_value = 1.0
bsdf.inputs['Transmission Weight'].default_value = .80
bsdf.inputs['Emission Color'].default_value = (.012,.27,.31,1)
bsdf.inputs['Emission Strength'].default_value = .12
shell.surface_render_method = 'BLENDED'
shell.use_backface_culling = True

# Blender 면색 보존. 게임에서는 정점색을 모서리 발광 표식으로 해석하지 않음.
colors = cut.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
for poly in cut.polygons:
    is_main = bool(cut.attributes['main_facet'].data[poly.index].value)
    strength = (.65 + (poly.index * 7 % 9) * .075) if is_main else 1.18
    for index in poly.loop_indices:
        colors.data[index].color = (.03*strength if is_main else 0, .5*strength, .58*strength, 1)

# 결정 안의 덩어리·불투명 선 제거. 단일 결정의 면과 재질만으로 깊이 표현.
for obj in list(crystal.children):
    if obj.name == 'core_heart' or obj.name.startswith('crystal_inclusion_'):
        bpy.data.objects.remove(obj, do_unlink=True)

# 베이스 디스크의 발광이 결정의 투명함을 흰 원으로 덮지 않도록 국소 보정.
socket = bpy.data.objects['socket_energy']
socket_material = bpy.data.materials.get('core_socket_glow') or bpy.data.materials['core_runes'].copy()
socket_material.name = 'core_socket_glow'
socket_material.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = .18
socket.data.materials.clear()
socket.data.materials.append(socket_material)

guide = bpy.data.texts['00_제작_안내']
body = guide.as_string().split('2026-09-12 결정 v2')[0].split('2026-09-12 결정 v3')[0].split('2026-09-12 결정 v4')[0].split('2026-09-12 결정 v5')[0].split('2026-09-12 결정 v6')[0].rstrip()
guide.clear()
guide.write(body + '\n2026-09-12 결정 v6: 폭 .27104/길이 .84, 피벗 Z=.72. 긴 다이아몬드 주면·좁은 bevel의 단일 청록 크리스탈.\n'
            'Blender는 Alpha=1, Transmission=.80, IOR=1.46. 정점색은 면색으로만 사용한다.\n'
            'Godot은 원본 재질 값과 공유 반사·화면 굴절을 사용한다. 파란 모서리 발광은 넣지 않는다.\n'
            '초기 생성기를 사용한 경우 refine_core_crystal.py를 거쳐 현행 형태를 복원한다.\n')
bpy.context.window.scene = bpy.data.scenes['02 Core Master']
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'rune-landmarks.blend'))
print('CORE_CRYSTAL_REFINED', {'width': .27104, 'height': .84, 'pivot_z': .72})
