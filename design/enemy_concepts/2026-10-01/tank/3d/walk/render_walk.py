"""Render actual moving tank, camera follows it over stationary path tiles.
Background Blender: --python render_walk.py -- [draft|final] [view].
Frames go into ignored local/, final videos/sheets are packed from these pixels.
"""
import bpy,math,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
quality=args[0] if args else 'draft'
view=args[1] if len(args)>1 else 'three-quarter'
reuse='--reuse' in args
s=bpy.data.scenes['Tank_Walk_Traversal']
for w in bpy.context.window_manager.windows:
    w.scene=s
camera=s.camera
root=s.objects['Traversal_TankWalk_ROOT']
height=5.666368484
views={'three-quarter':(25,22),'side':(90,9),'high-angle':(25,65)}
yaw,elevation=map(math.radians,views[view])
offset=Vector((height*2.3*math.sin(yaw),-height*2.3*math.cos(yaw),height*2.3*math.tan(elevation)))
camera.data.type='ORTHO'
camera.data.ortho_scale=height*1.43
s.cycles.samples=12
s.render.resolution_x=640
s.render.resolution_y=560
s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG'
frames=[1,8,14,21] if quality=='probe' else (range(1,27) if quality=='draft' else range(1,53))
folder=OUT/'local'/quality/view
folder.mkdir(parents=True,exist_ok=True)
for f in frames:
    if reuse and (folder/f'{f:04d}.png').exists():
        print('FRAME_REUSED',quality,view,f,flush=True)
        continue
    s.frame_set(f)
    target=Vector((0,root.location.y,height*.46))
    camera.location=target+offset
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=str(folder/f'{f:04d}.png')
    bpy.ops.render.render(write_still=True)
    (OUT/'local'/f'render-{quality}-{view}-progress.txt').write_text(f'{f}/{max(frames)}\n')
    print('FRAME_READY',quality,view,f,flush=True)
conditions={'blender':bpy.app.version_string,'source_traversal_sha256':hashlib.sha256((OUT/'tank-walk-traversal.blend').read_bytes()).hexdigest(),'engine':s.render.engine,'samples':s.cycles.samples,'view':view,'yaw_degrees':math.degrees(yaw),'elevation_degrees':math.degrees(elevation),'orthographic_scale':camera.data.ortho_scale,'resolution':[s.render.resolution_x,s.render.resolution_y],'frames':[min(frames),max(frames)],'camera_follows_root':True,'root_travels':True,'tile_is_stationary':True,'view_transform':s.view_settings.view_transform,'look':s.view_settings.look,'existing_frames_reused':reuse}
(OUT/'local'/f'render-{quality}-{view}-conditions.json').write_text(json.dumps(conditions,indent=2))
if quality=='final':
    path=OUT/'render-conditions.json'
    data=json.loads(path.read_text()) if path.exists() else {'views':{}}
    data['views'][view]=conditions
    path.write_text(json.dumps(data,indent=2))
