"""Render only the approved SWIFT sniper with the shared fixed-camera recipe.

Run: Blender --background --python design/hud_turret_icons_fixed/render_sniper_swift.py
The shared six-scene source, other PNGs and both game/approved GLBs are read-only.
"""
import ast
from pathlib import Path

WORK = Path(__file__).resolve().parent
recipe = ast.parse((WORK / 'render_icons.py').read_text())
# Reuse the exact camera, lighting, orientation and scale from the common recipe.
# Execute only imports/setup and its one-turret loop; never its factory reset or
# six-scene save. A separate editable scene follows the frost-only update pattern.
namespace = {'__file__': str(WORK / 'render_icons.py')}
for statement in recipe.body:
    if isinstance(statement, ast.For):
        for assignment in statement.body:
            if isinstance(assignment, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'source' for t in assignment.targets):
                assignment.value = ast.parse("ROOT/'design/sniper_tower_concepts/2026-09-26/production/optimized-game-distance/sniper-swift-optimized.glb'", mode='eval').body
        # Preserve model scale and viewpoint. The approved long barrel needs a
        # minimally wider frustum; fit real vertices with eight pixels of margin.
        fit = ast.parse("""
points = [world_to_camera_view(scene, camera, o.matrix_world @ v.co) for o in objects if o.type == 'MESH' for v in o.data.vertices]
extent = max(max(abs(p.x-.5), abs(p.y-.5)) for p in points)
cam_data.ortho_scale = math.ceil(1.45 * extent / (.5 - 8/256) * 10000) / 10000
""").body
        index = next(i for i, node in enumerate(statement.body) if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'origin' for t in node.targets))
        statement.body[index:index] = fit
        namespace['KINDS'] = ['sniper']
        exec(compile(ast.fix_missing_locations(ast.Module(body=[statement], type_ignores=[])), str(WORK / 'render_icons.py'), 'exec'), namespace)
        break
    if isinstance(statement, (ast.Import, ast.ImportFrom, ast.Assign)):
        exec(compile(ast.Module(body=[statement], type_ignores=[]), str(WORK / 'render_icons.py'), 'exec'), namespace)

bpy = namespace['bpy']
scene = namespace['scene']
record = namespace['records']['sniper']
record['triangles'] = sum(len(o.data.polygons) if all(len(p.vertices) == 3 for p in o.data.polygons) else sum(len(p.vertices)-2 for p in o.data.polygons) for o in namespace['objects'] if o.type == 'MESH')
coordinates = [namespace['world_to_camera_view'](scene, scene.camera, o.matrix_world @ v.co) for o in namespace['objects'] if o.type == 'MESH' for v in o.data.vertices]
record['vertex_bounds_uv'] = [min(p.x for p in coordinates), min(p.y for p in coordinates), max(p.x for p in coordinates), max(p.y for p in coordinates)]
record['standard_orthographic_scale'] = 1.45
record['fit_margin_pixels'] = 8
assert all(8/256 - .0001 <= v <= 1-8/256+.0001 for v in record['vertex_bounds_uv']), record['vertex_bounds_uv']
bpy.data.libraries.write(str(WORK / 'hud-sniper-swift.blend'), {scene}, fake_user=True, compress=True)
(WORK / 'sniper-swift-direction-verification.json').write_text(namespace['json'].dumps({'sniper':record}, indent=2)+'\n')
print('SWIFT_FIXED_ICON_DONE', record, flush=True)
