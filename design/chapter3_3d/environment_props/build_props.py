"""Editable approved foundry props. Independent background Blender; no runtime exports."""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector
H=Path(__file__).resolve().parent
sys.path.insert(0,str(H.parent/'tiles'))
import build_tiles as T
PI=math.pi

def root(name):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o['approved_reference']='design/chapter3_3d/environment_concepts/integrated-mounts/multiview-v2.png';o['mount_contract']='tile_wall_anchor_v2';o['mount_back_y']=0.0;return o

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

def swept_tube(name,path,ro,ri,p):
 n=96;v=[]
 for rad in [ro,ri]:
  for c,a in path:
   a=Vector(a);w=a.cross(Vector((1,0,0)));v += [Vector(c)+rad*(Vector((1,0,0))*math.cos(i*2*PI/n)+w*math.sin(i*2*PI/n)) for i in range(n)]
 count=len(path);off=count*n;f=[]
 for k in range(count-1):
  for i in range(n):
   j=(i+1)%n;a=k*n+i;b=k*n+j;c=(k+1)*n+j;d=(k+1)*n+i;f.extend([(a,b,c,d),(off+d,off+c,off+b,off+a)])
 for i in range(n):
  j=(i+1)%n;f.extend([(i,off+i,off+j,j),((count-1)*n+i,(count-1)*n+j,off+(count-1)*n+j,off+(count-1)*n+i)])
 return mesh(name,v,f,M['iron'],p,.001,True)

def elbow():
 p=root('elbow_pipe')
 # Rear gasket and upright wall flange have flat attachment planes at Y=0.
 tube('elbow wall cast socket',(0,-.012,-.205),.145,.063,.024,(0,1,0),M['dark'],p)
 tube('elbow upright bronze mounting flange',(0,-.033,-.205),.137,.063,.024,(0,1,0),M['bronze'],p)
 for i in range(8):
  a=(i+.5)*2*PI/8;x=.113*math.sin(a);z=-.205+.113*math.cos(a)
  bolt('elbow wall flange bolt %d'%i,(x,-.048,z),p,axis=(0,-1,0),scale=.48)
 # Wall outlet leads outward, curves smoothly upward and ends in a vertical open mouth.
 path=[((0,y,-.205),(0,-1,0)) for y in [-.023,-.052,-.080]]
 R=.135
 for i in range(1,33):
  t=i*PI/64;path.append(((0,-.080-R*math.sin(t),-.205+R*(1-math.cos(t))),(0,-math.cos(t),math.sin(t))))
 path += [((0,-.215,z),(0,0,1)) for z in [-.025,.025,.075,.113]]
 swept_tube('elbow hollow upward quarter bend',path,.085,.062,p)
 tube('elbow subtle socket seam',(0,-.063,-.205),.089,.062,.012,(0,1,0),M['dark'],p)
 tube('elbow upward iron mouth lip',(0,-.215,.112),.094,.061,.018,(0,0,1),M['edge'],p)
 return p

def conduit():
 p=root('side_conduit');shell=tube('conduit open hollow body',(0,0,0),.108,.078,.81,(1,0,0),M['iron'],p)
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
 # Keep all mount backs flush with Y=0; pipe axis height is baked into wallanchor coords.
 for ob in p.children:ob.location+=Vector((0,-.135,-.25))
 return p

def exhaust():
 p=root('exhaust_vent')
 # Thick integral furnace housing reaches tile base Z=-.5 and top Z=0.
 # A rounded X/Z profile is extruded 0.245 out from a flat wall plane.
 profile=[];w=.218;z0=-.5;z1=0;r=.071
 for cx,cz,start in [(w-r,z1-r,0),(-w+r,z1-r,90),(-w+r,z0+r,180),(w-r,z0+r,270)]:
  for i in range(9):
   a=math.radians(start+i*90/8);profile.append((cx+r*math.cos(a),cz+r*math.sin(a)))
 # Profile loops counterclockwise in X/Z; mesh helper fixes winding.
 n=len(profile);v=[(x,y,z) for y in [0,-.245] for x,z in profile]
 f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 housing=mesh('exhaust integrated full height rounded housing',v,f,M['iron'],p,.014)
 # Actual enclosed furnace chamber and chimney opening, with .03+ solid side walls.
 cut(housing,(0,-.13,-.25),(.33,.15,.43))
 # Round deep bore through the upper body instead of a painted black mouth.
 bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=.083,depth=.16,location=(0,-.143,.005))
 cutter=bpy.context.object;cutter.name='TEMP chimney throat';cutter.data.materials.append(M['iron'])
 bpy.context.view_layer.objects.active=housing
 m=housing.modifiers.new('True chimney through hole','BOOLEAN');m.operation='DIFFERENCE';m.object=cutter;m.solver='EXACT'
 while housing.modifiers.find(m.name)>0:bpy.ops.object.modifier_move_up(modifier=m.name)
 bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cutter,do_unlink=True)
 for i,x in enumerate([-.051,0,.051]):
  cut(housing,(x,-.233,-.264),(.024,.10,.13))
  box('exhaust recessed furnace core %d'%i,(x,-.218,-.264),(.030,.022,.124),M['ember'],p,.003)
 # Inset inspection aperture frame and continuous reinforcement straps.
 for x in [-.084,.084]:box('exhaust inspection frame upright',(x,-.251,-.264),(.009,.008,.168),M['dark'],p,.002)
 for z in [-.348,-.180]:box('exhaust inspection frame sill',(0,-.251,z),(.177,.008,.009),M['dark'],p,.002)
 for x in [-.181,.181]:
  # Straps are solid metal wrapping the rounded shoulder, without floating brackets.
  sideprofile=[(y,z) for y,z in [(-.005,-.491),(-.175,-.491),(-.236,-.442),(-.252,-.392),(-.252,-.10),(-.235,-.05),(-.175,-.007),(-.005,-.007)]]
  vv=[(xx,y,z) for xx in [x-.011,x+.011] for y,z in sideprofile];nn=len(sideprofile)
  ff=[tuple(reversed(range(nn))),tuple(range(nn,2*nn))]+[(i,(i+1)%nn,(i+1)%nn+nn,i+nn) for i in range(nn)]
  mesh('exhaust shoulder reinforcement band',vv,ff,M['dark'],p,.005)
  for z in [-.408,-.10]:bolt('exhaust front housing bolt',(x,-.258,z),p,axis=(0,-1,0),scale=.54)
 tube('exhaust bronze stack seat',(0,-.143,.008),.115,.083,.022,(0,0,1),M['bronze'],p)
 tube('exhaust short deep open chimney',(0,-.143,.123),.102,.083,.222,(0,0,1),M['iron'],p)
 tube('exhaust bronze top lip',(0,-.143,.237),.115,.081,.024,(0,0,1),M['bronze'],p)
 flange_rivets('exhaust lip',(0,-.143,.251),.101,(0,0,1),p,n=10)
 for x in [-.143,.143]:bolt('exhaust top shoulder bolt',(x,-.11,-.003),p,scale=.55)
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
 report={'reference':'../environment_concepts/integrated-mounts/multiview-v2.png','blender':bpy.app.version_string,'real_geometry':{'elbow':'wall flange and upward open 90 degree annular bend','conduit':'96 sided annular body, both ends open, boolean recessed inspection aperture','exhaust':'integrated full height housing from -.5 to 0 and short open stack to .253, 3 real recessed slots'},'props':{}}
 for r in roots:
  pts=[r.matrix_world.inverted() @ o.matrix_world @ Vector(v) for o in r.children if o.type=='MESH' for v in o.bound_box]
  report['props'][r.name]={'objects':len(r.children),'local_min':[min(v[i] for v in pts) for i in range(3)],'local_max':[max(v[i] for v in pts) for i in range(3)],'dimensions':[max(v[i] for v in pts)-min(v[i] for v in pts) for i in range(3)]}
 (H/'geometry-check.json').write_text(json.dumps(report,indent=2))
 # Save library roots at identity; preview uses separate scene instances.
 s=bpy.context.scene;s.name='Editable prop library'
 bpy.ops.wm.save_as_mainfile(filepath=str(H/'foundry-props.blend'));print('PROPS_SOURCE_READY',flush=True)

if __name__=='__main__':main()
