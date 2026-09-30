"""Bounded source check: retained base/barrel, transforms and real interfaces."""
import bpy, json, hashlib
from pathlib import Path
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
BARREL=('Squared receiver throat','Silver barrel retaining band','Tapered silver barrel shroud','Long slender octagonal precision barrel','Fine dark dorsal barrel groove','Dark precision barrel collar','Receiver fastener','Square silver muzzle tip','Dark muzzle frontal cap','Twin cyan muzzle aperture','Muzzle split spine')
def signature(objects):
    deps=bpy.context.evaluated_depsgraph_get();points=[]
    for o in objects:
        if o.type=='MESH':points.extend(tuple(round(x,6) for x in (o.matrix_world@v.co)) for v in o.evaluated_get(deps).data.vertices)
    return hashlib.sha256(repr(sorted(points)).encode()).hexdigest()
def snapshot():
    bpy.context.view_layer.update();s=bpy.context.scene
    base=[o for c in s.collection.children if c.name.startswith('C01') for o in c.objects]
    barrel=[o for o in s.objects if o.name.startswith(BARREL)]
    return {'fixed_geometry':signature(base),'barrel_geometry':signature(barrel),'head':list(next(o for o in s.objects if o.name.split('.')[0]=='turret_head').location),'barrel':list(next(o for o in s.objects if o.name.split('.')[0]=='turret_barrel').location),'muzzle':list(next(o for o in s.objects if o.name.split('.')[0]=='muzzle').location)}
current=snapshot();deps=bpy.context.evaluated_depsgraph_get();objects=list(bpy.context.scene.objects)
def tree(o):
    m=o.evaluated_get(deps).data
    return BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[p.vertices[:] for p in m.polygons])
def find(prefix):return [o for o in objects if o.name.startswith(prefix)]
bridge=find('SWIFT bearing bridge')[0];drum=find('Eight sided rotation drum')[0];axle=find('SWIFT continuous trunnion axle')[0];body=find('SWIFT swept teardrop receiver shell')[0];saddle=find('SWIFT lower receiver saddle')[0]
pairs=[(bridge,drum),(axle,body),(saddle,body)]+[(a,y) for y in find('SWIFT continuous curved silver yoke') for a in [bridge,axle]]
contact=[{'a':a.name,'b':b.name,'surface_intersections':len(tree(a).overlap(tree(b)))} for a,b in pairs]
bpy.ops.wm.open_mainfile(filepath=str(OUT/'before-swift/sniper-c-editable.blend'))
before=snapshot()
result={'before':before,'swift':current,'fixed_geometry_preserved':current['fixed_geometry']==before['fixed_geometry'],'barrel_geometry_preserved':current['barrel_geometry']==before['barrel_geometry'],'contract_positions_preserved':all(current[k]==before[k] for k in ['head','barrel','muzzle']),'interfaces':contact}
(OUT/'swift-source-check.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
