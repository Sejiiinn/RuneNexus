"""Shared hidden-geometry-pruned tiles; original tile source remains unchanged.

Mask uses ORIGINAL tile-local W=1,E=2,N=4,S=8. Blender N=+Y; Godot N=-Z.
A cell still rotates index%4 quarter turns about Godot +Y / Blender +Z.
Only masks required by maps 6–10 are exported, sharing materials and textures.
"""
import argparse
import json
import math
import re
import sys
from pathlib import Path
import bpy
from mathutils import Matrix
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
from hidden_geometry import prune_hidden_faces
SOURCE=HERE/'chapter2-tiles-optimized.blend'
TARGET=ROOT/'assets/images/stage1_3d/environment/chapter2_tiles_optimized.glb'
# Blender XY local outward vectors, corresponding Godot cardinal directions.
DIRECTIONS=[(1,-1,0),(2,1,0),(4,0,1),(8,0,-1)]


def definitions():
    text=(ROOT/'lib/data/definitions/game_stage_maps.dart').read_text()
    result={}
    for stage in range(6,11):
        body=re.search(r'const chapterTwoStage%dMap = MapDefinition\((.*?)\n\);'%stage,text,re.S)[1]
        cols=int(re.search(r'columns: (\d+)',body)[1]);rows=int(re.search(r'rows: (\d+)',body)[1])
        tiles=re.findall(r'TileType\.(\w+)',body.split('path:')[0])
        occupied={(i%cols,i//cols) for i,t in enumerate(tiles) if t!='blocked'}
        placements=[]
        for i,kind in enumerate(tiles):
            if kind=='blocked':continue
            angle=i%4*math.pi/2;mask=0
            for bit,x,y in DIRECTIONS:
                # Rotate a LOCAL outward direction into world XY, then invert Y for row.
                dx=round(x*math.cos(angle)-y*math.sin(angle))
                dy=-round(x*math.sin(angle)+y*math.cos(angle))
                if (i%cols+dx,i//cols+dy) in occupied:mask|=bit
            placements.append(dict(index=i,kind='build' if kind=='build' else 'path',mask=mask,quarterTurns=i%4))
        result[stage]=placements
    return result


def tris(mesh):return sum(len(p.vertices)-2 for p in mesh.polygons)


def export():
    root=bpy.data.objects['chapter2_tiles_optimized']
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in root.children_recursive:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format='GLB',use_selection=True,
        export_yup=True,export_materials='EXPORT',export_extras=True,export_animations=False,
        export_cameras=False,export_lights=False)
    variants={r.name:dict(triangles=sum(tris(o.data) for o in r.children_recursive if o.type=='MESH'),
                         surfaces=2) for r in root.children}
    stages={}
    for stage,placements in definitions().items():
        active={(p['kind'],p['mask']) for p in placements}
        stages[stage]=dict(instances=len(placements),variants=len(active),expectedBaseDraws=2*len(active),
            instanceTriangles=sum(variants['%s_tile_mask_%d'%(p['kind'],p['mask'])]['triangles'] for p in placements))
    report=dict(bytes=TARGET.stat().st_size,variantCount=len(variants),
        uniqueTriangles=sum(v['triangles'] for v in variants.values()),variants=variants,stages=stages,
        maskBitOrder='LOCAL W=1 E=2 N=4 S=8; Blender N=+Y, Godot N=-Z; rotate local direction by cell index%4 before querying neighbor')
    (HERE/'tile_variants_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VARIANTS_COMPLETE',json.dumps({k:v for k,v in report.items() if k!='variants'}),flush=True)


def build():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'design/chapter2_3d/tiles/chapter2-tiles.blend'))
    sources={kind:bpy.data.objects[kind+'_tile'] for kind in ('path','build')}
    keep=set(sources.values())
    for obj in sources.values():keep.update(obj.children_recursive)
    for obj in list(bpy.data.objects):
        if obj not in keep:bpy.data.objects.remove(obj,do_unlink=True)
    root=bpy.data.objects.new('chapter2_tiles_optimized',None);bpy.context.collection.objects.link(root)
    root['maskBitOrder']='W=1,E=2,N=4,S=8 in unrotated tile local coordinates'
    root['directionCoordinates']='Blender W=-X,E=+X,N=+Y,S=-Y; Godot W=-X,E=+X,N=-Z,S=+Z'
    root['rotationContract']='Rotate each cell index%4 quarter turns about Godot +Y / Blender +Z'
    root['source']='design/chapter2_3d/tiles/chapter2-tiles.blend (unchanged)'
    required=sorted({(p['kind'],p['mask']) for placements in definitions().values() for p in placements})
    for kind,mask in required:
        source=sources[kind]
        group=bpy.data.objects.new('%s_tile_mask_%d'%(kind,mask),None);bpy.context.collection.objects.link(group);group.parent=root
        group['neighborMask']=mask;group['tileKind']=kind;group['tileFootprint']=[1.,1.];group['surfaceHeightGodot']=0.
        pieces=[]
        for original in source.children_recursive:
            if original.type!='MESH':continue
            side=re.match(r'side_([012])_([0-3])_[0-3](?:\.|$)',original.name)
            # Authored side0=S, side1=E, side2=N, side3=W.
            if side and int(side[1])<2 and mask & (8,2,4,1)[int(side[2])]:continue
            local=source.matrix_world.inverted()@original.matrix_world
            copy=original.copy();copy.data=original.data.copy();copy.parent=None
            bpy.context.collection.objects.link(copy);copy.hide_render=False;copy.hide_set(False)
            prune_hidden_faces(original,copy,local)
            copy.matrix_world=local;pieces.append(copy)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in pieces:obj.select_set(True)
        bpy.context.view_layer.objects.active=pieces[0];bpy.ops.object.join()
        merged=bpy.context.object;merged.name=group.name+'_surface';merged.parent=group
        # Ensure mesh transform is identity for parent-side MultiMesh extraction.
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for obj in list(keep):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.context.scene.name='Shared chapter 2 optimized local-mask tile variants'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    export()


parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--export-only',action='store_true');parser.add_argument('--regenerate',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
if args.export_only:bpy.ops.wm.open_mainfile(filepath=str(SOURCE));export()
elif SOURCE.exists() and not args.regenerate:parser.error('Use --export-only to preserve edits, or explicit --regenerate')
else:build()
