"""Check exact controls/material graphs, bounds and real mechanical interfaces."""
import bpy,json,hashlib
from pathlib import Path
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
def snap():
    bpy.context.view_layer.update();s=bpy.context.scene;d=bpy.context.evaluated_depsgraph_get()
    obs=[o for c in s.collection.children if c.name.startswith(('C01','C02','C03')) for o in c.objects]
    points=[o.matrix_world@v.co for o in obs if o.type=='MESH' for v in o.evaluated_get(d).data.vertices]
    controls={n:{'local':list(bpy.data.objects[n].location),'world':list(bpy.data.objects[n].matrix_world.translation),'parent':bpy.data.objects[n].parent.name if bpy.data.objects[n].parent else None} for n in ['turret_root','turret_head','turret_barrel','muzzle']}
    mats={}
    for o in obs:
        if o.type!='MESH':continue
        for m in o.data.materials:
            if m.name in mats:continue
            nodes=[]
            for n in m.node_tree.nodes:
                vals=[]
                for x in n.inputs:
                    if hasattr(x,'default_value'):
                        v=x.default_value
                        if hasattr(v,'__len__'):v=list(v)
                        vals.append((x.name,v))
                nodes.append((n.name,n.type,vals))
            links=[(l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name) for l in m.node_tree.links]
            mats[m.name]=hashlib.sha256(repr((nodes,links)).encode()).hexdigest()
    return {'bounds':[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]],'controls':controls,'materials':mats}
def contacts(kick):
    bpy.data.objects['turret_barrel'].location.y=kick;bpy.context.view_layer.update();d=bpy.context.evaluated_depsgraph_get()
    def tree(o):
        m=o.evaluated_get(d).data;return BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[p.vertices[:] for p in m.polygons])
    obs=list(bpy.context.scene.objects)
    find=lambda p:next(o for o in obs if o.name.startswith(p))
    bridge,drum,axle,body,saddle=[find(p) for p in ['SWIFT bearing bridge','Eight sided rotation drum','SWIFT continuous trunnion axle','SWIFT swept teardrop receiver shell','SWIFT lower receiver saddle']]
    pairs=[(bridge,drum),(axle,body),(saddle,body)]+[(a,y) for y in obs if y.name.startswith('SWIFT continuous curved silver yoke') for a in [bridge,axle]]
    return [{'a':a.name,'b':b.name,'surface_intersections':len(tree(a).overlap(tree(b)))} for a,b in pairs]
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'sniper-c-editable.blend'));source=snap();original_rest=contacts(0);original_recoil=contacts(.048)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'sniper-swift-optimized.blend'));optimized=snap()
result={'source':source,'optimized':optimized,'controls_equal':source['controls']==optimized['controls'],'materials_equal':source['materials']==optimized['materials'],'bounds_max_abs_change':max(abs(source['bounds'][j][i]-optimized['bounds'][j][i]) for j in range(2) for i in range(3)),'original_rest_contacts':original_rest,'original_recoil_contacts':original_recoil,'rest_contacts':contacts(0),'recoil_048_contacts':contacts(.048)}
bpy.data.objects['turret_barrel'].location.y=0;bpy.context.view_layer.update()
(OUT/'source-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
assert result['controls_equal'] and result['materials_equal']
assert all(p['surface_intersections']>0 for p in result['rest_contacts']+result['recoil_048_contacts'] if 'lower receiver saddle' not in p['a'])
assert all(bool(a['surface_intersections'])==bool(b['surface_intersections']) for a,b in zip(original_rest+original_recoil,result['rest_contacts']+result['recoil_048_contacts']))
