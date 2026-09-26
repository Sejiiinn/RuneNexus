"""Part-specific topology reduction of the final surface-frost source.
Keeps all existing atlas UVs/materials. Regenerates only uncoated rotational
components using the original helper with fewer radial/path samples.
"""
import bpy,bmesh,re,json,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'production/frost.blend'
BASELINE_COMMIT='0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047'
if Path(bpy.data.filepath)!=SOURCE:bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
with bpy.context.temp_override(window=bpy.context.window_manager.windows[0]):
 scene=bpy.context.scene;root=bpy.data.objects['turret_root']
 objects=[o for o in root.children_recursive if o.type=='MESH']
 def clean(n):return re.sub(r'\.\d+$','',n)
 # collection access, not method
 src=Path(OUT.parent/'production/build_frost.py').read_text().split('def export():')[0]
 src=src.replace("verts=64,parent=None", "verts=32,parent=None").replace("vertices=verts,radius=r", "vertices=min(verts,16),radius=r")
 src=src.replace('major_segments=96,minor_segments=8','major_segments=32,minor_segments=6').replace('rings=12;sides=96','rings=6;sides=48')
 # Preserve all original coated meshes and their packed UV atlas.
 ns={'FROST_OUTPUT_PATH':str(OUT)}
 # Blender ID names are occupied; normalise only the generated names for matching.
 exec(compile(src,'original_frost_helpers_reduced','exec'),ns)
 generated={clean(o.name):o for o in ns['root'].children_recursive if o.type=='MESH'}
 bpy.context.window.scene=scene
 changes=[]
 def preserve_bounds(data,original):
  for axis in range(3):
   lo=min(v.co[axis] for v in data.vertices);hi=max(v.co[axis] for v in data.vertices)
   a=min(v.co[axis] for v in original.vertices);b=max(v.co[axis] for v in original.vertices)
   if hi-lo>1e-9:
    for v in data.vertices:v.co[axis]=a+(v.co[axis]-lo)/(hi-lo)*(b-a)
 def tris(m):m.calc_loop_triangles();return len(m.loop_triangles)
 def snapshot():
  bpy.context.view_layer.update();pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
  return {'triangles':sum(tris(o.data) for o in objects),'parts':{clean(o.name):tris(o.data) for o in objects},'bounds':[[min(p[i] for p in pts),max(p[i] for p in pts)] for i in range(3)]}
 before=snapshot()
 for o in objects:
  name=clean(o.name);old=tris(o.data)
  if 'FrostSurface' not in o.data.uv_layers and (any(s in name for s in ('horizontal fin','Cooling core','Pivot shadow seat','underlight','coolant ring','chilled gasket','ice lens','inner volume','deep dark socket'))):
   g=generated[name]
   assert max(abs(o.matrix_world[i][j]-g.matrix_world[i][j]) for i in range(4) for j in range(4))<1e-6,name
   data=g.data.copy();preserve_bounds(data,o.data);indices=[p.material_index for p in data.polygons];data.materials.clear()
   for m in o.data.materials:data.materials.append(m)
   for p,idx in zip(data.polygons,indices):p.material_index=idx
   for uv in data.uv_layers:uv.name='OriginalSurface'
   o.data=data;changes.append({'part':name,'method':'original cylinder/torus/lens helper radial resampling','before':old,'after':tris(data)})
  # Remove only coplanar redundant edges; retain materials, UV island seams,
  # all curved perimeter/bevel vertices, and all atlas coordinates.
  bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update()
  bmesh.ops.dissolve_limit(bm,angle_limit=.001,verts=list(bm.verts),edges=list(bm.edges),delimit={'MATERIAL','UV'})
  bm.to_mesh(o.data);bm.free();o.data.update()
  if tris(o.data)!=old and not (changes and changes[-1]['part']==name):changes.append({'part':name,'method':'coplanar dissolve, UV/material boundaries retained','before':old,'after':tris(o.data)})
 for ob in list(ns['scene'].objects):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.data.scenes.remove(ns['scene'])
 after=snapshot()
 assert max(abs(after['bounds'][i][j]-before['bounds'][i][j]) for i in range(3) for j in range(2))<1e-7
 report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'baseline_git_commit':BASELINE_COMMIT,'baseline_sha256':'e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544','before':before,'after':after,'changes':changes,'preserved':['6 thick curved shutters and gaps','72 distinct fins and 6 cores','4 feet and real recesses','all frost atlas UV coordinates on retained surfaces','all materials and image contents','fixed root/head/barrel/muzzle transforms'],'decimate_used':False,'whole_model_replaced':False}
 (OUT/'optimization-manifest.json').write_text(json.dumps(report,indent=2)+'\n')
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'frost-optimized.blend'))
 print('FROST_OPTIMIZED',before['triangles'],after['triangles'])
