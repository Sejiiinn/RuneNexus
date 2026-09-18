import bpy,json,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from pathlib import Path
HERE=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(HERE.parent/'chapter3-thick-tiles.blend'))
dg=bpy.context.evaluated_depsgraph_get()
def tree(root):
 verts=[];faces=[]
 for ob in root.children:
  if ob.type!='MESH':continue
  me=bpy.data.meshes.new_from_object(ob.evaluated_get(dg),depsgraph=dg);base=len(verts)
  verts.extend(v.co.copy() for v in me.vertices);faces.extend(tuple(base+i for i in p.vertices) for p in me.polygons)
  bpy.data.meshes.remove(me)
 return BVHTree.FromPolygons(verts,faces)
report={}
for name in ('01_Cast_iron_plate','02_Heat_vent_grate','03_Construction_foundation','04_Plain_construction_foundation'):
 root=bpy.data.objects[name];bv=tree(root);hits=[]
 for side in range(4):
  rotation=Matrix.Rotation(side*math.pi/2,3,'Z');start=rotation@Vector((.072,-1,-.28));direction=rotation@Vector((0,1,0))
  hit=bv.ray_cast(start,direction,2)
  # Actual cut reaches at least .125 inward beyond original housing y=-.450.
  assert hit[0] is None or hit[3]>=.67,(name,side,hit)
  hits.append(None if hit[0] is None else hit[3])
 assert not any(o.name.startswith('Vent_') for o in root.children)
 report[name]={'seat_ray_distances':hits,'corner_hex_bolts':sum(o.name.startswith('Corner_') and '_hex_bolt' in o.name for o in root.children)}
 assert report[name]['corner_hex_bolts']==4
for name,expected in [('05_Panel_solid',-.452),('06_Panel_vent',-.465)]:
 bv=tree(bpy.data.objects[name]);hit=bv.ray_cast(Vector((.072,-1,-.28)),Vector((0,1,0)),2)
 assert abs(hit[0].y-expected)<.00001,(name,hit)
 frame=-.485 if name=='06_Panel_vent' else -.457
 report[name]={'front_at_aperture':hit[0].y,'frame_front':frame,'recession':hit[0].y-frame}
plain=bpy.data.objects['04_Plain_construction_foundation']
assert not any(o.name.startswith(('Bronze_mounting_ring','Cardinal_ring_clamp_','Ring_anchor_')) for o in plain.children)
(HERE/'seat-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('SEAT_VERIFICATION_PASS',json.dumps(report),flush=True)
