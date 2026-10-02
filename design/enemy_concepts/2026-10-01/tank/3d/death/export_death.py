"""Background GLB export of the MCP-authored death library, atlas reuse only."""
import bpy, json, struct, hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
scene=next(s for s in bpy.data.scenes if s.name.startswith('Tank_Death_Runtime'))
for w in bpy.context.window_manager.windows: w.scene=scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for o in scene.objects:
    if o.type in ['MESH','ARMATURE']: o.select_set(True)
bpy.context.view_layer.objects.active=rig
path=OUT/'tank-death.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_force_sampling=False,export_animation_mode='ACTIVE_ACTIONS',export_cameras=False,export_lights=False,export_extras=True,export_skins=True,export_morph=False)
raw=path.read_bytes()
length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length])
assert len(doc['animations'])==1
doc['animations'][0]['name']='Death'
encoded=json.dumps(doc,separators=(',',':')).encode()
encoded+=b' '*((-len(encoded))%4)
tail=raw[20+length:]
path.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(tail))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+tail)
print('TANK_DEATH_EXPORTED',path.stat().st_size)
