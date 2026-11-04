import bpy,math,random
from mathutils import Vector
ROOT='/Users/sejin/Documents/Codex/RuneNexus/design/stage1_3d/cannon_impact/v2'
for name in ['CannonImpactV2','CannonGroundV2']:
 s=bpy.data.scenes.get(name)
 if s:bpy.data.scenes.remove(s)
def scene(name):
 s=bpy.data.scenes.new(name);s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.frame_start=1;s.frame_end=32;s.render.fps=320;s.render.fps_base=11;s.view_settings.view_transform='AgX'
 w=bpy.data.worlds.new(name+' black');w.use_nodes=True;w.node_tree.nodes['Background'].inputs['Strength'].default_value=0;s.world=w
 d=bpy.data.cameras.new(name+' camera');o=bpy.data.objects.new(d.name,d);s.collection.objects.link(o);s.camera=o;d.type='ORTHO';d.ortho_scale=4.7;o.location=(3,-7,4);o.rotation_euler=(Vector((0,0,1.15))-o.location).to_track_quat('-Z','Y').to_euler();return s
body=scene('CannonImpactV2');ground=scene('CannonGroundV2');bpy.context.window.scene=body
# One closed box bounds a continuous density field; no mesh silhouette shapes the gas.
def box(s,name,mat):
 vs=[(x,y,z) for z in [-1,1] for y in [-1,1] for x in [-1,1]];fs=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)];me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.materials.append(mat);o=bpy.data.objects.new(name,me);s.collection.objects.link(o);return o
def material(name):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes.clear();return m,m.node_tree.nodes,m.node_tree.links
def field(kind):
 m,n,L=material('Cinematic '+kind)
 def node(typ):return n.new(typ)
 def mathn(op,a,b=None):
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
 def noise(v,scale,detail):
  q=node('ShaderNodeTexNoise');q.noise_dimensions='4D';q.inputs['Scale'].default_value=scale;q.inputs['Detail'].default_value=detail;q.inputs['Roughness'].default_value=.72;L.new(v,q.inputs['Vector'])
  for f in [1,8,16,24,32]:q.inputs['W'].default_value=(f-1)*.083;q.inputs['W'].keyframe_insert(data_path='default_value',frame=f)
  return q
 coord=node('ShaderNodeTexCoord');p=vec('SUBTRACT',coord.outputs['Generated'],(.5,.5,.5));p=vec('MULTIPLY',p,(2,2,2));coarse=noise(p,2.5,3)
 warp=vec('SUBTRACT',coarse.outputs['Color'],(.5,.5,.5));warp=vec('MULTIPLY',warp,(.65,.65,.65));pwarped=vec('ADD',p,warp)
 # Height-varying twist rolls flame folds through the volume.
 sep=node('ShaderNodeSeparateXYZ');L.new(pwarped,sep.inputs[0]);rot=node('ShaderNodeVectorRotate');rot.rotation_type='AXIS_ANGLE';rot.inputs['Axis'].default_value=(0,0,1);L.new(pwarped,rot.inputs['Vector']);L.new(mathn('MULTIPLY',sep.outputs['Z'],2.8),rot.inputs['Angle']);turb=noise(rot.outputs[0],5.4,5);fine=noise(rot.outputs[0],18,2)
 leng=node('ShaderNodeVectorMath');leng.operation='LENGTH';L.new(p,leng.inputs[0])
 envelope=mathn('SUBTRACT',.88,leng.outputs['Value']);cloud=mathn('ADD',envelope,mathn('MULTIPLY',mathn('SUBTRACT',turb.outputs['Fac'],.5),.72));cloud=mathn('ADD',cloud,mathn('MULTIPLY',mathn('SUBTRACT',fine.outputs['Fac'],.5),.12));positive=mathn('MAXIMUM',cloud,0)
 fade=node('ShaderNodeValue');fade.name=kind+' lifetime'
 curve={1:.25,3:1,6:1,12:.9,17:.7,20:.4,23:.12,25:0,32:0} if kind=='fire' else {1:0,2:1,5:.7,9:.25,12:0,32:0}
 for f,val in curve.items():fade.outputs[0].default_value=val;fade.outputs[0].keyframe_insert(data_path='default_value',frame=f)
 out=node('ShaderNodeOutputMaterial');v=node('ShaderNodeVolumePrincipled');L.new(v.outputs[0],out.inputs['Volume'])
 if kind=='fire':
  density=mathn('MULTIPLY',mathn('POWER',positive,.65),3.4);L.new(mathn('MULTIPLY',density,fade.outputs[0]),v.inputs['Density']);v.inputs['Color'].default_value=(.18,.055,.018,1);v.inputs['Anisotropy'].default_value=.25
  heat=mathn('MULTIPLY',positive,2.4);r=node('ShaderNodeValToRGB');r.color_ramp.elements.remove(r.color_ramp.elements[1]);r.color_ramp.elements[0].position=0;r.color_ramp.elements[0].color=(.12,.003,.0001,1)
  for pos,col in [(.16,(.8,.045,.0005,1)),(.4,(1,.2,.004,1)),(.68,(1,.62,.10,1)),(.92,(1,.9,.54,1))]:r.color_ramp.elements.new(pos).color=col
  L.new(heat,r.inputs[0]);L.new(r.outputs['Color'],v.inputs['Emission Color']);L.new(mathn('MULTIPLY',mathn('MULTIPLY',mathn('POWER',positive,1.5),75),fade.outputs[0]),v.inputs['Emission Strength'])
 else:
  v.inputs['Color'].default_value=(.11,.085,.06,1);L.new(mathn('MULTIPLY',mathn('MULTIPLY',positive,2.5),fade.outputs[0]),v.inputs['Density'])
 return m
fire=box(body,'Turbulent combustion field',field('fire'))
for f,loc,scale in [(1,(0,0,.14),(.32,.32,.25)),(3,(0,0,.54),(1.12,1.05,.82)),(6,(0,0,.85),(1.55,1.4,1.23)),(10,(.05,0,1.04),(1.63,1.47,1.47)),(16,(.1,.05,1.23),(1.51,1.36,1.6)),(21,(.13,.08,1.42),(1.29,1.15,1.57)),(25,(.16,.08,1.56),(1.1,1,1.5)),(32,(.16,.08,1.56),(1.1,1,1.5))]:
 fire.location=loc;fire.scale=scale;fire.keyframe_insert(data_path='location',frame=f);fire.keyframe_insert(data_path='scale',frame=f)
# Subtle early ground dirt and fragments, with no persistent smoke tail.
dust=box(ground,'Brief fragmented impact dust',field('dust'))
for f in [1,3,6,9,12,32]:
 t=(f-1)*11/320;dust.location=(0,0,.1);dust.scale=(.5+2.3*min(t,.4),.5+2.3*min(t,.4),.22);dust.keyframe_insert(data_path='scale',frame=f)
def emission(name,color,strength):
 m,n,L=material(name);out=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*color,1);e.inputs[1].default_value=strength;L.new(e.outputs[0],out.inputs['Surface']);return m
sparks=emission('Cinematic hot needle sparks',(1,.32,.035),13)
metal=bpy.data.materials.new('Cinematic scorched metal');metal.diffuse_color=(.12,.055,.015,1);metal.use_nodes=True;bs=metal.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.09,.055,.026,1);bs.inputs['Metallic'].default_value=.75;bs.inputs['Roughness'].default_value=.38;bs.inputs['Emission Color'].default_value=(1,.13,.005,1);bs.inputs['Emission Strength'].default_value=.3
rng=random.Random(928)
for j in range(70):
 a=rng.uniform(0,math.tau);speed=rng.uniform(1.2,4.3);vz=rng.uniform(1.2,4.5);vel=Vector((math.cos(a)*speed,math.sin(a)*speed,vz));death=rng.uniform(.42,1.07);delay=rng.uniform(0,.035)
 # Very thin tapered tetrahedra create crisp streaks without thick cartoon rays.
 width=rng.uniform(.002,.006);length=rng.uniform(.035,.105);me=bpy.data.meshes.new('Spark needle');me.from_pydata([(-width,0,0),(width,0,0),(0,width,0),(0,0,length)],[],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)]);me.materials.append(sparks);o=bpy.data.objects.new('Ballistic ember %02d'%j,me);body.collection.objects.link(o)
 for f in range(1,33):
  t=(f-1)*11/320-delay;o.location=vel*max(t,0)+Vector((0,0,.08-3.2*max(t,0)**2));direction=vel+Vector((0,0,-6.4*max(t,0)));o.rotation_euler=direction.to_track_quat('Z','Y').to_euler();o.scale=(1,1,max(.15,1-t));o.hide_render=t<0 or t>death or o.location.z<.015 or f==32
  for path in ['location','rotation_euler','scale','hide_render']:o.keyframe_insert(data_path=path,frame=f)
for j in range(15):
 a=rng.uniform(0,math.tau);speed=rng.uniform(.6,2.5);vz=rng.uniform(.9,2.8);vel=Vector((math.cos(a)*speed,math.sin(a)*speed,vz));size=rng.uniform(.012,.04);me=bpy.data.meshes.new('Metal chip');me.from_pydata([(-size,-size*.3,0),(size,-size*.2,0),(size*.2,size*.5,0),(0,0,size*.6)],[],[(0,2,1),(0,1,3),(1,2,3),(2,0,3)]);me.materials.append(metal);o=bpy.data.objects.new('Small metal fragment %02d'%j,me);ground.collection.objects.link(o)
 for f in range(1,33):
  t=(f-1)*11/320;o.location=vel*t+Vector((0,0,.05-3.5*t*t));o.rotation_euler=(t*8+j,t*5,t*3);o.hide_render=f==1 or o.location.z<.01 or f>22
  for path in ['location','rotation_euler','hide_render']:o.keyframe_insert(data_path=path,frame=f)
for s in [body,ground]:
 for o in s.objects:
  if o.animation_data and o.animation_data.action:
   try:
    for fc in o.animation_data.action.fcurves:
     for kp in fc.keyframe_points:kp.interpolation='CONSTANT' if fc.data_path=='hide_render' else 'LINEAR'
   except AttributeError:pass
body.frame_set(8);ground.frame_set(8);bpy.context.window.scene=body
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/cannon_impact_cinematic.blend')
print('Cinematic scenes ready: 32 frames, 320/11 fps, origin ground contact, +Z up')
