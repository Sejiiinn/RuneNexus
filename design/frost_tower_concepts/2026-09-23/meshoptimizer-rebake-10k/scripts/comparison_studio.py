"""Accepted original comparison lighting, camera and Cycles settings."""
import bpy
from mathutils import Vector
def configure(scene,center,extent):
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.cycles.seed=0
    scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    world=bpy.data.worlds.new('Comparison studio world');scene.world=world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.035,.05,.075,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
    for name,offset,power,size,color in [('Key',(-3,-4,5),600,4,(.88,.95,1)),('Fill',(3,-1,2.5),280,3,(.65,.8,1)),('Rim',(0,3,4),750,3,(.7,.88,1))]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size*extent;d.color=color
        o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=center+Vector(offset)*extent
        o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new('Comparison camera');d.type='ORTHO';d.ortho_scale=extent*1.30
    o=bpy.data.objects.new('Comparison camera',d);scene.collection.objects.link(o);scene.camera=o
    return o
