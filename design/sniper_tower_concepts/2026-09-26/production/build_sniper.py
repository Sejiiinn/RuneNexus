"""Approved C vertical sniper. Execute build() through Blender MCP.
Reuses the runic-fire bpy geometry helpers; never modifies game assets.
"""
import bpy, math, json, random
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
OUT=ROOT/'design/sniper_tower_concepts/2026-09-26/production'
HELPERS=ROOT/'design/fire_tower_concepts/runic_3d/build_model.py'
ns={};exec(compile(HELPERS.read_text(),str(HELPERS),'exec'),ns)
mesh,cube,cyl,ring,profile_x,loft,empty,metal,emissive=[ns[k] for k in ['mesh','cube','cyl','ring','profile_x','loft','empty','metal','emissive']]

def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c

def tapered(name,r0,r1,z0,z1,mat,parent,col,bevel=.005):
    vs=[(r*math.cos(math.pi/8+i*math.pi/4),r*math.sin(math.pi/8+i*math.pi/4),z) for r,z in [(r0,z0),(r1,z1)] for i in range(8)]
    fs=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    return mesh(name,vs,fs,mat,col,parent,bevel)

def stroke(name,points,width,mat,parent,col):
    for i,(a,b) in enumerate(zip(points[:-1],points[1:])):
        a,b=Vector(a),Vector(b);o=cyl(name+' %02d'%i,width/2,(b-a).length,(a+b)/2,mat,col,parent,8,bevel=.0004)
        o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()

def bolt(name,loc,parent,col,axis='Y',rad=.008):
    o=cyl(name,rad,.005,loc,bronze,col,parent,8,axis,.0007)
    return o

def satin(name,color,metallic,roughness):
    m=bpy.data.materials.new(name);m.use_nodes=True;nodes=m.node_tree.nodes;links=m.node_tree.links
    p=nodes.get('Principled BSDF');p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
    p.inputs['Base Color'].default_value=(*color,1)
    noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=95;noise.inputs['Detail'].default_value=1
    ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=tuple(c*.94 for c in color)+(1,);ramp.color_ramp.elements[1].color=tuple(c*1.06 for c in color)+(1,)
    links.new(noise.outputs['Fac'],ramp.inputs[0]);links.new(ramp.outputs[0],p.inputs['Base Color'])
    fine=nodes.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=280;fine.inputs['Detail'].default_value=1
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.075;bump.inputs['Distance'].default_value=.00018
    links.new(fine.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs[0],p.inputs['Normal'])
    return m

def flat_inlay(name,points,width,mat,parent,col,normal):
    n=Vector(normal).normalized();depth=.0005
    for i,(a,b) in enumerate(zip(points[:-1],points[1:])):
        a,b=Vector(a),Vector(b);w=n.cross((b-a).normalized()).normalized()*width/2
        vs=[tuple(p+u*w+v*n*depth/2) for p in [a,b] for u,v in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        fs=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        mesh(name+' %02d'%i,vs,fs,mat,col,parent,0)

def build():
    global scene,base,carriage,gunparts,studio,root,head,gun,iron,silver,bronze,dark,rune
    scene=bpy.data.scenes.new('Sniper C — Vertical production');bpy.context.window.scene=scene
    ns['scene']=scene
    base=collection('C01 Fixed vertical foundation');carriage=collection('C02 Rotating crescent cradle');gunparts=collection('C03 Recoiling precision rifle');studio=collection('C90 Presentation only')
    root=empty('turret_root',base);head=empty('turret_head',carriage,root);head.location.z=.45
    gun=empty('turret_barrel',gunparts,head)
    iron=satin('C | blue grey forged steel',(.066,.091,.119),.88,.34)
    silver=satin('C | worn silver edge armour',(.37,.385,.395),.94,.26)
    bronze=satin('C | restrained aged bronze',(.28,.181,.080),.85,.33)
    dark=satin('C | dark mechanical recess',(.013,.021,.029),.80,.40)
    rune=emissive('C | cyan runic inlay',(.035,.63,1),2.2)
    # Tall centered upright octagonal plinth; only taper, no lean.
    tapered('Foot collar dark sole',.237,.226,.007,.062,dark,root,base,.006)
    tapered('Thick silver foundation rim',.230,.219,.025,.089,silver,root,base,.009)
    tapered('Vertical octagonal steel column',.214,.131,.068,.585,iron,root,base,.005)
    tapered('Top steel shoulder collar',.146,.143,.547,.604,silver,root,base,.005)
    # Silver strips emphasize the long upright silhouette, actual raised metal.
    for i in range(8):
        a=math.pi/8+i*math.pi/4
        stroke('Column structural arris %02d'%i,[(.212*math.cos(a),.212*math.sin(a),.083),(.134*math.cos(a),.134*math.sin(a),.565)],.012,silver,root,base)
    # Three broad splayed feet, 120 degrees apart, with shaped toe guards.
    pts=[(.153,.028),(.397,.014),(.407,.046),(.351,.206),(.300,.246),(.176,.185)]
    guard=[(.303,.030),(.397,.014),(.407,.046),(.351,.206),(.311,.235),(.285,.202)]
    for i,a in enumerate([math.pi,math.pi/3,5*math.pi/3]):
        anchor=empty('Fixed support %d'%(i+1),base,root);anchor.rotation_euler.z=a
        profile_x('Broad steel tripod foot %d'%i,pts,.150,0,iron,base,anchor,.009)
        toe=profile_x('Silver toe armour %d'%i,guard,.160,0,silver,base,anchor,.006)
        toe.location.y=.003;toe.location.z=.001
        for side in [-1,1]:
            for y,z in [(.330,.100),(.306,.185)]:bolt('Foot fastener',(side*.083,y,z),anchor,base,'X',.006)
    # Four large, readable inlaid glyphs sit on the actual sloping pillar faces.
    for k,a in enumerate([math.pi/4,5*math.pi/4]):
        group=empty('Column rune face %d'%k,base,root);group.rotation_euler.z=a
        def pp(x,z):return (x,-((.214-(z-.068)/.517*.083)*math.cos(math.pi/8)+.0003),z)
        paths=[[(0,.414),(.034,.364),(0,.315),(-.034,.364),(0,.414)],[(0,.315),(.022,.283),(0,.258),(-.021,.283),(0,.315)],[(0,.258),(0,.165)],[(0,.281),(.024,.247)]]
        for j,path in enumerate(paths):
            points=[pp(x,z) for x,z in path]
            flat_inlay('Recessed rune channel %d %d'%(k,j),points,.009,dark,group,base,(0,-1,.15))
            points=[(x,y-.0006,z) for x,y,z in points]
            flat_inlay('Large cyan pillar glyph %d %d'%(k,j),points,.0048,rune,group,base,(0,-1,.15))
        for x,z in [(-.043,.49),(.043,.49),(-.063,.122),(.063,.122)]:
            p=pp(x,z);bolt('Pillar panel rivet',p,group,base,rad=.0045)
    # User feedback: lower only the vertical column; feet and gun stay full size.
    bpy.context.view_layer.update()
    for o in base.objects:
        if o.type!='MESH':continue
        ancestor=o.parent;is_foot=False
        while ancestor:
            if ancestor.name.startswith('Fixed support'):is_foot=True
            ancestor=ancestor.parent
        if is_foot:continue
        mw=o.matrix_world.copy();inv=mw.inverted()
        for v in o.data.vertices:
            p=mw@v.co
            if p.z>.08:p.z=.08+(p.z-.08)*(.45-.08)/(.60-.08)
            v.co=inv@p
    # Ring and yoke above this point rotate independently of fixed pillar.
    cyl('Turntable bearing shadow',.147,.038,(0,0,.013),dark,carriage,head,32,bevel=.005)
    ring('Narrow bronze bearing seam',.150,.136,.013,(0,0,.036),bronze,carriage,head,32,bevel=.002)
    cyl('Eight sided rotation drum',.132,.041,(0,0,.058),iron,carriage,head,16,bevel=.006)
    swift_ns={}
    exec(compile((OUT/'swift_receiver.py').read_text(),str(OUT/'swift_receiver.py'),'exec'),swift_ns)
    swift_ns['build_swift'](globals())
    # Single long precision barrel, tapered in width; no shortening of concept.
    barrelz=.326
    collar=loft('Squared receiver throat',[(-.348,.064,.061),(-.154,.070,.064)],dark,gunparts,gun,.005);collar.location.z=barrelz
    for y in [-.315,-.178]:
        ring('Silver barrel retaining band',.081,.062,.033,(0,y,barrelz),silver,gunparts,gun,8,'Y',.003,math.pi/8)
    jacket=loft('Tapered silver barrel shroud',[(-.532,.041,.040),(-.340,.057,.052)],silver,gunparts,gun,.003);jacket.location.z=barrelz
    tube=loft('Long slender octagonal precision barrel',[(-.995,.024,.024),(-.530,.031,.031)],silver,gunparts,gun,.002);tube.location.z=barrelz
    # Thin dark dorsal rib and two joining collars make the long barrel read.
    cube('Fine dark dorsal barrel groove',(0,-.749,barrelz+.028),(.009,.404,.006),dark,gunparts,gun,.001)
    for y,ra in [(-.542,.039),(-.975,.032)]:ring('Dark precision barrel collar',ra,ra-.011,.021,(0,y,barrelz),dark,gunparts,gun,8,'Y',.0015,math.pi/8)
    for s in [-1,1]:
        for y in [-.423,-.260]:bolt('Receiver fastener',(s*.061,y,barrelz+.008),gun,gunparts,'X',.004)
    cube('Square silver muzzle tip',(0,-1.024,barrelz),(.079,.100,.075),silver,gunparts,gun,.008)
    cube('Dark muzzle frontal cap',(0,-1.078,barrelz),(.070,.027,.067),dark,gunparts,gun,.005)
    for s in [-1,1]:cube('Twin cyan muzzle aperture',(s*.018,-1.094,barrelz),(.011,.005,.036),rune,gunparts,gun,.002)
    cube('Muzzle split spine',(0,-1.096,barrelz),(.008,.009,.053),silver,gunparts,gun,.001)
    muzzle=empty('muzzle',gunparts,gun);muzzle.location=(0,-1.099,barrelz)
    # A simple separate tile gives contact and scale without becoming an asset.
    stone=metal('Studio | muted moss slate',(.081,.111,.071),0,.96)
    cube('Single square placement tile',(0,0,-.050),(1.03,1.03,.090),stone,studio,None,.030)
    floor=metal('Studio | dark green floor',(.026,.047,.039),0,.96)
    cube('Backdrop',(0,0,-.114),(200,200,.030),floor,studio,None,.0)
    scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('C Studio atmosphere');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.20,.25,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    for name,pos,power,size,color in [('C warm key',(-3,-4,5),450,3.2,(1,.89,.76)),('C soft fill',(4,-1,4),300,3,(.73,.83,1)),('C rim',(-1,3,4),380,2.5,(1,.87,.67))]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=size;d.color=color;o=bpy.data.objects.new(name,d);studio.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.45))-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new('C Camera');o=bpy.data.objects.new('C Camera',d);studio.objects.link(o);d.type='ORTHO';d.ortho_scale=1.85;scene.camera=o
    camera('hero')
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=.6
    scene.render.image_settings.file_format='PNG'
    reference=bpy.data.images.load(str(OUT.parent/'receiver-variants/01-swept-wedge.png'),check_existing=True);reference.name='APPROVED — 01 SWIFT swept wedge';reference.pack()
    scene['approved_reference']=str(OUT.parent/'receiver-variants/01-swept-wedge.png');scene['source_user_request']='1번 정도면 될 것 같아. 그렇게 수정해줘. 그리고 탑뷰 시점도 한 장 찍어서 보여줘'
    scene['coordinate_contract']='Z up / -Y forward; root fixed column and feet; head z=.45; barrel local position zero; muzzle points -Y'
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
    bpy.data.libraries.write(str(OUT/'sniper-c-editable.blend'),{scene,reference},fake_user=True,compress=True)
    print('C build saved',len(scene.objects),'objects; existing Blender scenes retained')
    return scene

def camera(view):
    s=bpy.context.scene;t=Vector((0,-.24,.48))
    if view=='top':
        s.camera.location=(0,-.28,5);s.camera.rotation_euler=(0,0,0);s.camera.data.ortho_scale=1.85;s.render.filepath=str(OUT/'sniper-c-top.png');return
    loc={'hero':(3.4,-4.1,3.1),'rear':(-3.4,4.1,3.1),'drone':(2.9,-3.8,6.3),'side':(4.5,-.1,1.9)}[view]
    s.camera.location=loc;s.camera.rotation_euler=(t-s.camera.location).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=str(OUT/('sniper-c-'+view+'.png'))

if __name__=='__main__':build()
