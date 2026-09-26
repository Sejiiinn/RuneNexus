"""Reduce existing integrated-mounts-v2 props by known part topology.
No whole-model regeneration/decimation, no game asset writes.
"""
import bpy,bmesh,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent;SOURCE=OUT.parent/'foundry-props.blend'
ROOT=OUT.parents[3];ASSET=ROOT/'assets/images/stage1_3d/environment/chapter3_props.glb'
NAMES=['elbow_pipe','side_conduit','exhaust_vent']
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();result={}
    for name in NAMES:
        root=bpy.data.objects[name];parts={};pts=[];nonmanifold=[]
        for o in root.children:
            if o.type!='MESH':continue
            e=o.evaluated_get(dg);m=e.to_mesh();m.calc_loop_triangles();parts[o.name]=len(m.loop_triangles);pts.extend(o.matrix_world@v.co for v in m.vertices);e.to_mesh_clear()
            bm=bmesh.new();bm.from_mesh(o.data)
            if any(not edge.is_manifold for edge in bm.edges):nonmanifold.append(o.name)
            bm.free()
        result[name]={'triangles':sum(parts.values()),'parts':parts,'bounds':[[min(p[i] for p in pts),max(p[i] for p in pts)] for i in range(3)],'root_matrix':[list(r) for r in root.matrix_world],'nonmanifold_base_meshes':nonmanifold}
    return result
before=snapshot();changes=[]
def replace(o,vs,fs):
    old=o.data;new=bpy.data.meshes.new(old.name+' reduced');new.from_pydata(vs,[],fs);new.update()
    bm=bmesh.new();bm.from_mesh(new);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(new);bm.free()
    for mat in old.materials:new.materials.append(mat)
    smooth=old.polygons[0].use_smooth
    for p in new.polygons:p.use_smooth=smooth
    o.data=new
for name in NAMES:
    for o in bpy.data.objects[name].children:
        if o.type!='MESH':continue
        for m in list(o.modifiers):
            if m.type=='BEVEL':
                n=2 if o.name=='exhaust integrated full height rounded housing' else 1
                changes.append([o.name,'bevel_segments',m.segments,n]);m.segments=n
        # All untouched annular parts use the source helper's four 96-vertex loops.
        # Conduit body has an applied inspection-window boolean; retain its topology.
        if len(o.data.vertices)==384 and len(o.data.polygons)==384 and all(len(p.vertices)==4 for p in o.data.polygons):
            oldn=96;n=32
            vs=[tuple(o.data.vertices[g*oldn+i*3].co) for g in range(4) for i in range(n)];fs=[]
            for i in range(n):
                j=(i+1)%n;fs.extend([(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),(i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)])
            replace(o,vs,fs);changes.append([o.name,'annulus_radial',96,32])
        elif o.name=='elbow hollow upward quarter bend':
            oldn=96;count=len(o.data.vertices)//(oldn*2);assert count==39
            ids=[0]+list(range(2,35,2))+[38];n=32;nn=len(ids);vs=[]
            for wall in range(2):
                for k in ids:vs.extend(tuple(o.data.vertices[wall*count*oldn+k*oldn+i*3].co) for i in range(n))
            off=nn*n;fs=[]
            for k in range(nn-1):
                for i in range(n):
                    j=(i+1)%n;a=k*n+i;b=k*n+j;c=(k+1)*n+j;d=(k+1)*n+i;fs.extend([(a,b,c,d),(off+d,off+c,off+b,off+a)])
            for i in range(n):
                j=(i+1)%n;fs.extend([(i,off+i,off+j,j),((nn-1)*n+i,(nn-1)*n+j,off+(nn-1)*n+j,off+(nn-1)*n+i)])
            replace(o,vs,fs);changes.append([o.name,'swept_radial/path',[96,count],[n,nn]])
        elif 'washer' in o.name and len(o.data.vertices)==64:
            coords=[v.co.copy() for v in o.data.vertices];levels=sorted(set(round(v.z,8) for v in coords));assert len(levels)==2
            n=16;vs=[]
            for z in levels:
                rr=sorted([v for v in coords if abs(v.z-z)<1e-7],key=lambda p:math.atan2(p.y,p.x));vs.extend(tuple(rr[i*2]) for i in range(n))
            fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
            replace(o,vs,fs);changes.append([o.name,'washer_radial',32,16])
after=snapshot()
for name in NAMES:
    assert not after[name]['nonmanifold_base_meshes'],after[name]
    assert bpy.data.objects[name].matrix_world==Matrix.Identity(4)
    assert abs(after[name]['bounds'][1][1])<1e-7
    assert after[name]['bounds']==before[name]['bounds'],(name,before[name]['bounds'],after[name]['bounds'])
def ray(name,origin,direction,length):
    dg=bpy.context.evaluated_depsgraph_get();vs=[];fs=[]
    for o in bpy.data.objects[name].children:
        if o.type=='MESH':
            m=o.evaluated_get(dg).data;k=len(vs);vs.extend(o.matrix_world@v.co for v in m.vertices);fs.extend(tuple(k+i for i in p.vertices) for p in m.polygons)
    hit=BVHTree.FromPolygons(vs,fs).ray_cast(Vector(origin),Vector(direction),length)
    return {'start':origin,'direction':direction,'first_hit':list(hit[0]) if hit[0] else None,'distance':hit[3]}
bores={'conduit':ray('side_conduit',(-.6,-.135,-.25),(1,0,0),1.2),'exhaust':ray('exhaust_vent',(0,-.143,.5),(0,0,-1),1.2),'elbow':ray('elbow_pipe',(0,-.215,.5),(0,0,-1),1.2)}
assert bores['conduit']['first_hit'] is None
assert bores['exhaust']['distance']>.90
assert bores['elbow']['distance']>.65
report={'source':str(SOURCE),'source_sha256':sha(SOURCE),'baseline_game_asset':str(ASSET),'baseline_game_sha256':sha(ASSET),'before':before,'after':after,'changes':changes,'bore_checks':bores,'all_roots_identity':True,'wall_plane_y':0,'outward':'-Y','tile_bottom_z':-.5,'materials_unchanged':True,'whole_model_regenerated':False,'decimate_used':False,'game_files_changed':False}
(OUT/'optimization-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'foundry-props-optimized.blend'))
print('OPTIMIZED_PROPS',json.dumps({n:[before[n]['triangles'],after[n]['triangles']] for n in NAMES}))
