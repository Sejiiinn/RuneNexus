"""Saved traversal measurements; raw samples remain in ignored local/.
Run in separate background Blender with tank-walk-traversal.blend.
These geometric checks supplement, never replace, the actual motion review.
"""
import bpy,math,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
s=bpy.data.scenes['Tank_Walk_Traversal']
for w in bpy.context.window_manager.windows:
    w.scene=s
root=s.objects['Traversal_TankWalk_ROOT']
rig=s.objects['Traversal_Tank_Walk_Rig']
scale=s['production_model_to_tile_scale']
feet={side:s.objects['Traversal_TankWalk_'+side+' broad flat-soled stone foot'] for side in ['L','R']}
rows=[]
support_height=0
min_floor=1e9
joint_gap=0
neck_gap=0
head_centres=[]
torso_eulers=[]
head_eulers=[]
for i in range(729):
    f=1+i*.25
    s.frame_set(math.floor(f),subframe=f%1)
    bpy.context.view_layer.update()
    row={'frame':f,'root_world':list(root.matrix_world.translation),'feet':{}}
    for side,offset in [('L',0),('R',.5)]:
        phase=((f-1)/26+offset)%1
        foot=feet[side]
        z=min((foot.matrix_world@v.co).z for v in foot.data.vertices)*scale
        contact=phase<=.55
        if contact:
            support_height=max(support_height,abs(z))
        min_floor=min(min_floor,z)
        row['feet'][side]={'phase':phase,'contact':contact,'centre_tiles':list(foot.matrix_world.translation*scale),'min_z_tile':z}
        pb=rig.pose.bones
        a=rig.matrix_world@pb['thigh.'+side].tail
        b=rig.matrix_world@pb['ankle_link.'+side].head
        c=rig.matrix_world@pb['ankle_link.'+side].tail
        d=rig.matrix_world@pb['foot.'+side].head
        joint_gap=max(joint_gap,(a-b).length*scale,(c-d).length*scale)
    if f<=27:
        torso=rig.pose.bones['torso']
        head=rig.pose.bones['head']
        expected=torso.matrix@rig.data.bones['torso'].matrix_local.inverted()@rig.data.bones['head'].head_local
        neck_gap=max(neck_gap,(rig.matrix_world.to_3x3()@(head.head-expected)).length*scale)
        obj=s.objects['Traversal_TankWalk_large round chamfered monolithic head']
        head_centres.append(list((obj.matrix_world.translation-root.matrix_world.translation)*scale))
        torso_eulers.append([math.degrees(x) for x in (torso.matrix@rig.data.bones['torso'].matrix_local.inverted()).to_euler()])
        head_eulers.append([math.degrees(x) for x in (head.matrix@rig.data.bones['head'].matrix_local.inverted()).to_euler()])
    rows.append(row)
support_speeds=[]
for a,b in zip(rows[:-1],rows[1:]):
    for side in feet:
        aa,bb=a['feet'][side],b['feet'][side]
        if aa['contact'] and bb['contact'] and bb['phase']>aa['phase']:
            v=[(bb['centre_tiles'][i]-aa['centre_tiles'][i])/((b['frame']-a['frame'])/60) for i in range(3)]
            support_speeds.append(math.sqrt(sum(x*x for x in v)))
def ranges(seq):
    return [max(row[i] for row in seq)-min(row[i] for row in seq) for i in range(3)]
# Actual surfaces at quarter-frame phases. Expected buried overlap of separate
# natural stones is intentional; visible gaps still require image/video review.
surface=[]
for i in range(105):
    f=1+i*.25
    s.frame_set(math.floor(f),subframe=f%1)
    bpy.context.view_layer.update()
    for side in ['L','R']:
        thigh=s.objects['Traversal_TankWalk_'+side+' short massive thigh']
        for target in [s.objects['Traversal_TankWalk_single pelvis keystone including rear'],feet[side]]:
            signs=[]
            for a,b in [(thigh,target),(target,thigh)]:
                inv=b.matrix_world.inverted()
                for v in a.data.vertices:
                    p=inv@(a.matrix_world@v.co)
                    ok,q,n,index=b.closest_point_on_mesh(p)
                    if ok:
                        signs.append((p-q).dot(n))
            surface.append({'frame':f,'side':side,'target':'pelvis' if 'pelvis' in target.name else 'foot','inside_vertex_count':sum(d<-.001 for d in signs),'min_signed_local_distance':min(signs)})
metrics={'scene':s.name,'source_blend_sha256':hashlib.sha256((OUT/'tank-walk.blend').read_bytes()).hexdigest(),'traversal_blend_sha256':hashlib.sha256((OUT/'tank-walk-traversal.blend').read_bytes()).hexdigest(),'sample_count':len(rows),'frame_step':.25,'distance_tiles':(rows[0]['root_world'][1]-rows[-1]['root_world'][1])*scale,'speed_tiles_per_second':.65625,'cycle_seconds':26/60,'cycle_distance_tiles':.284375,'stance_fraction':.55,'max_world_support_foot_speed_tile_per_s':max(support_speeds),'max_contact_height_error_tiles':support_height,'minimum_floor_clearance_tiles':min_floor,'maximum_skeletal_joint_gap_tiles':joint_gap,'maximum_neck_connection_error_tiles':neck_gap,'head_relative_root_xyz_range_tiles':ranges(head_centres),'torso_euler_xyz_range_degrees':ranges(torso_eulers),'head_euler_xyz_range_degrees':ranges(head_eulers),'surface_phase_sample_count':105,'minimum_thigh_foot_inside_vertex_count':min(r['inside_vertex_count'] for r in surface if r['target']=='foot'),'minimum_thigh_pelvis_inside_vertex_count':min(r['inside_vertex_count'] for r in surface if r['target']=='pelvis'),'visual_note':'Signed overlap/joint metrics do not prove visible connection; actual representative phases and motion are separately reviewed.'}
(OUT/'walk-metrics.json').write_text(json.dumps(metrics,indent=2))
(OUT/'local'/'walk-samples.json').write_text(json.dumps({'traversal_samples':rows,'surface_contacts':surface},indent=2))
assert support_height<1e-5 and min_floor>-1e-5
assert joint_gap<1e-6 and neck_gap<1e-6
assert max(support_speeds)<.002
assert metrics['minimum_thigh_foot_inside_vertex_count']>0
assert metrics['minimum_thigh_pelvis_inside_vertex_count']>0
print(json.dumps(metrics,indent=2))
