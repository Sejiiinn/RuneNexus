"""Map-specific paving copies: remove only concealed foundation geometry.

Original tile blend and GLB are read-only. All tops, carving, cracks, UVs,
materials, the upper masonry band and exterior masonry remain unchanged.
Blender --background --python build_paving.py -- [--stage 6] [--export-only]
"""
import argparse
import json
import math
import re
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Matrix
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
TILES=ROOT/'design/chapter2_3d/tiles/chapter2-tiles.blend'
OUTPUT=HERE/'rejected-map-batches'
OUTPUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(HERE))
from hidden_geometry import prune_hidden_faces


def definition(stage):
    body=re.search(r'const chapterTwoStage%dMap = MapDefinition\((.*?)\n\);'%stage,
        (ROOT/'lib/data/definitions/game_stage_maps.dart').read_text(),re.S)[1]
    return dict(columns=int(re.search(r'columns: (\d+)',body)[1]),
        rows=int(re.search(r'rows: (\d+)',body)[1]),
        tileTypes=re.findall(r'TileType\.(\w+)',body.split('path:')[0]))


def triangles(mesh):
    return sum(len(p.vertices)-2 for p in mesh.polygons)


def export(stage):
    root=bpy.data.objects['stage%d_paving'%stage]
    copies=[]
    for obj in root.children_recursive:
        if obj.type!='MESH':continue
        copy=obj.copy();copy.data=obj.data.copy();bpy.context.collection.objects.link(copy);copies.append(copy)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in copies:obj.select_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
    merged=bpy.context.object;merged.name='stage%d_paving_surface'%stage;merged.parent=root
    root.select_set(True)
    target=OUTPUT/('chapter2_stage%d_paving.glb'%stage)
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
        export_yup=True,export_materials='EXPORT',export_extras=True,export_animations=False,
        export_cameras=False,export_lights=False)
    report=dict(stage=stage,beforeTriangles=int(root['beforeTriangles']),
        afterTriangles=triangles(merged.data),bytes=target.stat().st_size,
        materials=len({p.material_index for p in merged.data.polygons}),removedLowerBandObjects=int(root['removedLowerBandObjects']),
        removedHiddenFaceTriangles=int(root['removedHiddenFaceTriangles']))
    report['reductionPercent']=round(100*(1-report['afterTriangles']/report['beforeTriangles']),2)
    bpy.data.objects.remove(merged,do_unlink=True)
    print('PAVING_COMPLETE',json.dumps(report),flush=True)
    return report


def build(stage):
    bpy.ops.wm.open_mainfile(filepath=str(TILES))
    sources={name:bpy.data.objects[name] for name in ('path_tile','build_tile')}
    keep=set(sources.values())
    for obj in sources.values():keep.update(obj.children_recursive)
    for obj in list(bpy.data.objects):
        if obj not in keep:bpy.data.objects.remove(obj,do_unlink=True)
    data=definition(stage);cols,rows=data['columns'],data['rows']
    occupied={(i%cols,i//cols) for i,t in enumerate(data['tileTypes']) if t!='blocked'}
    root=bpy.data.objects.new('stage%d_paving'%stage,None);bpy.context.collection.objects.link(root)
    for key,value in data.items():root[key]=value
    root['sourceTileBlend']='design/chapter2_3d/tiles/chapter2-tiles.blend'
    root['rotationContract']='index % 4 * PI/2, Blender +Z corresponds to Godot +Y'
    root['preserved']='All paving, engraving, borders, corners, upper masonry, exposed lower masonry, original UV and materials'
    baseline=0;removed_objects=0;removed_faces=0
    for index,kind in enumerate(data['tileTypes']):
        if kind=='blocked':continue
        source=sources['build_tile' if kind=='build' else 'path_tile']
        col,row=index%cols,index//cols
        angle=index%4*math.pi/2
        transform=Matrix.Translation((col-cols/2+.5,rows/2-.5-row,0))@Matrix.Rotation(angle,4,'Z')
        pieces=[]
        for original in source.children_recursive:
            if original.type!='MESH':continue
            baseline+=triangles(original.data)
            side=re.match(r'side_([012])_([0-3])_[0-3](?:\.|$)',original.name)
            if side and int(side[1])<2:
                direction=int(side[2])*math.pi/2+angle
                neighbor=(col+round(math.sin(direction)),row+round(math.cos(direction)))
                if neighbor in occupied:
                    removed_objects+=1;continue
            local=source.matrix_world.inverted()@original.matrix_world
            copy=original.copy();copy.data=original.data.copy();copy.parent=None
            bpy.context.collection.objects.link(copy)
            copy.hide_render=False;copy.hide_set(False)
            removed_faces+=prune_hidden_faces(original,copy,local)
            copy.matrix_world=transform@local
            pieces.append(copy)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in pieces:obj.select_set(True)
        bpy.context.view_layer.objects.active=pieces[0];bpy.ops.object.join()
        tile=bpy.context.object;tile.name='tile_%03d_%s'%(index,kind);tile.parent=root
        tile['mapIndex']=index;tile['tileType']=kind;tile['quarterTurns']=index%4
    for obj in list(keep):
        if obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
    root['beforeTriangles']=baseline
    root['removedLowerBandObjects']=removed_objects
    root['removedHiddenFaceTriangles']=removed_faces
    bpy.context.view_layer.update()
    bpy.context.scene.name='Stage %d editable optimized paving'%stage
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/('stage%d-paving.blend'%stage)))
    return export(stage)


parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stage',type=int,choices=range(6,11))
parser.add_argument('--export-only',action='store_true')
parser.add_argument('--regenerate',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
reports=[]
for stage in ([args.stage] if args.stage else range(6,11)):
    source=HERE/('stage%d-paving.blend'%stage)
    if args.export_only:
        bpy.ops.wm.open_mainfile(filepath=str(source));reports.append(export(stage))
    elif source.exists() and not args.regenerate:parser.error('Use --export-only to preserve edited '+source.name)
    else:reports.append(build(stage))
(HERE/'paving_report.json').write_text(json.dumps(reports,indent=2)+'\n')
