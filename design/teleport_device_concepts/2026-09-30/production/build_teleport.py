"""Editable Blender portal source; run with Blender --background --factory-startup.

Default builds a NEW standalone file. --render-still / --render-loop open the
saved source, preserving manual edits. No runtime or game assets are written.
"""
import bpy, bmesh, math, json, sys, random
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / 'design/stage1_3d/surface_effects/terrain-surface.blend'
BLEND = HERE / 'teleport-four-variants.blend'
TAU = math.tau
PERIOD = 96

def mat(name, color, metal=0, rough=.4, emission=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    p.inputs['Emission Color'].default_value=(*color,1)
    p.inputs['Emission Strength'].default_value=emission
    return m

def mesh(name,verts,faces,material,collection):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); collection.objects.link(ob)
    if material: me.materials.append(material)
    return ob

def bevel(ob, width=.004):
    mod=ob.modifiers.new('Machined edge radius','BEVEL'); mod.width=width; mod.segments=3
    mod=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')

def polyline(name,pts,radius,material,col):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.bevel_depth=radius; cu.bevel_resolution=2
    s=cu.splines.new('POLY'); s.points.add(len(pts)-1)
    for p,co in zip(s.points,pts): p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu); col.objects.link(ob); cu.materials.append(material)
    return ob

def octagon(half,cut):
    return [(-half+cut,-half),(half-cut,-half),(half,-half+cut),(half,half-cut),
            (half-cut,half),(-half+cut,half),(-half,half-cut),(-half,-half+cut)]

def ring(name,outer,inner,z0,z1,material,col):
    vs=[(x,y,z) for z in (z0,z1) for loop in (outer,inner) for x,y in loop]
    fs=[]
    for i in range(8):
        j=(i+1)%8
        fs.extend([(16+i,16+j,24+j,24+i),(i,j,16+j,16+i),(8+j,8+i,24+i,24+j),(j,i,8+i,8+j)])
    ob=mesh(name,vs,fs,material,col); bevel(ob,.003); return ob

def driver(sock,expression):
    sock.driver_add('default_value').driver.expression=expression

def vortex_material(name,color,is_out):
    m=mat(name,color,metal=0,rough=.85)
    n=m.node_tree.nodes; l=m.node_tree.links; p=n.get('Principled BSDF'); p.inputs['Specular IOR Level'].default_value=.015
    uv=n.new('ShaderNodeTexCoord'); sep=n.new('ShaderNodeSeparateXYZ'); l.new(uv.outputs['UV'],sep.inputs[0])
    def op(operation,a,b=None):
        x=n.new('ShaderNodeMath'); x.operation=operation
        if isinstance(a,(int,float)): x.inputs[0].default_value=a
        else:l.new(a,x.inputs[0])
        if b is not None:
            if isinstance(b,(int,float)):x.inputs[1].default_value=b
            else:l.new(b,x.inputs[1])
        return x.outputs[0]
    # UV.x is radius, UV.y is polar angle. Curved radial bands have three arms.
    r=sep.outputs['X']; angle=sep.outputs['Y']
    turbulence=n.new('ShaderNodeTexNoise');turbulence.inputs['Scale'].default_value=5;turbulence.inputs['Detail'].default_value=4;turbulence.inputs['Roughness'].default_value=.7
    l.new(uv.outputs['Generated'],turbulence.inputs['Vector'])
    twist=9 if is_out else 13
    spiral=op('ADD',op('SUBTRACT',op('MULTIPLY',angle,TAU*3),op('MULTIPLY',r,twist)),op('MULTIPLY',op('SUBTRACT',turbulence.outputs['Fac'],.5),.9))
    # Outflow broadens and brightens towards its leading outer edge; inflow
    # fades at the throat and keeps its broad trailing sheet outside it.
    exponent=op('ADD',op('MULTIPLY',r,-3 if is_out else 3),6 if is_out else 2)
    arms=op('POWER',op('MULTIPLY',op('ADD',op('COSINE',spiral),1),.5),exponent)
    fine=op('POWER',op('MULTIPLY',op('ADD',op('COSINE',op('ADD',op('MULTIPLY',spiral,4),op('MULTIPLY',turbulence.outputs['Fac'],6))),1),.5),3)
    time=n.new('ShaderNodeValue');time.label='4 second radial advection, direction is semantic'
    driver(time.outputs[0],f'(frame-1)/96*{TAU*3}*{1 if is_out else -1}')
    pulse=op('SUBTRACT',op('MULTIPLY',r,TAU*3),time.outputs[0])
    pulse=op('ADD',op('MULTIPLY',op('SINE',pulse),.38),.62)
    if is_out:
        radial=op('ADD',op('MULTIPLY',op('POWER',r,1.5),.85),.15)
    else:
        radial=op('MULTIPLY',op('MINIMUM',op('MULTIPLY',r,7),1),op('SUBTRACT',1,op('MULTIPLY',r,.42)))
    visible=op('MULTIPLY',op('MULTIPLY',op('MULTIPLY',arms,pulse),radial),op('ADD',.72,op('MULTIPLY',fine,.28)))
    visible=op('MULTIPLY',visible,op('MINIMUM',1,op('MAXIMUM',0,op('MULTIPLY',op('SUBTRACT',1.09,r),7))))
    if is_out: visible=op('ADD',visible,op('MULTIPLY',op('EXPONENT',op('MULTIPLY',r,-23)),1.1))
    ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=0;ramp.color_ramp.elements[0].color=(color[0]*.015,color[1]*.015,color[2]*.03,1)
    ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(color[0]*1.35,color[1]*1.35,color[2]*1.35,1)
    mid=ramp.color_ramp.elements.new(.3);mid.color=(color[0]*.09,color[1]*.09,color[2]*.16,1)
    l.new(visible,ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color']);l.new(ramp.outputs[0],p.inputs['Emission Color'])
    p.inputs['Emission Strength'].default_value=2.4
    noise=n.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=85; noise.inputs['Detail'].default_value=2
    l.new(uv.outputs['Generated'],noise.inputs['Vector'])
    bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.02; bump.inputs['Distance'].default_value=.0003
    l.new(noise.outputs[0],bump.inputs['Height']); l.new(bump.outputs[0],p.inputs['Normal'])
    return m

def surface(name,is_out,material,col):
    nr,na=42,192; vs=[]; uvs=[]
    for j in range(nr+1):
        q=max(.0001,j/nr)
        for i in range(na+1):
            a=TAU*i/na
            edge=.434/(abs(math.cos(a))**12+abs(math.sin(a))**12)**(1/12)
            r=q*edge
            z=(.002+.025*(1-q)**1.6) if is_out else (-.005-.092*(1-q)**2)
            z+=.002*math.sin(3*a-12*q)*q*(1-q)
            vs.append((r*math.cos(a),r*math.sin(a),z));uvs.append((r/.434,i/na))
    fs=[]
    for j in range(nr):
        for i in range(na):
            k=j*(na+1)+i;fs.append((k,k+1,k+na+2,k+na+1))
    ob=mesh(name,vs,fs,material,col); uv=ob.data.uv_layers.new(name='PolarRadiusAngle')
    for p in ob.data.polygons:
        p.use_smooth=True
        for li in p.loop_indices:uv.data[li].uv=uvs[ob.data.loops[li].vertex_index]
    return ob

def sphere(name,radius,loc,material,col):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=radius,location=loc)
    ob=bpy.context.object;ob.name=name
    for c in list(ob.users_collection): c.objects.unlink(ob)
    col.objects.link(ob);ob.data.materials.append(material)
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def build():
    if BLEND.exists(): raise RuntimeError('Source already exists: use explicit backup before rebuilding; render flags preserve edits')
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    sc=bpy.context.scene;sc.name='Teleport • Four Variant Comparison'
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.objects=['path_tile_natural_surface']
    path=dst.objects[0];path.parent=None
    # Reuse current chapter 1 tile side mesh, top align exactly to Z=0.
    top=max(v.co.z for v in path.data.vertices)
    for v in path.data.vertices:v.co.z-=top
    path.location=(0,0,0);path.rotation_euler=(0,0,0);path.scale=(1,1,1)
    # Actual imported terrain uses distinct side/top material slots.
    side=path.copy();side.data=path.data.copy();side.name='Shared existing terrain sides';sc.collection.objects.link(side)
    bm=bmesh.new();bm.from_mesh(side.data);bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index!=0],context='FACES');bm.to_mesh(side.data);bm.free()
    bronze=mat('Aged bronze / narrow frame',(.16,.073,.024),.72,.5)
    dark=mat('Frame inset / dark steel',(.023,.031,.038),.68,.38)
    edge=mat('Polished bronze edge',(.39,.22,.085),.8,.26)
    void=mat('IN recessed dark throat',(.0003,.0006,.0016),.1,.42)
    variants=[]
    for idx,(label,color,out,x,y) in enumerate([
        ('BLUE IN',(.006,.19,1),False,-1.87,.91),('BLUE OUT',(.006,.19,1),True,.83,.91),
        ('ORANGE IN',(1,.14,.002),False,-1.87,-.91),('ORANGE OUT',(1,.14,.002),True,.83,-.91)]):
        col=bpy.data.collections.new(label);sc.collection.children.link(col)
        root=bpy.data.objects.new(label.replace(' ','_'),None);col.objects.link(root)
        root['variant']=label;root['flow_direction']='center_to_edge' if out else 'edge_to_center'
        root['footprint']='1 x 1';root['surface_height']=0.;root['loop_frames']=PERIOD
        stone=side.copy();stone.data=side.data;col.objects.link(stone);stone.name=label+' / existing stacked stone sides'
        ring(label+' / bronze perimeter',octagon(.5,.065),octagon(.437,.05),-.017,.013,bronze,col)
        ring(label+' / inner shadow channel',octagon(.444,.05),octagon(.431,.05),-.021,.009,dark,col)
        polyline(label+' / bronze outer seam',[(a,b,.015) for a,b in octagon(.498,.065)+octagon(.498,.065)[:1]],.0018,edge,col)
        glow=mat(label+' / rune emission',color,metal=.2,rough=.25,emission=5)
        filament=mat(label+' / subtle flow filaments',tuple(c*.15 for c in color),rough=.8,emission=.9)
        head=mat(label+' / traveling white core',tuple(.58+.42*c for c in color),rough=.25,emission=8)
        polyline(label+' / inner luminous seal',[(a,b,.016) for a,b in octagon(.433,.05)+octagon(.433,.05)[:1]],.0032,glow,col)
        for side_idx in range(4):
            a=side_idx*TAU/4
            def orient(u,v,z=.018):return (u*math.cos(a)-v*math.sin(a),u*math.sin(a)+v*math.cos(a),z)
            for j,points in enumerate([[(-.034,.478),(-.034,.455),(.034,.478),(.034,.455),(-.034,.478)],
                                        [(-.022,.466),(0,.481),(.022,.466),(0,.452),(-.022,.466)]]):
                if j==side_idx%2:polyline(label+f' / cardinal rune {side_idx}',[orient(*p) for p in points],.0018,glow,col)
            for sign in [-1,1]:
                polyline(label+f' / plate seam {side_idx} {sign}',[orient(sign*.36,.44),orient(sign*.4,.496)],.0015,dark,col)
            for offset in [-.28,-.15,.15,.28]:sphere(label+' / frame rivet',.0031,orient(offset,.477),edge,col)
            # Four small corner glyphs rather than extra plinths.
            ca=a+math.pi/4;cx=.457*math.cos(ca)*1.414;cy=.457*math.sin(ca)*1.414
            pts=[(cx+.013*math.cos(t),cy+.013*math.sin(t),.019) for t in [0,math.pi/2,math.pi,3*math.pi/2,TAU]]
            polyline(label+' / corner rune',pts,.0017,glow,col)
        surface(label+' / editable 3D vortex bowl' if not out else label+' / editable 3D low outflow',out,vortex_material(label+' / radial flow shader',color,out),col)
        if out:
            center=sphere(label+' / luminous emergence',.017,(0,0,.026),head,col);center.scale.z=.3
        for arm in range(3):
            for packet in range(5):
                ob=sphere(label+f' / moving radial light {arm}.{packet}',.004,(0,0,0),glow,col)
                for f in range(1,PERIOD+2):
                    t=((f-1)/PERIOD+packet/5)%1
                    q=.055+.9*(t if out else 1-t);a=arm*TAU/3+(3 if out else 13/3)*q
                    r=.428*q;z=(.014+.028*(1-q)**1.6) if out else (.003-.088*(1-q)**2)
                    ob.location=(r*math.cos(a),r*math.sin(a),z)
                    fade=max(.001,min(t/.09,(1-t)/.09,1))
                    ob.scale=(fade,fade,fade*.52)
                    ob.keyframe_insert('location',frame=f);ob.keyframe_insert('scale',frame=f)
        for ob in list(col.objects):
            if ob!=root:ob.parent=root
        root.location=(x,y,0);variants.append(root)
        ref=path.copy();ref.data=path.data;sc.collection.objects.link(ref);ref.name=label+' / CONTEXT adjacent path';ref.location=(x+1,y,0)
        # Scene typography is kept outside asset collections.
        cu=bpy.data.curves.new(label+' caption','FONT');cu.body=label;cu.align_x='CENTER';cu.size=.13;cu.extrude=.0001
        txt=bpy.data.objects.new(label+' caption',cu);sc.collection.objects.link(txt);txt.location=(x+.5,y+.66,.035);cu.materials.append(mat(label+' caption',tuple(.55+.45*c for c in color),rough=.7,emission=.5))
    bpy.data.objects.remove(side,do_unlink=True);bpy.data.objects.remove(path,do_unlink=True)
    world=bpy.data.worlds.new('Deep navy studio');sc.world=world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.007,.012,.025,1);world.node_tree.nodes['Background'].inputs[1].default_value=.3
    for name,loc,energy,size,color in [('Large warm key',(-3,-4,7),550,8,(1,.83,.65)),('Cool rim',(2,4,6),450,8,(.43,.66,1))]:
        bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(0,-6.8,11));camera=bpy.context.object;camera.name='Comparison camera';camera.rotation_euler=(Vector((0,0,-.02))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=5.25;sc.camera=camera
    sc.render.engine='CYCLES';sc.cycles.samples=32;sc.cycles.use_denoising=True
    sc.render.resolution_x=1600;sc.render.resolution_y=1080;sc.render.resolution_percentage=100
    sc.render.fps=24;sc.frame_start=1;sc.frame_end=96;sc.frame_set(1)
    sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast'
    sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
    # Blender 5 compositor is a node group; glow is render presentation only.
    group=bpy.data.node_groups.new('Portal restrained optical glow','CompositorNodeTree');sc.compositing_node_group=group
    group.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    layers=group.nodes.new('CompositorNodeRLayers');glare=group.nodes.new('CompositorNodeGlare');glare.inputs['Type'].default_value='Fog Glow';glare.inputs['Quality'].default_value='High'
    glare.inputs['Threshold'].default_value=1.3;glare.inputs['Strength'].default_value=.45
    output=group.nodes.new('NodeGroupOutput');group.links.new(layers.outputs['Image'],glare.inputs['Image']);group.links.new(glare.outputs['Image'],output.inputs['Image'])
    readme=bpy.data.texts.new('START HERE — Teleport source')
    readme.write('Approved reference: ../12-in-out-vortex-single-tile.png\nFour editable collections: BLUE IN, BLUE OUT, ORANGE IN, ORANGE OUT.\n96 frames at 24fps; frame 97 equals frame 1. Real shallow bowl / low dome geometry.\nAnimated lights move edge→center for IN, center→edge for OUT. Radial shader pulses match.\nCONTEXT adjacent path objects / captions / lights / camera are presentation only.\nNo game assets modified. Procedural shader + compositor require engine adaptation.\nSee production/README.md.\n')
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print('PORTAL_BUILD_DONE',BLEND,flush=True)

def render_still():
    sc=bpy.context.scene;sc.frame_set(17);sc.render.filepath=str(HERE/'four-variants.png')
    bpy.ops.render.render(write_still=True)

def render_loop():
    sc=bpy.context.scene;sc.render.resolution_percentage=60;sc.cycles.samples=12
    sc.render.filepath=str(HERE/'_frames/frame-');sc.render.image_settings.file_format='PNG'
    (HERE/'_frames').mkdir(exist_ok=True);bpy.ops.render.render(animation=True)

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if '--render-still' in args or '--render-loop' in args:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
else:build()
if '--render-loop' in args:render_loop()
else:render_still()
