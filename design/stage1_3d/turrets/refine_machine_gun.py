"""현행 2D 기관총의 리시버·후방 탄창·쌍열 비례를 유지한 3D 개선."""
import bpy, bmesh, math, re, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus');WORK=ROOT/'design/stage1_3d/turrets';OUT=ROOT/'assets/images/stage1_3d/turrets/arrow.glb'
s=bpy.data.scenes.new('Stage1_MachineGun_Refined');bpy.context.window.scene=s
source=(ROOT/'lib/game/rendering/turret_shape_renderer.dart').read_text().split('void _drawMachineGunTurretShape(')[1].split('\nvoid ')[0]
colors=dict(re.findall(r'final (\w+) = Paint\(\)\.\.color = const Color\(0xFF([0-9A-F]+)\)',source))
colors.update(accent='E7C66A',edge='909899',dark='10191F')

def linear(h):
 v=[int(h[i:i+2],16)/255 for i in (0,2,4)];return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v)+(1,)
def material(name,h,metal,rough):
 m=bpy.data.materials.new('MG2_'+name);m.use_nodes=True;m.diffuse_color=linear(h);n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
 p.inputs['Base Color'].default_value=linear(h);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 # 도장과 주조 금속의 미세 요철·불규칙한 표면색
 fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=180;fine.inputs['Detail'].default_value=2
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.004;l.new(fine.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=25;noise.inputs['Detail'].default_value=3
 ramp=n.new('ShaderNodeValToRGB');base=linear(h);ramp.color_ramp.elements[0].color=tuple(c*.73 for c in base[:3])+(1,);ramp.color_ramp.elements[1].color=tuple(min(1,c*1.10) for c in base[:3])+(1,)
 l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs['Color'],p.inputs['Base Color'])
 return m
mats={name:material(name,h,.7 if name in ['accent','edge','muzzle'] else .28,.59 if name=='accent' else .70) for name,h in colors.items()}
def empty(name,parent=None,loc=(0,0,0)):
 o=bpy.data.objects.new(name,None);s.collection.objects.link(o);o.parent=parent;o.location=loc;return o
root=empty('turret_root');head=empty('turret_head',root,(0,0,.235));barrel=empty('turret_barrel',head);muzzle=empty('muzzle',barrel,(0,-.507,.18))

def finish(o,name,m,parent,bevel=.008):
 o.name=name;o.parent=parent;o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('정밀_면취','BEVEL');mod.width=bevel;mod.segments=3
  o.modifiers.new('면_법선','WEIGHTED_NORMAL')
 return o

def cylinder(name,loc,r,depth,m,parent,axis='Z',verts=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc);o=bpy.context.object
 if axis=='Y':o.rotation_euler.x=math.pi/2
 return finish(o,name,m,parent)

def plate(name,pts,bottom,top,m,parent,unit=.0095,bevel=.012):
 points=[(x*unit,y*unit) for x,y in pts];N=len(points)
 # 상부 둘레를 조금 좁혀 평평한 프리즘 대신 경사진 주조 측면 형성
 vs=[(x,y,bottom) for x,y in points]+[(x*.94,y*.97,top) for x,y in points]
 fs=[tuple(reversed(range(N))),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
 o=bpy.data.objects.new(name,me);s.collection.objects.link(o);return finish(o,name,m,parent,bevel)

def box(name,loc,size,m,parent,bevel=.007):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m,parent,bevel)

def tube(name,x,z,profile,m,parent):
 N=32;vs=[(x+math.cos(i*math.tau/N)*r,y,z+math.sin(i*math.tau/N)*r) for y,r in profile for i in range(N)]
 fs=[(j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(len(profile)-1) for i in range(N)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);o=bpy.data.objects.new(name,me);s.collection.objects.link(o)
 for f in me.polygons:f.use_smooth=True
 return finish(o,name,m,parent,.003)

# 기존 원형 받침을 낮춰 위쪽 기관총 본체가 주된 실루엣이 되게 함
cylinder('낮은_고정_받침',(0,0,.064),.40,.125,mats['base'],root)
cylinder('청회색_회전_마운트',(0,0,.157),.314,.072,mats['mount'],root)
cylinder('회전_베어링_틈',(0,0,.210),.258,.028,mats['dark'],root)
polyroles=[]
for match in re.finditer(r'_drawLocalPolygon\(\s*canvas,\s*scale,\s*const \[(.*?)\],\s*(\w+),',source,re.S):
 pts=[(float(x),float(y)) for x,y in re.findall(r'Offset\(\s*([\d.-]+),\s*([\d.-]+)\s*\)',match[1])];polyroles.append((match[2],pts))
for i,(role,pts) in enumerate(polyroles):
 if role=='armor':plate('원형받침_측면_장갑',pts,.085,.20,mats[role],root)
 elif role=='receiver':
  plate('본체_하부_강철_리시버',pts,0,.245,mats[role],head,bevel=.021)
 elif role=='receiverPanel':
  plate('리시버_상판_홈',pts,.246,.270,mats[role],head,bevel=.009)
 elif role=='magazine':
  plate('후방_탄창',pts,-.01,.17,mats[role],head,bevel=.018)
# 본체 앞에서 시작하는 실제 원통 총열. 뒤쪽은 리시버 안에 매립
for side in [-1,1]:
 x=side*.062
 tube('쌍열_강철_몸통',x,.168,[(-.125,.040),(-.26,.040),(-.43,.036),(-.494,.038),(-.494,.023),(-.26,.023)],mats['accent'],barrel)
 for y in [-.255,-.337]:
  tube('총열_띠',x,.168,[(y-.012,.043),(y+.012,.043)],mats['muzzle'],barrel)
 tube('가공된_포구',x,.168,[(-.427,.039),(-.445,.051),(-.505,.051),(-.518,.044),(-.518,.023),(-.49,.023)],mats['muzzle'],barrel)
 cylinder('총구_안쪽_어둠',(x,-.30,.168),.023,.008,mats['dark'],barrel,'Y')
 # 원본의 후방 탄창과 본체를 구분하는 낮은 경계·체결부
 box('본체_측면_선',(side*.158,-.018,.20),(.016,.20,.018),mats['edge'],head,.003)
 for y in [-.11,.13]:cylinder('리시버_체결부',(side*.136,y,.252),.012,.012,mats['edge'],head,verts=6)
cylinder('원본_황동_중앙_원판',(0,0,.280),.071,.018,mats['accent'],head)
cylinder('중앙_원판_음각',(0,0,.291),.045,.006,mats['receiverPanel'],head)
for x in [-.06,0,.06]:box('탄창_세로_홈',(x,.229,.171),(.012,.075,.009),mats['dark'],head,.002)

# 3D 게임에서도 동일한 재질이 보이도록 공유 아틀라스에 베이크
meshes=[o for o in root.children_recursive if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.convert(target='MESH')
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.1,island_margin=.013);bpy.ops.object.mode_set(mode='OBJECT')
materials=set(slot.material for o in meshes for slot in o.material_slots if slot.material)
normal=bpy.data.images.new('machine_gun_cast_normal',width=1024,height=1024);normal.colorspace_settings.name='Non-Color'
color=bpy.data.images.new('machine_gun_matte_color',width=1024,height=1024)
for m in materials:
 n=m.node_tree.nodes;target=n.new('ShaderNodeTexImage');target.name='BAKE_TARGET';target.image=normal;n.active=target
s.render.engine='CYCLES';s.cycles.samples=8;s.render.bake.use_clear=False;s.render.bake.margin=5
bpy.ops.object.bake(type='NORMAL')
for m in materials:m.node_tree.nodes['BAKE_TARGET'].image=color
s.render.bake.use_pass_direct=False;s.render.bake.use_pass_indirect=False;s.render.bake.use_pass_color=True
bpy.ops.object.bake(type='DIFFUSE')
for im in [color,normal]:im.pack()
for m in materials:
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');l.new(n['BAKE_TARGET'].outputs['Color'],p.inputs['Base Color'])
 tex=n.new('ShaderNodeTexImage');tex.image=normal;nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.7;l.new(tex.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
for group in [root,head,barrel]:
 children=[o for o in group.children if o.type=='MESH']
 if len(children)>1:
  bpy.ops.object.select_all(action='DESELECT')
  for o in children:o.select_set(True)
  bpy.context.view_layer.objects.active=children[0];bpy.ops.object.join()
bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
for o in root.children_recursive:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'machine-gun-refined.blend'))
(WORK/'machine-gun-refined.json').write_text(json.dumps({'bytes':OUT.stat().st_size,'triangles':sum(len(p.vertices)-2 for o in root.children_recursive if o.type=='MESH' for p in o.data.polygons),'source':'drawMachineGunTurretShape','root':'turret_root','head':'turret_head','barrel':'turret_barrel','muzzle':'muzzle','forward':'+Z glTF','up':'+Y glTF'},indent=2))
print('MACHINE_GUN_REFINED')
