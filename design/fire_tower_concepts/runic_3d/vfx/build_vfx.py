"""Editable standalone VFX preview. No game integration or export."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d')
OUT=ROOT/'vfx'
FPS=24
END=144
SHOTS=(30,94)

def keyscale(o,f,s):
    o.scale=(s,s,s) if isinstance(s,(int,float)) else s
    o.keyframe_insert(data_path='scale',frame=f)

def setup():
    s=bpy.context.scene
    s.name='Rune Flame Turret — VFX Preview'
    s.frame_start=1;s.frame_end=END;s.render.fps=FPS
    s.render.engine='CYCLES'
    s.render.resolution_x=960;s.render.resolution_y=640;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'
    s.render.film_transparent=False
    s.render.engine='BLENDER_EEVEE'
    s.eevee.taa_render_samples=32
    s.eevee.volumetric_samples=48
    s.eevee.volumetric_tile_size='4'
    s.eevee.use_volume_custom_range=True
    s.eevee.volumetric_start=.1;s.eevee.volumetric_end=12
    s.camera.location=(4,-3.2,2.9)
    s.camera.rotation_euler=(Vector((0,-.60,.58))-s.camera.location).to_track_quat('-Z','Y').to_euler()
    s.camera.data.ortho_scale=2.65
    s.view_settings.exposure=-.35
    coll=bpy.data.collections.new('05 Animated Fire VFX');s.collection.children.link(coll)
    gun=s.objects['turret_barrel']
    ns={};exec(compile((ROOT/'finish_flames.py').read_text(),'finish_flames.py','exec'),ns)
    tongue=ns['_tongue'];firemat=ns['_flame_material']
    orange=firemat('VFX | orange flame volume')
    golden=firemat('VFX | hot golden core',True)
    # Animate spatial noise so the flame texture flows, not merely a rigid wobble.
    mats=[m for m in bpy.data.materials if m.use_nodes and ('Flame_Finish' in m.name or m.name.startswith('VFX |'))]
    for m in mats:
        for n in m.node_tree.nodes:
            if n.type=='TEX_NOISE':
                n.noise_dimensions='4D'
                n.inputs['W'].default_value=0;n.inputs['W'].keyframe_insert('default_value',frame=1)
                n.inputs['W'].default_value=5;n.inputs['W'].keyframe_insert('default_value',frame=END)
    def ripple(o,phase):
        basis=o.shape_key_add(name='Rest')
        for k in range(2):
            sk=o.shape_key_add(name='Flow '+str(k+1))
            height=max(v.co.z for v in o.data.vertices)
            for src,dst in zip(basis.data,sk.data):
                t=max(0,src.co.z/height)
                dst.co.x+=.016*t*math.sin(t*8+phase+k*2.2)
                dst.co.y+=.009*t*math.sin(t*11+phase+k*3)
            for f in range(1,END+2,3):
                sk.value=.5+.5*math.sin(f*.32+phase+k*math.pi)
                sk.keyframe_insert('value',frame=f)
    for i,o in enumerate(list(bpy.data.collections['04 Flame Study'].objects)):
        if 'Top_' in o.name and 'Ember' not in o.name:
            ripple(o,i*1.3)
            for f in range(1,END+2,3):
                pulse=sum(math.exp(-((f-shot-2)/5)**2) for shot in SHOTS)
                keyscale(o,f,(1+.08*math.sin(f*.4+i),1+.06*math.cos(f*.3+i),.92+.13*math.sin(f*.31+i)+.2*pulse))
        elif 'Muzzle' in o.name:
            for f in range(1,END+1):
                a=min((f-shot for shot in SHOTS if f>=shot),default=1000)
                power=(2.5*math.exp(-a/3.2) if a<15 else 0)+.12
                keyscale(o,f,(power,power,power*1.3))
            if 'Ember' not in o.name:ripple(o,i)
        elif 'Ember_Top' in o.name:
            origin=o.location.copy()
            for f in range(1,END+1):
                t=((f+i*13)%35)/35
                o.location=origin+Vector((.03*math.sin(t*5+i),.01*math.cos(t*6+i),t*.13))
                o.keyframe_insert('location',frame=f)
                keyscale(o,f,max(.001,math.sin(math.pi*t)))
    # Short divergent tongues make a muzzle bloom rather than a laser cone.
    for i in range(5):
        a=i*math.tau/5
        o=tongue(coll,gun,'VFX muzzle bloom %02d'%i,(0,-.69,0),(.30*math.cos(a),-1,.30*math.sin(a)),.25,.055,.55,i,orange if i else golden)
        for f in range(1,END+1):
            age=min((f-shot for shot in SHOTS if f>=shot),default=1000)
            v=1.5*math.exp(-age/2.6) if age<12 else .001
            keyscale(o,f,v)
    rng=random.Random(14)
    for shot in SHOTS:
        root=bpy.data.objects.new('VFX projectile flight %03d'%shot,None);coll.objects.link(root);root.parent=gun
        # A rounded hot head with several distinct tongues trailing toward the turret.
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1)
        body=bpy.context.object;body.name='VFX fireball outer %03d'%shot
        for c in list(body.users_collection):c.objects.unlink(body)
        coll.objects.link(body);body.parent=root;body.scale=(.087,.12,.082);body.data.materials.append(orange)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
        core=bpy.context.object;core.name='VFX fireball core %03d'%shot
        for c in list(core.users_collection):c.objects.unlink(core)
        coll.objects.link(core);core.parent=root;core.location=(0,-.025,0);core.scale=(.055,.075,.052);core.data.materials.append(golden)
        for j in range(4):
            a=j*math.tau/4
            o=tongue(coll,root,'VFX projectile tail %03d %d'%(shot,j),(.032*math.cos(a),.03,.03*math.sin(a)),(.1*math.cos(a),1,.12*math.sin(a)),.29+j*.025,.083-j*.008,.65,j,orange if j else golden)
            ripple(o,j+shot)
        for f in range(1,END+1):
            age=f-shot
            t=max(0,age)/24
            root.location=(.014*math.sin(t*8),-.78-t*1.50,.018*math.sin(t*6))
            root.keyframe_insert('location',frame=f)
            v=min(1,max(.001,age/2)) * min(1,max(.001,(31-age)/7)) if 0<=age<=31 else .001
            keyscale(root,f,v)
        # Individual hot fragments peel away, drift and die behind the moving head.
        for j in range(9):
            delay=j//3+2
            o=tongue(coll,gun,'VFX flight ember %03d %02d'%(shot,j),(0,0,0),(0,1,.1),.035,.009,.3,j,bpy.data.materials['Flame_Finish_EmberGlow'])
            dx=rng.uniform(-.10,.10);dz=rng.uniform(-.035,.13)
            for f in range(1,END+1):
                age=f-shot-delay
                o.location=(dx*max(age,0)/20,-.83-max(age,0)*.046,dz*max(age,0)/20)
                o.keyframe_insert('location',frame=f)
                v=math.sin(math.pi*age/27) if 0<age<27 else .001
                keyscale(o,f,max(.001,v))
    light=bpy.data.lights.new('VFX warm firing light','POINT');light.color=(1,.19,.015);light.shadow_soft_size=.12
    lo=bpy.data.objects.new(light.name,light);coll.objects.link(lo);lo.parent=gun;lo.location=(0,-.73,.035)
    for f in range(1,END+1):
        age=min((f-shot for shot in SHOTS if f>=shot),default=1000)
        light.energy=12*math.exp(-age/3) if age<18 else 0
        light.keyframe_insert('energy',frame=f)
    # Mild recoil settles quickly; only the independent preview carries animation.
    rest=gun.location.copy()
    for f in range(1,END+1):
        age=min((f-shot for shot in SHOTS if f>=shot),default=1000)
        back=.025*math.exp(-age/4)*math.sin(min(age/2,math.pi/2)) if age<20 else 0
        gun.location=rest+Vector((0,back,0));gun.keyframe_insert('location',frame=f)
    for label,frame in [('대기 불꽃',1),('발사 1 — 화구',30),('화염 발사체',40),('발사 2 — 화구',94),('화염 꼬리·잔불',106)]:
        s.timeline_markers.new(label,frame=frame)
    s.frame_set(40)
    s.render.filepath=str(OUT/'preview-test.png')
    return {'frames':END,'fps':FPS,'shots':SHOTS,'game_export':False}
