"""승인 원본의 정적 스테이지 환경을 실메시로 보존하여 GLB에 추가."""
import bpy,math,json,re,os
from mathutils import Matrix,Vector
ROOT='/Users/sejin/Documents/Codex/RuneNexus';OUT=ROOT+'/design/stage1_3d/environment';ASSET=ROOT+'/assets/images/stage1_3d/environment/terrain.glb'
bpy.ops.wm.open_mainfile(filepath=OUT+'/terrain-approved.blend');scene=bpy.context.scene
old=bpy.data.objects.get('stage1_environment')
if old:
 for ob in list(old.children_recursive):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.data.objects.remove(old,do_unlink=True)
shared={key:bpy.data.materials[key] for key in ['C1_mossy_PBR_stone','C1_worn_earth_cobbles','C1_natural_rock_faces']}
prefixes=('earth foundation','worn earth path','moss covered build stone','exposed natural rock','moss edge','edge grass','exposed root')
with bpy.data.libraries.load(ROOT+'/design/stage1_3d/actor_refinement/stage1-actors-refined.blend',link=False) as (src,dst):
 dst.objects=[name for name in src.objects if name.startswith(prefixes)]
source_objects=list(dst.objects);assert len(source_objects)>200,len(source_objects)
root=bpy.data.objects.new('stage1_environment',None);scene.collection.objects.link(root)
source=open(ROOT+'/lib/data/definitions/game_stage_maps.dart').read().split('const gameStage2Map')[0];tiles=re.findall(r'TileType\.(\w+)',source);assert len(tiles)==80
root['columns']=8;root['rows']=10;root['tileTypes']=tiles;root['source']='actor_refinement/stage1-actors-refined.blend';root['tileSize']=1.0
root['gridCenterConvention']='column-3.5, row-4.5';root['surfaceReference']=0.0
counts={key:sum(o.name.startswith(key) for o in source_objects) for key in prefixes};print('SOURCE_COUNTS',json.dumps(counts));groups={}
transform=Matrix.Scale(.5,4)@Matrix.Translation((0,0,-.082))
for o in source_objects:
 scene.collection.objects.link(o);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 # Convert applies the original bevel, weighted normal and curve thickness.
 bpy.ops.object.convert(target='MESH');o=bpy.context.object
 for slot in o.material_slots:
  for key,value in shared.items():
   if slot.material and slot.material.name.startswith(key):slot.material=value;break
 o.matrix_world=transform@o.matrix_world;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 assert len(o.data.materials)==1,(o.name,len(o.data.materials))
 key=o.data.materials[0].name;groups.setdefault(key,[]).append(o)
for key,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name='stage1_static_'+key;o.parent=root
root['sourceObjectCounts']=counts;root['staticMeshCount']=len(groups)
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=ASSET,export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_extras=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/terrain-approved.blend')
print('FULL_STATIC_ENVIRONMENT_EXPORTED',len(groups))
