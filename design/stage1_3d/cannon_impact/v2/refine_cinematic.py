"""Apply the same volume refinement to source or composed review scenes in place."""
import bpy
m=bpy.data.materials.get('Cinematic fire')
if m is None:raise RuntimeError('Cinematic fire material missing')
n=m.node_tree.nodes;L=m.node_tree.links;n.clear();m.node_tree.animation_data_clear()
def node(typ,name=None):
 q=n.new(typ)
 if name:q.name=name
 return q
def calc(op,a,b=None):
 q=node('ShaderNodeMath');q.operation=op
 for i,val in enumerate([a,b]):
  if val is not None:
   if hasattr(val,'node'):L.new(val,q.inputs[i])
   else:q.inputs[i].default_value=val
 return q.outputs[0]
def vec(op,a,b=None):
 q=node('ShaderNodeVectorMath');q.operation=op
 for i,val in enumerate([a,b]):
  if val is not None:
   if hasattr(val,'node'):L.new(val,q.inputs[i])
   else:q.inputs[i].default_value=val
 return q.outputs[0]
def noise(p,scale,detail,name):
 q=node('ShaderNodeTexNoise',name);q.noise_dimensions='4D';q.inputs['Scale'].default_value=scale;q.inputs['Detail'].default_value=detail;q.inputs['Roughness'].default_value=.72;L.new(p,q.inputs['Vector'])
 for f in [1,8,16,24,32]:q.inputs['W'].default_value=(f-1)*.083;q.inputs['W'].keyframe_insert(data_path='default_value',frame=f)
 return q
coord=node('ShaderNodeTexCoord');p=vec('MULTIPLY',vec('SUBTRACT',coord.outputs['Generated'],(.5,.5,.5)),(2,2,2));coarse=noise(p,1.7,2,'Large asymmetric gas rolls');warp=vec('MULTIPLY',vec('SUBTRACT',coarse.outputs['Color'],(.5,.5,.5)),(1.05,.95,.85));pw=vec('ADD',p,warp)
sep=node('ShaderNodeSeparateXYZ');L.new(pw,sep.inputs[0]);rot=node('ShaderNodeVectorRotate');rot.rotation_type='AXIS_ANGLE';rot.inputs['Axis'].default_value=(0,0,1);L.new(pw,rot.inputs['Vector']);L.new(calc('MULTIPLY',sep.outputs['Z'],2.8),rot.inputs['Angle'])
turb=noise(rot.outputs[0],4.2,4,'Rolling combustion cells');fine=noise(rot.outputs[0],15,2,'Fine torn folds')
distance=node('ShaderNodeVectorMath');distance.operation='LENGTH';L.new(pw,distance.inputs[0]);cloud=calc('ADD',calc('SUBTRACT',.78,distance.outputs['Value']),calc('MULTIPLY',calc('SUBTRACT',turb.outputs['Fac'],.5),.54));cloud=calc('MAXIMUM',cloud,0)
# Fade to exactly zero at every bounding-box plane, independent of displacement.
edge=node('ShaderNodeSeparateXYZ');L.new(p,edge.inputs[0]);maximum=calc('MAXIMUM',calc('MAXIMUM',calc('ABSOLUTE',edge.outputs['X']),calc('ABSOLUTE',edge.outputs['Y'])),calc('ABSOLUTE',edge.outputs['Z']));boundary=calc('MINIMUM',calc('MAXIMUM',calc('MULTIPLY',calc('SUBTRACT',1,maximum),8),0),1);cloud=calc('MULTIPLY',cloud,boundary)
fade=node('ShaderNodeValue','fire lifetime')
for f,val in {1:.25,3:1,6:1,12:.9,17:.7,20:.4,23:.12,25:0,32:0}.items():fade.outputs[0].default_value=val;fade.outputs[0].keyframe_insert(data_path='default_value',frame=f)
# Heat is local turbulent fuel concentration, never radial distance to the center.
local=calc('ADD',turb.outputs['Fac'],calc('MULTIPLY',calc('SUBTRACT',fine.outputs['Fac'],.5),.16));gate=calc('MINIMUM',calc('MAXIMUM',calc('MULTIPLY',calc('SUBTRACT',local,.40),3.8),0),1)
out=node('ShaderNodeOutputMaterial');v=node('ShaderNodeVolumePrincipled');L.new(v.outputs['Volume'],out.inputs['Volume']);v.inputs['Color'].default_value=(.09,.025,.007,1);v.inputs['Anisotropy'].default_value=.15
# Dense cooler gas absorbs light between hot folds; emission is confined to hot cells.
density=calc('MULTIPLY',calc('POWER',cloud,.7),15);L.new(calc('MULTIPLY',density,fade.outputs[0]),v.inputs['Density']);strength=calc('MULTIPLY',calc('MULTIPLY',calc('POWER',gate,2.7),22),calc('MINIMUM',calc('MULTIPLY',cloud,4),1));L.new(calc('MULTIPLY',strength,fade.outputs[0]),v.inputs['Emission Strength'])
r=node('ShaderNodeValToRGB','Restricted golden cores');r.color_ramp.elements.remove(r.color_ramp.elements[1]);r.color_ramp.elements[0].position=0;r.color_ramp.elements[0].color=(.075,.001,.00005,1)
for pos,col in [(.26,(.65,.018,.0002,1)),(.50,(1,.095,.001,1)),(.73,(1,.34,.015,1)),(.90,(1,.68,.14,1)),(.99,(1,.9,.55,1))]:r.color_ramp.elements.new(pos).color=col
L.new(gate,r.inputs[0]);L.new(r.outputs['Color'],v.inputs['Emission Color'])
for s in bpy.data.scenes:s.frame_set(s.frame_current)
print('Refined Cinematic fire: asymmetrical warped envelope, absorption folds, noise-only heat, peak emission 22')
