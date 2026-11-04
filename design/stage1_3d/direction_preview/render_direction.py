"""챕터 1의 녹회색 자연 지형 + 고밀도 석재 PBR 방향 확인용 실제 3D 렌더."""
import bpy, math, random, re
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
OUT=ROOT/'design/stage1_3d/direction_preview'
random.seed(163)
s=bpy.data.scenes.new('Stage1_Material_Direction');bpy.context.window.scene=s
# 실제 스테이지 1의 칸 배열: 시안 맵을 사용하지 않음
source=(ROOT/'lib/data/definitions/game_stage_maps.dart').read_text().split('const gameStage2Map')[0]
tiles=re.findall(r'TileType\.(\w+)',source)
assert len(tiles)==80

def material(name,c,metal=0,rough=.75):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*c,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
stone=bpy.data.materials['HF_slate'].copy();stone.name='C1_mossy_PBR_stone'
road=bpy.data.materials['HF_road'].copy();road.name='C1_worn_earth_cobbles'
wall=bpy.data.materials['HF_wall'].copy();wall.name='C1_natural_rock_faces'
earth=material('C1_dark_earth',(.042,.052,.035),rough=.97)
moss=material('C1_moss',(.043,.105,.026),rough=.94)
fern=material('C1_grass',(.07,.17,.044),rough=.86)
wood=material('C1_exposed_roots',(.082,.055,.025),rough=.89)
for mat in [stone,road,wall]:
 p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Coat Weight'].default_value=0
# 석재 세부 무늬를 유지한 채 표면 일부에 이끼의 색·거칠기를 얹음
n=stone.node_tree.nodes;l=stone.node_tree.links;p=n.get('Principled BSDF')
original=p.inputs['Base Color'].links[0].from_socket
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=3.7;noise.inputs['Detail'].default_value=5
coord=n.new('ShaderNodeTexCoord');l.new(coord.outputs['Object'],noise.inputs['Vector'])
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.3;ramp.color_ramp.elements[1].position=.68
ramp.color_ramp.elements[1].color=(.7,.7,.7,1);l.new(noise.outputs['Fac'],ramp.inputs[0])
mix=n.new('ShaderNodeMixRGB');mix.inputs[2].default_value=(.038,.092,.024,1);l.new(ramp.outputs[0],mix.inputs[0]);l.new(original,mix.inputs[1]);l.new(mix.outputs[0],p.inputs['Base Color'])
for link in list(p.inputs['Roughness'].links):l.remove(link)
p.inputs['Roughness'].default_value=.69
for mat in [road,wall]:
 p=mat.node_tree.nodes.get('Principled BSDF')
 p.inputs['Coat Weight'].default_value=0

# 절단면이 규칙적이지 않은 낮은 석재·흙 기반

def block(name,loc,size,mat,seed,bevel=.025):
 rng=random.Random(seed);x,y,z=size
 corners=[(-x*.43,-y*.5),(x*.42,-y*.5),(x*.5,-y*.4),(x*.5,y*.43),(x*.4,y*.5),(-x*.43,y*.5),(-x*.5,y*.4),(-x*.5,-y*.41)]
 corners=[(a+rng.uniform(-.022,.022),b+rng.uniform(-.022,.022)) for a,b in corners]
 vs=[(a,b,-z/2) for a,b in corners]+[(a,b,z/2+rng.uniform(-.006,.006)) for a,b in corners]
 fs=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.materials.append(mat)
 o=bpy.data.objects.new(name,me);s.collection.objects.link(o);o.location=loc
 uv=me.uv_layers.new(name='UVMap')
 # 元のPBR適用と同じ約2m実寸平面投影
 for poly in me.polygons:
  no=poly.normal;axis=max(range(3),key=lambda a:abs(no[a]))
  for li in poly.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co
   uv.data[li].uv=((v.x+loc[0])/2,(v.y+loc[1])/2) if axis==2 else ((v.y+loc[1])/2,v.z/2) if axis==0 else ((v.x+loc[0])/2,v.z/2)
 mod=o.modifiers.new('broken stone edge','BEVEL');mod.width=bevel;mod.segments=2;o.modifiers.new('face normals','WEIGHTED_NORMAL')
 return o

def ico(name,loc,size,mat):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc);o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(mat);return o

def line(name,points,r,mat):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.bevel_depth=r;d.bevel_resolution=2
 sp=d.splines.new('POLY');sp.points.add(len(points)-1)
 for p,co in zip(sp.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,d);s.collection.objects.link(o);d.materials.append(mat);return o

def xy(col,row):return (col*2-7,9-row*2)
for row in range(10):
 for col in range(8):
  kind=tiles[row*8+col]
  if kind=='blocked':continue
  x,y=xy(col,row);isroad=kind in ['path','spawn','core']
  block('earth foundation',(x,y,-.30),(1.99,1.99,.57),earth,row*8+col,.045)
  block('worn earth path' if isroad else 'moss covered build stone',(x,y,.012),(1.985,1.985,.14),road if isroad else stone,row*87+col,.018)
  # 바깥쪽 절벽과 잔디는 실제 건설·이동 칸의 가장자리만 사용
  for dc,dr in [(1,0),(-1,0),(0,1),(0,-1)]:
   nc,nr=col+dc,row+dr
   outer=not(0<=nc<8 and 0<=nr<10) or tiles[nr*8+nc]=='blocked'
   if outer:
    for j in range(3):
     ox=dc*.84+(j-1)*.55*(not dc);oy=-dr*.84+(j-1)*.55*(not dr)
     block('exposed natural rock',(x+ox,y+oy,-.22),(random.uniform(.40,.64),random.uniform(.4,.6),.38),wall,row*71+col*17+j,.04)
  if kind=='build':
   for j in range(18):
    a=random.random()*math.tau;rr=random.uniform(.77,.95);px=x+math.cos(a)*rr;py=y+math.sin(a)*rr
    ico('moss edge',(px,py,.10),(random.uniform(.03,.085),random.uniform(.025,.07),.025),moss)
    if j%3==0:
     for k in range(3):
      ang=a+k;h=random.uniform(.06,.14)
      me=bpy.data.meshes.new('small grass');me.from_pydata([(px-.013,py,.08),(px+.013,py,.08),(px+math.cos(ang)*.06,py+math.sin(ang)*.06,h+.08)],[],[(0,1,2)]);me.materials.append(fern)
      o=bpy.data.objects.new('edge grass',me);s.collection.objects.link(o)
   if random.random()<.25:
    line('exposed root',[(x-.93,y-.43,.085),(x-.73,y-.26,.12),(x-.70,y+.05,.095),(x-.81,y+.3,.083)],.018,wood)

# 실제 로딩 예정 GLB를 같은 좌표·방향으로 배치

def import_asset(rel,name,loc,scale=2,angle=0):
 before=set(s.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/rel));created=set(s.objects)-before
 root=bpy.data.objects.new(name,None);s.collection.objects.link(root)
 for o in created:
  if o.parent not in created:o.parent=root
 root.location=loc;root.scale=(scale,)*3;root.rotation_euler.z=angle
 return root

# 환경 라이브러리의 포털·코어만 추출
before=set(s.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/images/stage1_3d/environment/terrain.glb'));lib=set(s.objects)-before
for rootname,col,row in [('portal',0,0),('core',6,9)]:
 root=next(o for o in lib if o.name==rootname)
 keep={root,*root.children_recursive}
 for o in keep:o.hide_render=False
 x,y=xy(col,row);root.location=(x,y,.095);root.scale=(2,)*3
 lib-=keep
for o in list(lib):bpy.data.objects.remove(o,do_unlink=True)
# 코어 발광의 면별 밝기·거칠기는 무광 결정 형태가 읽히는 수준
for o in s.objects:
 if 'core_emissive_crystal' in o.name:
  for slot in o.material_slots:
   if slot.material:
    m=slot.material.copy();slot.material=m;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Strength'].default_value=.45;p.inputs['Base Color'].default_value=(.02,.34,.43,1);p.inputs['Roughness'].default_value=.38
for name,col,row,angle in [('cannon',3,3,math.pi/2),('arrow',2,1,-math.pi/2),('frost',5,5,0)]:
 x,y=xy(col,row);import_asset('assets/images/stage1_3d/turrets/'+name+'.glb','placed '+name,(x,y,.10),2,angle)
for name,col,row,angle in [('normal',1,1.6,0),('armored',3.3,2,math.pi/2),('fast',4,3.3,0),('shielded',5.8,4,math.pi/2),('tank',4.7,6,-math.pi/2)]:
 x,y=xy(col,row);import_asset('assets/images/stage1_3d/enemies/'+name+'.glb','moving '+name,(x,y,.22),1.10 if name!='tank' else 1.3,angle)

world=bpy.data.worlds.new('chapter1 shaded daylight');world.use_nodes=True;s.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.11,.16,.18,1);world.node_tree.nodes['Background'].inputs[1].default_value=.33

def area(name,loc,power,size,col):
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=col
 o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
area('soft neutral sky',(-6,-2,18),2300,10,(.90,.94,1))
area('warm indirect sky',(8,6,13),1700,9,(1,.86,.66))
area('front fill',(1,-12,12),650,10,(.70,.83,1))
for name,col,row,color,power in [('portal light',0,0,(.45,.03,1),60),('core light',6,9,(.04,.65,1),95)]:
 x,y=xy(col,row);d=bpy.data.lights.new(name,'POINT');d.energy=power;d.color=color;d.shadow_soft_size=.9
 o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=(x,y,.7)
camd=bpy.data.cameras.new('chapter1 overview');cam=bpy.data.objects.new('chapter1 overview',camd);s.collection.objects.link(cam)
cam.location=(5,-13,27);focus=Vector((0,0,.1));cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=25.7;s.camera=cam
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=64;s.eevee.use_raytracing=True
s.render.resolution_x=1440;s.render.resolution_y=1600;s.render.resolution_percentage=100
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=.15
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'stage1-material-direction.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'stage1-material-direction.blend'))
bpy.ops.render.render(write_still=True)
print('STAGE1_DIRECTION_COMPLETE')
