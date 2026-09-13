"""Volumetric shell revision: source front/side/back identity, steep-camera legibility."""
import bpy,bmesh,math,json,random
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus');OUT=ROOT/'assets/images/stage1_3d/enemies';WORK=ROOT/'design/stage1_3d/enemies'
scene=bpy.data.scenes.get('Stage1EnemyRefinement') or bpy.data.scenes.new('Stage1EnemyRefinement');bpy.context.window.scene=scene
for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
P={'normal':['2F4355','1E3142','AEB7C1','C7CED6'],'armored':['4A4F55','30343A','D0D3D6','F0D878'],'shielded':['123A4E','0A2535','4CAEC6','62D9FF'],'fast':['123E4A','0B2C36','2CB7C8','9CEBFF'],'tank':['4A3B27','332A1F','C0964D','A9856A'],'boss':['4E1824','35121C','B6394B','FF5A66']}
def lin(c):
 v=[int(c[i:i+2],16)/255 for i in (0,2,4)];return tuple(t/12.92 if t<=.04045 else ((t+.055)/1.055)**2.4 for t in v)+(1,)
def mat(n,c,emit=0):
 m=bpy.data.materials.new(n);m.diffuse_color=lin(c);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=lin(c);p.inputs['Metallic'].default_value=.24;p.inputs['Roughness'].default_value=.84;p.inputs['Emission Color'].default_value=lin(c);p.inputs['Emission Strength'].default_value=emit;return m
def mesh(n,vs,fs,m):
 d=bpy.data.meshes.new(n);d.from_pydata(vs,[],fs);d.update();bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(d);bm.free();o=bpy.data.objects.new(n,d);scene.collection.objects.link(o);o.data.materials.append(m);return o
def ico(n,loc,scale,m,sub=2):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc);o=bpy.context.object;o.name=n;o.scale=scale;o.data.materials.append(m);return o
def shard(n,base,tip,width,m):
 direction=Vector(tip)-Vector(base);up=direction.normalized();a=up.cross(Vector((0,1,0))).normalized();b=up.cross(a)
 vs=[Vector(base)+a*width,Vector(base)+b*width*.65,Vector(base)-a*width,Vector(base)-b*width*.65,Vector(tip)]
 return mesh(n,vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],m)
roots={};solids=[];allmats=[]
for index,(kind,c) in enumerate(P.items()):
 rnd=random.Random(510+index);m={r:mat(kind+'_'+r,h) for r,h in zip(['body','spike','armor','accent'],c)};m['core']=mat(kind+'_crystal',c[-1],.85);m['edge']=mat(kind+'_core_edge',c[-1],.25)
 m['core'].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.48
 objs=[];rx=.39 if kind!='fast' else .31;ry=.40 if kind!='fast' else .46;rz=.34 if kind!='fast' else .25;cz=.42
 if kind=='tank':rx=.44;ry=.42;rz=.35
 if kind=='boss':rx=.46;ry=.43;rz=.39;cz=.46
 # Tapered multi-ring convex shell, no extrusion walls; varied facets over its entire surface.
 vs=[];fs=[];rings=7;segments=14
 for j in range(rings+1):
  lat=-math.pi/2+j*math.pi/rings
  for i in range(segments):
   a=i*math.tau/segments+(j%2)*.045;rad=math.cos(lat);z=math.sin(lat)
   perturb=1+rnd.uniform(-.035,.035)
   vs.append((rx*rad*math.cos(a)*perturb,ry*rad*math.sin(a)*perturb,cz+rz*z))
 for j in range(rings):
  for i in range(segments):
   a=j*segments+i;b=j*segments+(i+1)%segments;c1=b+segments;d=a+segments
   fs.extend([(a,b,c1),(a,c1,d)])
 body=mesh(kind+'_convex_shell',vs,fs,m['body']);objs.append(body)
 # Plate surfaces wrap over the shell shoulders; central seam remains visible from above.
 def surface(u,v,raiseby=.025):
  x=(rx+raiseby)*math.sin(u)*math.cos(v);y=(ry+raiseby)*math.sin(v);z=cz+(rz+raiseby)*math.cos(u)*math.cos(v);return (x,y,z)
 def plate(name,umin,umax,vmin,vmax,material):
  verts=[];faces=[];nu=3;nv=4
  for j in range(nv+1):
   v=vmin+(vmax-vmin)*j/nv
   for i in range(nu+1):verts.append(surface(umin+(umax-umin)*i/nu,v))
  for j in range(nv):
   for i in range(nu):
    a=j*(nu+1)+i;faces.extend([(a,a+1,a+nu+2),(a,a+nu+2,a+nu+1)])
  o=mesh(name,verts,faces,material);solid=o.modifiers.new('plate thickness','SOLIDIFY');solid.thickness=.035;bev=o.modifiers.new('worn plate edge','BEVEL');bev.width=.008;bev.segments=1;objs.append(o)
 if kind in ['armored','tank','boss']:
  for side in [-1,1]:plate(kind+'_wrap_'+str(side),side*.10,side*1.50,-.63,.80,m['armor'])
  plate(kind+'_rear',-.63,.63,.82,1.36,m['armor'])
  # Central dark wedge divides the helmet/armored panels as in original directional rendering.
  plate(kind+'_forehead',-.30,.30,-.94,-.64,m['accent'] if kind!='armored' else m['armor'])
 else:
  plate(kind+'_forehead',-.42,.42,-.73,-.30,m['armor'])
  plate(kind+'_rear_dorsal',-.36,.36,.30,1.1,m['armor'])
  for side in [-1,1]:plate(kind+'_cheek_'+str(side),side*.90,side*1.30,-.63,.35,m['body'])
 # Existing spike families, represented as tapered shards rather than upright flat slabs.
 if kind in ['normal','shielded']:
  objs += [shard('dorsal',(0,.20,.64),(0,.33,.91),.105,m['spike'])]
  for side in [-1,1]:objs.append(shard('side shard',(side*.30,.04,.42),(side*.55,.10,.46),.10,m['spike']))
 elif kind=='fast':
  objs.append(shard('dorsal',(0,.20,.60),(0,.41,.78),.075,m['spike']))
  for side in [-1,1]:objs.append(shard('swept shard',(side*.23,.17,.34),(side*.46,.46,.28),.085,m['spike']))
 elif kind=='tank':objs.append(shard('dorsal',(0,.21,.68),(0,.35,.95),.12,m['spike']))
 elif kind=='boss':
  objs.append(shard('crown',(0,.21,.79),(0,.33,1.07),.115,m['spike']))
  for side in [-1,1]:
   objs.append(shard('shoulder',(side*.36,.03,.61),(side*.63,.16,.69),.105,m['spike']))
   objs.append(shard('lower shard',(side*.33,.09,.26),(side*.49,.25,.10),.09,m['spike']))
 # Upward-tilted recessed crystalline core: seen from steep battlefield camera, no white button.
 direction=Vector((0,-.78,.625)).normalized();center=Vector((0,-ry*.78,cz+rz*.625));axis=direction.to_track_quat('Z','Y')
 # Open the shell behind the lens; a recess must not be covered by solid shell facets.
 bm=bmesh.new();bm.from_mesh(body.data);cut=[]
 for face in bm.faces:
  q=face.calc_center_median();q=Vector((q.x/rx,q.y/ry,(q.z-cz)/rz)).normalized()
  if q.dot(direction)>.91:cut.append(face)
 bmesh.ops.delete(bm,geom=cut,context='FACES');bm.to_mesh(body.data);bm.free()
 radius={'normal':.145,'armored':.13,'shielded':.155,'fast':.125,'tank':.145,'boss':.19}[kind]
 bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=4,location=center,major_radius=radius*1.07,minor_radius=.034)
 ring=bpy.context.object;ring.name='recessed core rim';ring.rotation_mode='QUATERNION';ring.rotation_quaternion=axis;ring.data.materials.append(m['spike']);objs.append(ring)
 # Multiple asymmetric gem facets make the core itself carry the accent hue.
 gemvs=[]
 for z,r in [(-.036,radius*.88),(.005,radius*.85),(.038,radius*.51)]:
  for i in range(9):
   a=i*math.tau/9;gemvs.append(center+axis@Vector((r*math.cos(a),r*math.sin(a),z)))
 gemvs.append(center+direction*.053);gemfs=[]
 for j in range(2):
  for i in range(9):a=j*9+i;b=j*9+(i+1)%9;gemfs.extend([(a,b,b+9),(a,b+9,a+9)])
 for i in range(9):gemfs.append((18+i,18+(i+1)%9,27))
 objs.append(mesh('faceted core',gemvs,gemfs,m['core']))
 # Subtle metal-stone face variation; no new pattern or decorative symbol.
 for o in objs:
  if o.type=='MESH' and o.name not in ['faceted core','recessed core rim']:
   base=o.data.materials[0]
   for j,factor in enumerate([.88,1.08]):
    variant=base.copy();variant.name=base.name+'_grainfacet'+str(j);p=variant.node_tree.nodes.get('Principled BSDF');v=p.inputs['Base Color'].default_value;p.inputs['Base Color'].default_value=tuple(x*factor for x in v[:3])+(1,);o.data.materials.append(variant)
   for p in o.data.polygons:p.material_index=rnd.choices([0,1,2],[.75,.16,.09])[0]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=body;bpy.ops.object.convert(target='MESH');bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bpy.ops.object.join();o=bpy.context.object;o.name=kind
 # Normalize width exactly to 1 while keeping ground clearance and model pivot.
 width=max(v.co.x for v in o.data.vertices)-min(v.co.x for v in o.data.vertices);zmin=min(v.co.z for v in o.data.vertices)
 for v in o.data.vertices:v.co.x/=width;v.co.y/=width;v.co.z=(v.co.z-zmin)/width+.045
 root=bpy.data.objects.new(kind+'_root',None);scene.collection.objects.link(root);o.parent=root;roots[kind]=root;solids.append(o)
# Bake a shared fine-grain normal atlas across all six source meshes.
bpy.ops.object.select_all(action='DESELECT')
for o in solids:o.select_set(True)
bpy.context.view_layer.objects.active=solids[0];bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.18,island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
atlas=bpy.data.images.new('enemy_cast_grain_512',width=512,height=512);atlas.colorspace_settings.name='Non-Color'
materials=set(slot.material for o in solids for slot in o.material_slots if slot.material)
for m in materials:
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=90;noise.inputs['Detail'].default_value=2
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.20;bump.inputs['Distance'].default_value=.008;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);tex=n.new('ShaderNodeTexImage');tex.name='grain atlas';tex.image=atlas;n.active=tex
scene.render.engine='CYCLES';scene.cycles.samples=4;scene.render.bake.use_clear=False;scene.render.bake.margin=2;bpy.ops.object.bake(type='NORMAL');atlas.pack()
for m in materials:
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.55;l.new(n['grain atlas'].outputs['Color'],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal'])
# Consolidate face-color variation into vertex colors: two material draws per enemy.
for o in solids:
 colors=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
 old=list(o.data.materials);core=next(m for m in old if '_crystal' in m.name)
 cast=mat(o.name+'_cast_atlas','FFFFFF');nodes=cast.node_tree.nodes;links=cast.node_tree.links;p=nodes.get('Principled BSDF')
 vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';links.new(vc.outputs['Color'],p.inputs['Base Color'])
 tex=nodes.new('ShaderNodeTexImage');tex.image=atlas;normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.55;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
 indices=[]
 for face in o.data.polygons:
  original=old[face.material_index];iscore=original==core;col=(1,1,1,1) if iscore else tuple(original.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value)
  for loop in face.loop_indices:colors.data[loop].color=col
  indices.append(1 if iscore else 0)
 o.data.materials.clear();o.data.materials.append(cast);o.data.materials.append(core)
 for face,index in zip(o.data.polygons,indices):face.material_index=index
stats={}
for kind,root in roots.items():
 bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
 for o in root.children:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
 stats[kind]={'bytes':(OUT/(kind+'.glb')).stat().st_size,'width':1,'triangles':sum(len(p.vertices)-2 for o in root.children for p in o.data.polygons)}
(WORK/'manifest-refined.json').write_text(json.dumps(stats,indent=2))
# Representative steep-angle game camera. Front row and back row use differing headings.
for i,(kind,root) in enumerate(roots.items()):root.location=((i%3-1)*1.65,(i//3)*1.9,0);root.rotation_euler.z=[0,-.5,.3,.4,-.25,.2][i]
floor=mat('muted grass','344C3E');bpy.ops.mesh.primitive_plane_add(size=200);bpy.context.object.data.materials.append(floor);bpy.context.object.location.z=-.025
world=bpy.data.worlds.new('EnemyRefinementWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.17,.20,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.world=world
for name,loc,power,color in [('key',(-3,-4,8),1000,(1,.92,.80)),('fill',(4,0,5),500,(.70,.84,1))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=5;d.color=color;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,1,.3))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('SteepGameCamera');cam=bpy.data.objects.new('SteepGameCamera',d);scene.collection.objects.link(cam);cam.location=(5,-13,27);cam.rotation_euler=(Vector((0,1,.3))-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=6.3;scene.camera=cam
scene.cycles.samples=24;scene.render.resolution_x=1300;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(WORK/'enemy-steep-refined.png')
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'chapter-one-enemies-refined.blend'));print(stats)
