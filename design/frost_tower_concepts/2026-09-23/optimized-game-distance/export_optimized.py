import bpy,json,struct,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
scene=bpy.context.scene
root=bpy.data.objects['turret_root'];head=bpy.data.objects['turret_head'];barrel=bpy.data.objects['turret_barrel'];muzzle=bpy.data.objects['muzzle']
shellmat=next(m for m in bpy.data.materials if m.name=='Frost | transparent ice outer skin')
def export():
    displaced=[]
    displaced_materials=[]
    for m in {m for o in root.children_recursive if o.type=='MESH' for m in o.data.materials}:
        name=m.name.split('.')[0]
        while name.startswith('refined_'):name=name[len('refined_'):]
        old=bpy.data.materials.get(name)
        if old and old!=m:
            displaced_materials.append((old,name,m));old.name='Archived prototype '+old.name
        m.name=name
    for o,name in [(root,'turret_root'),(head,'turret_head'),(barrel,'turret_barrel'),(muzzle,'muzzle')]:
        old=bpy.data.objects.get(name)
        if old and old!=o:
            displaced.append((old,name));old.name='preserved_original_'+name
        o.name=name
    for o in list(barrel.children):
        if o.type=='MESH':o.parent=head
    for img in bpy.data.images:
        if img.filepath and img.users:img.pack()
    bpy.data.libraries.write(str(OUT/'frost-optimized.blend'),{scene},fake_user=True,compress=True)
    originals=[o for o in root.children_recursive if o.type=='MESH']
    groups={}
    for o in originals:
        key=(o.parent,'skin' if shellmat in list(o.data.materials) else 'solid')
        cp=o.copy();cp.data=o.data.copy();scene.collection.objects.link(cp)
        # Joining differently named UV layers creates default-filled UV0 data.
        # Preserve each source's active-render coordinates as a single common UV0.
        if cp.data.uv_layers:
            active=next((uv for uv in cp.data.uv_layers if uv.active_render),cp.data.uv_layers.active)
            coords=[tuple(loop.uv) for loop in active.data]
            for uv in list(cp.data.uv_layers):cp.data.uv_layers.remove(uv)
            uv=cp.data.uv_layers.new(name='UVMap')
            for loop,co in zip(uv.data,coords):loop.uv=co
            uv.active_render=True;cp.data.uv_layers.active_index=0
        groups.setdefault(key,[]).append(cp)
    merged=[]
    for (parent,kind),objects in groups.items():
        for o in bpy.data.objects:o.select_set(False)
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        ob=objects[0];ob.name=('Frost fixed body' if parent==root else 'Frost fixed iris')+' '+kind
        merged.append(ob)
    for o in bpy.data.objects:o.select_set(False)
    for o in [root,head,barrel,muzzle]+merged:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'frost-optimized.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    payload=(OUT/'frost-optimized.glb').read_bytes();gltf=json.loads(payload[20:20+struct.unpack_from('<I',payload,12)[0]])
    tris=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
    surfaces=sum(len(set(p.material_index for p in o.data.polygons)) for o in merged)
    mats=set(m.name for o in merged for m in o.data.materials)
    for o in merged:bpy.data.objects.remove(o,do_unlink=True)
    for old,name in displaced:
        bpy.data.objects[name].name='frost_production_'+name
        old.name=name
    for old,name,new in displaced_materials:
        new.name='refined_'+name
        old.name=name
    bpy.context.view_layer.update()
    coords=[o.matrix_world@Vector(c) for o in originals for c in o.bound_box]
    dimensions=[max(c[i] for c in coords)-min(c[i] for c in coords) for i in range(3)]
    (OUT/'model_audit.json').write_text(json.dumps({'triangles':tris,'sha256':hashlib.sha256(payload).hexdigest(),'embedded_images':len(gltf.get('images',[])),'runtime_nodes':len(gltf.get('nodes',[])),'editable_meshes':len(originals),'runtime_meshes':len(groups),'runtime_surfaces':surfaces,'materials':sorted(mats),'dimensions_blender_xyz':dimensions,'glb_bytes':(OUT/'frost-optimized.glb').stat().st_size,'rig':['turret_root','turret_head','turret_barrel','muzzle'],'structure':{'shutters':6,'ribs':6,'cooling_bays':6,'fins_per_bay':12,'feet':4}},indent=2))

export()
