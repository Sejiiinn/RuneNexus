"""착탄 원본을 실제 조명이 반응하는 단독 검수 장면으로 구성."""
import bpy
from mathutils import Vector
from pathlib import Path

root = Path(bpy.data.filepath).parent
body = bpy.data.scenes['CannonImpactV2']
ground = bpy.data.scenes['CannonGroundV2']
scene = bpy.data.scenes.new('ImpactReview')
bpy.context.window.scene = scene
for source in (body, ground):
    for obj in source.objects:
        if obj.type != 'CAMERA':
            scene.collection.objects.link(obj)

scene.frame_start = body.frame_start
scene.frame_end = body.frame_end
scene.render.fps = body.render.fps
scene.render.fps_base = body.render.fps_base
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.film_transparent = False
scene.view_settings.view_transform = 'AgX'

world = bpy.data.worlds.new('Review dusk')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (.12, .16, .2, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = .15
scene.world = world

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.02))
floor = bpy.context.object
floor.name = 'Review stone floor'
material = bpy.data.materials.new('Rough charcoal stone')
material.use_nodes = True
n = material.node_tree.nodes
links = material.node_tree.links
surface = n.get('Principled BSDF')
surface.inputs['Base Color'].default_value = (.028, .035, .04, 1)
surface.inputs['Roughness'].default_value = .78
tex = n.new('ShaderNodeTexNoise')
tex.inputs['Scale'].default_value = 18
tex.inputs['Detail'].default_value = 4
coord = n.new('ShaderNodeTexCoord')
links.new(coord.outputs['Object'], tex.inputs['Vector'])
bump = n.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .28
bump.inputs['Distance'].default_value = .07
links.new(tex.outputs['Fac'], bump.inputs['Height'])
links.new(bump.outputs['Normal'], surface.inputs['Normal'])
floor.data.materials.append(material)

key_data = bpy.data.lights.new('Review soft key', 'AREA')
key_data.energy = 170
key_data.shape = 'DISK'
key_data.size = 5
key_data.color = (.56, .68, 1)
key = bpy.data.objects.new('Review soft key', key_data)
scene.collection.objects.link(key)
key.location = (-2, -3, 6)
key.rotation_euler = (-key.location).to_track_quat('-Z', 'Y').to_euler()

flash_data = bpy.data.lights.new('Impact reflected light', 'POINT')
flash_data.color = (1, .3, .045)
flash_data.shadow_soft_size = .32
flash = bpy.data.objects.new('Impact reflected light', flash_data)
scene.collection.objects.link(flash)
flash.location = (0, -.12, .45)
for frame in range(scene.frame_start, scene.frame_end + 1):
    t = (frame - scene.frame_start) / max(1, scene.frame_end - scene.frame_start)
    flash_data.energy = 750 * max(0, 1 - t / .68) ** 2
    flash_data.keyframe_insert(data_path='energy', frame=frame)

camera_data = bpy.data.cameras.new('Review camera')
camera = bpy.data.objects.new('Review camera', camera_data)
scene.collection.objects.link(camera)
camera.location = (2.8, -7, 4.2)
camera.rotation_euler = (Vector((0, 0, .72)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 4.9
scene.camera = camera
scene.frame_set(min(10, scene.frame_end))
bpy.ops.wm.save_as_mainfile(filepath=str(root / 'preview' / 'impact-review.blend'))
print('REVIEW_READY', scene.frame_end, scene.render.fps)
