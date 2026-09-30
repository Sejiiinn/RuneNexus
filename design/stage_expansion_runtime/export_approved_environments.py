"""Export approved saved map geometry; never regenerate or overwrite source blends.
Uses the established dressing UV/Color batching and chapter-two geology GLB path.
Run using Blender --background --python this_file.py.
"""
import bpy, json, hashlib, os
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
TARGET=ROOT/'assets/images/stage1_3d/environment'
REPORT=ROOT/'build/stage-expansion-runtime/export.json'
TARGET.mkdir(parents=True,exist_ok=True);REPORT.parent.mkdir(parents=True,exist_ok=True)
if not bpy.app.background: raise RuntimeError('Preserve the open editor: independent background export only')
report=[]

def export(root,path):
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for ob in root.children_recursive: ob.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_yup=True,export_extras=True,export_animations=False,export_cameras=False,export_lights=False,export_morph=False,export_vertex_color="NAME",export_vertex_color_name="Color",export_all_vertex_colors=False)

def root_object(name):
    # Original roots remain unmodified in the saved Blender file.
    old=bpy.data.objects.get(name)
    if old: old.name=name+'_source'
    root=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(root)
    return root

def batch(name,objects,root):
    copies=[]
    for src in objects:
        if src.type!='MESH':continue
        ob=src.copy();ob.data=src.data.copy();bpy.context.scene.collection.objects.link(ob)
        ob.parent=None;ob.matrix_world=src.matrix_world.copy();copies.append(ob)
    if not copies: return
    bpy.ops.object.select_all(action='DESELECT')
    for ob in copies:ob.select_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
    ob=bpy.context.object;ob.name=name;ob.parent=root

for chapter in (1,2):
    if os.environ.get("EXPANSION_CHAPTER") and str(chapter)!=os.environ["EXPANSION_CHAPTER"]:continue
    specs=json.loads((ROOT/f'design/chapter{chapter}_map_expansion/maps.json').read_text())['maps']
    for spec in specs:
        label=spec['chapterStage'];number=int(label.split('-')[1]);fixed=(10+number if chapter==1 else 15+number)
        source=ROOT/(f'design/chapter1_map_expansion/concepts/'+('chapter1-teleport-map-concepts.blend' if number in (7,10) else 'chapter1-five-map-concepts.blend') if chapter==1 else 'design/chapter2_map_expansion/concepts/chapter2-five-map-concepts.blend')
        bpy.ops.wm.open_mainfile(filepath=str(source))
        scene=next(s for s in bpy.data.scenes if s.name.startswith(label+' '));bpy.context.window.scene=scene
        entry={'stage':fixed,'label':label,'source':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'files':[]}
        if chapter==1:
            objects=[o for o in scene.objects if o.name.startswith(label+'_dressing_')]
            slots={tuple(cell):slot for slot,cell in enumerate(spec['buildCells'])}
            # Slots follow row-major runtime traversal, independent of design JSON ordering.
            slots={(i%spec['columns'],i//spec['columns']):slot for slot,i in enumerate(i for i,t in enumerate(spec['tiles']) if t=='build')}
            records={d['name']:d for d in json.loads(scene['dressingRecords'])}
            root=root_object('stage1_dressing');root['columns']=spec['columns'];root['rows']=spec['rows'];root['tileTypes']=spec['tiles'];root['buildTileCount']=len(slots)
            for group in ('foliage','rocks'):
                vertices=[];faces=[];colors=[];uvs=[];occupancy=[]
                for ob in objects:
                    if ob.get('dressingGroup')!=group:continue
                    mesh=ob.data;offset=len(vertices);vertices.extend(tuple(ob.matrix_world@v.co) for v in mesh.vertices)
                    faces.extend(tuple(i+offset for i in p.vertices) for p in mesh.polygons)
                    colors.extend(tuple(c.color) for c in mesh.color_attributes['Color'].data)
                    uvs.extend(tuple(u.uv) for u in mesh.uv_layers[0].data)
                    slot=slots[tuple(records[ob.name]['cell'])]
                    occupancy.extend((slot,u.uv.y) for u in mesh.uv_layers['Occupancy'].data)
                if not vertices:raise RuntimeError(f'{label} missing dressing group {group}')
                mesh=bpy.data.meshes.new('stage1_dressing_'+group);mesh.from_pydata(vertices,[],faces);mesh.materials.append(bpy.data.materials['Stage1Dressing_'+group])
                attr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT');mesh.color_attributes.active_color=attr
                for a,v in zip(attr.data,colors):a.color=v
                for name,values in [('Wind',uvs),('Occupancy',occupancy)]:
                    uv=mesh.uv_layers.new(name=name)
                    for a,v in zip(uv.data,values):a.uv=v
                for p in mesh.polygons:p.use_smooth=group=='foliage'
                mesh.update();ob=bpy.data.objects.new(mesh.name,mesh);scene.collection.objects.link(ob);ob.parent=root
            scene.name="Dressing Export (temporary)"
            path=TARGET/f'dressing_stage{fixed}.glb';export(root,path);entry['files'].append(str(path.relative_to(ROOT)))
        else:
            original=next(o for o in scene.objects if o.name==label+'_continuous_geology')
            root=root_object(f'stage{fixed}_geology');root['columns']=spec['columns'];root['rows']=spec['rows'];root['tileTypes']=spec['tiles']
            points=[o.matrix_world@Vector(v) for o in original.children_recursive if o.type=='MESH' for v in o.bound_box]
            root['cameraPointsGodot']=[[v.x,v.z,-v.y] for v in points]
            root['accentLights']=[]
            batch(f'stage{fixed}_continuous_rock_strata',original.children_recursive,root)
            path=TARGET/f'chapter2_stage{fixed}_geology.glb';export(root,path);entry['files'].append(str(path.relative_to(ROOT)))
            props=root_object(f'stage{fixed}_props')
            records=json.loads(scene['dressingRecords'])
            actors=[scene.objects[label+'_'+d['role']] for d in records]
            for actor in actors:
                # Preserve the existing source exporter boundaries: each crystal shell
                # and its layered interior sort separately, while opaque stone is batched.
                groups={}
                for ob in [actor,*actor.children_recursive]:
                    if ob.type!='MESH':continue
                    material=ob.data.materials[0].name
                    if '_mineral_layer_' in ob.name:key=ob.name.split('_mineral_layer_')[0]+'_inner'
                    elif material.startswith('ch2_crystal_'):key=ob.name
                    else:key=material
                    groups.setdefault(key,[]).append(ob)
                for key,objects in groups.items():batch(actor.name+'__'+key,objects,props)
            path=TARGET/f'chapter2_stage{fixed}_props.glb';export(props,path);entry['files'].append(str(path.relative_to(ROOT)))
        report.append(entry);REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('EXPORTED_APPROVED',label,fixed,flush=True)
