"""Standalone preparation export. Adapted from runic_3d/migration/export_native.py.
Usage: Blender -b sniper-swift-optimized.blend --python export_preview.py
Writes only the production directory, never a game asset.
"""
import bpy, math, json, hashlib, struct
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
source=bpy.context.scene; bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
keep=[o for c in source.collection.children if c.name.startswith(('C01','C02','C03')) for o in c.objects]
target=bpy.data.scenes.new('Sniper C — Baked preview export')
mapping={}; mats={}; meshes=[]
for o in keep:
    if o.type=='MESH':
        data=bpy.data.meshes.new_from_object(o.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
        clone=bpy.data.objects.new(o.name+'__preview',data)
        for i,m in enumerate(data.materials):
            if m not in mats:mats[m]=m.copy()
            data.materials[i]=mats[m]
        meshes.append(clone)
    else:clone=bpy.data.objects.new(o.name+'__preview',None)
    target.collection.objects.link(clone);mapping[o]=clone;clone.matrix_world=o.matrix_world.copy()
for o,clone in mapping.items():
    world=clone.matrix_world.copy()
    if o.parent in mapping:clone.parent=mapping[o.parent]
    clone.matrix_world=world
bpy.context.window.scene=target;bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.005)
bpy.ops.object.mode_set(mode='OBJECT')
target.render.engine='CYCLES';target.cycles.samples=8
target.render.bake.use_clear=False;target.render.bake.margin=3
target.render.bake.use_pass_direct=False;target.render.bake.use_pass_indirect=False;target.render.bake.use_pass_color=True
metals=[m for orig,m in mats.items() if 'cyan' not in orig.name]
bakeobjs=[o for o in meshes if any(m in metals for m in o.data.materials)]
images={}
for name in ['color','roughness','normal']:
    im=bpy.data.images.new('Sniper C atlas '+name,width=1024,height=1024,alpha=False)
    if name!='color':im.colorspace_settings.name='Non-Color'
    im.filepath_raw=str(OUT/('sniper-c-'+name+'.png'));im.file_format='PNG';images[name]=im
for m in metals:
    n=m.node_tree.nodes.new('ShaderNodeTexImage');n.name='Bake Target';m.node_tree.nodes.active=n
bpy.ops.object.select_all(action='DESELECT')
for o in bakeobjs:o.select_set(True)
bpy.context.view_layer.objects.active=bakeobjs[0]
for name,kind in [('color','EMIT'),('roughness','ROUGHNESS'),('normal','NORMAL')]:
    for m in metals:m.node_tree.nodes['Bake Target'].image=images[name]
    connections=[]
    if name=='color':
        for m in metals:
            nodes,links=m.node_tree.nodes,m.node_tree.links
            bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            em=nodes.new('ShaderNodeEmission');links.new(bs.inputs['Base Color'].links[0].from_socket,em.inputs['Color']);links.new(em.outputs[0],output.inputs['Surface']);connections.append((m,bs,output,em))
    bpy.ops.object.bake(type=kind)
    for m,bs,output,em in connections:m.node_tree.links.new(bs.outputs[0],output.inputs['Surface']);m.node_tree.nodes.remove(em)
    images[name].save();images[name].pack()
    print('BAKED',name,flush=True)
for m in metals:
    metallic=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Metallic'].default_value
    m.node_tree.nodes.clear();nodes,links=m.node_tree.nodes,m.node_tree.links
    bs=nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Metallic'].default_value=metallic
    output=nodes.new('ShaderNodeOutputMaterial');links.new(bs.outputs[0],output.inputs['Surface'])
    for name,socket in [('color','Base Color'),('roughness','Roughness'),('normal','Normal')]:
        n=nodes.new('ShaderNodeTexImage');n.image=images[name]
        if name=='normal':
            norm=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],norm.inputs['Color']);links.new(norm.outputs[0],bs.inputs[socket])
        else:links.new(n.outputs['Color'],bs.inputs[socket])

def is_descendant(o,p):
    while o:
        if o==p:return True
        o=o.parent
    return False

controls={}
for name in ['turret_root','turret_head','turret_barrel','muzzle']:
    orig=next(o for o in mapping if o.name.split('.')[0]==name)
    controls[name]=mapping[orig]
    orig.name=orig.name+'__editable';controls[name].name=name
head=controls['turret_head'];root=controls['turret_root'];barrel=controls['turret_barrel']
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
rotating=[o.matrix_world@v.co for o in meshes if is_descendant(o,head) for v in o.data.vertices]
fixed=[o.matrix_world@v.co for o in meshes if not is_descendant(o,head) for v in o.data.vertices]
triangles=0
for o in meshes:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
assert tuple(round(v,6) for v in barrel.location)==(0,0,0)
assert all(sum(abs(a) for a in controls[n].rotation_euler)<1e-6 for n in controls)
assert head.parent==root and barrel.parent==head and controls['muzzle'].parent==barrel
# Merge by contract ownership only. Preserve fixed vs aiming vs recoil boundaries.
groups={root:[],head:[],barrel:[]}
for o in meshes:
    owner=barrel if is_descendant(o,barrel) else head if is_descendant(o,head) else root
    groups[owner].append(o)
merged=[]
for parent,group in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in group:o.select_set(True)
    bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();o=bpy.context.object
    mw=o.matrix_world.copy();o.parent=parent;o.matrix_world=mw;o.name=parent.name+'_geometry';merged.append(o)
for o in list(target.objects):
    if o.type=='EMPTY' and o not in controls.values():bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'sniper-swift-optimized.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
manifest={
 'approved_reference':'../../receiver-variants/01-swept-wedge.png (01 SWIFT)',
 'latest_user_revision':'01 SWIFT swept receiver, inset aiming lens, curved yoke; true vertical top view. Lowered column, head pivot .45, long barrel and muzzle retained.',
 'editable_source':'sniper-swift-optimized.blend','prepared_export':'sniper-swift-optimized.glb',
 'not_installed_in_game':True,'blender_version':bpy.app.version_string,
 'triangles':triangles,'material_count':len(mats),'mesh_count':len(merged),
 'bounds_blender':[[round(min(p[i] for p in points),6) for i in range(3)],[round(max(p[i] for p in points),6) for i in range(3)]],
 'fixed_footprint_radius':round(max(math.hypot(p.x,p.y) for p in fixed),6),
 'rotating_footprint_radius':round(max(math.hypot(p.x,p.y) for p in rotating),6),
 'head_origin_blender':list(head.location),'barrel_initial_position':list(barrel.location),
 'muzzle_blender_world':list(controls['muzzle'].matrix_world.translation),
 'coordinates':'Blender Z up/-Y forward => glTF Y up/+Z forward',
 'material_parameters':{'blue_grey_steel':{'metallic':.88,'roughness':.34},'silver_armour':{'metallic':.94,'roughness':.26},'bronze':{'metallic':.85,'roughness':.33},'dark_recess':{'metallic':.80,'roughness':.40}},
 'geometry_sha256':hashlib.sha256(repr(sorted(set(tuple(round(a,6) for a in p) for p in points))).encode()).hexdigest(),
 'render_conditions':{'renderer':'Cycles','samples':48,'size':[1200,1200],'view':'AgX / Medium High Contrast','exposure':.6,'tile':'standalone simple green tile, not game capture'},
 'limitations':['No game integration or runtime aim/recoil verification in this model-production scope.']}
manifest['glb_bytes']=(OUT/'sniper-swift-optimized.glb').stat().st_size
manifest['glb_sha256']=hashlib.sha256((OUT/'sniper-swift-optimized.glb').read_bytes()).hexdigest()
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
bpy.data.libraries.write(str(OUT/'sniper-swift-optimized-baked.blend'),{target},fake_user=True,compress=True)
print(json.dumps(manifest,ensure_ascii=False,indent=2),flush=True)
