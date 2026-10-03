"""Export the approved Lightning A solid model with selectable coil detail.

Run with Blender 4.3+: blender -b --python export_static.py -- --source PATH
No VFX is exported. Six equal-rest collar materials are deduplicated to one;
unused UVs are excluded. Every part must be closed and consistently wound before
back-face culling is enabled. Geometry is baked into each rigid group's local
space so VERTEX is meaningful for station-based charge effects in Godot.
The approved blend is never saved or modified on disk. --coil-segments 0 exports
its original evaluated topology; 24 removes unnecessary bevels along smooth coil
seams; 16 also resamples only those circular coils. Rim bevels and PBR stay intact.
"""
import argparse, hashlib, json, math, struct, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Matrix, Vector

P=Path(__file__).resolve().parent
ap=argparse.ArgumentParser()
ap.add_argument('--source',default=str(P/'lightning-A-approved.blend'))
ap.add_argument('--output',default=str(P.parents[2]/'assets/images/stage1_3d/turrets/lightning.glb'))
ap.add_argument('--coil-segments',type=int,choices=(0,16,24),default=16)
ap.add_argument('--manifest',default=str(P/'export-manifest.json'))
a=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
source=Path(a.source).resolve();out=Path(a.output).resolve()
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene;scene.frame_set(1)
asset=bpy.data.collections['01 LIGHTNING | editable solid parts']
root=bpy.data.objects['turret_root'];head=bpy.data.objects['turret_head'];barrel=bpy.data.objects['turret_barrel'];muzzle=bpy.data.objects['muzzle']
parts=[o for o in asset.objects if o.type=='MESH']
assert len(parts)==153
assert len([o for o in parts if 'lavender induction band' in o.name])==6
coils=[o for o in parts if ' coil ' in o.name and
       ('black insulator' in o.name or 'lavender induction band' in o.name)]
assert len(coils)==18
# These are four-loop hollow cylinders, not torus primitives. The source's
# 0.2-radian bevel threshold also catches the 15-degree circumference seams.
# Beveling only the 90-degree rim corners keeps the cross-section chamfers while
# avoiding tiny longitudinal chamfers on an already smoothly shaded cylinder.
if a.coil_segments:
 for ob in coils:
  original=ob.data
  assert len(original.vertices)==96 and len(original.polygons)==96,ob.name
  assert len(ob.modifiers)==2 and ob.modifiers[0].type=='BEVEL' and ob.modifiers[1].type=='WEIGHTED_NORMAL',ob.name
  assert ob.modifiers[0].segments==1,ob.name
  if a.coil_segments!=24:
   n=a.coil_segments;vertices=[];faces=[]
   for ring in range(4):
    ref=original.vertices[ring*24].co;r=ref.xy.length;z=ref.z
    for v in original.vertices[ring*24:(ring+1)*24]:
     assert abs(v.co.xy.length-r)<1e-7 and abs(v.co.z-z)<1e-7,ob.name
    for i in range(n):
     theta=math.tau*i/n
     vertices.append((r*math.cos(theta),r*math.sin(theta),z))
   for i in range(n):
    j=(i+1)%n
    faces.extend(((i,j,n+j,n+i),(n+i,n+j,3*n+j,3*n+i),
                  (2*n+i,3*n+i,3*n+j,2*n+j),(j,i,2*n+i,2*n+j)))
   me=bpy.data.meshes.new(ob.name+' runtime coil');me.from_pydata(vertices,[],faces)
   for material in original.materials:me.materials.append(material)
   for face in me.polygons:
    source_face=original.polygons[face.index%4]
    face.use_smooth=source_face.use_smooth;face.material_index=source_face.material_index
   me.update();ob.data=me
  ob.modifiers[0].angle_limit=math.radians(30)
for o in (root,head,barrel,muzzle):o.animation_data_clear()
bpy.context.view_layer.update()
materials={}
for ob in parts:
 for m in ob.data.materials:
  key='08 | lavender charge collars' if m.name.startswith('CHARGE |') else m.name
  if key not in materials:
   cp=m.copy();cp.name=key+' runtime';cp.animation_data_clear();cp.node_tree.animation_data_clear();cp.use_backface_culling=True
   materials[key]=cp
# Keep the exact current evaluated source values, but share identical collar PBR.
collar_material=materials['08 | lavender charge collars']
originals=[];exports=[];triangles=0;part_triangles={}
deps=bpy.context.evaluated_depsgraph_get()
col=bpy.data.collections.new('RUNTIME | consolidated solid geometry');scene.collection.children.link(col)
for group in (root,head,barrel):
 copies=[]
 for ob in parts:
  if ob.parent!=group:continue
  me=bpy.data.meshes.new_from_object(ob.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
  bm=bmesh.new();bm.from_mesh(me)
  assert all(e.is_manifold and e.is_contiguous for e in bm.edges),ob.name
  assert bm.calc_volume(signed=True)>0,ob.name
  part_triangles[ob.name]=sum(len(f.verts)-2 for f in bm.faces)
  triangles+=part_triangles[ob.name]
  bm.free()
  # Preserve evaluated weighted normals, including the selected coil profile.
  for i,m in enumerate(me.materials):
   key='08 | lavender charge collars' if m.name.startswith('CHARGE |') else m.name
   me.materials[i]=materials[key]
  # No source material has a texture or normal map. Removing UVs is lossless.
  for uv in list(me.uv_layers):me.uv_layers.remove(uv)
  cp=bpy.data.objects.new(ob.name+' evaluated',me);col.objects.link(cp)
  cp.matrix_world=ob.matrix_world.copy();copies.append(cp)
 bpy.ops.object.select_all(action='DESELECT')
 for cp in copies:cp.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();cp=bpy.context.object
 cp.name=group.name+'_geometry';cp.data.name=cp.name+'_mesh'
 # Apply local transform to mesh before parenting, preserving custom normals.
 cp.data.transform(group.matrix_world.inverted() @ cp.matrix_world)
 cp.parent=group;cp.matrix_parent_inverse=Matrix.Identity(4);cp.matrix_basis=Matrix.Identity(4)
 exports.append(cp)
assert triangles=={0:23140,24:19684,16:17380}[a.coil_segments]
for ob in parts:ob.hide_set(True);ob.hide_render=True
bpy.ops.object.select_all(action='DESELECT')
for ob in [root,head,barrel,muzzle]+exports:ob.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_apply=False,export_animations=False,export_cameras=False,export_lights=False,export_yup=True,export_texcoords=False,export_tangents=False,export_normals=True,export_extras=False)
raw=out.read_bytes();gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
contract={'mesh_nodes':len(gltf['meshes']),'materials':len(gltf['materials']),
          'surfaces':sum(len(m['primitives']) for m in gltf['meshes']),'hierarchy_nodes':len(gltf['nodes'])}
assert contract=={'mesh_nodes':3,'materials':8,'surfaces':20,'hierarchy_nodes':7}
metadata={
 'source':str(source.relative_to(P)) if source.is_relative_to(P) else str(source),
 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'output':out.name,'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),
 'output_bytes':out.stat().st_size,'triangles':triangles,'original_parts':len(parts),
 'method':'Approved source at frame 1; selected coil profile only; preserved bevel widths and evaluated weighted normals; no UVs; culled closed solids; equal collar rest materials deduplicated; three rigid groups in local coordinates',
 'coil_segments':a.coil_segments or 24,'source_coil_segments':24,
 'coil_seam_bevels':not bool(a.coil_segments),'source_triangles':23140,
 'coil_triangles':sum(part_triangles[o.name] for o in coils),
 'unchanged_other_triangles':sum(v for k,v in part_triangles.items() if k not in {o.name for o in coils}),
 'part_triangles':part_triangles,
 'runtime_contract':contract,
 'material_count':len(materials),
 'rest_emission_strength':{key:float(m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value) for key,m in materials.items()},
 'collar_station_centers_godot_barrel_local':[[x,.181,z]for x in (-.213,.213) for z in (.284,.091,-.102)],
 'muzzle_godot_barrel_local':[0,.181,.566],
 'game_camera_comparison':'pending',
 'unverified':['Android device rendering and performance','actual game-camera acceptance after integration'],
}
Path(a.manifest).write_text(json.dumps(metadata,indent=2))
print('RUNTIME_EXPORT',json.dumps({k:v for k,v in metadata.items() if k!='part_triangles'}),flush=True)
