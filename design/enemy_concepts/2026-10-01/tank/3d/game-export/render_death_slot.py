"""Render only the existing death atlas's tank input from the approved 3D body.

Use background Blender with ../walk/tank-walk.blend. The runtime death overlay
keeps its original fade, drift, 13 stone fragments and lifetime.
"""
import bpy
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
scene = bpy.data.scenes['Tank_WideChest_Walk']
for window in bpy.context.window_manager.windows: window.scene = scene
rig = scene.objects['Tank_Walk_Rig']
rig.data.pose_position = 'REST'
scene.frame_set(1)
for obj in scene.objects:
    if obj.type == 'MESH' and obj.parent_type != 'BONE':
        obj.hide_render = True
world = bpy.data.worlds.new('TankDeathInputWorld')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (.8,.8,.8,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = .55
scene.world = world
camera = bpy.data.objects.new('TankDeathInputCamera', bpy.data.cameras.new('TankDeathInputCamera'))
scene.collection.objects.link(camera)
camera.location = (4,-10,5.6)
camera.rotation_euler = (Vector((0,0,2.83))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 6.8
scene.camera = camera
light = bpy.data.objects.new('TankDeathInputKey', bpy.data.lights.new('TankDeathInputKey','AREA'))
scene.collection.objects.link(light)
light.location = (-4,-6,9)
light.rotation_euler = (Vector((0,0,2.5))-light.location).to_track_quat('-Z','Y').to_euler()
light.data.energy, light.data.size = 650, 6
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.render.film_transparent = True
scene.render.use_compositing = False
scene.render.resolution_x = scene.render.resolution_y = 192
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = str(OUT/'tank-death-slot.png')
bpy.ops.render.render(write_still=True)
