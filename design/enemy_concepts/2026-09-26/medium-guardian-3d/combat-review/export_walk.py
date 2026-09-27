"""Bake approved PBR, consolidate surfaces, and reduce rigid bone keys offline."""
import bpy,math,json,struct,time
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
OUT=Path(__file__).resolve().parent;SIZE=1024;TOL=.00025
source=bpy.data.scenes['Medium_Guardian_Walk_V3']
for w in bpy.context.window_manager.windows:w.scene=source
source.frame_set(1);bpy.context.view_layer.update()
source_rig=source.objects['Guardian_Walk_V3_Rig'];obs=[o for o in source.objects if o.type=='MESH' and o.parent_type=='BONE']
# Record local poses and source bounding corners before changing any data.
frames=[1+i/10 for i in range(261)];poses={b.name:[] for b in source_rig.pose.bones}
for f in frames:
 source.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
 for b in source_rig.pose.bones:poses[b.name].append(b.matrix_basis.decompose())
source.frame_set(1);source_rig.data.pose_position='REST';bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
scene=bpy.data.scenes.new('Guardian_Walk_Runtime');scene.world=source.world.copy()
rig=source_rig.copy();rig.data=source_rig.data.copy();rig.parent=None;rig.name='Guardian_Walk_Runtime_Rig';rig.animation_data_clear();scene.collection.objects.link(rig)
clones=[];material_map={}
fallback=bpy.data.materials.new('Cut face default surface');fallback.use_nodes=True;fallback.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.8,.8,.8,1)
for old in obs:
 data=bpy.data.meshes.new_from_object(old.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
 attr=data.attributes.new('RestObject','FLOAT_VECTOR','POINT')
 for v in data.vertices:attr.data[v.index].vector=v.co;v.co=old.matrix_world@v.co
 o=bpy.data.objects.new('Runtime_'+old.name,data);scene.collection.objects.link(o)
 for i,m in enumerate(o.data.materials):
  if not m:o.data.materials[i]=fallback
  if m:
   if m not in material_map:
    mat=m.copy();material_map[m]=mat;nodes=mat.node_tree.nodes;links=mat.node_tree.links;att=nodes.new('ShaderNodeAttribute');att.attribute_name='RestObject'
    for node in list(nodes):
     if node.type=='TEX_COORD':
      for link in list(node.outputs['Object'].links):links.new(att.outputs['Vector'],link.to_socket)
   o.data.materials[i]=material_map[m]
 vg=o.vertex_groups.new(name=old.parent_bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE');clones.append(o)
source_rig.data.pose_position='POSE'
for w in bpy.context.window_manager.windows:w.scene=scene
# Same original surface attributes are preserved through the join; no decimation.
bpy.ops.object.select_all(action='DESELECT')
for o in clones:o.select_set(True)
bpy.context.view_layer.objects.active=clones[0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name='Guardian_Walk_AtlasMesh'
mod=mesh.modifiers.new('Rigid precomputed bones','ARMATURE');mod.object=rig;mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
# UV atlas + explicit bake is the repository's existing PBR export route.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003);bpy.ops.object.mode_set(mode='OBJECT')
scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.bake.use_clear=False;scene.render.bake.margin=4
images={};materials=list(dict.fromkeys(m for m in mesh.data.materials if m))
for name in ['color','roughness','metallic','normal']:
 im=bpy.data.images.new('Walk atlas '+name,width=SIZE,height=SIZE,alpha=False)
 if name!='color':im.colorspace_settings.name='Non-Color'
 im.filepath_raw=str(OUT/('walk-'+name+'.png'));im.file_format='PNG';images[name]=im
for m in materials:
 n=m.node_tree.nodes.new('ShaderNodeTexImage');n.name='Bake Target';m.node_tree.nodes.active=n
for name,kind in [('color','EMIT'),('roughness','ROUGHNESS'),('metallic','EMIT'),('normal','NORMAL')]:
 links_to_restore=[]
 for m in materials:
  m.node_tree.nodes['Bake Target'].image=images[name]
  if name in ['color','metallic']:
   nodes=m.node_tree.nodes;links=m.node_tree.links;bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');em=nodes.new('ShaderNodeEmission');socket=bs.inputs['Base Color' if name=='color' else 'Metallic']
   if socket.is_linked:links.new(socket.links[0].from_socket,em.inputs['Color'])
   else:
    value=socket.default_value;em.inputs['Color'].default_value=tuple(value) if name=='color' else (value,value,value,1)
   links.new(em.outputs[0],output.inputs['Surface']);links_to_restore.append((m,bs,output,em))
 bpy.ops.object.bake(type=kind)
 for m,bs,out,em in links_to_restore:m.node_tree.links.new(bs.outputs[0],out.inputs['Surface']);m.node_tree.nodes.remove(em)
 images[name].save();images[name].pack();print('BAKED',name,flush=True)
# Single atlas material: draw submissions follow one skinned surface, not 93 objects.
mat=bpy.data.materials.new('Guardian_Walk_PBR_Atlas');mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF')
for name,socket in [('color','Base Color'),('roughness','Roughness'),('metallic','Metallic'),('normal','Normal')]:
 tex=nodes.new('ShaderNodeTexImage');tex.image=images[name]
 if name=='normal':n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=4;links.new(tex.outputs['Color'],n.inputs['Color']);links.new(n.outputs[0],bs.inputs[socket])
 else:links.new(tex.outputs['Color'],bs.inputs[socket])
mesh.data.materials.clear();mesh.data.materials.append(mat)
for p in mesh.data.polygons:p.material_index=0
# Per-bone corner displacement bounds allow explicit error-limited key reduction.
rig.data.pose_position='POSE'
kept={};errors={};radii={}
for b in rig.pose.bones:
 indexes=[]
 for v in mesh.data.vertices:
  if any(mesh.vertex_groups[g.group].name==b.name and g.weight>.5 for g in v.groups):indexes.append(v.index)
 pts=[rig.data.bones[b.name].matrix_local.inverted()@mesh.data.vertices[i].co for i in indexes]
 radius=max([p.length for p in pts]+[.1]);radii[b.name]=radius
 values=poses[b.name]
 def error(i,a,z):
  u=(frames[i]-frames[a])/(frames[z]-frames[a]);p,q,k=values[i];p0,q0,k0=values[a];p1,q1,k1=values[z];qp=q0.slerp(q1,u)
  angle=q.rotation_difference(qp).angle;angle=min(angle,2*math.pi-angle)
  return (p-p0.lerp(p1,u)).length+radius*(angle+(k-k0.lerp(k1,u)).length)
 keep={0,len(frames)-1};stack=[(0,len(frames)-1)]
 while stack:
  a,z=stack.pop()
  if z-a<=1:continue
  e,i=max((error(i,a,z),i) for i in range(a+1,z))
  if e>TOL:keep.add(i);stack.extend([(a,i),(i,z)])
 ids=sorted(keep);kept[b.name]=ids;errors[b.name]=max([error(i,a,z) for a,z in zip(ids,ids[1:]) for i in range(a+1,z)]+[0])
 for i in ids:
  p,q,k=values[i];b.rotation_mode='QUATERNION';b.location=p;b.rotation_quaternion=q;b.scale=k
  for prop in ['location','rotation_quaternion','scale']:b.keyframe_insert(prop,frame=frames[i],group=b.name)
rig.animation_data.action.name='Walk';rig.animation_data.action.use_fake_user=True
for layer in rig.animation_data.action.layers:
 for strip in layer.strips:
  for slot in rig.animation_data.action.slots:
   bag=strip.channelbag(slot)
   if bag:
    for fc in bag.fcurves:
     for kp in fc.keyframe_points:kp.interpolation='LINEAR'
scene.render.fps=60;scene.frame_start=1;scene.frame_end=27;scene.frame_set(1);bpy.context.view_layer.update()
# Width normalization matches existing enemy imports; runtime presentation scale remains .55.
rig.scale=(1/4.12951922416687,)*3;rig.location.z=-.035/4.12951922416687
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'medium-guardian-walk.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_force_sampling=False,export_animation_mode='ACTIVE_ACTIONS',export_cameras=False,export_lights=False,export_extras=True,export_skins=True,export_morph=False)
raw=(OUT/'medium-guardian-walk.glb').read_bytes();jn=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+jn]);assert len(doc['animations'])==1;doc['animations'][0]['name']='Walk'
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);tail=raw[20+jn:];(OUT/'medium-guardian-walk.glb').write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(js)+len(tail))+struct.pack('<I4s',len(js),b'JSON')+js+tail)
mesh.data.calc_loop_triangles();report={'source_original_meshes':89,'authoring_meshes':len(obs),'runtime_mesh_objects':1,'runtime_materials':1,'runtime_bones':len(rig.pose.bones),'walk_bones':14,'runtime_triangles':len(mesh.data.loop_triangles),'runtime_vertices_blender':len(mesh.data.vertices),'dense_pose_samples_per_bone':261,'dense_main_scalar_keys':14*261*10,'reduced_scalar_keys':sum(len(v)*10 for v in kept.values()),'kept_pose_keys_per_bone':{k:len(v) for k,v in kept.items()},'rdp_proxy_threshold_model':TOL,'rdp_max_proxy_error_model':max(errors.values()),'target_actual_vertex_error_model':.002,'atlas_resolution':SIZE,'normal_atlas_resolution':SIZE,'normal_strength':4,'atlas_rgba8_uncompressed_upper_bytes':SIZE*SIZE*4*4,'glb_bytes':(OUT/'medium-guardian-walk.glb').stat().st_size,'physics_ik_constraints':0,'runtime_cost_scope':'Runtime animation interpolation/skinning/render still needed; FPS/GPU/process RAM unmeasured.'}
(OUT/'walk-runtime-stats.json').write_text(json.dumps(report,indent=2));print('RUNTIME_DONE',json.dumps(report),flush=True)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'medium-guardian-walk-runtime.blend'),compress=True)
