"""Editable approved foundry props. Independent background Blender; no runtime exports."""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector
H=Path(__file__).resolve().parent
sys.path.insert(0,str(H.parent/'tiles'))
import build_tiles as T
PI=math.pi

def root(name):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o['approved_reference']='design/chapter3_3d/environment_concepts/foundry-props-multiview.png';return o

def finish(o,mat,p,bev=.002,smooth=False):
 o.parent=p;o.data.materials.append(mat);o.data.materials.append(M['worn_bronze'] if mat==M['bronze'] else M['edge'])
 if smooth:
  for face in o.data.polygons:face.use_smooth=True
 if bev:
  m=o.modifiers.new('Rounded worn casting edges','BEVEL');m.width=bev;m.segments=3;m.material=1
 o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');return o

def mesh(name,v,f,mat,p,bev=.002,smooth=False):
 m=bpy.data.meshes.new(name);m.from_pydata(v,[],f);m.update();bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(m);bm.free();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);return finish(o,mat,p,bev,smooth)

def box(name,c,d,mat,p,bev=.002):
 bpy.ops.mesh.primitive_cube_add(size=1,location=c);o=bpy.context.object;o.name=name;o.dimensions=d;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,mat,p,bev)

def tube(name,c,ro,ri,length,axis,mat,p):
 # Annular closed wall, both bores open; smooth round surfaces, 96 radial segments.
 n=96;v=[];axis=Vector(axis);u=axis.orthogonal().normalized();w=axis.cross(u).normalized();c=Vector(c)
 for z,r in [(-length/2,ro),(-length/2,ri),(length/2,ro),(length/2,ri)]:
  v += [c+axis*z+r*(u*math.cos(i*2*PI/n)+w*math.sin(i*2*PI/n)) for i in range(n)]
 f=[]
 for i in range(n):
  j=(i+1)%n;f.extend([(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),(i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)])
 return mesh(name,v,f,mat,p,.0015,True)

def cyl(name,c,r,d,mat,p,axis=(0,0,1),n=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d,location=c);o=bpy.context.object;o.name=name;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return finish(o,mat,p,.001,n>12)

def bolt(name,c,p,axis=(0,0,1),scale=1):
 c=Vector(c);a=Vector(axis)
 cyl(name+' washer',c,.024*scale,.006*scale,M['dark'],p,axis)
 cyl(name+' hex',c+a*.009*scale,.017*scale,.016*scale,M['bolt'],p,axis,6)
 # actual indented socket
 o=cyl(name+' socket lip',c+a*.018*scale,.007*scale,.001*scale,M['dark'],p,axis,6)

def cut(o,c,d):
 q=box('TEMP aperture cutter',c,d,M['dark'],None,0)
 bpy.context.view_layer.objects.active=o
 b=o.modifiers.new('True recessed aperture','BOOLEAN');b.operation='DIFFERENCE';b.object=q;b.solver='EXACT';bpy.ops.object.modifier_move_up(modifier=b.name)
 # Apply boolean before bevel and normals
 while o.modifiers.find(b.name)>0:bpy.ops.object.modifier_move_up(modifier=b.name)
 bpy.ops.object.modifier_apply(modifier=b.name);bpy.data.objects.remove(q,do_unlink=True)

def flange_rivets(name,c,r,axis,p,n=10):
 a=Vector(axis);u=a.orthogonal().normalized();w=a.cross(u).normalized()
 for i in range(n):
  q=Vector(c)+r*(u*math.cos(i*2*PI/n)+w*math.sin(i*2*PI/n));cyl(name+' rivet %02d'%i,q,.004,.004,M['bolt'],p,axis,n=12)

def elbow():
 p=root('elbow_pipe');box('elbow square footplate',(0,0,.025),(.40,.40,.05),M['dark'],p,.006)
 for i,(x,y) in enumerate([(-.157,-.157),(.157,-.157),(.157,.157),(-.157,.157)]):bolt('elbow foot %d'%i,(x,y,.055),p)
 shell=tube('elbow heated pedestal',(0,0,.106),.123,.092,.112,(0,0,1),M['dark'],p)
 for i,x in enumerate([-.059,0,.059]):
  cut(shell,(x,-.11,.108),(.019,.08,.054));box('elbow recessed heat %d'%i,(x,-.103,.108),(.021,.018,.050),M['ember'],p,.003)
 tube('elbow lower bronze joint',(0,0,.165),.135,.092,.035,(0,0,1),M['bronze'],p)
 flange_rivets('elbow collar',(0,0,.185),.119,(0,0,1),p)
 # swept annular tube: vertical lead, quarter circle, horizontal lead.
 path=[((0,0,z),(0,0,1)) for z in [.175,.195,.22]]
 R=.137
 for i in range(1,33):
  t=i*PI/64;path.append(((0,-R*(1-math.cos(t)),.22+R*math.sin(t)),(0,-math.sin(t),math.cos(t))))
 path += [((0,y,.357),(0,-1,0)) for y in [-.18,-.23,-.264]]
 n=96;v=[]
 for rad in [.114,.083]:
  for c,a in path:
   a=Vector(a);w=a.cross(Vector((1,0,0)));v += [Vector(c)+rad*(Vector((1,0,0))*math.cos(i*2*PI/n)+w*math.sin(i*2*PI/n)) for i in range(n)]
 count=len(path);off=count*n;f=[]
 for k in range(count-1):
  for i in range(n):
   j=(i+1)%n;a=k*n+i;b=k*n+j;c=(k+1)*n+j;d=(k+1)*n+i;f.extend([(a,b,c,d),(off+d,off+c,off+b,off+a)])
 for i in range(n):
  j=(i+1)%n;f.extend([(i,off+i,off+j,j),((count-1)*n+i,(count-1)*n+j,off+(count-1)*n+j,off+(count-1)*n+i)])
 mesh('elbow continuous hollow cast bend',v,f,M['iron'],p,.001,True)
 for y in [-.153,-.18]:tube('elbow twin outlet joint band',(0,y,.357),.123,.083,.012,(0,1,0),M['dark'],p)
 tube('elbow bronze mouth lip',(0,-.269,.357),.130,.081,.026,(0,1,0),M['bronze'],p)
 flange_rivets('elbow mouth',(0,-.285,.357),.111,(0,-1,0),p)
 return p

def conduit():
 p=root('side_conduit');p['mount_back_y']=.135;shell=tube('conduit open hollow body',(0,0,0),.108,.078,.81,(1,0,0),M['iron'],p)
 cut(shell,(0,-.105,0),(.139,.07,.027));box('conduit recessed amber inspection core',(0,-.097,0),(.134,.012,.029),M['ember'],p,.003)
 # real raised rectangular slot border
 for z in [-.019,.019]:box('conduit inspection frame rail',(0,-.108,z),(.151,.008,.008),M['bronze'],p,.002)
 for x in [-.076,.076]:box('conduit inspection frame end',(x,-.108,0),(.008,.008,.037),M['dark'],p,.002)
 for x in [-.414,.414]:
  tube('conduit bronze end flange',(x,0,0),.122,.077,.030,(1,0,0),M['bronze'],p)
  flange_rivets('conduit flange',(x+(.017 if x>0 else -.017),0,0),.103,(1 if x>0 else -1,0,0),p)
 for i,x in enumerate([-.235,.235]):
  tube('conduit saddle clamp %d'%i,(x,0,0),.121,.108,.055,(1,0,0),M['dark'],p)
  for z in [-.142,.142]:
   box('conduit wall mount ear',(x,.054,z),(.087,.162,.076),M['dark'],p,.004)
   bolt('conduit mount bolt',(x,-.027,z),p,axis=(0,-1,0),scale=.75)
  for xx in [x-.026,x+.026]:tube('conduit clamp edge',(xx,0,0),.123,.113,.006,(1,0,0),M['edge'],p)
 return p

def exhaust():
 p=root('exhaust_vent')
 # trapezoidal thick-walled furnace base, hollow cavity and open top.
 v=[]
 for z,w,d in [(.025,.185,.175),(.236,.155,.143)]:v += [(x*w,y*d,z) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
 f=[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
 body=mesh('exhaust trapezoid furnace housing',v,f,M['iron'],p,.005)
 # cavity carved from block, retaining thick base and structural walls
 cut(body,(0,0,.225),(.258,.237,.30))
 for i,x in enumerate([-.052,0,.052]):
  cut(body,(x,-.18,.131),(.023,.11,.103));box('exhaust deep orange vent %d'%i,(x,-.133,.131),(.030,.030,.10),M['ember'],p,.004)
 for x in [-.083,.083]:
  o=box('exhaust inspection side frame',(x,-.161,.13),(.008,.007,.137),M['dark'],p);o.rotation_euler.x=-.151
 for z in [.061,.20]:box('exhaust inspection sill',(0,-.175+(z-.025)*(.032/.211)-.003,z),(.175,.008,.009),M['dark'],p)
 for i,(x,y) in enumerate([(-.176,-.16),(.176,-.16),(.176,.16),(-.176,.16)]):
  box('exhaust mounting foot %d'%i,(x,y,.033),(.074,.074,.066),M['dark'],p,.004)
  bolt('exhaust floor bolt %d'%i,(x,y,.074),p,scale=.8)
 tube('exhaust lower stack collar',(0,0,.246),.138,.090,.023,(0,0,1),M['bronze'],p)
 tube('exhaust deep open stack',(0,0,.377),.120,.091,.263,(0,0,1),M['iron'],p)
 tube('exhaust bronze open lip',(0,0,.518),.139,.090,.035,(0,0,1),M['bronze'],p)
 flange_rivets('exhaust lip',(0,0,.537),.119,(0,0,1),p)
 for i,(x,y) in enumerate([(-.13,-.12),(.13,-.12),(.13,.12),(-.13,.12)]):bolt('exhaust stack seat %d'%i,(x,y,.243),p,scale=.62)
 return p

def main():
 global M
 assert bpy.app.background
 bpy.ops.wm.read_factory_settings(use_empty=True)
 with bpy.data.libraries.load(str(H.parent/'tiles/chapter3-thick-tiles.blend'),link=False) as (src,dst):dst.materials=src.materials
 mats=bpy.data.materials
 M={'iron':mats['Construction plate | blue graphite'],'dark':mats['Flanges | dark forged iron'],'edge':mats['Exposed worn iron edges'],'bolt':mats['Forged steel fasteners'],'bronze':mats['Mounting ring | aged bronze'],'worn_bronze':mats['Worn bronze bevel']}
 m=bpy.data.materials.new('Props | confined amber furnace core');m.use_nodes=True;q=m.node_tree.nodes.get('Principled BSDF');q.inputs['Base Color'].default_value=(.13,.024,.003,1);q.inputs['Emission Color'].default_value=(1,.19,.013,1);q.inputs['Emission Strength'].default_value=2.2;M['ember']=m
 T.M=M
 roots=[elbow(),conduit(),exhaust()]
 bpy.context.view_layer.update()
 report={'reference':'../environment_concepts/foundry-props-multiview.png','blender':bpy.app.version_string,'real_geometry':{'elbow':'96 radial x 38 path stations annular sweep, open mouth into curved bore','conduit':'96 sided annular body, both ends open, boolean recessed inspection aperture','exhaust':'open hollow furnace and continuous .182 bore stack, 3 boolean front slots'},'props':{}}
 for r in roots:
  pts=[r.matrix_world.inverted() @ o.matrix_world @ Vector(v) for o in r.children if o.type=='MESH' for v in o.bound_box]
  report['props'][r.name]={'objects':len(r.children),'local_min':[min(v[i] for v in pts) for i in range(3)],'local_max':[max(v[i] for v in pts) for i in range(3)],'dimensions':[max(v[i] for v in pts)-min(v[i] for v in pts) for i in range(3)]}
 (H/'geometry-check.json').write_text(json.dumps(report,indent=2))
 # Save library roots at identity; preview uses separate scene instances.
 s=bpy.context.scene;s.name='Editable prop library'
 bpy.ops.wm.save_as_mainfile(filepath=str(H/'foundry-props.blend'));print('PROPS_SOURCE_READY',flush=True)
 # Only rendered preview offsets the roots; the saved source stays identity.
 s.render.engine='CYCLES';s.cycles.samples=64;s.cycles.use_denoising=True
 s.world=bpy.data.worlds.new('Foundry neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.18,.21,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.5
 for name,c,power,size in [('Softbox',(-3,-4,5),500,4),('Fill',(4,-1,3),230,3),('Rim',(1,4,4),600,3)]:
  d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=c;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 g=bpy.data.materials.new('Studio charcoal');g.diffuse_color=(.018,.024,.028,1);g.use_nodes=True;g.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.018,.024,.028,1);g.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.82
 box('Studio floor',(0,0,-.026),(200,200,.05),g,None,0)
 roots[0].location=(-.84,0,0);roots[1].location=(0,0,.18);roots[2].location=(.85,0,0)
 camd=bpy.data.cameras.new('Preview');cam=bpy.data.objects.new('Preview',camd);s.collection.objects.link(cam);cam.location=(1.9,-5,3.9);cam.rotation_euler=(Vector((0,0,.22))-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=2.75;s.camera=cam
 s.render.resolution_x=1900;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.render.filepath=str(H/'props-preview.png');bpy.ops.render.render(write_still=True)
 print('PROPS_RENDER_READY',flush=True)
if __name__=='__main__':main()
