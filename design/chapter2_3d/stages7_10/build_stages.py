"""Reuse approved stage-6 geology and upper props for stages 7–10.

Blender --background --python build_stages.py -- [--stage 7] [--export-only]
Edited stageN.blend files are preserved unless --regenerate is explicit.
"""
import argparse
import ast
import math
import random
import re
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUTPUT = ROOT / 'assets/images/stage1_3d/environment'
RNG = random.Random(6026)
# Load only the approved construction helpers, never its stage-6 build entrypoint.
source = ROOT/'design/chapter2_3d/stage6/terrain/build_geology.py'
module = ast.parse(source.read_text())
helpers = [n for n in module.body if isinstance(n, ast.FunctionDef) and n.name in
           ('uv_planar','rock','rectangle','clip','split_stone')]
exec(compile(ast.Module(body=helpers,type_ignores=[]),str(source),'exec'))


def definition(stage):
    text=(ROOT/'lib/data/definitions/game_stage_maps.dart').read_text()
    body=re.search(r'const chapterTwoStage%dMap = MapDefinition\((.*?)\n\);'%stage,text,re.S).group(1)
    return dict(columns=int(re.search(r'columns: (\d+)',body)[1]),
                rows=int(re.search(r'rows: (\d+)',body)[1]),
                tileTypes=re.findall(r'TileType\.(\w+)',body.split('path:')[0]))


def support(root,props):
    bpy.context.view_layer.update()
    points=[tuple(o.matrix_world@v.co) for r in (root,props) for o in r.children_recursive
            if o.type=='MESH' for v in o.data.vertices]
    result=set()
    for step in range(24):
        angle=step*math.tau/24
        for dz in (-2,-1,0,1,2):
            p=max(points,key=lambda p:p[0]*math.cos(angle)+p[1]*math.sin(angle)+p[2]*dz)
            result.add(tuple(round(c,5) for c in (p[0],p[2],-p[1])))
    root['cameraPointsGodot']=[list(p) for p in sorted(result)]
    colors=[(.24,.68,1),(.3,.65,1),(.36,.57,1),(.58,.23,1)]
    root['accentLights']=[dict(positionGodot=[a.location.x,.55,-a.location.y],
        color=list(colors[i]),energy=.85,range=1.6) for i,a in enumerate(props.children)]


def export(stage):
    root=bpy.data.objects['stage%d_geology'%stage]
    props=bpy.data.objects['stage%d_props'%stage]
    support(root,props)
    copies=[]
    for child in root.children_recursive:
        if child.type!='MESH':continue
        copy=child.copy();copy.data=child.data.copy();bpy.context.collection.objects.link(copy);copies.append(copy)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in copies:obj.select_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
    merged=bpy.context.object;merged.name='stage%d_continuous_rock_strata'%stage;merged.parent=root
    root.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/('chapter2_stage%d_geology.glb'%stage)),
        export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True,
        export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,
        export_cameras=False,export_lights=False)
    bpy.data.objects.remove(merged,do_unlink=True)
    # Preserve stage-6 crystal COLOR_0 and inner-fragment batching verbatim.
    prop_source=ROOT/'design/chapter2_3d/stage6/props/build_stage6_props.py'
    module=ast.parse(prop_source.read_text())
    node=next(n for n in module.body if isinstance(n,ast.FunctionDef) and n.name=='export')
    class Names(ast.NodeTransformer):
        def visit_Constant(self,node):
            if node.value=='stage6_props':node.value='stage%d_props'%stage
            return node
    node=Names().visit(node)
    scope=dict(bpy=bpy,TARGET=OUTPUT/('chapter2_stage%d_props.glb'%stage))
    exec(compile(ast.fix_missing_locations(ast.Module(body=[node],type_ignores=[])),str(prop_source),'exec'),scope)
    scope['export']()


def build(stage):
    global RNG
    RNG=random.Random(6026+stage)
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'design/chapter2_3d/stage6/props/stage6-props.blend'))
    props=bpy.data.objects['stage6_props'];props.name='stage%d_props'%stage
    keep={props,*props.children_recursive}
    for obj in list(bpy.data.objects):
        if obj not in keep:bpy.data.objects.remove(obj,do_unlink=True)
    data=definition(stage);cols,rows=data['columns'],data['rows']
    occupied={(i%cols,i//cols) for i,t in enumerate(data['tileTypes']) if t!='blocked'}
    with bpy.data.libraries.load(str(ROOT/'design/chapter2_3d/tiles/chapter2-tiles.blend'),link=False) as (src,dst):
        dst.materials=['chapter2_side','chapter2_build']
    side=bpy.data.materials['chapter2_side'];topmat=bpy.data.materials['chapter2_build']
    root=bpy.data.objects.new('stage%d_geology'%stage,None);bpy.context.collection.objects.link(root)
    for key,value in data.items():root[key]=value
    root['artReference']='Approved stage 6 darker facets and upper props'
    root['purpose']='Continuous substrate and exterior prop ledges; playable cells unchanged'
    coast=[];candidates=[]
    for col,row in sorted(occupied):
        x,y=col-cols/2,rows/2-1-row
        rock('substrate_%d_%d'%(col,row),rectangle(x-.025,y-.025,x+1.025,y+1.025),
             RNG.uniform(-1.28,-1.04),-.39,side,root,.93,bevel=0)
        for dx,dy,a,b in [(-1,0,(x,y+1),(x,y)),(1,0,(x+1,y),(x+1,y+1)),
                          (0,-1,(x+1,y+1),(x,y+1)),(0,1,(x,y),(x+1,y))]:
            if (col+dx,row+dy) in occupied:continue
            a,b,out=Vector(a),Vector(b),Vector((dx,-dy));coast.append((a,b,out))
            exterior=not any((c-col)*dx+(r-row)*dy>0 and (r==row if dx else c==col) for c,r in occupied)
            if exterior:candidates.append(((a+b)/2,out))
    for e,(a,b,out) in enumerate(coast):
        tangent=(b-a).normalized();cursor=0.;n=0
        while cursor<.99:
            length=min(1-cursor,RNG.uniform(.28,.49));center=a+tangent*(cursor+length*.5)
            width=RNG.uniform(.13,.25)
            pts=[center-tangent*length*.55-out*.08,center+tangent*length*.55-out*.08,
                 center+tangent*length*.55+out*width,center-tangent*length*.55+out*width]
            poly=[tuple(p) for p in pts];bottom=RNG.uniform(-1.75,-1.03)
            rock('coast_%03d_%d'%(e,n),poly,bottom,RNG.uniform(-.25,-.10),side,root,
                 RNG.uniform(.6,.95),tuple(-out*.05))
            if n%2==0:
                shift=-tangent*.10-out*.05
                rock('lower_fin_%03d_%d'%(e,n),[(p[0]+shift.x,p[1]+shift.y) for p in poly],
                     bottom-RNG.uniform(.08,.28),-.66,side,root,.63,tuple(-out*.08))
            cursor+=length;n+=1
    # These three approved placements stay fixed when relocating the pillar.
    fixed={7:[(-4,-3.055),(4,-3.055),(4,2.155)],
           8:[(-3.555,-2.5),(3.555,-3.5),(1.5,2.655)],
           9:[(-4.055,-3.5),(2.055,-3.5),(4.155,1.5)],
           10:[(-5.055,-4),(5.055,-4),(5.155,2)]}[stage]
    pillar_targets={7:(0,rows/2),8:(-cols/2,0),
                    9:(-cols/2,rows*.3),10:(cols/2,-1)}
    targets=[Vector(pillar_targets[stage])]+[Vector(p) for p in fixed]
    endpoints=[Vector((i%cols-cols/2+.5,rows/2-.5-i//cols))
               for i,t in enumerate(data['tileTypes']) if t in ('spawn','core')]
    actors=[bpy.data.objects[n] for n in ('pillar','crystal_lower_left','crystal_right','void_fissure')]
    used=[Vector(p) for p in fixed]
    for index,(actor,target) in enumerate(zip(actors,targets)):
        half=.58 if index==3 else .48;distance=half+.075
        ranked=[]
        for edge,out in candidates:
            center=edge+out*distance
            if any(center.x+half>c-cols/2 and center.x-half<c-cols/2+1 and
                   center.y+half>rows/2-1-r and center.y-half<rows/2-r for c,r in occupied):continue
            if index==0 and any((center-p).length<2.5 for p in endpoints):continue
            gap=min(((center-p).length for p in used),default=100)
            spacing=max(0,2.3-gap)*20 if index==0 else 0
            ranked.append(((center-target).length+spacing,edge,out,center))
        _,edge,out,center=min(ranked,key=lambda a:a[0]);used.append(center)
        actor.location=(center.x,center.y,-.19 if index==3 else 0)
        if 'stage6_anchor' in actor:del actor['stage6_anchor']
        actor['stage_anchor']=list(actor.location)
        tangent=Vector((-out.y,out.x));end=distance+.53;wide=.70
        boundary=[tuple(edge-tangent*wide-out*.13),tuple(edge+tangent*wide-out*.13),
                  tuple(edge+tangent*(wide+.08)+out*(end*.7)),tuple(edge+tangent*.48+out*end),
                  tuple(edge-tangent*.48+out*end),tuple(edge-tangent*(wide+.08)+out*(end*.7))]
        seeds=[tuple(edge+out*.22-tangent*.25),tuple(center+tangent*.3),tuple(center-tangent*.3)]
        angle=actor.rotation_euler.z;nx,ny=math.cos(angle),math.sin(angle);slit=center.x*nx+center.y*ny
        domains=[boundary] if index!=3 else [clip(boundary,nx,ny,slit-.075),clip(boundary,-nx,-ny,-slit-.075)]
        z=-.34 if index==3 else -.055
        for di,domain in enumerate(domains):
            for pi,part in enumerate(split_stone(domain,seeds)):
                rock('ledge_%d_%d_%d'%(index,di,pi),part,RNG.uniform(-1.6,-1.2),z,side,root,.8)
                cx=sum(x for x,y in part)/len(part);cy=sum(y for x,y in part)/len(part)
                inset=[(cx+(x-cx)*.975,cy+(y-cy)*.975) for x,y in part]
                rock('ledge_cap_%d_%d_%d'%(index,di,pi),inset,z-.17,z+.012,topmat,root,.98)
    # Small detached fragments use the same flat fractured rock geometry as stage 6.
    # Sample all directions around the coast, within the existing prop envelope.
    fragment_candidates=[]
    for edge,out in candidates:
        center=edge+out*RNG.uniform(.58,.70)
        size=RNG.uniform(.10,.18)
        clearance=min(math.hypot(center.x-max(c-cols/2,min(center.x,c-cols/2+1)),
                                 center.y-max(rows/2-1-r,min(center.y,rows/2-r))) for c,r in occupied)
        if clearance<size+.30 or any((center-p).length<1.4 for p in used):continue
        fragment_candidates.append((math.atan2(center.y,center.x),center,size))
    fragments=[]
    for sector in range(8):
        target=-math.pi+(sector+.5)*math.tau/8
        available=[entry for entry in fragment_candidates
                   if all((entry[1]-p).length>1.15 for p in fragments)]
        if not available:break
        _,center,size=min(available,key=lambda entry:abs(math.atan2(math.sin(entry[0]-target),math.cos(entry[0]-target))))
        fragments.append(center)
        x,y=center;z=RNG.uniform(-1.5,-.5)
        poly=[(x-size,y-size*.40),(x-size*.15,y-size*.77),
              (x+size*.93,y-size*.35),(x+size*.68,y+size*.58),
              (x-size*.46,y+size*.72)]
        rock('detached_fragment_%02d'%sector,poly,z-size*1.7,z+size*.7,
             side,root,.68,(.035,-.02),bevel=.003)
    print('FRAGMENTS',stage,len(fragments),flush=True)
    props['coordinate_contract']='Blender XY centered %dx%d battlefield; surface Z=0; glTF Y-up'%(cols,rows)
    props['terrain_owner']='stage%d continuous geology'%stage
    bpy.context.scene.name='Stage %d editable environment'%stage
    support(root,props)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/('stage%d.blend'%stage)))
    export(stage)
    print('STAGE_COMPLETE',stage,[(a.name,list(a.location)) for a in actors],flush=True)


parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stage',type=int,choices=range(7,11))
parser.add_argument('--export-only',action='store_true')
parser.add_argument('--regenerate',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUTPUT.mkdir(parents=True,exist_ok=True)
for stage in ([args.stage] if args.stage else range(7,11)):
    source=HERE/('stage%d.blend'%stage)
    if args.export_only:
        bpy.ops.wm.open_mainfile(filepath=str(source));export(stage)
    elif source.exists() and not args.regenerate:
        parser.error('%s exists; use --export-only or explicit --regenerate'%source.name)
    else:build(stage)
