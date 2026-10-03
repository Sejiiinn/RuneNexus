"""Refresh only lightning.png using the repository's fixed HUD camera recipe."""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
source=ROOT/'assets/images/stage1_3d/turrets/lightning.glb'
target_path=ROOT/'assets/images/ui/hud/turrets_3d/lightning.png'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
scene=bpy.context.scene
target=Vector((0,0,.40))
data=bpy.data.cameras.new('HUD fixed camera');camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera)
camera.location=target+Vector((4,-4,5.1));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=1.45;scene.camera=camera
world=bpy.data.worlds.new('HUD studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.21,.26,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
for name,loc,power,size,color in [('key',(-3,-4,6),650,4,(1,.92,.8)),('fill',(4,-1,4),440,4,(.70,.85,1)),('rim',(1,4,5),750,3,(.68,.88,1))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.samples=96;scene.cycles.use_denoising=False
scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
bpy.context.view_layer.update()
points=[world_to_camera_view(scene,camera,o.matrix_world@v.co) for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
bounds=[min(p.x for p in points),min(p.y for p in points),max(p.x for p in points),max(p.y for p in points)]
assert all(.025 <= v <= .975 for v in bounds),bounds
scene.render.filepath=str(target_path);bpy.ops.render.render(write_still=True)
(P/'hud-icon-verification.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'camera':[4,-4,5.5],'target':[0,0,.4],'ortho_scale':1.45,'vertex_bounds_uv':bounds,'size':[256,256],'rgba':True,'samples':96,'post_processing':False},indent=2))
print('LIGHTNING_HUD_ICON_READY',target_path)
