"""Blender background: preserve approved native source, resize whole assembly to 90%."""
import bpy, json, hashlib
from bpy_extras.object_utils import world_to_camera_view
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
WORK = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(WORK.parent / 'migration/runic-native-export.blend'))
root = bpy.data.objects['turret_root']
assert tuple(root.scale) == (1.0, 1.0, 1.0)
def vertices():
    bpy.context.view_layer.update()
    return [o.matrix_world @ v.co for o in bpy.context.scene.objects if o.type == 'MESH' for v in o.data.vertices]
before = vertices()
root.scale *= .9
after = vertices()
error = max((a - b * .9).length for a, b in zip(after, before))
assert error < 1e-6, error
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'assets/images/stage1_3d/turrets/magic.glb'), export_format='GLB', use_selection=True, use_active_scene=True, export_apply=True, export_normals=True, export_texcoords=True, export_tangents=True, export_animations=False, export_cameras=False, export_lights=False, export_extras=True)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK / 'runic-native-90.blend'))
report = {'linear_scale': .9, 'vertices_checked': len(after), 'max_position_error': error,
          'muzzle': list(bpy.data.objects['muzzle'].matrix_world.translation),
          'upper_flame_port': list(bpy.data.objects['upper_flame_port'].matrix_world.translation)}
(WORK / 'geometry.json').write_text(json.dumps(report, indent=2))
# Keep the exact approved icon camera, lights, framing, materials and other five scenes.
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'design/hud_turret_icons_fixed/fixed-camera-turret-icons.blend'))
scene = bpy.data.scenes['HUD_magic']
bpy.context.window.scene = scene
icon_root = next(o for o in scene.objects if o.name == 'magic_turret_root')
icon_root.scale = Vector((.9, .9, .9))
scene.render.filepath = str(ROOT / 'assets/images/ui/hud/turrets_3d/magic.png')
bpy.context.view_layer.update()
coords = [world_to_camera_view(scene, scene.camera, o.matrix_world @ Vector(c)) for o in scene.objects if o.type == 'MESH' for c in o.bound_box]
record_path = ROOT / 'design/hud_turret_icons_fixed/direction-verification.json'
records = json.loads(record_path.read_text())
records['magic']['sha256'] = hashlib.sha256((ROOT / 'assets/images/stage1_3d/turrets/magic.glb').read_bytes()).hexdigest()
records['magic']['bounds_uv'] = [min(c.x for c in coords), min(c.y for c in coords), max(c.x for c in coords), max(c.y for c in coords)]
records['magic']['model_scale'] = .9
physical = scene.objects['magic_muzzle'].matrix_world.translation - scene.objects['magic_turret_head'].matrix_world.translation
physical.z = 0
records['magic']['muzzle_horizontal_blender'] = list(physical)
record_path.write_text(json.dumps(records, indent=2))
bpy.ops.render.render(write_still=True)
bpy.context.window.scene = bpy.data.scenes['HUD_arrow']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'design/hud_turret_icons_fixed/fixed-camera-turret-icons.blend'))
print('FIRE_SCALE_90_PASS', report)
