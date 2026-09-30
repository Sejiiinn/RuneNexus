"""Export preserved decoration only for the isolated Godot layout preview."""
import bpy
from pathlib import Path
HERE=Path(__file__).resolve().parent
if not bpy.app.background:raise RuntimeError('Use independent background Blender')
bpy.ops.wm.open_mainfile(filepath=str(HERE/'chapter1-teleport-map-concepts.blend'))
for stage in ['1-7','1-10']:
    scene=next(s for s in bpy.data.scenes if s.name.startswith(stage+' '));bpy.context.window.scene=scene
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in scene.objects if o.name.startswith(stage+'_dressing_')]
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(HERE/f'chapter-{stage}-dressing.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
    print('DRESSING_EXPORTED',stage,len(objects),flush=True)
