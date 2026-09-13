"""Blender authored chapter-2 props. --export-only reads blend without regeneration."""
import bpy, bmesh, math, random, sys, json
from pathlib import Path
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=ROOT/'assets/images/stage1_3d/environment/chapter2_props.glb'
random.seed(27)
def material(name,color,rough=.8,metal=0,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
def mesh(name,v,f,mat,parent=None):
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(mat);o.parent=parent;return o
def colors(o,base,crystal=False):
 ca=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
 zs=[v.co.z for v in o.data.vertices];lo,hi=min(zs),max(zs)
 for p in o.data.polygons:
  fac=(random.uniform(.9,1.1)*(1.8 if p.area<.00010 else 1)) if not crystal else random.uniform(.84,1.16)
  for li in p.loop_indices:
   v=o.data.vertices[o.data.loops[li].vertex_index].co
   if crystal:
    t=max(0,min(1,((v.z-lo)/(hi-lo)-.52)/.48));t=t**1.15
    a=(.14,.008,.29);b=(.15,.68,.83);c=[a[i]*(1-t)+b[i]*t for i in range(3)]
    fac2=1
   else:c=base;fac2=.91+.16*noise.noise_vector(v*83).x
   ca.data[li].color=(*[max(0,min(1,x*fac*fac2)) for x in c],(.42*(1-t)+.34*t) if crystal else 1)
def bevel(o,width=.009):
 mod=o.modifiers.new('Hand chipped edge bevel','BEVEL');mod.width=width;mod.segments=2
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
def stone(name,c,s,parent,seed=0):
 # Eight irregular corners, three strata; chipped oblique walls and uneven upper rim.
 rr=random.Random(seed+219)
 v=[]
 for axis in range(3):
  for sign in (-1,1):
   for k in range(11):
    q=[rr.uniform(-.49,.49) for _ in range(3)];q[axis]=sign*rr.uniform(.39,.50)
    v.append(tuple(c[j]+q[j]*s[j] for j in range(3)))
 bm=bmesh.new()
 for q in v:bm.verts.new(q)
 bm.verts.ensure_lookup_table();bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
 me=bpy.data.meshes.new(name);bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(STONE);o.parent=parent
 bevel(o,min(s)*.013);colors(o,(.052,.069,.091));uv(o);return o

def uv(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
 for d in o.data.uv_layers.active.data:d.uv*=1.5
def stroke(name,points,radius,mat,parent):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=1;cu.bevel_depth=radius;cu.bevel_resolution=1;cu.use_fill_caps=True;s=cu.splines.new('POLY');s.points.add(len(points)-1)
 for a,b in zip(s.points,points):a.co=(*b,1)
 o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);o.parent=parent;cu.materials.append(mat);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False);return o
def crystal(name,c,r,h,parent,tilt=0):
 rr=random.Random(name);n=6;v=[]
 angles=[i*math.tau/n+rr.uniform(-.10,.10) for i in range(n)]
 for i,a in enumerate(angles):v.append((math.cos(a)*r*.57,math.sin(a)*r*.57,rr.uniform(0,.035)*h))
 for i,a in enumerate(angles):
  z=rr.uniform(.51,.77);radius=r*rr.uniform(.80,1.12);v.append((math.cos(a)*radius+tilt*z,math.sin(a)*radius,z*h))
 v.append((tilt+r*.16,-r*.12,h));f=[tuple(range(5,-1,-1))]
 for i in range(n):
  j=(i+1)%n;f.append((i,j,6+j,6+i));f.append((6+i,6+j,12))
 o=mesh(name,v,f,CRYSTAL,parent);colors(o,(1,1,1),True);o.location=c;boundary=BVHTree.FromPolygons([Vector(q) for q in v],f)
 # Irregular internal cleavage planes, physically separated in depth.
 if name.startswith('cluster_'):
  for layer in range(14):
   z0=rr.uniform(.01,.15);zt=rr.uniform(.53,.90);xx=rr.uniform(-.57,.57)*r;yy=rr.uniform(-.48,.48)*r;w=rr.uniform(.14,.24)*r
   vv=[(xx-w,yy,z0*h),(xx+w,yy+.09*r,(z0+.04)*h),(xx+w*.65+tilt*zt,yy+.02*r,(zt-.08)*h),(xx+tilt*zt,yy,zt*h),(xx-w*.72+tilt*zt,yy-.06*r,(zt-.14)*h)]
   vv=[(x*min(.80,(1-z/h)/.32),y*min(.80,(1-z/h)/.32),z) for x,y,z in vv]
   vv+= [(x,y+.065*r,z) for x,y,z in vv]
   confined=[]
   for q in vv:
    pos=Vector(q);pos.z=max(pos.z,.045*h);center=Vector((tilt*(pos.z/h),0,pos.z));direction=pos-center
    if direction.length>.00001:
     hit,normal,index,distance=boundary.ray_cast(center,direction.normalized(),r*4)
     if hit is not None and direction.length>distance*.88:pos=center+direction.normalized()*distance*.88
    confined.append(tuple(pos))
   vv=confined;ff=[(0,1,2,3,4),(5,9,8,7,6)]+[(j,(j+1)%5,(j+1)%5+5,j+5) for j in range(5)]
   inn=mesh(name+'_mineral_layer_%d'%layer,vv,ff,MINERAL,parent);inn.location=c
   ca=inn.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
   for po in inn.data.polygons:
    fac=rr.uniform(.45,1.55)
    for li in po.loop_indices:
     q=inn.data.vertices[inn.data.loops[li].vertex_index].co;t=max(0,min(1,(q.z/h-.52)/.48));ca.data[li].color=((.12*(1-t)+.14*t)*fac,(.008*(1-t)+.53*t)*fac,(.30*(1-t)+.72*t)*fac,1)
   uv(inn)

 uv(o)

 return o
def clip(poly,a,b,c):
 out=[]
 for p,q in zip(poly,poly[1:]+poly[:1]):
  dp=a*p[0]+b*p[1]-c;dq=a*q[0]+b*q[1]-c
  if dp<=0:out.append(p)
  if (dp<0)!=(dq<0):
   t=dp/(dp-dq);out.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])))
 return out
def cells(bound,seeds):
 result=[]
 for i,p in enumerate(seeds):
  poly=list(bound)
  for j,q in enumerate(seeds):
   if i==j:continue
   poly=clip(poly,q[0]-p[0],q[1]-p[1],(q[0]**2+q[1]**2-p[0]**2-p[1]**2)/2)
   if len(poly)<3:break
  if len(poly)>=3:result.append(poly)
 return result
def rockpoly(name,poly,bottom,top,parent,vertical=False):
 cx=sum(p[0] for p in poly)/len(poly);cy=sum(p[1] for p in poly)/len(poly)
 refined=[]
 for aa,bb in zip(poly,poly[1:]+poly[:1]):
  refined.append(aa);length=math.hypot(bb[0]-aa[0],bb[1]-aa[1])
  if length>.075:
   for tt in (.32,.68):
    xx=aa[0]+tt*(bb[0]-aa[0]);yy=aa[1]+tt*(bb[1]-aa[1]);sh=random.uniform(.005,.024);refined.append((xx+(cx-xx)*sh,yy+(cy-yy)*sh))
 poly=refined;n=len(poly);v=[]
 for k,(z,sc) in enumerate(((bottom,.90),(bottom+.018,.98),(top-.012,.99),(top,.95))):
  for x,y in poly:
   sc2=sc-random.uniform(0,.014);xx=cx+(x-cx)*sc2;yy=cy+(y-cy)*sc2
   v.append((xx,z,yy) if vertical else (xx,yy,z))
 f=[tuple(range(n-1,-1,-1)),tuple(range(3*n,4*n))]
 for k in range(3):
  for i in range(n):f.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
 o=mesh(name,v,f,STONE,parent);bevel(o,.0015);colors(o,(.055,.073,.098));uv(o);return o
def root(name):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);return o
def export():
 bpy.ops.object.select_all(action='DESELECT');duplicates=[]
 for name in ('rune_pillar','crystal_cluster','void_fissure'):
  o=bpy.data.objects[name];o.location=(0,0,0);groups={}
  for ch in list(o.children_recursive):
   if ch.type!='MESH':continue
   # Keep transparency ordering per crystal, batch static opaque geometry by material.
   key=ch.name.split('_mineral_layer_')[0]+'_inner' if '_mineral_layer_' in ch.name else ch.name if ch.data.materials[0].name.startswith('ch2_crystal_') else ch.data.materials[0].name
   dup=ch.copy();dup.data=ch.data.copy();bpy.context.collection.objects.link(dup);groups.setdefault(key,[]).append(dup)
  for key,items in groups.items():
   bpy.ops.object.select_all(action='DESELECT')
   for ch in items:ch.select_set(True)
   bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=name+'__'+key;duplicates.append(ob)
 bpy.ops.object.select_all(action='DESELECT')
 for name in ('rune_pillar','crystal_cluster','void_fissure'):bpy.data.objects[name].select_set(True)
 for ob in duplicates:ob.select_set(True)
 OUT.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_materials='EXPORT',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,export_extras=True,export_cameras=False,export_lights=False)
 for ob in duplicates:bpy.data.objects.remove(ob,do_unlink=True)
def setup_studio():
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=40;scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
 scene.world.color=(.17,.17,.17);scene.world.use_nodes=True;wn=scene.world.node_tree.nodes;wl=scene.world.node_tree.links
 coord=wn.new('ShaderNodeTexCoord');sep=wn.new('ShaderNodeSeparateXYZ');wl.new(coord.outputs['Normal'],sep.inputs[0]);mathn=wn.new('ShaderNodeMath');mathn.operation='MULTIPLY_ADD';mathn.inputs[1].default_value=.5;mathn.inputs[2].default_value=.5;wl.new(sep.outputs['Z'],mathn.inputs[0]);ra=wn.new('ShaderNodeValToRGB');ra.color_ramp.elements.remove(ra.color_ramp.elements[1]);ra.color_ramp.elements[0].position=0;ra.color_ramp.elements[0].color=(.07,.09,.13,1)
 for pos,col in [(.22,(.07,.09,.13,1)),(.29,(1.4,1.5,1.7,1)),(.36,(.08,.10,.14,1)),(.66,(.08,.10,.14,1)),(.78,(1.4,1.5,1.7,1)),(.9,(.12,.15,.20,1))]:ra.color_ramp.elements.new(pos).color=col
 wl.new(mathn.outputs[0],ra.inputs[0]);wl.new(ra.outputs[0],wn.get('Background').inputs['Color']);wn.get('Background').inputs['Strength'].default_value=.5;scene.view_settings.view_transform='AgX'
 bpy.ops.object.camera_add(location=(2,-3,2.5));cam=bpy.context.object;cam.name='Studio camera';cam.rotation_euler=(Vector((0,0,.42))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.62;scene.camera=cam
 for name,loc,power,size,col in [('key',(-3,-4,5),430,3.4,(1,.91,.81)),('fill',(3,-1,3),280,3,(.7,.84,1)),('rim',(0,3,4),550,2,(.81,.89,1))]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name='Studio '+name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=col;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.mesh.primitive_plane_add(size=200);o=bpy.context.object;o.name='Studio floor';o.visible_glossy=False;o.data.materials.append(material('studio charcoal',(.027,.03,.035),.85));o.location.z=-.013
def render_props():
 scene=bpy.context.scene
 for name in ('rune_pillar','crystal_cluster','void_fissure'):
  for n in ('rune_pillar','crystal_cluster','void_fissure'):
   for ch in bpy.data.objects[n].children_recursive:ch.hide_render=n!=name
  cam=scene.camera;target=Vector((0,0,.51 if name=='rune_pillar' else .26 if name=='crystal_cluster' else .02));cam.location=target+Vector((1.7,-2.7,2.3));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.5 if name=='rune_pillar' else 1.05 if name=='crystal_cluster' else 1.30
  floor=bpy.data.objects['Studio floor'];floor.location.z=-.18 if name=='void_fissure' else -.013
  if any(o.name.startswith('floating_ground') for o in bpy.data.objects[name].children_recursive):
   pts=[o.matrix_world@Vector(v) for o in bpy.data.objects[name].children_recursive if o.type=='MESH' for v in o.bound_box];low=min(v.z for v in pts);high=max(v.z for v in pts);width=max(max(v.x for v in pts)-min(v.x for v in pts),max(v.y for v in pts)-min(v.y for v in pts))
   target=Vector((0,0,(low+high)/2));cam.location=target+Vector((1.7,-2.7,2.3));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=max(1.75,(high-low)*1.2+width*.35);floor.location.z=low-.20
  scene.render.filepath=str(HERE/(name+'-studio.png'));bpy.ops.render.render(write_still=True)
 for n in ('rune_pillar','crystal_cluster','void_fissure'):
  for ch in bpy.data.objects[n].children_recursive:ch.hide_render=False

if '--export-only' in sys.argv:
 bpy.ops.wm.open_mainfile(filepath=str(HERE/'chapter2_props.blend'));export()
 if '--render' in sys.argv:render_props()
 sys.exit()
if (HERE/'chapter2_props.blend').exists() and '--regenerate' not in sys.argv:
 raise SystemExit('Preserve edited source: use --export-only, or explicit --regenerate after backup.')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
STONE=material('ch2_weathered_slate', (1,1,1),.83)
CRYSTAL=material('ch2_crystal_mineral_facets',(1,1,1),.13,0)
CRYSTAL.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=1
CRYSTAL.surface_render_method='DITHERED'
MINERAL=CRYSTAL.copy();MINERAL.name='ch2_crystal_internal_mineral';MINERAL.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.89;MINERAL.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.20
CRYSTAL.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.28
for m in (STONE,CRYSTAL,MINERAL):
 n=m.node_tree.nodes.new('ShaderNodeVertexColor');n.layer_name='Color';m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
 if m==CRYSTAL:m.node_tree.links.new(n.outputs['Alpha'],m.node_tree.nodes.get('Principled BSDF').inputs['Alpha'])
BRASS=material('ch2_antiqued_brass',(.26,.18,.085),.43,.82)
RUNE=material('ch2_teal_inset_rune',(.035,.43,.48),.30,.28,.28)
VOID=material('ch2_deep_violet_fissure',(.014,.002,.035),.65,0,.12)
GLOW=material('ch2_violet_depth_mineral',(.09,.008,.24),.5,0,.48)

# Bake a tiling physical stone microrelief in Blender. GLB receives actual texture,
# not an unsupported procedural node graph; no baked lighting or specular highlights.
bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=8
bpy.ops.mesh.primitive_plane_add(size=1);bakeplane=bpy.context.object
bm=material('BAKE_ONLY_stone_relief',(.5,.5,.5));bakeplane.data.materials.append(bm)
nt=bm.node_tree;n=nt.nodes;l=nt.links;p=n.get('Principled BSDF')
tc=n.new('ShaderNodeTexCoord');no=n.new('ShaderNodeTexNoise');no.inputs['Scale'].default_value=70;no.inputs['Detail'].default_value=4;l.new(tc.outputs['UV'],no.inputs['Vector'])
vo=n.new('ShaderNodeTexVoronoi');vo.feature='DISTANCE_TO_EDGE';vo.inputs['Scale'].default_value=7;l.new(tc.outputs['UV'],vo.inputs['Vector'])
mix=n.new('ShaderNodeMath');mix.operation='MULTIPLY';l.new(no.outputs['Fac'],mix.inputs[0]);l.new(vo.outputs['Distance'],mix.inputs[1])
bu=n.new('ShaderNodeBump');bu.inputs['Strength'].default_value=.65;bu.inputs['Distance'].default_value=.032;l.new(mix.outputs[0],bu.inputs['Height']);l.new(bu.outputs[0],p.inputs['Normal'])
# Reuse the already approved natural rock surface, sampled from one broad face.
coord=n.new('ShaderNodeVectorMath');coord.operation='MULTIPLY_ADD';coord.inputs[1].default_value=(.24,.24,.24);coord.inputs[2].default_value=(.51,.54,0);l.new(tc.outputs['UV'],coord.inputs[0])
rock=n.new('ShaderNodeTexImage');rock.image=bpy.data.images.load(str(ROOT/'design/stage1_3d/environment/approved_textures/C1_natural_rock_faces_basecolor.png'),check_existing=True);rock.image.pack();l.new(coord.outputs[0],rock.inputs['Vector'])
gray=n.new('ShaderNodeRGBToBW');l.new(rock.outputs[0],gray.inputs[0])
rn=n.new('ShaderNodeTexImage');rn.image=bpy.data.images.load(str(ROOT/'design/stage1_3d/environment/approved_textures/C1_natural_rock_faces_normal.png'),check_existing=True);rn.image.colorspace_settings.name='Non-Color';rn.image.pack();l.new(coord.outputs[0],rn.inputs['Vector'])
rnm=n.new('ShaderNodeNormalMap');rnm.inputs['Strength'].default_value=.65;l.new(rn.outputs['Color'],rnm.inputs['Color']);l.new(rnm.outputs[0],bu.inputs['Normal']);bu.inputs['Strength'].default_value=.15;bu.inputs['Distance'].default_value=.001
im=bpy.data.images.new('chapter2_stone_normal',width=512,height=512);im.colorspace_settings.name='Non-Color';it=n.new('ShaderNodeTexImage');it.image=im;n.active=it
bpy.ops.object.bake(type='NORMAL',margin=8);im.filepath_raw=str(HERE/'stone-normal.png');im.file_format='PNG';im.save();im.pack()
al=bpy.data.images.new('chapter2_stone_albedo',width=512,height=512);it.image=al
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.25;ramp.color_ramp.elements[0].color=(.30,.33,.37,1);ramp.color_ramp.elements[1].position=.75;ramp.color_ramp.elements[1].color=(1.0,.93,.83,1);l.new(gray.outputs[0],ramp.inputs[0]);ramp.color_ramp.elements[0].position=.03;ramp.color_ramp.elements[0].color=(.26,.28,.33,1);ramp.color_ramp.elements[1].position=.38;ramp.color_ramp.elements[1].color=(1.65,1.65,1.65,1)
er=n.new('ShaderNodeValToRGB');er.color_ramp.elements[0].position=.013;er.color_ramp.elements[0].color=(.12,.12,.12,1);er.color_ramp.elements[1].position=.038;er.color_ramp.elements[1].color=(1,1,1,1);l.new(vo.outputs['Distance'],er.inputs[0])
mx=n.new('ShaderNodeMixRGB');mx.blend_type='MULTIPLY';mx.inputs[0].default_value=.35;l.new(ramp.outputs[0],mx.inputs[1]);l.new(er.outputs[0],mx.inputs[2])
em=n.new('ShaderNodeEmission');l.new(mx.outputs[0],em.inputs['Color']);l.new(em.outputs[0],n.get('Material Output').inputs['Surface']);n.active=it;bpy.ops.object.bake(type='EMIT',margin=8);al.filepath_raw=str(HERE/'stone-albedo.png');al.file_format='PNG';al.save();al.pack()
# A separate mineral-fracture albedo bake; this records mineral inclusions only.
l.new(no.outputs['Fac'],ramp.inputs[0])
ci=bpy.data.images.new('chapter2_mineral_inclusions',width=512,height=512);it.image=ci;no.inputs['Scale'].default_value=7;no.inputs['Detail'].default_value=5;vo.inputs['Scale'].default_value=9
ramp.color_ramp.elements[0].position=.28;ramp.color_ramp.elements[0].color=(.18,.20,.28,1);ramp.color_ramp.elements[1].position=.70;ramp.color_ramp.elements[1].color=(1.0,1.0,1.0,1);mx.inputs[0].default_value=0
er.color_ramp.elements[0].position=.008;er.color_ramp.elements[0].color=(.9,.9,1,1);er.color_ramp.elements[1].position=.035;er.color_ramp.elements[1].color=(.3,.4,.55,1)
bpy.ops.object.bake(type='EMIT',margin=8);ci.filepath_raw=str(HERE/'mineral-inclusions.png');ci.file_format='PNG';ci.save();ci.pack()
for mat in (MINERAL,):
 cn=mat.node_tree.nodes;cl=mat.node_tree.links;tx=cn.new('ShaderNodeTexImage');tx.image=ci;mul=cn.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1;vc=next(q for q in cn if q.type=='VERTEX_COLOR');cl.new(vc.outputs['Color'],mul.inputs[1]);cl.new(tx.outputs['Color'],mul.inputs[2]);cl.new(mul.outputs[0],cn.get('Principled BSDF').inputs['Base Color'])
bpy.data.objects.remove(bakeplane,do_unlink=True)
sn=STONE.node_tree.nodes;sl=STONE.node_tree.links;tex=sn.new('ShaderNodeTexImage');tex.image=im;nm=sn.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.25;sl.new(tex.outputs['Color'],nm.inputs['Color']);sl.new(nm.outputs['Normal'],sn.get('Principled BSDF').inputs['Normal'])
texc=sn.new('ShaderNodeTexImage');texc.image=al;cm=sn.new('ShaderNodeMixRGB');cm.blend_type='MULTIPLY';cm.inputs[0].default_value=1;sl.new(sn.get('Color Attribute').outputs['Color'] if sn.get('Color Attribute') else next(q for q in sn if q.type=='VERTEX_COLOR').outputs['Color'],cm.inputs[1]);sl.new(texc.outputs['Color'],cm.inputs[2]);sl.new(cm.outputs[0],sn.get('Principled BSDF').inputs['Base Color'])

# Chipped stone monolith: layered asymmetrical columns, deep gaps, sheltered rune engraving.
p=root('rune_pillar')
for i,(x,y,sx,sy) in enumerate([(-.17,-.10,.28,.36),(.145,-.10,.30,.36),(-.16,.17,.27,.20),(.14,.17,.29,.20)]):stone('pillar_foot_%02d'%i,(x,y,.085),(sx,sy,.17),p,i)
pillar_bound=[(-.20,.17),(.20,.17),(.20,.72),(.15,.83),(.11,.94),(.04,.99),(.02,1.13),(-.20,1.15)]
pillar_seeds=[(-.13,.27),(.10,.27),(-.13,.43),(.10,.40),(-.12,.64),(.08,.60),(.12,.79),(-.13,.81),(-.12,1.00),(-.06,1.12),(.04,.92)]
for i,poly in enumerate(cells(pillar_bound,pillar_seeds)):rockpoly('pillar_fracture_%d'%i,poly,-.15,.15,p,True)
for i in range(16):
 x=random.uniform(-.27,.28);y=random.uniform(-.22,.23)
 if abs(x)<.19 and abs(y)<.15:continue
 stone('pillar_scattered_chip_%02d'%i,(x,y,.03),(.045,.042,.065),p,90+i)
# Inset front relief, cyan lines lie beneath dark bevel edging, leaving full stone surrounds.
paths=[[(-.005,-.13,.30),(-.005,-.13,.47),(-.115,-.13,.59),(-.005,-.13,.72),(.105,-.13,.59),(-.005,-.13,.47)],[(-.005,-.13,.72),(-.005,-.13,.96)],[(-.082,-.13,.34),(-.082,-.13,.46)],[(.073,-.13,.72),(.073,-.13,.91)]]
# Chisel actual channels across the fractured front stone faces.
for i,pts in enumerate(paths):
 for seg in range(len(pts)-1):
  pair=pts[seg:seg+2];cutter=stroke('temporary_chisel_%d_%d'%(i,seg),[(x,-.153,z) for x,y,z in pair],.011,VOID,p)
  for panel in [q for q in p.children if q.name.startswith('pillar_fracture_')]:
   bpy.context.view_layer.objects.active=panel;mod=panel.modifiers.new('Recessed carved rune','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.data.objects.remove(cutter,do_unlink=True)
 stroke('rune_inlay_%d'%i,[(x,-.148,z) for x,y,z in pts],.0035,RUNE,p)
# Broad old bronze collar plates, broken edges and physical low bevels.
for i,(xa,xb) in enumerate(((-.202,-.02),(-.014,.20))):
 vv=[(xa,-.184,.196),(xb,-.184,.207),(xb,-.184,.283),(xa,-.184,.291),(xa,-.159,.196),(xb,-.159,.207),(xb,-.159,.283),(xa,-.159,.291)]
 o=mesh('brass_collar_face_%d'%i,vv,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],BRASS,p);bevel(o,.003)
for side in (-1,1):
 x=side*.193;vv=[(x,-.18,.20),(x,.17,.20),(x,.17,.28),(x,-.18,.285),(x+side*.015,-.18,.20),(x+side*.015,.17,.20),(x+side*.015,.17,.28),(x+side*.015,-.18,.285)]
 o=mesh('brass_collar_side_%s'%side,vv,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],BRASS,p);bevel(o,.003)
stroke('brass_diamond_seal',[(0,-.198,.18),(.055,-.198,.235),(0,-.198,.29),(-.055,-.198,.235),(0,-.198,.18)],.009,BRASS,p)

c=root('crystal_cluster')
cbound=[(-.28,-.18),(-.20,-.29),(-.07,-.25),(.10,-.28),(.19,-.22),(.29,-.14),(.24,.06),(.28,.20),(.14,.27),(.03,.23),(-.08,.29),(-.21,.20),(-.28,.11)]
seeds=[(random.uniform(-.24,.24),random.uniform(-.23,.23)) for i in range(17)]
for i,poly in enumerate(cells(cbound,seeds)):rockpoly('crystal_bedrock_%02d'%i,poly,.0,random.uniform(.04,.085) if sum(y for x,y in poly)/len(poly)<-.09 else random.uniform(.07,.155),c)
for i,(x,y,r,h,t) in enumerate([(0,.055,.085,.61,.02),(-.135,.015,.065,.41,-.045),(.12,.08,.06,.40,.06),(-.08,-.13,.052,.25,-.02),(.035,-.17,.032,.18,.01),(.16,-.10,.041,.24,.04)]):crystal('cluster_crystal_%d'%i,(x,y,.035),r,h,c,t)
v=root('void_fissure')
# Interlocking irregular rock strata with an actual open zig-zag chasm.
for side in (-1,1):
 bound=[(side*x,y) for x,y in [(.05,-.43),(.35,-.43),(.44,-.31),(.44,.32),(.34,.44),(.04,.42),(.075,.17),(.04,-.10)]]
 seeds=[(side*random.uniform(.085,.41),random.uniform(-.39,.39)) for _ in range(15)]
 for i,poly in enumerate(cells(bound,seeds)):rockpoly('rift_fractured_bedrock_%s_%d'%(side,i),poly,-.175,random.uniform(.105,.17),v)
for i in range(25):
 a=random.random()*math.tau;r=random.uniform(.28,.44);stone('rift_edge_debris_%02d'%i,(math.cos(a)*r,math.sin(a)*r,-.115),(.04,.05,.08),v,500+i)
mesh('recessed_void_floor',[(-.12,-.44,-.168),(.12,-.44,-.168),(.12,.44,-.168),(-.12,.44,-.168)],[(0,1,2,3)],VOID,v)
for i in range(23):
 y=random.uniform(-.4,.4);x=random.uniform(-.045,.045);crystal('void_depth_shard_%02d'%i,(x,y,-.155),.007,random.uniform(.012,.04),v)
 o=bpy.data.objects['void_depth_shard_%02d'%i];o.data.materials.clear();o.data.materials.append(GLOW)
# Broken thick ceremonial arc lies diagonally against the front chasm edge, with rivets.
pts=[];vv=[]
for j in range(25):
 a=math.radians(20+j*9)
 for y in (-.385,-.36):
  for r in (.112,.155):vv.append((-.13+math.cos(a)*r,y,.035+math.sin(a)*r))
 pts.append((-.13+math.cos(a)*.134,-.391,.035+math.sin(a)*.134))
ff=[]
for j in range(24):
 q=4*j;t=q+4
 ff.extend([(q,q+1,t+1,t),(q+2,t+2,t+3,q+3),(q,t,t+2,q+2),(q+1,q+3,t+3,t+1)])
ff.extend([(0,2,3,1),(96,97,99,98)])
o=mesh('broken_brass_arch',vv,ff,BRASS,v);bevel(o,.0015)
for j in range(0,25,3):
 q=pts[j];bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.006,location=q);o=bpy.context.object;o.name='arch_rivet_%02d'%j;o.parent=v;o.data.materials.append(BRASS)

# Regeneration explicitly includes the approved floating ground, while --export-only
# preserves the edited .blend without recreating any upper prop or ground geometry.
import importlib.util
ground_spec=importlib.util.spec_from_file_location('chapter2_floating_ground',HERE/'add_floating_ground.py');ground_module=importlib.util.module_from_spec(ground_spec);ground_spec.loader.exec_module(ground_module);ground_module.add_floating_ground()
setup_studio();export();bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'chapter2_props.blend'));render_props()
