"""Editable wide-chest tank, approved references 12-A and 16 unified rear.

Run inside Blender with exec(compile(open(__file__).read(), __file__, 'exec')).
Creates only the named scene; libraries.write saves that scene and its dependencies,
without serializing or modifying other open projects. Front = -Y, up = +Z.
"""
import bpy, bmesh, math, json, random
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
TARGET_HEIGHT_RATIO = 1.25
PREFIX = 'Tank_WideChest_'
SCENE_NAME = PREFIX + 'Concept'
random.seed(261001)
original_scene = bpy.context.scene.name
original_file = bpy.data.filepath
scene = bpy.data.scenes.get(SCENE_NAME)
if scene:
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for col in list(scene.collection.children):
        if col.name.startswith(PREFIX):bpy.data.collections.remove(col)
else:
    scene = bpy.data.scenes.new(SCENE_NAME)
bpy.context.window.scene = scene
model = bpy.data.collections.new(PREFIX + 'MODEL')
scene.collection.children.link(model)
studio = bpy.data.collections.new(PREFIX + 'STUDIO')
scene.collection.children.link(studio)

def linear(h):
    s=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in s)+(1,)

def material(name, color, metallic=0, roughness=.7):
    m=bpy.data.materials.new(PREFIX+name);m.diffuse_color=linear(color);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=linear(color)
    p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
    return m

stone=material('weathered limestone','3A3B34',0,.86)
n=stone.node_tree.nodes;l=stone.node_tree.links;p=n.get('Principled BSDF')
tex=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=6.5;noise.inputs['Detail'].default_value=3.2;noise.inputs['Roughness'].default_value=.75
l.new(tex.outputs['Object'],noise.inputs['Vector'])
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
for pos,col in [(0,'1B201B'),(.31,'282D24'),(.48,'3A3B34'),(.63,'494A41'),(1,'64655C')]:
    e=ramp.color_ramp.elements[0] if pos==0 else ramp.color_ramp.elements.new(pos);e.color=linear(col)
l.new(noise.outputs['Fac'],ramp.inputs['Fac']);l.new(ramp.outputs['Color'],p.inputs['Base Color'])
grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=95;grain.inputs['Detail'].default_value=2
l.new(tex.outputs['Object'],grain.inputs['Vector']);bump=n.new('ShaderNodeBump')
bump.inputs['Strength'].default_value=.18;bump.inputs['Distance'].default_value=.018
l.new(grain.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
edge=material('fresh stone chip','B3AD9E',0,.88)
iron=material('charcoal iron','30322C',.28,.82)
n=iron.node_tree.nodes;l=iron.node_tree.links;p=n.get('Principled BSDF')
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=42;noise.inputs['Detail'].default_value=2
bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.17;bump.inputs['Distance'].default_value=.012
l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
rim=material('worn warm iron edges','48483E',.30,.80)
dark=material('recess dark','191B1A',.4,.81)
moss=material('dry olive deposits','55583A',0,.95)
core=material('wine red core','511426',.35,.35)
p=core.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=linear('9A1739');p.inputs['Emission Strength'].default_value=.08
hot=material('core hot seam','9B2347',.35,.4)
p=hot.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=linear('BB2452');p.inputs['Emission Strength'].default_value=.65

def link_obj(obj, col=model):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    col.objects.link(obj);return obj

def mesh(name, verts, faces, mat):
    data=bpy.data.meshes.new(PREFIX+name);data.from_pydata(verts,[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(data);bm.free()
    o=bpy.data.objects.new(PREFIX+name,data);model.objects.link(o);o.data.materials.append(mat);return o

def bevel(o, width=.04, segments=1, apply=True, weighted=True):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Physical rounded/chipped edge','BEVEL');mod.width=width;mod.segments=segments
    mod.affect='EDGES'
    if apply:bpy.ops.object.modifier_apply(modifier=mod.name)
    if weighted:
        w=o.modifiers.new('Area weighted stone normals','WEIGHTED_NORMAL');w.keep_sharp=True;w.weight=35
    return o

def cube(name, loc, dims, mat, bev=.04, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=link_obj(bpy.context.object);o.name=PREFIX+name;o.dimensions=dims
    if rot:o.rotation_euler=rot
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    if bev:bevel(o,bev)
    return o

def prism(name, outline, front, back, mat=stone, bev=.05):
    """XZ-outline, real depth along Y; front can be per-vertex for sculpted planes."""
    if isinstance(front,(int,float)):front=[front]*len(outline)
    count=len(outline);verts=[(x,front[i],z) for i,(x,z) in enumerate(outline)]+[(x,back,z) for x,z in outline]
    faces=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
    for i in range(count):j=(i+1)%count;faces.append((i,j,count+j,count+i))
    o=mesh(name,verts,faces,mat)
    if bev:bevel(o,bev)
    return o

def cylinder(name, center, radius, depth, mat, axis='X', segments=20, bev=.015):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=radius,depth=depth,location=center)
    o=link_obj(bpy.context.object);o.name=PREFIX+name
    o.rotation_euler=(0,math.pi/2,0) if axis=='X' else ((math.pi/2,0,0) if axis=='Y' else (0,0,0))
    o.data.materials.append(mat)
    if bev:bevel(o,bev,1)
    return o

def ring(name, center, ro, ri, depth, mat, axis='X', segments=24):
    verts=[]
    for x,r in [(-depth/2,ro),(depth/2,ro),(-depth/2,ri),(depth/2,ri)]:
        for i in range(segments):
            a=i*math.tau/segments
            v=(x,r*math.sin(a),r*math.cos(a))
            if axis=='Y':v=(v[1],v[0],v[2])
            if axis=='Z':v=(v[1],v[2],v[0])
            verts.append(tuple(Vector(center)+Vector(v)))
    faces=[]
    for i in range(segments):
        j=(i+1)%segments
        faces.extend([(i,j,j+segments,i+segments),(i+2*segments,i+3*segments,j+3*segments,j+2*segments),(i,i+2*segments,j+2*segments,j),(i+segments,j+segments,j+3*segments,i+3*segments)])
    o=mesh(name,verts,faces,mat);return o

def boolean(obj, cutter):
    bpy.context.view_layer.objects.active=obj
    before=obj.data.copy()
    for solver in ('EXACT',):
        mod=obj.modifiers.new('Carved geometric recess','BOOLEAN');mod.operation='DIFFERENCE';mod.solver=solver;mod.object=cutter
        obj.modifiers.move(len(obj.modifiers)-1,0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bm=bmesh.new();bm.from_mesh(obj.data);open_edges=sum(not e.is_manifold for e in bm.edges);bm.free()
        if len(obj.data.vertices)>0 and open_edges==0:break
        bad=obj.data;obj.data=before.copy();bpy.data.meshes.remove(bad)
    assert len(obj.data.vertices)>0 and open_edges==0,('Invalid boolean result',obj.name,cutter.name,open_edges)
    bpy.data.meshes.remove(before)
    bpy.data.objects.remove(cutter,do_unlink=True)

def carve_line(obj, name, points, width=.036, front=-.9, depth=.07, fill=False):
    """Actual rectangular channels cut into the stone; no painted rune."""
    for i,(a,b) in enumerate(zip(points[:-1],points[1:])):
        dx=b[0]-a[0];dz=b[1]-a[1];length=math.hypot(dx,dz)
        cutter=cube('tool_'+name,(.5*(a[0]+b[0]),front+depth/2,.5*(a[1]+b[1])),(width,depth,length+width*.28),dark,0)
        cutter.rotation_euler.y=math.atan2(dx,dz)
        boolean(obj,cutter)
        if fill:
            inset=cube(name+'_buried patina'+str(i),(.5*(a[0]+b[0]),front+depth-.009,.5*(a[1]+b[1])),(width*.92,.012,length),dark,.003)
            inset.rotation_euler.y=math.atan2(dx,dz)

def joint(name, center, radius, width, axis='X', detailed=True):
    cylinder(name+' axle',center,radius,width,dark,axis,16,.015)
    dim=0 if axis=='X' else 1
    for sign in [-1,1]:
        pos=list(center);pos[dim]+=sign*(width/2-.026)
        ring(name+' rim '+str(sign),pos,radius*1.04,radius*.80,.07,rim,axis,20)
        pos[dim]+=sign*.039;cylinder(name+' boss '+str(sign),pos,radius*.66,.055,iron,axis,12,.018)
        pos[dim]+=sign*.036;ring(name+' inset '+str(sign),pos,radius*.41,radius*.32,.016,rim,axis,12)
    return None

# Weathered warm stone: coherent middle-sized cells, mineral layers and porous grain.
# Geometry carries the rounded irregular stones; shader layers only their surface.
n=stone.node_tree.nodes;l=stone.node_tree.links;p=n.get('Principled BSDF')
for node in list(n):
    if node!=p and node.type!='OUTPUT_MATERIAL':n.remove(node)
p.inputs['Roughness'].default_value=.83
tex=n.new('ShaderNodeTexCoord')
warp=n.new('ShaderNodeTexNoise');warp.inputs['Scale'].default_value=15.0;warp.inputs['Detail'].default_value=3;l.new(tex.outputs['Object'],warp.inputs['Vector'])
vm=n.new('ShaderNodeVectorMath');vm.operation='SCALE';vm.inputs[3].default_value=.025;l.new(warp.outputs['Color'],vm.inputs[0])
a=n.new('ShaderNodeVectorMath');a.operation='ADD';l.new(tex.outputs['Object'],a.inputs[0]);l.new(vm.outputs[0],a.inputs[1])
cell=n.new('ShaderNodeTexVoronoi');cell.feature='F1';cell.inputs['Scale'].default_value=9.5;cell.distance='EUCLIDEAN';l.new(a.outputs[0],cell.inputs['Vector'])
edges=n.new('ShaderNodeTexVoronoi');edges.feature='DISTANCE_TO_EDGE';edges.inputs['Scale'].default_value=9.5;l.new(a.outputs[0],edges.inputs['Vector'])
cellval=n.new('ShaderNodeRGBToBW');l.new(cell.outputs['Color'],cellval.inputs[0])
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.30;ramp.color_ramp.elements[0].color=linear('62594D');ramp.color_ramp.elements[1].position=.70;ramp.color_ramp.elements[1].color=linear('AC9C85')
e=ramp.color_ramp.elements.new(.50);e.color=linear('817260')
broad=n.new('ShaderNodeTexNoise');broad.inputs['Scale'].default_value=10.0;broad.inputs['Detail'].default_value=3.2;l.new(tex.outputs['Object'],broad.inputs[0])
cv=n.new('ShaderNodeMath');cv.operation='MULTIPLY';cv.inputs[1].default_value=.18;l.new(cellval.outputs[0],cv.inputs[0])
bv=n.new('ShaderNodeMath');bv.operation='MULTIPLY_ADD';bv.inputs[1].default_value=.82;l.new(broad.outputs['Fac'],bv.inputs[0]);l.new(cv.outputs[0],bv.inputs[2]);l.new(bv.outputs[0],ramp.inputs[0])
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=34;noise.inputs['Detail'].default_value=4.0;noise.inputs['Roughness'].default_value=.75;l.new(tex.outputs['Object'],noise.inputs[0])
noise_r=n.new('ShaderNodeValToRGB');noise_r.color_ramp.elements[0].position=.25;noise_r.color_ramp.elements[0].color=(.15,.14,.12,1);noise_r.color_ramp.elements[1].position=.75;noise_r.color_ramp.elements[1].color=(.98,.94,.86,1);l.new(noise.outputs['Fac'],noise_r.inputs[0])
mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.48;l.new(ramp.outputs[0],mix.inputs[1]);l.new(noise_r.outputs[0],mix.inputs[2])
edge_r=n.new('ShaderNodeValToRGB');edge_r.color_ramp.elements[0].position=.004;edge_r.color_ramp.elements[0].color=(.42,.42,.42,1);edge_r.color_ramp.elements[1].position=.036;edge_r.color_ramp.elements[1].color=(0,0,0,1);l.new(edges.outputs['Distance'],edge_r.inputs[0])
patch=n.new('ShaderNodeTexNoise');patch.inputs['Scale'].default_value=6;patch.inputs['Detail'].default_value=3;l.new(tex.outputs['Object'],patch.inputs[0])
edge_mask=n.new('ShaderNodeMath');edge_mask.operation='MULTIPLY';l.new(edge_r.outputs[0],edge_mask.inputs[0]);l.new(patch.outputs['Fac'],edge_mask.inputs[1])
mineral=n.new('ShaderNodeMixRGB');l.new(edge_mask.outputs[0],mineral.inputs[0]);l.new(mix.outputs[0],mineral.inputs[1]);mineral.inputs[2].default_value=linear('AA987B');l.new(mineral.outputs[0],p.inputs['Base Color'])
grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=115;grain.inputs['Detail'].default_value=2.4;l.new(tex.outputs['Object'],grain.inputs[0])
bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.18;bump.inputs['Distance'].default_value=.007;l.new(grain.outputs['Fac'],bump.inputs['Height'])
relief=n.new('ShaderNodeValToRGB');relief.color_ramp.elements[0].position=.0;relief.color_ramp.elements[0].color=(.0,.0,.0,1);relief.color_ramp.elements[1].position=.055;relief.color_ramp.elements[1].color=(.6,.6,.6,1);l.new(edges.outputs['Distance'],relief.inputs[0])
small=n.new('ShaderNodeTexVoronoi');small.feature='DISTANCE_TO_EDGE';small.inputs['Scale'].default_value=15.5;l.new(a.outputs[0],small.inputs[0])
small_r=n.new('ShaderNodeValToRGB');small_r.color_ramp.elements[0].position=.0;small_r.color_ramp.elements[0].color=(0,0,0,1);small_r.color_ramp.elements[1].position=.055;small_r.color_ramp.elements[1].color=(.6,.6,.6,1);l.new(small.outputs['Distance'],small_r.inputs[0])
mixedrelief=n.new('ShaderNodeMixRGB');l.new(patch.outputs['Fac'],mixedrelief.inputs[0]);l.new(relief.outputs[0],mixedrelief.inputs[1]);l.new(small_r.outputs[0],mixedrelief.inputs[2])
wear=n.new('ShaderNodeMixRGB');l.new(patch.outputs['Fac'],wear.inputs[0]);l.new(noise.outputs['Fac'],wear.inputs[1]);l.new(mixedrelief.outputs[0],wear.inputs[2])
bump2=n.new('ShaderNodeBump');bump2.inputs['Strength'].default_value=.40;bump2.inputs['Distance'].default_value=.020;l.new(mixedrelief.outputs[0],bump2.inputs['Height']);l.new(bump.outputs[0],bump2.inputs['Normal'])
bump3=n.new('ShaderNodeBump');bump3.inputs['Strength'].default_value=.20;bump3.inputs['Distance'].default_value=.014;l.new(noise.outputs['Fac'],bump3.inputs['Height']);l.new(bump2.outputs[0],bump3.inputs['Normal']);l.new(bump3.outputs[0],p.inputs['Normal'])
from mathutils import noise as mnoise

def rock(name,center,scale,power=.86,sub=3,seed=0,smooth=True):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=center)
    o=link_obj(bpy.context.object);o.name=PREFIX+name
    for ve in o.data.vertices:
        q=ve.co.copy();v=Vector([math.copysign(abs(k)**(power[i] if isinstance(power,(list,tuple)) else power),k) for i,k in enumerate(q)])
        # Low-frequency sculpting changes the silhouette, independent of grain.
        rough=1+.052*mnoise.noise(q*2.7+Vector((seed*.71,seed*.13,seed*.37)))+.013*mnoise.noise(q*7+Vector((seed,2,6)))
        ve.co=Vector([v[i]*scale[i]*rough for i in range(3)])
    o.data.materials.append(stone)
    for poly in o.data.polygons:poly.use_smooth=smooth
    return o

def sphere(name,center,scale,mat,seg=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=center)
    o=link_obj(bpy.context.object);o.name=PREFIX+name;o.scale=scale;o.data.materials.append(mat)
    for f in o.data.polygons:f.use_smooth=True
    return o

darkstone=material('dark stone connectors','393229',0,.94)
eye_mat=material('solid turquoise spherical eyes','008F98',.14,.20)
p=eye_mat.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=linear('008C97');p.inputs['Emission Strength'].default_value=.12
amber=material('single amber front heart','E8BD71',0,.12)
p=amber.node_tree.nodes.get('Principled BSDF');p.inputs['Transmission Weight'].default_value=1.0;p.inputs['IOR'].default_value=1.20;p.inputs['Specular IOR Level'].default_value=.16
p.inputs['Coat Weight'].default_value=.08;p.inputs['Coat Roughness'].default_value=.18
absorb=amber.node_tree.nodes.new('ShaderNodeVolumeAbsorption');absorb.inputs['Color'].default_value=linear('D78119');absorb.inputs['Density'].default_value=4.5;amber.node_tree.links.new(absorb.outputs[0],amber.node_tree.nodes.get('Material Output').inputs['Volume'])
inner_amber=material('internal luminous amber nucleus','FFC13D',0,.28)
ip=inner_amber.node_tree.nodes.get('Principled BSDF');ip.inputs['Emission Strength'].default_value=1.05
# Optical facing gradient on a true inner sphere: a small warm-white centre,
# golden volume and a dark amber edge, seen through the absorbing outer stone lens.
fw=inner_amber.node_tree.nodes.new('ShaderNodeLayerWeight');fw.inputs['Blend'].default_value=.5
fr=inner_amber.node_tree.nodes.new('ShaderNodeValToRGB');fr.color_ramp.elements[0].position=0;fr.color_ramp.elements[0].color=(1.8,1.45,.95,1);fr.color_ramp.elements[1].position=.85;fr.color_ramp.elements[1].color=linear('663201')
for pos,col in [(.035,'FFE2A1'),(.18,'FFBF36'),(.48,'C67909')]:fr.color_ramp.elements.new(pos).color=linear(col)
inner_amber.node_tree.links.new(fw.outputs['Facing'],fr.inputs[0]);inner_amber.node_tree.links.new(fr.outputs[0],ip.inputs['Emission Color']);inner_amber.node_tree.links.new(fr.outputs[0],ip.inputs['Base Color'])
rune_mat=material('recessed turquoise mineral spiral','16858A',.06,.55)
def weathered_crack(obj,name,paths,width=.0045):
    # Cache every branch on the untouched stone before cutting any channel.
    projected=[]
    for path in paths:
        bpy.context.view_layer.update();inv=obj.matrix_world.inverted();coords=[]
        for aa,bb in zip(path[:-1],path[1:]):
            for k in range(3):
                t=k/3;x=aa[0]*(1-t)+bb[0]*t;z=aa[1]*(1-t)+bb[1]*t
                ok,loc,no,face=obj.ray_cast(inv@Vector((x,-3,z)),inv.to_3x3()@Vector((0,1,0)))
                if ok:coords.append(obj.matrix_world@loc+Vector((0,.0015,0)))
        projected.append(coords)
    for index,coords in enumerate(projected):
        if len(coords)<2:continue
        cv=bpy.data.curves.new(PREFIX+name,'CURVE');cv.dimensions='3D';cv.resolution_u=1;cv.bevel_depth=width;cv.bevel_resolution=1;cv.use_fill_caps=True
        sp=cv.splines.new('BEZIER');sp.bezier_points.add(len(coords)-1);sp.resolution_u=2
        for i,(pt,co) in enumerate(zip(sp.bezier_points,coords)):pt.co=co;pt.handle_left_type='AUTO';pt.handle_right_type='AUTO';pt.radius=.65+.25*math.sin(math.pi*(i+1)/(len(coords)+1))
        o=bpy.data.objects.new(PREFIX+name,cv);model.objects.link(o);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
        cutter=bpy.context.view_layer.objects.active
        if darkstone.name not in obj.data.materials:obj.data.materials.append(darkstone)
        cutter.data.materials.append(stone);cutter.data.materials.append(darkstone)
        for f in cutter.data.polygons:f.material_index=1
        boolean(obj,cutter)
        # Crisp fissure walls must not smear their normals into the broad stone.
        for f in obj.data.polygons:
            if f.material_index==1:f.use_smooth=False

def faceted_chest(side, sign, seed):
    # A low-volume natural polyhedron: each broad front is enclosed by unequal
    # oblique planes rather than a rounded cuboid or inflated hemisphere.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=1,location=(sign*.59,-.30,2.45))
    o=link_obj(bpy.context.object);o.name=PREFIX+side+' broad chest slab'
    planes=[((1,0,0),.63),((-1,0,0),.57),((0,1,0),.285),((0,-1,0),.282),
            ((0,0,1),.555),((0,0,-1),.49),((1,0,.62),.76),((-1,0,.30),.65),
            ((1,0,-.72),.69),((-1,0,-.48),.61),
            ((.43,-1,.08),.445),((-.32,-1,-.06),.405),
            ((.08,-1,.48),.447),((-.07,-1,-.55),.431)]
    for ve in o.data.vertices:
        q=ve.co.normalized();d=Vector((q.x*sign,q.y,q.z))
        radii=[b/Vector(a).dot(d) for a,b in planes if Vector(a).dot(d)>1e-5]
        # Smooth minimum retains large planes and gently rounds their joins.
        r=sum(t**-32 for t in radii)**(-1/32)
        v=d*r
        v*=1+.012*mnoise.noise(q*3.1+Vector((seed,4,7)))
        v.x+=.018*v.z/.55;v.z+=.020*v.x/.63
        ve.co=Vector((v.x*sign,v.y,v.z))
    o.data.materials.append(stone)
    for f in o.data.polygons:f.use_smooth=True
    return o

# Compact reference proportions: curved paired chest, diagonal rounded shoulders,
# full natural stone forearms and a rounded single pelvis joining both thighs.
back=rock('single broad unsegmented back',(0,.13,2.48),(1.16,.57,.85),.82,4,10)
# A single wide stone with a broad rear plane, sloping shoulders and lower corners.
# Its upper mass overlaps the head; the rear must not read as a horizontal pill.
back_planes=[((1,0,0),1.16),((-1,0,0),1.16),((0,1,0),.55),((0,-1,0),.40),
             ((0,0,1),.90),((0,0,-1),.62),
             ((1,0,.62),1.40),((-1,0,.67),1.43),
             ((1,0,-.86),1.27),((-1,0,-.89),1.28),
             ((.40,1,.06),.88),((-.43,1,-.02),.90),
             ((0,1,.55),1.04),((0,1,-.55),.86)]
for ve in back.data.vertices:
    q=ve.co.normalized();radii=[b/Vector(a).dot(q) for a,b in back_planes if Vector(a).dot(q)>1e-5]
    r=sum(t**-14 for t in radii)**(-1/14)
    ve.co=q*r*(1+.014*mnoise.noise(q*3+Vector((10,7,2))))
chests=[]
for sign in [-1,1]:
    side='L' if sign<0 else 'R'
    chest=faceted_chest(side,sign,22+sign)
    chest.rotation_euler.y=-sign*.10
    cutter=sphere('front heart socket cutter',(0,-.57,2.35),(.174,.26,.174),darkstone,16,10);boolean(chest,cutter)
    chests.append(chest)
# The upper side boundary follows the actual pectoral roof instead of a flat
# height cut. This keeps the rear one continuous sloping stone and prevents
# a front collar, without changing either the head or the paired chest shapes.
bpy.context.view_layer.update()
chest_edges=[]
for chest in chests:
    points=[chest.matrix_world@v.co for v in chest.data.vertices]
    chest_edges.extend((points[e.vertices[0]],points[e.vertices[1]]) for e in chest.data.edges)
def pectoral_roof(x):
    heights=[a.z+(b.z-a.z)*(x-a.x)/(b.x-a.x) for a,b in chest_edges
             if min(a.x,b.x)<=x<=max(a.x,b.x) and abs(b.x-a.x)>1e-8]
    return max(heights) if heights else 2.70
for ve in back.data.vertices:
    x=ve.co.x;central_roof=3.38-.45*x*x
    t=max(0,min(1,(abs(x)-.68)/.14));t=t*t*(3-2*t)
    roof=(1-t)*central_roof+t*(pectoral_roof(x)-.006)-back.location.z
    ve.co.z=.5*(ve.co.z+roof-math.sqrt((ve.co.z-roof)**2+.012**2))
bpy.context.view_layer.objects.active=back
reduce_back=back.modifiers.new('Preserve broad stone planes within mesh budget','DECIMATE');reduce_back.ratio=.65
bpy.ops.object.modifier_apply(modifier=reduce_back.name)
pelvis=rock('single pelvis keystone including rear',(0,.045,1.77),(.74,.42,.40),.9,3,71)
# Broad hidden upper support; only a short faceted keystone is exposed beneath
# the chest. Its lower planes turn inward without a separate oval belly apex.
pelvis_planes=[((1,0,0),.74),((-1,0,0),.74),((0,1,0),.42),((0,-1,0),.345),
               ((0,0,1),.34),((0,0,-1),.40),
               ((1,0,-.92),.75),((-1,0,-.98),.76),
               ((0,-1,-.34),.40),((.2,-1,.12),.43),((-.2,-1,.06),.425)]
for ve in pelvis.data.vertices:
    q=ve.co.normalized();radii=[b/Vector(a).dot(q) for a,b in pelvis_planes if Vector(a).dot(q)>1e-5]
    r=sum(t**-28 for t in radii)**(-1/28)
    ve.co=q*r*(1+.010*mnoise.noise(q*3+Vector((71,4,9))))
cylinder('heart stone cavity',(0,-.20,2.35),.149,.12,darkstone,'Y',24,.012)
# The natural chest socket provides its own stone rim; no independent frame.
sphere('single spherical amber front core',(0,-.44,2.35),(.105,.105,.105),amber,16,12)
sphere('small internal amber light volume',(0,-.43,2.35),(.072,.072,.072),inner_amber,12,8)
for sign in [-1,1]:
    side='L' if sign<0 else 'R'
    joint_rock=rock(side+' recessed shoulder connector',(sign*1.22,.05,2.71),(.26,.26,.26),.9,2,90+sign)
    joint_rock.data.materials.clear();joint_rock.data.materials.append(darkstone)
    shoulder=rock(side+' rounded natural stone shoulder',(sign*1.56,.025,2.94),(.49,.43,.56),.89,4,3+sign)
    shoulder.rotation_euler.y=-sign*.30
    arm=rock(side+' short stone upper arm',(sign*1.69,.08,2.40),(.38,.34,.285),.83,2,8+sign)
    arm.rotation_euler.y=-sign*.30
    joint_rock=rock(side+' recessed elbow connector',(sign*1.76,.07,2.18),(.25,.24,.15),.90,2,96+sign)
    joint_rock.data.materials.clear();joint_rock.data.materials.append(darkstone)
    forearm=rock(side+' heavy short forearm',(sign*1.89,-.005,1.85),(.49,.43,.52),.96,4,5+sign)
    forearm.rotation_euler.y=-sign*.18
    for k in range(2):
        rock(side+' stone fist knuckle '+str(k),(sign*(1.72+k*.27),-.26,1.345),(.22,.24,.235),.87,2,50+k+sign)
    rock(side+' stone thumb',(sign*1.58,-.30,1.51),(.22,.23,.26),.92,2,44+sign)
    joint_rock=rock(side+' recessed hip connector',(sign*.57,.10,1.47),(.18,.20,.17),.91,2,81+sign)
    joint_rock.data.materials.clear();joint_rock.data.materials.append(darkstone)
    thigh=rock(side+' short massive thigh',(sign*.65,.035,1.23),(.485,.425,.48),(.88,.91,.90),3,10+sign)
    thigh.rotation_euler.y=sign*.10
    for ve in thigh.data.vertices:
        # A short, full stone is raised into the keystone, keeping its broad
        # proximal surface continuous; isolated stretched cap vertices are not used.
        upper=max(0,min(1,(ve.co.z-.15)/.32))
        ve.co.x-=sign*.045*upper
    joint_rock=rock(side+' recessed ankle connector',(sign*.73,.02,.57),(.25,.27,.13),.92,2,82+sign)
    joint_rock.data.materials.clear();joint_rock.data.materials.append(darkstone)
    foot=rock(side+' broad flat-soled stone foot',(sign*.79,-.19,.32),(.56,.60,.45),.74,4,66+sign)
    for vertex in foot.data.vertices:vertex.co.z=max(vertex.co.z,-.32)
    bm=bmesh.new();bm.from_mesh(foot.data);bottom={v for v in bm.verts if abs(v.co.z+.32)<1e-6};inside=[v for v in bottom if all(all(vv in bottom for vv in f.verts) for f in v.link_faces)];bmesh.ops.dissolve_verts(bm,verts=inside,use_face_split=False,use_boundary_tear=False);bm.to_mesh(foot.data);bm.free()
    for target,xx,zz,paths in [
        (shoulder,sign*1.56,2.94,[[(.04,.30),(-.02,.18),(.035,.07),(-.035,-.08)],[(-.01,.18),(-.13,.10),(-.15,.01)]]),
        (forearm,sign*1.89,1.85,[[(.02,.35),(-.025,.22),(.025,.09),(-.04,-.09)],[(.0,.19),(.12,.11),(.13,.02)]])]:
        weathered_crack(target,side+' branched weathered fracture', [[(xx+sign*x,zz+z) for x,z in path] for path in paths])
# Large rounded/chamfered head: broad cheeks and crown, neither helmet nor human skull.
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=32,radius=1,location=(0,0,3.65))
head=link_obj(bpy.context.object);head.name=PREFIX+'large round chamfered monolithic head'
for ve in head.data.vertices:
    q=ve.co.copy();v=Vector([math.copysign(abs(k)**(.73 if i==2 else .77),k) for i,k in enumerate(q)])
    rough=1+.018*mnoise.noise(q*3+Vector((1,3,7)))+.006*mnoise.noise(q*9+Vector((3,2,1)))
    ve.co=Vector((v.x*1.17*rough,v.y*.77*rough,v.z*.86*rough))
    if ve.co.y<-.5:
        worldz=ve.co.z+3.65;ve.co.y-=.05*max(0,1-abs(ve.co.x)/.30)*max(0,1-abs(worldz-3.5)/.36)
head.data.materials.append(stone)
for f in head.data.polygons:f.use_smooth=True
for s in [-1,1]:
    side='L' if s<0 else 'R'
    outline=[(.6+(x-.6)*.78,3.40+(z-3.40)*.78) for x,z in [(.24,3.40),(.46,3.46),(.94,3.59),(1.015,3.43),(.94,3.24),(.65,3.18),(.38,3.21),(.25,3.30)]]
    cut=prism(side+' physical recessed eye socket',[(s*x,z) for x,z in outline],-1.32,-.48,darkstone,.07);boolean(head,cut)
    sphere(side+' eye cavity dark stone',(s*.60,-.46,3.36),(.235,.12,.170),darkstone,16,10)
    sphere(side+' turquoise spherical eye',(s*.60,-.581,3.405),(.121,.125,.129),eye_mat,16,12)
carve_line(head,'subtle curved jaw fissure',[(-1.05,3.07),(-.77,3.025),(-.40,2.986),(0,2.985),(.40,2.995),(.77,3.035),(1.06,3.12)],.015,-1.02,.27)
# Project a sparse weathered crown crack into the actual curved face.
bpy.context.view_layer.update()
fracture=[(-1.05,3.78),(-.92,3.88),(-.77,3.94),(-.71,4.10),(-.48,4.19),(-.38,4.39)]
cv=bpy.data.curves.new(PREFIX+'weathered crown crack tool','CURVE');cv.dimensions='3D';cv.resolution_u=1;cv.bevel_depth=.014;cv.bevel_resolution=1;cv.use_fill_caps=True
sp=cv.splines.new('POLY');locations=[]
for a,b in zip(fracture[:-1],fracture[1:]):
    for k in range(5):
        t=k/5;x=a[0]*(1-t)+b[0]*t;z=a[1]*(1-t)+b[1]*t
        ok,loc,no,idx=head.ray_cast(head.matrix_world.inverted()@Vector((x,-3,z)),Vector((0,1,0)))
        if ok:locations.append(head.matrix_world@loc+Vector((0,.006,0)))
sp.points.add(len(locations)-1)
for p0,loc in zip(sp.points,locations):p0.co=(*loc,1)
o=bpy.data.objects.new(PREFIX+'weathered crown crack tool',cv);model.objects.link(o)
bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH')
crack_cutter=bpy.context.view_layer.objects.active;assert crack_cutter != head
boolean(head,crack_cutter)
# A long, low jaw seam must follow the stone surface rather than a flat plane.
# Small, physically cut groove: no line decal and no separate mouth plate.
bpy.context.view_layer.update()
jawpath=[(-1.04,3.085),(-.80,3.035),(-.48,3.005),(0,2.995),(.48,3.005),(.80,3.035),(1.04,3.085)]
cv=bpy.data.curves.new(PREFIX+'projected low jaw groove tool','CURVE');cv.dimensions='3D';cv.resolution_u=1;cv.bevel_depth=.009;cv.bevel_resolution=1;cv.use_fill_caps=True
sp=cv.splines.new('POLY');locations=[]
for a,b in zip(jawpath[:-1],jawpath[1:]):
    for k in range(7):
        t=k/7;x=a[0]*(1-t)+b[0]*t;z=a[1]*(1-t)+b[1]*t
        ok,loc,no,idx=head.ray_cast(head.matrix_world.inverted()@Vector((x,-3,z)),Vector((0,1,0)))
        if ok:locations.append(head.matrix_world@loc+Vector((0,.0025,0)))
sp.points.add(len(locations)-1)
for pt,loc in zip(sp.points,locations):pt.co=(*loc,1)
o=bpy.data.objects.new(PREFIX+'projected low jaw groove tool',cv);model.objects.link(o)
bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH')
boolean(head,bpy.context.view_layer.objects.active)
# Approved angular spiral: one physically carved watertight curved channel.
bpy.context.view_layer.update()
normal=Vector((0,-.67,.742)).normalized();u=Vector((1,0,0));vv=normal.cross(u).normalized();origin=Vector((.13,-.62,4.15))
path=[(.265,-.30),(.265,.285),(-.285,.285),(-.285,-.15),(.065,-.15),(.065,.105),(-.075,.105)]
world_to_head=head.matrix_world.inverted()
def surface_point(a,b):
    start=origin+u*a+vv*b+normal*2
    ok,loc,no,idx=head.ray_cast(world_to_head@start,world_to_head.to_3x3()@(-normal))
    assert ok,('rune projection',a,b)
    return head.matrix_world@loc
# Project the spiral as one closed ribbon. Samples must remain farther apart
# than the miter half-width, so the inner corner does not self-intersect.
points=[]
for a,b in zip(path[:-1],path[1:]):
    av=Vector(a);bv=Vector(b);count=max(1,math.floor((bv-av).length/.13))
    for k in range(count):points.append(av.lerp(bv,k/count))
points.append(Vector(path[-1]));sides=[]
for i,pt in enumerate(points):
    dp=(pt-points[max(0,i-1)]).normalized() if i else (points[1]-pt).normalized()
    dn=(points[min(len(points)-1,i+1)]-pt).normalized() if i<len(points)-1 else dp
    a=Vector((-dp.y,dp.x));b=Vector((-dn.y,dn.x));m=(a+b).normalized();offset=m*(.043/max(.4,m.dot(b)))
    sides.append([surface_point(*(pt-offset)),surface_point(*(pt+offset))])
nr=len(sides);tops=[p for row in sides for p in row];faces=[]
for i in range(nr-1):
    j=i*2;k=j+2;faces.extend([(j,k,k+1,j+1),(j+2*nr,j+1+2*nr,k+1+2*nr,k+2*nr),(j,j+2*nr,k+2*nr,k),(j+1,k+1,k+1+2*nr,j+1+2*nr)])
faces.extend([(0,1,1+2*nr,2*nr),(2*nr-2,4*nr-2,4*nr-1,2*nr-1)])
verts=[tuple(q+normal*.045) for q in tops]+[tuple(q-normal*.065) for q in tops]
cutter=mesh('watertight forehead spiral channel cutter',verts,faces,stone);boolean(head,cutter)
fillverts=[tuple(q-normal*.027) for q in tops]+[tuple(q-normal*.049) for q in tops]
mesh('continuous physically recessed turquoise spiral',fillverts,faces,rune_mat)
assert len(head.data.vertices)>2000,'Head mesh lost after carving'
for polygon in head.data.polygons:polygon.material_index=0
# Keep the large-head family while giving the high, broad frame visual priority.
# Eyes, carved jaw and recessed spiral move with the actual head, not as decals.
head_origin=Vector((0,0,3.65))
for part in list(model.objects):
    if part==head or ' eye cavity ' in part.name or ' spherical eye' in part.name or 'continuous physically recessed turquoise spiral' in part.name:
        part.location=(part.location-head_origin)*.96+head_origin+Vector((0,0,.10))
        part.scale*=.96
        part.location.x*=.89
        if ' spherical eye' not in part.name:part.scale.x*=.89
neck=rock('recessed dark stone neck',(0,.08,2.99),(.39,.30,.16),.65,2,94)
neck.data.materials.clear();neck.data.materials.append(darkstone)
root=bpy.data.objects.new(PREFIX+'ROOT',None);model.objects.link(root)
for o in list(model.objects):
    if o!=root:o.parent=root
root['reference']='../16-wide-chest-multiview-unified-back.png'
root['proportion_reference']='../12-a-wide-chest-150.png'
root['frame_revision']='Astra reference revision 5: tall broad single rear stone with continuous rounded upper slopes fitted to the actual pectoral roof, no front collar or rear shelves; descending pelvis and short thighs; preserved head, chest and material.'
root['scope']='Editable static 3D concept only; no rig, animation or game integration.'
# Determine exactly 1.25x the approved normal from actual evaluated world mesh bounds.
normal_file=OUT.parents[2]/'2026-09-26/medium-guardian-3d/medium-guardian.blend'
with bpy.data.libraries.load(str(normal_file),link=False) as (data_from,data_to):
    data_to.collections=['Medium_Guardian_MODEL']
normal_collection=data_to.collections[0]
def mesh_bounds(objects,evaluated=True):
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();points=[]
    for o in objects:
        if o.type!='MESH':continue
        if evaluated and o.name in scene.objects:
            ev=o.evaluated_get(deps);me=ev.to_mesh();points.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
        else:points.extend(o.matrix_world@v.co for v in o.data.vertices)
    return {'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)]}
scene.collection.children.link(normal_collection)
normal_bounds=mesh_bounds(normal_collection.objects,True)
scene.collection.children.unlink(normal_collection)
tank_before=mesh_bounds(model.objects)
normal_height=normal_bounds['max'][2]-normal_bounds['min'][2];tank_height=tank_before['max'][2]-tank_before['min'][2]
root.scale=(normal_height*TARGET_HEIGHT_RATIO/tank_height,)*3;root.location.z=-tank_before['min'][2]*root.scale.z
bpy.context.view_layer.update();tank_bounds=mesh_bounds(model.objects)
height=tank_bounds['max'][2]-tank_bounds['min'][2];assert abs(height/normal_height-TARGET_HEIGHT_RATIO)<1e-5
scale_data={'normal_source':str(normal_file),'normal_bounds':normal_bounds,'normal_height':normal_height,'tank_bounds':tank_bounds,'tank_height':height,'height_ratio':height/normal_height,'tank_root_uniform_scale':root.scale.x,'rule':'Actual head-to-sole height 1.25x the normal in the same production coordinate system. In-game normal 1.15 common display factor cancels in a ratio; do not multiply tank by another 1.15. Width and depth preserve wide-chest form, not forced to 1.25x normal.'}
(OUT/'size-comparison.json').write_text(json.dumps(scale_data,ensure_ascii=False,indent=2))
root['normal_height']=normal_height;root['tank_height']=height;root['normal_height_ratio']=TARGET_HEIGHT_RATIO
floor_mat=material('studio dark blue charcoal','292D35',0,.95)
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.012));floor=bpy.context.object;floor.name=PREFIX+'studio floor';floor.data.materials.append(floor_mat);link_obj(floor,studio)
world=bpy.data.worlds.new(PREFIX+'World');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.09,.115,.15,1);world.node_tree.nodes['Background'].inputs[1].default_value=.38;scene.world=world
for name,loc,power,size,color in [('warm large key',(-6,-9,12),1800,6,(1,.94,.85)),('cool soft fill',(7,-4,7),950,5,(.82,.9,1)),('broad warm back',(2,6,10),2000,5,(1,.9,.75))]:
    d=bpy.data.lights.new(PREFIX+name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
    o=bpy.data.objects.new(PREFIX+name,d);studio.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,height*.5))-o.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new(PREFIX+'Camera');camera=bpy.data.objects.new(PREFIX+'Camera',camera_data);studio.objects.link(camera)
camera.location=(10,-17,9.8);camera.rotation_euler=(Vector((0,0,height*.50))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=height*1.36;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'preview-three-quarter.png');scene.render.film_transparent=False
entries=[];deps=bpy.context.evaluated_depsgraph_get()
for o in model.objects:
    if o.type!='MESH':continue
    ev=o.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles();entries.append({'object':o.name,'vertices':len(me.vertices),'faces':len(me.polygons),'triangles':len(me.loop_triangles)});ev.to_mesh_clear()
totals={k:sum(e[k] for e in entries) for k in ('vertices','faces','triangles')}
(OUT/'mesh-stats.json').write_text(json.dumps({'asset':'Wide chest tank / unified rear','blender_version':bpy.app.version_string,'totals':totals,'objects':entries,'front_axis':'-Y','active_scene_before_build':original_scene,'original_open_file_preserved':original_file,'preserved_existing_fast_hound_objects':len(bpy.data.scenes['Fast_Hound_Run'].objects) if bpy.data.scenes.get('Fast_Hound_Run') else None,'size':scale_data,'scope':root['scope']},ensure_ascii=False,indent=2))
bpy.data.libraries.write(str(OUT/'tank-wide-chest.blend'),{scene},fake_user=True,compress=True)
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=height*1.8;area.spaces.active.region_3d.view_location=Vector((0,0,height*.5));area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
print('TANK_MODEL_READY',str(OUT/'tank-wide-chest.blend'),totals,scale_data)
