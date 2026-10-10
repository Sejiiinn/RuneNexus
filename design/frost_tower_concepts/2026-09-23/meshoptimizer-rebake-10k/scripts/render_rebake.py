"""Render exported GLB under the original frost comparison's exact conditions."""
import bpy,json,hashlib,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1];ROOT=OUT.parents[3]
reference=json.loads((OUT/'comparison-conditions.json').read_text());source=OUT/'frost-rebaked-10k.glb'
assert reference['sources']['before']['sha256']=='7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39'
sys.path.insert(0,str(Path(__file__).resolve().parent))
from comparison_studio import configure
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source));scene=bpy.context.scene;bpy.context.view_layer.update()
meshes=[o for o in scene.objects if o.type=='MESH'];points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices];bounds=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)];ref=reference['sources']['before']['bounds'];assert max(abs(bounds[i][j]-ref[i][j]) for i in range(3) for j in range(2))<2e-6
center=Vector([(a+b)*.5 for a,b in ref]);extent=max(b-a for a,b in ref);camera=configure(scene,center,extent)
report={'blender_version':bpy.app.version_string,'engine':'CYCLES','samples':48,'resolution':[1100,1100],'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'original_conditions':'design/frost_tower_concepts/2026-09-23/meshoptimizer-rebake-10k/comparison-conditions.json','bounds':bounds,'views':{}}
for view,offset in {'hero':(2.4,-3.4,2.35),'opposite':(-2.8,3.2,1.8)}.items():
    camera.location=center+Vector(offset)*extent;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();path=OUT/f'after-{view}.png';scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    report['views'][view]={'camera_location':list(camera.location),'camera_rotation':list(camera.rotation_euler),'ortho_scale':camera.data.ortho_scale,'png_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(OUT/'render-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('REBAKE_RENDER_COMPLETE',report,flush=True)
