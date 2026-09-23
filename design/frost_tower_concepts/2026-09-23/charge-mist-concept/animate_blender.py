import bpy,math
from pathlib import Path
OUT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/charge-mist-concept')
s=bpy.data.scenes['Frost charge mist concept'];bpy.context.window.scene=s
s.frame_start=1;s.frame_end=192;s.render.fps=24
source=next(o for o in s.objects if o.name.startswith('Mist source'))
mat=bpy.data.materials.new('Mist preview - noise broken soft volume surface');mat.use_nodes=True
n=mat.node_tree.nodes;l=mat.node_tree.links;n.clear()
out=n.new('ShaderNodeOutputMaterial');mix=n.new('ShaderNodeMixShader');transparent=n.new('ShaderNodeBsdfTransparent');diffuse=n.new('ShaderNodeBsdfPrincipled');diffuse.inputs['Base Color'].default_value=(.38,.67,.74,1);diffuse.inputs['Roughness'].default_value=1
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=3.8;noise.inputs['Detail'].default_value=2
layer=n.new('ShaderNodeLayerWeight');mult=n.new('ShaderNodeMath');mult.operation='MULTIPLY';gain=n.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.inputs[1].default_value=.35
l.new(noise.outputs['Fac'],mult.inputs[0]);l.new(layer.outputs['Facing'],mult.inputs[1]);l.new(mult.outputs[0],gain.inputs[0]);l.new(gain.outputs[0],mix.inputs[0]);l.new(transparent.outputs[0],mix.inputs[1]);l.new(diffuse.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs[0])
source.data.materials.clear();source.data.materials.append(mat)
for i in range(32):
 o=source.copy();o.data=source.data;s.collection.objects.link(o);o.name=f'Animated 3D mist lobe {i:02d}';o.hide_render=False
 seed=(i*.618)%1;theta=(i*.381966)%1*math.tau;band=.25+.75*((i*.719)%1)
 for f in [1,111,112,115,120,126,131,136,138,192]:
  age=max(0,min(1,(f/24-4.65)/1.05));p=1-(1-age)**2.2;r=(.18+1.20*p)*(.42+.58*band)*1.58/1.92;size=(.08+.24*p)*(.72+.53*seed)
  alive=112<=f<=136
  o.location=(math.cos(theta)*r,math.sin(theta)*r,.09+p*(.07+.22*seed));o.scale=(size*1.5*1.58/1.92,size*1.35*1.58/1.92,size*1.4) if alive else (.0001,)*3
  o.keyframe_insert('location',frame=f);o.keyframe_insert('scale',frame=f)
source.hide_render=True
s.frame_set(37)
bpy.data.libraries.write(str(OUT/'charge-mist.blend'),{s},fake_user=True,compress=True)
print('BLENDER_ANIMATION_SAVED')
