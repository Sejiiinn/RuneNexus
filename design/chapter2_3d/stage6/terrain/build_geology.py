"""Stage 6 continuous rift geology; preserve the existing playable map and tiles.

Blender --background --python build_geology.py [-- --export-only]
The editable source contains separate rock strata. Only the game export is joined.
"""
import json
import math
import random
import re
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = HERE / 'stage6-geology.blend'
OUTPUT = ROOT / 'assets/images/stage1_3d/environment/chapter2_stage6_geology.glb'
RNG = random.Random(6026)


def map_definition():
    text = (ROOT / 'lib/data/definitions/game_stage_maps.dart').read_text()
    body = re.search(r'const chapterTwoStage6Map = MapDefinition\((.*?)\n\);', text, re.S).group(1)
    return dict(columns=8, rows=10, tileTypes=re.findall(r'TileType\.(\w+)', body.split('path:')[0]))


def uv_planar(mesh):
    uv = mesh.uv_layers.new(name='UVMap')
    shift = RNG.uniform(0, 1)
    for face in mesh.polygons:
        n = face.normal
        for li in face.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index].co
            xy = (v.x, v.y) if abs(n.z) > .55 else (v.y, v.z) if abs(n.x) > abs(n.y) else (v.x, v.z)
            uv.data[li].uv = (xy[0] + shift, xy[1] + shift)


def rock(name, poly, bottom, top, material, root, taper=.82, lean=(0, 0), bevel=.003):
    """A wide fractured stone stratum with asymmetric planar faces and flat tips."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    # Broad unequal cleavage planes, with only a few genuinely broken corners.
    # Local shape randomness leaves placement choices independent of face complexity.
    shape_rng = random.Random(6026 + sum((i+1)*ord(c) for i,c in enumerate(name)))
    outline = []
    chipped_corner = sum(ord(c) for c in name) % len(poly)
    for i,p in enumerate(poly):
        prev,nxt = poly[i-1],poly[(i+1)%len(poly)]
        if i == chipped_corner:
            a,b = shape_rng.uniform(.13,.25),shape_rng.uniform(.045,.105)
            outline.extend([(p[0]+(prev[0]-p[0])*a,p[1]+(prev[1]-p[1])*a),
                            (p[0]+(nxt[0]-p[0])*b,p[1]+(nxt[1]-p[1])*b)])
        else:
            outline.append(p)
    count = len(outline)
    height = top-bottom
    levels = [(top,1,0),(top-height*.58,.965,.54),(bottom,taper,1)]
    verts = []
    for level,(z,scale,tilt) in enumerate(levels):
        for x,y in outline:
            jitter = .002 if level==0 else .006
            verts.append((cx+(x-cx)*scale+lean[0]*tilt+shape_rng.uniform(-jitter,jitter),
                          cy+(y-cy)*scale+lean[1]*tilt+shape_rng.uniform(-jitter,jitter),
                          z+shape_rng.uniform(-.004,.003)))
    faces = [tuple(range(count))]
    for level in range(len(levels)-1):
        for i in range(count):
            j=(i+1)%count
            faces.append((level*count+i,level*count+j,(level+1)*count+j,(level+1)*count+i))
    faces.append(tuple(range((len(levels)-1)*count,len(levels)*count)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj); obj.parent = root
    mesh.materials.append(material)
    uv_planar(mesh)
    if bevel:
        bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new('Chipped mineral edges', 'BEVEL')
        mod.width = min(bevel,.004); mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)
    return obj


def rectangle(x0, y0, x1, y1):
    return [(x0,y0), (x1,y0), (x1,y1), (x0,y1)]


def clip(poly, a, b, c):
    result = []
    for p, q in zip(poly, poly[1:] + poly[:1]):
        d, e = a*p[0] + b*p[1] - c, a*q[0] + b*q[1] - c
        if d <= 0: result.append(p)
        if (d < 0) != (e < 0):
            t = d/(d-e); result.append((p[0]+t*(q[0]-p[0]), p[1]+t*(q[1]-p[1])))
    return result


def split_stone(poly, seeds):
    for i, p in enumerate(seeds):
        part = list(poly)
        for j, q in enumerate(seeds):
            if i == j: continue
            part = clip(part, q[0]-p[0], q[1]-p[1], (q[0]**2+q[1]**2-p[0]**2-p[1]**2)/2)
            if len(part) < 3: break
        if len(part) >= 3: yield part


def camera_support_points(root):
    # A whole-stage AABB encloses large empty corners of this diagonal map.
    # Store a small set of actual support vertices for its runtime camera fit.
    points=[tuple(o.matrix_world @ v.co) for o in root.children_recursive
            if o.type=='MESH' for v in o.data.vertices]
    for x,y,half,height in [(-4.48,4.35,.46,1.30),(-1.65,-3.50,.5,.80),
                            (3.45,-2.35,.5,.80),(3.40,2.48,.60,.02)]:
        points.extend((x+dx,y+dy,z) for dx in (-half,half) for dy in (-half,half) for z in (-.2,height))
    support=set()
    for step in range(32):
        angle=step*math.tau/32
        for dz in (-2,-1,0,1,2):
            dx,dy=math.cos(angle),math.sin(angle)
            p=max(points,key=lambda p:p[0]*dx+p[1]*dy+p[2]*dz)
            support.add(tuple(round(c,5) for c in (p[0],p[2],-p[1])))
    root['cameraPointsGodot']=[list(p) for p in sorted(support)]


def export():
    root = bpy.data.objects['stage6_geology']
    bpy.context.view_layer.update(); camera_support_points(root)
    copies = []
    for child in root.children_recursive:
        if child.type != 'MESH': continue
        duplicate = child.copy(); duplicate.data = child.data.copy()
        bpy.context.collection.objects.link(duplicate); copies.append(duplicate)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in copies: obj.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join(); merged = bpy.context.object
    merged.name = 'stage6_continuous_rock_strata'; merged.parent = root
    root.select_set(True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format='GLB', use_selection=True,
                             export_apply=True, export_yup=True, export_extras=True,
                             export_vertex_color='NAME', export_vertex_color_name='Color',
                             export_all_vertex_colors=False, export_cameras=False, export_lights=False)
    triangles = sum(len(p.vertices) - 2 for p in merged.data.polygons)
    bpy.data.objects.remove(merged, do_unlink=True)
    (HERE / 'export.json').write_text(json.dumps({'bytes': OUTPUT.stat().st_size, 'triangles': triangles,
        'root': 'stage6_geology', 'source': SOURCE.name, 'surface': 0}, indent=2) + '\n')


def studio():
    """Single working render of the whole authored terrain, no test harness."""
    scene = bpy.context.scene; scene.render.engine = 'CYCLES'; scene.cycles.samples = 24
    scene.render.resolution_x = 1080; scene.render.resolution_y = 1440; scene.render.resolution_percentage = 100
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.033,.052,.071,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .65
    scene.view_settings.view_transform = 'AgX'
    bpy.ops.object.camera_add(location=(6,-10,15)); cam=bpy.context.object
    cam.name='Review camera'; cam.data.type='ORTHO'; cam.data.ortho_scale=14.1
    cam.rotation_euler=(Vector((0,0,-.4))-cam.location).to_track_quat('-Z','Y').to_euler(); scene.camera=cam
    for name,loc,power,size,col in [('Key',(-6,-3,11),1700,8,(1,.92,.85)),('Fill',(7,-2,8),1150,9,(.73,.85,1)),('Rim',(0,8,9),1500,7,(.76,.84,1))]:
        bpy.ops.object.light_add(type='AREA', location=loc); lamp=bpy.context.object
        lamp.name='Review '+name; lamp.data.energy=power; lamp.data.shape='DISK'; lamp.data.size=size; lamp.data.color=col
        lamp.rotation_euler=(-lamp.location).to_track_quat('-Z','Y').to_euler()
    return scene


def build():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    definition = map_definition(); tiles=definition['tileTypes']
    with bpy.data.libraries.load(str(ROOT/'design/chapter2_3d/tiles/chapter2-tiles.blend'), link=False) as (src,dst):
        dst.materials=['chapter2_side','chapter2_build']
    side=bpy.data.materials['chapter2_side']; topmat=bpy.data.materials['chapter2_build']
    root=bpy.data.objects.new('stage6_geology',None); bpy.context.collection.objects.link(root)
    for key,value in definition.items(): root[key]=value
    root['artReference']='design/chapter2_asset_concepts/stage6/01-integrated-stage6.png'
    root['purpose']='Continuous shattered substrate under unchanged stage-6 playable tiles'
    occupied={(i%8,i//8) for i,t in enumerate(tiles) if t!='blocked'}
    coast=[]
    for col,row in sorted(occupied):
        x,y=col-4,4-row
        # Overlapping concealed strata make one continuous body, including the path bends.
        rock('substrate_%d_%d'%(col,row), rectangle(x-.025,y-.025,x+1.025,y+1.025),
             RNG.uniform(-1.28,-1.04),-.39,side,root,.93,bevel=0)
        for dx,dy,a,b in [(-1,0,(x,y+1),(x,y)),(1,0,(x+1,y),(x+1,y+1)),
                          (0,-1,(x+1,y+1),(x,y+1)),(0,1,(x,y),(x+1,y))]:
            if (col+dx,row+dy) in occupied: continue
            coast.append((Vector(a),Vector(b),Vector((dx,-dy)),col,row))
    # The cliffs cross tile boundaries: long mineral fins and staggered fractured shelves.
    for e,(a,b,out,col,row) in enumerate(coast):
        inner_void = (col==3 and row in (3,4) and out.x>0) or (col==5 and row in (3,4) and out.x<0)
        tangent=(b-a).normalized(); cursor=0.; n=0
        while cursor<.99:
            length=min(1.0-cursor,RNG.uniform(.28,.49)); center=a+tangent*(cursor+length*.5)
            width=RNG.uniform(.055,.115) if inner_void else RNG.uniform(.13,.28)
            p0=center-tangent*(length*.55)-out*.08; p1=center+tangent*(length*.55)-out*.08
            p2=p1+out*(width+.08); p3=p0+out*(width+.08)
            poly=[tuple(p) for p in (p0,p1,p2,p3)]
            bottom=RNG.uniform(-1.75,-1.03)
            rock('coast_%03d_%d'%(e,n),poly,bottom,RNG.uniform(-.25,-.10),side,root,
                 RNG.uniform(.60,.95),tuple(-out*RNG.uniform(.015,.09)))
            if not inner_void and n%2==0:
                shift=-tangent*.10-out*.05
                rock('lower_fin_%03d_%d'%(e,n),[(p[0]+shift.x,p[1]+shift.y) for p in poly],
                     bottom-RNG.uniform(.08,.28),-.66,side,root,.63,tuple(-out*.08))
            if not inner_void and e%3==1 and n==1:
                # An attached, unequal angular splinter stays within the existing coast width.
                pts=[center-tangent*.10-out*.015,center+tangent*.13+out*.015,
                     center+tangent*.08+out*width*.92,center-tangent*.045+out*width*.85]
                rock('attached_coast_splinter_%03d'%e,[tuple(p) for p in pts],
                     max(bottom+.15,-1.10),-.27-RNG.uniform(0,.12),side,root,.83,
                     tuple(-out*.025),bevel=.002)
            cursor+=length; n+=1
    # These are parts of the main landmass, not prop-sized display bases.
    ledges=[
        ('pillar',[(-3.88,5.08),(-4.48,5.12),(-4.90,4.75),(-4.92,4.02),(-4.28,3.70),(-3.83,3.90)],
         [(-4.2,4.85),(-4.63,4.5),(-4.36,3.99)]),
        ('left_crystals',[(-2.0,-2.68),(-2.45,-3.13),(-2.4,-3.80),(-1.86,-4.09),(-1.15,-3.97),(-.76,-3.30),(-1.05,-2.73)],
         [(-1.35,-3.12),(-2.05,-3.45),(-1.48,-3.87)]),
        ('right_crystals',[(2.72,-1.67),(3.44,-1.76),(3.97,-2.03),(4.05,-2.62),(3.54,-3.12),(2.76,-3.11),(2.60,-2.27)],
         [(3.06,-1.96),(3.65,-2.30),(3.26,-2.85)]),
        ('rift',[(1.80,3.10),(2.45,3.11),(2.98,3.35),(3.76,3.27),(4.09,2.79),(4.07,2.13),(3.78,1.82),(2.66,1.70),(2.12,1.91),(1.81,2.19)],
         [(2.26,2.73),(2.90,2.9),(2.91,2.05),(3.80,2.89),(3.77,2.17)])]
    for name,boundary,seeds in ledges:
        angle=math.radians(12); nx,ny=math.cos(angle),math.sin(angle)
        slit_center=3.40*nx+2.48*ny
        domains=[boundary] if name!='rift' else [clip(boundary,nx,ny,slit_center-.075),clip(boundary,-nx,-ny,-slit_center-.075)]
        for di,domain in enumerate(domains):
            for i,part in enumerate(split_stone(domain,seeds)):
                ledge_top=-.34 if name=='rift' else -.055
                rock('ledge_%s_%d_%d'%(name,di,i),part,RNG.uniform(-1.6,-1.2),ledge_top,side,root,.80,
                     (RNG.uniform(-.08,.08),RNG.uniform(-.08,.08)))
                # Unequal layers reveal a torn transition into the intact paving.
                cx=sum(x for x,y in part)/len(part); cy=sum(y for x,y in part)/len(part)
                inset=[(cx+(x-cx)*.975,cy+(y-cy)*.975) for x,y in part]
                rock('ledge_cap_%s_%d_%d'%(name,di,i),inset,ledge_top-.17,ledge_top+RNG.uniform(-.003,.027),topmat,root,.98,bevel=.008)
    # Low angular debris belongs to the non-playable ledges, never the path/build cells.
    rubble=[(-4.78,4.36,.065),(-4.24,3.90,.075),(-4.68,4.93,.055),
            (-2.15,-3.40,.080),(-1.93,-3.95,.060),(-1.05,-3.38,.060),
            (3.85,-2.65,.075),(3.60,-2.98,.055),(2.89,-2.94,.065),
            (3.97,2.38,.065),(3.65,3.14,.085),(2.88,3.19,.055)]
    for i,(x,y,size) in enumerate(rubble):
        intersects_play=False
        for col,row in occupied:
            tx,ty=col-4,4-row
            nearx=max(tx,min(x,tx+1));neary=max(ty,min(y,ty+1))
            if math.hypot(x-nearx,y-neary)<size+.035:
                intersects_play=True;break
        if intersects_play:continue
        is_rift=i>=9
        angle=math.radians(12)
        if is_rift and abs((x-3.40)*math.cos(angle)+(y-2.48)*math.sin(angle))<.075+size:
            continue
        ground=-.34 if is_rift else -.055
        poly=[(x-size,y-size*.44),(x+size*.31,y-size*.70),
              (x+size,y+size*.10),(x+size*.14,y+size*.67),(x-size*.67,y+size*.49)]
        rock('ledge_low_rubble_%02d'%i,poly,ground-.02,ground+size*.85,
             side if i%3 else topmat,root,.91,(size*.1,-size*.08),bevel=.002)
    # A few detached fragments echo the picture without filling the playable negative space.
    fragments=[(-4.68,2.9,-.8,.15),(-4.68,1.1,-1.1,.10),(-3.12,-1.0,-1.32,.13),
               (-2.75,-3.8,-1.6,.15),(1.0,-5.2,-1.65,.14),(3.5,-5.05,-1.2,.12),
               (4.34,-2.4,-.75,.11),(4.29,2.65,-.42,.14),(2.65,3.65,-.5,.10)]
    for i,(x,y,z,size) in enumerate(fragments):
        rock('detached_fragment_%02d'%i,rectangle(x-size,y-size*.7,x+size,y+size*.7),z-size*2,z+size,
             side,root,.68,(.035,-.02),bevel=.006)
    # A source file remains editable; the runtime output batches only at export.
    bpy.context.view_layer.update(); export()
    studio(); bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))


if '--export-only' in sys.argv:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE)); export()
elif SOURCE.exists() and '--regenerate' not in sys.argv:
    raise SystemExit('Use --export-only for saved edits, or explicit --regenerate.')
else:
    build()
