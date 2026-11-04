import bpy,os,math
from mathutils import Matrix
ROOT='/Users/sejin/Documents/Codex/RuneNexus';OUT=ROOT+'/design/stage1_3d/environment';ASSET=ROOT+'/assets/images/stage1_3d/environment/terrain.glb'
bpy.ops.wm.open_mainfile(filepath=OUT+'/terrain-approved.blend');s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.render.bake.use_pass_direct=False;s.render.bake.use_pass_indirect=False;s.render.bake.use_pass_color=True
os.makedirs(OUT+'/authored_atlas',exist_ok=True)
with bpy.data.libraries.load(ROOT+'/design/stage1_3d/actor_refinement/stage1-actors-refined.blend',link=False) as (src,dst):dst.objects=[n for n in src.objects if n.startswith(('moss covered build stone','worn earth path'))]
groups={}
for o in dst.objects:
 s.collection.objects.link(o);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');o=bpy.context.object
 material=o.data.materials[0];key='build' if o.name.startswith('moss covered') else 'path';groups.setdefault(key,[]).append(o)
 # Preserve original shader UV lookup independently of the bake target atlas.
 if not material.get('source_uv_preserved'):
  n=material.node_tree.nodes;l=material.node_tree.links;uv=n.new('ShaderNodeUVMap');uv.uv_map='UVMap'
  for link in list(l):
   if link.from_node.type=='TEX_COORD' and link.from_socket.name=='UV':l.new(uv.outputs['UV'],link.to_socket)
  material['source_uv_preserved']=True
 atlas=o.data.uv_layers.new(name='RuntimeAtlas')
 for face in o.data.polygons:
  for li in face.loop_indices:
   co=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co;atlas.data[li].uv=((co.x+8.5)/17,(co.y+10.5)/21)
 o.data.uv_layers['UVMap'].active_render=True
root=bpy.data.objects['stage1_environment']
for key,objects in groups.items():
 material=objects[0].data.materials[0];n=material.node_tree.nodes;p=n.get('Principled BSDF');images={}
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 for channel,mode in [('basecolor','DIFFUSE'),('normal','NORMAL'),('roughness','ROUGHNESS')]:
  image=bpy.data.images.new('stage1_'+key+'_'+channel,width=2048,height=2048,alpha=False)
  if channel!='basecolor':image.colorspace_settings.name='Non-Color'
  node=n.new('ShaderNodeTexImage');node.image=image;n.active=node
  bpy.ops.object.bake(type=mode,uv_layer='RuntimeAtlas',margin=4,use_clear=False)
  image.file_format='PNG';image.filepath_raw=OUT+'/authored_atlas/'+image.name+'.png';image.save();images[channel]=image
 runtime=bpy.data.materials.new('stage1_authored_'+key);runtime.use_nodes=True;rn=runtime.node_tree.nodes;rl=runtime.node_tree.links;rp=rn.get('Principled BSDF');rp.inputs['Metallic'].default_value=0;rp.inputs['Coat Weight'].default_value=0
 for channel,image in images.items():
  node=rn.new('ShaderNodeTexImage');node.image=image;node.extension='EXTEND'
  if channel=='normal':
   normal=rn.new('ShaderNodeNormalMap');rl.new(node.outputs[0],normal.inputs['Color']);rl.new(normal.outputs[0],rp.inputs['Normal'])
  else:rl.new(node.outputs[0],rp.inputs['Base Color' if channel=='basecolor' else 'Roughness'])
 transform=Matrix.Scale(.5,4)@Matrix.Translation((0,0,-.082))
 for o in objects:
  o.data.materials.clear();o.data.materials.append(runtime)
  # Only atlas UV is needed in the runtime mesh.
  for uv in list(o.data.uv_layers):
   if uv.name!='RuntimeAtlas':o.data.uv_layers.remove(uv)
  o.data.uv_layers.active_index=0;o.data.uv_layers[0].active_render=True
  o.matrix_world=transform@o.matrix_world
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);bpy.ops.object.join();new=bpy.context.object;new.parent=root
 oldname='stage1_static_C1_mossy_PBR_stone' if key=='build' else 'stage1_static_C1_worn_earth_cobbles'
 old=bpy.data.objects.get(oldname)
 if old:bpy.data.objects.remove(old,do_unlink=True)
 new.name=oldname
 print('ATLAS_DONE',key,len(objects),flush=True)
root['authoredMaterialCoordinates']='original UV mapping and world/object color variation baked per full stage'
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=ASSET,export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_extras=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/terrain-approved.blend');print('AUTHORED_ATLAS_COMPLETE',flush=True)
