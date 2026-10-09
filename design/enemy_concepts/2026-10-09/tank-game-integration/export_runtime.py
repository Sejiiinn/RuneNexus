"""Export approved tank Walk and rigid rubble Death without altering the .blend.

Run using the project's guarded background Blender. SOURCE overrides are accepted
only for a byte-identical copy; game assets go to the repository's existing paths.
The source uses Y-up/+Z-front already, so export_yup=False preserves its axes.
"""
from pathlib import Path
import hashlib
import json
import os
import struct
import bpy

ROOT = Path(__file__).resolve().parents[4]
SOURCE = Path(os.environ.get('TANK_APPROVED_SOURCE', '/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/tank-shoulder-03-multiview-20261008-512/rigging/death-rubble-v4-optimized/blender/tank-shoulder03-death-rubble-optimized-v4.blend'))
SOURCE_SHA256 = '81a1d5008a7a909b0ca3f58c975cb3d39b8abced2693320210d02f0db8bb2ab4'
ASSETS = ROOT / 'assets/images/stage1_3d/enemies'
# Existing tank's actual rest-skinned height. Preserve its established display
# height instead of normalizing to the newly approved, wider shoulder silhouette.
GAME_REST_HEIGHT = 1.37216152
SOURCE_HEAD_TOP = 0.3853047490119934
SOURCE_FLOOR = -0.42562058568000793
SOURCE_STRIDE = 0.2032258064516129
MODEL_SCALE = GAME_REST_HEIGHT / (SOURCE_HEAD_TOP - SOURCE_FLOOR)
CHUNKS = ['Head', 'Chest.L', 'Chest.R', 'Foot.L', 'Foot.R', 'Forearm.L',
          'Forearm.R', 'Pelvis', 'Thigh.L', 'Thigh.R', 'UpperArm.L', 'UpperArm.R']


def inspect_glb(path, clip, triangle_count, mesh_count):
    data = path.read_bytes()
    assert data[:4] == b'glTF'
    length = struct.unpack_from('<I', data, 12)[0]
    document = json.loads(data[20:20 + length])
    assert [a['name'] for a in document['animations']] == [clip]
    assert len(document['meshes']) == mesh_count
    triangles = sum(document['accessors'][p['indices']]['count'] // 3
                    for mesh in document['meshes'] for p in mesh['primitives'])
    assert triangles == triangle_count, (clip, triangles)
    duration = max(document['accessors'][s['input']]['max'][0]
                   for s in document['animations'][0]['samplers'])
    assert abs(duration - (2.0 if clip == 'Walk' else 2.5)) < 1e-6
    if clip == 'Walk':
        assert len(document['skins']) == 1
        assert len(document['skins'][0]['joints']) == 14
    else:
        assert not document.get('skins')
        assert sorted(n['name'] for n in document['nodes'] if 'mesh' in n) == sorted('DeathStone_' + c for c in CHUNKS)
    return {'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(data).hexdigest(),
            'bytes': len(data), 'clip': clip, 'seconds': duration, 'triangles': triangles,
            'meshes': mesh_count, 'materials': [m['name'] for m in document['materials']],
            'embedded_images': len(document.get('images', []))}


def export(scene_name, clip, end_frame, triangle_count, mesh_count):
    # Reopen pristine input for each export; shared scene objects cannot leak
    # normalization or parent changes from Walk into the Death export.
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes[scene_name]
    bpy.context.window.scene = scene
    scene.frame_start = 1
    scene.frame_end = end_frame
    scene.frame_set(1)
    if clip == 'Walk':
        objects = [scene.objects['TankShoulder03_Rig'], scene.objects['TankShoulder03_Surface']]
    else:
        objects = [scene.objects['DeathStone_' + c] for c in CHUNKS]
        # The preview's 60 frame timeline is 2.5 seconds. Preserve keys 1..60
        # and append the already settled pose at frame 61 for the glTF endpoint.
        scene.frame_set(61)
        for obj in objects:
            for channel in ['location', 'rotation_euler']:
                obj.keyframe_insert(data_path=channel, frame=61)
        scene.frame_set(1)
    wrapper = bpy.data.objects.new('Tank_Game_Coordinates', None)
    scene.collection.objects.link(wrapper)
    wrapper.scale = (MODEL_SCALE,) * 3
    wrapper.location.y = -SOURCE_FLOOR * MODEL_SCALE
    wrapper['source_up_axis'] = '+Y'
    wrapper['source_front_axis'] = '+Z'
    wrapper['source_floor'] = SOURCE_FLOOR
    wrapper['source_to_game_uniform_scale'] = MODEL_SCALE
    wrapper['walk_stride_model_units'] = SOURCE_STRIDE
    wrapper['approved_source_sha256'] = SOURCE_SHA256
    for obj in objects:
        if obj.parent is None:
            obj.parent = wrapper
        obj.hide_render = False
        obj.hide_set(False)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects + [wrapper]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = ASSETS / ('tank.glb' if clip == 'Walk' else 'tank_death.glb')
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB', use_selection=True,
        use_active_scene=True, export_yup=False, export_materials='EXPORT',
        export_normals=True, export_tangents=True, export_animations=True,
        export_animation_mode='ACTIVE_ACTIONS', export_nla_strips_merged_animation_name=clip,
        export_frame_range=True, export_force_sampling=True, export_frame_step=1,
        export_anim_slide_to_zero=True,
        export_cameras=False, export_lights=False, export_extras=True,
        export_skins=(clip == 'Walk'), export_def_bones=False, export_morph=False,
        export_optimize_animation_size=False)
    return inspect_glb(path, clip, triangle_count, mesh_count)


assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == SOURCE_SHA256, 'Approved source differs'
ASSETS.mkdir(parents=True, exist_ok=True)
results = [export('01_Walk_Source_v2', 'Walk', 49, 11933, 1),
           export('02_Death_Rubble_Natural_v2', 'Death', 61, 16118, 12)]
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == SOURCE_SHA256, 'Source changed'
print('TANK_RUNTIME_EXPORT ' + json.dumps({'source': str(SOURCE),
      'source_sha256': SOURCE_SHA256, 'source_floor': SOURCE_FLOOR,
      'uniform_scale': MODEL_SCALE, 'normalized_stride': SOURCE_STRIDE * MODEL_SCALE,
      'game_stride_tiles': SOURCE_STRIDE * MODEL_SCALE * 0.55 * 1.15,
      'assets': results}, ensure_ascii=False))
