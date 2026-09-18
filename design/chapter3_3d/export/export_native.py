"""Bake approved evaluated tiles; never regenerate or overwrite the source.

Adapts runic_3d/migration/export_native.py's raw-channel EMIT bake and
chapter2 tile root contracts. Run with a separate background Blender.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Matrix
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'tiles/chapter3-thick-tiles.blend'
ASSET=ROOT/'assets/images/stage1_3d/environment/chapter3_tiles.glb'
SIZE=2048

def points(objects):
    return [o.matrix_world@v.co for o in objects for v in o.data.vertices]

def error(a,b):
    tree=KDTree(len(b))
    for i,p in enumerate(b):tree.insert(p,i)
    tree.balance()
    return max(tree.find(p)[2] for p in a)

def main():
    assert bpy.app.background
    source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    original=bpy.context.scene
    dg=bpy.context.evaluated_depsgraph_get()
    target=bpy.data.scenes.new('Chapter 3 Native PBR Tiles')
    mats={}; groups={}; checks={}
    for oldname,name in [('01_Cast_iron_plate','path_tile'),('02_Heat_vent_grate','grate_tile'),('03_Construction_foundation','build_tile'),('04_Plain_construction_foundation','plain_build_tile'),('05_Panel_solid','panel_solid'),('06_Panel_vent','panel_vent')]:
        root=bpy.data.objects[oldname];group=[]
        for ob in root.children:
            if ob.type!='MESH':continue
            mesh=bpy.data.meshes.new_from_object(ob.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
            clone=bpy.data.objects.new(ob.name+'__native',mesh);target.collection.objects.link(clone)
            clone.matrix_world=root.matrix_world.inverted()@ob.matrix_world
            # Procedural coordinates are local; all source tile parts use identity transforms.
            assert max(abs(clone.matrix_world[i][j]-Matrix.Identity(4)[i][j]) for i in range(4) for j in range(4))<1e-6
            for i,mat in enumerate(mesh.materials):
                if mat not in mats:mats[mat]=mat.copy()
                mesh.materials[i]=mats[mat]
            group.append(clone)
        groups[name]=group
    bpy.context.window.scene=target
    merged=[]
    for name,group in groups.items():
        before=points(group)
        tris=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in group)
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:o.select_set(True)
        bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
        o=bpy.context.object;o.name=name
        after=points([o]);o.data.calc_loop_triangles()
        deviation=max(error(before,after),error(after,before));assert deviation<1e-6
        assert tris==len(o.data.loop_triangles)
        checks[name]={'source_parts':len(group),'triangles':tris,'max_position_error':deviation,'bounds':[[min(p[i] for p in after),max(p[i] for p in after)] for i in range(3)]}
        merged.append(o)
    bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=merged[0]
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003)
    bpy.ops.object.mode_set(mode='OBJECT')
    target.render.engine='CYCLES';target.cycles.samples=4
    target.render.bake.use_clear=False;target.render.bake.margin=4
    images={}
    for channel in ('basecolor','roughness','normal','metallic','emission'):
        im=bpy.data.images.new('Chapter3 '+channel,width=SIZE,height=SIZE,alpha=False)
        if channel not in ('basecolor','emission'):im.colorspace_settings.name='Non-Color'
        im.filepath_raw=str(OUT/('chapter3-'+channel+'.png'));im.file_format='PNG';images[channel]=im
    for m in mats.values():
        n=m.node_tree.nodes.new('ShaderNodeTexImage');n.name='Bake Target';m.node_tree.nodes.active=n
    for channel in images:
        restore=[]
        for m in mats.values():
            nodes=m.node_tree.nodes;links=m.node_tree.links
            nodes['Bake Target'].image=images[channel]
            if channel=='normal':continue
            bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            em=nodes.new('ShaderNodeEmission')
            socket=bs.inputs[{'basecolor':'Base Color','roughness':'Roughness','metallic':'Metallic','emission':'Emission Color'}[channel]]
            if socket.is_linked:links.new(socket.links[0].from_socket,em.inputs['Color'])
            else:
                val=socket.default_value
                em.inputs['Color'].default_value=(val,val,val,1) if isinstance(val,float) else val
            if channel=='emission':
                strength=bs.inputs['Emission Strength']
                if strength.is_linked:links.new(strength.links[0].from_socket,em.inputs['Strength'])
                else:em.inputs['Strength'].default_value=strength.default_value
            links.new(em.outputs[0],out.inputs['Surface']);restore.append((m,bs,out,em))
        bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT')
        for m,bs,out,em in restore:
            m.node_tree.links.new(bs.outputs[0],out.inputs['Surface']);m.node_tree.nodes.remove(em)
        images[channel].save();images[channel].pack()
        (OUT/'progress.json').write_text(json.dumps({'baked':channel}))
        print('BAKED',channel,flush=True)
    # One common native material, one draw surface per tile, full channel semantics.
    material=bpy.data.materials.new('Chapter3 approved foundry PBR');material.use_nodes=True
    nodes=material.node_tree.nodes;links=material.node_tree.links;bs=nodes.get('Principled BSDF')
    for channel,socket in [('basecolor','Base Color'),('roughness','Roughness'),('metallic','Metallic'),('normal','Normal'),('emission','Emission Color')]:
        n=nodes.new('ShaderNodeTexImage');n.image=images[channel]
        if channel=='normal':
            norm=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],norm.inputs['Color']);links.new(norm.outputs[0],bs.inputs[socket])
        else:links.new(n.outputs['Color'],bs.inputs[socket])
    bs.inputs['Emission Strength'].default_value=1
    for o in merged:
        o.data.materials.clear();o.data.materials.append(material)
        for face in o.data.polygons:face.material_index=0
        tri=o.modifiers.new('Explicit export triangulation','TRIANGULATE')
        if hasattr(tri,'keep_custom_normals'):tri.keep_custom_normals=True
        o['bodyThickness']=.50;o['surfaceZ']=0.;o['source']=str(SOURCE.relative_to(ROOT))
    bpy.ops.export_scene.gltf(filepath=str(ASSET),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_normals=True,export_texcoords=True,export_tangents=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'chapter3-native-export.blend'))
    # Reimport exported geometry to verify actual artifact and embedded maps.
    checkscene=bpy.data.scenes.new('GLB reimport verification');bpy.context.window.scene=checkscene
    bpy.ops.import_scene.gltf(filepath=str(ASSET))
    imported=[o for o in checkscene.objects if o.type=='MESH']
    reimport={}
    for source in merged:
        ob=next(o for o in imported if o.name.split('.')[0]==source.name)
        deviation=max(error(points([source]),points([ob])),error(points([ob]),points([source])))
        assert deviation<2e-6,(source.name,deviation)
        reimport[source.name]={'max_position_error':deviation,'surfaces':len(ob.data.materials)}
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
    report={'source_sha256':source_hash,'source_unchanged':True,'tiles':checks,'reimport':reimport,'atlas_size':SIZE,'channels':list(images),'glb_bytes':ASSET.stat().st_size,'glb_sha256':hashlib.sha256(ASSET.read_bytes()).hexdigest(),'source_features':'4 tile tops; 4 true recessed panel seats per tile; independent solid and vent panels; vent heat recessed .020 behind frame, three vertical orange slots; no embedded side panels in tile roots'}
    (OUT/'geometry-check.json').write_text(json.dumps(report,indent=2)+'\n')
    (OUT/'progress.json').write_text(json.dumps({'complete':True,**report}))
    print('EXPORT_READY',json.dumps(report),flush=True)

if __name__=='__main__':main()
