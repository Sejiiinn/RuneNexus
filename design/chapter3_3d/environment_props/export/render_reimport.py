"""Single integrated review: actual GLB mounted on unchanged approved source tiles."""
import bpy,json,hashlib
from mathutils import Matrix
from pathlib import Path
H=Path(__file__).resolve().parent
ROOT=H.parents[3]
ASSET=ROOT/'assets/images/stage1_3d/environment/chapter3_props.glb'
bpy.ops.wm.open_mainfile(filepath=str(H.parent/'mounted-scene.blend'))
s=bpy.context.scene
names=('elbow_pipe','side_conduit','exhaust_vent')
mounts={name:next(o for o in s.objects if o.name==name+' mounted') for name in names}
def clear_children(ob):
 for child in list(ob.children):
  clear_children(child);bpy.data.objects.remove(child,do_unlink=True)
for ob in mounts.values():clear_children(ob)
before=set(s.objects)
bpy.ops.import_scene.gltf(filepath=str(ASSET))
for o in set(s.objects)-before:
 if o.type!='MESH':continue
 name=next(n for n in names if o.name.split('.')[0]==n)
 o.parent=mounts[name];o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4)
s.cycles.samples=48
s.render.filepath=str(H/'integrated-v2-glb-mounted.png')
bpy.ops.render.render(write_still=True)
(H/'render-check.json').write_text(json.dumps({'glb_sha256':hashlib.sha256(ASSET.read_bytes()).hexdigest(),'image':'integrated-v2-glb-mounted.png','camera':'mounted source hero','views':1,'purpose':'source/export combined representative visual review'},indent=2)+'\n')
print('REIMPORT_RENDER_READY',flush=True)
