"""Read-only source checks; writes geometry-checks.json beside the source."""
import bpy,json
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(P/'chapter3-thick-tiles.blend'))
roots=[bpy.data.objects[n] for n in ('01_Cast_iron_plate','02_Heat_vent_grate','03_Construction_foundation')]
results={}
for r in roots:
    children=list(r.children)
    points=[r.matrix_world.inverted() @ o.matrix_world @ Vector(p) for o in children for p in o.bound_box]
    spans=[round(max(v[i] for v in points)-min(v[i] for v in points),6) for i in range(3)]
    bolts=[o for o in children if '_hex_bolt' in o.name]
    reinforcement=[o for o in children if '_reinforcement_' in o.name]
    assert spans[:2]==[1.,1.] and len(bolts)==4 and len(reinforcement)==8
    assert abs(min(v.z for v in points)+.50)<1e-6
    results[r.name]={'dimensions':spans,'corner_bolts':len(bolts),'side_reinforcements':len(reinforcement),'mesh_count':len(children)}
treads=[o for o in roots[0].children if o.name.startswith('Raised_tread_')];assert len(treads)==5
clamps=[o for o in roots[2].children if o.name.startswith('Cardinal_ring_clamp_')];assert len(clamps)==4
plate=next(o for o in roots[1].children if o.name.startswith('Top_flange_plate'))
open_holes=0
for row in range(5):
    for col in range(5):
        hit=plate.ray_cast(Vector(((col-2)*.128,(row-2)*.128,.1)),Vector((0,0,-1)))[0]
        assert not hit
        open_holes+=1
assert plate.ray_cast(Vector((0,.064,.1)),Vector((0,0,-1)))[0]
results['checks']={'tread_count':len(treads),'round_ring_anchors':len(clamps),'ray_verified_through_holes':open_holes,'solid_grid_crossbar':True,'body_bottom_z':-.50,'common_plate_surface_z':0,'external_images':[im.filepath for im in bpy.data.images if im.source=='FILE' and not im.packed_file],'pass':True}
assert not results['checks']['external_images']
(P/'geometry-checks.json').write_text(json.dumps(results,indent=2)+'\n')
print('GEOMETRY_CHECKS_PASS')
