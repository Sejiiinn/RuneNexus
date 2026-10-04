"""True 3D editable volume material matching the native local-density formula.
Geometry and authored instance animation stay unchanged. Export the hidden master's
separate fallback PBR material; glTF does not encode this volume node tree.
"""
from pathlib import Path
import bpy,json
HERE=Path(__file__).resolve().parent
scene=bpy.data.scenes['PlacementDust3D']
puff=scene.objects['placement_dust_puff']
size=[max(v.co[i] for v in puff.data.vertices)-min(v.co[i] for v in puff.data.vertices) for i in range(3)]
manifest=json.loads((HERE/'burst_manifest.json').read_text())
if bpy.data.materials.get('PlacementDust_True3DVolume'):
    raise RuntimeError('Edit existing PlacementDust_True3DVolume nodes rather than overwriting.')
material=bpy.data.materials.new('PlacementDust_True3DVolume')
material.use_nodes=True
nodes=material.node_tree.nodes; links=material.node_tree.links
nodes.clear()
def node(kind,label):
    result=nodes.new(kind);result.label=label;result.name=label
    return result
def wire(value,socket):
    if hasattr(value,'node'):links.new(value,socket)
    else:socket.default_value=value
def math(op,*inputs,label=None):
    result=node('ShaderNodeMath',label or op);result.operation=op
    for index,value in enumerate(inputs):wire(value,result.inputs[index])
    return result.outputs[0]
def vector(op,*inputs,label=None):
    result=node('ShaderNodeVectorMath',label or op);result.operation=op
    for index,value in enumerate(inputs):wire(value,result.inputs[index])
    return result.outputs['Value'] if op in ['DOT_PRODUCT','LENGTH','DISTANCE'] else result.outputs['Vector']
def mix(a,b,f):return math('ADD',math('MULTIPLY',a,math('SUBTRACT',1.0,f)),math('MULTIPLY',b,f))
def split(v):
    result=node('ShaderNodeSeparateXYZ','density xyz');wire(v,result.inputs[0]);return [result.outputs[c] for c in 'XYZ']
texcoord=node('ShaderNodeTexCoord','Object-space actual 3D position')
normalized=vector('DIVIDE',texcoord.outputs['Object'],tuple(size),label='Normalize proxy mesh bounds')
# Godot p=(Blender x,z,-y), independent of each object's motion/rotation.
x,y,z=split(normalized)
combine=node('ShaderNodeCombineXYZ','Godot density coordinates')
wire(x,combine.inputs[0]);wire(z,combine.inputs[1]);wire(math('MULTIPLY',y,-1),combine.inputs[2])
p=combine.outputs[0]
progress=node('ShaderNodeValue','Normalized burst age');progress.outputs[0].default_value=0
for frame,value in [(1,0),(20,1)]:progress.outputs[0].default_value=value;progress.outputs[0].keyframe_insert(data_path='default_value',frame=frame)
age=progress.outputs[0]
info=node('ShaderNodeObjectInfo','Authored puff index')
flow=node('ShaderNodeCombineXYZ','3D density flow')
wire(math('MULTIPLY',age,.6),flow.inputs[0]);wire(math('MULTIPLY',info.outputs['Object Index'],7.3),flow.inputs[1]);wire(math('MULTIPLY',age,-.3),flow.inputs[2])
material_nodes,material_links=nodes,links
noise_group=bpy.data.node_groups.new('PlacementDust_HashValueNoise3D','ShaderNodeTree')
noise_group.interface.new_socket(name='Position',in_out='INPUT',socket_type='NodeSocketVector')
noise_group.interface.new_socket(name='Noise',in_out='OUTPUT',socket_type='NodeSocketFloat')
nodes,links=noise_group.nodes,noise_group.links
input_node=node('NodeGroupInput','3D position')
q=input_node.outputs['Position']
cell=vector('FLOOR',q)
f=vector('SUBTRACT',q,cell)
f=vector('MULTIPLY',vector('MULTIPLY',f,f),vector('SUBTRACT',(3.,3.,3.),vector('MULTIPLY',f,(2.,2.,2.))))
fx,fy,fz=split(f)
hashes={}
for i in range(8):
    offset=((i&1),((i>>1)&1),((i>>2)&1))
    dot=vector('DOT_PRODUCT',vector('ADD',cell,offset),(127.1,311.7,74.7))
    hashes[i]=math('FRACT',math('MULTIPLY',math('SINE',dot),43758.5453),label='Hash3 corner '+str(i))
x00=mix(hashes[0],hashes[1],fx);x10=mix(hashes[2],hashes[3],fx)
x01=mix(hashes[4],hashes[5],fx);x11=mix(hashes[6],hashes[7],fx)
noise_output=mix(mix(x00,x10,fy),mix(x01,x11,fy),fz)
output_node=node('NodeGroupOutput','Interpolated 3D density')
wire(noise_output,output_node.inputs['Noise'])
nodes,links=material_nodes,material_links
def noise3(position,label):
    result=node('ShaderNodeGroup',label);result.node_tree=noise_group
    wire(position,result.inputs['Position']);return result.outputs['Noise']
warp_coordinate=vector('ADD',vector('MULTIPLY',p,(4.,4.,4.)),flow.outputs[0])
warp=node('ShaderNodeCombineXYZ','Irregular 3D cloud boundary')
for i,offset in enumerate([(0.,0.,0.),(13.,4.,7.),(3.,17.,9.)]):
    wire(math('SUBTRACT',noise3(vector('ADD',warp_coordinate,offset),'Boundary warp '+str(i)),.5),warp.inputs[i])
warped=vector('ADD',p,vector('MULTIPLY',warp.outputs[0],(.20,.20,.20)))
radius=vector('LENGTH',warped,label='Warped normalized radial density')
t=math('MINIMUM',math('MAXIMUM',math('DIVIDE',math('SUBTRACT',radius,.08),.41),0.),1.)
smooth=math('MULTIPLY',math('MULTIPLY',t,t),math('SUBTRACT',3.,math('MULTIPLY',2.,t)))
shape=math('SUBTRACT',1.,smooth,label='1 - smoothstep(0.08, 0.49, warped radius)')
turbulence=noise3(vector('ADD',vector('MULTIPLY',p,(3.8,3.8,3.8)),flow.outputs[0]),'Spatial cloud density')
strength=math('ADD',.20,math('MULTIPLY',.80,turbulence),label='3D noise strength 0.20..1')
envelope=node('ShaderNodeValue','Author opacity envelope')
for frame,value in [(1,0),(3,.58),(10,.38),(20,0)]:
    envelope.outputs[0].default_value=value;envelope.outputs[0].keyframe_insert(data_path='default_value',frame=frame)
density=math('MULTIPLY',math('MULTIPLY',shape,strength),math('MULTIPLY',envelope.outputs[0],2.8),label='Authored normalized optical density')
# Blender integrates physical world distances; native integrates normalized proxy
# distances. Convert the metric so scaling the authored puff preserves its opacity.
geometry=node('ShaderNodeNewGeometry','Volume ray direction')
convert=node('ShaderNodeVectorTransform','World ray to object metric');convert.vector_type='VECTOR';convert.convert_from='WORLD';convert.convert_to='OBJECT'
wire(geometry.outputs['Incoming'],convert.inputs['Vector'])
metric=vector('LENGTH',vector('DIVIDE',convert.outputs[0],tuple(size)),label='Normalized density units per world unit')
density=math('MULTIPLY',density,metric,label='Physical density with native optical metric')
volume=node('ShaderNodeVolumePrincipled','True 3D dust volume')
volume.inputs['Color'].default_value=(.57,.53,.46,1)
volume.inputs['Anisotropy'].default_value=0
wire(density,volume.inputs['Density'])
output=node('ShaderNodeOutputMaterial','Volume output; no surface shell')
links.new(volume.outputs['Volume'],output.inputs['Volume'])
material['density_contract']='(1-smoothstep(.08,.49,length(p+warp*.20))) * (.20+.80*hashValueNoise3(p*3.8+flow)) * authorOpacity(age) * 2.8; flow=(age*.6,index*7.3,-age*.3)'
material['color_contract']='Matte warm grey (.57,.53,.46), zero emission; physical source scattering vs native unshaded integrated density'
material['metric_contract']='Object geometry is bounds normalized; source physical density converts normalized ray-length units into world ray length.'
for obj in bpy.data.collections['PlacementDust_BurstPreview'].objects:
    obj.pass_index=int(obj.name.rsplit('_',1)[-1])
    obj.material_slots[0].link='OBJECT';obj.material_slots[0].material=material
for layer in material.node_tree.animation_data.action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for point in curve.keyframe_points:point.interpolation='LINEAR'
scene.frame_set(6)
manifest['volume']={'representation':'true 3D spatial density; closed geometry is a proxy, no surface shell',
    'normalized_coordinates':'p=mesh_vertex/mesh_size, approximately -0.5..0.5',
    'shape_smoothstep':[.08,.49],'noise_scale':3.8,'noise_strength':[.20,.80],
    'warp_scale':4.,'warp_amplitude':.20,'warp_offsets':[[0,0,0],[13,4,7],[3,17,9]],'index_phase':7.3,
    'noise_advection':[.6,0,-.3],'density_multiplier':2.8,'color':[.57,.53,.46],
    'native_steps':12,'opaque_depth_clip':True,'source_material':material.name,
    'native_color_alpha_factor':[.8,.2],
    'native_tint':[.60,.56,.48],'native_tint_mix':.55}
manifest['native_guidance']='shared MultiMesh closed proxy with normalized 3D density ray integration and opaque depth clipping; no surface shell/sprite/extra light'
(HERE/'burst_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PLACEMENT_DUST_VOLUME nodes='+str(len(nodes))+' material='+material.name)
