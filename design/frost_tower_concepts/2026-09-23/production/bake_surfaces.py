"""Blender-native procedural metal and ice surface bakes; no source-scene edits."""
import bpy
from pathlib import Path
OUT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/production/textures');OUT.mkdir(exist_ok=True)
previous=bpy.context.window.scene
sc=bpy.data.scenes.new('Frost PBR surface bake');bpy.context.window.scene=sc
sc.render.engine='CYCLES';sc.cycles.samples=8
sc.render.bake.use_pass_direct=False;sc.render.bake.use_pass_indirect=False;sc.render.bake.use_pass_color=True
def rgba(h):
    vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1,)
def make_surface(kind):
    m=bpy.data.materials.new('Bake '+kind);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    tex=n.new('ShaderNodeTexCoord');uv=tex.outputs['UV']
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7;noise.inputs['Detail'].default_value=4;l.new(uv,noise.inputs['Vector'])
    dis=n.new('ShaderNodeVectorMath');dis.operation='SCALE';dis.inputs[3].default_value=.04;l.new(noise.outputs['Color'],dis.inputs[0])
    add=n.new('ShaderNodeVectorMath');add.operation='ADD';l.new(uv,add.inputs[0]);l.new(dis.outputs[0],add.inputs[1])
    v=n.new('ShaderNodeTexVoronoi');v.feature='DISTANCE_TO_EDGE';v.inputs['Scale'].default_value=19 if kind=='metal' else 13;l.new(add.outputs[0],v.inputs['Vector'])
    grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=95;grain.inputs['Detail'].default_value=3;l.new(uv,grain.inputs[0])
    color=n.new('ShaderNodeValToRGB');color.color_ramp.elements[0].color=rgba('29373D' if kind=='metal' else '03385F');color.color_ramp.elements[1].color=rgba('526068' if kind=='metal' else '24A3C2');l.new(noise.outputs[0],color.inputs[0])
    cracks=n.new('ShaderNodeValToRGB');cracks.color_ramp.elements[0].position=.002;cracks.color_ramp.elements[1].position=.012 if kind=='metal' else .008;l.new(v.outputs['Distance'],cracks.inputs[0])
    mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=rgba('15272F' if kind=='metal' else 'A1E8EF');l.new(cracks.outputs[0],mix.inputs[0]);l.new(color.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],p.inputs['Base Color'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.23 if kind=='metal' else .12;bump.inputs['Distance'].default_value=.0015 if kind=='metal' else .001;l.new(v.outputs[0],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
    rough=n.new('ShaderNodeMapRange');rough.inputs['To Min'].default_value=.32 if kind=='metal' else .13;rough.inputs['To Max'].default_value=.57 if kind=='metal' else .28;l.new(grain.outputs[0],rough.inputs[0]);l.new(rough.outputs[0],p.inputs['Roughness'])
    return m
for kind in ['metal','ice']:
    bpy.ops.mesh.primitive_plane_add(size=1);o=bpy.context.object;m=make_surface(kind);o.data.materials.append(m)
    for channel,mode in [('basecolor','DIFFUSE'),('normal','NORMAL'),('roughness','ROUGHNESS')]:
        im=bpy.data.images.new(f'frost_{kind}_{channel}',width=1024,height=1024,alpha=False)
        if channel!='basecolor':im.colorspace_settings.name='Non-Color'
        node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;m.node_tree.nodes.active=node
        bpy.ops.object.bake(type=mode,margin=8)
        im.filepath_raw=str(OUT/f'{kind}_{channel}.png');im.file_format='PNG';im.save()
    bpy.data.objects.remove(o,do_unlink=True)
bpy.context.window.scene=previous
bpy.data.scenes.remove(sc)
print('FROST_SURFACES_BAKED')
