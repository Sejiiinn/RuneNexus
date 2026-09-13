"""Add irregular cliff geology to the edited props source without recreating props.

Blender --background --python this_file.py
Only floating_ground* meshes are replaced on repeat runs. The existing fissure
depth plane is lowered into the new chasm; upper props and materials are preserved.
"""
import ast
import hashlib
import json
import math
import random
import shutil
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NAMES = ('rune_pillar', 'crystal_cluster', 'void_fissure')


def clipped(poly, a, b, c):
    out = []
    for p, q in zip(poly, poly[1:] + poly[:1]):
        dp, dq = a*p[0] + b*p[1] - c, a*q[0] + b*q[1] - c
        if dp <= 0:
            out.append(p)
        if (dp < 0) != (dq < 0):
            t = dp/(dp-dq)
            out.append((p[0]+t*(q[0]-p[0]), p[1]+t*(q[1]-p[1])))
    return out


def tile_helpers_and_materials():
    source = ROOT/'design/chapter2_3d/tiles/chapter2-tiles.blend'
    with bpy.data.libraries.load(str(source),link=False) as (available, target):
        target.materials = [name for name in ('chapter2_build','chapter2_side') if name not in bpy.data.materials]
    tree = ast.parse((source.parent/'build_tiles.py').read_text())
    wanted = ('planar_uv','stone','rectangle')
    selected = ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in wanted],type_ignores=[])
    scope = dict(globals(),RNG=random.Random(781))
    exec(compile(selected,str(source.parent/'build_tiles.py'),'exec'),scope)
    return scope,bpy.data.materials['chapter2_build'],bpy.data.materials['chapter2_side']


def add_floating_ground():
    for obj in list(bpy.data.objects):
        if obj.name.startswith('floating_ground'):
            bpy.data.objects.remove(obj,do_unlink=True)
    author, top_material, side_material = tile_helpers_and_materials()
    stone = author['stone']
    # A broken construction plate with long cut edges and missing corners.
    # Staggered T-shaped joints replace radial pie-shaped fractures.
    outline = [(-.60,-.42),(-.34,-.57),(.17,-.57),(.28,-.44),(.58,-.40),
               (.57,.25),(.43,.26),(.28,.55),(-.42,.54),(-.55,.30),(-.59,.09)]
    for index,name in enumerate(NAMES):
        rng = random.Random(871+index)
        root = bpy.data.objects[name]
        bound = [(x*(1.12 if name=='void_fissure' else 1),y*(1.12 if name=='void_fissure' else 1)) for x,y in outline]
        top = -.14 if name=='void_fissure' else .018
        if name=='void_fissure':
            domains=[clipped(bound,1,0,-.045),clipped(bound,-1,0,-.045)]
        else:
            domains=[clipped(bound,1,0,-.09),clipped(bound,-1,0,.09)]
        pieces=[]
        for side,domain in enumerate(domains):
            split=.14 if side==0 else -.12
            pieces.extend([clipped(domain,0,1,split),clipped(domain,0,-1,-split)])
        for j,poly in enumerate(pieces):
            cx=sum(x for x,y in poly)/len(poly);cy=sum(y for x,y in poly)/len(poly)
            inset=[(cx+(x-cx)*.995,cy+(y-cy)*.995) for x,y in poly]
            # Broad paving slab follows the exact authored tile geometry and UV rules.
            slab=stone('floating_ground_%s_paving_%d'%(name,j),inset,top-.10,top,top_material,root,.003)
            slab['material_source']='chapter2_tiles/build_tile'
            bottom = (-.83 if name=='void_fissure' else -.74)+(-.035,.055,-.008,.075)[j]+rng.uniform(-.008,.008)
            # Vertical cut geology remains plate-like; lower faces do not meet centrally.
            body_poly=[(cx+(x-cx)*.92,cy+(y-cy)*.92) for x,y in poly]
            body=stone('floating_ground_%s_cut_wall_%d'%(name,j),body_poly,bottom,top-.095,side_material,root,.004)
            body['material_source']='chapter2_tiles/side'
        # The tile's staggered chipped stone courses continue around the separated fragment.
        for domain_index,domain in enumerate(domains):
            for edge,(p,q) in enumerate(zip(domain,domain[1:]+domain[:1])):
                delta=Vector((q[0]-p[0],q[1]-p[1]));length=delta.length
                if length<.09:continue
                tangent=delta.normalized();normal=Vector((-tangent.y,tangent.x))
                count=max(1,round(length/.25))
                for row in range(5):
                    z=top-.69+row*.118
                    # Small unequal cutbacks, rather than a globally scaled/tapered outline.
                    cutback=(.007 if edge%3 else .022)*(4-row)/4
                    cuts=[0]+[t for jj in range(1,count+1) if 0 < (t:=(jj-(.5 if row%2 else 0))*length/count) < length]+[length]
                    for k,(aa0,bb0) in enumerate(zip(cuts,cuts[1:])):
                        if row==0 and (edge+k+domain_index)%4==0:continue
                        aa=aa0+.003;bb=bb0-.003
                        pp=Vector(p)+tangent*aa+normal*cutback;qq=Vector(p)+tangent*bb+normal*cutback
                        brick=[tuple(pp),tuple(qq),tuple(qq+normal*.075),tuple(pp+normal*.075)]
                        stone('floating_ground_%s_course_%d_%d_%d_%d'%(name,domain_index,edge,row,k),brick,z,z+.112,side_material,root,.004)
        if name=='void_fissure':
            floor=bpy.data.objects.get('recessed_void_floor')
            if floor:
                if 'pre_floating_ground_location_z' not in floor:floor['pre_floating_ground_location_z']=floor.location.z
                floor.location.z=floor['pre_floating_ground_location_z']-.64
                if 'pre_floating_ground_scale_xy' not in floor:floor['pre_floating_ground_scale_xy']=[floor.scale.x,floor.scale.y]
                original=floor['pre_floating_ground_scale_xy'];floor.scale.x=original[0]*.45;floor.scale.y=original[1]*.60
                floor['floating_ground_depth_plane']=True
    bpy.context.view_layer.update()


def render_tile_comparison():
    scene=bpy.context.scene
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/images/stage1_3d/environment/chapter2_tiles.glb'))
    imported=set(bpy.data.objects)-before
    build=next(o for o in imported if o.name=='build_tile')
    build.location=(-.80,0,0)
    allowed=set(build.children_recursive)|{build}
    for o in imported:o.hide_render=o not in allowed
    chosen=bpy.data.objects['rune_pillar'];chosen.location=(.80,0,0)
    for name in NAMES:
        for o in bpy.data.objects[name].children_recursive:o.hide_render=name!='rune_pillar'
    scene.render.resolution_x=1400;scene.render.resolution_y=1000
    camera=scene.camera;target=Vector((.10,0,.13));camera.location=target+Vector((1.7,-2.7,2.3));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=3.55
    bpy.data.objects['Studio floor'].location.z=-.99
    scene.render.filepath=str(HERE/'tile-ground-comparison.png');bpy.ops.render.render(write_still=True)
    chosen.location=(0,0,0)
    for o in imported:bpy.data.objects.remove(o,do_unlink=True)


def geometry_signature(obj):
    values = [[round(c,7) for c in v.co] for v in obj.data.vertices]
    payload = {'vertices':values,'faces':[list(p.vertices) for p in obj.data.polygons],
               'materials':[m.name for m in obj.data.materials]}
    return hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()


def load_export_helpers():
    # Load only function definitions, never execute the regeneration module body.
    tree = ast.parse((HERE/'build_props.py').read_text())
    funcs = ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[])
    scope = dict(globals(), OUT=ROOT/'assets/images/stage1_3d/environment/chapter2_props.glb')
    exec(compile(funcs,str(HERE/'build_props.py'),'exec'),scope)
    return scope


if __name__ == '__main__':
    source = HERE/'chapter2_props.blend'
    backup = HERE/'before-floating-ground.blend'
    if not backup.exists():
        shutil.copy2(source,backup)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    originals = {o.name:geometry_signature(o) for n in NAMES for o in bpy.data.objects[n].children_recursive
                 if o.type=='MESH' and not o.name.startswith('floating_ground')}
    add_floating_ground()
    for name,signature in originals.items():
        assert geometry_signature(bpy.data.objects[name]) == signature, name
    report = {'preserved_original_meshes':len(originals),'roots':{}}
    for name in NAMES:
        pts = [o.matrix_world@Vector(p) for o in bpy.data.objects[name].children_recursive
               if o.type=='MESH' for p in o.bound_box]
        report['roots'][name] = {'min_blender_xyz':[min(p[i] for p in pts) for i in range(3)],
                                'max_blender_xyz':[max(p[i] for p in pts) for i in range(3)]}
    (HERE/'floating-ground-check.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report))
    helpers = load_export_helpers()
    helpers['export']()
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    helpers['render_props']()
    render_tile_comparison()
