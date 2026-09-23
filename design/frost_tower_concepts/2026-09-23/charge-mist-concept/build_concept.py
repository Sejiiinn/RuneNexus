import bpy,math,json
from pathlib import Path
OUT=Path('/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/charge-mist-concept')
s=bpy.data.scenes['Frost charge mist concept']; bpy.context.window.scene=s
# Original editable fin geometry retained. Separate per-level materials provide editable charge animation.
for o in s.objects:
 if 'horizontal fin' in o.name:
  level=int(o.name.split('horizontal fin ')[1][:2])-1
  for j,m in enumerate(o.data.materials):
   mm=m.copy();o.data.materials[j]=mm
   bs=mm.node_tree.nodes.get('Principled BSDF')
   if bs:
    bs.inputs['Emission Color'].default_value=(.015,.55,.85,1)
    for f,v in [(1,.03),(int(5+level*4),.03),(int(13+level*4),2.8),(111,2.8),(113,.03),(192,.03)]:
     bs.inputs['Emission Strength'].default_value=v;bs.inputs['Emission Strength'].keyframe_insert('default_value',frame=f)
# Shared mesh has actual thickness and irregular folded contour; no camera planes.
verts=[];faces=[];rings=12;segments=24
for j in range(rings+1):
 t=math.pi*j/rings
 for i in range(segments):
  a=2*math.pi*i/segments
  r=1+.12*math.sin(3*a+2*t)+.07*math.sin(5*a-3*t)
  verts.append((math.sin(t)*math.cos(a)*r,math.sin(t)*math.sin(a)*r,math.cos(t)*(.62+.08*math.sin(a*3))))
for j in range(rings):
 for i in range(segments):
  a=j*segments+i;b=j*segments+(i+1)%segments;c=b+segments;d=a+segments
  faces.append((a,b,c,d))
me=bpy.data.meshes.new('Irregular folded mist volume');me.from_pydata(verts,[],faces);me.update()
ob=bpy.data.objects.new('Mist source - 3D folded volume',me);s.collection.objects.link(ob)
for p in me.polygons:p.use_smooth=True
ob.location=(0,0,-3);ob.hide_render=True
bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
x=bpy.data.scenes.new('Mist export isolated');x.collection.objects.link(ob);bpy.context.window.scene=x
bpy.ops.export_scene.gltf(filepath=str(OUT/'mist-volume.glb'),export_format='GLB',use_active_scene=True,export_apply=True)
bpy.context.window.scene=s
bpy.data.libraries.write(str(OUT/'charge-mist.blend'),{s},fake_user=True,compress=True)
(OUT/'mesh-audit.json').write_text(json.dumps({'mist_vertices':len(verts),'mist_triangles':len(faces)*2,'instances':32,'source':'Blender editable irregular closed mesh'},indent=2))
print('CONCEPT_SOURCE_READY',len(verts),len(faces)*2)
