"""Part-specific topology reduction of the approved SWIFT source; no decimation.
Run in Blender. Writes only this directory. Material graphs and contract unchanged.
"""
import bpy, math, json, hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'sniper-c-editable.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene
scene.name='SWIFT — Game distance optimized'
objects=[o for c in scene.collection.children if c.name.startswith(('C01','C02','C03')) for o in c.objects]
def tris(o):
    d=bpy.context.evaluated_depsgraph_get();e=o.evaluated_get(d);m=e.to_mesh();m.calc_loop_triangles();n=len(m.loop_triangles);e.to_mesh_clear();return n
before={o.name:tris(o) for o in objects if o.type=='MESH'}
changes=[]
def replace(o,vs,fs,attrs=None):
    old=o.data; new=bpy.data.meshes.new(old.name+' reduced')
    new.from_pydata(vs,[],fs);new.update()
    for m in old.materials:new.materials.append(m)
    if attrs:
        for p,(mi,smooth) in zip(new.polygons,attrs):p.material_index=mi;p.use_smooth=smooth
    o.data=new
ring_names=['SWIFT sight silver recessed bezel','SWIFT sight dark inner well','SWIFT lens retaining line','Narrow bronze bearing seam']
cylinder_names=['Turntable bearing shadow','SWIFT trunnion dark bearing','SWIFT continuous trunnion axle','SWIFT inset cyan aiming lens','SWIFT bronze pivot boss','SWIFT recessed pivot hub']
for o in objects:
    if o.type!='MESH':continue
    name=o.name
    for m in list(o.modifiers):
        if m.type=='BEVEL':
            if any(s in name.lower() for s in ['fastener','fastening','rivet']):o.modifiers.remove(m)
            else:m.segments=1
    if any(name.startswith(n) for n in ring_names):
        oldn=len(o.data.vertices)//4;n=16;stride=oldn//n
        vs=[tuple(o.data.vertices[g*oldn+i*stride].co) for g in range(4) for i in range(n)]
        fs=[]
        for i in range(n):
            j=(i+1)%n;fs.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(n+i,n+j,3*n+j,3*n+i),(j,i,2*n+i,2*n+j)])
        replace(o,vs,fs);changes.append([name,'ring',oldn,n])
    elif any(name.startswith(n) for n in cylinder_names):
        vs0=[v.co.copy() for v in o.data.vertices];oldn=len(vs0)//2;n=16 if oldn in [32,48] else 12
        levels=sorted(set(round(v.z,7) for v in vs0));rings=[]
        for z in levels:
            r=sorted([v for v in vs0 if abs(v.z-z)<1e-6],key=lambda v:math.atan2(v.y,v.x))
            rings.extend(tuple(r[i*(oldn//n)]) for i in range(n))
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        replace(o,rings,fs,[(0,False),(0,False)]+[(0,True)]*n);changes.append([name,'cylinder',oldn,n])
    elif name.startswith('SWIFT continuous curved silver yoke'):
        oldn=len(o.data.vertices)//2;ids=sorted(set(range(0,oldn,2))|{0,40,41,oldn-1});n=len(ids)
        vs=[tuple(o.data.vertices[k*oldn+i].co) for k in range(2) for i in ids]
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        replace(o,vs,fs,[(0,False),(0,False)]+[(0,True)]*n);changes.append([name,'profile samples',oldn,n])
    elif name=='SWIFT swept teardrop receiver shell':
        oldn=len(o.data.vertices)//10;ids=list(range(0,oldn,2));n=len(ids)
        vs=[tuple(o.data.vertices[i*10+j].co) for i in ids for j in range(10)]
        fs=[tuple(reversed(range(10))),tuple(range((n-1)*10,n*10))];attrs=[(0,False),(0,False)]
        for k in range(n-1):
            for j in range(10):
                fs.append((k*10+j,k*10+(j+1)%10,(k+1)*10+(j+1)%10,(k+1)*10+j))
                p=o.data.polygons[2+ids[k]*10+j];attrs.append((p.material_index,p.use_smooth))
        replace(o,vs,fs,attrs);changes.append([name,'longitudinal sections',oldn,n])
bpy.context.view_layer.update()
after={o.name:tris(o) for o in objects if o.type=='MESH'}
controls={n:bpy.data.objects[n] for n in ['turret_root','turret_head','turret_barrel','muzzle']}
assert controls['turret_head'].parent==controls['turret_root']
assert controls['turret_barrel'].parent==controls['turret_head']
assert controls['muzzle'].parent==controls['turret_barrel']
assert controls['turret_barrel'].location.length<1e-8
manifest={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'original_triangles':sum(before.values()),'optimized_triangles':sum(after.values()),'part_triangles_before':before,'part_triangles_after':after,'topology_changes':changes,'bevel_policy':'Remove only tiny fastening bevels; retain bevel widths with one segment on other parts. Weighted normals retained. No decimate modifier.','materials':'All source material graphs preserved.','head_origin':list(controls['turret_head'].location),'muzzle_world':list(controls['muzzle'].matrix_world.translation),'barrel_rest':list(controls['turret_barrel'].location),'game_integration':False}
(OUT/'optimization-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sniper-swift-optimized.blend'))
print('OPTIMIZED',manifest['original_triangles'],manifest['optimized_triangles'])
