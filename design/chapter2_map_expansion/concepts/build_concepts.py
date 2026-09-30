"""Five editable Chapter 2 proposal scenes. No game exports.
Run using independent Blender background; --regenerate explicitly replaces source.
"""
import bpy,bmesh,ast,json,math,random,sys,argparse,hashlib,importlib.util
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
LOG=ROOT/'build/chapter2-expansion-design'
LOG.mkdir(parents=True,exist_ok=True)
TARGET=HERE/'chapter2-five-map-concepts.blend'
p=argparse.ArgumentParser();p.add_argument('--regenerate',action='store_true');p.add_argument('--render-only',action='store_true');p.add_argument('--stage');args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
if not bpy.app.background:raise RuntimeError('Use independent background Blender')
if TARGET.exists() and not (args.regenerate or args.render_only):raise RuntimeError('Editable source exists; use --render-only or --regenerate')
MAPS=json.loads((HERE.parent/'maps.json').read_text())['maps']
if args.stage:MAPS=[s for s in MAPS if s['chapterStage']==args.stage]
if args.render_only:
 bpy.ops.wm.open_mainfile(filepath=str(TARGET))
 for s in MAPS:
  bpy.context.window.scene=bpy.data.scenes[s['chapterStage']+' '+s['name']];bpy.ops.render.render(write_still=True)
 sys.exit(0)
bpy.ops.wm.read_factory_settings(use_empty=True)
SOURCES={
 'tiles':ROOT/'design/chapter2_3d/tiles/chapter2-tiles.blend',
 'props':ROOT/'design/chapter2_3d/stage6/props/stage6-props.blend',
 'landmarks':ROOT/'design/stage1_3d/portal_core_concepts/production/rune-landmarks.blend',
 'portals':ROOT/'design/teleport_device_concepts/2026-09-30/production/teleport-four-variants.blend'}
def append(path):
 with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
 return {o.name:o for o in dst.objects}
tiles=append(SOURCES['tiles']);props=append(SOURCES['props']);land=append(SOURCES['landmarks'])
preview_path=ROOT/'design/chapter1_map_expansion/concepts/portal_preview.py'
preview_spec=importlib.util.spec_from_file_location('portal_preview',preview_path)
preview=importlib.util.module_from_spec(preview_spec);preview_spec.loader.exec_module(preview)
preview.apply(land['portal_vortex'])
with bpy.data.libraries.load(str(SOURCES['portals']),link=False) as (src,dst):
 dst.collections=['BLUE IN','BLUE OUT','ORANGE IN','ORANGE OUT'];dst.node_groups=['Portal restrained optical glow']
portals={n:bpy.data.objects[n] for n in ('BLUE_IN','BLUE_OUT','ORANGE_IN','ORANGE_OUT')}
font=bpy.data.fonts.load('/System/Library/Fonts/AppleSDGothicNeo.ttc')
source=ROOT/'design/chapter2_3d/stage6/terrain/build_geology.py'
helpers=[n for n in ast.parse(source.read_text()).body if isinstance(n,ast.FunctionDef) and n.name in ('uv_planar','rock','rectangle','clip','split_stone')]
exec(compile(ast.Module(body=helpers,type_ignores=[]),str(source),'exec'))
side=bpy.data.materials['chapter2_side'];topmat=bpy.data.materials['chapter2_build']
def clone(scene,src,parent=None,exclude=None):
 if exclude and exclude(src):return None
 ob=src.copy();scene.collection.objects.link(ob);ob.parent=parent;ob.hide_render=False;ob.hide_viewport=False
 for child in src.children:clone(scene,child,ob,exclude)
 return ob

def label(scene,cam,text,y,size):
 d=bpy.data.curves.new(text,'FONT');d.body=text;d.font=font;d.size=size;d.align_x='CENTER'
 o=bpy.data.objects.new(text,d);scene.collection.objects.link(o);o.rotation_euler=cam.rotation_euler;o.location=cam.location+cam.rotation_euler.to_matrix()@Vector((0,y,-10))
 m=bpy.data.materials.get('Caption')
 if not m:
  m=bpy.data.materials.new('Caption');m.use_nodes=True;n=m.node_tree.nodes;n.clear();e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(.66,.78,.96,1);out=n.new('ShaderNodeOutputMaterial');m.node_tree.links.new(e.outputs[0],out.inputs[0])
 d.materials.append(m)
def setup(scene):
 bpy.context.window.scene=scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.render.resolution_x=1200;scene.render.resolution_y=1440;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
 scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
 world=bpy.data.worlds.new('Neutral space lighting');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.15,.22,1);world.node_tree.nodes['Background'].inputs[1].default_value=.48;scene.world=world
 for loc,power,size in [((-5,-3,10),2000,6),((4,4,8),850,7)]:
  d=bpy.data.lights.new('Soft area','AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 d=bpy.data.cameras.new('Shared map overview');o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=(0,-math.sin(math.radians(25))*25,math.cos(math.radians(25))*25);o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=16.;scene.camera=o
 bpy.ops.mesh.primitive_plane_add(size=2);plane=bpy.context.object;plane.name='Chapter 2 tinted space backdrop';plane.rotation_euler=o.rotation_euler;plane.location=o.location+o.rotation_euler.to_matrix()@Vector((0,0,-38));plane.scale=(9,10,1)
 m=bpy.data.materials.get('Chapter 2 nebula')
 if not m:
  m=bpy.data.materials.new('Chapter 2 nebula');m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/images/backgrounds/combat_space_nebula.png'));mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.7;mix.inputs[2].default_value=(.56,.42,.83,1);m.node_tree.links.new(t.outputs['Color'],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],e.inputs[0]);m.node_tree.links.new(e.outputs[0],out.inputs[0])
 plane.data.materials.append(m);scene.frame_set(17);scene.render.fps=24;scene.frame_end=96
 scene.compositing_node_group=bpy.data.node_groups['Portal restrained optical glow'].copy()
 for n in scene.compositing_node_group.nodes:
  if n.bl_idname=='CompositorNodeRLayers':n.scene=scene
 return o

def open_portal_host(root,scene):
 # Subtract only the host's surface within the approved metal rim. Retain Chapter 2 masonry.
 bpy.ops.mesh.primitive_cube_add(size=1);cutter=bpy.context.object;cutter.name='temporary portal opening';cutter.parent=root;cutter.location=(0,0,.55);cutter.scale=(.882,.882,1.34)
 bpy.context.view_layer.update()
 for ob in list(root.children_recursive):
  if ob==cutter or ob.type!='MESH':continue
  zs=[(root.matrix_world.inverted()@ob.matrix_world@Vector(c)).z for c in ob.bound_box]
  if max(zs)<-.115:continue
  ob.data=ob.data.copy();mod=ob.modifiers.new('Real recessed portal opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.context.view_layer.objects.active=ob
  bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.data.objects.remove(cutter,do_unlink=True)

def continuous_substrate(stage,occupied,cols,rows,root):
 # A shared manifold body per landmass. Boundary runs cross tile seams; no void is filled.
 remaining=set(occupied);part=0
 while remaining:
  component={remaining.pop()};todo=list(component)
  while todo:
   c,r=todo.pop()
   for p in ((c-1,r),(c+1,r),(c,r-1),(c,r+1)):
    if p in remaining:remaining.remove(p);component.add(p);todo.append(p)
  # Use integer x/y lattice with y pointing up for consistent boundary winding.
  solid={(c,rows-1-r) for c,r in component};edges={}
  for x,y in solid:
   for neighbour,a,b in [((x,y-1),(x,y),(x+1,y)),((x+1,y),(x+1,y),(x+1,y+1)),((x,y+1),(x+1,y+1),(x,y+1)),((x-1,y),(x,y+1),(x,y))]:
    if neighbour not in solid:edges.setdefault(a,[]).append(b)
  loops=[]
  while edges:
   start=next(iter(edges));v=start;loop=[]
   while True:
    loop.append(v);nxt=edges[v].pop()
    if not edges[v]:del edges[v]
    v=nxt
    if v==start:break
   # Remove straight-through lattice vertices to form broad multi-tile cliff faces.
   corners=[]
   for i,v in enumerate(loop):
    a,b=loop[i-1],loop[(i+1)%len(loop)]
    if (v[0]-a[0])*(b[1]-v[1])!=(v[1]-a[1])*(b[0]-v[0]):corners.append(v)
   loops.append(corners)
  verts=[];faces=[];cache={}
  def vi(v,level):
   key=(v,level)
   if key not in cache:
    x,y=v;wx,wy=x-cols/2,y-rows/2
    touching=[(cx+.5,cy+.5) for cx,cy in ((x-1,y-1),(x,y-1),(x-1,y),(x,y)) if (cx,cy) in solid]
    direction=Vector((sum(p[0] for p in touching)/len(touching)-x,sum(p[1] for p in touching)/len(touching)-y)).normalized()
    inset=(0,.018,.095)[level];z=(-.39,-.86+.09*math.sin(wx*.67+wy*.43),-1.48+.18*math.sin(wx*.71+wy*.39))[level]
    cache[key]=len(verts);verts.append((wx+direction.x*inset,wy+direction.y*inset,z))
   return cache[key]
  for x,y in solid:
   points=[(x,y),(x+1,y),(x+1,y+1),(x,y+1)]
   faces.append(tuple(vi(v,0) for v in points));faces.append(tuple(vi(v,2) for v in points[::-1]))
  for loop in loops:
   for a,b in zip(loop,loop[1:]+loop[:1]):
    for level in (0,1):faces.append((vi(a,level),vi(a,level+1),vi(b,level+1),vi(b,level)))
  mesh=bpy.data.meshes.new(f'{stage}_wide_cliff_{part}');mesh.from_pydata(verts,[],faces)
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
  ob=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(ob);ob.parent=root;mesh.materials.append(side);uv_planar(mesh);part+=1

report={'sources':{k:hashlib.sha256(v.read_bytes()).hexdigest() for k,v in SOURCES.items()},'maps':[]}
for spec in MAPS:
 stage=spec['chapterStage'];RNG=random.Random(6026+spec['progressionOrdinal']);cols,rows=spec['columns'],spec['rows'];scene=bpy.data.scenes.new(stage+' '+spec['name']);scene.use_fake_user=True;cam=setup(scene)
 occupied={(i%cols,i//cols) for i,t in enumerate(spec['tiles']) if t!='blocked'};gaps=set(map(tuple,spec['portalGapCells']))
 def center(c,r):return Vector((c+.5-cols/2,rows/2-r-.5,0))
 def intersects(poly,cells):
  xs=[p[0] for p in poly];ys=[p[1] for p in poly]
  return any(max(xs)>c-cols/2+.005 and min(xs)<c-cols/2+.995 and max(ys)>rows/2-1-r+.005 and min(ys)<rows/2-r-.005 for c,r in cells)
 records=[];tile_roots={}
 for i,t in enumerate(spec['tiles']):
  if t=='blocked':continue
  c,r=i%cols,i//cols;ob=clone(scene,tiles['build_tile' if t=='build' else 'path_tile']);ob.location=center(c,r);ob.name=f'{stage}_{t}_c{c}_r{r}';ob['tile']=[c,r];ob['tileType']=t;tile_roots[c,r]=ob;records.append({'type':t,'cell':[c,r],'name':ob.name})
  if t in ('spawn','core'):
   ob=clone(scene,land['portal' if t=='spawn' else 'core']);ob.location=center(c,r);ob.name=f'{stage}_{t}_landmark'
 for pair in spec['teleportPairs']:
  for role,kind in [('entrance','IN'),('exit','OUT')]:
   cell=tuple(pair[role]);open_portal_host(tile_roots[cell],scene)
   src=portals[pair['color'].upper()+'_'+kind];ob=clone(scene,src,exclude=lambda x:'existing stacked stone sides' in x.name);ob.location=center(*cell);ob.name=f'{stage}_{pair["color"]}_{kind}';ob['cell']=list(cell);ob['role']=role
 root=bpy.data.objects.new(stage+'_continuous_geology',None);scene.collection.objects.link(root);candidates=[];coast=[]
 continuous_substrate(stage,occupied,cols,rows,root)
 for c,r in sorted(occupied):
  x,y=c-cols/2,rows/2-1-r
  for dx,dy,a,b in [(-1,0,(x,y+1),(x,y)),(1,0,(x+1,y),(x+1,y+1)),(0,-1,(x+1,y+1),(x,y+1)),(0,1,(x,y),(x+1,y))]:
   if (c+dx,r+dy) in occupied:continue
   a,b,out=Vector(a),Vector(b),Vector((dx,-dy));coast.append((a,b,out,(c+dx,r+dy) in gaps))
   if not any((cc-c)*dx+(rr-r)*dy>0 and (rr==r if dx else cc==c) for cc,rr in occupied):candidates.append(((a+b)/2,out))
 for e,(a,b,out,gap_edge) in enumerate(coast):
  tangent=(b-a).normalized();cursor=0;n=0
  while cursor<.99:
   length=min(1-cursor,RNG.uniform(.28,.49));mid=a+tangent*(cursor+length*.5);width=-.012 if gap_edge else RNG.uniform(.13,.24)
   poly=[tuple(mid-tangent*length*.49-out*.10),tuple(mid+tangent*length*.49-out*.10),tuple(mid+tangent*length*.49+out*width),tuple(mid-tangent*length*.49+out*width)]
   if not intersects(poly,gaps):
    bottom=RNG.uniform(-.96,-.70)
    rock(f'{stage}_coast_{e}_{n}',poly,bottom,RNG.uniform(-.25,-.10),side,root,RNG.uniform(.6,.92),tuple(-out*.05))
    if not gap_edge and e%4==0 and n==0:
     shift=-tangent*.10-out*.05;fin=[(v[0]+shift.x,v[1]+shift.y) for v in poly]
     if not intersects(fin,gaps):rock(f'{stage}_lower_fin_{e}_{n}',fin,bottom-RNG.uniform(.08,.18),-.66,side,root,.63,tuple(-out*.08))
    if not gap_edge and e%3==1 and n==1:
     pts=[mid-tangent*.10-out*.015,mid+tangent*.13+out*.015,mid+tangent*.08+out*width*.92,mid-tangent*.045+out*width*.85]
     shard=[tuple(v) for v in pts]
     if not intersects(shard,gaps):rock(f'{stage}_attached_fragment_{e}',shard,max(bottom+.15,-1.1),-.27-RNG.uniform(0,.12),side,root,.83,tuple(-out*.025),bevel=.002)
   cursor+=length;n+=1
 targets={16:[(0,6),(-4,-2),(4,-3),(4,3)],17:[(5,-1),(-4,4),(-3,-4),(4,5)],18:[(-5,0),(4,5),(3,-4),(-3,5)],19:[(0,-5),(-5,3),(4,2),(1,6)],20:[(5,-1),(-4,5),(-4,-5),(5,-5)]}[spec['progressionOrdinal']]
 deco=[];used=[];endpoints=[center(*spec['path'][0]),center(*spec['path'][-1])]
 for index,(name,target) in enumerate(zip(('pillar','crystal_lower_left','crystal_right','void_fissure'),targets)):
  actor=clone(scene,props[name]);actor.name=f'{stage}_{name}';half=.58 if index==3 else .48;distance=half+.075;ranked=[]
  for edge,out in candidates:
   mid=edge+out*distance;tangent=Vector((-out.y,out.x));end=distance+.53;wide=.70
   boundary=[tuple(edge-tangent*wide-out*.13),tuple(edge+tangent*wide-out*.13),tuple(edge+tangent*(wide+.08)+out*(end*.7)),tuple(edge+tangent*.48+out*end),tuple(edge-tangent*.48+out*end),tuple(edge-tangent*(wide+.08)+out*(end*.7))]
   footprint=rectangle(mid.x-half,mid.y-half,mid.x+half,mid.y+half)
   if intersects(footprint,occupied) or intersects(boundary,gaps):continue
   if index==0 and any((Vector((mid.x,mid.y,0))-v).length<2.5 for v in endpoints):continue
   gap=min(((mid-v).length for v in used),default=100)
   ranked.append(((mid-Vector(target)).length+max(0,2.5-gap)*30,edge,out,mid,boundary))
  _,edge,out,mid,boundary=min(ranked,key=lambda x:x[0]);used.append(mid);actor.location=(mid.x,mid.y,-.19 if index==3 else 0)
  tangent=Vector((-out.y,out.x));seeds=[tuple(edge+out*.22-tangent*.25),tuple(mid+tangent*.3),tuple(mid-tangent*.3)];ang=actor.rotation_euler.z;nx,ny=math.cos(ang),math.sin(ang);slit=mid.x*nx+mid.y*ny;domains=[boundary] if index!=3 else [clip(boundary,nx,ny,slit-.075),clip(boundary,-nx,-ny,-slit-.075)];z=-.34 if index==3 else -.055
  for di,domain in enumerate(domains):
   for pi,part in enumerate(split_stone(domain,seeds)):
    rock(f'{stage}_ledge_{index}_{di}_{pi}',part,RNG.uniform(-1.6,-1.2),z,side,root,.8);cx=sum(x for x,y in part)/len(part);cy=sum(y for x,y in part)/len(part);inset=[(cx+(x-cx)*.975,cy+(y-cy)*.975) for x,y in part];rock(f'{stage}_cap_{index}_{di}_{pi}',inset,z-.17,z+.012,topmat,root,.98)
  for j in range(3):
   pos=edge+out*(distance+.32)+tangent*((j-1)*.24);size=RNG.uniform(.045,.080)
   rubble=rectangle(pos.x-size,pos.y-size*.7,pos.x+size,pos.y+size*.7)
   if not intersects(rubble,occupied|gaps):rock(f'{stage}_ledge_rubble_{index}_{j}',rubble,z-.015,z+size*.8,side,root,.86,(.004,-.006),bevel=.002)
  deco.append({'role':name,'location':list(actor.location),'ledge':boundary})
 fragments=[]
 for edge,out in candidates:
  pos=edge+out*.62;size=RNG.uniform(.10,.17);footprint=rectangle(pos.x-size,pos.y-size*.75,pos.x+size,pos.y+size*.75)
  if intersects(footprint,occupied|gaps) or any((pos-v).length<1.6 for v in used) or any((pos-v).length<2.3 for v in fragments):continue
  fragments.append(pos);z=RNG.uniform(-1.35,-.65)
  rock(f'{stage}_floating_fragment_{len(fragments)}',footprint,z-size*2,z+size,side,root,.68,(.035,-.02),bevel=.006)
  if len(fragments)==6:break
 label(scene,cam,f'{spec["progressionOrdinal"]}  |  {stage}  {spec["name"]}',7.05,.34)
 label(scene,cam,f'보행 {spec["walkingEdges"]}칸  ·  순간이동 {len(spec["teleportPairs"])}회  ·  건설 {len(spec["buildCells"])}칸',-6.9,.21)
 label(scene,cam,'챕터 2 신규 맵 설계 · 기존 자산 재배치 · 게임 미적용',-7.25,.16)
 scene['proposalOnly']=True;scene['mapSource']='../maps.json';scene['tileRecords']=json.dumps(records);scene['teleportPairs']=json.dumps(spec['teleportPairs']);scene['dressingRecords']=json.dumps(deco);scene.render.filepath=str(HERE/f'chapter-{stage}.png')
 report['maps'].append({'stage':stage,'tileRecords':records,'dressingRecords':deco,'gapCells':spec['portalGapCells'],'cameraScale':cam.data.ortho_scale})
 bpy.context.view_layer.update();print('RENDER_BEGIN',stage,flush=True);bpy.ops.render.render(write_still=True);print('RENDER_DONE',stage,flush=True)
for scene in list(bpy.data.scenes):
 if scene.name not in [s['chapterStage']+' '+s['name'] for s in MAPS]:bpy.data.scenes.remove(scene)
bpy.ops.outliner.orphans_purge(do_recursive=True);bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(TARGET if not args.stage else HERE/'chapter2-preview.blend'))
(LOG/'blender-placement.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('ALL_CONCEPTS_COMPLETE',flush=True)
