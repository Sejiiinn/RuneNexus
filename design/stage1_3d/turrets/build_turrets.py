"""Game silhouette → real volumes; reuse approved matte cannon geometry."""
import bpy,bmesh,math,re,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus');OUT=ROOT/'assets/images/stage1_3d/turrets';WORK=ROOT/'design/stage1_3d/turrets'
scene=bpy.data.scenes.get('Stage1TurretLibrary') or bpy.data.scenes.new('Stage1TurretLibrary');bpy.context.window.scene=scene
for o in list(scene.objects): bpy.data.objects.remove(o,do_unlink=True)
source=(ROOT/'lib/game/rendering/turret_shape_renderer.dart').read_text()
def lin(c):
 v=[int(c[i:i+2],16)/255 for i in (0,2,4)];return tuple(t/12.92 if t<=.04045 else ((t+.055)/1.055)**2.4 for t in v)+(1,)
def mat(name,c,metal=.3,rough=.82,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=lin(c);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=lin(c);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;p.inputs['Emission Color'].default_value=lin(c);p.inputs['Emission Strength'].default_value=emit;return m
def empty(n,parent=None,loc=(0,0,0)):
 o=bpy.data.objects.new(n,None);scene.collection.objects.link(o);o.parent=parent;o.location=loc;return o
def finish(o,m,parent):
 o.data.materials.clear();o.data.materials.append(m);o.parent=parent
 return o
def cyl(n,r,d,loc,m,parent,axis='Z',verts=20):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d,location=loc);o=bpy.context.object;o.name=n
 if axis=='Y':o.rotation_euler.x=math.pi/2
 return finish(o,m,parent)
def poly(n,pts,bottom,top,m,parent,unit=.009):
 points=[(x*unit,y*unit) for x,y in pts];N=len(points);vs=[(x,y,z) for z in (bottom,top) for x,y in points];fs=[tuple(range(N-1,-1,-1)),tuple(range(N,N*2))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(vs,[],fs);mesh.update();bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
 o=bpy.data.objects.new(n,mesh);scene.collection.objects.link(o);finish(o,m,parent)
 bevel=o.modifiers.new('small cast edge','BEVEL');bevel.width=.008;bevel.segments=1
 return o
def sphere(n,loc,scale,m,parent):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object;o.name=n;o.scale=scale;return finish(o,m,parent)
roots={};metadata={}
# Mesh node names need exact spelling in every isolated GLB; rename only while exporting.
def export(kind,root,head,barrel,muzzle):
 bpy.context.view_layer.update()
 # Preserve transform hierarchy and consolidate each rigid group to 1 mesh.
 for group in (root,head,barrel):
  objs=[o for o in list(group.children) if o.type=='MESH']
  if len(objs)>1:
   bpy.ops.object.select_all(action='DESELECT')
   for o in objs:o.select_set(True)
   bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
 for o in (root,head,barrel,muzzle):o.name={root:'turret_root',head:'turret_head',barrel:'turret_barrel',muzzle:'muzzle'}[o]
 bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
 for o in root.children_recursive:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
 metadata[kind]={'bytes':(OUT/(kind+'.glb')).stat().st_size,'muzzleLocalBlender':list(muzzle.location),'headLocalBlender':list(head.location),'triangles':sum(len(p.vertices)-2 for o in root.children_recursive if o.type=='MESH' for p in o.data.polygons)}
 for o in (root,head,barrel,muzzle):o.name=kind+'_'+o.name
 roots[kind]=root
for kind,fn,accent in [('arrow','MachineGun','E7C66A'),('sniper','Sniper','B7F4FF'),('magic','Fire','FF5E3A'),('lightning','Lightning','CFA7FF')]:
 code=source.split('void _draw'+fn+'TurretShape(')[1].split('\nvoid ')[0]
 colors=dict(re.findall(r'final (\w+) = Paint\(\)\.\.color = const Color\(0xFF([0-9A-F]+)\)',code));colors.update(accent=accent,barrel=accent,muzzle=colors.get('muzzle',accent))
 mats={n:mat(kind+'_'+n,c,metal=.1 if n in ('accent','barrel') else .35) for n,c in colors.items()};mats['glow']=mat(kind+'_core',accent,0,.64,.55);mats['hot']=mat(kind+'_hot','F6F8E8',0,.5,.8)
 root=empty(kind);head=empty('head',root,(0,0,.27));barrel=empty('barrel',head);muzzle=empty('muzzle',barrel,(0,-.54,.18))
 if kind!='lightning':
  cyl('base',.395,.14,(0,0,.07),mats['base'],root,verts=16);cyl('bearing',.30,.11,(0,0,.19),mats.get('mount',mats.get('armor')),root)
 before=code.split('canvas.rotate(aimAngle')[0]
 for idx,m in enumerate(re.finditer(r'_drawLocalPolygon\(\s*canvas,\s*scale,\s*const \[(.*?)\],\s*(\w+),',code,re.S)):
  raw,role=m.groups()
  if role=='glow' or role not in mats:continue
  pts=[(float(a),float(b)) for a,b in re.findall(r'Offset\(\s*([\d.-]+),\s*([\d.-]+)\s*\)',raw)]
  if not pts:continue
  fixed=m.start()<len(before);group=root if fixed else head
  if fixed: bottom,top=(.03,.17) if role=='base' else (.17,.245)
  else:
   bottom,top=.0,.18
   if role in ('receiverPanel','carriagePanel','dark'):bottom,top=.18,.195
   elif role in ('barrel','muzzle','vent') or (role=='accent' and sum(y for x,y in pts)<0):group=barrel;bottom,top=.12,.26
  poly(kind+'_'+role+str(idx),pts,bottom,top,mats[role],group)
 if kind=='arrow':
  for x in [-.059,.059]:cyl('bore',.027,.004,(x,-.478,.19),mats['base'],barrel,axis='Y')
  cyl('central disk',.09,.03,(0,0,.22),mats['accent'],head)
 elif kind=='sniper':
  sphere('offset optic',(.207,-.117,.24),(.05,.035,.045),mats['hot'],head)
  cyl('bore',.027,.005,(0,-.524,.2),mats['base'],barrel,axis='Y');muzzle.location.y=-.53
 elif kind=='magic':
  sphere('ember', (0,.08,.25),(.16,.14,.18),mats['glow'],head)
  for i,(r,h,c) in enumerate([(.14,.46,mats['glow']),(.08,.34,mats['hot'])]):
   bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=r,radius2=0,depth=h,location=(0,.08,.39+h/2));finish(bpy.context.object,c,head)
  muzzle.location=(0,-.42,.22)
 elif kind=='lightning':
  for x in [-.165,.165]:
   for y in [-.279,-.144,-.009]:poly('coil',[(x/.009-11,y/.009-1.5),(x/.009+11,y/.009-1.5),(x/.009+11,y/.009+1.5),(x/.009-11,y/.009+1.5)],.19,.218,mats['glow'],head)
  poly('power core',[(-11,-11),(11,-11),(11,11),(-11,11)],.18,.24,mats['glow'],head);muzzle.location=(0,-.55,.19)
 export(kind,root,head,barrel,muzzle)
# Frost uses the existing radial crystal silhouette.
root=empty('frost');head=empty('head',root,(0,0,.26));barrel=empty('barrel',head);muzzle=empty('muzzle',barrel,(0,0,.43))
base=mat('frost_base','1A2533');ice=mat('frost_crystal','7FD8FF',.08,.57,.35);hot=mat('frost_core','E8FBFF',0,.5,.75)
cyl('frost_foot',.38,.15,(0,0,.075),base,root);cyl('frost_mount',.28,.12,(0,0,.2),base,root)
sphere('frost diamond',(0,0,.29),(.23,.23,.39),ice,head)
for i in range(6):
 a=i*math.tau/6;sphere('frost radial',(.28*math.cos(a),.28*math.sin(a),.13),(.06,.06,.17),ice,head)
sphere('frost inner',(0,-.20,.27),(.085,.035,.12),hot,head);export('frost',root,head,barrel,muzzle)
# Cannon: reuse the actual approved matte source, convert modifiers, retain rigid groups.
p=ROOT/'design/high_fidelity_battlefield/cannon_material_refinement/battlefield-cannon-matte.blend'
with bpy.data.libraries.load(str(p),link=False) as (src,dst):dst.objects=src.objects
loaded=[o for o in dst.objects if o];old=next(o for o in loaded if o.name.startswith('Cannon_Root'));kids=list(old.children_recursive)
oldhead=next(o for o in kids if 'HF_조준_회전' in o.name);oldbarrel=next(o for o in kids if 'HF_포신_반동' in o.name)
for o in [old]+kids:o.animation_data_clear()
old.location=(0,0,0);old.rotation_euler=(0,0,0);old.scale=(1,1,1);oldhead.rotation_euler=(0,0,0);oldbarrel.location=(0,0,0)
for o in [old]+kids:scene.collection.objects.link(o)
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
root=empty('cannon');head=empty('head',root,(0,0,.30));barrel=empty('barrel',head);muzzle=empty('muzzle',barrel,(0,-.64,.27))
orange=mat('cannon_matte_orange','B7652C',.025,.89);steel=mat('cannon_cast_steel','454745',.52,.79);rim=mat('cannon_worn_edges','887D6C',.45,.77);bore=mat('cannon_bore','0D0A08',.05,.95);rune=mat('cannon_rune','DDD3B5',.1,.73)
rot=Matrix.Rotation(-math.pi/2,4,'Z');factor=.62
barrelset=set(oldbarrel.children_recursive);headset=set(oldhead.children_recursive)
for o in kids:
 if o.type not in {'MESH','CURVE'}:continue
 e=o.evaluated_get(dg);mesh=bpy.data.meshes.new_from_object(e);group=barrel if o in barrelset else head if o in headset else root
 for v in mesh.vertices:
  v.co=rot@(o.matrix_world@v.co);v.co*=factor;v.co.z-=.105
  if group!=root:v.co.z-=.30
 ob=bpy.data.objects.new('cannon_'+o.name,mesh);scene.collection.objects.link(ob);ob.parent=group
 for i,slot in enumerate(ob.material_slots):
  name=slot.material.name if slot.material else '';slot.material=orange if 'ORANGE' in name else rune if 'ivory' in name else rim if 'rim' in name else bore if 'bore' in name else steel
# Unlink imported source assets from this scene only; no changes to originals.
for o in [old]+kids:scene.collection.objects.unlink(o)
# Mobile atlas: bake cast grain and paint variation into ordinary glTF textures.
meshes=[o for o in root.children_recursive if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for ob in meshes:ob.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.1,island_margin=.018);bpy.ops.object.mode_set(mode='OBJECT')
materials=set(slot.material for ob in meshes for slot in ob.material_slots if slot.material)
atlas=bpy.data.images.new('cannon_cast_normal',width=512,height=512);atlas.colorspace_settings.name='Non-Color'
coloratlas=bpy.data.images.new('cannon_matte_color',width=512,height=512)
for m in materials:
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');base=tuple(p.inputs['Base Color'].default_value)
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=115;noise.inputs['Detail'].default_value=2
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.3;bump.inputs['Distance'].default_value=.012;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
 coarse=n.new('ShaderNodeTexNoise');coarse.inputs['Scale'].default_value=24;coarse.inputs['Detail'].default_value=3
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=tuple(c*.65 for c in base[:3])+(1,);ramp.color_ramp.elements[1].color=tuple(min(1,c*1.14) for c in base[:3])+(1,);l.new(coarse.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs['Color'],p.inputs['Base Color'])
 tex=n.new('ShaderNodeTexImage');tex.name='BAKE_TARGET';tex.image=atlas;n.active=tex
scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.bake.use_clear=False;scene.render.bake.margin=4
bpy.ops.object.bake(type='NORMAL')
for m in materials:m.node_tree.nodes['BAKE_TARGET'].image=coloratlas
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
bpy.ops.object.bake(type='DIFFUSE')
for im in [atlas,coloratlas]:im.pack()
for m in materials:
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');tex=n['BAKE_TARGET'];l.new(tex.outputs['Color'],p.inputs['Base Color'])
 normaltex=n.new('ShaderNodeTexImage');normaltex.image=atlas;normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.6;l.new(normaltex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs['Normal'])
export('cannon',root,head,barrel,muzzle)

(WORK/'manifest.json').write_text(json.dumps(metadata,indent=2))
# Gallery verification.
for i,root in enumerate(roots.values()):root.location=((i%3-1)*1.8,(i//3)*2.0,0)
floor=mat('gallery_moss','304B3C',0,.95);bpy.ops.mesh.primitive_plane_add(size=200);finish(bpy.context.object,floor,None);bpy.context.object.location.z=-.02
world=bpy.data.worlds.new('TurretGallery');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.16,.20,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.world=world
for name,loc,power,size,color in [('key',(-3,-4,7),1050,5,(1,.93,.81)),('fill',(4,-1,5),750,4,(.67,.86,1))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,1,.3))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('TurretGallery');cam=bpy.data.objects.new('TurretGallery',d);scene.collection.objects.link(cam);cam.location=(3,-7,8);cam.rotation_euler=(Vector((0,1,.1))-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=6.5;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1300;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(WORK/'turret-library-preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'chapter-one-turrets.blend'));print(json.dumps(metadata))
