import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/enemy_burn')
s=bpy.context.scene
for name in ['02 Shared attached flames','03 Shared drifting embers']:
 c=bpy.data.collections.get(name)
 if c:
  for ob in list(c.objects): bpy.data.objects.remove(ob,do_unlink=True)
c=bpy.data.collections.new('04 Turbulent surface combustion');s.collection.children.link(c)
mat=bpy.data.materials.new('Burn V2 | turbulent fire volume');mat.use_nodes=True
n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
out=n.new('ShaderNodeOutputMaterial');vol=n.new('ShaderNodeVolumePrincipled');l.new(vol.outputs['Volume'],out.inputs['Volume'])
def op(kind,a,b=None):
 t=n.new('ShaderNodeMath');t.operation=kind
 for i,v in enumerate([a,b]):
  if v is None:continue
  if isinstance(v,(float,int)):t.inputs[i].default_value=v
  else:l.new(v,t.inputs[i])
 return t.outputs[0]
def ramp(x,stops):
 r=n.new('ShaderNodeValToRGB');l.new(x,r.inputs[0]);cr=r.color_ramp
 for i,(p,color) in enumerate(stops):
  e=cr.elements[i] if i<2 else cr.elements.new(p);e.position=p;e.color=color
 return r.outputs['Color']
tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Generated'],sep.inputs[0]);x,y,z=sep.outputs
mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';l.new(tc.outputs['Generated'],mapping.inputs[0]);mapping.inputs[1].default_value=(1.2,1.2,.72)
flow=n.new('ShaderNodeVectorMath');flow.operation='ADD';l.new(mapping.outputs[0],flow.inputs[0])
for f in [1,120]:
 flow.inputs[1].default_value=(0,0,-(f-1)*.018);flow.inputs[1].keyframe_insert('default_value',frame=f)
noise=n.new('ShaderNodeTexNoise');noise.noise_dimensions='4D';noise.inputs['Scale'].default_value=6.8;noise.inputs['Detail'].default_value=3.5;noise.inputs['Roughness'].default_value=.72;l.new(flow.outputs[0],noise.inputs['Vector'])
for f in [1,120]:noise.inputs['W'].default_value=f*.025;noise.inputs['W'].keyframe_insert('default_value',frame=f)
fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=19;fine.inputs['Detail'].default_value=2;l.new(flow.outputs[0],fine.inputs['Vector'])
# Elliptical envelope tapered and torn by a moving 3D turbulence field.
dx=op('SUBTRACT',x,.5);dy=op('SUBTRACT',y,.5)
r=op('SQRT',op('ADD',op('MULTIPLY',dx,dx),op('MULTIPLY',dy,dy)))
radius=op('SUBTRACT',op('SUBTRACT',.53,op('MULTIPLY',z,.30)),r)
field=op('ADD',op('MULTIPLY',radius,2.7),op('MULTIPLY',op('SUBTRACT',noise.outputs['Fac'],.5),1.65))
field=op('ADD',field,op('MULTIPLY',op('SUBTRACT',fine.outputs['Fac'],.5),.34))
field=op('MULTIPLY',field,op('MULTIPLY',op('MINIMUM',op('MULTIPLY',z,12),1),op('MINIMUM',op('MULTIPLY',op('SUBTRACT',1,z),5),1)))
heat=ramp(field,[(.08,(0,0,0,1)),(.65,(1,1,1,1))])
power=op('MULTIPLY',heat,30)
l.new(power,vol.inputs['Emission Strength']);l.new(op('MULTIPLY',heat,.14),vol.inputs['Density'])
color=ramp(field,[(.05,(.8,.018,.0005,1)),(.25,(1,.10,.001,1)),(.48,(1,.43,.018,1)),(.82,(1,.80,.24,1))]);l.new(color,vol.inputs['Emission Color'])
vol.inputs['Color'].default_value=(.13,.055,.015,1)
# One shared closed volume carrier, no fixed flame-shaped silhouettes.
bpy.ops.mesh.primitive_cube_add(size=1);template=bpy.context.object;mesh=template.data;mesh.materials.append(mat);mesh.use_fake_user=True;bpy.data.objects.remove(template,do_unlink=True)
rng=random.Random(34)
for enemy in bpy.data.collections['01 Original enemies'].objects:
 height=max(v.co.z for v in enemy.data.vertices);kind=enemy.name.split(' ')[0]
 # Side/back burn patches start halfway down the armour, overlap as they rise.
 for j,(angle,hlev) in enumerate([(-.25,.35),(.30,.47),(.72,.52),(1.2,.47),(1.75,.38),(2.35,.53),(2.9,.43),(3.3,.60)]):
  # front is -Y, keep core region open
  x=.40*math.cos(angle);y=.33*math.sin(angle)
  ob=bpy.data.objects.new(kind+' turbulent patch '+str(j),mesh);c.objects.link(ob);ob.parent=enemy
  ob.location=(x,y,height*hlev+.19)
  base=Vector((.32+rng.random()*.07,.28+rng.random()*.05,.48+rng.random()*.15))
  ob.rotation_euler[2]=angle+.3
  for f in range(1,122,3):
   env=min(1,max(0,(f-10-j*.65)/15))*min(1,max(0,(120-f)/17))
   wave=.85+.17*math.sin(f*.22+j*2.4)+.09*math.sin(f*.41+j)
   ob.scale=(base.x*max(.001,env),base.y*max(.001,env),base.z*max(.001,env)*wave)
   ob.keyframe_insert('scale',frame=f)
 # orange illumination binds the fire to the armour
 for ob in s.objects:
  if ob.type=='LIGHT' and ob.parent==enemy:
   for f in range(1,122,3):
    env=min(1,max(0,(f-10)/15))*min(1,max(0,(120-f)/17))
    ob.data.energy=12*env*(1+.18*math.sin(f*.35));ob.data.keyframe_insert('energy',frame=f)
s.eevee.volumetric_tile_size='2';s.eevee.volumetric_samples=64
s.frame_set(48);s.render.filepath=str(ROOT/'burn-v2-preview.png')
txt=bpy.data.texts.get('revise_burn_volume.py') or bpy.data.texts.new('revise_burn_volume.py');txt.clear();txt.write((ROOT/'revise_burn_volume.py').read_text())
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'enemy-burn-v2.blend'))
def render():
 bpy.ops.render.render(write_still=True)
 return None
bpy.app.timers.register(render,first_interval=.5)
