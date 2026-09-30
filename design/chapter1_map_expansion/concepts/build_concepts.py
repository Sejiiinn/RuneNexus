"""Render proposed Chapter 1 maps from saved approved assets, without game exports.
Run in an independent Blender background process to preserve the open editor.
"""
import bpy,json,math,hashlib,random,os
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
if not bpy.app.background: raise RuntimeError('Use independent background Blender')
bpy.ops.wm.read_factory_settings(use_empty=True)
MAPS=json.loads((HERE.parent/'maps.json').read_text())['maps']
PREVIEW_STAGE=os.environ.get('CONCEPT_STAGE')
if PREVIEW_STAGE:MAPS=[m for m in MAPS if m['chapterStage']==PREVIEW_STAGE]
if any(m.get('teleportPairs') for m in MAPS):
 raise RuntimeError('Portal revisions must use update_teleport_concepts.py with the preserved five-map source; base rebuild would omit devices.')
TERRAIN=ROOT/'design/stage1_3d/surface_effects/terrain-surface.blend'
DRESS=ROOT/'design/stage1_3d/environment_dressing/environment-dressing.blend'
LAND=ROOT/'design/stage1_3d/portal_core_concepts/production/rune-landmarks.blend'
BG=ROOT/'assets/images/backgrounds/combat_space_nebula.png'
manifest=json.loads((DRESS.parent/'placement_manifest.json').read_text())
def append(path,names=None):
 with bpy.data.libraries.load(str(path),link=False) as (s,d): d.objects=names or s.objects
 return {o.name:o for o in d.objects}
tiles=append(TERRAIN,['build_tile','path_tile','build_tile_natural_surface','path_tile_natural_surface'])
land=append(LAND)
import sys
sys.path.insert(0,str(HERE))
from portal_preview import apply as apply_portal_preview
apply_portal_preview(land['portal_vortex'])
plants=append(DRESS,[p['name'] for p in manifest['placements']])
font=bpy.data.fonts.load('/System/Library/Fonts/AppleSDGothicNeo.ttc')
report={'inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [TERRAIN,DRESS,LAND,BG,HERE.parent/'maps.json']},'maps':[]}
# Same 25-degree-from-top view, camera scale, lighting, and texture background for all five.
def setup(scene):
 bpy.context.window.scene=scene
 scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
 scene.render.resolution_x=1200;scene.render.resolution_y=1320;scene.render.resolution_percentage=100
 scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
 scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
 w=bpy.data.worlds.new('Soft neutral ambient');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.12,.17,.22,1);w.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=w
 for loc,power,size in [((-5,-3,9),1800,5),((4,3,7),700,6)]:
  d=bpy.data.lights.new('Shared area lighting','AREA');d.energy=power;d.shape='DISK';d.size=size
  o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 d=bpy.data.cameras.new('Shared 25 degree camera');o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o)
 o.location=(0,-math.sin(math.radians(25))*20,math.cos(math.radians(25))*20);o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=12.8;scene.camera=o
 # A camera-aligned emissive plane carries the existing approved nebula image.
 bpy.ops.mesh.primitive_plane_add(size=2);plane=bpy.context.object;plane.name='Approved chapter 1 space backdrop'
 plane.rotation_euler=o.rotation_euler;plane.location=o.location+o.rotation_euler.to_matrix()@Vector((0,0,-30));plane.scale=(7.2,7.8,1)
 m=bpy.data.materials.get('Approved space texture')
 if not m:
  m=bpy.data.materials.new('Approved space texture');m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(BG));m.node_tree.links.new(t.outputs['Color'],e.inputs['Color']);m.node_tree.links.new(e.outputs[0],out.inputs['Surface'])
 plane.data.materials.append(m)
 return o

def clone_tree(scene,src,pos,parent=None):
 ob=src.copy();scene.collection.objects.link(ob);ob.hide_render=False;ob.hide_viewport=False;ob.animation_data_clear();ob.parent=parent
 if parent is None:ob.location=pos
 for child in src.children:clone_tree(scene,child,pos,ob)
 return ob

def label(scene,camera,text,x,y,size):
 curve=bpy.data.curves.new(text,'FONT');curve.body=text;curve.font=font;curve.size=size;curve.align_x='CENTER'
 ob=bpy.data.objects.new(text,curve);scene.collection.objects.link(ob);ob.rotation_euler=camera.rotation_euler;ob.location=camera.location+camera.rotation_euler.to_matrix()@Vector((x,y,-10))
 m=bpy.data.materials.get('Caption white')
 if not m:
  m=bpy.data.materials.new('Caption white');m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.7,.85,.85,1);p.inputs['Emission Color'].default_value=(.7,.85,.85,1);p.inputs['Emission Strength'].default_value=1
 curve.materials.append(m)

for spec in MAPS:
 stage=spec['chapterStage'];scene=bpy.data.scenes.new(stage+' '+spec['name']);scene.use_fake_user=True;cam=setup(scene)
 cols,rows=spec['columns'],spec['rows'];types=spec['tiles'];records=[];decos=[]
 def center(c,r):return Vector((c+.5-cols/2,rows/2-r-.5,0))
 for i,t in enumerate(types):
  if t=='blocked':continue
  c,r=i%cols,i//cols;pos=center(c,r);ob=clone_tree(scene,tiles['build_tile' if t=='build' else 'path_tile'],pos);ob.name=f'{stage}_{t}_c{c}_r{r}';ob['tile']=[c,r];ob['tileType']=t;records.append({'type':t,'cell':[c,r],'name':ob.name})
  if t in ('spawn','core'):clone_tree(scene,land['portal' if t=='spawn' else 'core'],pos)
 # Authored sparse distribution: two or three unequal focal areas per map, selected
 # species rather than copying every fern/rock cluster to each build cell.
 # Each tuple is (column,row,exposed edge, source placement IDs).
 layouts={
  '1-6':[
   # Upper planting sweeps across several cells, with an open break at c4.
   (1,1,'S',[0,4,2]),(2,1,'S',[27,31,32]),(3,1,'S',[44,45]),
   (5,1,'S',[47]),(6,1,'S',[13,14,37]),(6,2,'W',[46]),
   # Core-side cluster: rich upper leaf pocket tapering into narrow grass.
   (3,3,'E',[11,15,10]),(3,4,'E',[21,20]),(3,5,'E',[50]),
   # Broken small island, leafy on one side and quiet stone on the other.
   (5,4,'N',[43,12]),(6,4,'N',[29,30]),
   # Lower pocket spreads fern, grass and groundcover across adjacent cells.
   (4,6,'N',[16,19,17]),(3,7,'N',[48]),(4,7,'N',[49,51]),
   (5,7,'N',[55]),(6,6,'W',[24,25]),
  ],
  '1-7':[
   (1,1,'W',[21,25,23]),(2,1,'N',[27,31]),(1,2,'W',[44,45]),
   (2,3,'W',[29,30]),(4,1,'E',[11,15]),(4,2,'E',[50]),
   (4,3,'N',[0,20]),(5,3,'N',[13,14]),
   (9,4,'E',[16,19,17]),(9,5,'E',[43,47]),(7,6,'W',[49,32]),
   (5,7,'N',[5,10]),(6,7,'N',[24,25,55]),
   (2,7,'N',[27,28]),(3,7,'N',[51]),
  ],
  '1-8':[
   (1,0,'N',[27,28,31]),(2,2,'W',[21,25]),(3,2,'N',[11,15]),
   (4,2,'N',[46]),(3,3,'W',[44,45]),(4,3,'S',[16,20]),
   (7,3,'E',[8,9,12]),(1,4,'W',[43,47]),
   (3,5,'S',[0,4]),(4,5,'S',[48]),
   (5,6,'N',[21,25,23]),(6,6,'N',[27,31,32]),
   (7,6,'N',[13,14,37]),(7,8,'W',[49,50]),
  ],
  '1-9':[
   (1,1,'W',[0,4]),(2,1,'N',[27,28,31]),(3,1,'N',[46]),
   (5,1,'N',[29,30]),(2,3,'N',[21,20]),(3,3,'N',[44,45]),
   (4,3,'N',[43,15]),(5,3,'N',[5,9,7]),(6,3,'N',[13,14,37]),
   (2,5,'S',[48]),(4,5,'S',[49,51]),
   (6,7,'W',[16,19,17]),(6,8,'W',[27,31]),
   (8,7,'E',[24,25,12]),(8,5,'E',[11,15,10]),
  ],
  '1-10':[
   (1,1,'W',[27,31,32]),(2,1,'N',[44,45]),(2,2,'W',[21,25,23]),
   (4,1,'N',[13,14]),(4,2,'N',[50]),(5,2,'N',[11,15,10]),
   (6,2,'N',[0,4,2]),(4,4,'S',[43,47]),(5,4,'S',[48]),
   (2,6,'N',[49,51]),(2,7,'W',[21,20]),(3,7,'S',[44,45]),
   (4,6,'E',[8,9,37]),(5,7,'W',[24,25,55]),
   (6,7,'E',[27,31]),(6,6,'W',[16,19,17]),
  ],
 }
 candidates=manifest['placements'];angles={'N':0,'W':math.pi/2,'S':math.pi,'E':-math.pi/2}
 for c,r,edge,ids in layouts[stage]:
  assert types[r*cols+c]=='build'
  for source_index in ids:
   p=candidates[source_index]
   proto=plants[p['name']];sc,sr=p['tile'];old=Vector((sc-3.5,4.5-sr,0));rot=Matrix.Rotation(angles[edge]-angles[p['edge']],4,'Z');verts=[center(c,r)+rot.to_3x3()@(proto.matrix_world@v.co-old) for v in proto.data.vertices]
   # Move removable foliage toward shared seams inside each authored cluster,
   # instead of centering one plant on every tile. Hard stones retain edge placement.
   offsets={
    '1-6':{(1,1):(.18,0),(2,1):(-.17,.03),(3,1):(-.20,-.10),
           (3,3):(.10,-.14),(3,4):(.10,.14),(3,5):(.12,.15),
           (5,4):(.10,.03),(4,6):(.03,-.18),(4,7):(.10,.18),(3,7):(.21,.12)},
    '1-7':{(1,1):(.17,-.10),(2,1):(-.17,-.12),(1,2):(.12,.15),
           (4,1):(.08,-.16),(4,2):(.08,.10),(4,3):(.15,0),
           (9,4):(.08,-.16),(9,5):(.06,.16),(5,7):(.18,.05),(2,7):(.16,0),(3,7):(-.18,.02)},
    '1-8':{(2,2):(.16,-.06),(3,2):(-.15,-.05),(4,2):(-.18,-.04),
           (3,3):(.16,.12),(4,3):(-.14,.12),(5,6):(.17,.03),(6,6):(-.15,.06),(3,5):(.15,0)},
    '1-9':{(1,1):(.16,0),(2,1):(-.15,0),(3,1):(-.2,0),
           (2,3):(.14,0),(3,3):(-.13,0),(4,3):(.14,0),(5,3):(-.15,.04),
           (6,7):(-.05,-.16),(6,8):(-.04,.16)},
    '1-10':{(1,1):(.16,-.05),(2,1):(-.15,-.07),(2,2):(.1,.15),
            (5,2):(.17,.06),(6,2):(-.16,.06),(4,4):(.12,-.02),
            (2,6):(.10,-.16),(2,7):(.12,.15),(3,7):(-.18,.10),(6,7):(.07,.16),(6,6):(.07,-.15)},
   }
   dx,dy=0,0
   if p['removableOnBuild']:
    dx,dy=offsets.get(stage,{}).get((c,r),(0,0))
    verts=[v+Vector((dx,dy,0)) for v in verts]
   bad=False
   for v in verts:
    if v.z<.005:continue
    cc,rr=math.floor(v.x+cols/2),math.floor(rows/2-v.y)
    if 0<=cc<cols and 0<=rr<rows:
     kind=types[rr*cols+cc]
     if kind in ('path','spawn','core'):bad=True;break
     if kind=='build' and not (p['removableOnBuild'] and (cc,rr)==(c,r)):
      local=v-center(cc,rr)
      if abs(local.x)<.35 and abs(local.y)<.35:bad=True;break
   if bad:continue
   ob=proto.copy();ob.data=proto.data.copy();ob.animation_data_clear();ob.parent=None;ob.matrix_world=Matrix.Identity(4);scene.collection.objects.link(ob);ob.hide_render=False
   if ob.data.shape_keys:ob.shape_key_clear()
   for v,co in zip(ob.data.vertices,verts):v.co=co
   ob.name=f'{stage}_dressing_{len(decos):02}_{p["sourceAssetId"]}';decos.append({'name':ob.name,'source':p['name'],'cell':[c,r],'foliageOffset':[dx,dy]})
 label(scene,cam,stage+'  '+spec['name'],0,5.65,.34)
 label(scene,cam,f'3D 배치 시안  ·  경로 {spec["pathTiles"]}칸  /  건설 {len(spec["buildCells"])}칸',0,-5.5,.19)
 label(scene,cam,'기존 자산 재배치 · 게임 미적용',0,-5.85,.15)
 path=spec['path'];assert all(abs(a[0]-b[0])+abs(a[1]-b[1])==1 for a,b in zip(path,path[1:]));assert len(path)==spec['pathTiles'];assert len(set(map(tuple,path)))==len(path)
 assert len([x for x in records if x['type']=='build'])==len(spec['buildCells'])
 scene['proposalOnly']=True;scene['mapSource']='../maps.json';scene['tileRecords']=json.dumps(records);scene['dressingRecords']=json.dumps(decos)
 report['maps'].append({'stage':stage,'tileRecords':records,'dressingRecords':decos,'camera':list(cam.location),'orthographicScale':cam.data.ortho_scale})
 scene.render.filepath=str(HERE/f'chapter-{stage}.png')
 print('RENDER_BEGIN',stage, len(records),len(decos),flush=True)
 bpy.context.view_layer.update()
 bpy.ops.render.render(write_still=True)
 print('RENDER_DONE',stage,flush=True)
# Preserve all five editable scenes and packed source textures.
bpy.context.window.scene=bpy.data.scenes[MAPS[0]['chapterStage']+' '+MAPS[0]['name']]
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(HERE/('one-map-preview.blend' if PREVIEW_STAGE else 'chapter1-five-map-concepts.blend')))
(HERE/('verification-preview.json' if PREVIEW_STAGE else 'verification.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('ALL_CONCEPTS_COMPLETE',flush=True)
