"""네 식물의 명시적 조형을 최초 작성. 저장된 마스터는 재생성하거나 덮어쓰지 않음."""
from pathlib import Path
import json
import math

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
TARGET = HERE / 'forest-plant-masters.blend'


def rgb(code):
    values = [int(code[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values)


OLIVE = [rgb(c) for c in ('637840', '738346', '4d6535', '839050', '59713c')]
FERN = [rgb(c) for c in ('697b40', '788746', '526d37', '8b9551')]
GROUND = [rgb(c) for c in ('485f33', '63753d', '536b36', '7a8649')]
STEM = rgb('66723c')
SHEATH = rgb('5a5d36')


def curve(points, t):
    """제어점을 통과하는 Catmull–Rom 곡선. 잎 하나마다 다른 개별 명시 조형점."""
    points = [Vector(p) for p in points]
    u = min(max(t, 0), 1) * (len(points) - 1)
    i = min(int(u), len(points) - 2)
    f = u - i
    a, b = points[max(0, i - 1)], points[i]
    c, d = points[i + 1], points[min(len(points) - 1, i + 2)]
    return .5 * ((2 * b) + (-a + c) * f + (2 * a - 5 * b + 4 * c - d) * f * f + (-a + 3 * b - 3 * c + d) * f ** 3)


def mesh_object(name, vertices, faces, colors, material, collection, root, role):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(material)
    attribute = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
    mesh.color_attributes.active_color = attribute
    for entry, color in zip(attribute.data, colors):
        entry.color = (*color, 1)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = root
    obj['partRole'] = role
    obj['editableMaster'] = True
    return obj


def stem(name, controls, radius, material, collection, root, *, segments=8, sides=5, color=STEM):
    """곡선을 따라 회전 없이 이어지는 원통. 잎자루·가지가 잎 몸체와 분리됨."""
    positions = [curve(controls, i / segments) for i in range(segments + 1)]
    vertices, colors, faces = [], [], []
    side = None
    for i, point in enumerate(positions):
        tangent = (positions[min(i + 1, segments)] - positions[max(i - 1, 0)]).normalized()
        if side is None:
            side = tangent.cross(Vector((0, 1, 0)))
            if side.length < .1:
                side = tangent.cross(Vector((1, 0, 0)))
        side = (side - tangent * side.dot(tangent)).normalized()
        normal = tangent.cross(side).normalized()
        thickness = radius * (1 - .66 * (i / segments) ** 1.25)
        for j in range(sides):
            angle = j * math.tau / sides
            vertices.append(tuple(point + thickness * (side * math.cos(angle) + normal * math.sin(angle))))
            shade = .65 + .35 * i / segments
            colors.append(tuple(c * shade for c in color))
        if i:
            for j in range(sides):
                a = (i - 1) * sides + j
                b = (i - 1) * sides + (j + 1) % sides
                c = i * sides + (j + 1) % sides
                d = i * sides + j
                faces.append((a, b, c, d))
    faces.extend((tuple(reversed(range(sides))), tuple(range(segments * sides, (segments + 1) * sides))))
    return mesh_object(name, vertices, faces, colors, material, collection, root, 'stem')


def lamina(name, controls, width, material, collection, root, *, color, stations=9, columns=5,
           profile='lance', roll=0.0, cup=.10, skew=.10, ripple=.025):
    """실제 곡면 잎. 고정 부채가 아닌 개별 곡선·말림·비대칭 윤곽."""
    shapes = {
        'grass': (.25, .86, 1, .94, .79, .58, .32, .12, 0),
        'lance': (.03, .49, .84, 1, .97, .80, .53, .23, 0),
        'pinna': (.12, .64, .95, 1, .84, .62, .39, .13, 0),
        'heart': (.08, .79, 1, .87, .69, .63, .40, .17, 0),
    }
    shape = shapes[profile]
    vertices, colors, faces = [], [], []
    for i in range(stations):
        t = i / (stations - 1)
        point = curve(controls, t)
        tangent = curve(controls, min(1, t + .015)) - curve(controls, max(0, t - .015))
        tangent.normalize()
        across = Vector((0, 0, 1)).cross(tangent)
        if across.length < .08:
            across = Vector((1, 0, 0))
        across.normalize()
        normal = tangent.cross(across).normalized()
        angle = roll * (t * t - .18) + ripple * math.sin(t * math.tau * 1.2)
        rotated = across * math.cos(angle) + normal * math.sin(angle)
        leaf_normal = tangent.cross(rotated).normalized()
        f = t * (len(shape) - 1)
        at = min(int(f), len(shape) - 2)
        breadth = shape[at] * (1 - (f - at)) + shape[at + 1] * (f - at)
        for j in range(columns):
            u = -1 + 2 * j / (columns - 1)
            asymmetry = 1 + skew * u * math.sin(t * math.pi)
            edge_wave = 1 + ripple * math.sin(t * math.tau * 2.4 + u * .9)
            lateral = width * .5 * breadth * u * asymmetry * edge_wave
            # 넓은 중륵과 비대칭 가장자리 말림. 색으로 잎맥을 그린 평판을 피함.
            ridge = width * breadth * (.09 * (1 - abs(u)) + cup * abs(u) ** 1.5)
            vertex = point + rotated * lateral + leaf_normal * ridge
            vertices.append(tuple(vertex))
            shade = (.57 + .43 * math.sin(t * 1.5 + .14)) * (1.03 if j == columns // 2 else .85 + .11 * (u + 1) / 2)
            colors.append(tuple(c * shade for c in color))
        if i:
            for j in range(columns - 1):
                a = (i - 1) * columns + j
                b = i * columns + j
                faces.append((a, b, b + 1, a + 1))
    # 끝의 중복 정점을 하나로 병합해 뾰족한 윤곽을 유지.
    final = vertices[-columns]
    tip_index = len(vertices) - columns
    vertices = vertices[:-columns] + [final]
    colors = colors[:-columns] + [colors[-columns // 2]]
    faces = [tuple(dict.fromkeys(tip_index if v >= tip_index else v for v in face)) for face in faces]
    faces = [face for face in faces if len(face) >= 3]
    return mesh_object(name, vertices, faces, colors, material, collection, root, 'leaf')


def grass(materials, collection, root):
    # 끝점과 중간 굽힘을 각각 지정한 22장. 한 방향의 바람을 받은 비대칭 포기.
    shapes = [
        ((-.018,.006,.012),(-.035,.025,.20),(-.13,.045,.43),(-.31,.07,.25),.029,.55),
        ((.008,.015,.012),(.01,.04,.24),(-.07,.12,.53),(-.22,.21,.38),.025,-.40),
        ((.018,-.008,.013),(.045,-.015,.22),(.20,-.045,.48),(.38,-.07,.26),.034,.65),
        ((-.01,-.02,.014),(-.012,-.07,.22),(-.10,-.24,.39),(-.19,-.40,.20),.031,-.45),
        ((.0,.0,.02),(.025,.02,.29),(.015,.045,.58),(-.065,.085,.50),.024,.42),
        ((.027,.022,.01),(.08,.07,.20),(.25,.15,.36),(.40,.21,.14),.036,-.55),
        ((-.024,.023,.01),(-.10,.08,.17),(-.24,.13,.29),(-.39,.19,.095),.030,.75),
        ((.005,-.036,.012),(.06,-.10,.16),(.18,-.26,.28),(.30,-.40,.13),.028,-.65),
        ((-.039,-.012,.012),(-.09,-.045,.20),(-.22,-.08,.36),(-.36,-.06,.21),.033,.35),
        ((.022,.036,.008),(.022,.11,.16),(-.04,.29,.34),(-.10,.41,.24),.028,-.65),
        ((.032,-.011,.012),(.07,-.02,.28),(.13,.00,.54),(.22,.05,.46),.026,.50),
        ((-.009,.01,.014),(-.015,.015,.23),(-.02,-.045,.47),(-.07,-.12,.43),.022,-.30),
        ((-.025,-.033,.008),(-.10,-.11,.10),(-.20,-.22,.20),(-.28,-.34,.09),.027,.85),
        ((.037,.011,.008),(.13,.025,.14),(.29,.07,.24),(.44,.14,.10),.032,-.72),
        ((-.03,.027,.012),(-.07,.11,.23),(-.08,.25,.45),(-.14,.32,.33),.022,.44),
        ((.008,.01,.019),(.002,.07,.27),(.04,.20,.50),(.105,.31,.42),.026,-.50),
        ((.023,-.027,.01),(.045,-.09,.20),(.07,-.22,.40),(.15,-.34,.30),.029,.70),
        ((-.022,.012,.012),(-.08,.035,.14),(-.21,.005,.25),(-.32,-.025,.08),.038,-.52),
        ((-.005,-.014,.01),(-.03,-.03,.30),(-.01,-.01,.62),(.035,.035,.57),.018,.32),
        ((.028,.03,.01),(.08,.14,.17),(.18,.28,.30),(.27,.36,.17),.026,-.40),
        ((-.04,-.01,.004),(-.10,-.08,.07),(-.24,-.10,.105),(-.35,-.10,.022),.022,.58),
        ((.02,-.04,.004),(.06,-.13,.08),(.16,-.20,.12),(.27,-.25,.025),.020,-.60),
    ]
    for i, (a,b,c,d,width,roll) in enumerate(shapes):
        color = rgb('8b8950') if i in (20,21) else OLIVE[i % len(OLIVE)]
        lamina(f'Grass.leaf_{i+1:02}', (a,b,c,d), width, materials['leaf'], collection, root,
               color=color, stations=11, columns=3, profile='grass', roll=roll, cup=.20, skew=.06)
    for i, (a,b,c,d,_,_) in enumerate(shapes[:6]):
        end = curve((a,b,c,d), .23)
        stem(f'Grass.sheath_{i+1:02}', (a, Vector(a).lerp(end,.52), end), .0065,
             materials['stem'], collection, root, segments=4, sides=5, color=SHEATH)


def fern(materials, collection, root):
    # 겹침을 고려한 여섯 성숙 잎축. 앞쪽 낮은 잎과 뒷쪽 높은 잎의 다른 아치.
    fronds = [
        ((0,.015,.012),(.008,.06,.17),(.025,.28,.43),(.04,.57,.30)),
        ((-.015,.004,.01),(-.07,.03,.17),(-.31,.08,.36),(-.55,.16,.18)),
        ((.016,-.003,.015),(.065,-.04,.22),(.31,-.10,.45),(.54,-.22,.28)),
        ((-.002,-.02,.008),(-.035,-.10,.12),(-.11,-.31,.26),(-.23,-.54,.105)),
        ((.015,.022,.009),(.10,.10,.19),(.31,.24,.36),(.52,.36,.22)),
        ((-.02,.014,.012),(-.08,.075,.20),(-.27,.27,.43),(-.40,.46,.32)),
    ]
    tiers = (.19,.285,.38,.475,.565,.65,.735,.81,.88,.94)
    for f, controls in enumerate(fronds):
        stem(f'Fern.frond_{f+1:02}.rachis', controls, .0057, materials['stem'], collection, root, segments=10)
        for n, t in enumerate(tiers):
            for side in (-1,1):
                progress = t + (.012 if side == 1 else -.004) * (1 + f % 2)
                origin = curve(controls,progress)
                direction = (curve(controls,min(1,progress+.012))-curve(controls,max(0,progress-.012))).normalized()
                transverse = Vector((0,0,1)).cross(direction).normalized() * side
                reach = (.035 + .145 * math.sin(math.pi * progress) ** .90) * (1 if f in (0,2,5) else .89)
                reach *= (1.0 if side < 0 else .83 + .09 * ((n + f) % 3))
                end = origin + transverse * reach + direction * reach * (.30 + .12 * n / 10)
                end.z -= reach * (.05 + .25 * progress)
                path = (origin, origin.lerp(end,.28) + Vector((0,0,.008)),
                        origin.lerp(end,.63) + Vector((0,0,.015)), end)
                lamina(f'Fern.frond_{f+1:02}.pinna_{n+1:02}_{"L" if side<0 else "R"}', path,
                       reach * (.33 if n<6 else .39), materials['leaf'], collection, root,
                       color=FERN[(f + n // 4) % 4], stations=7, columns=3, profile='pinna',
                       roll=side * (.25 + .035 * n), cup=.10, skew=.15, ripple=.10)
    # 아직 펴지지 않은 독립적인 새 잎. 완전 방사형 꽃 형태를 끊는 비대칭 세로 윤곽.
    young = ((.014,.005,.012),(.025,.012,.17),(.010,.028,.35),(-.015,.01,.51),(-.06,-.028,.51),(-.076,-.045,.466))
    stem('Fern.young_frond.curled_rachis', young, .0055, materials['stem'], collection, root, segments=14)
    for n,t in enumerate((.38,.48,.59,.69)):
        for side in (-1,1):
            a=curve(young,t)
            b=a+Vector((side*(.041-.005*n),.01,.034))
            lamina(f'Fern.young_frond.pinna_{n}_{side}', (a,a.lerp(b,.50)+Vector((0,0,.008)),b),
                   .015, materials['leaf'], collection, root, color=FERN[2], stations=5, columns=3, profile='pinna', roll=side*.8)


def broadleaf(materials, collection, root):
    trunks = [((0,0,.002),(-.014,.005,.12),(.014,.026,.28),(-.002,.034,.425)),
              ((.009,-.009,.001),(.047,-.028,.10),(.105,-.05,.23),(.145,-.035,.335))]
    for i,points in enumerate(trunks):
        stem(f'Broadleaf.branch_{i+1:02}', points,.010 if i==0 else .0075,
             materials['stem'],collection,root,segments=10,sides=6)
    # 줄기의 서로 다른 마디에서 나온 잎자루와 명시적 잎 윤곽. 한 밑동 부채 배치 금지.
    leaves = [
        (0,.21,((-.085,-.035,.095),(-.18,-.078,.17),(-.30,-.12,.115),(-.365,-.145,.07)),.155,-.46),
        (0,.36,((.087,.028,.17),(.19,.076,.275),(.34,.11,.225),(.41,.15,.13)),.175,.50),
        (0,.55,((-.06,.092,.25),(-.14,.20,.345),(-.26,.285,.29),(-.325,.315,.205)),.19,-.62),
        (0,.69,((-.009,-.06,.30),(-.055,-.16,.415),(-.11,-.31,.365),(-.125,-.37,.245)),.175,.38),
        (0,.83,((.045,.067,.385),(.13,.145,.47),(.25,.24,.41),(.29,.265,.315)),.15,.66),
        (0,.98,((-.01,.033,.429),(-.033,.08,.50),(-.026,.157,.50),(.004,.19,.463)),.078,-.90),
        (1,.36,((.12,-.07,.125),(.23,-.13,.205),(.37,-.22,.145),(.41,-.255,.075)),.17,.60),
        (1,.60,((.05,-.108,.215),(.045,-.235,.28),(.13,-.36,.22),(.17,-.40,.125)),.17,-.58),
        (1,.82,((.205,-.028,.285),(.295,.036,.35),(.39,.115,.275),(.45,.15,.185)),.16,-.40),
        (1,.98,((.151,-.032,.339),(.195,-.012,.425),(.235,.003,.44),(.25,.01,.395)),.075,.95),
    ]
    for i,(branch,t,controls,width,roll) in enumerate(leaves):
        join=curve(trunks[branch],t)
        petiole_end=Vector(controls[0])
        stem(f'Broadleaf.petiole_{i+1:02}',(join,join.lerp(petiole_end,.45)+Vector((0,0,.012)),petiole_end),
             .0048,materials['stem'],collection,root,segments=4,sides=5)
        lamina(f'Broadleaf.leaf_{i+1:02}',controls,width,materials['leaf'],collection,root,
               color=OLIVE[(i+2)%5],stations=9,columns=5,profile='lance',roll=roll,cup=-.035 if i%3==0 else .065,
               skew=.19 if i%2==0 else -.13,ripple=.065)
        vein=[curve(controls,t)+Vector((0,0,width*.045*math.sin(t*math.pi))) for t in (0,.18,.38,.59,.78,.96)]
        stem(f'Broadleaf.midrib_{i+1:02}',vein,.0023,materials['stem'],collection,root,segments=5,sides=3,color=OLIVE[1])


def groundcover(materials,collection,root):
    vines=[((0,0,.012),(-.04,-.10,.017),(-.18,-.24,.018),(-.35,-.35,.012),(-.56,-.31,.014)),
           ((0,0,.012),(.12,.09,.026),(.30,.105,.014),(.47,.16,.018),(.58,.245,.014)),
           ((-.015,.014,.012),(-.04,.13,.035),(-.08,.30,.027),(-.19,.43,.012))]
    for i,controls in enumerate(vines):
        stem(f'Groundcover.runner_{i+1:02}',controls,.006,materials['stem'],collection,root,segments=12,sides=5,color=rgb('5b6640'))
    # 마디를 따라 엇갈린 크기·방향. 넓은 잎 식물과 다른 낮은 심장형 잎.
    leaves=[(0,.12,2.72,.17,.115,.075),(0,.26,-.70,.145,.110,.055),
            (0,.42,2.55,.19,.13,.065),(0,.56,-1.08,.17,.12,.052),
            (0,.70,2.43,.15,.115,.062),(0,.87,-.82,.135,.10,.040),
            (1,.12,-.68,.165,.115,.058),(1,.26,1.70,.175,.12,.065),
            (1,.43,-.58,.16,.125,.067),(1,.57,1.76,.145,.12,.055),
            (1,.71,-.34,.16,.115,.070),(1,.88,1.55,.115,.09,.042),
            (2,.17,3.04,.16,.125,.055),(2,.36,.03,.185,.135,.072),
            (2,.57,2.76,.17,.13,.047),(2,.77,.19,.14,.115,.049),
            (2,.94,2.53,.10,.08,.038),(0,.04,-1.20,.13,.11,.060)]
    for i,(vine,t,angle,length,width,height) in enumerate(leaves):
        node=curve(vines[vine],t)
        direction=Vector((math.cos(angle),math.sin(angle),0))
        side=Vector((-direction.y,direction.x,0))
        start=node+direction*.025+Vector((0,0,height*.52))
        stem(f'Groundcover.petiole_{i+1:02}',(node,node.lerp(start,.52)+Vector((0,0,.012)),start),
             .0035,materials['stem'],collection,root,segments=3,sides=4,color=STEM)
        points=(start,start+direction*length*.27+Vector((0,0,height*.47)),
                start+direction*length*.69+side*length*.11+Vector((0,0,height*.17)),
                start+direction*length+side*length*.15-Vector((0,0,height*.35)))
        lamina(f'Groundcover.leaf_{i+1:02}',points,width,materials['leaf'],collection,root,
               color=GROUND[i%4],stations=7,columns=5,profile='heart',roll=(-.38 if i%2 else .48),cup=-.06,skew=.18,ripple=.075)


def main():
    if not bpy.app.background or bpy.data.filepath:
        raise RuntimeError('최초 제작 전용입니다. 별도 Blender --background --factory-startup에서 실행하세요.')
    if TARGET.exists():
        raise FileExistsError('저장된 마스터 보호: seed는 기존 forest-plant-masters.blend를 덮어쓰지 않습니다. 해당 원본을 직접 편집하세요.')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    original=bpy.context.scene
    materials={}
    for key in ('leaf','stem'):
        material=bpy.data.materials.new('ForestPlant_'+key)
        material.use_nodes=True
        bsdf=material.node_tree.nodes.get('Principled BSDF')
        attribute=material.node_tree.nodes.new('ShaderNodeVertexColor')
        attribute.layer_name='Color'
        material.node_tree.links.new(attribute.outputs['Color'],bsdf.inputs['Base Color'])
        bsdf.inputs['Roughness'].default_value=.86 if key=='leaf' else .95
        bsdf.inputs['Specular IOR Level'].default_value=.16 if key=='leaf' else .08
        material.diffuse_color=(*OLIVE[0],1)
        material.use_backface_culling=False
        materials[key]=material
    entries=[]
    for index,(name,asset_id,builder) in enumerate((('Grass','arched_grass',grass),('Fern','layered_fern',fern),
                                                  ('Broadleaf','broadleaf_herb',broadleaf),('Groundcover','creeping_groundcover',groundcover)),1):
        scene=bpy.data.scenes.new(f'{index:02} {name} Master')
        scene.unit_settings.system='METRIC'
        scene.unit_settings.scale_length=1
        collection=bpy.data.collections.new(f'{index:02} {name}')
        scene.collection.children.link(collection)
        root=bpy.data.objects.new(asset_id+'_root',None)
        collection.objects.link(root)
        root['plantAssetId']=asset_id
        root['tileUnits']=1.0
        root['sourceRole']='independent_editable_master'
        root['productionMethod']='authored control points and leaf layouts; initial Python seed'
        builder(materials,collection,root)
        meshes=[obj for obj in collection.objects if obj.type=='MESH']
        for obj in meshes: obj.data.calc_loop_triangles()
        triangles=sum(len(obj.data.loop_triangles) for obj in meshes)
        minimum=[min(v.co[i] for obj in meshes for v in obj.data.vertices) for i in range(3)]
        maximum=[max(v.co[i] for obj in meshes for v in obj.data.vertices) for i in range(3)]
        entries.append({'plantAssetId':asset_id,'scene':scene.name,'collection':collection.name,'root':root.name,
                        'meshObjects':len(meshes),'triangles':triangles,'bounds':{'min':minimum,'max':maximum},
                        'stemObjects':sum(obj['partRole']=='stem' for obj in meshes),'leafObjects':sum(obj['partRole']=='leaf' for obj in meshes)})
        scene.world=bpy.data.worlds.new(name+' Preview World')
        scene.world.color=(.12,.15,.12)
        scene.view_settings.view_transform='AgX'
    bpy.data.scenes.remove(original)
    bpy.context.window.scene=bpy.data.scenes['01 Grass Master']
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            region=area.spaces.active.region_3d
            region.view_distance=1.6
            region.view_location=(0,0,.23)
            region.view_rotation=Vector((1.2,-2.0,1.4)).to_track_quat('Z','Y')
    text=bpy.data.texts.new('README - Editable Plant Masters')
    text.write('독립 식물 마스터 4종\n\n상단 Scene에서 01 Grass / 02 Fern / 03 Broadleaf / 04 Groundcover를 선택합니다.\n모든 식물은 원점 0, 단위 1=게임 1타일입니다.\n줄기, 잎자루, 잎, 중륵은 별도 메시이며 일반 Edit Mode에서 수정할 수 있습니다.\n최초 형태는 seed_plant_masters.py의 명시적 조형점과 잎 배치로 작성했습니다.\nseed는 저장된 이 원본을 덮어쓰지 않습니다. 미리보기/내보내기는 반드시 저장된 마스터를 읽습니다.\n맵 배치 및 게임 GLB와 분리된 검수용 원본입니다. 애니메이션이나 텍스처는 없습니다.\n')
    summary={'source':TARGET.name,'units':'1 Blender unit = 1 game tile','production':'explicit authored control points; editable independent mesh masters',
             'masters':entries,'totalTriangles':sum(e['triangles'] for e in entries),'textures':0,'materials':2,'animations':0}
    if summary['totalTriangles']>9000:
        raise RuntimeError(f'마스터 조형 예산 점검 필요: {summary["totalTriangles"]}')
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    (HERE/'master_manifest.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print('PLANT_MASTERS_READY',json.dumps(summary,ensure_ascii=False))


if __name__=='__main__':
    main()
