"""Chapter 1 enemy shells: source silhouette polygons, volumetric glTF PBR geometry."""
import bpy, bmesh, math, re, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
OUT=ROOT/'assets/images/stage1_3d/enemies'
WORK=ROOT/'design/stage1_3d/enemies'
source=(ROOT/'lib/game/rendering/enemy_shape_renderer.dart').read_text()
scene=bpy.data.scenes.get('Stage1EnemyLibrary') or bpy.data.scenes.new('Stage1EnemyLibrary')
bpy.context.window.scene=scene
for obj in list(scene.objects): bpy.data.objects.remove(obj,do_unlink=True)
palettes={
'normal':['2F4355','1E3142','C7D2DF','AEB7C1','C7CED6'],
'armored':['4A4F55','30343A','F0F2F4','D0D3D6','F0D878'],
'shielded':['123A4E','0A2535','B9F4FF','4CAEC6','62D9FF'],
'fast':['123E4A','0B2C36','7DEBFF','2CB7C8','9CEBFF'],
'tank':['4A3B27','332A1F','E3C982','C0964D','A9856A'],
'boss':['4E1824','35121C','FF8791','B6394B','FF5A66']}
def linear(hex):
    v=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v)+(1,)
def material(name,color,metal=.15,rough=.79,emission=0):
    mat=bpy.data.materials.new(name);mat.diffuse_color=linear(color);mat.use_nodes=True
    p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=linear(color)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    p.inputs['Emission Color'].default_value=linear(color);p.inputs['Emission Strength'].default_value=emission
    return mat
def volume(name,points,front,back,mat,bulge=.03):
    n=len(points);cx=sum(p[0] for p in points)/n;cz=sum(.55-p[1] for p in points)/n
    vs=[(x,-front,.55-z) for x,z in points]+[(x,back,.55-z) for x,z in points]+[(cx,-front-bulge,cz),(cx,back+.03,cz)]
    fs=[]
    for i in range(n):
        j=(i+1)%n;fs += [(i,j,2*n),(n+j,n+i,2*n+1),(i,n+i,n+j,j)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    ob=bpy.data.objects.new(name,mesh);scene.collection.objects.link(ob);ob.data.materials.append(mat)
    return ob
roots={}; stats={}
for kind,colors in palettes.items():
    mats={k:material(kind+'_'+k,c,.25 if k=='armor' else .08) for k,c in zip(['body','spike','edge','armor','accent'],colors)}
    mats['core']=material(kind+'_core',colors[-1],0,.45,.75)
    mats['hot']=material(kind+'_hot','F7FBFF',0,.5,1.1)
    fn={'normal':'Normal','shielded':'Normal','fast':'FastFront','armored':'Armored','tank':'Tank','boss':'Boss'}[kind]
    code=source.split('void _draw'+fn+'(')[1].split('\nvoid ')[0]
    objs=[]
    for i,match in enumerate(re.finditer(r'_draw(Body|Shard|Plate)\(\s*canvas,\s*scale,\s*\[(.*?)\],\s*palette(?:\.(\w+))?',code,re.S)):
        shape,raw,role=match.groups();role=role or 'body'
        pts=[]
        for m in re.finditer(r'Offset\(\s*([\d.-]+),\s*([\d.-]+)\s*\)|Offset\.zero',raw):
            pts.append((float(m[1]),float(m[2])) if m[1] else (0,0))
        if shape=='Body': front,back,bulge=.22,.21,.12
        elif shape=='Shard': front,back,bulge=.12,.14,.04
        else: front,back,bulge=.365,.07,.035
        objs.append(volume(kind+'_'+shape+str(i),pts,front,back,mats[role],bulge))
    # Recessed lens setting, bright nested core, no humanoid additions.
    radius={'normal':.16,'shielded':.16,'fast':.13,'armored':.13,'tank':.15,'boss':.23}[kind]
    centerz=.55-{'armored':.2,'tank':.08}.get(kind,0)
    for label,r,dep,y,mat in [('socket',radius*1.19,.055,-.385,mats['spike']),('core',radius,.075,-.443,mats['core']),('hot',radius*.42,.022,-.52,mats['hot'])]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=(0,y,centerz));ob=bpy.context.object
        ob.name=kind+'_'+label;ob.scale=(r,dep,r);ob.data.materials.append(mat);objs.append(ob)
    # Rear dorsal plate; useful when facing away, consistent with original back renderer.
    objs.append(volume(kind+'_dorsal',[(0,-.27),(.18,-.1),(.12,.17),(0,.29),(-.12,.17),(-.18,-.1)],-.22,.25,mats['armor'],0))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs: ob.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.ops.object.join();ob=bpy.context.object;ob.name=kind
    # Exact source width normalized to 1; origin is ground, default forward is Blender -Y → glTF +Z.
    maxwidth=max(v.co.x for v in ob.data.vertices)-min(v.co.x for v in ob.data.vertices)
    for v in ob.data.vertices: v.co/=maxwidth
    root=bpy.data.objects.new(kind+'_root',None);scene.collection.objects.link(root);ob.parent=root
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True);ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False)
    stats[kind]={'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons),'bytes':(OUT/(kind+'.glb')).stat().st_size,'width':1,'sourceWidth':maxwidth}
    roots[kind]=root
# Gallery scene is editorial verification only, not gameplay.
for i,(kind,root) in enumerate(roots.items()): root.location=((i%3-1)*1.9,(i//3)*2.2,0)
mat=material('gallery_floor','263B35',0,.92)
bpy.ops.mesh.primitive_plane_add(size=200);bpy.context.object.data.materials.append(mat);bpy.context.object.location.z=-.02
world=bpy.data.worlds.new('EnemyGalleryWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.11,.14,.18,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
for name,loc,power,size,color in [('key',(-3,-4,7),950,5,(1,.93,.81)),('fill',(4,-1,5),650,4,(.67,.86,1))]:
    dat=bpy.data.lights.new(name,'AREA');dat.energy=power;dat.shape='DISK';dat.size=size;dat.color=color
    ob=bpy.data.objects.new(name,dat);scene.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,1,.3))-ob.location).to_track_quat('-Z','Y').to_euler()
camdat=bpy.data.cameras.new('EnemyGallery');cam=bpy.data.objects.new('EnemyGallery',camdat);scene.collection.objects.link(cam)
cam.location=(3,-9,7);cam.rotation_euler=(Vector((0,1,.35))-cam.location).to_track_quat('-Z','Y').to_euler();camdat.type='ORTHO';camdat.ortho_scale=7;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(WORK/'enemy-library-preview.png')
(WORK/'manifest.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'chapter-one-enemies.blend'))
print(json.dumps(stats))
