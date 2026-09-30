"""Extend shared chapter-two paving coverage using the established masked export.
Preserves both original editable tile files; writes a separate expansion derivative.
"""
import ast, json, math, struct
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0,str(ROOT/'scripts'))
from content_design_views import load_design_view
if not bpy.app.background:raise RuntimeError('Use independent background Blender')
path=ROOT/'design/chapter2_3d/optimization/build_tile_variants.py'
module=ast.parse(path.read_text());nodes=[]
for node in module.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='parser' for t in node.targets):break
    nodes.append(node)
ns={'__file__':str(path)};exec(compile(ast.Module(body=nodes,type_ignores=[]),str(path),'exec'),ns)
ns['SOURCE']=ROOT/'design/stage_expansion_runtime/chapter2-expansion-tile-variants.blend'
ns['TARGET']=ROOT/'assets/images/stage1_3d/environment/chapter2_tiles_expansion.glb'
original_glb=(ROOT/'assets/images/stage1_3d/environment/chapter2_tiles_optimized.glb').read_bytes()
original_document=json.loads(original_glb[20:20+struct.unpack_from("<I",original_glb,12)[0]])
existing_names={n.get("name", "") for n in original_document["nodes"]}
def definitions():
    stages={}
    for spec in load_design_view(ROOT/'design/chapter2_map_expansion/maps.json')['maps']:
        cols,rows=spec['columns'],spec['rows'];tiles=spec['tiles'];occupied={(i%cols,i//cols) for i,t in enumerate(tiles) if t!='blocked'};placements=[]
        for i,kind in enumerate(tiles):
            if kind=='blocked':continue
            angle=i%4*math.pi/2;mask=0
            for bit,x,y in ns['DIRECTIONS']:
                dx=round(x*math.cos(angle)-y*math.sin(angle));dy=-round(x*math.sin(angle)+y*math.cos(angle))
                if (i%cols+dx,i//cols+dy) in occupied:mask|=bit
            tile_kind='build' if kind=='build' else 'path'
            if f"{tile_kind}_tile_mask_{mask}" not in existing_names:
                placements.append(dict(index=i,kind=tile_kind,mask=mask,quarterTurns=i%4))
        stages[15+int(spec['chapterStage'].split('-')[1])]=placements
    return stages
ns['definitions']=definitions
# The reused exporter writes only its report beside its own configured HERE.
ns['HERE']=ROOT/'build/stage-expansion-runtime'
ns['build']()
