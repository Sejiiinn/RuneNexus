"""Export the edited PlacementDust3D source without touching another open scene."""
from pathlib import Path
import bpy
import json
import shutil
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
ASSET=ROOT/'assets/images/stage1_3d/effects/placement_dust.glb'
scene=bpy.data.scenes.get('PlacementDust3D')
if scene is None: raise RuntimeError('Load/append the saved PlacementDust3D source scene first.')
puff=scene.objects.get('placement_dust_puff')
if puff is None or puff.type!='MESH': raise RuntimeError('Single dust mesh is missing.')
previous=bpy.context.window.scene if bpy.context.window else None
original_material=puff.data.materials[0]
rest_material=original_material.copy()
rest_material.name='PlacementDust_SoftGreyBrown_Rest'
rest_material.node_tree.animation_data_clear()
alpha_socket=rest_material.node_tree.nodes['Principled BSDF'].inputs['Alpha']
for link in list(alpha_socket.links): rest_material.node_tree.links.remove(link)
alpha_socket.default_value=.46
rest_material.surface_render_method='BLENDED'
puff.data.materials[0]=rest_material
try:
    if bpy.context.window: bpy.context.window.scene=scene
    for obj in scene.objects: obj.select_set(False)
    puff.select_set(True)
    bpy.context.view_layer.objects.active=puff
    ASSET.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(ASSET),export_format='GLB',use_selection=True,
        use_active_scene=True,export_animations=False,export_cameras=False,export_lights=False,
        export_extras=True,export_normals=True,export_all_vertex_colors=True)
    mesh=puff.data
    mesh.calc_loop_triangles()
    low=[min(v.co[i] for v in mesh.vertices) for i in range(3)]
    high=[max(v.co[i] for v in mesh.vertices) for i in range(3)]
    shutil.copy2(HERE/'burst_manifest.json',ASSET.with_suffix('.json'))
    print('PLACEMENT_DUST_EXPORTED '+json.dumps({'model':str(ASSET),'bytes':ASSET.stat().st_size,
        'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),
        'bounds_blender': [low,high], 'bounds_godot':[[low[0],low[2],-high[1]],[high[0],high[2],-low[1]]],
        'source_scene':scene.name,'mesh':puff.name,'smooth_normals':all(p.use_smooth for p in mesh.polygons),
        'colors':list(mesh.color_attributes.keys())}))
finally:
    puff.data.materials[0]=original_material
    bpy.data.materials.remove(rest_material)
    if bpy.context.window and previous: bpy.context.window.scene=previous
