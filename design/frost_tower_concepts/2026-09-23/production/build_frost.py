"""Editable six shutter / six cooling bay frost turret. Run through Blender MCP.
Creates an isolated scene and never deletes or saves over an existing user scene.
"""
import bpy, math, random, json, os, struct, hashlib
from mathutils import Vector
from pathlib import Path
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
PRODUCTION=ROOT/'design/frost_tower_concepts/2026-09-23/production'
OUT=Path(globals().get('FROST_OUTPUT_PATH',PRODUCTION))
OUT.mkdir(parents=True,exist_ok=True)
SCALE=1.0
scene=bpy.data.scenes.new('Frost cooling-fin production')
bpy.context.window.scene=scene
scene.render.engine='CYCLES'; scene.cycles.samples=48
scene.render.resolution_x=1024; scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'

def rgba(h):
    a=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in a)+(1,)
def mat(name,h,rough=.5,metal=0,emission=None,strength=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=rgba(h)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emission: p.inputs['Emission Color'].default_value=rgba(emission);p.inputs['Emission Strength'].default_value=strength
    return m
steel=mat('Frost | graphite blue-black machined steel','37464C',.48,.72)
edge=mat('Frost | worn edge steel','69777B',.39,.73)
stone=mat('Frost | basalt housing','354249',.76,.13)
black=mat('Frost | recessed cavity','071B23',.56,.35)
bronze=mat('Frost | aged bronze pivot and restraint','887253',.4,.72)
bronzeedge=mat('Frost | bronze pivot edge','B39A70',.32,.75)
cyan=mat('Frost | cold circulating core','087697',.25,.35,'019AD7',.8)
finmat=mat('Frost | cold aluminum fins','206277',.27,.73,'126680',.12)
coremat=mat('Frost | dark deep coolant column','083D55',.3,.35,'046991',.18)
rime=mat('Frost | crystalline rim hoarfrost','9DD2DA',.65,.02)
ice=mat('Frost | deeply fractured blue ice lens','268CAD',.21,.08,'1379A1',.33)
# Surface textures are baked in Blender by bake_surfaces.py and embedded in GLB.
surface_maps={}
for m,kind in [(steel,'metal'),(stone,'metal'),(ice,'ice')]:
    for channel in ['basecolor','normal','roughness']:
        n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
        tex=n.new('ShaderNodeTexImage');path=str(PRODUCTION/f'textures/{kind}_{channel}.png')
        if path not in surface_maps:surface_maps[path]=bpy.data.images.load(path,check_existing=False)
        tex.image=surface_maps[path]
        if channel!='basecolor':tex.image.colorspace_settings.name='Non-Color'
        if channel=='normal':
            normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.6;l.new(tex.outputs[0],normal.inputs[0]);l.new(normal.outputs[0],p.inputs['Normal'])
        else:l.new(tex.outputs[0],p.inputs['Base Color' if channel=='basecolor' else 'Roughness'])
emtex=ice.node_tree.nodes.new('ShaderNodeTexImage');emtex.image=bpy.data.images.load(str(PRODUCTION/'textures/ice_emission.png'),check_existing=False)
ice.node_tree.links.new(emtex.outputs[0],ice.node_tree.nodes.get('Principled BSDF').inputs['Emission Color']);ice.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.9
shellmat=mat('Frost | transparent ice outer skin','196B93',.18,.0)
shellmat.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.13
shellmat.surface_render_method='DITHERED'
shellmat.use_transparency_overlap=False
shellmat.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.15
ice.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.08
crackmat=mat('Frost | submerged branching ice fractures','60CFE9',.3,0,'178AAD',.12)

def empty(name,parent=None,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.parent=parent;o.location=loc;return o
root=empty('turret_root');head=empty('turret_head',root);barrel=empty('turret_barrel',head);muzzle=empty('muzzle',barrel,(0,-.025,.64))
def finish(o,name,m,parent=None,bevel=0):
    o.name=name;o.parent=parent or root;o.data.materials.append(m)
    if bevel:
        mod=o.modifiers.new('Manufactured softened arris','BEVEL');mod.width=bevel;mod.segments=1 if m==finmat else 2
        if m==finmat:o.data.materials.append(cyan);mod.material=1
        if m in (steel,stone,bronze):
            o.data.materials.append(bronzeedge if m==bronze else edge);mod.material=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def mesh(name,vs,fs,m,parent=None,bevel=0):
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);scene.collection.objects.link(o)
    uv=me.uv_layers.new(name='World grain')
    for po in me.polygons:
        ax=max(range(3),key=lambda i:abs(po.normal[i]));axes=[i for i in range(3) if i!=ax]
        for li in po.loop_indices:
            co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]*3,co[axes[1]]*3)
    return finish(o,name,m,parent,bevel)
def cyl(name,r,depth,z,m,loc=(0,0),verts=64,parent=None,bevel=.002):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=(loc[0],loc[1],z))
    ob=finish(bpy.context.object,name,m,parent,bevel)
    if m==finmat:
        for poly in ob.data.polygons:
            if abs(poly.normal.z)<.15:poly.material_index=1
    return ob
def sector(name,ri,ro,z0,z1,a0,a1,m,n=16,parent=None,bevel=.002):
    vs=[]
    for z in (z0,z1):
        for r in (ri,ro):
            for i in range(n+1):
                a=a0+(a1-a0)*i/n;vs.append((r*math.cos(a),r*math.sin(a),z))
    k=n+1;fs=[]
    for i in range(n):fs.extend([(i,i+1,k+i+1,k+i),(2*k+i,3*k+i,3*k+i+1,2*k+i+1),(i,2*k+i,2*k+i+1,i+1),(k+i,k+i+1,3*k+i+1,3*k+i)])
    fs.extend([(0,k,3*k,2*k),(n,2*k+n,3*k+n,k+n)])
    return mesh(name,vs,fs,m,parent,bevel)
def box(name,loc,scale,m,rotation=0,bevel=.003,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=scale;o.rotation_euler.z=rotation
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m,parent,bevel)
def polar(r,a,z):return (r*math.cos(a),r*math.sin(a),z)
def torus(name,r,tube,z,m,parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=tube,major_segments=96,minor_segments=8,location=(0,0,z))
    return finish(bpy.context.object,name,m,parent)

# Broad base and segmented upper collar, open between structural ribs.
cyl('Low basalt foundation',.318,.055,.0275,stone,verts=48,bevel=.006)
sector('Deep cavity backing',.223,.23,.079,.567,0,math.tau,black,64)
for i in range(12):
    a=i*math.tau/12
    sector(f'Foundation segment {i+1:02}',.237,.321,.055,.108,a+.007,a+math.tau/12-.007,stone,5,bevel=.003)
    sector(f'Upper rim segment {i+1:02}',.247,.323,.531,.578,a+.007,a+math.tau/12-.007,steel,5,bevel=.003)
torus('Upper inner chilled gasket',.247,.005,.576,cyan)
torus('Iris underlight',.284,.004,.588,cyan,barrel)
for i in range(6):
    a=i*math.tau/6
    sector(f'Load bearing rib {i+1}',.235,.321,.10,.544,a-.285,a+.285,stone,5,bevel=.004)
    sector(f'Rib bronze head restraint {i+1}',.310,.328,.507,.582,a-.087,a+.087,bronze,4,bevel=.002)
    sector(f'Rib bronze lower restraint {i+1}',.310,.327,.087,.119,a-.087,a+.087,bronze,4,bevel=.002)
    # Narrow continuous restraint rails join the bronze top shoe to its lower
    # shoe; the broad dark structural rib remains visible between the rails.
    for side in (-1,1):
        ra=a+side*.075
        sector(f'Continuous rib bronze rail {i+1}-{side}',.314,.329,.108,.540,ra-.012,ra+.012,bronze,2,bevel=.0012)
    sector(f'Rib load-bearing lower socket {i+1}',.277,.325,.060,.098,a-.118,a+.118,steel,4,bevel=.003)
    # Actual narrow, deep bays with free standing stacked fins and shadow gaps.
    ca=a+math.pi/6;x,y,_=polar(.263,ca,0)
    cyl(f'Cooling core {i+1}',.034,.399,.322,coremat,(x,y),32,bevel=.002)
    for j in range(12):
        z=.139+j*.032
        cyl(f'Cooling bay {i+1} horizontal fin {j+1:02}',.052,.011,z,finmat,(x,y),32,bevel=.0015)
    for side in (-1,1):
        sa=ca+side*.190
        sector(f'Cooling bay {i+1} recessed jamb {side}',.241,.314,.111,.528,sa-.028,sa+.028,steel,3,bevel=.002)

# Four discrete radial feet. Inclined armor carries recessed narrow coolant glass.
for i in range(4):
    a=i*math.pi/2
    profile=[(.275,.025),(.400,.025),(.401,.063),(.351,.18),(.310,.203),(.275,.133)]
    vs=[]
    for w in (-.063,.063):
        for r,z in profile:vs.append((r*math.cos(a)-w*math.sin(a),r*math.sin(a)+w*math.cos(a),z))
    k=len(profile);fs=[tuple(reversed(range(k))),tuple(range(k,2*k))]+[(j,(j+1)%k,(j+1)%k+k,j+k) for j in range(k)]
    foot=mesh(f'Outrigger foot {i+1}',vs,fs,stone,bevel=.005)
    # Four feet retain their cardinal layout. A low load saddle bridges the
    # six-rib ring into each foot; the two between-rib feet do not gain a tall
    # fake column across a cooling bay.
    sector(f'Foot continuous load saddle {i+1}',.284,.343,.083,.166,a-.23,a+.23,steel,8,bevel=.003)
    for side in (-1,1):
        # Solid diagonal straps connect the upper foot frame with the saddle.
        start=Vector(polar(.317,a,.163));end=Vector(polar(.359,a,.161))
        offset=Vector((-math.sin(a),math.cos(a),0))*side*.039
        mid=(start+end)*.5+offset
        box(f'Foot bronze shoulder bridge {i+1}-{side}',mid,(.054,.014,.025),bronze,a,bevel=.002)
    # inset aligned to the outward descending bevel.
    # Four solid frame members surround a physically recessed window.
    origin=Vector(polar(.370,a,.133))
    u=Vector((math.cos(a)*math.cos(1.11),math.sin(a)*math.cos(1.11),-math.sin(1.11)))
    v=Vector((-math.sin(a),math.cos(a),0));normal=u.cross(v)
    cutter=box('Foot aperture boolean tool',origin+normal*.005,(.120,.055,.045),black,a,bevel=0);cutter.rotation_euler=(0,1.11,a)
    mod=foot.modifiers.new('Actual recessed coolant window','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
    bpy.context.view_layer.objects.active=foot;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    for side in (-1,1):
        ob=box(f'Foot bronze frame jamb {i+1}-{side}',origin+v*(side*.035),(.145,.014,.018),bronze,a,bevel=.002);ob.rotation_euler=(0,1.11,a)
        ob=box(f'Foot bronze frame end {i+1}-{side}',origin+u*(side*.065),(.017,.056,.018),bronze,a,bevel=.002);ob.rotation_euler=(0,1.11,a)
    ob=box(f'Foot aperture shadow {i+1}',origin-normal*.003,(.119,.056,.005),black,a,bevel=.002);ob.rotation_euler=(0,1.11,a)
    ob=box(f'Foot narrow cyan window {i+1}',origin-normal*.0005,(.104,.022,.004),cyan,a,bevel=.001);ob.rotation_euler=(0,1.11,a)

# Six thick, swept blades with a true open gap at every radial cross-section.
# At a given radius each blade occupies < 60 degrees, so adjacent plates never
# overlap even in top projection. The inner tip sweeps 57 degrees forward while
# the outer, broad pivot root stays radial: a spiral of blades, not radial wedges.
def bez(points,t):return sum((Vector(p)*w for p,w in zip(points,[(1-t)**3,3*(1-t)**2*t,3*(1-t)*t*t,t**3])),Vector((0,0)))
def blade_point(v,side):
    radius=.168+.157*v
    center=1.0*(1.0-v)**1.25
    half=.485-.055*(1.0-v)**4
    angle=center+side*half
    return Vector((radius*math.cos(angle),radius*math.sin(angle)))
for j in range(6):
    a=j*math.tau/6;vs=[];N=28;M=10
    for z in (.603,.650):
        for i in range(N+1):
            v=i/N
            for k in range(M+1):
                p=blade_point(v,-1+2*k/M)
                vs.append((p.x*math.cos(a)-p.y*math.sin(a),p.x*math.sin(a)+p.y*math.cos(a),z))
    W=M+1;K=(N+1)*W;fs=[]
    for i in range(N):
        for k in range(M):
            q=i*W+k
            fs.extend([(q,q+1,q+W+1,q+W),(K+q,K+q+W,K+q+W+1,K+q+1)])
        left=i*W;right=left+M
        fs.extend([(left,left+W,K+left+W,K+left),(right,K+right,K+right+W,right+W)])
    for k in range(M):
        q=N*W+k
        fs.extend([(k,K+k,K+k+1,k+1),(q,q+1,K+q+1,K+q)])
    mesh(f'Iris swept shutter {j+1}',vs,fs,steel,barrel,.0035)
    x,y,_=polar(.284,a+.035,.65)
    cyl(f'Pivot shadow seat {j+1}',.024,.007,.654,black,(x,y),32,barrel)
    cyl(f'Bronze shutter pivot {j+1}',.019,.010,.660,bronzeedge,(x,y),40,barrel)
    cyl(f'Pivot inset face {j+1}',.014,.004,.666,bronze,(x,y),40,barrel,.001)

# Wide lens: a shaped, closed shallow dome over a darker deep socket.
cyl('Lens deep dark socket',.175,.080,.557,black,parent=barrel)
torus('Lens bronze-black retaining ring',.168,.007,.603,steel,barrel)
torus('Lens inner coolant ring',.161,.003,.609,cyan,barrel)
vs=[(0,0,.657)];rings=12;sides=96
for rj in range(1,rings+1):
    r=.157*rj/rings;z=.608+.049*(1-(r/.157)**2)**.55
    for i in range(sides):vs.append((r*math.cos(i*math.tau/sides),r*math.sin(i*math.tau/sides),z))
fs=[(0,1+i,1+(i+1)%sides) for i in range(sides)]
for rj in range(rings-1):
    b=1+rj*sides
    for i in range(sides):fs.append((b+i,b+sides+i,b+sides+(i+1)%sides,b+(i+1)%sides))
bottom=len(vs);vs.append((0,0,.58))
for i in range(sides):fs.append((bottom,1+(rings-1)*sides+(i+1)%sides,1+(rings-1)*sides+i))
lens=mesh('Broad transparent ice lens',vs,fs,shellmat,barrel)
inner_vs=[(x*.985,y*.985,.604+(z-.608)*.55) for x,y,z in vs]
inner=mesh('Lens deep blue fractured inner volume',inner_vs,fs,ice,barrel)
for p in inner.data.polygons:p.use_smooth=True
for ob in (lens,inner):
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            co=ob.data.vertices[ob.data.loops[li].vertex_index].co;ob.data.uv_layers.active.data[li].uv=(.5+co.x/.314,.5+co.y/.314)
for p in lens.data.polygons:p.use_smooth=True

# Nonuniform branching hoarfrost patches accumulate at each curved blade tip.
rng=random.Random(629)
for j in range(6):
    a=j*math.tau/6;fvs=[];ffs=[]
    def frost_spike(start,end,width,z):
        delta=end-start;side=Vector((-delta.y,delta.x)).normalized()*width
        idx=len(fvs)
        for q,dz in [(start-side,0),(start+side,0),(end,0),(start+delta*.35,.0018)]:
            fvs.append((q.x*math.cos(a)-q.y*math.sin(a),q.x*math.sin(a)+q.y*math.cos(a),z+dz))
        ffs.extend([(idx,idx+1,idx+3),(idx+1,idx+2,idx+3),(idx+2,idx,idx+3)])
    for k in range(14):
        t=rng.uniform(.025,.28)
        p=blade_point(t,-1)
        radial=p.normalized();tangent=Vector((-radial.y,radial.x))
        length=rng.uniform(.009,.036);end=p+radial*length+tangent*rng.uniform(-.007,.007)
        z=.6508
        frost_spike(p,end,rng.uniform(.001,.0027),z)
        for side in (-1,1):
            start=p+(end-p)*rng.uniform(.3,.65)
            tip=start+radial*length*.28+tangent*(side*length*.23)
            frost_spike(start,tip,.0008,z+.0004)
    mesh(f'Iris branched hoarfrost patch {j+1}',fvs,ffs,rime,head)
# Real fine branching fractures at different depths under the clear outer skin.
for k in range(12):
    a=rng.random()*math.tau;r=rng.uniform(.025,.13)
    center=Vector((r*math.cos(a),r*math.sin(a),.625+rng.uniform(-.007,.009)))
    direction=Vector((math.cos(a+1.1),math.sin(a+1.1),rng.uniform(-.25,.25)))
    pts=[center-direction*.015,center,center+direction*.018+Vector((.005,-.003,.004))]
    for point in pts:
        radial=min(.156,math.hypot(point.x,point.y));ceiling=.608+.049*(1-(radial/.157)**2)**.55-.005
        point.z=min(point.z,ceiling)
    for q in range(2):
        start,end=pts[q],pts[q+1];delta=end-start
        bpy.ops.mesh.primitive_cylinder_add(vertices=4,radius=.00065,depth=delta.length,location=(start+end)*.5)
        ob=bpy.context.object;ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler();finish(ob,f'Deep ice fracture {k+1}-{q}',crackmat,head)

# Match the approved squat cylindrical proportion while preserving horizontal scale.
for ob in [root]+list(root.children_recursive):
    if ob.type=='MESH':
        for v in ob.data.vertices:v.co.z*=.80
    ob.location.z*=.80
# Neutral preview staging; excluded from exports.
world=bpy.data.worlds.new('Frost neutral studio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.095,.11,.13,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.55
for name,loc,energy,size,col in [('Key',(-2,-3,4),320,3,(1,.91,.8)),('Fill',(2,-1,2),130,2,(.66,.82,1)),('Rim',(0,3,3),240,2,(.75,.87,1))]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.data.color=col;o.rotation_euler=(Vector((0,0,.32))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Preview ground';floor.location.z=-.008;floor.data.materials.append(mat('Preview neutral charcoal','303334',.85))
bpy.ops.object.camera_add(location=(1.35,-1.85,1.7));camera=bpy.context.object;camera.name='Preview camera';camera.data.type='ORTHO';camera.data.ortho_scale=1.10;scene.camera=camera
camera.location=(1.35,-1.85,1.85);camera.rotation_euler=(Vector((0,0,.25))-camera.location).to_track_quat('-Z','Y').to_euler()
def render(view='hero'):
    camera.location=(1.35,-1.85,1.85) if view=='hero' else (0,-.001,3)
    camera.rotation_euler=(Vector((0,0,.25))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'detail-{view}.png');bpy.ops.render.render(write_still=True)
def export():
    displaced=[]
    displaced_materials=[]
    for m in {m for o in root.children_recursive if o.type=='MESH' for m in o.data.materials}:
        name=m.name.split('.')[0]
        while name.startswith('refined_'):name=name[len('refined_'):]
        old=bpy.data.materials.get(name)
        if old and old!=m:
            displaced_materials.append((old,name,m));old.name='Archived prototype '+old.name
        m.name=name
    for o,name in [(root,'turret_root'),(head,'turret_head'),(barrel,'turret_barrel'),(muzzle,'muzzle')]:
        old=bpy.data.objects.get(name)
        if old and old!=o:
            displaced.append((old,name));old.name='preserved_original_'+name
        o.name=name
    for o in list(barrel.children):
        if o.type=='MESH':o.parent=head
    for img in bpy.data.images:
        if img.filepath and img.users:img.pack()
    bpy.data.libraries.write(str(OUT/'frost.blend'),{scene},fake_user=True,compress=True)
    originals=[o for o in root.children_recursive if o.type=='MESH']
    groups={}
    for o in originals:
        key=(o.parent,'skin' if shellmat in list(o.data.materials) else 'solid')
        cp=o.copy();cp.data=o.data.copy();scene.collection.objects.link(cp)
        # Joining differently named UV layers creates default-filled UV0 data.
        # Preserve each source's active-render coordinates as a single common UV0.
        if cp.data.uv_layers:
            active=next((uv for uv in cp.data.uv_layers if uv.active_render),cp.data.uv_layers.active)
            coords=[tuple(loop.uv) for loop in active.data]
            for uv in list(cp.data.uv_layers):cp.data.uv_layers.remove(uv)
            uv=cp.data.uv_layers.new(name='UVMap')
            for loop,co in zip(uv.data,coords):loop.uv=co
            uv.active_render=True;cp.data.uv_layers.active_index=0
        groups.setdefault(key,[]).append(cp)
    merged=[]
    for (parent,kind),objects in groups.items():
        for o in bpy.data.objects:o.select_set(False)
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        ob=objects[0];ob.name=('Frost fixed body' if parent==root else 'Frost fixed iris')+' '+kind
        merged.append(ob)
    for o in bpy.data.objects:o.select_set(False)
    for o in [root,head,barrel,muzzle]+merged:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'frost.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    payload=(OUT/'frost.glb').read_bytes();gltf=json.loads(payload[20:20+struct.unpack_from('<I',payload,12)[0]])
    tris=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
    surfaces=sum(len(set(p.material_index for p in o.data.polygons)) for o in merged)
    mats=set(m.name for o in merged for m in o.data.materials)
    for o in merged:bpy.data.objects.remove(o,do_unlink=True)
    for old,name in displaced:
        bpy.data.objects[name].name='frost_production_'+name
        old.name=name
    for old,name,new in displaced_materials:
        new.name='refined_'+name
        old.name=name
    bpy.context.view_layer.update()
    coords=[o.matrix_world@Vector(c) for o in originals for c in o.bound_box]
    dimensions=[max(c[i] for c in coords)-min(c[i] for c in coords) for i in range(3)]
    (OUT/'model_audit.json').write_text(json.dumps({'triangles':tris,'sha256':hashlib.sha256(payload).hexdigest(),'embedded_images':len(gltf.get('images',[])),'runtime_nodes':len(gltf.get('nodes',[])),'editable_meshes':len(originals),'runtime_meshes':len(groups),'runtime_surfaces':surfaces,'materials':sorted(mats),'dimensions_blender_xyz':dimensions,'glb_bytes':(OUT/'frost.glb').stat().st_size,'rig':['turret_root','turret_head','turret_barrel','muzzle'],'structure':{'shutters':6,'ribs':6,'cooling_bays':6,'fins_per_bay':12,'feet':4}},indent=2))

export()
print('FROST_MODEL_READY',scene.name)
