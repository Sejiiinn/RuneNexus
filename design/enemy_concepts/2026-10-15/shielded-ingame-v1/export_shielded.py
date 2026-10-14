"""Export adopted shielded asset using original UVs/PBR and a native EMIT bake.
Run using Blender bpy; only local external-SSD editing sources are modified.
"""
import bpy,math,json,hashlib,struct
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus');A=Path('/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/shielded-01-20261014');D=ROOT/'design/enemy_concepts/2026-10-15/shielded-ingame-v1';O=A/'previews/sv-ingame-v1';O.mkdir(exist_ok=True,parents=True)
AD=A/'manifests/single-view-idle-emission-adopted-v1.json';ad=json.loads(AD.read_text());SOURCE=Path(ad['native']['path']);DEST=A/'blender/shielded-01-single-view-ingame-v1.blend';GLB=ROOT/'assets/images/stage1_3d/enemies/shielded.glb'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert Path('/Volumes/KIOXIA_MAC').is_mount() and sha(SOURCE)==ad['native']['sha256']
if bpy.data.filepath!=str(SOURCE):bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
s=bpy.context.scene;s.frame_set(1);source_meshes=[o for o in s.objects if o.type=='MESH'];mat=source_meshes[0].data.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');albedo=nodes['GeneratedUltraTexAlbedo'].image;normal=next(n for n in nodes if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name=='Non-Color').image
# Bake only the authored emission color, normalized by its explicit 3.8 strength.
image=bpy.data.images.new('Shielded_RuneEmission_2048',width=2048,height=2048,alpha=False);image.colorspace_settings.name='sRGB';image.filepath_raw=str(A/'textures/shielded-01-single-view-emission2048-v1.png');image.file_format='PNG'
target=nodes.new('ShaderNodeTexImage');target.name='EmissionBakeTarget';target.image=image;nodes.active=target
em=nodes.new('ShaderNodeEmission');links.new(bs.inputs['Emission Color'].links[0].from_socket,em.inputs['Color']);links.new(nodes['RuneEmissionStrength'].inputs[0].links[0].from_socket,em.inputs['Strength']);links.new(em.outputs[0],out.inputs['Surface'])
bpy.ops.object.select_all(action='DESELECT')
for o in source_meshes:o.select_set(True)
bpy.context.view_layer.objects.active=source_meshes[0];s.render.engine='CYCLES';s.cycles.samples=1;s.cycles.device='CPU';s.render.bake.use_selected_to_active=False;s.render.bake.use_clear=True;s.render.bake.margin=4
nodes.active=target;bpy.ops.object.bake(type='EMIT');image.save();image.pack();links.new(bs.outputs[0],out.inputs['Surface']);nodes.remove(em)
# Standard glTF PBR shader; source Albedo and tangent Normal are reused unmodified.
game_mat=bpy.data.materials.new('Shielded_OriginalPBR_Emissive');game_mat.use_nodes=True;ns=game_mat.node_tree.nodes;lk=game_mat.node_tree.links;ns.clear();gb=ns.new('ShaderNodeBsdfPrincipled');gb.inputs['Metallic'].default_value=0;gb.inputs['Roughness'].default_value=.8;gb.inputs['Emission Strength'].default_value=3.8;go=ns.new('ShaderNodeOutputMaterial');lk.new(gb.outputs[0],go.inputs['Surface'])
for im,name,socket in [(albedo,'Original_Albedo','Base Color'),(normal,'Original_Normal','Normal'),(image,'Baked_RuneEmission','Emission Color')]:
 n=ns.new('ShaderNodeTexImage');n.name=name;n.image=im
 if socket=='Normal':
  nm=ns.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=1;lk.new(n.outputs['Color'],nm.inputs['Color']);lk.new(nm.outputs[0],gb.inputs[socket])
 else:lk.new(n.outputs['Color'],gb.inputs[socket])
for o in source_meshes:o.data.materials[0]=game_mat
# Stable ASCII node names and rigid physical groups. The input coordinates are already Y-up.
root=next(o for o in s.objects if o.type=='EMPTY' and o.parent is None);root.name='HoverRoot'
names=['Body','Ring','Stone_LowerLeft','Stone_UpperRight','Stone_LowerRight','Stone_UpperLeft'];newnames=['Body','Ring','StoneLowerLeft','StoneUpperRight','StoneLowerRight','StoneUpperLeft'];parts=[];controls=[]
for old,new in zip(names,newnames):
 o=bpy.data.objects[old];o.name=new;o.parent.name=new+'Pivot';parts.append(o);controls.append(o.parent)
# Each stone gets a distinct integer number of turns over the same 24-second loop.
turns=[1,-2,3,-4]
for j,c in enumerate(controls[2:]):
 multiplier=abs(turns[j]);direction=1 if turns[j]>0 else -1
 for fc in c.animation_data.drivers:
  expr=fc.driver.expression
  if fc.data_path=='rotation_euler':fc.driver.expression=f'{direction}*({multiplier}*(frame-1)*2*pi/576)'
  else:fc.driver.expression=expr.replace('(frame-1)*2*pi/576',f'{multiplier}*(frame-1)*2*pi/576')
 c['turns_per_24_seconds']=turns[j]
# Sample transforms first, then replace drivers with editable quaternion/translation keys.
animated=[root]+controls[1:];samples={o.name:[] for o in animated}
for f in range(1,578,2):
 s.frame_set(f)
 for o in animated:samples[o.name].append((f,o.matrix_basis.copy().decompose()))
for o in animated:
 o.animation_data_clear();o.rotation_mode='QUATERNION';previous=None
 for f,(loc,quat,scale) in samples[o.name]:
  if previous is not None and previous.dot(quat)<0:quat=-quat
  previous=quat.copy();o.location=loc;o.rotation_quaternion=quat;o.scale=scale;o.keyframe_insert(data_path='location',frame=f);o.keyframe_insert(data_path='rotation_quaternion',frame=f)
 if o.animation_data and o.animation_data.action:
  o.animation_data.action.name='Idle_'+o.name
  for layer in o.animation_data.action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for fc in bag.fcurves:
      for key in fc.keyframe_points:key.interpolation='LINEAR'
s.frame_start=1;s.frame_end=577;s.render.fps=24;s.frame_set(1);s.name='Idle'
# Runtime real lights use these body-local positions; no studio/rune lights or cameras exported.
anchors=[{'name':'RuneFront','parent':'BodyPivot','position_y_up':[-float(controls[0].location.x),-.005-float(controls[0].location.y),.315-float(controls[0].location.z)],'source_energy_watts':1.25},{'name':'RuneBack','parent':'BodyPivot','position_y_up':[-float(controls[0].location.x),-.005-float(controls[0].location.y),-.275-float(controls[0].location.z)],'source_energy_watts':.65}]
for a in anchors:
 ob=bpy.data.objects.new(a['name'],None);s.collection.objects.link(ob);ob.parent=controls[0];ob.location=a['position_y_up'];ob.empty_display_size=.025
s.render.engine='BLENDER_EEVEE';bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(DEST),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in [root]+controls+parts+[bpy.data.objects[a['name']] for a in anchors]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(GLB),export_format='GLB',use_selection=True,export_yup=False,export_normals=True,export_tangents=True,export_materials='EXPORT',export_cameras=False,export_lights=False,export_extras=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='Idle',export_force_sampling=True,export_frame_range=True,export_frame_step=1,export_optimize_animation_size=False,export_optimize_animation_keep_anim_object=True)
# Normalize the merged animation's public name without touching any binary data.
raw=GLB.read_bytes();length,ctype=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+length]);assert len(g.get('animations',[]))==1,g.get('animations');g['animations'][0]['name']='Idle'
# Blender exports frame1 at 1/fps. Shift only animation input times to the public0..24 contract.
# The curve outputs, geometry, image bytes and every non-time binary byte remain unchanged.
bo=20+length;binlength,bintype=struct.unpack_from('<II',raw,bo);binary=bytearray(raw[bo+8:bo+8+binlength])
for ai in sorted({x['input'] for an in g['animations'] for x in an['samplers']}):
 accessor=g['accessors'][ai];view=g['bufferViews'][accessor['bufferView']];assert accessor['componentType']==5126 and accessor['type']=='SCALAR' and 'byteStride' not in view
 offset=view.get('byteOffset',0)+accessor.get('byteOffset',0);times=np.frombuffer(binary,dtype='<f4',count=accessor['count'],offset=offset).copy();shifted=(times.astype(np.float64)-float(times[0])).astype('<f4');binary[offset:offset+shifted.nbytes]=shifted.tobytes();accessor['min']=[float(shifted.min())];accessor['max']=[float(shifted.max())]
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*(-len(j)%4);tail=struct.pack('<II',len(binary),bintype)+binary;new=struct.pack('<4sII',b'glTF',2,12+8+len(j)+len(tail))+struct.pack('<II',len(j),ctype)+j+tail;GLB.write_bytes(new)
metadata={'source':ad['native'],'native':{'path':str(DEST),'sha256':sha(DEST)},'glb':{'path':str(GLB),'sha256':sha(GLB)},'emission_bake':{'path':image.filepath_raw,'sha256':sha(image.filepath_raw),'size':[2048,2048],'method':'Blender Cycles EMIT, original UV, normalized source emission color; glTF emissive strength3.8'},'source_triangles':9757,'axis':'glTF Y-up; source coordinates already Y-up; export_yup=False','bounds_y_up':{'min':[-.376177877,-.499604106,-.324245393],'max':[.374659181,.415731490,.323511064]},'animation':{'name':'Idle','seconds':24,'fps':24,'time_start_seconds':0,'end_frame':577,'stone_turns':dict(zip(newnames[2:],turns)),'runtime':'seek Idle using authoritative combat clock; 4 stones are baked at distinct speeds'},'node_names':{'hover':'HoverRoot','meshes':newnames,'pivots':[c.name for c in controls]},'rune_light_anchors':anchors,'pbr':{'metallic':0,'roughness':.8,'emission_strength':3.8,'original_albedo_normal_bytes_unchanged':True,'authoring_texture_resolution':2048,'game_import_size_limit':1024},'game_shield_shell':'Runtime state effect, not part of the original9757 triangles','validation':'Exported; reimport and independent game verification pending'}
(D/'asset-contract.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2));(O/'asset-contract.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2));print(json.dumps(metadata))
