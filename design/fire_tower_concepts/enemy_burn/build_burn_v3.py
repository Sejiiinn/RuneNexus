import bpy,math,random,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path('/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/enemy_burn');s=bpy.context.scene
for name in ['04 Turbulent surface combustion','05 Rolling combustion']:
 c=bpy.data.collections.get(name)
 if c:
  for o in list(c.objects):bpy.data.objects.remove(o,do_unlink=True)
c=bpy.data.collections.new('05 Rolling combustion');s.collection.children.link(c)
mat=bpy.data.materials.new('V3 short lived turbulent fire');mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');l.new(v.outputs['Volume'],out.inputs['Volume'])
def op(k,a,b):
 q=n.new('ShaderNodeMath');q.operation=k
 for i,t in enumerate([a,b]):
  if isinstance(t,(int,float)):q.inputs[i].default_value=t
  else:l.new(t,q.inputs[i])
 return q.outputs[0]
tc=n.new('ShaderNodeTexCoord');off=n.new('ShaderNodeVectorMath');off.operation='SUBTRACT';off.inputs[1].default_value=(.5,.5,.5);l.new(tc.outputs['Generated'],off.inputs[0])
length=n.new('ShaderNodeVectorMath');length.operation='LENGTH';l.new(off.outputs[0],length.inputs[0])
no=n.new('ShaderNodeTexNoise');no.noise_dimensions='4D';no.inputs['Scale'].default_value=3.4;no.inputs['Detail'].default_value=2.5;l.new(tc.outputs['Generated'],no.inputs['Vector'])
for f in [1,97]:no.inputs['W'].default_value=f*.033;no.inputs['W'].keyframe_insert('default_value',frame=f)
field=op('ADD',op('MULTIPLY',op('SUBTRACT',.43,length.outputs['Value']),3),op('MULTIPLY',op('SUBTRACT',no.outputs['Fac'],.5),1.5))
heat=op('MAXIMUM',field,0);l.new(op('MULTIPLY',heat,25),v.inputs['Emission Strength']);l.new(op('MULTIPLY',heat,.1),v.inputs['Density'])
r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.05;r.color_ramp.elements[0].color=(1,.027,.0004,1);r.color_ramp.elements[1].position=.8;r.color_ramp.elements[1].color=(1,.60,.06,1);l.new(heat,r.inputs[0]);l.new(r.outputs[0],v.inputs['Emission Color'])
bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;mesh=o.data;mesh.materials.append(mat);mesh.use_fake_user=True;bpy.data.objects.remove(o,do_unlink=True)
rng=random.Random(683)
for e in bpy.data.collections['01 Original enemies'].objects:
 bv=BVHTree.FromPolygons([v.co for v in e.data.vertices],[tuple(p.vertices) for p in e.data.polygons if p.material_index==0]);h=max(v.co.z for v in e.data.vertices)
 for j in range(52):
  angle=rng.uniform(-math.pi,math.pi)
  # Keep the front core open, emit along flanks, back, and upper shoulders.
  if -2.15<angle<-.98:angle+=1.4
  level=rng.uniform(.3,.8)
  hit,normal,_,_=bv.find_nearest(Vector((.47*math.cos(angle),.44*math.sin(angle),h*level)))
  anchor=hit+normal*.012
  ob=bpy.data.objects.new(e.name+' rising flame parcel %02d'%j,mesh);c.objects.link(ob);ob.parent=e
  period=rng.choice([16,24,32]);phase=rng.randrange(period);size=rng.uniform(.16,.26);drift=rng.uniform(-.10,.10);rise=rng.uniform(.18,.40)
  for f in range(1,98):
   age=((f-1+phase)%period)/period
   # Each flame is born, rolls upward, breaks away, and vanishes completely.
   life=math.sin(math.pi*age)**.65
   ob.location=anchor+Vector((drift*age+.024*math.sin(age*7+j),.018*math.sin(age*5+j),rise*age))
   ob.scale=(size*life*(1-.35*age),size*.85*life*(1-.35*age),size*life*(1.0+.55*age))
   ob.rotation_euler=(age*.4,age*.35,j+age*1.5)
   ob.keyframe_insert('location',frame=f);ob.keyframe_insert('scale',frame=f);ob.keyframe_insert('rotation_euler',frame=f)
 for o in s.objects:
  if o.type=='LIGHT' and o.parent==e:
   o.data.animation_data_clear();o.data.energy=8
s.frame_end=96;s.frame_set(40);s.render.filepath=str(root/'burn-v3-preview.png')
t=bpy.data.texts.get('build_burn_v3.py') or bpy.data.texts.new('build_burn_v3.py');t.clear();t.write((root/'build_burn_v3.py').read_text())
bpy.ops.wm.save_as_mainfile(filepath=str(root/'enemy-burn-v3.blend'))
def rr():
 bpy.ops.render.render(write_still=True)
 return None
bpy.app.timers.register(rr,first_interval=.5)
