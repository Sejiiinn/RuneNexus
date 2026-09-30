"""Extract approved SWIFT solid flash and normalized hexagonal aim mesh.
Independent background Blender only; never save or edit approval sources.
"""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[5]
HERE=Path(__file__).resolve().parent
TARGET=ROOT/'assets/images/stage1_3d/effects/sniper'
assert bpy.app.background, 'Preserve the open editor; run background Blender.'
TARGET.mkdir(parents=True,exist_ok=True)
source=HERE.parent/'animation/sniper-fire-animated.blend'
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.scene.frame_set(17)
fx=next(o for o in bpy.context.scene.objects if o.name.startswith('FX precise single-shot flash'))
local_inverse=fx.matrix_world.inverted();copies=[]
for original in fx.children_recursive:
 if original.type!='MESH':continue
 copy=original.copy();copy.data=original.data.copy();copy.animation_data_clear();copy.parent=None
 bpy.context.scene.collection.objects.link(copy);copy.matrix_world=local_inverse@original.matrix_world
 copies.append(copy)
for o in list(bpy.context.scene.objects):
 if o not in copies:bpy.data.objects.remove(o,do_unlink=True)
root=bpy.data.objects.new('sniper_flash',None);bpy.context.scene.collection.objects.link(root)
for o in copies:
 matrix=o.matrix_world.copy();o.parent=root;o.matrix_world=matrix
root['source']='production/animation/sniper-fire-animated.blend; approved 56-triangle needle + four fins'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(TARGET/'flash.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
triangles=sum(len(p.vertices)-2 for o in copies for p in o.data.polygons);assert triangles==56
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
line_source=HERE.parent/'animation/aim-line/sniper-aim-line.blend';line_hash=hashlib.sha256(line_source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(line_source))
original=next(o for o in bpy.context.scene.objects if o.name.startswith('Aim line —'))
copy=original.copy();copy.data=original.data.copy();copy.animation_data_clear();copy.parent=None;copy.matrix_world=Matrix.Identity(4);copy.hide_render=False;copy.hide_set(False)
bpy.context.scene.collection.objects.link(copy)
for o in list(bpy.context.scene.objects):
 if o!=copy:bpy.data.objects.remove(o,do_unlink=True)
copy.name='sniper_aim_line';copy['source']='production/animation/aim-line/sniper-aim-line.blend; 20-triangle solid hexagonal cylinder, normalize source radius/length at runtime'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(TARGET/'aim_line.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
assert sum(len(p.vertices)-2 for p in copy.data.polygons)==20
assert hashlib.sha256(line_source.read_bytes()).hexdigest()==line_hash
(HERE/'manifest.json').write_text(json.dumps({'flash_source_sha256':source_hash,'line_source_sha256':line_hash,'flash_triangles':56,'line_triangles':20,'outputs':[str(p.relative_to(ROOT)) for p in TARGET.glob('*.glb')],'source_preserved':True},indent=2)+'\n')
print('SWIFT_VFX_EXPORT_READY')
