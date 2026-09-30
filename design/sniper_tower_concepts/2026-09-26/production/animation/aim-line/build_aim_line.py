"""Four-second Blender target-tracking study; existing game enemy, 20-tri line.
No source-model changes and no game implementation.
"""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'sniper-fire-animated.blend'
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
ENEMY=ROOT/'assets/images/stage1_3d/enemies/armored.glb'
FPS=30;END=120;ACQUIRE=9;LOCK=43;SHOT=51;CLEAR=65;RETURN=85;RANGE=3.4
ORIGIN=Vector((0,-.196,.420))

def curves(action):
    if hasattr(action,'fcurves'):return list(action.fcurves)
    return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
def named(name):return next(o for o in bpy.context.scene.objects if o.name.split('.')[0]==name)
def worldtree(objects):
    dg=bpy.context.evaluated_depsgraph_get();verts=[];faces=[]
    for o in objects:
        if o.type!='MESH':continue
        m=o.evaluated_get(dg).data;offset=len(verts);verts.extend(o.matrix_world@v.co for v in m.vertices);faces.extend(tuple(offset+i for i in p.vertices) for p in m.polygons)
    return BVHTree.FromPolygons(verts,faces)

def build():
    assert Path(bpy.data.filepath).resolve()==SOURCE.resolve() and not bpy.data.is_dirty
    source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sniper-aim-line.blend'),copy=True,compress=True)
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'sniper-aim-line.blend'))
    s=bpy.context.scene;s.name='SWIFT — Target surface aiming line';s.frame_start=1;s.frame_end=END;s.render.fps=FPS
    # Preserve the original firing/return timing; prepend 34 frames for tracking.
    for action in bpy.data.actions:
        for fc in curves(action):
            for key in fc.keyframe_points:key.co.x+=34;key.handle_left.x+=34;key.handle_right.x+=34
    barrel=named('turret_barrel');head=named('turret_head');root=named('turret_root')
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ENEMY));imported=[o for o in bpy.data.objects if o not in before]
    col=bpy.data.collections.new('C20 Aiming preview only');s.collection.children.link(col)
    target=bpy.data.objects.new('Preview armored target controller',None);col.objects.link(target)
    for o in imported:
        if o.parent not in imported:
            world=o.matrix_world.copy();o.parent=target;o.matrix_world=world
        for c in list(o.users_collection):c.objects.unlink(o)
        col.objects.link(o)
    target.rotation_euler.z=math.pi
    target_meshes=[o for o in imported if o.type=='MESH']
    for o in target_meshes:
        for f,value in [(1,True),(ACQUIRE,False),(CLEAR,True),(END,True)]:o.hide_render=value;o.keyframe_insert('hide_render',frame=f)
    # Target uses its original GLB scale and sits at its original ground height.
    tile=next(o for o in s.objects if o.name.startswith('Single square placement tile')).copy();tile.data=tile.data.copy();col.objects.link(tile);tile.name='Preview target placement tile';tile.location.y=-2.4;tile.scale.x=1.75;tile.scale.y=1.22
    vertices=[(math.cos(i*math.tau/6),math.sin(i*math.tau/6),z) for z in [-.5,.5] for i in range(6)]
    faces=[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
    data=bpy.data.meshes.new('Aim line low-poly hexagon');data.from_pydata(vertices,[],faces);data.update()
    line=bpy.data.objects.new('Aim line — 20 triangle solid cylinder',data);col.objects.link(line);line.rotation_mode='QUATERNION'
    mat=bpy.data.materials.new('Aim line | restrained cyan');mat.use_nodes=True;p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.015,.42,.58,1);p.inputs['Emission Color'].default_value=(.025,.60,.83,1);p.inputs['Emission Strength'].default_value=1.6;p.inputs['Roughness'].default_value=.45;line.data.materials.append(mat)
    line.data.calc_loop_triangles();assert len(line.data.loop_triangles)==20
    samples=[];own_meshes=[o for c in s.collection.children if c.name.startswith(('C01','C02','C03')) for o in c.objects if o.type=='MESH']
    for f in range(1,END+1):
        s.frame_set(f)
        q=max(0,min(1,(f-ACQUIRE)/(LOCK-ACQUIRE)));q=q*q*(3-2*q)
        x=-.32+.62*q;target.location=(x,-2.4,0);target.keyframe_insert('location',frame=f)
        valid=ACQUIRE<=f<CLEAR;aim=ACQUIRE<=f<SHOT
        bearing=math.atan2(x,2.4)
        if f<ACQUIRE:bearing*=max(0,(f-1)/(ACQUIRE-1))
        if f>=CLEAR:bearing*=max(0,1-(f-CLEAR)/(RETURN-CLEAR))
        head.rotation_euler=(0,0,bearing);head.keyframe_insert('rotation_euler',frame=f)
        bpy.context.view_layer.update()
        origin=barrel.matrix_world@ORIGIN
        aim_center=target.matrix_world@Vector((0,0,.780))
        direction=(aim_center-origin).normalized();dist=(aim_center-origin).length
        hit,normal,index,ray_distance=worldtree(target_meshes).ray_cast(origin,direction,dist+.5)
        in_range=dist<=RANGE;visible=valid and aim and in_range and hit is not None
        self_hit=None
        if visible:
            self_hit,_,_,own_distance=worldtree(own_meshes).ray_cast(origin+direction*.001,direction,ray_distance-.003)
            assert self_hit is None, ('Self occlusion',f,list(self_hit),own_distance)
            end=hit-direction*.00025;segment=end-origin
            line.location=(origin+end)/2;line.rotation_quaternion=segment.to_track_quat('Z','Y');line.scale=(.0022,.0022,segment.length)
        else:line.scale=(0,0,0)
        line.hide_render=not visible
        for path in ['location','rotation_quaternion','scale','hide_render']:line.keyframe_insert(path,frame=f)
        s['preview_target_valid']=int(valid);s.keyframe_insert(data_path='["preview_target_valid"]',frame=f)
        s['preview_in_range']=int(in_range);s.keyframe_insert(data_path='["preview_in_range"]',frame=f)
        s['preview_aim_active']=int(aim);s.keyframe_insert(data_path='["preview_aim_active"]',frame=f)
        samples.append({'frame':f,'valid':valid,'aim':aim,'in_range':in_range,'visible':visible,'target':list(target.location),'head_yaw':bearing,'origin':list(origin),'hit':list(hit) if hit is not None else None,'self_occluded':self_hit is not None,'recoil':barrel.location.y})
    head.animation_data.action.name='sniper_preview_target_tracking';target.animation_data.action.name='preview_enemy_lateral_motion';line.animation_data.action.name='sniper_aim_line_surface_tracking'
    for o in [head,target,line]:
        for fc in curves(o.animation_data.action):
            for k in fc.keyframe_points:k.interpolation='CONSTANT' if fc.data_path=='hide_render' else 'LINEAR'
    s['preview_range_tiles']=RANGE;s['preview_origin']='Actual cyan scope front surface, barrel local (0,-.196,.420)'
    s['preview_scope']='Blender staged tracking example only; no runtime aim, range, combat, or enemy changes.'
    s.timeline_markers.clear()
    for name,f in [('NO TARGET',1),('ACQUIRE / TRACK',ACQUIRE),('LOCK',LOCK),('SHOT / LINE OFF',SHOT),('MAX RECOIL',52),('TARGET CLEARED',CLEAR),('RECOVERED',70),('NO TARGET IDLE',RETURN),('END REST',END)]:s.timeline_markers.new(name,frame=f)
    camera=s.camera;camera.location=(4.7,-.65,3.5);look=Vector((0,-1.12,.38));camera.rotation_euler=(look-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=4.3
    s.render.resolution_x=1120;s.render.resolution_y=720;s.cycles.samples=12;s.cycles.adaptive_threshold=.065
    s.render.filepath=str(OUT/'frames/frame-');s.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sniper-aim-line.blend'),compress=True)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
    result={'source_sha256':source_hash,'enemy_asset':str(ENEMY.relative_to(ROOT)),'enemy_sha256':hashlib.sha256(ENEMY.read_bytes()).hexdigest(),'enemy_scale':[1,1,1],'target_center_height':.780,'aim_origin_barrel_local':list(ORIGIN),'line_triangles':20,'line_radius':.0022,'flash_triangles_preserved':56,'fps':FPS,'frames':END,'shot_frame':SHOT,'range_tiles_preview_only':RANGE,'self_occlusion_in_this_sequence':False,'line_end':'first raycast hit on actual enemy mesh; small outward surface offset','game_integration':False,'samples':samples}
    (OUT/'aim-line-manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print('AIM_LINE_SOURCE_READY')

if __name__=='__main__':build()
