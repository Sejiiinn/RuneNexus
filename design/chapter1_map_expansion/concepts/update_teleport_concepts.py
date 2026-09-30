"""Update only approved proposal 1-7/1-10 from the saved five-map source.
Retain the original .blend; emit an editable two-scene derivative and two renders.
Run through an independent Blender background process.
"""
import bpy, json, hashlib, shutil
from pathlib import Path
from mathutils import Vector
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'build/chapter1-teleport-placement'
SOURCE = HERE / 'chapter1-five-map-concepts.blend'
PORTALS = ROOT / 'design/teleport_device_concepts/2026-09-30/production/teleport-four-variants.blend'
OUTPUT = HERE / 'chapter1-teleport-map-concepts.blend'
if not bpy.app.background: raise RuntimeError('Use independent background Blender')
OUT.mkdir(parents=True, exist_ok=True)
import sys
sys.path.insert(0,str(ROOT/'scripts'))
from content_design_views import load_design_view
specs = {m['chapterStage']:m for m in load_design_view(HERE.parent/'maps.json')['maps'] if m['chapterStage'] in ['1-7','1-10']}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def remove_tree(ob):
    for child in list(ob.children): remove_tree(child)
    bpy.data.objects.remove(ob, do_unlink=True)
def clone_tree(scene, source, parent=None):
    ob=source.copy(); scene.collection.objects.link(ob); ob.parent=parent
    ob.hide_render=False; ob.hide_viewport=False
    for child in source.children: clone_tree(scene,child,ob)
    return ob
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
for scene in list(bpy.data.scenes):
    if scene.name.split(' ')[0] not in specs: bpy.data.scenes.remove(scene)
with bpy.data.libraries.load(str(PORTALS),link=False) as (src,dst):
    dst.collections = ['BLUE IN','BLUE OUT','ORANGE IN','ORANGE OUT']
    dst.node_groups = ['Portal restrained optical glow']
roots = {name:bpy.data.objects[name.replace(' ','_')] for name in ['BLUE IN','BLUE OUT','ORANGE IN','ORANGE OUT']}
report={'source':sha(SOURCE),'portal_source':sha(PORTALS),'maps':[]}
for stage,spec in specs.items():
    scene=next(s for s in bpy.data.scenes if s.name.startswith(stage+' '));bpy.context.window.scene=scene
    scene.frame_set(17);scene.render.fps=24;scene.frame_start=1;scene.frame_end=96
    scene.compositing_node_group=bpy.data.node_groups['Portal restrained optical glow'].copy()
    for node in scene.compositing_node_group.nodes:
        if node.bl_idname=='CompositorNodeRLayers':node.scene=scene
    records=json.loads(scene['tileRecords']); removed=[]
    for record in list(records):
        c,r=record['cell']
        if spec['tiles'][r*spec['columns']+c]=='blocked':
            remove_tree(bpy.data.objects[record['name']]);records.remove(record);removed.append([c,r])
    portals=[]
    for pair in spec['teleportPairs']:
        for role,label in [('entrance','IN'),('exit','OUT')]:
            cell=pair[role];record=next(r for r in records if r['cell']==cell)
            remove_tree(bpy.data.objects[record['name']])
            variant=pair['color'].upper()+' '+label
            root=clone_tree(scene,roots[variant]);root.name=f'{stage}_{variant}_c{cell[0]}_r{cell[1]}'
            root.location=(cell[0]+.5-spec['columns']/2,spec['rows']/2-cell[1]-.5,0)
            root['tile']=cell;root['teleportRole']=role;root['teleportColor']=pair['color']
            record['name']=root.name;record['teleport']=variant
            portals.append({'cell':cell,'role':role,'color':pair['color'],'root':root.name})
    for ob in scene.objects:
        if ob.type=='FONT' and ob.data.body.startswith('3D 배치 시안'):
            ob.data=ob.data.copy();ob.data.body=f'보행 {spec["walkingEdges"]}칸 · 순간이동 {len(spec["teleportPairs"])}회 · 건설 {len(spec["buildCells"])}칸'
        if ob.type=='FONT' and ob.data.body=='기존 자산 재배치 · 게임 미적용':
            ob.data=ob.data.copy();ob.data.body='포탈 사이 지형 분리 · 설계 맵 미리보기'
    scene['tileRecords']=json.dumps(records);scene['teleportPairs']=json.dumps(spec['teleportPairs']);scene['mapSource']='../maps.json'
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get();bounds=[]
    for item in portals:
        root=bpy.data.objects[item['root']];inverse=root.matrix_world.inverted();minimum=[1e9]*3;maximum=[-1e9]*3
        for ob in root.children:
            if ob.type not in {'MESH','CURVE'}:continue
            evaluated=ob.evaluated_get(deps);mesh=bpy.data.meshes.new_from_object(evaluated,depsgraph=deps)
            for v in mesh.vertices:
                p=inverse@evaluated.matrix_world@v.co
                for i in range(3):minimum[i]=min(minimum[i],p[i]);maximum[i]=max(maximum[i],p[i])
            bpy.data.meshes.remove(mesh)
        assert max(abs(minimum[0]),abs(maximum[0]),abs(minimum[1]),abs(maximum[1]))<=.500001
        bounds.append({'cell':item['cell'],'min':minimum,'max':maximum})
    assert {tuple(r['cell']) for r in records if r['type']=='build'}==set(map(tuple,spec['buildCells']))
    assert len([r for r in records if r['type'] in ['path','spawn','core']])==spec['pathTiles']
    report['maps'].append({'stage':stage,'removedCells':removed,'tileRecords':records,'portals':portals,'bounds':bounds})
    output=HERE/f'chapter-{stage}.png'
    backup=OUT/f'before-chapter-{stage}.png'
    if output.exists() and not backup.exists():shutil.copy2(output,backup)
    scene.render.filepath=str(output)
    print('TELEPORT_MAP_RENDER_BEGIN',stage,flush=True)
    bpy.ops.render.render(write_still=True)
    print('TELEPORT_MAP_RENDER_DONE',stage,flush=True)
for scene in list(bpy.data.scenes):
    if scene.name.split(' ')[0] not in specs:bpy.data.scenes.remove(scene)
bpy.context.window.scene=next(s for s in bpy.data.scenes if s.name.startswith('1-7 '))
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
report['output_sha256']=sha(OUTPUT)
(OUT/'blender-placement.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('TELEPORT_MAPS_COMPLETE',flush=True)
