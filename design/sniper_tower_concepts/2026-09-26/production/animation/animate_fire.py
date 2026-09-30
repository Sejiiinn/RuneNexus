"""Blender firing study; separate copy, no static asset or game changes.
Run from the final static SWIFT source, through Blender MCP or background.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'sniper-c-editable.blend'
KEYS=[(1,0),(15,0),(17,0),(18,.048),(21,.043),(27,.018),(36,0),(60,0)]

def curves(action):
    if hasattr(action,'fcurves'):return list(action.fcurves)
    return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]

def create():
    assert Path(bpy.data.filepath).resolve()==SOURCE.resolve(), 'Open the approved static SWIFT source first.'
    assert not bpy.data.is_dirty, 'Preserve unsaved original work before animation copy.'
    source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sniper-fire-animated.blend'),copy=True,compress=True)
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'sniper-fire-animated.blend'))
    s=bpy.context.scene;s.name='SWIFT Sniper — Fire animation';s.frame_start=1;s.frame_end=60;s.render.fps=30
    barrel=next(o for o in s.objects if o.name.split('.')[0]=='turret_barrel')
    muzzle=next(o for o in s.objects if o.name.split('.')[0]=='muzzle')
    for f,kick in KEYS:
        barrel.location=(0,kick,0);barrel.keyframe_insert(data_path='location',frame=f,group='Precision recoil')
    barrel.animation_data.action.name='sniper_fire'
    for fc in curves(barrel.animation_data.action):
        for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    # Reuse native bpy solid-mesh helpers. These are volumetric spear facets,
    # not a textured plane, billboard, or a long beam.
    h={}
    # Resolve from repository root, independent of the caller's cwd.
    p=Path('/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d/build_model.py')
    exec(compile(p.read_text(),str(p),'exec'),h)
    col=bpy.data.collections.new('C10 Fire animation only');s.collection.children.link(col)
    fx=h['empty']('FX precise single-shot flash',col,muzzle)
    core=h['emissive']('FX white cyan impulse',(.72,.93,1),5.0)
    aura=h['emissive']('FX restrained cyan edge',(.015,.48,.86),2.5)
    def spear(name,length,radius,phase,mat):
        vs=[(0,.003,0)]
        for y,r in [(-.011,radius),(-length*.52,radius*.42)]:
            for i in range(6):
                a=phase+math.tau*i/6;vs.append((r*math.cos(a),y,r*math.sin(a)))
        vs.append((0,-length,0));fs=[]
        for i in range(6):
            j=(i+1)%6;fs.extend([(0,1+j,1+i),(1+i,1+j,7+j,7+i),(7+i,7+j,13)])
        return h['mesh'](name,vs,fs,mat,col,fx,0)
    spear('FX solid white needle',.142,.018,0,core)
    # Four short pointed flare petals create depth in any camera view.
    for i in range(4):
        a=i*math.pi/2+.35;radial=Vector((math.cos(a),0,math.sin(a)));side=Vector((-math.sin(a),0,math.cos(a)))
        pts=[Vector((0,-.002,0)),radial*.040+Vector((0,-.020,0)),radial*.010+Vector((0,-.063,0))]
        vs=[tuple(v+side*t) for t in [-.003,.003] for v in pts]
        h['mesh']('FX short cyan petal %02d'%i,vs,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],aura,col,fx,0)
    for f,scale in [(1,0),(16,0),(17,1),(18,.38),(19,0),(60,0)]:
        fx.scale=(scale,)*3;fx.keyframe_insert(data_path='scale',frame=f,group='One short shot')
    fx.animation_data.action.name='sniper_fire_flash'
    for fc in curves(fx.animation_data.action):
        for k in fc.keyframe_points:k.interpolation='LINEAR'
    # Animate the existing shared cyan material; no shape or texture replacement.
    rune=next(m for m in bpy.data.materials if m.name.startswith('C | cyan runic inlay') and m.users)
    bs=rune.node_tree.nodes.get('Principled BSDF');strength=bs.inputs['Emission Strength']
    for f,value in [(1,2.2),(9,2.2),(14,3.5),(16,5.5),(17,3.4),(22,2.2),(60,2.2)]:
        strength.default_value=value;strength.keyframe_insert(data_path='default_value',frame=f)
    rune.node_tree.animation_data.action.name='sniper_fire_aim_glow'
    for fc in curves(rune.node_tree.animation_data.action):
        for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    for name,f in [('REST',1),('AIM CHARGE',10),('SINGLE SHOT',17),('MAX RECOIL',18),('RETURN',27),('RESTORED',36),('LOOP REST',60)]:s.timeline_markers.new(name,frame=f)
    s['animation_scope']='Blender study only. No game timing, combat or static mesh changes.'
    s['recoil_contract']='Only turret_barrel +Y in Blender (glTF -Z). head and root fixed.'
    s['timing']='60 frames / 30 fps, 2.0 sec; shot 17, maximum recoil 18, restored 36.'
    s.frame_set(1)
    s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True;s.cycles.adaptive_threshold=.055
    s.render.resolution_x=800;s.render.resolution_y=800;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'frames/frame-')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sniper-fire-animated.blend'),compress=True)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
    (OUT/'animation-manifest.json').write_text(json.dumps({'source_sha256':source_hash,'source':'../sniper-c-editable.blend','animated_source':'sniper-fire-animated.blend','action':'sniper_fire','fps':30,'frames':60,'shot_frame':17,'max_recoil_frame':18,'restored_frame':36,'recoil_tile':.048,'recoil_keyframes':KEYS,'root_and_head_animated':False,'effect':'Short solid 3D white/cyan spear and four petals; no beam, billboard or smoke','static_source_unchanged':True,'video_plan':'2 normal cycles, then one 1.5x-duration slow cycle, total 7 sec','game_integration':False},ensure_ascii=False,indent=2))
    print('ANIMATED_SOURCE_READY')

if __name__=='__main__':create()
