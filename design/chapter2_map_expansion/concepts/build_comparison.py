"""Compose final Blender renders without editing their pixels or any asset source."""
import bpy
from pathlib import Path
HERE=Path(__file__).resolve().parent
if not bpy.app.background:raise RuntimeError('Use independent background Blender')
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=1
s.render.resolution_x=2400;s.render.resolution_y=1920;s.render.resolution_percentage=100
s.view_settings.view_transform='Standard';s.view_settings.look='None'
s.world=bpy.data.worlds.new('Dark comparison background');s.world.use_nodes=True
s.world.node_tree.nodes['Background'].inputs[0].default_value=(.002,.004,.008,1)
for i,stage in enumerate(range(6,11)):
 x=(-6.1,0,6.1,-3.05,3.05)[i];y=(3.7,3.7,3.7,-3.7,-3.7)[i]
 bpy.ops.mesh.primitive_plane_add(size=2,location=(x,y,0));o=bpy.context.object;o.name=f'2-{stage} final render';o.scale=(3,3.6,1)
 m=bpy.data.materials.new(o.name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission');im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(HERE/f'chapter-2-{stage}.png'));m.node_tree.links.new(im.outputs['Color'],em.inputs['Color']);m.node_tree.links.new(em.outputs[0],out.inputs['Surface']);o.data.materials.append(m)
bpy.ops.object.camera_add(location=(0,0,10));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=18.4;s.camera=cam
s.render.filepath=str(HERE/'five-map-comparison.png');s.render.image_settings.file_format='PNG';bpy.ops.render.render(write_still=True)
