import bpy,json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];source=root/'chapter3-thick-tiles.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
for name in ('05_Panel_solid','06_Panel_vent'):
 for ob in bpy.data.objects[name].children:ob.hide_render=True;ob.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
# Only standalone source panel visibility changed; meshes and materials unchanged.
report=root.parent/'export/geometry-check.json';data=json.loads(report.read_text());data['baked_source_sha256']=data['source_sha256'];data['source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest();data['post_export_edit']='Standalone source panel visibility only; geometry and materials unchanged'
report.write_text(json.dumps(data,indent=2)+'\n')
bpy.context.scene.render.filepath=str(root/'modular_revision/assembled-source.png');bpy.ops.render.render(write_still=True)
