"""Check actual hollow muzzle axis and GLB surface-position roundtrip."""
import bpy,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
OUT=Path(__file__).resolve().parent
def body_objects():
    return [o for o in bpy.context.scene.objects if o.type=='MESH' and (o.name.startswith('turret_') or any(c.name.startswith(('01 ','02 ','03 ')) for c in o.users_collection))]
def surface(objects):
    bpy.context.view_layer.update();d=bpy.context.evaluated_depsgraph_get();vs=[];fs=[]
    for o in objects:
        m=o.evaluated_get(d).data;k=len(vs);vs.extend(o.matrix_world@v.co for v in m.vertices);fs.extend(tuple(k+i for i in p.vertices) for p in m.polygons)
    return vs,fs
def mouth():
    vs,fs=surface(body_objects());b=BVHTree.FromPolygons(vs,fs)
    m=bpy.data.objects['muzzle'].matrix_world;outward=(m.to_3x3()@Vector((0,-1,0))).normalized();start=m.translation+outward*.02
    hit=b.ray_cast(start,-outward,.4)
    return {'start':list(start),'inward_direction':list(-outward),'first_surface':list(hit[0]),'free_depth_tiles':hit[3]}
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'scale-90/runic-native-90.blend'));baseline_mouth=mouth()
bpy.ops.wm.open_mainfile(filepath=str(OUT/'runic-fire-optimized.blend'));optimized_mouth=mouth()
print('MUZZLE_COMPARISON',baseline_mouth,optimized_mouth,flush=True)
assert optimized_mouth['free_depth_tiles']>.04
assert abs(baseline_mouth['free_depth_tiles']-optimized_mouth['free_depth_tiles'])<1e-5
bpy.ops.wm.open_mainfile(filepath=str(OUT/'runic-fire-optimized-baked.blend'))
vs,fs=surface(body_objects());source=[vs[i] for i in set(i for f in fs for i in f)]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'runic-fire-optimized.glb'))
vs,fs=surface([o for o in bpy.context.scene.objects if o.type=='MESH']);target=[vs[i] for i in set(i for f in fs for i in f)]
def error(a,b):
    tree=KDTree(len(b))
    for i,v in enumerate(b):tree.insert(v,i)
    tree.balance();return max(tree.find(v)[2] for v in a)
maximum=max(error(source,target),error(target,source));assert maximum<1e-6,maximum
result={'baseline_muzzle':baseline_mouth,'optimized_muzzle':optimized_mouth,'muzzle_depth_difference':abs(baseline_mouth['free_depth_tiles']-optimized_mouth['free_depth_tiles']),'roundtrip_surface_max_error':maximum,'glb_nodes':[{ 'name':o.name,'parent':o.parent.name if o.parent else None,'world_position':list(o.matrix_world.translation),'scale':list(o.scale)} for o in bpy.context.scene.objects if o.type=='EMPTY']}
(OUT/'export-check.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
