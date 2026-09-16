"""Execute with Blender MCP; copies approved top tongues, preserves original document."""
import bpy, math, json
from mathutils import Vector
from pathlib import Path
OUT=Path('/Users/sejin/Documents/RuneNexus/design/fire_tower_concepts/runic_3d/flipbook_preview/atlas')
original_scene=bpy.context.window.scene
source=bpy.data.scenes['Rune Flame Turret — VFX Preview']
s=bpy.data.scenes.new('Runic Flame Flipbook Bake')
bpy.context.window.scene=s
s.render.engine='BLENDER_EEVEE'
s.eevee.taa_render_samples=64
s.eevee.volumetric_samples=128
s.eevee.volumetric_tile_size='2'
s.eevee.use_volume_custom_range=True
s.eevee.volumetric_start=.1;s.eevee.volumetric_end=5
s.render.resolution_x=s.render.resolution_y=256
s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.render.film_transparent=True
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=-.35
s.world=bpy.data.worlds.new('Flame Black World');s.world.use_nodes=True
s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=0
origin=source.objects['Flame_Finish_Top_Main'].location.copy()
flames=[]
for i,src in enumerate(o for o in source.objects if 'Flame_Finish_Top_' in o.name):
 o=src.copy();o.data=src.data.copy();o.parent=None;o.animation_data_clear();o.location=src.location-origin
 s.collection.objects.link(o)
 if o.data.shape_keys:o.data.shape_keys.animation_data_clear()
 o.data.materials.clear();m=src.data.materials[0].copy();m.node_tree.animation_data_clear();o.data.materials.append(m)
 # Emission volumes have near-zero extinction alpha. Increase extinction while
 # retaining approved orange/golden emission for useful straight-alpha output.
 for n in m.node_tree.nodes:
  if n.type=='PRINCIPLED_VOLUME':
   for l in list(m.node_tree.links):
    if l.to_node==n and l.to_socket==n.inputs['Density']:
     l.from_node.inputs[1].default_value=30
    if l.to_node==n and l.to_socket==n.inputs['Emission Strength']:
     l.from_node.inputs[1].default_value=160 if 'Golden' in m.name else 60
 flames.append(o)
camd=bpy.data.cameras.new('Flame fixed orthographic camera');cam=bpy.data.objects.new(camd.name,camd);s.collection.objects.link(cam)
cam.location=(0,-2,.14);cam.rotation_euler=(Vector((0,0,.14))-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=.35;s.camera=cam
s.frame_start=1;s.frame_end=16;s.render.fps=16
for f in range(1,18):
 phase=math.tau*(f-1)/16
 for i,o in enumerate(flames):
  o.scale=(1+.065*math.sin(phase+i),1+.04*math.cos(phase+i),.94+.095*math.sin(phase+i*.8));o.keyframe_insert('scale',frame=f)
  if o.data.shape_keys:
   for k,sk in enumerate(list(o.data.shape_keys.key_blocks)[1:]):
    sk.value=.5+.5*math.sin(phase+i*1.3+k*math.pi);sk.keyframe_insert('value',frame=f)
  for n in o.data.materials[0].node_tree.nodes:
   if n.type=='TEX_NOISE':
    n.noise_dimensions='4D';n.inputs['W'].default_value=.8+.45*math.sin(phase+i*.9);n.inputs['W'].keyframe_insert('default_value',frame=f)
s.frame_set(1)
bpy.data.libraries.write(str(OUT/'flame_flipbook.blend'),{s})
state={'i':0}
def render_next():
 i=state['i'];bpy.context.window.scene=s
 s.frame_set(i+1);s.render.filepath=str(OUT/('frames/frame_%02d.png'%i));bpy.ops.render.render(write_still=True)
 state['i']+=1;(OUT/'render_status.json').write_text(json.dumps({'rendered':state['i']}))
 if state['i']>=16:
  bpy.context.window.scene=original_scene;return None
 return .15
bpy.app.timers.register(render_next,first_interval=.1)
