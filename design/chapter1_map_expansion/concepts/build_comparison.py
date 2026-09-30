"""Create a five-map comparison with Blender image planes; no external 2D editing."""
import bpy,os
from pathlib import Path
HERE=Path(__file__).resolve().parent
if not bpy.app.background:raise RuntimeError('Use background Blender')
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.name='Five proposed maps comparison';s.render.engine='CYCLES';s.cycles.samples=1
s.render.resolution_x=2400;s.render.resolution_y=1780;s.render.resolution_percentage=100
s.view_settings.view_transform='Standard';s.view_settings.look='None'
s.world=bpy.data.worlds.new('Dark background');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.002,.004,.008,1)
only_teleports=os.environ.get('COMPARE_TELEPORT_ONLY')=='1'
if only_teleports:s.render.resolution_y=1320
for idx,stage in enumerate([7,10] if only_teleports else range(6,11)):
 x=(-3.05,3.05)[idx] if only_teleports else (-6.1,0,6.1,-3.05,3.05)[idx];y=0 if only_teleports else (3.35,3.35,3.35,-3.35,-3.35)[idx]
 bpy.ops.mesh.primitive_plane_add(size=2,location=(x,y,0));o=bpy.context.object;o.name=f'1-{stage} final render';o.scale=(3,3.3,1)
 m=bpy.data.materials.new(o.name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission');im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(HERE/f'chapter-1-{stage}.png'));m.node_tree.links.new(im.outputs['Color'],em.inputs['Color']);m.node_tree.links.new(em.outputs[0],out.inputs['Surface']);o.data.materials.append(m)
bpy.ops.object.camera_add(location=(0,0,10));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=12.2 if only_teleports else 18.4;s.camera=cam
s.render.filepath=str(HERE/('teleport-map-comparison.png' if only_teleports else 'five-map-comparison.png'));s.render.image_settings.file_format='PNG';bpy.ops.render.render(write_still=True)
