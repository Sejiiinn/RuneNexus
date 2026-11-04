import bpy,math,random,os,json
from mathutils import Vector
ROOT='/Users/sejin/Documents/Codex/RuneNexus'; OUT=ROOT+'/design/stage1_3d/environment'; ASSET=ROOT+'/assets/images/stage1_3d/environment/terrain.glb'
bpy.ops.wm.open_mainfile(filepath=OUT+'/terrain.blend')
s=bpy.context.scene
# Retain approved portal/core, replace only terrain meshes.
for o in list(s.objects):
 if o.name not in ['portal','core'] and not any(p.name in ['portal','core'] for p in [o.parent,o.parent.parent if o.parent else None] if p): bpy.data.objects.remove(o,do_unlink=True)
with bpy.data.libraries.load(ROOT+'/design/stage1_3d/actor_refinement/stage1-actors-refined.blend',link=False) as (src,dst): dst.materials=[n for n in src.materials if n in ['C1_mossy_PBR_stone','C1_worn_earth_cobbles','C1_natural_rock_faces']]
mats={m.name.split('.')[0]:m for m in dst.materials}
s.render.engine='CYCLES';s.cycles.samples=8;s.render.bake.use_pass_direct=False;s.render.bake.use_pass_indirect=False;s.render.bake.use_pass_color=True
os.makedirs(OUT+'/approved_textures',exist_ok=True)
for name,m in mats.items():
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');bpy.ops.mesh.primitive_plane_add(size=2);plane=bpy.context.object;plane.data.materials.append(m);images={}
 for channel,mode in [('basecolor','DIFFUSE'),('normal','NORMAL'),('roughness','ROUGHNESS')]:
  image=bpy.data.images.new(name+'_'+channel,width=1024,height=1024,alpha=False)
  if channel!='basecolor':image.colorspace_settings.name='Non-Color'
  node=n.new('ShaderNodeTexImage');node.image=image;n.active=node;bpy.ops.object.bake(type=mode,margin=8)
  image.file_format='PNG';image.filepath_raw=OUT+'/approved_textures/'+name+'_'+channel+'.png';image.save();images[channel]=image
 # Height-derived micro-cavity: only recessed stone joints, no global darkening.
 disp=next(node for node in n if node.type=='TEX_IMAGE' and node.image and '_disp_' in node.image.name)
 threshold={'C1_mossy_PBR_stone':.55,'C1_worn_earth_cobbles':.30,'C1_natural_rock_faces':.48}[name]
 cavity=n.new('ShaderNodeMapRange');cavity.clamp=True;cavity.inputs['From Min'].default_value=threshold*.5;cavity.inputs['From Max'].default_value=threshold;cavity.inputs['To Min'].default_value=.65;cavity.inputs['To Max'].default_value=1;l.new(disp.outputs['Color'],cavity.inputs[0])
 emission=n.new('ShaderNodeEmission');l.new(cavity.outputs[0],emission.inputs[0]);output=next(node for node in n if node.type=='OUTPUT_MATERIAL');l.new(emission.outputs[0],output.inputs['Surface'])
 image=bpy.data.images.new(name+'_cavity',width=1024,height=1024,alpha=False);image.colorspace_settings.name='Non-Color';node=n.new('ShaderNodeTexImage');node.image=image;n.active=node;bpy.ops.object.bake(type='EMIT',margin=8);image.file_format='PNG';image.filepath_raw=OUT+'/approved_textures/'+name+'_cavity.png';image.save();images['cavity']=image;l.new(p.outputs[0],output.inputs['Surface'])
 bpy.data.objects.remove(plane,do_unlink=True)
 for node in list(n):
  if node!=p and node.type!='OUTPUT_MATERIAL':n.remove(node)
 # Standard PBR texture paths, no renderer-specific nodes at runtime.
 for channel,image in images.items():
  node=n.new('ShaderNodeTexImage');node.image=image
  if channel=='normal':
   normal=n.new('ShaderNodeNormalMap');l.new(node.outputs[0],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal'])
  elif channel=='cavity':
   group=bpy.data.node_groups.get('glTF Material Output')
   if group is None:
    from io_scene_gltf2.blender.com.material_helpers import create_settings_group
    group=create_settings_group('glTF Material Output')
   settings=n.new('ShaderNodeGroup');settings.node_tree=group;l.new(node.outputs[0],settings.inputs['Occlusion'])
  else:l.new(node.outputs[0],p.inputs['Base Color' if channel=='basecolor' else 'Roughness'])
 p.inputs['Coat Weight'].default_value=0
stone=mats['C1_mossy_PBR_stone'];road=mats['C1_worn_earth_cobbles'];wall=mats['C1_natural_rock_faces']

def block(name,root,center,size,material,seed,topmat=None):
 rng=random.Random(seed);x,y,z=size;corners=[(-x*.43,-y*.5),(x*.42,-y*.5),(x*.5,-y*.4),(x*.5,y*.43),(x*.4,y*.5),(-x*.43,y*.5),(-x*.5,y*.4),(-x*.5,-y*.41)]
 corners=[(max(-x/2,min(x/2,a+rng.uniform(-.011,.011))),max(-y/2,min(y/2,b+rng.uniform(-.011,.011)))) for a,b in corners]
 # Keep the tile's exact 1×1 footprint and top reference plane.
 heights=[rng.uniform(-.003,0) for _ in corners] if topmat else [0]*8
 highest=max(heights);heights=[v-highest for v in heights]
 verts=[(a,b,-z/2) for a,b in corners]+[(a,b,z/2+heights[i]) for i,(a,b) in enumerate(corners)];faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(material)
 if topmat:mesh.materials.append(topmat);mesh.polygons[1].material_index=1
 ob=bpy.data.objects.new(name,mesh);s.collection.objects.link(ob);ob.parent=root;ob.location=center;uv=mesh.uv_layers.new(name='UVMap')
 for poly in mesh.polygons:
  axis=max(range(3),key=lambda a:abs(poly.normal[a]))
  for li in poly.loop_indices:
   v=mesh.vertices[mesh.loops[li].vertex_index].co
   uv.data[li].uv=(v.x+.5,v.y+.5) if axis==2 else (v.y+.5,v.z*2+.5) if axis==0 else (v.x+.5,v.z*2+.5)
 mod=ob.modifiers.new('natural stone edge','BEVEL');mod.width=.009 if topmat else .020;mod.segments=2;bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name)
 if topmat:
  delta=z/2-max(v.co.z for v in ob.data.vertices)
  for v in ob.data.vertices:
   if v.co.z>0:v.co.z+=delta
 ob.select_set(False);return ob
roots=[]
for name,top in [('build_tile',stone),('path_tile',road),('blocked_tile',wall)]:
 root=bpy.data.objects.new(name,None);s.collection.objects.link(root);roots.append(root)
 surface=block(name+'_natural_surface',root,(0,0,-.167),(1,1,.334),wall,10,top)
 # Embedded low natural-rock faces; they stay beneath the playable top surface.
 fragments=[]
 for j in range(8):
  edge=j//2;along=(-.25,.25)[j%2];x,y=[(along,-.445),(.445,along),(along,.445),(-.445,along)][edge]
  f=block(name+'_natural_edge',root,(x,y,-.151),(.11 if edge%2 else .29,.29 if edge%2 else .11,.19),wall,100+j);fragments.append(f)
 if name=='build_tile':
  rng=random.Random(163)
  moss=bpy.data.materials.get('C1_edge_moss') or bpy.data.materials.new('C1_edge_moss');moss.diffuse_color=(.043,.105,.026,1);moss.use_nodes=True;p=moss.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.043,.105,.026,1);p.inputs['Roughness'].default_value=.94
  for j in range(12):
   angle=rng.random()*math.tau;radius=rng.uniform(.39,.465);x=math.cos(angle)*radius;y=math.sin(angle)*radius
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,.004));o=bpy.context.object;o.name='build_tile_edge_moss';o.scale=(rng.uniform(.015,.035),rng.uniform(.012,.031),.008);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=root;o.data.materials.append(moss);fragments.append(o)
 bpy.ops.object.select_all(action='DESELECT');surface.select_set(True)
 for o in fragments:o.select_set(True)
 bpy.context.view_layer.objects.active=surface;bpy.ops.object.join()
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=ASSET,export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/terrain-approved.blend')
# QA imports the exported GLB, not the authoring scene.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=ASSET)
lib={o.name:o for o in s.objects if o.parent is None}
for o in lib.values():
 o.hide_render=True
 for child in o.children_recursive:child.hide_render=True
for row in range(4):
 for col in range(5):
  source=lib['path_tile' if col==2 else 'build_tile']
  r=source.copy();s.collection.objects.link(r);r.hide_render=False;r.location=(col-2,row-1.5,0)
  for child in source.children:
   cp=child.copy();cp.data=child.data;s.collection.objects.link(cp);cp.parent=r;cp.hide_render=False
for name,pos in [('portal',(0,1.5,0)),('core',(0,-1.5,0))]:
 lib[name].hide_render=False;lib[name].location=pos
 for child in lib[name].children_recursive:child.hide_render=False
world=bpy.data.worlds.new('approved terrain sky');world.use_nodes=True;s.world=world;world.node_tree.nodes['Background'].inputs[0].default_value=(.11,.16,.18,1);world.node_tree.nodes['Background'].inputs[1].default_value=.33
for loc,power,size,col in [((-3,-1,9),575,5,(.90,.94,1)),((4,3,6.5),425,4.5,(1,.86,.66)),((.5,-6,6),162,5,(.7,.83,1))]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.data.color=col;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(5,-13,27));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=6.3;s.camera=cam
s.render.resolution_x=1000;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.cycles.samples=32;s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=.15;s.render.filepath=OUT+'/terrain-glb-import-qa.png';s.render.image_settings.file_format='PNG';bpy.ops.render.render(write_still=True)
print('APPROVED_TERRAIN_DONE')
