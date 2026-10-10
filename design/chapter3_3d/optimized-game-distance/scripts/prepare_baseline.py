"""Fresh checkout: export full native geometry to an ignored baseline, no bake.

Run background Blender --python this_file.py. Never writes the original blend,
PBR PNGs, or the game GLB. Re-export bytes may depend on the Blender exporter
version; mesh/atlas semantics are checked against the original six-root budget.
"""
import bpy, hashlib, json, argparse, sys
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]
SOURCE=OUT.parent/'export/chapter3-native-export.blend'
BASE=OUT/'checks/chapter3_tiles-before.glb'
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,default=BASE)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
BASE=args.output.resolve()
NAMES={'path_tile':24416,'grate_tile':30320,'build_tile':24916,'plain_build_tile':16276,'panel_solid':2660,'panel_vent':4048}
assert bpy.app.background
assert not BASE.exists(),'Existing baseline is preserved; pass another --source to optimizer or move it explicitly'
sha=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
s=next(s for s in bpy.data.scenes if all(n in s.objects for n in NAMES))
bpy.context.window.scene=s
bpy.ops.object.select_all(action='DESELECT')
dg=bpy.context.evaluated_depsgraph_get()
for name,count in NAMES.items():
    ob=s.objects[name];ob.select_set(True)
    evaluated=ob.evaluated_get(dg);me=evaluated.to_mesh();me.calc_loop_triangles();assert len(me.loop_triangles)==count,(name,len(me.loop_triangles),count);evaluated.to_mesh_clear()
BASE.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(BASE),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_normals=True,export_texcoords=True,export_tangents=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==sha
(OUT/'checks/baseline-regeneration.json').write_text(json.dumps({'source':str(SOURCE),'source_sha256':sha,'output':str(BASE),'output_sha256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'blender':bpy.app.version_string,'rebaked':False,'original_preserved':True},indent=2)+'\n')
print('FULL_GEOMETRY_BASELINE_READY',str(BASE),flush=True)
