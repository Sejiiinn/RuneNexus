import bpy,math,json
from mathutils import Vector
from pathlib import Path
H=Path(__file__).resolve().parent
ROOT=H.parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/images/stage1_3d/environment/chapter3_props.glb'))
for i,name in enumerate(('elbow_pipe','side_conduit','exhaust_vent')):
 o=bpy.data.objects[name];o.location=((i-1)*.9,0,0 if i!=1 else -.05)
s.render.engine='CYCLES';s.cycles.samples=40;s.cycles.use_denoising=True
s.world=bpy.data.worlds.new('Foundry neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.18,.21,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.5
for name,c,power,size in [('Softbox',(-3,-4,5),500,4),('Fill',(4,-1,3),230,3),('Rim',(1,4,4),600,3)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=c;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
g=bpy.data.materials.new('Studio charcoal');g.use_nodes=True;g.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.018,.024,.028,1);g.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.82
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.37));bpy.context.object.data.materials.append(g)
camd=bpy.data.cameras.new('Preview');cam=bpy.data.objects.new('Preview',camd);s.collection.objects.link(cam);cam.location=(1.9,-5,3.9);cam.rotation_euler=(Vector((0,0,.07))-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=3.05;s.camera=cam
s.render.resolution_x=1800;s.render.resolution_y=1050;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.render.filepath=str(H/'glb-reimport-hero.png');bpy.ops.render.render(write_still=True)
print('REIMPORT_RENDER_READY',flush=True)
