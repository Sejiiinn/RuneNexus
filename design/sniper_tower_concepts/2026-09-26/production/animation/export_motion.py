"""Export recoil motion only from existing baked mesh; flash/glow stay in .blend."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
ns={'__name__':'animation_helpers','__file__':str(OUT/'animate_fire.py')};exec(compile((OUT/'animate_fire.py').read_text(),str(OUT/'animate_fire.py'),'exec'),ns)
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'sniper-c-baked-preview.blend'))
s=bpy.context.scene;s.frame_start=1;s.frame_end=60;s.render.fps=30
barrel=next(o for o in s.objects if o.name=='turret_barrel')
for f,kick in ns['KEYS']:
    barrel.location=(0,kick,0);barrel.keyframe_insert(data_path='location',frame=f)
barrel.animation_data.action.name='sniper_fire'
for fc in ns['curves'](barrel.animation_data.action):
    for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
s.frame_set(1);bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'sniper-fire-motion-only.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_frame_range=True,export_cameras=False,export_lights=False,export_yup=True)
print('MOTION_ONLY_GLB_READY')
