"""Author low geometry/normals, transfer original PBR, save/export/reopen.

Run background Blender. Original GLB/source scenes are never overwritten.
"""
import bpy,numpy as np,json,hashlib,math,sys,os
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parents[1];ROOT=OUT.parents[3]
(OUT/'checks').mkdir(exist_ok=True);(OUT/'textures').mkdir(exist_ok=True)
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from source_input import materialize_original
source=materialize_original()
geometry=json.loads((OUT/'geometry-manifest.json').read_text())
assert hashlib.sha256(source.read_bytes()).hexdigest()==geometry['source_sha256']=='7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39'
TEXTURED={0,1,4,5,8,12};SIZE=2048
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source));scene=bpy.context.scene
names=['Frost fixed body solid','Frost fixed iris skin','Frost fixed iris solid'];high=[bpy.data.objects[n] for n in names]
source_mats=[]
for mi,obj in enumerate(high):
    for m in obj.data.materials:
        if m not in source_mats:source_mats.append(m)
# Import materials map by original GLB table names, not Blender slot order.
import struct
raw=source.read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length])
source_mats=[bpy.data.materials[m['name']] for m in doc['materials']]
low_mats=[]
for m in source_mats:
    name=m.name;m.name='Source '+name;cp=m.copy();cp.name=name;low_mats.append(cp)
    p=next(n for n in cp.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    if low_mats.index(cp) in TEXTURED:
        for name in ('Base Color','Metallic','Roughness','Normal','Emission Color'):
            for link in list(p.inputs[name].links):cp.node_tree.links.remove(link)

def convert(v):return np.column_stack((v[:,0],-v[:,2],v[:,1]))
low=[];ownership=[];authored_normals=[];authored_materials=[]
for mi,obj in enumerate(high):
    obj.name='Source '+names[mi];data=np.load(OUT/'checks'/f'mesh{mi}-geometry.npz');pos=data['positions'];f=data['low_faces'];lg=data['low_groups'];hp=data['high_positions'];hf=data['high_faces'];hm=data['high_materials'];hg=data['high_groups'];uv=np.load(OUT/'checks'/f'mesh{mi}-uv.npz')['loop_uv']
    bvhs={}
    for ci in np.unique(hg):
        ids=np.flatnonzero(hg==ci);bvhs[int(ci)]=(BVHTree.FromPolygons([Vector(p) for p in hp],hf[ids].tolist(),all_triangles=True),ids)
    q=pos[f];fn=np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]);fn/=np.maximum(np.linalg.norm(fn,axis=1)[:,None],1e-20)
    materials=[]
    for ti,tri in enumerate(f):
        ci=int(lg[ti]);part=geometry['records'][mi]['parts'][ci]
        if part['fin']:material=2 if abs(fn[ti,1])>.85 else 3
        elif len(part['materials'])==1:material=part['materials'][0]
        else:
            bvh,ids=bvhs[ci];hit=bvh.find_nearest(Vector(pos[tri].mean(0)));assert hit[2] is not None;material=int(hm[ids[hit[2]]])
        materials.append(material)
    mesh=bpy.data.meshes.new(names[mi]+' rebaked mesh');mesh.from_pydata(convert(pos),[],f.tolist());mesh.update()
    ob=bpy.data.objects.new(names[mi],mesh);scene.collection.objects.link(ob);ob.parent=obj.parent;ob.matrix_world=obj.matrix_world.copy()
    for m in low_mats:mesh.materials.append(m)
    for polygon,material in zip(mesh.polygons,materials):polygon.material_index=material;polygon.use_smooth=True
    layer=mesh.uv_layers.new(name='RebakeUV');layer.data.foreach_set('uv',uv.ravel());layer.active_render=True
    # Geometry normals are independent of the bake. Dynamic charge surfaces use
    # these vertex normals because the runtime shader ignores texture normals.
    normals=np.zeros((len(pos),3),np.float32);counts=np.zeros(len(pos),np.int32);normal_candidates={i:[] for i in range(len(pos))}
    inv={tuple(v):i for i,v in enumerate(pos)}
    for p,n in zip(hp,data['high_normals']):
        vi=inv[tuple(p)];normals[vi]+=n;counts[vi]+=1;normal_candidates[vi].append(n)
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-20)
    loopnorm=[]
    for ti,tri in enumerate(f):
        part=geometry['records'][mi]['parts'][int(lg[ti])]
        if part['fin']:
            localids=np.unique(f[lg==int(lg[ti])]);center=(pos[localids].min(0)+pos[localids].max(0))*.5
        for vi in tri:
            if part['fin']:
                if materials[ti]==2:n=np.array([0.,math.copysign(1.,fn[ti,1]),0.])
                else:
                    radial=pos[vi]-center;radial[1]=0.;radial/=max(np.linalg.norm(radial),1e-20);ny=float(fn[ti,1]);n=radial*math.sqrt(max(0.,1.-ny*ny));n[1]=ny
            else:
                choices=np.array(normal_candidates[vi]);n=choices[np.argmax(choices@fn[ti])]
                if np.dot(n,fn[ti])<=0:n=fn[ti]
            loopnorm.append((float(n[0]),float(-n[2]),float(n[1])))
    mesh.normals_split_custom_set(loopnorm)
    authored_normals.append(np.array(loopnorm,np.float32).reshape(-1,3,3))
    authored_materials.append(np.array(materials,np.int32))
    np.savez_compressed(OUT/'checks'/f'mesh{mi}-assignment.npz',material_index=authored_materials[-1])
    low.append(ob);ownership.append({'mesh':mi,'triangles':len(f),'materials':{source_mats[i].name.removeprefix('Source '):materials.count(i) for i in sorted(set(materials))},'fin_parts':sum(p['fin'] for p in geometry['records'][mi]['parts'])})
    obj.hide_render=True
print('LOW_GEOMETRY_OWNERSHIP',ownership,flush=True)
# Per-component selected-to-active projection prevents nearby separate parts
# (fins, frost strips, lens rims) from being hit instead of the authored source.
bake_pairs=[];bake_ids=[]
for mi in (0,2):
    data=np.load(OUT/'checks'/f'mesh{mi}-geometry.npz');uv=np.load(OUT/'checks'/f'mesh{mi}-uv.npz')['loop_uv'].reshape(-1,3,2)
    for ci,part in enumerate(geometry['records'][mi]['parts']):
        if not set(part['materials'])&TEXTURED:continue
        pair=[]
        for label,positions,faces,mask,mats,normals,uvs,materials in [
            ('Source component bake',data['high_positions'],data['high_faces'],data['high_groups']==ci,source_mats,convert(data['high_normals'])[data['high_faces']],np.column_stack((data['high_uv'][:,0],1.-data['high_uv'][:,1]))[data['high_faces']],data['high_materials']),
            ('Target component bake',data['positions'],data['low_faces'],data['low_groups']==ci,low_mats,authored_normals[mi],uv,authored_materials[mi])]:
            selected=faces[mask];used,inv=np.unique(selected,return_inverse=True)
            mesh=bpy.data.meshes.new(label);mesh.from_pydata(convert(positions[used]),[],inv.reshape(-1,3).tolist());mesh.update()
            for mat in mats:mesh.materials.append(mat)
            for polygon,material in zip(mesh.polygons,materials[mask]):polygon.material_index=int(material);polygon.use_smooth=True
            layer=mesh.uv_layers.new(name='UVMap' if label.startswith('Source ') else 'RebakeUV');layer.data.foreach_set('uv',uvs[mask].ravel());layer.active_render=True
            mesh.normals_split_custom_set(normals[mask].reshape(-1,3).tolist())
            ob=bpy.data.objects.new(label,mesh);scene.collection.objects.link(ob);ob.matrix_world=low[mi].matrix_world.copy();ob.hide_render=True;pair.append(ob)
        bake_pairs.append(pair);bake_ids.append((mi,ci))
print('ISOLATED_BAKE_PAIRS',len(bake_pairs),flush=True)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1
scene.render.bake.use_selected_to_active=True;scene.render.bake.use_cage=False;scene.render.bake.cage_extrusion=.02;scene.render.bake.max_ray_distance=.06;scene.render.bake.margin=8
scene.render.bake.normal_space='TANGENT';scene.render.bake.normal_r='POS_X';scene.render.bake.normal_g='POS_Y';scene.render.bake.normal_b='POS_Z'
tmp=bpy.data.images.new('Constant material unused bake',width=32,height=32,alpha=False)
targets={}
def image(name,color):
    resolution=1024 if name=='emission' else SIZE;i=bpy.data.images.new('Frost rebake '+name,width=resolution,height=resolution,alpha=False);i.colorspace_settings.name='sRGB' if color else 'Non-Color';return i
for channel in ('normal','basecolor','roughness','metallic','emission'):targets[channel]=image(channel,channel in ('basecolor','emission'))
def set_targets(img):
    for i,m in enumerate(low_mats):
        nodes=m.node_tree.nodes;tex=nodes.get('REBAKE_DESTINATION') or nodes.new('ShaderNodeTexImage');tex.name='REBAKE_DESTINATION';tex.image=img if i in TEXTURED else tmp
        for n in nodes:n.select=False
        tex.select=True;nodes.active=tex
def bake(channel,kind):
    img=targets[channel];set_targets(img)
    records=[];previous=None
    for index,pair in enumerate(bake_pairs):
        bpy.ops.object.select_all(action='DESELECT')
        for ob in pair:ob.hide_render=False;ob.select_set(True)
        bpy.context.view_layer.objects.active=pair[1];scene.render.bake.use_clear=index==0
        bpy.ops.object.bake(type=kind,use_clear=index==0,use_selected_to_active=True,cage_extrusion=.02,max_ray_distance=.06,margin=8)
        for ob in pair:ob.hide_render=True
        if index%25==0:print('BAKE_COMPONENT_PROGRESS',channel,index,len(bake_pairs),flush=True)
        if os.environ.get('FROST_BAKE_PILOT'):
            pixels=np.empty(len(img.pixels),np.float32);img.pixels.foreach_get(pixels);rgb=pixels.reshape(-1,4)[:,:3];record={'component':bake_ids[index],'positive_pixels':int((rgb.max(-1)>.001).sum())}
            if previous is not None:record['previous_positive_preserved']=float(np.mean(np.any(rgb[previous]>0.001,axis=-1)))
            previous=rgb.max(-1)>.001;records.append(record);print('PILOT',channel,record,flush=True)
    directory=OUT/'checks' if os.environ.get('FROST_BAKE_PILOT') else (OUT/'checks/intermediate' if channel in ('roughness','metallic') else OUT/'textures')
    directory.mkdir(exist_ok=True)
    img.filepath_raw=str(directory/f'frost-{channel}.png');img.file_format='PNG';img.save();img.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'checks/bake-progress.blend'),compress=True)
if os.environ.get('FROST_BAKE_PILOT'):
    selected=[i for i,key in enumerate(bake_ids) if key in ((0,177),(2,288),(2,0),(2,297))];bake_pairs=[bake_pairs[i] for i in selected];bake_ids=[bake_ids[i] for i in selected]
bake('normal','NORMAL')
outputs=[]
for m in source_mats:
    nodes=m.node_tree.nodes;output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');bsdf=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');original=output.inputs['Surface'].links[0].from_socket
    emit=nodes.new('ShaderNodeEmission');m.node_tree.links.new(emit.outputs[0],output.inputs['Surface']);outputs.append((m,bsdf,emit,output,original))
passes=[('basecolor','Base Color')] if os.environ.get('FROST_BAKE_PILOT') else [('basecolor','Base Color'),('roughness','Roughness'),('metallic','Metallic'),('emission','Emission Color')]
for channel,socket in passes:
    for m,bsdf,emit,output,original in outputs:
        for link in list(emit.inputs['Color'].links):m.node_tree.links.remove(link)
        inp=bsdf.inputs[socket]
        if channel=='emission' and float(bsdf.inputs['Emission Strength'].default_value)==0:
            emit.inputs['Color'].default_value=(0,0,0,1)
        elif inp.is_linked:m.node_tree.links.new(inp.links[0].from_socket,emit.inputs['Color'])
        else:
            value=inp.default_value
            emit.inputs['Color'].default_value=tuple(value) if hasattr(value,'__len__') else (value,value,value,1.)
        emit.inputs['Strength'].default_value=1.
    bake(channel,'EMIT')
for m,bsdf,emit,output,original in outputs:m.node_tree.links.new(original,output.inputs['Surface']);m.node_tree.nodes.remove(emit)
if os.environ.get('FROST_BAKE_PILOT'):
    print('PILOT_COMPLETE',flush=True);bpy.ops.wm.quit_blender()
else:
    # Pack ORM: occlusion1, source roughness G, source metallic B.
    rp=np.empty(SIZE*SIZE*4,np.float32);mp=np.empty_like(rp);targets['roughness'].pixels.foreach_get(rp);targets['metallic'].pixels.foreach_get(mp);rp=rp.reshape(-1,4);mp=mp.reshape(-1,4);pixels=np.ones_like(rp);pixels[:,1]=rp[:,0];pixels[:,2]=mp[:,0]
    orm=image('orm',False);orm.pixels.foreach_set(pixels.ravel());orm.filepath_raw=str(OUT/'textures/frost-orm.png');orm.file_format='PNG';orm.save();orm.pack()
    for i,m in enumerate(low_mats):
        if i not in TEXTURED:continue
        n=m.node_tree.nodes;l=m.node_tree.links;p=next(x for x in n if x.type=='BSDF_PRINCIPLED')
        for name in ('Base Color','Metallic','Roughness','Normal','Emission Color'):
            for link in list(p.inputs[name].links):l.remove(link)
        channels=[('basecolor','Base Color')]
        if any(doc['materials'][i].get('emissiveFactor',[0,0,0])):channels.append(('emission','Emission Color'))
        else:p.inputs['Emission Color'].default_value=(0,0,0,1);p.inputs['Emission Strength'].default_value=0
        for channel,socket in channels:
            t=n.new('ShaderNodeTexImage');t.image=targets[channel];l.new(t.outputs['Color'],p.inputs[socket])
        t=n.new('ShaderNodeTexImage');t.image=targets['normal'];normal=n.new('ShaderNodeNormalMap');normal.uv_map='RebakeUV';normal.inputs['Strength'].default_value=1.;l.new(t.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs['Normal'])
        t=n.new('ShaderNodeTexImage');t.image=orm;split=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],split.inputs['Color']);l.new(split.outputs['Green'],p.inputs['Roughness']);l.new(split.outputs['Blue'],p.inputs['Metallic'])
        p.inputs['Base Color'].default_value=(1,1,1,1);p.inputs['Metallic'].default_value=1.;p.inputs['Roughness'].default_value=1.
    scene.render.bake.use_selected_to_active=False
    for pair in bake_pairs:
        for ob in pair:
            mesh=ob.data;bpy.data.objects.remove(ob,do_unlink=True);bpy.data.meshes.remove(mesh)
    for ob in high:ob.hide_render=True;ob.hide_set(True)
    for ob in low:ob.hide_render=False
    bpy.ops.object.select_all(action='DESELECT')
    for ob in low:ob.select_set(True)
    for name in ('turret_root','turret_head','turret_barrel','muzzle'):bpy.data.objects[name].select_set(True)
    bpy.context.view_layer.objects.active=low[0]
    bpy.ops.file.pack_all();blend=OUT/'frost-rebaked-10k.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    glb=OUT/'frost-rebaked-10k.glb';bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_normals=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    map_names=[targets['basecolor'].name,targets['normal'].name,orm.name,targets['emission'].name];constant_names=[low_mats[i].name for i in range(13) if i not in TEXTURED]
    bpy.ops.wm.open_mainfile(filepath=str(blend));got=[bpy.data.objects[n] for n in names];assert sum(len(o.data.polygons) for o in got)==11760
    report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'triangles':11760,'maps':map_names,'atlas_size':SIZE,'normal_space':'TANGENT OpenGL +X/+Y/+Z','source_projection':'125 isolated original components; GLB source UV v converted to Blender 1-v','cage_extrusion':.02,'max_ray_distance':.06,'geometry_normals':'source corner with maximum face-direction agreement; fin cap flat and side radial','constant_materials_unchanged':constant_names,'ownership':ownership,'packed_images':[i.name for i in bpy.data.images if i.type=='IMAGE' and i.packed_file],'dirty':bpy.data.is_dirty,'visual_status':'PENDING'}
    (OUT/'bake-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('FROST_REBAKE_PACKED_REOPEN',report,flush=True)
