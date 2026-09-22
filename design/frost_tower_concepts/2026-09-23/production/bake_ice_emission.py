"""Bakes the cold light contained within the three-dimensional lens interior."""
import bpy
from pathlib import Path
OUT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/production/textures')
previous=bpy.context.window.scene;sc=bpy.data.scenes.new('Cold interior light bake');bpy.context.window.scene=sc
sc.render.engine='CYCLES';sc.cycles.samples=4
m=bpy.data.materials.new('Cold interior light source');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
uv=n.new('ShaderNodeTexCoord')
dist=n.new('ShaderNodeVectorMath');dist.operation='DISTANCE';dist.inputs[1].default_value=(.5,.5,0);l.new(uv.outputs['UV'],dist.inputs[0])
def rgba(h):
    vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1,)
r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.05;r.color_ramp.elements[0].color=rgba('58DCF4');r.color_ramp.elements[1].position=.52;r.color_ramp.elements[1].color=rgba('053E68');r.color_ramp.interpolation='EASE';l.new(dist.outputs['Value'],r.inputs[0])
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=12;noise.inputs['Detail'].default_value=4;l.new(uv.outputs['UV'],noise.inputs[0])
mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.25;l.new(r.outputs[0],mix.inputs[1]);l.new(noise.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=1
bpy.ops.mesh.primitive_plane_add(size=1);o=bpy.context.object;o.data.materials.append(m)
img=bpy.data.images.new('frost_ice_emission',width=512,height=512,alpha=False);node=n.new('ShaderNodeTexImage');node.image=img;n.active=node
bpy.ops.object.bake(type='EMIT',margin=4);img.filepath_raw=str(OUT/'ice_emission.png');img.file_format='PNG';img.save()
bpy.data.objects.remove(o,do_unlink=True);bpy.context.window.scene=previous;bpy.data.scenes.remove(sc)
print('ICE_INTERIOR_LIGHT_BAKED')
