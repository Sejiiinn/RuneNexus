import bpy, math, random, os
from mathutils import Vector
ROOT='/Users/sejin/Documents/Codex/RuneNexus/design/stage1_3d/cannon_impact'
random.seed(24)
scene=bpy.data.scenes.new('CannonImpact3D')
bpy.context.window.scene=scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
world=bpy.data.worlds.new('ImpactDarkWorld');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Strength'].default_value=0
camdata=bpy.data.cameras.new('ImpactOrtho');cam=bpy.data.objects.new('ImpactOrtho',camdata);scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=4
cam.location=(0,-10,1.28);cam.rotation_euler=(Vector((0,0,1.28))-cam.location).to_track_quat('-Z','Y').to_euler()
# Principled volumes create genuine soft light transport without round smoke meshes.
def volume(name,color,density,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Color'].default_value=(*color,1);v.inputs['Emission Color'].default_value=(*color,1);v.inputs['Emission Strength'].default_value=emission
 tex=n.new('ShaderNodeTexNoise');tex.noise_dimensions='3D';tex.inputs['Scale'].default_value=7;tex.inputs['Detail'].default_value=4;tex.inputs['Roughness'].default_value=.75
 coord=n.new('ShaderNodeTexCoord');m.node_tree.links.new(coord.outputs['Generated'],tex.inputs['Vector']);r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.37;r.color_ramp.elements[1].position=.72
 m.node_tree.links.new(tex.outputs['Fac'],r.inputs[0]);mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=density;m.node_tree.links.new(r.outputs['Color'],mul.inputs[0]);m.node_tree.links.new(mul.outputs[0],v.inputs['Density']);m.node_tree.links.new(v.outputs[0],out.inputs['Volume']);return m
fire=volume('Ivory turbulent flame',(1,.24,.025),4,1.5)
smoke=volume('Torn charcoal dust',(.27,.24,.2),2.8,0)
def emit(name,col,power):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*col,1);e.inputs[1].default_value=power;m.node_tree.links.new(e.outputs[0],o.inputs[0]);return m
hot=emit('White hot core',(1,.82,.45),8);gold=emit('Copper sparks',(1,.25,.025),4)
objects=[]
def tube(name,points,widths,mat):
 verts=[];faces=[];N=7
 for j,p in enumerate(points):
  axis=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
  axis.normalize();side=axis.cross(Vector((0,1,0))).normalized();other=axis.cross(side).normalized()
  for k in range(N):
   a=k*math.tau/N;verts.append(Vector(p)+widths[j]*(math.cos(a)*side+math.sin(a)*other))
 for j in range(len(points)-1):
  for k in range(N):faces.append((j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k))
 faces.extend([tuple(reversed(range(N))),tuple((len(points)-1)*N+k for k in range(N))]);mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(mat);o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);objects.append(o);return o
# Each frame is a separately editable collection; visibility is keyed for playback.
for f in range(12):
 start=len(objects);t=f/11
 if f<11:
  peak=[.45,1,.9,.72,.53,.35,.2,.1,.06,.035,.015][f]
  for j in range(15):
   rng=random.Random(100+j);a=rng.uniform(-1.3,1.3);length=rng.uniform(1.0,2.8)*(min(1,(f+1)/2))
   x=math.sin(a)*length*.65;z=math.cos(a)*length;depth=rng.uniform(-.2,.2)
   if f<6:
    w=rng.uniform(.06,.16)*peak
    tube('F%02d flame tongue %02d'%(f,j),[(0,0,.05),(x*.3,depth,z*.32),(x*.72,depth*.6,z*.74),(x,depth,z)],[w*.8,w,w*.52,.003],fire)
    if f<4:tube('F%02d white filament %02d'%(f,j),[(0,-.04,.04),(x*.7,depth-.05,z*.7),(x,depth-.05,z)],[.023*peak,.011*peak,.001],gold)
  for j in range(38):
   rng=random.Random(700+j);a=rng.uniform(-1.5,1.5);speed=rng.uniform(.5,1.7);u=(f+.25)/11;x=math.sin(a)*speed*u;z=max(.01,math.cos(a)*speed*u*2.4-1.8*u*u)
   if rng.random()<1-t*.8:
    length=.045+.13*(1-t);tube('F%02d incandescent shard %02d'%(f,j),[(x,0,z),(x-math.sin(a)*length,0,z-math.cos(a)*length)],[.009*(1-t*.7),.001],hot if f<3 else gold)
  if 1<f<8:
   for j in range(6):
    rng=random.Random(500+j);x=rng.uniform(-1,1)*(t+.25);z=.3+rng.uniform(.3,1.5)*t
    w=(.05+.12*t)*(1 if f<8 else (11-f)/4)
    tube('F%02d torn smoke ribbon %02d'%(f,j),[(x*.35,.16,z*.5),(x,.13,z),(x+.12,.15,z+.35),(x-.08,.16,z+.7)],[w*.6,w,w*.6,.002],smoke)
 for o in objects[start:]:
  for k in range(12):o.hide_render=(k!=f or ('dust' in o.name and f>=8));o.keyframe_insert(data_path='hide_render',frame=k+1)
for o in objects:
 if o.type=='MESH':
  for vertex in o.data.vertices: vertex.co.x*=1.6;vertex.co.z*=1.55
scene.frame_start=1;scene.frame_end=12
# Separate true-top-view ground scene, sharing materials but not body geometry.
ground=bpy.data.scenes.new('CannonGround3D');ground.render.engine='CYCLES';ground.cycles.samples=24;ground.cycles.use_denoising=True;ground.render.resolution_x=256;ground.render.resolution_y=256;ground.render.resolution_percentage=100;ground.render.film_transparent=True;ground.render.image_settings.file_format='PNG';ground.render.image_settings.color_mode='RGBA';ground.view_settings.view_transform='Standard';ground.world=world
bpy.context.window.scene=ground;scene=ground
c=bpy.data.objects.new('GroundOrtho',camdata.copy());scene.collection.objects.link(c);c.location=(0,0,10);c.rotation_euler=(0,0,0);scene.camera=c
objects=[]
for f in range(12):
 start=len(objects);t=f/11
 if 0<f<11:
  radius=.18+1.55*math.sqrt(t)
  for j in range(30):
   rng=random.Random(900+j);a=j*math.tau/30+rng.uniform(-.04,.04);span=rng.uniform(.045,.17);r=radius*rng.uniform(.94,1.04);w=.05*(1-t)+.055
   points=[(r*math.cos(a+span*k/3),r*math.sin(a+span*k/3),.03) for k in range(4)]
   tube('G%02d broken dust crest %02d'%(f,j),points,[.004,w,w*.7,.001],fire if f<3 else smoke)
   if f>=8: objects[-1].hide_render=True
  for j in range(20):
   rng=random.Random(300+j);a=rng.uniform(0,math.tau);r=radius*rng.uniform(.55,1.05)
   tube('G%02d ground shard %02d'%(f,j),[(r*math.cos(a),r*math.sin(a),.04),((r-.1)*math.cos(a),(r-.1)*math.sin(a),.04)],[.007*(1-t),.001],gold)
 for o in objects[start:]:
  for k in range(12):o.hide_render=(k!=f or ('dust' in o.name and f>=8));o.keyframe_insert(data_path='hide_render',frame=k+1)
scene.frame_start=1;scene.frame_end=12

import bpy,math
from mathutils import Vector
s=bpy.data.scenes['CannonImpact3D'];bpy.context.window.scene=s
for o in s.objects:
 if o.type!='MESH':continue
 f=int(o.name[1:3])
 if ('white filament' in o.name and f>=2) or ('flame tongue' in o.name and f>=2 and int(o.name[-2:]) not in [1,5,8,12]):
  o.animation_data_clear();o.hide_render=True
 elif 'flame tongue' in o.name and f>=2:
  j=int(o.name[-2:]);verts=o.data.vertices
  for ring in range(len(verts)//7):
   vs=[verts[ring*7+k] for k in range(7)];center=sum((v.co for v in vs),Vector())/7
   bend=Vector((.21*math.sin(ring*math.pi/3)*(1 if j%2 else -1),0,.08*math.sin(ring*math.pi/3)))
   for v in vs:v.co=center+bend+(v.co-center)*3.5
m=bpy.data.materials['Ivory turbulent flame'];n=m.node_tree.nodes;v=n.get('Principled Volume');tex=n.get('Noise Texture');r=n.new('ShaderNodeValToRGB');r.name='Flame ivory-amber turbulence';r.color_ramp.elements[0].position=.25;r.color_ramp.elements[0].color=(.55,.025,.001,1);r.color_ramp.elements[1].position=.8;r.color_ramp.elements[1].color=(1,.78,.3,1);m.node_tree.links.new(tex.outputs['Fac'],r.inputs[0]);m.node_tree.links.new(r.outputs['Color'],v.inputs['Emission Color']);v.inputs['Emission Strength'].default_value=3

import bpy
from mathutils import Vector
s=bpy.data.scenes['CannonImpact3D']
for o in s.objects:
 if o.type!='MESH':continue
 f=int(o.name[1:3])
 for v in o.data.vertices:v.co.x/=1.6;v.co.z/=1.55
 if 'flame tongue' in o.name and f>=2:
  for ring in range(len(o.data.vertices)//7):
   vs=[o.data.vertices[ring*7+k] for k in range(7)];center=sum((v.co for v in vs),Vector())/7
   for v in vs:v.co=center+(v.co-center)*.6
m=bpy.data.materials['Ivory turbulent flame'];n=m.node_tree.nodes;v=n.get('Principled Volume');density=n.get('Math');mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=.35;m.node_tree.links.new(density.outputs[0],mul.inputs[0]);m.node_tree.links.new(mul.outputs[0],v.inputs['Emission Strength'])

import bpy,math
from mathutils import Vector
s=bpy.data.scenes['CannonImpact3D'];m=bpy.data.materials['Ivory turbulent flame']
for o in s.objects:
 if o.type!='MESH' or 'flame tongue' not in o.name or int(o.name[1:3])<2 or o.animation_data is None:continue
 vs=o.data.vertices;tip=sum((vs[len(vs)-7+k].co for k in range(7)),Vector())/7;base=sum((vs[k].co for k in range(7)),Vector())/7;direction=tip-base;length=direction.length
 verts=[(x,y,z) for z in [0,1] for y in [-.5,.5] for x in [-.5,.5]];faces=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)];mesh=bpy.data.meshes.new(o.name+' volume container');mesh.from_pydata(verts,[],faces);mesh.materials.append(m);o.data=mesh;o.location=base;o.rotation_euler=direction.to_track_quat('Z','Y').to_euler();o.scale=(.68,.54,length)

import bpy
m=bpy.data.materials['Ivory turbulent flame']
# The box only bounds a curved density field; density reaches zero before every side.
n=m.node_tree.nodes;n.clear();L=m.node_tree.links;o=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');L.new(v.outputs['Volume'],o.inputs['Volume']);v.inputs['Color'].default_value=(.85,.24,.04,1)
def calc(op,a,b=None):
 q=n.new('ShaderNodeMath');q.operation=op
 for i,val in enumerate([a,b]):
  if val is None:continue
  if hasattr(val,'node'):L.new(val,q.inputs[i])
  else:q.inputs[i].default_value=val
 return q.outputs[0]
co=n.new('ShaderNodeTexCoord');sp=n.new('ShaderNodeSeparateXYZ');L.new(co.outputs['Generated'],sp.inputs[0]);z=sp.outputs['Z'];bend=calc('MULTIPLY',calc('SINE',calc('MULTIPLY',z,4.5)),.12);warp=n.new('ShaderNodeTexNoise');warp.inputs['Scale'].default_value=3.8;warp.inputs['Detail'].default_value=4;L.new(co.outputs['Generated'],warp.inputs['Vector']);w=calc('MULTIPLY',calc('SUBTRACT',warp.outputs['Fac'],.5),.28);x=calc('SUBTRACT',calc('SUBTRACT',calc('SUBTRACT',sp.outputs['X'],.5),bend),w);y=calc('SUBTRACT',calc('SUBTRACT',sp.outputs['Y'],.5),calc('MULTIPLY',w,.6));distance=calc('SQRT',calc('ADD',calc('MULTIPLY',x,x),calc('MULTIPLY',y,y)))
radius=calc('MULTIPLY',calc('POWER',calc('MAXIMUM',calc('SUBTRACT',1,z),0),.7),.4);rad=calc('MAXIMUM',calc('SUBTRACT',1,calc('DIVIDE',distance,radius)),0);rad=calc('POWER',rad,.8)
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=5;noise.inputs['Detail'].default_value=5;noise.inputs['Roughness'].default_value=.8;L.new(co.outputs['Generated'],noise.inputs['Vector']);r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.35;r.color_ramp.elements[1].position=.72;L.new(noise.outputs['Fac'],r.inputs[0]);d=calc('MULTIPLY',calc('MULTIPLY',rad,r.outputs['Color']),6);L.new(d,v.inputs['Density']);L.new(calc('MULTIPLY',d,2),v.inputs['Emission Strength'])
c=n.new('ShaderNodeValToRGB');c.color_ramp.elements[0].position=.1;c.color_ramp.elements[0].color=(1,.045,.001,1);c.color_ramp.elements[1].position=.6;c.color_ramp.elements[1].color=(1,.88,.55,1);L.new(rad,c.inputs[0]);L.new(c.outputs[0],v.inputs['Emission Color'])

import bpy,random,math
from mathutils import Vector
s=bpy.data.scenes['CannonImpact3D'];bpy.context.window.scene=s
for f in range(2,6):
 group=[o for o in s.objects if o.type=='MESH' and o.name.startswith('F%02d'%f) and 'flame tongue' in o.name and o.animation_data is not None]
 for j,o in enumerate(group):
  rng=random.Random(202+j);o.scale.x*=1.8;o.scale.y*=1.8;o.scale.z*=rng.uniform(.4,.55);o.location.x+=rng.uniform(-.17,.17);o.location.y+=rng.uniform(-.1,.1);o.location.z+=rng.uniform(.015,.1);o.rotation_euler.x+=rng.uniform(-.2,.2);o.rotation_euler.z+=rng.uniform(-.3,.3)
 for j in range(3):
  template=group[j];o=template.copy();o.data=template.data.copy();o.name='F%02d overlapping blast lobe %02d'%(f,j);s.collection.objects.link(o);o.animation_data_clear();rng=random.Random(370+j);o.location.x=rng.uniform(-.35,.35);o.location.y=-.1;o.location.z=rng.uniform(.04,.2);o.scale.z*=.65;o.scale.x*=.9;o.rotation_euler.x+=rng.uniform(-.3,.3)
  for k in range(12):o.hide_render=(k!=f);o.keyframe_insert(data_path='hide_render',frame=k+1)
m=bpy.data.materials['Ivory turbulent flame'];n=m.node_tree.nodes
# Frame-to-frame turbulent deformation, shared only by flame volumes.
for node in n:
 if node.bl_idname=='ShaderNodeTexNoise':
  node.noise_dimensions='4D'
  for k in range(12):node.inputs['W'].default_value=k*.21;node.inputs['W'].keyframe_insert(data_path='default_value',frame=k+1)
for node in n:
 if node.bl_idname=='ShaderNodeMath' and node.operation=='MULTIPLY':
  if node.inputs[1].default_value==.28:node.inputs[1].default_value=.9
  if node.inputs[1].default_value==6:node.inputs[1].default_value=12
  if node.inputs[1].default_value==2:node.inputs[1].default_value=.25
for node in n:
 if node.bl_idname=='ShaderNodeValToRGB' and node.color_ramp.elements[0].color[0]>.9:
  node.color_ramp.elements[0].color=(1,.025,.0005,1);node.color_ramp.elements[1].position=.88;node.color_ramp.elements[1].color=(1,.7,.28,1);mid=node.color_ramp.elements.new(.5);mid.color=(1,.15,.003,1)

import bpy
for kind in ['flash','ground']:
 m=bpy.data.materials.new('Preserved '+kind+' flame');m.use_nodes=True;n=m.node_tree.nodes;n.clear();L=m.node_tree.links;out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Color'].default_value=(1,.55,.16,1);L.new(v.outputs['Volume'],out.inputs['Volume']);co=n.new('ShaderNodeTexCoord');tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=7;tex.inputs['Detail'].default_value=4;tex.inputs['Roughness'].default_value=.75;L.new(co.outputs['Generated'],tex.inputs['Vector']);r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.37;r.color_ramp.elements[1].position=.72;L.new(tex.outputs['Fac'],r.inputs[0]);mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=4;L.new(r.outputs['Color'],mul.inputs[0]);L.new(mul.outputs[0],v.inputs['Density'])
 if kind=='flash':
  c=n.new('ShaderNodeValToRGB');c.color_ramp.elements[0].position=.25;c.color_ramp.elements[0].color=(.55,.025,.001,1);c.color_ramp.elements[1].position=.8;c.color_ramp.elements[1].color=(1,.78,.3,1);L.new(tex.outputs['Fac'],c.inputs[0]);L.new(c.outputs['Color'],v.inputs['Emission Color']);em=n.new('ShaderNodeMath');em.operation='MULTIPLY';em.inputs[1].default_value=.35;L.new(mul.outputs[0],em.inputs[0]);L.new(em.outputs[0],v.inputs['Emission Strength'])
  targets=[o for o in bpy.data.scenes['CannonImpact3D'].objects if 'flame tongue' in o.name and o.name[:3] in ['F00','F01']]
 else:
  v.inputs['Emission Color'].default_value=(1,.24,.025,1);v.inputs['Emission Strength'].default_value=1.5
  targets=[o for o in bpy.data.scenes['CannonGround3D'].objects if o.type=='MESH' and o.data.materials and o.data.materials[0].name=='Ivory turbulent flame']
 for ob in targets:ob.data.materials.clear();ob.data.materials.append(m)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/cannon_impact.blend')
