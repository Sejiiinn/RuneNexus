"""Reuse saved approved Blender clusters; preserve masters and stage 1 assembly.
Run in a separate Blender background process; writes four editable stage scenes.
"""
import bpy, json, math, shutil, hashlib, struct, re
from pathlib import Path
from mathutils import Vector, Matrix
if not bpy.app.background:
    raise RuntimeError("Use a separate --background Blender process to preserve the open workspace")
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
import sys
sys.path.insert(0,str(HERE))
from export_dressing import export_stage
SOURCE = ROOT / 'design/stage1_3d/environment_dressing/environment-dressing.blend'
MANIFEST = json.loads((SOURCE.parent / 'placement_manifest.json').read_text())
# A copied source can be appended even when the original is open in Blender.
COPY = Path('/tmp/rune-dressing-source.blend')
shutil.copy2(SOURCE, COPY)
with bpy.data.libraries.load(str(COPY), link=False) as (src, dst):
    dst.objects = [p['name'] for p in MANIFEST['placements']]
prototypes = dict(zip([p['name'] for p in MANIFEST['placements']], dst.objects))
EDGE = {'N':0, 'W':math.pi/2, 'S':math.pi, 'E':-math.pi/2}
FOCALS = [(3,0,'N'), (5,1,'E'), (7,4,'E'), (7,7,'E'), (0,7,'W'), (0,9,'W')]
# Regions deliberately alternate tall fern, broadleaf/flower and quieter low stone.
LAYOUT = {
 2: [(2,2,'N',0),(8,2,'N',2),(5,3,'E',4),(2,4,'S',3),(6,6,'S',5)],
 3: [(1,1,'N',1),(5,2,'E',0),(0,4,'W',4),(6,5,'S',2),(4,7,'S',5)],
 4: [(3,2,'N',0),(7,2,'E',2),(4,5,'W',4),(6,6,'W',1),(4,9,'S',5)],
 5: [(6,0,'N',2),(2,1,'W',0),(5,3,'E',1),(1,6,'W',4),(6,7,'S',5)],
}
report = {'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'stages':[]}
source_text = (ROOT/'lib/data/definitions/game_stage_maps.dart').read_text()
old_scene = bpy.context.window.scene
for stage, map_name in [(2,'gameStage2Map'),(3,'stage3Map'),(4,'stage4Map'),(5,'stage5Map')]:
    body = re.search(rf'const {map_name} = MapDefinition\((.*?)\n\);',source_text,re.S).group(1)
    cols = int(re.search(r'columns:\s*(\d+)',body).group(1)); rows=int(re.search(r'rows:\s*(\d+)',body).group(1))
    tiles=re.findall(r'TileType\.(\w+)',body.split('path:')[0])
    slots={i:n for n,i in enumerate(i for i,t in enumerate(tiles) if t=='build')}
    scene=bpy.data.scenes.new(f'Chapter1 Stage {stage} Environment')
    root=bpy.data.objects.new(f'chapter_stage{stage}_dressing',None); scene.collection.objects.link(root)
    root['columns']=cols; root['rows']=rows; root['tileTypes']=tiles; root['stageNumber']=stage
    root['sourceAssemblySha256']=report['sourceSha256']
    placed=[]; omitted=[]
    def place(p,c,r,edge,source_edge):
        assert tiles[r*cols+c]=='build'
        normal={'N':(0,-1),'E':(1,0),'S':(0,1),'W':(-1,0)}[edge]
        nc,nr=c+normal[0],r+normal[1]
        exposed=not(0<=nc<cols and 0<=nr<rows) or tiles[nr*cols+nc]=='blocked'
        if not p['removableOnBuild'] and not exposed: return
        sc,sr=p['tile']; old=Vector((sc-3.5,4.5-sr,0)); center=Vector((c+.5-cols/2,rows/2-r-.5,0))
        rot=Matrix.Rotation(EDGE[edge]-EDGE[source_edge],4,'Z')
        proto=prototypes[p['name']]
        vertices=[center+rot.to_3x3()@(proto.matrix_world@v.co-old) for v in proto.data.vertices]
        margin=.022*max((uv.uv.x for uv in proto.data.uv_layers['Wind'].data),default=0)**2
        for v in vertices:
            if v.z<=.003: continue
            for dx,dy in ((0,0),(-margin,-margin),(-margin,margin),(margin,-margin),(margin,margin)):
                cc,rr=math.floor(v.x+dx+cols/2), math.floor(rows/2-v.y-dy)
                if 0<=cc<cols and 0<=rr<rows:
                    tile=tiles[rr*cols+cc]
                    if tile in ('path','spawn','core'):
                        omitted.append([p['name'],c,r,'path clearance']); return
                    if tile=='build' and not(p['removableOnBuild'] and (cc,rr)==(c,r)):
                        local=v-Vector((cc+.5-cols/2,rows/2-rr-.5,0))
                        if abs(local.x)<.35+margin and abs(local.y)<.35+margin:
                            omitted.append([p['name'],c,r,'build clearance']); return
        obj=proto.copy(); obj.data=proto.data.copy(); obj.animation_data_clear()
        if obj.data.shape_keys: obj.shape_key_clear()
        scene.collection.objects.link(obj); obj.parent=root; obj.matrix_world=Matrix.Identity(4)
        obj.name=f's{stage}_{len(placed):02}_{p["sourceAssetId"]}_c{c}_r{r}'
        for v,co in zip(obj.data.vertices,vertices): v.co=co
        obj['tile']=[c,r]; obj['sourcePlacement']=p['name']; obj['buildSlot']=slots[r*cols+c]
        for uv in obj.data.uv_layers['Occupancy'].data: uv.uv=(slots[r*cols+c],0 if p['removableOnBuild'] else 1)
        for uv in obj.data.uv_layers['Wind'].data: uv.uv.y += stage*.37+len(placed)*.13
        placed.append({'name':obj.name,'asset':p['sourceAssetId'],'tile':[c,r],'edge':edge,'removable':p['removableOnBuild']})
    used=set()
    for c,r,edge,idx in LAYOUT[stage]:
        sc,sr,se=FOCALS[idx]; used.add((c,r))
        for p in MANIFEST['placements']:
            if p['region']==f'focal_{sc}_{sr}' or (p['tile']==[sc,sr] and p['region']=='outer_wall' and p['edge']==se):
                place(p,c,r,edge,se)
    connectors=[p for p in MANIFEST['placements'] if p['region']=='connector']
    for n,i in enumerate(slots):
        c,r=i%cols,i//cols
        if (c,r) not in used and n%2==0:
            p=connectors[(n+stage)%len(connectors)]; place(p,c,r,p['edge'],p['edge'])
    scene.use_fake_user=True
    triangle_count=export_stage(scene,stage)
    target=ROOT/f'assets/images/stage1_3d/environment/dressing_stage{stage}.glb'
    report['stages'].append({'stage':stage,'objects':len(placed),'triangles':triangle_count,'glbBytes':target.stat().st_size,'placements':placed,'omitted':omitted})
bpy.context.window.scene=bpy.data.scenes.get('Chapter1 Stage 2 Environment')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'chapter1-dressing.blend'),copy=True)
(HERE/'placement_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==report['sourceSha256']
print('CHAPTER_DRESSING',json.dumps([{k:v for k,v in s.items() if k not in ('placements','omitted')} | {'omitted':len(s['omitted'])} for s in report['stages']]))
