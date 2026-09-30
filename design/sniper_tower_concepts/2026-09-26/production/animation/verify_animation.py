import bpy,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene
def obj(name):return next(o for o in bpy.context.scene.objects if o.name.split('.')[0]==name)
def geo_signature():
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();p=[]
    for c in bpy.context.scene.collection.children:
        if c.name.startswith(('C01','C02','C03')):
            for o in c.objects:
                if o.type=='MESH':p.extend(tuple(round(x,6) for x in o.matrix_world@v.co) for v in o.evaluated_get(deps).data.vertices)
    return hashlib.sha256(repr(sorted(p)).encode()).hexdigest()
barrel=obj('turret_barrel');head=obj('turret_head');root=obj('turret_root');muzzle=obj('muzzle')
fx=next(o for o in s.objects if o.name.startswith('FX precise single-shot flash'))
fixed=[];samples=[]
for f in range(1,61):
    s.frame_set(f);bpy.context.view_layer.update()
    fixed.append(tuple(root.matrix_world)+tuple(head.matrix_world))
    samples.append({'frame':f,'barrel':list(barrel.location),'muzzle_world':list(muzzle.matrix_world.translation),'flash_scale':fx.scale[0]})
s.frame_set(1);start=geo_signature();s.frame_set(60);end=geo_signature()
assert start==end and all(t==fixed[0] for t in fixed)
assert not root.animation_data and not head.animation_data
assert max(abs(x['barrel'][0])+abs(x['barrel'][2]) for x in samples)<1e-8
assert min(x['barrel'][1] for x in samples)>=-1e-7 and max(x['barrel'][1] for x in samples)<=.048001
assert samples[0]['barrel']==samples[-1]['barrel']==[0,0,0]
assert samples[0]['flash_scale']==samples[-1]['flash_scale']==0
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'sniper-c-editable.blend'));original=geo_signature()
assert start==original
result={'static_mesh_geometry_matches_approved_source':start==original,'rest_geometry_identical_first_last':start==end,'root_and_head_fixed_all_frames':True,'recoil_range':[min(x['barrel'][1] for x in samples),max(x['barrel'][1] for x in samples)],'source_mesh_signature':original,'samples':samples}
(OUT/'animation-check.json').write_text(json.dumps(result,indent=2));print('ANIMATION_CONTRACT_PASS')
