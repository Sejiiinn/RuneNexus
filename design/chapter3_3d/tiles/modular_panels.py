"""Preserve approved tile surfaces; cut real seats and build removable panels."""
import bpy, math, sys, json
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import build_tiles as kit
assert bpy.app.background
bpy.ops.wm.open_mainfile(filepath=str(HERE/'modular_revision/before-modular-panels.blend'))
kit.M={key:bpy.data.materials[name] for key,name in {
 'side':'Recess walls | forged iron','dark':'Flanges | dark forged iron',
 'edge':'Exposed worn iron edges','bronze':'Mounting ring | aged bronze',
 'worn_bronze':'Worn bronze bevel'}.items()}
roots=[bpy.data.objects[n] for n in ('01_Cast_iron_plate','02_Heat_vent_grate','03_Construction_foundation')]
for root in roots:
 for ob in list(root.children):
  if ob.name.startswith('Vent_'):bpy.data.objects.remove(ob,do_unlink=True)
 # Cut actual openings through the former housing/cavity walls, into the body.
 for side in range(4):
  a=side*math.pi/2
  poly=[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in kit.rect(-.148,-.52,.148,-.325,0)]
  cut=kit.prism('Seat cutter',poly,-.405,-.155,kit.M['dark'],root,0)
  bpy.context.view_layer.update()
  for ob in list(root.children):
   if ob==cut or not ob.name.startswith(('Recessed_housing','Cavity_wall')):continue
   # Apply bevel first so Boolean does not change the original outer bevels.
   bpy.context.view_layer.objects.active=ob
   for mod in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
   mod=ob.modifiers.new('Actual recessed service seat','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
   bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.data.objects.remove(cut,do_unlink=True)
 root['sidePanelSeats']=4;root['sidePanelContract']='tile-local origin; front Blender -Y; rotate Z by quarter turns'
plain=bpy.data.objects.new('04_Plain_construction_foundation',None);bpy.context.scene.collection.objects.link(plain)
for k in roots[2].keys():plain[k]=roots[2][k]
for ob in roots[2].children:
 if ob.name.startswith(('Bronze_mounting_ring','Cardinal_ring_clamp_','Ring_anchor_')):continue
 clone=ob.copy();clone.data=ob.data.copy();bpy.context.scene.collection.objects.link(clone);clone.parent=plain
roots.append(plain)
panels=[]
for name in ('05_Panel_solid','06_Panel_vent'):
 r=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(r);panels.append(r)
 r['mount']='tile origin; front Blender -Y / Godot +Z';r['seatWidth']=.296;r['seatHeight']=.25
solid,vent=panels
def block(name,x0,x1,y0,y1,z0,z1,mat,parent,bevel=.0015):
 return kit.prism(name,kit.rect(x0,y0,x1,y1,.001),z0,z1,mat,parent,bevel)
block('Solid removable closure',-.146,.146,-.452,-.425,-.403,-.157,kit.M['side'],solid)
for parent in panels:
 for side,x0,x1,z0,z1 in [('upper',-.146,.146,-.207,-.157),('lower',-.146,.146,-.403,-.353),('left',-.146,-.108,-.353,-.207),('right',.108,.146,-.353,-.207)]:
  block('Panel frame '+side,x0,x1,-.457,-.425,z0,z1,kit.M['dark'],parent)
 # Inner return surfaces expose the real depth in an oblique view.
 for x0,x1 in [(-.108,-.099),(.099,.108)]:block('Seat inner return',x0,x1,-.425,-.355,-.353,-.207,kit.M['side'],parent)
 if parent==vent:
  for x in (-.036,.036):block('Vent mullion',x-.009,x+.009,-.45,-.393,-.353,-.207,kit.M['dark'],parent)
  # Initial vent volumes; apply the shallow three-slot correction below.
  block('Vent cavity back',-.108,.108,-.351,-.339,-.400,-.207,kit.M['dark'],parent)
  hot=bpy.data.materials['Recessed orange service vent']
  for x in (-.072,0,.072):block('Recessed vent heat core',x-.020,x+.020,-.365,-.353,-.398,-.214,hot,parent,.003)
# Keep the solid panel unchanged; expose three vertical heat slots at 55 degrees.
from modular_revision.restore_visible_vents import reshape_vent
reshape_vent(vent)
# Separate preview copies: exporter only consumes the six source roots above.
for i,r in enumerate(roots):r.location=((i-1.5)*1.22,0,0)
for p in panels:p.hide_render=True;p.hide_set(True)
for i,r in enumerate(roots):
 for side in range(4):
  source=vent if (i in (1,3) and side==0) else solid
  for ob in source.children:
   clone=ob.copy();clone.data=ob.data;clone.parent=None;bpy.context.scene.collection.objects.link(clone)
   clone.name='Preview only '+ob.name;clone.rotation_euler.z=side*math.pi/2;clone.location=r.location;clone['previewOnly']=True
for p in panels:
 for ob in p.children:ob.hide_render=True;ob.hide_set(True)
cam=bpy.context.scene.camera;cam.location=(2.8,-7,5.4);cam.rotation_euler=(Vector((0,0,-.18))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=5.3
s=bpy.context.scene;s.cycles.samples=32;s.render.resolution_x=1800;s.render.resolution_y=850;s.render.resolution_percentage=100
s.render.filepath=str(HERE/'modular_revision/assembled-source.png')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'chapter3-thick-tiles.blend'))
bpy.ops.render.render(write_still=True)
print('MODULAR_SOURCE_READY',flush=True)
