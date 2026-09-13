"""A안 공용 랜드마크 원본 제작. Blender --background --factory-startup 전용."""
import bpy
import json
import math
from pathlib import Path
import random
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ASSET = ROOT / 'assets/images/stage1_3d/environment/landmarks.glb'
if not bpy.app.background:
    raise RuntimeError('열린 편집 원본 보존을 위해 독립 background 프로세스로 실행하세요.')
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'RuneLandmarks'
rng = random.Random(120926)


def linear(hex_color):
    values = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in values)


def material(name, color, roughness, metallic=0, emission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    pbr = nodes.get('Principled BSDF')
    pbr.inputs['Base Color'].default_value = (*linear(color), 1)
    pbr.inputs['Roughness'].default_value = roughness
    pbr.inputs['Metallic'].default_value = metallic
    tint = nodes.new('ShaderNodeVertexColor')
    tint.layer_name = 'Color'
    mat.node_tree.links.new(tint.outputs['Color'], pbr.inputs['Base Color'])
    if emission:
        # glTF 발광은 정점색을 지원하지 않으므로 고정된 유색 발광으로 내보내기.
        pbr.inputs['Emission Color'].default_value = (*linear(color), 1)
        pbr.inputs['Emission Strength'].default_value = emission
    mat['palette'] = color
    return mat


stone = material('landmark_stone', '686D68', .87)
iron = material('landmark_iron', '354B4F', .56, .52)
brass = material('landmark_brass', 'AF864A', .47, .65)
teal = material('core_runes', '38C7BE', .35, .15, .55)
crystal_mat = material('core_crystal_facets', '38CECE', .27, .1, .26)
energy = material('portal_energy', '6D24A9', .35, .05, .035)


# 기존 석재의 노멀맵 재사용. 지면 색이나 이끼를 모델에 고정하지 않음.
stone_nodes = stone.node_tree.nodes
normal_image = stone_nodes.new('ShaderNodeTexImage')
normal_image.image = bpy.data.images.load(str(ROOT / 'design/stage1_3d/environment/textures/weathered_stone_normal.png'))
normal_image.image.colorspace_settings.name = 'Non-Color'
normal_map = stone_nodes.new('ShaderNodeNormalMap')
normal_map.inputs['Strength'].default_value = .65
stone.node_tree.links.new(normal_image.outputs['Color'], normal_map.inputs['Color'])
stone.node_tree.links.new(normal_map.outputs['Normal'], stone_nodes.get('Principled BSDF').inputs['Normal'])


def parent(name):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj['tileSize'] = 1.0
    obj['groundPlane'] = 0.0
    obj['includesTerrain'] = False
    return obj


def finish(obj, name, mat, root, bevel=0, variation=.12):
    obj.name = name
    obj.parent = root
    obj.data.materials.append(mat)
    if mat == stone:
        # 동일 좌표를 함께 움직여 연결면의 틈 없이 작은 석재 마모 형성.
        for vertex in obj.data.vertices:
            co = vertex.co
            co += Vector((math.sin(co.y*93+co.z*37), math.sin(co.x*89+co.z*73), math.sin(co.x*97+co.y*47))) * .0018
            if obj.location.z + co.z < 0:
                co.z = -obj.location.z
    if bevel:
        mod = obj.modifiers.new('면 모서리 마모', 'BEVEL')
        mod.width, mod.segments = bevel, 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # 면 방향에 따른 로컬 UV; 타일 월드 위치와 무관한 표면 무늬.
    uv = obj.data.uv_layers.new(name='UVMap')
    for poly in obj.data.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        for index in poly.loop_indices:
            co = obj.data.vertices[obj.data.loops[index].vertex_index].co
            uv.data[index].uv = ((co.x*4, co.y*4) if axis == 2 else ((co.x*4, co.z*4) if axis == 1 else (co.y*4, co.z*4)))
    colors = obj.data.color_attributes.new(name='Color', type='BYTE_COLOR', domain='CORNER')
    base = linear(mat['palette'])
    for poly in obj.data.polygons:
        shade = rng.uniform(1 - variation, 1 + variation)
        for index in poly.loop_indices:
            colors.data[index].color = (*(min(1, c * shade) for c in base), 1)
    return obj


def mesh(name, verts, faces, mat, root, bevel=0, variation=.12):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return finish(obj, name, mat, root, bevel, variation)


def cylinder(name, radius, bottom, top, mat, root, count=12, bevel=.006):
    bpy.ops.mesh.primitive_cylinder_add(vertices=count, radius=radius, depth=top-bottom, location=(0, 0, (bottom+top)/2))
    return finish(bpy.context.object, name, mat, root, bevel)


def sector(name, inner, outer, bottom, top, start, end, mat, root, steps=3, bevel=.005):
    verts = []
    for z, radius in [(bottom, inner), (bottom, outer), (top, inner), (top, outer)]:
        verts += [(radius*math.cos(start+(end-start)*i/steps), radius*math.sin(start+(end-start)*i/steps), z) for i in range(steps+1)]
    n = steps+1
    faces = []
    for i in range(steps):
        faces += [(i, i+1, n+i+1, n+i), (2*n+i, 3*n+i, 3*n+i+1, 2*n+i+1),
                  (i, 2*n+i, 2*n+i+1, i+1), (n+i, n+i+1, 3*n+i+1, 3*n+i)]
    faces += [(0,n,3*n,2*n), (n-1,3*n-1,4*n-1,2*n-1)]
    return mesh(name, verts, faces, mat, root, bevel)


def stroke(name, points, width, mat, root):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = width
    curve.bevel_resolution = 0
    spline = curve.splines.new('POLY')
    spline.points.add(len(points)-1)
    for point, co in zip(spline.points, points):
        point.co = (*co, 1)
    obj = bpy.data.objects.new(name, curve)
    scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return finish(obj, name, mat, root, variation=.03)


portal = parent('portal')
# 바닥을 채우지 않는 빈 고리: 어떤 지면에도 같은 접지 규격.
sector('lower_iron_band', .303, .435, .006, .056, 0, math.tau, iron, portal, 48, .004)
for i in range(12):
    a = i*math.tau/12
    sector('ring_stone_%02d' % i, .307, .452+rng.uniform(-.006,.004), .025, .153+rng.uniform(-.009,.008),
           a+.014, a+math.tau/12-.014, stone, portal, 3, .009)
    sector('outer_foot_%02d' % i, .407, .449, .012, .05, a+.01, a+math.tau/12-.01, stone, portal, 2, .005)
sector('portal_inner_metal_lip', .299, .317, .101, .118, 0, math.tau, brass, portal, 64, .002)
for i in range(4):
    a = i*math.pi/2+math.pi/4
    sector('rune_clamp_%d' % i, .306, .459, .15, .181, a-.13, a+.13, brass, portal, 2, .005)
    # 상면 룬 홈과 작은 중심 마름모.
    radial = Vector((math.cos(a),math.sin(a),0))
    tangent = Vector((-math.sin(a),math.cos(a),0))
    center = radial*.382+Vector((0,0,.185))
    points = [center+radial*.032,center+tangent*.023,center-radial*.032,center-tangent*.023,center+radial*.032]
    stroke('clamp_inlay_%d' % i, points, .006, iron, portal)
    stroke('clamp_gold_pin_%d' % i, [center-radial*.008,center+radial*.008], .005, brass, portal)
# 실제 오목한 표면. 런타임은 동일 반경에 공유 소용돌이 셰이더를 적용.
verts=[(0,0,.048)]
for ring in range(1,9):
    r=.305*ring/8
    for i in range(96):
        a=i*math.tau/96
        verts.append((r*math.cos(a),r*math.sin(a),.048+.067*(r/.305)**1.5))
faces=[(0,1+i,1+(i+1)%96) for i in range(96)]
for ring in range(7):
    k=1+ring*96
    for i in range(96):
        j=(i+1)%96
        faces.append((k+i,k+96+i,k+96+j,k+j))
vortex=mesh('portal_vortex',verts,faces,energy,portal,variation=0)
vortex['surfaceRadius']=.305
# Blender 원본에서도 소용돌이 형태를 확인하는 정점색; 애니메이션은 Godot 담당.
for loop in vortex.data.loops:
    co=vortex.data.vertices[loop.vertex_index].co
    r=math.hypot(co.x,co.y)/.305
    a=math.atan2(co.y,co.x)
    band=max(0,math.sin(a*3-r*17))**7
    shade=(.12+.55*r+.75*band)*(min(1,r*6))
    vortex.data.color_attributes['Color'].data[loop.index].color=(.22*shade,.028*shade,.48*shade,1)

core=parent('core')
cylinder('octagonal_stone_foot',.377,0,.067,stone,core,8,.009)
cylinder('lower_iron_reveal',.335,.065,.097,iron,core,8,.004)
cylinder('octagonal_upper_stone',.319,.095,.155,stone,core,8,.008)
cylinder('socket_metal',.224,.15,.191,iron,core,12,.006)
sector('socket_brass_rim',.175,.224,.183,.20,0,math.tau,brass,core,32,.002)
cylinder('socket_energy',.175,.188,.195,teal,core,32,.001)
# 네 방향 동일한 지지대. 특정 타일의 정면/장식에 의존하지 않는 실루엣.
for i in range(4):
    a=i*math.pi/2+math.pi/4
    radial=Vector((math.cos(a),math.sin(a),0))
    tangent=Vector((-math.sin(a),math.cos(a),0))
    outline=[(.19,.105),(.33,.11),(.317,.36),(.273,.427),(.225,.425),(.232,.369),(.25,.344)]
    verts=[]
    for side in [-.054,.054]:
        verts += [tuple(radial*r+tangent*side+Vector((0,0,z))) for r,z in outline]
    n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    mesh('core_guard_%d'%i,verts,faces,iron,core,.008)
    # 지지대 상단과 바깥쪽의 넓은 황동 띠.
    pts=[tuple(radial*r+Vector((0,0,z))) for r,z in [(.322,.13),(.305,.355),(.273,.416),(.234,.416)]]
    stroke('guard_brass_spine_%d'%i,pts,.012,brass,core)
    c=radial*.329+Vector((0,0,.242))
    points=[c+Vector((0,0,.044)),c+tangent*.029,c-Vector((0,0,.044)),c-tangent*.029,c+Vector((0,0,.044))]
    stroke('guard_rune_%d'%i,points,.0045,teal,core)
    for sign in [-1,1]:
        pts=[tuple(radial*.352+tangent*(sign*.07)+Vector((0,0,.071))),tuple(radial*.306+tangent*(sign*.062)+Vector((0,0,.104)))]
        stroke('foot_brass_pin_%d_%d'%(i,sign),pts,.007,brass,core)
# 회전 중심 기준의 독립 결정 메시; 비균일 면과 어두운 옆면 보존.
verts=[(.004,-.008,-.30)]
for z,r,offset in [(-.17,.105,0),(.035,.154,.06),(.145,.11,-.025)]:
    for i in range(8):
        a=i*math.tau/8+offset
        verts.append((r*math.cos(a),r*math.sin(a),z+rng.uniform(-.012,.012)))
verts.append((-.018,.012,.30))
faces=[]
for i in range(8):
    j=(i+1)%8
    faces.append((0,1+j,1+i))
    for k in (1,9):
        faces.extend([(k+i,k+j,k+8+i),(k+j,k+8+j,k+8+i)])
    faces.append((25,17+i,17+j))
crystal=mesh('core_crystal',verts,faces,crystal_mat,core,variation=.42)
crystal.location.z=.60
# 확대 시 보이는 소수의 결정 내포물.
for index,points in enumerate([
    [(-.05,-.107,-.10),(.013,-.15,.024),(-.024,-.101,.145)],
    [(.013,-.15,.024),(.081,-.108,.07)],
]):
    seam=stroke('crystal_inclusion_%d'%index,points,.0018,teal,crystal)

# 원본 부품은 보존, 내보낼 때만 동일 재질의 정적 부품 병합.
for root in (portal,core):
    root['designDirection']='A — Ancient rune sanctuary'
text=bpy.data.texts.new('00_제작_안내')
text.write('포탈·코어 공용 A안. 바닥·식생 없음. 타일=1, GLTF +Y 위/지면=0.\n'
           'portal_vortex와 core_crystal은 독립 애니메이션 파트. 원본 부품 수동 편집 후 export_landmarks.py로 출력.\n'
           'build_landmarks.py는 새 원본을 만드는 생성기이므로 수동 편집한 원본에 다시 실행하지 마세요.\n')
scene.world=bpy.data.worlds.new('Landmark studio')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.14,.16,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
normal_image.image.pack()
for name, root in [('01 Portal Master', portal), ('02 Core Master', core)]:
    view = bpy.data.scenes.new(name)
    view.world = scene.world
    for obj in [root] + list(root.children_recursive):
        view.collection.objects.link(obj)
bpy.context.window.scene = bpy.data.scenes['01 Portal Master']
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'rune-landmarks.blend'))
exec(compile((HERE/'export_landmarks.py').read_text(),str(HERE/'export_landmarks.py'),'exec'))
