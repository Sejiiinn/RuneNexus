"""Reuse V3 baked geometry/materials. Export truncated landing plus one whole-exit root track."""
import bpy,json,struct,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.data.scenes['Guardian_WholeExit_Runtime']
for w in bpy.context.window_manager.windows:w.scene=s
for other in list(bpy.data.scenes):
 if other!=s and not other.objects:bpy.data.scenes.remove(other)
s.frame_set(1);bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in s.objects if o.type=='ARMATURE')
bpy.ops.export_scene.gltf(filepath=str(OUT/'medium-guardian-whole-exit.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_force_sampling=False,export_animation_mode='ACTIVE_ACTIONS',export_cameras=False,export_lights=False,export_extras=True,export_skins=True,export_morph=False)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'medium-guardian-whole-exit-runtime.blend'),compress=True)
def load(path):
 data=path.read_bytes();n=struct.unpack_from('<I',data,12)[0];return data,json.loads(data[20:20+n]),data[28+n:]
b,d,bin=load(OUT/'medium-guardian-whole-exit.glb');old,od,ob=load(OUT.parent/'v3-rubble/medium-guardian-rubble.glb')
def hashes(d,bin):
 return [hashlib.sha256(bin[d['bufferViews'][im['bufferView']].get('byteOffset',0):d['bufferViews'][im['bufferView']].get('byteOffset',0)+d['bufferViews'][im['bufferView']]['byteLength']]).hexdigest() for im in d['images']]
assert len(d['animations'])==1 and len(d['meshes'])==1 and len(d['materials'])==1
assert hashes(d,bin)==hashes(od,ob),'PBR image bytes changed'
dims={'SCALAR':1,'VEC3':3,'VEC4':4};a=d['animations'][0];ac=d['accessors'];rootidx=next(i for i,n in enumerate(d['nodes'])if n.get('name')=='whole_exit_runtime');rootchannels=[c for c in a['channels']if c['target']['node']==rootidx]
assert len(rootchannels)==1 and rootchannels[0]['target']['path']=='translation'
report={'glb_bytes':len(b),'mesh_count':len(d['meshes']),'material_count':len(d['materials']),'skin_count':len(d['skins']),'joint_count':len(d['skins'][0]['joints']),'animation_count':len(d['animations']),'animation_name':a['name'],'channels':len(a['channels']),'scalar_key_values':sum(ac[x['output']]['count']*dims[ac[x['output']]['type']]for x in a['samplers']),'duration_seconds':max(ac[x['input']]['max'][0]for x in a['samplers'])-min(ac[x['input']]['min'][0]for x in a['samplers']),'whole_exit_root_channels':len(rootchannels),'whole_exit_path':'translation','pbr_image_bytes_identical_to_v3':True,'pbr_image_sha256':hashes(d,bin),'runtime_physics_ik':False,'scope':'Existing V3 bake reused. Runtime interpolation/skinning/render remain; FPS unmeasured.'}
(OUT/'glb-stats.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
