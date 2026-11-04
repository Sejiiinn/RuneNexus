"""Shared enemy-attached burn study. Blender only; no runtime writes/export."""
import bpy,math,json,random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path('/Users/sejin/Documents/Codex/RuneNexus')
OUT=ROOT/'design/fire_tower_concepts/enemy_burn'
END=120

def create():
 s=bpy.data.scenes.new('Enemy Burn — Shared Attachment Study');bpy.context.window.scene=s
 def coll(name):
  c=bpy.data.collections.new(name);s.collection.children.link(c);return c
 enemies=coll('01 Original enemies');flames=coll('02 Shared attached flames');embers=coll('03 Shared drifting embers');studio=coll('90 Studio')
 ns={};exec(compile((ROOT/'design/fire_tower_concepts/runic_3d/finish_flames.py').read_text(),'finish_flames.py','exec'),ns)
 orange=ns['_flame_material']('Burn study | shared orange');gold=ns['_flame_material']('Burn study | shared golden core',True)
 for mat in [orange,gold]:
  for n in mat.node_tree.nodes:
   if n.type=='TEX_NOISE':
    n.noise_dimensions='4D'
    n.inputs['W'].default_value=0;n.inputs['W'].keyframe_insert('default_value',frame=1)
    n.inputs['W'].default_value=4;n.inputs['W'].keyframe_insert('default_value',frame=END)
 templates=[]
 for i,mat in enumerate([orange,gold]):
  o=ns['_tongue'](flames,None,'Burn shared tongue '+str(i),(0,0,0),(0,0,1),1,.40,.55,i*.7,mat)
  me=o.data
  o.shape_key_add(name='Rest')
  for j in range(2):
   sk=o.shape_key_add(name='Upward flow '+str(j))
   for v,dst in zip(me.vertices,sk.data):
    t=v.co.z;dst.co.x+=.055*t*math.sin(t*8+j*2.8+i);dst.co.y+=.03*t*math.cos(t*9+j*2+i)
   for f in range(1,END+2,2):
    sk.value=.5+.5*math.sin(f*.24+j*math.pi+i);sk.keyframe_insert('value',frame=f)
  templates.append(me);me.use_fake_user=True;bpy.data.objects.remove(o,do_unlink=True)
 ember_mat=bpy.data.materials.new('Burn study | shared ember');ember_mat.use_nodes=True
 nodes=ember_mat.node_tree.nodes;nodes.clear();e=nodes.new('ShaderNodeEmission');e.inputs['Color'].default_value=(1,.13,.002,1);e.inputs['Strength'].default_value=3
 output=nodes.new('ShaderNodeOutputMaterial');ember_mat.node_tree.links.new(e.outputs[0],output.inputs[0])
 em=ns['_tongue'](embers,None,'Burn ember template',(0,0,0),(0,0,1),1,.20,.4,.1,ember_mat)
 ember_mesh=em.data;ember_mesh.use_fake_user=True;bpy.data.objects.remove(em,do_unlink=True)
 records={};rng=random.Random(914)
 def envelope(f):return min(1,max(0,(f-12)/12))*min(1,max(0,(END-f)/15))
 for idx,(kind,x,y) in enumerate([('normal',-1.22,.20),('tank',0,-.26),('armored',1.22,.20)]):
  with bpy.data.libraries.load(str(ROOT/'design/stage1_3d/enemies/chapter-one-enemies-refined.blend'),link=False) as (src,dst):dst.objects=[kind]
  enemy=dst.objects[0];enemies.objects.link(enemy);enemy.parent=None;enemy.location=(x,y,0);enemy.rotation_euler=(0,0,0);enemy.scale=(1,1,1);enemy.name=kind+' — original unchanged'
  parent=bpy.data.objects.new(kind+' burn attachment rig',None);flames.objects.link(parent);parent.parent=enemy
  mesh=enemy.data;bv=BVHTree.FromPolygons([v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons if p.material_index==0])
  height=max(v.co.z for v in mesh.vertices)
  anchors=[]
  for px,py in [(-.26,-.06),(.26,-.02),(-.23,.20),(.23,.22),(0,.25)]:
   hit,normal,face,dist=bv.ray_cast(Vector((px,py,height+1)),Vector((0,0,-1)),3)
   if hit is not None:anchors.append(hit+normal*.004)
  for sign in [-1,1]:
   hit,normal,face,dist=bv.ray_cast(Vector((sign*2,.08,height*.52)),Vector((-sign,0,0)),3)
   if hit is not None:anchors.append(hit+normal*.006)
  records[kind]=[list(v) for v in anchors]
  for j,anchor in enumerate(anchors):
   h=(.21+.07*rng.random())*(height/.95)
   for layer in range(2):
    o=bpy.data.objects.new(kind+' attached flame %02d %d'%(j,layer),templates[layer]);flames.objects.link(o);o.parent=parent;o.location=anchor+Vector((.006*layer,-.009*layer,.003*layer))
    o.rotation_euler=(0,0,j*1.91)
    for f in range(1,END+2,2):
     env=envelope(f);wave=1+.12*math.sin(f*.29+j+idx)
     o.scale=Vector((h,h,h*wave))*(.76 if layer else 1)*max(.001,env)
     o.keyframe_insert('scale',frame=f)
   for j2 in range(2):
    ember=bpy.data.objects.new(kind+' drifting ember %02d %d'%(j,j2),ember_mesh);embers.objects.link(ember);ember.parent=parent
    for f in range(1,END+1):
     age=((f+j*7+j2*13)%31)/31
     ember.location=anchor+Vector((.07*math.sin(age*3+j),.045*math.cos(age*4+j2),age*(h+.12)))
     ember.rotation_euler=(.2*math.sin(age*5+j),.18*math.cos(age*4+j),j)
     ember.keyframe_insert('location',frame=f);ember.keyframe_insert('rotation_euler',frame=f)
     k=max(.0001,envelope(f)*math.sin(age*math.pi))*.016
     ember.scale=(k,k,k);ember.keyframe_insert('scale',frame=f)
  light=bpy.data.lights.new(kind+' subtle burn bounce','POINT');light.color=(1,.20,.015);light.shadow_soft_size=.2
  o=bpy.data.objects.new(light.name,light);studio.objects.link(o);o.parent=enemy;o.location=(0,-.12,height*.8)
  for f in range(1,END+2,2):
   light.energy=3.0*envelope(f)*(1+.1*math.sin(f*.33));light.keyframe_insert('energy',frame=f)
 (OUT/'attachment-study.json').write_text(json.dumps({'game_export':False,'source_unchanged':True,'shared_flame_meshes':2,'shared_ember_meshes':1,'anchors_local':records},indent=2))
 bpy.ops.mesh.primitive_plane_add(size=200)
 ground=bpy.context.object
 for c in list(ground.users_collection):c.objects.unlink(ground)
 studio.objects.link(ground);ground.name='Studio ground'
 mat=bpy.data.materials.new('Studio | charcoal green');mat.diffuse_color=(.024,.043,.038,1);mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.024,.043,.038,1);bs.inputs['Roughness'].default_value=.85;ground.data.materials.append(mat)
 for name,location,power,size,color in [('Key',(-3,-4,6),650,5,(1,.91,.80)),('Fill',(4,-1,4),450,4,(.74,.84,1)),('Rim',(0,4,5),550,3,(1,.65,.34))]:
  light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size;light.color=color
  o=bpy.data.objects.new(name,light);studio.objects.link(o);o.location=location;o.rotation_euler=(Vector((0,0,.4))-o.location).to_track_quat('-Z','Y').to_euler()
 camera=bpy.data.cameras.new('Burn study camera');cam=bpy.data.objects.new(camera.name,camera);studio.objects.link(cam);s.camera=cam
 cam.location=(2.8,-6.5,4.0);cam.rotation_euler=(Vector((0,0,.50))-cam.location).to_track_quat('-Z','Y').to_euler();camera.type='ORTHO';camera.ortho_scale=4.05
 s.world=bpy.data.worlds.new('Burn study world');s.world.use_nodes=True;s.world.node_tree.nodes.get('Background').inputs[0].default_value=(.06,.09,.075,1);s.world.node_tree.nodes.get('Background').inputs[1].default_value=.4
 s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=32;s.eevee.volumetric_samples=48;s.eevee.volumetric_tile_size='4'
 s.render.resolution_x=1080;s.render.resolution_y=810;s.render.resolution_percentage=100
 s.render.image_settings.file_format='PNG';s.render.fps=24;s.frame_start=1;s.frame_end=END
 s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=-.6
 for name,f in [('Before ignition',1),('Ignite attached patches',13),('Shared burning effect',30),('Extinguish',105)]:s.timeline_markers.new(name,frame=f)
 s.frame_set(48);s.render.filepath=str(OUT/'burn-preview.png')
 t=bpy.data.texts.new('build_burn_study.py');t.write(Path(__file__).read_text());t.use_fake_user=True
 return s
