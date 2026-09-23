"""Actual Blender surface frosting, baked to shared PBR UV textures.
Run prepare(ns), preview the source material, then bake(ns). Geometry is unchanged.
The existing build_frost.py namespace supplies editable components and export().
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

def prepare(ns):
    scene=ns['scene'];bpy.context.window.scene=scene
    root=ns['root']
    materials=[ns[key] for key in ('steel','edge','stone','bronze','bronzeedge')]
    geometry_before={o.name:([tuple(v.co) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons],tuple(o.matrix_world)) for o in root.children_recursive if o.type=='MESH'}
    for material in materials:
        n=material.node_tree.nodes;l=material.node_tree.links;p=n.get('Principled BSDF')
        def node(kind,name):
            x=n.new(kind);x.label=name;x.name=name;return x
        def mathnode(op,a,b,name):
            x=node('ShaderNodeMath',name);x.operation=op
            for idx,v in enumerate((a,b)):
                if isinstance(v,(int,float)):x.inputs[idx].default_value=v
                else:l.new(v,x.inputs[idx])
            return x.outputs[0]
        def ramp(value,lo,hi,name):
            x=node('ShaderNodeMapRange',name);x.clamp=True
            x.inputs['From Min'].default_value=lo;x.inputs['From Max'].default_value=hi
            l.new(value,x.inputs['Value']);return x.outputs[0]
        def original(name):
            s=p.inputs[name]
            if s.is_linked:return s.links[0].from_socket
            return tuple(s.default_value) if name=='Base Color' else s.default_value
        uv=node('ShaderNodeUVMap','Original substrate UV');uv.uv_map='OriginalSurface'
        for tex in list(n):
            if tex.type=='TEX_IMAGE':l.new(uv.outputs['UV'],tex.inputs['Vector'])
        geo=node('ShaderNodeNewGeometry','Real surface geometry')
        noise=node('ShaderNodeTexNoise','Uneven frost accumulation');noise.inputs['Scale'].default_value=22;noise.inputs['Detail'].default_value=3.5
        l.new(geo.outputs['Position'],noise.inputs['Vector'])
        grain=node('ShaderNodeTexNoise','Fine frost grains');grain.inputs['Scale'].default_value=640;grain.inputs['Detail'].default_value=2
        l.new(geo.outputs['Position'],grain.inputs['Vector'])
        warp=node('ShaderNodeVectorMath','Crystal coordinate warp');warp.operation='SCALE';warp.inputs[3].default_value=.008;l.new(noise.outputs['Color'],warp.inputs[0])
        add=node('ShaderNodeVectorMath','Crystalline surface coordinates');add.operation='ADD';l.new(geo.outputs['Position'],add.inputs[0]);l.new(warp.outputs[0],add.inputs[1])
        crystal=node('ShaderNodeTexVoronoi','Thin frost crystal lattice');crystal.feature='DISTANCE_TO_EDGE';crystal.inputs['Scale'].default_value=205;l.new(add.outputs[0],crystal.inputs['Vector'])
        vein=mathnode('SUBTRACT',1,ramp(crystal.outputs['Distance'],.014,.063,'Crystal lattice width'),'Crystal lattice mask')
        patch=ramp(noise.outputs['Fac'],.49,.69,'Patch distribution')
        veins=mathnode('MULTIPLY',vein,patch,'Uneven crystal branches')
        bevel=node('ShaderNodeBevel','Actual edge frost accumulation');bevel.inputs['Radius'].default_value=.0035 if material in (ns['bronze'],ns['bronzeedge']) else .006;bevel.samples=4
        dot=node('ShaderNodeVectorMath','Bevel and surface normal difference');dot.operation='DOT_PRODUCT';l.new(geo.outputs['Normal'],dot.inputs[0]);l.new(bevel.outputs['Normal'],dot.inputs[1])
        edge=ramp(mathnode('SUBTRACT',1,dot.outputs['Value'],'Physical edge proximity'),.002,.040,'Edge frost width')
        clusters=node('ShaderNodeTexNoise','Broken granular frost clusters');clusters.inputs['Scale'].default_value=130;clusters.inputs['Detail'].default_value=5;clusters.inputs['Roughness'].default_value=.68
        l.new(add.outputs[0],clusters.inputs['Vector'])
        broken=ramp(clusters.outputs['Fac'],.37,.68,'Discontinuous crystal patches')
        edgegrain=mathnode('ADD',.18,mathnode('MULTIPLY',broken,.82,'Grain coverage'),'Broken edge crystals')
        edgecoat=mathnode('MULTIPLY',edge,edgegrain,'Frost on actual edges')
        grains=mathnode('MULTIPLY',mathnode('MULTIPLY',ramp(clusters.outputs['Fac'],.49,.66,'Sparse tiny crystals'),patch,'Scattered cluster islands'),.58,'Thin face frost')
        mask=mathnode('ADD',mathnode('MULTIPLY',mathnode('MULTIPLY',veins,broken,'Interrupted crystal threads'),.60,'Face crystal coverage'),mathnode('MULTIPLY',edgecoat,.80,'Edge crystal coverage'),'Frost surface coverage')
        mask=mathnode('MINIMUM',mathnode('ADD',mask,grains,'Combined frost'),.91,'Keep underlying metal readable')
        if material in (ns['bronze'],ns['bronzeedge']):mask=mathnode('MULTIPLY',mask,.72,'Preserve bronze centers')
        base=original('Base Color');rough=original('Roughness');metal=original('Metallic');normal=original('Normal') if p.inputs['Normal'].is_linked else None
        mix=node('ShaderNodeMixRGB','Frosted substrate basecolor');mix.blend_type='MIX';l.new(mask,mix.inputs[0])
        if isinstance(base,tuple):mix.inputs[1].default_value=base
        else:l.new(base,mix.inputs[1])
        mix.inputs[2].default_value=ns['rgba']('BBD8E2')
        l.new(mix.outputs[0],p.inputs['Base Color'])
        for name,old,target in [('Roughness',rough,.76),('Metallic',metal,.025)]:
            x=node('ShaderNodeMixRGB','Frosted '+name);l.new(mask,x.inputs[0])
            if isinstance(old,(int,float)):x.inputs[1].default_value=(old,old,old,1)
            else:l.new(old,x.inputs[1])
            x.inputs[2].default_value=(target,target,target,1);l.new(x.outputs[0],p.inputs[name])
        bump=node('ShaderNodeBump','Microscopic crystal relief');bump.inputs['Strength'].default_value=.23;bump.inputs['Distance'].default_value=.00085
        l.new(mask,bump.inputs['Height'])
        if normal is not None:l.new(normal,bump.inputs['Normal'])
        l.new(bump.outputs['Normal'],p.inputs['Normal'])
    for obj in root.children_recursive:
        if obj.type!='MESH':continue
        if obj.data.uv_layers:
            original=next((uv for uv in obj.data.uv_layers if uv.active_render),obj.data.uv_layers.active)
            original.name='OriginalSurface'
    ns['frost_materials']=materials;ns['frost_geometry_before']=geometry_before
    print('PROCEDURAL_SURFACE_FROST_READY')

def bake(ns):
    scene=ns['scene'];bpy.context.window.scene=scene;root=ns['root'];materials=ns['frost_materials']
    out=Path(ns['OUT'])/'textures';out.mkdir(parents=True,exist_ok=True)
    originals=[o for o in root.children_recursive if o.type=='MESH' and any(m in materials for m in o.data.materials)]
    # A single bake copy unifies UV packing, while the editable source meshes
    # retain their positions, polygons, material slots and component hierarchy.
    copies=[];counts=[]
    for ob in originals:
        cp=ob.copy();cp.data=ob.data.copy();scene.collection.objects.link(cp)
        cp.matrix_world=ob.matrix_world.copy();cp.parent=None
        cp.name='Frost atlas bake '+ob.name
        copies.append(cp);counts.append(len(cp.data.loops))
        for uv in list(cp.data.uv_layers):
            if uv.name!='OriginalSurface':cp.data.uv_layers.remove(uv)
        uv=cp.data.uv_layers.new(name='FrostSurface');uv.active_render=True;cp.data.uv_layers.active=uv
        # Preserve loop provenance through Blender join without relying on sort.
        attr=cp.data.attributes.new('frost_loop_source','INT','CORNER')
        for i,d in enumerate(attr.data):d.value=sum(counts[:-1])+i
    for ob in bpy.context.view_layer.objects:ob.select_set(False)
    for ob in copies:ob.select_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();target=copies[0]
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.009,area_weight=.3,correct_aspect=True,scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    atlas=target.data.uv_layers['FrostSurface'];lookup={a.value:tuple(atlas.data[i].uv) for i,a in enumerate(target.data.attributes['frost_loop_source'].data)}
    offset=0
    for ob,count in zip(originals,counts):
        uv=ob.data.uv_layers.get('FrostSurface') or ob.data.uv_layers.new(name='FrostSurface')
        for i,d in enumerate(uv.data):d.uv=lookup[offset+i]
        uv.active_render=True;ob.data.uv_layers.active=uv;offset+=count
    hidden=[]
    for ob in root.children_recursive:
        hidden.append((ob,ob.hide_render));ob.hide_render=True
    target.hide_render=False
    scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.bake.margin=12;scene.render.bake.use_clear=True
    scene.render.bake.use_selected_to_active=False
    images={};outputs={}
    for m in target.data.materials:
        if m is None:continue
        nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF');output=nodes.get('Material Output')
        outputs[m]=(output,p,output.inputs['Surface'].links[0].from_socket)
    # Actual metal/roughness must share a packed PBR texture; frost is dielectric.
    for channel in ('basecolor','normal','orm'):
        image=bpy.data.images.new('Frost surface '+channel,width=2048,height=2048,alpha=False)
        if channel!='basecolor':image.colorspace_settings.name='Non-Color'
        for m,(output,p,_) in outputs.items():
            n=m.node_tree.nodes;l=m.node_tree.links
            targetnode=n.new('ShaderNodeTexImage');targetnode.name='Frost bake target '+channel;targetnode.image=image;n.active=targetnode
            if channel=='normal':
                l.new(p.outputs['BSDF'],output.inputs['Surface'])
            else:
                emit=n.new('ShaderNodeEmission');emit.name='Frost bake emission '+channel
                if channel=='basecolor':
                    source=p.inputs['Base Color'];l.new(source.links[0].from_socket,emit.inputs['Color']) if source.is_linked else setattr(emit.inputs['Color'],'default_value',source.default_value)
                else:
                    combine=n.new('ShaderNodeCombineColor');combine.mode='RGB';combine.inputs[0].default_value=1.0
                    for idx,key in ((1,'Roughness'),(2,'Metallic')):
                        source=p.inputs[key]
                        if source.is_linked:l.new(source.links[0].from_socket,combine.inputs[idx])
                        else:combine.inputs[idx].default_value=source.default_value
                    l.new(combine.outputs[0],emit.inputs['Color'])
                l.new(emit.outputs[0],output.inputs['Surface'])
        bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT',margin=12)
        image.filepath_raw=str(out/f'frost_surface_{channel}.png');image.file_format='PNG';image.save();image.pack();images[channel]=image
        print('FROST_PBR_BAKED',channel,flush=True)
    for m,(output,p,socket) in outputs.items():m.node_tree.links.new(socket,output.inputs['Surface'])
    bpy.data.objects.remove(target,do_unlink=True)
    for ob,was in hidden:ob.hide_render=was
    for m in materials:
        n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
        uv=n.new('ShaderNodeUVMap');uv.uv_map='FrostSurface';uv.name='Baked frost surface UV'
        tex={}
        for channel,image in images.items():
            t=n.new('ShaderNodeTexImage');t.image=image;t.name='Final frost '+channel;l.new(uv.outputs['UV'],t.inputs['Vector']);tex[channel]=t
        l.new(tex['basecolor'].outputs[0],p.inputs['Base Color'])
        normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=1;l.new(tex['normal'].outputs[0],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal'])
        split=n.new('ShaderNodeSeparateColor');split.mode='RGB';l.new(tex['orm'].outputs[0],split.inputs[0]);l.new(split.outputs[1],p.inputs['Roughness']);l.new(split.outputs[2],p.inputs['Metallic'])
    before=ns['frost_geometry_before'];unchanged=True
    for ob in root.children_recursive:
        if ob.type!='MESH':continue
        record=before[ob.name]
        unchanged &= record[0]==[tuple(v.co) for v in ob.data.vertices] and record[1]==[tuple(p.vertices) for p in ob.data.polygons] and record[2]==tuple(ob.matrix_world)
    assert unchanged,'Frost baking changed source geometry'
    (Path(ns['OUT'])/'surface-bake-audit.json').write_text(json.dumps({'geometry_unchanged':unchanged,'coated_materials':len(materials),'atlas_size':2048,'channels':list(images),'coated_editable_objects':len(originals)},indent=2))
    print('SURFACE_FROST_BAKE_COMPLETE')
