"""Directional muzzle jets and noisy volume smoke, transparent animation frames."""
import bpy,math,random
from pathlib import Path
from mathutils import Vector
W=Path('/Users/sejin/Documents/Codex/RuneNexus/design/stage1_3d/weapon_effects')
for scene_name in ['WeaponMuzzleFrames','WeaponSmokeFrames']:
 s=bpy.data.scenes.get(scene_name) or bpy.data.scenes.new(scene_name);bpy.context.window.scene=s
 for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
 s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.render.resolution_x=256;s.render.resolution_y=256;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8';s.render.fps=24;s.frame_start=0;s.frame_end=7;s.view_settings.view_transform='Standard';s.view_settings.look='None'
 world=bpy.data.worlds.new(scene_name+'_world');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.55,.55,1);world.node_tree.nodes['Background'].inputs[1].default_value=.3;s.world=world
 d=bpy.data.cameras.new('EffectCamera');cam=bpy.data.objects.new('EffectCamera',d);s.collection.objects.link(cam);cam.location=(0,-7,0);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=4;s.camera=cam
 if scene_name=='WeaponMuzzleFrames':
  s.render.filepath=str(W/'frames/muzzle_')
  def emissive(name,c,strength):
   m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission');em.inputs[0].default_value=(*c,1);em.inputs[1].default_value=strength;tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');m.node_tree.links.new(tr.outputs[0],mix.inputs[1]);m.node_tree.links.new(em.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],out.inputs[0]);return m,mix.inputs[0]
  ivory,ia=emissive('hot ivory',(.98,.86,.54),3.4);amber,aa=emissive('thin amber fringe',(1,.27,.025),1.5)
  root=bpy.data.objects.new('muzzle_origin',None);s.collection.objects.link(root);root.location=(-.88,0,0)
  def jet(name,direction,length,width,mat,seed):
   rnd=random.Random(seed);direction=Vector(direction).normalized();a=direction.cross(Vector((0,1,0))).normalized();b=direction.cross(a);vs=[]
   for j in range(6):
    t=j/5;center=direction*(t*length)+a*math.sin(t*6+seed)*width*.45
    radius=width*([.22,1,.76,.48,.22,0][j])
    for i in range(6):
     theta=i*math.tau/6;vs.append(center+a*math.cos(theta)*radius*(.7+rnd.random()*.45)+b*math.sin(theta)*radius*.65)
   fs=[]
   for j in range(5):
    for i in range(6):p=j*6+i;q=j*6+(i+1)%6;fs.append((p,q,q+6,p+6))
   d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.parent=root;o.data.materials.append(mat)
  directions=[((1,0,0),2.22,.16),((1,.10,.30),1.70,.09),((1,-.1,-.32),1.55,.08),((.55,.05,.80),.84,.062),((.57,-.03,-.78),.86,.057),((-.28,.1,.7),.35,.048),((-.28,.05,-.7),.33,.044)]
  for i,(v,l,w) in enumerate(directions):
   jet('amber_tongue_'+str(i),v,l,w*1.5,amber,i+2);jet('ivory_jet_'+str(i),v,l*.93,w*.69,ivory,i+2)
  for f,(scale,alpha) in enumerate(zip([.58,1,.92,.76,.55,.38,.22,.10],[1,1,.92,.80,.57,.34,.16,.015])):
   root.scale=(scale,scale,scale);root.keyframe_insert('scale',frame=f);ia.default_value=alpha;ia.keyframe_insert('default_value',frame=f);aa.default_value=alpha*.70;aa.keyframe_insert('default_value',frame=f)
 else:
  s.render.filepath=str(W/'frames/smoke_')
  m=bpy.data.materials.new('rough grey brown vapor');m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Color'].default_value=(.38,.34,.28,1);v.inputs['Anisotropy'].default_value=.05
  coord=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7;noise.inputs['Detail'].default_value=4;noise.inputs['Roughness'].default_value=.75
  ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.35;ramp.color_ramp.elements[1].position=.68
  mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=2
  links=m.node_tree.links;links.new(coord.outputs['Generated'],noise.inputs[0]);links.new(noise.outputs['Fac'],ramp.inputs[0]);links.new(ramp.outputs[0],mul.inputs[0]);links.new(mul.outputs[0],v.inputs['Density']);links.new(v.outputs[0],out.inputs['Volume'])
  rnd=random.Random(77);puffs=[]
  for i in range(11):
   angle=i*2.399;rad=.18+(i/11)*.72;loc=Vector((math.cos(angle)*rad,rnd.uniform(-.25,.25),math.sin(angle)*rad*.65));base=Vector((rnd.uniform(.30,.49),rnd.uniform(.25,.38),rnd.uniform(.28,.45)))
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1);o=bpy.context.object;o.name='turbulent_puff_'+str(i);o.data.materials.append(m);puffs.append((o,loc,base))
  for f in range(8):
   t=f/7;spread=.27+.88*t
   for o,loc,base in puffs:
    o.location=loc*spread+Vector((t*.18,0,t*.17));o.scale=base*spread;o.keyframe_insert('location',frame=f);o.keyframe_insert('scale',frame=f)
   mul.inputs[1].default_value=[3.2,3,2.5,1.8,1.2,.72,.30,.04][f];mul.inputs[1].keyframe_insert('default_value',frame=f)
  for name,loc,power,size in [('key',(-2,-3,4),700,5),('fill',(3,-2,-1),350,4)]:
   d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=size;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(W/'weapon-effects.blend'))
print('VFX_SCENES_READY')
