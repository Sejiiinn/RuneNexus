"""Refine preserved foundry source to the user's 2026-09-18 stage screenshot.
Run in independent background Blender; keep the interactive document untouched.
"""
import bpy, math, sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import build_tiles as kit
assert bpy.app.background
bpy.ops.wm.open_mainfile(filepath=str(HERE/'reference_revision/before-reference-fix.blend'))
spec={
 'steel':('Cast iron | silver graphite',(.054,.047,.040),(.091,.080,.068),.66,.64),
 'blue':('Construction plate | blue graphite',(.007,.011,.017),(.015,.022,.030),.72,.52),
 'dark':('Flanges | dark forged iron',(.005,.007,.009),(.014,.017,.021),.76,.60),
 'side':('Recess walls | forged iron',(.007,.008,.010),(.019,.021,.024),.74,.58),
 'edge':('Exposed worn iron edges',(.028,.029,.030),(.064,.061,.055),.66,.64),
 'bolt':('Forged steel fasteners',(.055,.051,.043),(.107,.093,.073),.63,.65),
 'bronze':('Mounting ring | aged bronze',(.030,.022,.015),(.072,.053,.033),.71,.62),
 'worn_bronze':('Worn bronze bevel',(.044,.034,.024),(.097,.073,.049),.65,.62),
}
kit.M={}
for key,(name,dark,light,rough,metal) in spec.items():
 m=bpy.data.materials[name];kit.M[key]=m
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Metallic'].default_value=metal
 for n in m.node_tree.nodes:
  if n.type=='VALTORGB':
   n.color_ramp.elements[0].color=(*dark,1);n.color_ramp.elements[1].color=(*light,1)
  elif n.type=='MIX_RGB':n.inputs[2].default_value=(*(v*1.13 for v in light),1)
  elif n.type=='MAP_RANGE':n.inputs['To Min'].default_value=rough-.04;n.inputs['To Max'].default_value=rough+.05
  elif n.type=='BUMP':n.inputs['Strength'].default_value=.035
roots=[bpy.data.objects[n] for n in ('01_Cast_iron_plate','02_Heat_vent_grate','03_Construction_foundation')]
for r in roots:r['approvedConcept']='design/chapter3_3d/tiles/reference_revision/user-stage11-reference.jpg'
# Inner machined frame and small fasteners on path/grate; actual relief.
for root in roots[:2]:
 for side in range(4):
  a=side*math.pi/2
  poly=[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in kit.rect(-.378,-.388,.378,-.366,.006)]
  kit.prism('Inset_border_%d'%side,poly,.001,.012,kit.M['steel'],root,.002)
  for pos in (-.22,0,.22):
   x=pos*math.cos(a)+.434*math.sin(a);y=pos*math.sin(a)-.434*math.cos(a)
   kit.cylinder('Rim_rivet_%d_%s'%(side,pos),x,y,.001,.010,.011,kit.M['bolt'],root,8)
# Narrow, oxidized mounting ring with circular bolted saddles.
root=roots[2]
for ob in list(root.children):
 if ob.name.startswith(('Bronze_mounting_ring','Cardinal_ring_clamp_')):bpy.data.objects.remove(ob,do_unlink=True)
kit.ring('Bronze_mounting_ring',.307,.344,.002,.024,kit.M['bronze'],root)
for j in range(4):
 t=(j+.5)*math.pi/2;x=.327*math.cos(t);y=.327*math.sin(t)
 kit.cylinder('Cardinal_ring_clamp_%d'%j,x,y,.016,.037,.058,kit.M['bronze'],root,24)
 kit.cylinder('Ring_anchor_washer_%d'%j,x,y,.037,.040,.037,kit.M['dark'],root,20)
 kit.cylinder('Ring_anchor_fastener_%d'%j,x,y,.040,.053,.026,kit.M['bronze'],root,8)
 kit.cylinder('Ring_anchor_recess_%d'%j,x,y,.053,.0535,.010,kit.M['dark'],root,12)
# Warm interior remains below all 25 true openings, near enough to read obliquely.
ember=bpy.data.materials['Deep ember bed | localized orange only'];p=ember.node_tree.nodes.get('Principled BSDF')
p.inputs['Emission Color'].default_value=(.80,.135,.006,1)
for n in ember.node_tree.nodes:
 if n.type=='MAP_RANGE':n.inputs['To Min'].default_value=1.1;n.inputs['To Max'].default_value=.27;n.inputs['From Max'].default_value=.42
bed=next(o for o in roots[1].children if o.name.startswith('Recessed_embers'))
for v in bed.data.vertices:v.co.z+=.115
for ob in roots[1].children:
 if ob.name.startswith('Internal_baffle_'):
  for v in ob.data.vertices:v.co.z+=.08
# Real recessed vent windows, bounded by a dark frame and grille mullions.
vent=bpy.data.materials.new('Recessed orange service vent');vent.use_nodes=True
p=vent.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.055,.011,.002,1);p.inputs['Emission Color'].default_value=(1,.16,.007,1);p.inputs['Emission Strength'].default_value=1.1;p.inputs['Roughness'].default_value=.8
for root in roots[1:]:
 for side in (0,):
  a=side*math.pi/2
  def block(name,x0,x1,y0,y1,z0,z1,mat):
   poly=[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in kit.rect(x0,y0,x1,y1,.001)]
   return kit.prism(name,poly,z0,z1,mat,root,.001)
  block('Vent_dark_socket',-.13,.13,-.465,-.451,-.244,-.117,kit.M['dark'])
  for j in range(3):
   x=(j-1)*.061
   block('Vent_ember_window_%d'%j,x-.018,x+.018,-.467,-.465,-.221,-.149,vent)
  block('Vent_upper_hood',-.14,.14,-.479,-.452,-.145,-.123,kit.M['side'])
  block('Vent_lower_sill',-.14,.14,-.479,-.452,-.241,-.219,kit.M['side'])
# Match the reference's deep side casing at the actual game camera angle.
# Top hardware and the visible ember bed/baffles retain their exact locations.
for root in roots:
 root['bodyThickness']=.50
 for ob in root.children:
  if ob.type!='MESH' or ob.name.startswith(('Recessed_embers','Internal_baffle_')):continue
  for v in ob.data.vertices:
   if v.co.z<-.065:v.co.z=-.065+(v.co.z+.065)*(.50-.065)/(.34-.065)
for v in bpy.data.objects['Studio ground'].data.vertices:v.co.z-=.16
s=bpy.context.scene;cam=s.camera;kit.pose(cam,'hero')
s.cycles.samples=48;s.render.resolution_x=1600;s.render.resolution_y=820
s.render.filepath=str(HERE/'reference_revision/refined-hero.png')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'chapter3-thick-tiles.blend'))
bpy.ops.render.render(write_still=True)
print('REFERENCE_REFINEMENT_READY',flush=True)
