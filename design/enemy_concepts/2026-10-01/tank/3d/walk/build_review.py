"""Separate travelling review, using the existing natural game path mesh.
Run in Blender MCP after build_walk.py. Does not touch the source walk scene.
"""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent
NAME='Tank_Walk_Traversal'
SCALE=.55/4.12951922416687
SPEED=.65625
FRAMES=183  # exactly 7 cycles, 1..182 playback; 183 endpoint
source=bpy.data.scenes['Tank_WideChest_Walk']
bpy.context.window.scene=source
source.frame_set(1)
bpy.context.view_layer.update()
old=bpy.data.scenes.get(NAME)
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(old)
s=bpy.data.scenes.new(NAME)
c=bpy.data.collections.new('Tank_Traversal_MODEL')
studio=bpy.data.collections.new('Tank_Traversal_STUDIO')
s.collection.children.link(c)
s.collection.children.link(studio)
mapping={}
for old in source.objects:
    o=old.copy()
    if old.data:
        o.data=old.data.copy()
    o.name='Traversal_'+old.name
    (studio if old.type in {'LIGHT','CAMERA'} or 'studio floor' in old.name else c).objects.link(o)
    mapping[old]=o
    if old.animation_data and old.animation_data.action:
        o.animation_data.action=old.animation_data.action.copy()
for old,o in mapping.items():
    o.parent=mapping.get(old.parent)
    o.matrix_parent_inverse=old.matrix_parent_inverse.copy()
    o.matrix_basis=old.matrix_basis.copy()
root=mapping[source.objects['TankWalk_ROOT']]
rig=mapping[source.objects['Tank_Walk_Rig']]
rig.animation_data.action.name='Tank_Traversal_WeightShift'
# Real forward translation in production units, then use the common scale to
# report tile coordinates. The raw model's 1.25-height root scale is retained.
root.location.y=0
root.keyframe_insert('location',frame=1)
root.location.y=-SPEED/SCALE*(FRAMES-1)/60
root.keyframe_insert('location',frame=FRAMES)
for layer in root.animation_data.action.layers:
    for strip in layer.strips:
        for slot in root.animation_data.action.slots:
            bag=strip.channelbag(slot)
            if bag:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:
                        kp.interpolation='LINEAR'
bpy.context.window.scene=s
s.frame_set(1)
bpy.context.view_layer.update()
tile_path=OUT.parents[4]/'stage1_3d/surface_effects/terrain-surface.blend'
with bpy.data.libraries.load(str(tile_path),link=False) as (src,dst):
    dst.objects=['path_tile_natural_surface']
tile=dst.objects[0]
for j in range(-3,3):
    o=tile.copy()
    o.name='Tank_Actual_PathTile_'+str(j)
    o.parent=None
    studio.objects.link(o)
    o.location=(0,j/SCALE,-.167/SCALE)
    o.scale=(1/SCALE,)*3
floor=mapping[source.objects['TankWalk_studio floor']]
floor.location.z=-.37/SCALE
s.camera=mapping[source.camera]
s.world=source.world.copy()
s.render.engine='CYCLES'
s.cycles.samples=16
s.cycles.use_denoising=True
s.render.resolution_x=800
s.render.resolution_y=700
s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG'
s.render.fps=60
s.frame_start,s.frame_end=1,FRAMES-1
s.view_settings.view_transform=source.view_settings.view_transform
s.view_settings.look=source.view_settings.look
s['production_model_to_tile_scale']=SCALE
s['speed_tiles_per_second']=SPEED
s['cycle_distance_tiles']=.284375
s['stance_fraction']=.55
s['review_distance_tiles']=SPEED*(FRAMES-1)/60
s['path_source']=str(tile_path)
s['scope']='Editable traversal preview only; game integration/stat changes excluded.'
s['render_note']='The video renders two full cycles at true forward speed, then repeats that segment.'
s.frame_set(1)
bpy.data.libraries.write(str(OUT/'tank-walk-traversal.blend'),{s},fake_user=True,compress=True)
(OUT/'review-contract.json').write_text(json.dumps({'source':'tank-walk.blend','scene':NAME,'root':root.name,'rig':rig.name,'frames':[1,FRAMES-1],'endpoint_frame':FRAMES,'fps':60,'speed_tiles_per_second':SPEED,'cycle_distance_tiles':.284375,'stance_fraction':.55,'distance_to_endpoint_tiles':s['review_distance_tiles'],'production_model_to_tile_scale':SCALE,'tile_source':str(tile_path),'render_engine':'CYCLES','saved_scene_default_samples':16,'saved_scene_default_resolution':[800,700],'motion_render_conditions':'render-conditions.json'},indent=2))
print('TRAVERSAL_READY',NAME,s['review_distance_tiles'])
