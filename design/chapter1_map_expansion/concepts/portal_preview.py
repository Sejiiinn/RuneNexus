"""Static battle_time=0 translation of godot/environment/portal_vortex.gdshader.
Only material on the concept copy is changed; approved portal geometry is retained.
"""
import bpy

def apply(portal):
 m=bpy.data.materials.new('Portal runtime shader static preview');m.use_nodes=True
 n=m.node_tree.nodes;n.clear();links=m.node_tree.links
 def math(op,*args):
  q=n.new('ShaderNodeMath');q.operation=op
  for i,a in enumerate(args):
   if isinstance(a,(int,float)):q.inputs[i].default_value=a
   else:links.new(a,q.inputs[i])
  return q.outputs[0]
 def smooth(a,lo,hi):
  q=n.new('ShaderNodeMapRange');q.interpolation_type='SMOOTHSTEP';q.clamp=True;links.new(a,q.inputs['Value']);q.inputs['From Min'].default_value=lo;q.inputs['From Max'].default_value=hi
  return q.outputs['Result']
 tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');links.new(tc.outputs['Object'],sep.inputs[0])
 x=math('DIVIDE',sep.outputs['X'],.305);y=math('DIVIDE',sep.outputs['Y'],.305)
 r=math('SQRT',math('ADD',math('MULTIPLY',x,x),math('MULTIPLY',y,y)))
 angle=math('ARCTAN2',y,x);phase=math('ADD',math('MULTIPLY',angle,3),math('MULTIPLY',r,12))
 band=math('POWER',math('MAXIMUM',0,math('SINE',math('ADD',phase,math('MULTIPLY',math('SINE',math('MULTIPLY',r,15)),.35)))),5)
 ring=math('EXPONENT',math('MULTIPLY',-1,math('POWER',math('MULTIPLY',math('SUBTRACT',r,.92),24),2)))
 energy=math('ADD',math('MULTIPLY',math('MULTIPLY',band,smooth(r,.1,.5)),math('SUBTRACT',1,smooth(r,.86,1))),math('MULTIPLY',ring,.62))
 comb=n.new('ShaderNodeCombineColor');comb.mode='RGB'
 for i,(base,delta,bright) in enumerate([(.008,.052,.574),(.002,.010,.1565),(.020,.110,1.214)]):
  links.new(math('ADD',math('ADD',base,math('MULTIPLY',r,delta)),math('MULTIPLY',energy,bright)),comb.inputs[i])
 em=n.new('ShaderNodeEmission');links.new(comb.outputs[0],em.inputs['Color']);out=n.new('ShaderNodeOutputMaterial');links.new(em.outputs[0],out.inputs['Surface'])
 portal.data=portal.data.copy();portal.data.materials.clear();portal.data.materials.append(m)
