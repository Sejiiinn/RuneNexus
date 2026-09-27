"""Reuse exact static PBR GLB geometry/atlas; attach baked rigid skeleton.
Run in isolated Blender with run .blend open, never mutate the live authoring app.
"""
import bpy,json,struct,hashlib,shutil
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.kdtree import KDTree
OUT=Path(__file__).resolve().parent
REPO=next(p for p in OUT.parents if (p/'AGENTS.md').exists())
TARGET=REPO/'assets/images/stage1_3d/enemies/fast.glb'
SOURCE=OUT/'fast-rune-hound-run.blend'
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
BAKE_MULTIPLIER=4
contract=json.loads((OUT/'motion-contract.json').read_text());mapping=json.loads((OUT/'rig-map.json').read_text())['assignments']
src=bpy.data.scenes['Fast_Hound_Run']
for w in bpy.context.window_manager.windows:w.scene=src
rig=src.objects['Fast_Hound_Run_Rig'];rig.animation_data.action.name='Run';src.frame_set(1)
rig.data.pose_position='REST';bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
points=[]
for name,bone in mapping.items():
    ob=src.objects['Run_'+name];ev=ob.evaluated_get(deps);me=ev.to_mesh()
    for v in me.vertices:points.append((ob.matrix_world@v.co,bone))
    ev.to_mesh_clear()
kd=KDTree(len(points))
for i,(co,bn) in enumerate(points):kd.insert(co,i)
kd.balance()
rig.data.pose_position='POSE'
sc=bpy.data.scenes.new('Fast_Hound_Run_Runtime')
for w in bpy.context.window_manager.windows:w.scene=sc
bpy.ops.import_scene.gltf(filepath=str(OUT.parent.parent/'3d/fast-rune-hound.glb'))
meshes=[o for o in sc.objects if o.type=='MESH'];assert len(meshes)==1
ob=meshes[0];ob.name='Fast_Rune_Hound_PBR_Run';ob.data.transform(ob.matrix_world);ob.parent=None;ob.matrix_world=Matrix.Identity(4)
for o in list(sc.objects):
    if o!=ob:bpy.data.objects.remove(o,do_unlink=True)
rr=rig.copy();rr.data=rig.data.copy();rr.name='Fast_Rune_Hound_Skeleton';sc.collection.objects.link(rr);rr.parent=None;rr.matrix_world=Matrix.Identity(4)
root=bpy.data.objects.new('Fast_Rune_Hound',None);sc.collection.objects.link(root)
root.scale=(1/contract['source_width'],)*3;root.location.z=contract['normalized_ground_offset']
rr.parent=root;ob.parent=rr
old_action=rr.animation_data.action;old_action.name='Run_Source'
rr.animation_data.action=old_action.copy();rr.animation_data.action.name='Run'
for layer in rr.animation_data.action.layers:
    for strip in layer.strips:
        for slot in rr.animation_data.action.slots:
            bag=strip.channelbag(slot)
            if bag:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:
                        kp.co.x=(kp.co.x-1)*BAKE_MULTIPLIER;kp.handle_left.x=(kp.handle_left.x-1)*BAKE_MULTIPLIER;kp.handle_right.x=(kp.handle_right.x-1)*BAKE_MULTIPLIER
# Isolated export process only: exclude the unshifted authoring action from glTF.
for action in list(bpy.data.actions):
    if action!=rr.animation_data.action:bpy.data.actions.remove(action)
groups={name:ob.vertex_groups.new(name=name) for name in rr.data.bones.keys()};errors=[];counts={k:0 for k in groups}
for v in ob.data.vertices:
    co,index,d=kd.find(v.co);bn=points[index][1];groups[bn].add([v.index],1.,'REPLACE');errors.append(d);counts[bn]+=1
assert max(errors)<1e-5,max(errors)
mod=ob.modifiers.new('Rigid one-bone skin','ARMATURE');mod.object=rr;mod.use_deform_preserve_volume=False
for k,v in contract.items():
    if isinstance(v,(int,float,str)):root[k]=v
sc.render.fps=contract['fps']*BAKE_MULTIPLIER;sc.frame_start=0;sc.frame_end=contract['frames_per_cycle']*BAKE_MULTIPLIER;sc.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for o in [root,rr,ob]:o.select_set(True)
bpy.context.view_layer.objects.active=rr
bpy.ops.export_scene.gltf(filepath=str(OUT/'fast-rune-hound-run.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_frame_range=True,export_force_sampling=True,export_animation_mode='ACTIONS',export_cameras=False,export_lights=False,export_extras=True,export_skins=True,export_def_bones=False)
raw=(OUT/'fast-rune-hound-run.glb').read_bytes();ln=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+ln]);tris=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
assert tris==20214,tris
report={'triangles':tris,'mesh_count':len(doc['meshes']),'skin_count':len(doc.get('skins',[])),'joints':len(doc['skins'][0]['joints']),'animation_names':[a.get('name') for a in doc['animations']],'max_source_vertex_mapping_error':max(errors),'single_bone_weight_per_vertex':True,'vertex_count':len(ob.data.vertices),'bone_vertex_counts':counts,'glb_bytes':len(raw),'source_static_glb':'../../3d/fast-rune-hound.glb','normalization':'Common parent 1/source_width; z += -author_ground_z/source_width; 0.48 runtime scale gives correct tile size.'}
report['animation_times']=[{'min':doc['accessors'][a['samplers'][0]['input']]['min'],'max':doc['accessors'][a['samplers'][0]['input']]['max']} for a in doc['animations']]
report['baked_samples_per_second']=sc.render.fps
assert report['animation_names']==['Run'],report['animation_names']
assert report['joints']==24,report['joints']
assert len(doc['skins'])==1 and len(doc['meshes'])==1
for a in doc['animations']:
    for sampler in a['samplers']:
        ac=doc['accessors'][sampler['input']]
        assert abs(ac['min'][0])<1e-7 and abs(ac['max'][0]-contract['cycle_seconds'])<1e-6
# Imported atlas is in author space; source rest geometry and root give width/floor.
rest_min=[min(v.co[i] for v in ob.data.vertices) for i in range(3)]
rest_max=[max(v.co[i] for v in ob.data.vertices) for i in range(3)]
normalized_width=(rest_max[0]-rest_min[0])/contract['source_width']
normalized_floor=rest_min[2]/contract['source_width']+contract['normalized_ground_offset']
assert abs(normalized_width-1)<1e-5,normalized_width
assert abs(normalized_floor)<1e-5,normalized_floor
report.update({'source_blend_sha256':source_hash,'glb_sha256':hashlib.sha256(raw).hexdigest(),'approved_version':'gallop-kick-v9','target':str(TARGET.relative_to(REPO)),'rest_normalized_width':normalized_width,'rest_normalized_floor':normalized_floor,'author_forward':'-Y','gltf_godot_forward':'+Z; same standard Blender glTF axis conversion as normal guardian','cycle_seconds':contract['cycle_seconds'],'stride_tiles':contract['stride_tiles'],'stride_normalized_units':contract['stride_normalized_units'],'runtime_presentation_scale':.48,'tile_speed':contract['tile_speed'],'materials':doc.get('materials',[]),'texture_count':len(doc.get('textures',[])),'image_count':len(doc.get('images',[]))})
backup=OUT/'previous-game-fast.glb'
if TARGET.exists() and not backup.exists():shutil.copy2(TARGET,backup)
TARGET.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(OUT/'fast-rune-hound-run.glb',TARGET)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(OUT/'runtime-export.json').write_text(json.dumps(report,indent=2))
print('RUN_EXPORT_COMPLETE',json.dumps(report),flush=True)
