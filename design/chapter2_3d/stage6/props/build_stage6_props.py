"""Copy the edited upper props into a separately editable stage-6 arrangement.

Default creation requires a new destination. --export-only exports the edited
stage6-props.blend without recreating it; --refresh explicitly replaces it from
the common upper-prop source. Common source and GLB are never written.
"""
import argparse
import math
from pathlib import Path
import sys

import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT/'design/chapter2_3d/props/chapter2_props.blend'
EDITED = HERE/'stage6-props.blend'
TARGET = ROOT/'assets/images/stage1_3d/environment/chapter2_stage6_props.glb'


def export():
    root = bpy.data.objects['stage6_props']
    temporary = []
    for actor in root.children:
        groups = {}
        for obj in actor.children_recursive:
            if obj.type != 'MESH':
                continue
            material = obj.data.materials[0].name
            if '_mineral_layer_' in obj.name:
                key = obj.name.split('_mineral_layer_')[0]+'_inner'
            elif material.startswith('ch2_crystal_'):
                key = obj.name
            else:
                key = material
            copy = obj.copy()
            copy.data = obj.data.copy()
            bpy.context.collection.objects.link(copy)
            groups.setdefault(key,[]).append(copy)
        for key,objects in groups.items():
            bpy.ops.object.select_all(action='DESELECT')
            for obj in objects:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = objects[0]
            bpy.ops.object.join()
            joined = bpy.context.object
            joined.name = actor.name+'__'+key
            temporary.append(joined)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for actor in root.children:
        actor.select_set(True)
    for obj in temporary:
        obj.select_set(True)
    TARGET.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format='GLB',use_selection=True,
        export_apply=True,export_yup=True,export_materials='EXPORT',
        export_vertex_color='NAME',export_vertex_color_name='Color',
        export_all_vertex_colors=False,export_extras=True,
        export_cameras=False,export_lights=False)
    for obj in temporary:
        bpy.data.objects.remove(obj,do_unlink=True)
    print('STAGE6_PROPS_EXPORTED',TARGET,flush=True)


def create():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    roots = [bpy.data.objects[n] for n in ('rune_pillar','crystal_cluster','void_fissure')]
    keep = set(roots)
    for root in roots:
        keep.update(obj for obj in root.children_recursive if not obj.name.startswith('floating_ground'))
    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj,do_unlink=True)
    pillar,crystal,fissure = roots
    right = crystal.copy()
    bpy.context.collection.objects.link(right)
    right.name = 'crystal_right'
    mapping = {crystal:right}
    for obj in crystal.children_recursive:
        copy = obj.copy()
        # Linked immutable mesh data preserves the exact edited upper geometry.
        bpy.context.collection.objects.link(copy)
        mapping[obj] = copy
    for original,copy in mapping.items():
        if original != crystal:
            copy.parent = mapping.get(original.parent,right)
    crystal.name = 'crystal_lower_left'
    pillar.name = 'pillar'
    fissure.name = 'void_fissure'
    root = bpy.data.objects.new('stage6_props',None)
    bpy.context.collection.objects.link(root)
    anchors = [(pillar,(-4.48,4.35,0),1.10,-14),
               (crystal,(-1.65,-3.50,0),1.20,17),
               (right,(3.45,-2.35,0),1.20,-21),
               (fissure,(3.40,2.48,-.19),1.0,12)]
    for actor,position,scale,angle in anchors:
        actor.parent = root
        actor.location = position
        actor.scale = (scale,scale,scale)
        actor.rotation_euler = (0,0,math.radians(angle))
        actor['stage6_anchor'] = list(position)
        actor['independent_floating_ground'] = False
        actor.hide_render = False
        for obj in actor.children_recursive:
            obj.hide_render = False
            obj.hide_set(False)
    root['coordinate_contract'] = 'Blender XY centered 8x10 battlefield; surface Z=0; glTF Y-up'
    root['terrain_owner'] = 'stage6 integral battlefield; no independent prop ground'
    bpy.context.scene.name = 'Stage 6 Placed Upper Props'
    bpy.context.scene.camera = None
    export()
    bpy.ops.wm.save_as_mainfile(filepath=str(EDITED))
    print('STAGE6_PROPS_SOURCE',EDITED,flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export-only',action='store_true')
    parser.add_argument('--refresh',action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.export_only:
        bpy.ops.wm.open_mainfile(filepath=str(EDITED))
        export()
    elif EDITED.exists() and not args.refresh:
        parser.error('Preserve edited arrangement: use --export-only, or explicit --refresh.')
    else:
        create()
