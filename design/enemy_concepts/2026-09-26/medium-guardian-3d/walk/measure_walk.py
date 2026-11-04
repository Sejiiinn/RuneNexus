"""Read final rig evaluation at 1/4 frame intervals and write numeric evidence."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
s=bpy.data.scenes['Medium_Guardian_Walk']
for w in bpy.context.window_manager.windows:w.scene=s
rig=s.objects['Guardian_Walk_Rig'];boots={side:s.objects['Walk_'+side+' stone boot'] for side in ['L','R']}
records=[];worst_contact=0;min_ground=1;max_speed_error=0;max_joint_gap=0
floor=.035
for i in range(145):
    f=1+i*.25;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update()
    row={'frame':f,'feet':{}}
    for side,offset in [('L',0),('R',.5)]:
        phase=((f-1)/36+offset)%1;o=boots[side]
        points=[o.matrix_world@v.co for v in o.data.vertices];low=min(p.z for p in points)
        contact=phase<=.6
        row['feet'][side]={'phase':phase,'contact':contact,'min_z':low,'center':list(o.matrix_world.translation)}
        if contact:worst_contact=max(worst_contact,abs(low-floor))
        min_ground=min(min_ground,low-floor)
        pb=rig.pose.bones
        gap=(pb['thigh.'+side].tail-pb['shin.'+side].head).length
        gap2=(pb['shin.'+side].tail-pb['foot.'+side].head).length
        max_joint_gap=max(max_joint_gap,gap,gap2)
    records.append(row)
for a,b in zip(records[:-1],records[1:]):
    for side in boots:
        ra=a['feet'][side];rb=b['feet'][side]
        if ra['contact'] and rb['contact'] and rb['phase']>ra['phase']:
            v=(rb['center'][1]-ra['center'][1])/((b['frame']-a['frame'])/30)
            max_speed_error=max(max_speed_error,abs(v-(.42/(.6*1.2))))
def snapshot(f):
    s.frame_set(f);bpy.context.view_layer.update()
    return {o.name:o.matrix_world.copy() for o in s.objects if o.type=='MESH'}
a=snapshot(1);b=snapshot(37)
loop=max(max(abs(a[n][r][c]-b[n][r][c]) for r in range(4) for c in range(4)) for n in a)
result={'fps':30,'playback_frames':[1,36],'closure_frame':37,'seconds':1.2,'ground_top':floor,'samples':145,'sampling_step_frames':.25,'max_contact_height_error':worst_contact,'minimum_ground_clearance':min_ground,'max_support_speed_error_units_per_second':max_speed_error,'matched_root_speed_negative_Y':.42/(.6*1.2),'max_connected_leg_joint_gap':max_joint_gap,'loop_max_world_matrix_error':loop,'notes':['In-place support feet move +Y at 0.5833333 units/s; adding root -Y translation at that speed gives planted world contacts.','Subframe interpolation can introduce tiny deviations; tolerance 0.002 units.','Collision/appearance is assessed visually; numeric metrics do not assert every mesh-pair collision absence.'],'records':records}
(OUT/'walk-metrics.json').write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='records'},indent=2))
