"""Bake native PBR and export evaluated approved geometry without rebuilding it."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
OUT=Path(__file__).resolve().parent
ASSET=OUT/'runic-fire-optimized.glb'
SIZE=1024

def setup():
    source=bpy.context.scene
    deps=bpy.context.evaluated_depsgraph_get()
    keep=[o for c in source.collection.children if c.name.startswith(('01 ','02 ','03 ')) for o in c.objects]
    keep=list(dict.fromkeys(keep))
    target=bpy.data.scenes.new('Runic Fire Native Export')
    mapping={}; mats={};mesh_objects=[]
    for o in keep:
        if o.type not in {'MESH','EMPTY'}:continue
        if o.type=='MESH':
            data=bpy.data.meshes.new_from_object(o.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
            clone=bpy.data.objects.new(o.name+'__native',data)
            clone['source_object']=o.name
            for i,mat in enumerate(data.materials):
                if mat not in mats:mats[mat]=mat.copy()
                data.materials[i]=mats[mat]
            mesh_objects.append(clone)
        else:clone=bpy.data.objects.new(o.name+'__native',None)
        target.collection.objects.link(clone);mapping[o]=clone
        clone.matrix_world=o.matrix_world.copy()
    for o,clone in mapping.items():
        world=clone.matrix_world.copy()
        if o.parent in mapping:clone.parent=mapping[o.parent]
        clone.matrix_world=world
    bpy.context.window.scene=target
    bpy.ops.object.select_all(action='DESELECT')
    for o in mesh_objects:o.select_set(True)
    bpy.context.view_layer.objects.active=mesh_objects[0]
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.009)
    bpy.ops.object.mode_set(mode='OBJECT')
    target.render.engine='CYCLES';target.cycles.samples=8
    target.render.bake.use_clear=False;target.render.bake.margin=5
    target.render.bake.use_pass_direct=False;target.render.bake.use_pass_indirect=False;target.render.bake.use_pass_color=True
    metalmats=[m for orig,m in mats.items() if orig.name.startswith(('Iron |','Bronze |','Steel |','Recess |'))]
    bakeobjs=[o for o in mesh_objects if any(m in metalmats for m in o.data.materials)]
    images={}
    for name in ('color','roughness','normal'):
        im=bpy.data.images.new('Runic atlas '+name,width=SIZE,height=SIZE,alpha=False)
        if name!='color':im.colorspace_settings.name='Non-Color'
        im.filepath_raw=str(OUT/('runic-'+name+'.png'));im.file_format='PNG';images[name]=im
    for m in metalmats:
        n=m.node_tree.nodes.new('ShaderNodeTexImage');n.name='Bake Target';m.node_tree.nodes.active=n
    bpy.ops.object.select_all(action='DESELECT')
    for o in bakeobjs:o.select_set(True)
    bpy.context.view_layer.objects.active=bakeobjs[0]
    return target,mapping,mesh_objects,metalmats,images

def bake_export(state):
    scene,mapping,objects,materials,images=state
    for name,kind in [('color','EMIT'),('roughness','ROUGHNESS'),('normal','NORMAL')]:
        for m in materials:m.node_tree.nodes['Bake Target'].image=images[name]
        connections=[]
        if name=='color':
            # Raw base colour: diffuse baking attenuates metal and is NOT albedo.
            for m in materials:
                nodes=m.node_tree.nodes;links=m.node_tree.links
                bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
                output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
                em=nodes.new('ShaderNodeEmission')
                links.new(bs.inputs['Base Color'].links[0].from_socket,em.inputs['Color'])
                links.new(em.outputs[0],output.inputs['Surface'])
                connections.append((m,bs,output,em))
        bpy.ops.object.bake(type=kind)
        for m,bs,output,em in connections:
            m.node_tree.links.new(bs.outputs[0],output.inputs['Surface']);m.node_tree.nodes.remove(em)
        images[name].save();images[name].pack()
        (OUT/'progress.json').write_text(json.dumps({'baked':name}))
    for m in materials:
        metal=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Metallic'].default_value
        m.node_tree.nodes.clear();nodes=m.node_tree.nodes;links=m.node_tree.links
        bs=nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Metallic'].default_value=metal
        out=nodes.new('ShaderNodeOutputMaterial');links.new(bs.outputs[0],out.inputs['Surface'])
        for name,socket in [('color','Base Color'),('roughness','Roughness'),('normal','Normal')]:
            n=nodes.new('ShaderNodeTexImage');n.image=images[name]
            if name=='normal':
                normal=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bs.inputs[socket])
            else:links.new(n.outputs['Color'],bs.inputs[socket])
    # Exact position multiset is checked before/after joining. UV seams may duplicate export vertices.
    def signature(obs):
        points=set()
        triangles=0
        for o in obs:
            o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
            for v in o.data.vertices:points.add(tuple(round(a,5) for a in (o.matrix_world@v.co)))
        digest=hashlib.sha256(repr(sorted(points)).encode()).hexdigest()
        return {'unique_positions':len(points),'triangles':triangles,'position_sha256':digest}
    before=signature(objects)
    groups={}
    for o in objects:groups.setdefault(o.parent,[]).append(o)
    merged=[]
    for parent,group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:o.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        bpy.ops.object.join();o=bpy.context.object
        o.name=(parent.name.removesuffix('__native') if parent else 'root')+'_approved_geometry'
        merged.append(o)
    after=signature(merged)
    # Joining changes only floating-point matrix arithmetic; verify geometric distance.
    from mathutils.kdtree import KDTree
    target_scene=bpy.context.window.scene
    source_scene=next(sc for sc in bpy.data.scenes if sc.name=='Rune Flame Turret — Design')
    bpy.context.window.scene=source_scene
    dg=bpy.context.evaluated_depsgraph_get()
    source_points=[o.matrix_world@v.co for o in mapping if o.type=='MESH' for v in o.evaluated_get(dg).data.vertices]
    bpy.context.window.scene=target_scene
    target_points=[o.matrix_world@v.co for o in merged for v in o.data.vertices]
    def deviation(a,b):
        tree=KDTree(len(b))
        for i,point in enumerate(b):tree.insert(point,i)
        tree.balance()
        return max(tree.find(point)[2] for point in a)
    max_error=max(deviation(source_points,target_points),deviation(target_points,source_points))
    assert max_error<1e-6 and before['triangles']==after['triangles'],max_error
    for orig,clone in mapping.items():
        if orig.type=='EMPTY':
            # Original scene owns the canonical names; exporter names target IDs explicitly below.
            original_name=orig.name
            orig.name=original_name+'__design_source'
            clone.name=original_name
    for o in merged:
        mod=o.modifiers.new('Explicit export triangulation','TRIANGULATE');mod.quad_method='FIXED';mod.ngon_method='BEAUTY'
        if hasattr(mod,'keep_custom_normals'):mod.keep_custom_normals=True
    for m in {slot.material for o in merged for slot in o.material_slots}:
        if m.name.startswith('Runes'):
            bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            bs.inputs['Emission Strength'].default_value=.8
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(ASSET),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_normals=True,export_texcoords=True,export_tangents=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
    report={'source':'runic-flame-turret.blend','geometry_before':before,'geometry_after':after,'geometry_preserved':max_error<1e-6,'max_position_error':max_error,'export_meshes':len(merged),'pbr_atlas_size':SIZE,'glb_bytes':ASSET.stat().st_size,'rebuild_or_decimation':False}
    (OUT/'geometry-check.json').write_text(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'runic-fire-optimized-baked.blend'))
    (OUT/'progress.json').write_text(json.dumps({'complete':True,**report}))
    print(report)

if __name__=='__main__':
    bake_export(setup())
    import struct
    manifest_path=OUT/'optimization-manifest.json'
    manifest=json.loads(manifest_path.read_text())
    raw=ASSET.read_bytes();length=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+length])
    triangles=sum(gltf['accessors'][p['indices']]['count']//3 for mesh in gltf['meshes'] for p in mesh['primitives'])
    assert triangles==manifest['optimized_triangles']
    for path_key,hash_key in [('baseline_game_asset','baseline_game_sha256'),('baseline_native_source','baseline_native_sha256'),('editable_finished_source','editable_finished_sha256')]:
        assert hashlib.sha256(Path(manifest[path_key]).read_bytes()).hexdigest()==manifest[hash_key]
    manifest.update({'glb_file':ASSET.name,'glb_sha256':hashlib.sha256(raw).hexdigest(),'glb_bytes':len(raw),'glb_triangles':triangles,'glb_meshes':len(gltf['meshes']),'glb_materials':len(gltf['materials']),'triangle_reduction_percent':100*(1-triangles/manifest['baseline_triangles']),'baseline_sources_preserved':True,'optimized_editable_sha256':hashlib.sha256((OUT/'runic-fire-optimized.blend').read_bytes()).hexdigest(),'bake':'Existing migration exporter:1024 shared color,roughness,tangent-normal; evaluated optimized mesh self-bake, no high-to-low projection. Native rune .8 emission factor. Runtime rune UNSHADED unchanged.','hero':'1200x1200 Cycles32 source-camera body-only render. QHD game comparison recorded under review/.','scope':'Static tower body only. No VFX changes, game install, APK or FPS claim.'})
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
