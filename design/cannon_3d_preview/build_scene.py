import bpy, math, random
from mathutils import Vector
from pathlib import Path

OUT = Path('/Users/sejin/Documents/Codex/RuneNexus/design/cannon_3d_preview')
random.seed(17)
# 기존 열린 장면을 보존하는 독립 시안 장면
scene = bpy.data.scenes.new('RuneNexus_Cannon_Preview')
bpy.context.window.scene = scene

def material(name, color, metal=0, rough=.5, noise=False, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    n = m.node_tree.nodes
    p = n.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    if noise:
        tex = n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = 24
        tex.inputs['Detail'].default_value = 3
        bump = n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .23
        bump.inputs['Distance'].default_value = .055
        m.node_tree.links.new(tex.outputs['Fac'], bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'], p.inputs['Normal'])
    return m

orange = material('대포_주황_도장', (.8,.19,.035), .58,.32,True)
steel = material('내부_흑철', (.065,.078,.086), .8,.3,True)
rim = material('마모된_강철', (.29,.32,.33), .85,.27)
black = material('포구_내부', (.009,.012,.014), .2,.7)
stone = [material('석재_'+str(i), (.17+i*.012,.195+i*.011,.165+i*.01),0,.87,True) for i in range(4)]
dirt = [material('길_'+str(i),(.31+i*.012,.25+i*.009,.17+i*.009),0,.9,True) for i in range(3)]
moss = material('이끼',(.11,.16,.055),0,1,True)
earth = material('기반_암반',(.055,.069,.06),0,.94,True)
enemy_mat = material('표적_장갑',(.07,.085,.1),.75,.38)
red = material('표적_붉은_코어',(.8,.035,.012),.35,.3,False,2)
hot = material('섬광_중심',(1,.58,.12),0,.3,False,6)
fire = material('불꽃',(1,.15,.014),0,.5,False,3)
dustmat = material('폭발_먼지',(.19,.15,.105),0,1)
rune = material('주황_룬',(1,.63,.23),.3,.32,False,.45)

def finish(o,name,mat,parent=None):
    o.name=name
    if mat: o.data.materials.append(mat)
    if parent: o.parent=parent
    return o
def cube(name,loc,size,mat,parent=None,bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=finish(bpy.context.object,name,mat,parent);o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('角の面取り','BEVEL');b.width=bevel;b.segments=2
        o.modifiers.new('面法線','WEIGHTED_NORMAL')
    return o
def cyl(name,loc,r,depth,mat,parent=None,axis='Z',verts=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc)
    o=finish(bpy.context.object,name,mat,parent)
    if axis=='X':o.rotation_euler[1]=math.pi/2
    elif axis=='Y':o.rotation_euler[0]=math.pi/2
    b=o.modifiers.new('縁','BEVEL');b.width=.025;b.segments=2
    o.modifiers.new('法線','WEIGHTED_NORMAL')
    return o
def torus(name,loc,major,minor,mat,parent=None,axis='Z'):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=10,location=loc,major_radius=major,minor_radius=minor)
    o=finish(bpy.context.object,name,mat,parent)
    if axis=='X':o.rotation_euler[1]=math.pi/2
    return o
def ico(name,loc,size,mat,parent=None,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc)
    o=finish(bpy.context.object,name,mat,parent);o.scale=size
    return o
def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.location=loc;o.parent=parent;return o
def key(o,frame,loc=None,scale=None,rot=None):
    if loc is not None:o.location=loc;o.keyframe_insert('location',frame=frame)
    if scale is not None:o.scale=scale;o.keyframe_insert('scale',frame=frame)
    if rot is not None:o.rotation_euler=rot;o.keyframe_insert('rotation_euler',frame=frame)

# 연결된 석조 전장 / 우측 통행로
cube('전장_기반',(0,0,-.26),(7.7,8.8,.55),earth,bevel=.17)
for x in range(-2,3):
    for y in range(-2,3):
        px=x*1.5;py=y*1.65
        path=x==1
        tile=cube('통행로' if path else '건설_석판',(px,py,.04),(1.46,1.61,.22),random.choice(dirt if path else stone),bevel=.065)
        if not path:
            for ox,oy in [(-.60,-.68),(.60,-.68),(-.60,.68),(.60,.68)]:
                cube('모서리_석재',(px+ox,py+oy,.165),(.17,.17,.04),random.choice(stone),bevel=.02)
        for j in range(5):
            xx=px+random.choice([-1,1])*random.uniform(.54,.68);yy=py+random.uniform(-.72,.72)
            ico('이끼_조각' if not path else '작은_돌',(xx,yy,.17),(random.uniform(.025,.07),random.uniform(.05,.13),.025),moss if not path else stone[0])
for i in range(22):
    xx=random.choice([-3.65,3.65]);yy=random.uniform(-4,4)
    ico('외곽_잔해',(xx,yy,.04),(random.uniform(.10,.25),random.uniform(.1,.3),random.uniform(.1,.28)),random.choice(stone))
for y in [-3.45,-2.9,2.9,3.45]:
    cube('낮은_벽_잔해',(-3.48,y,.35),(.36,.48,.5),stone[0],bevel=.07)

# 한 칸 안의 고정 받침과 회전 상부
base=(-1.5,0,.18)
cyl('팔각_주황_받침',(-1.5,0,.29),.66,.22,orange,verts=8)
cyl('회전_베어링',(-1.5,0,.44),.49,.17,steel)
torus('회전_링',(-1.5,0,.53),.43,.035,rim)
for a in range(8):
    angle=a*math.pi/4
    cyl('받침_볼트',(-1.5+.55*math.cos(angle),.55*math.sin(angle),.415),.043,.045,rim,verts=6)
head=empty('조준_회전',(-1.5,0,.55))
cube('회전_상판',(0,0,.04),(.83,.82,.15),steel,head)
for sy in [-1,1]:
    cube('주황_측면_장갑',(-.07,sy*.34,.28),(.72,.13,.47),orange,head,.07)
    cyl('포신_축',(.03,sy*.44,.4),.14,.11,rim,head,'Y')
    cyl('축_덮개',(.03,sy*.505,.4),.09,.04,orange,head,'Y')
    cyl('반동_가이드',(.16,sy*.255,.58),.042,.83,rim,head,'X',24)
    cube('가이드_고정부',(-.3,sy*.255,.58),(.14,.13,.13),steel,head)
barrel=empty('포신_반동',parent=head)
cube('주황_폐쇄기',(-.25,0,.44),(.43,.48,.42),orange,barrel,.06)
cyl('두꺼운_주황_포신',(.39,0,.43),.21,1.05,orange,barrel,'X')
for xx in [-.07,.6,.9]:
    cyl('포신_강철_띠',(xx,0,.43),.231,.065,rim,barrel,'X')
# 속이 빈 포구의 어두운 면과 두꺼운 림
cyl('포구_내부',(.94,0,.43),.175,.015,black,barrel,'X')
torus('포구_림',(.957,0,.43),.20,.033,rim,barrel,'X')
for xx,yy in [(-.36,-.15),(-.36,.15),(-.12,-.15),(-.12,.15)]:
    cyl('폐쇄기_리벳',(xx,yy,.665),.027,.025,rim,barrel,verts=6)
mark=cube('룬_다이아',(-.24,0,.661),(.13,.13,.011),rune,barrel,.006);mark.rotation_euler.z=math.pi/4
mark=cube('룬_중심',(-.24,0,.673),(.07,.07,.012),orange,barrel,.003);mark.rotation_euler.z=math.pi/4

# 움직이는 장갑 표적
enemy=empty('이동_표적')
ico('표적_몸통',(0,0,.43),(.30,.33,.40),enemy_mat,enemy,2)
ico('표적_중심',(0,-.22,.54),(.11,.10,.13),red,enemy)
for sx in [-1,1]:
    ico('표적_어깨',(sx*.29,0,.45),(.15,.20,.21),steel,enemy)
    ico('표적_다리',(sx*.17,-.04,.15),(.12,.19,.16),enemy_mat,enemy)

FPS=24;END=192;shots=[38,78,118,158]
def target(f):return Vector((1.5,2.9-5.8*(f-1)/(END-1),.40))
for f in range(1,END+1):
    t=target(f)
    key(enemy,f,loc=(t.x,t.y,.05+abs(math.sin(f*.26))*.035))
    a=math.atan2(t.y,3.0)
    key(head,f,rot=(0,0,a))
    recoil=max([max(0,1-(f-s)/7)*.16 if s<=f<=s+7 else 0 for s in shots])
    key(barrel,f,loc=(-recoil,0,0))

# 발사 섬광 / 실제 위치를 잇는 포탄 / 명중 파편
for idx,s in enumerate(shots):
    a=math.atan2(target(s).y,3)
    direction=Vector((math.cos(a),math.sin(a),0))
    origin=Vector((-1.5,0,.98))+direction*.99
    hitframe=s+6;impact=target(hitframe)
    flash=ico('포구_섬광_'+str(idx),(0,0,0),(1,1,1),hot,sub=2)
    flash.rotation_euler[2]=a
    key(flash,s-1,loc=origin,scale=(.001,)*3)
    key(flash,s,scale=(.31,.11,.11))
    key(flash,s+2,loc=origin+direction*.13,scale=(.12,.055,.055))
    key(flash,s+3,scale=(.001,)*3)
    shell=ico('포탄_'+str(idx),origin,(.001,)*3,steel,sub=2);shell.rotation_euler[2]=a
    key(shell,s-1,scale=(.001,)*3)
    key(shell,s,loc=origin,scale=(.13,.055,.055))
    key(shell,hitframe,loc=impact,scale=(.13,.055,.055))
    key(shell,hitframe+1,scale=(.001,)*3)
    blast=ico('명중_섬광_'+str(idx),impact,(.001,)*3,hot,sub=2)
    key(blast,hitframe-1,scale=(.001,)*3)
    key(blast,hitframe,scale=(.28,.28,.23))
    key(blast,hitframe+2,scale=(.4,.4,.28))
    key(blast,hitframe+5,scale=(.001,)*3)
    for j in range(10):
        an=random.uniform(0,math.tau);v=Vector((math.cos(an),math.sin(an),random.uniform(.3,1)))
        piece=ico('폭발_파편',impact,(.001,)*3,fire if j<4 else stone[0])
        key(piece,hitframe-1,scale=(.001,)*3)
        key(piece,hitframe,loc=impact,scale=(.035,.035,.08))
        key(piece,hitframe+7,loc=impact+v*.65,scale=(.025,.025,.05))
        key(piece,hitframe+13,loc=impact+v*.85-Vector((0,0,.32)),scale=(.001,)*3)
    for j in range(5):
        an=j*math.tau/5
        puff=ico('빠르게_소멸하는_먼지',impact,(.001,)*3,dustmat,sub=2)
        off=Vector((math.cos(an)*.35,math.sin(an)*.35,.1))
        key(puff,hitframe,scale=(.001,)*3)
        key(puff,hitframe+4,loc=impact+off,scale=(.15,.15,.12))
        key(puff,hitframe+11,loc=impact+off*1.7+Vector((0,0,.14)),scale=(.09,.09,.07))
        key(puff,hitframe+17,scale=(.001,)*3)

# 일정한 광원과 고정 직교 카메라
world=bpy.data.worlds.new('차분한_환경광');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.20,.25,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
def area(name,loc,energy,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;data.color=color
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc
    o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
area('부드러운_주광',(-3,-4,9),1500,6,(1,.88,.73))
area('차가운_보조광',(4,3,7),900,5,(.65,.79,1))
camdata=bpy.data.cameras.new('고정_직교_게임시점');cam=bpy.data.objects.new('고정_직교_게임시점',camdata);scene.collection.objects.link(cam)
cam.location=(0,-7.5,17);look=Vector((0,0,.1));cam.rotation_euler=(look-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=10.8;scene.camera=cam
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.fps=FPS;scene.frame_start=1;scene.frame_end=END
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(OUT/'preview.png')
scene.frame_set(80)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cannon-preview.blend'))
print('READY',len(scene.objects),str(OUT/'cannon-preview.blend'))
