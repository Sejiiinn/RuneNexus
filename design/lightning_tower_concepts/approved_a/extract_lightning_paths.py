"""Extract approved Blender curve paths, preserving the spatial forks and tapers.

Run with Blender --background --python this_file.py. Conversion only; original
source is read without saving. Bake the resulting data with bake_lightning.gd.
"""
import bpy
import json
from pathlib import Path
from mathutils import Vector

DEST = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(DEST / 'lightning-A-approved.blend'))

def godot(p):
    return Vector((p[0], p[2], -p[1]))

def rounded(p):
    return [round(v, 7) for v in p]

def basis(direction):
    z = direction.normalized()
    x = Vector((0, 1, 0)).cross(z).normalized()
    y = z.cross(x).normalized()
    return x, y, z

def project(p, axes):
    return Vector(tuple(p.dot(axis) for axis in axes))

def paths(ob, normalize=False, skin_width=None, group=0):
    result = []
    for spline in ob.data.splines:
        points = [godot(p.co) for p in spline.points]
        anchor = [0.0] * len(points)
        if normalize:
            start = points[0]
            delta = points[-1] - start
            axes = basis(delta)
            length = delta.length
            points = [project(p - start, axes) for p in points]
            anchor = [p.z / length for p in points]
            for p, t in zip(points, anchor):
                p.z = t
        result.append(dict(points=[rounded(p) for p in points],
            radii=[round(p.radius, 7) for p in spline.points],
            core=round(ob.data.bevel_depth, 7), skin=skin_width,
            group=group, anchor=anchor))
    return result

data = {'source': 'lightning-A-attack-editable.blend / approved aura v3', 'charge': [], 'beam': [], 'feed': [], 'impact': []}
for phase in range(4):
    bank = []
    for group in range(3):
        core = bpy.data.objects[f'CHARGE | depth {group} | phase {phase} | core']
        skin = bpy.data.objects[f'CHARGE | depth {group} | phase {phase} | skin']
        bank += paths(core, skin_width=skin.data.bevel_depth, group=group)
    data['charge'].append(bank)
    core = bpy.data.objects[f'FEED | {phase} | core']
    skin = bpy.data.objects[f'FEED | {phase} | skin']
    # Each authored electrode contributes two separate currents. Normalizing
    # preserves its authored crooks while allowing real game muzzle positions.
    data['feed'].append(paths(core, normalize=True, skin_width=skin.data.bevel_depth, group=1)[:2])

# All release branches use the same axis/length as the main path. Only their
# longitudinal anchor stretches, so actual tube width and lateral forks stay.
for phase in range(6):
    main = bpy.data.objects[f'RELEASE | phase {phase} | branch 0 | core']
    main_points = main.data.splines[0].points
    start = godot(main_points[0].co)
    delta = godot(main_points[-1].co) - start
    axes = basis(delta)
    bank = []
    for group in range(3):
        core = bpy.data.objects[f'RELEASE | phase {phase} | branch {group} | core']
        skin = bpy.data.objects[f'RELEASE | phase {phase} | branch {group} | skin']
        for path in paths(core, skin_width=skin.data.bevel_depth, group=group):
            pts = [project(Vector(p) - start, axes) for p in path['points']]
            path['anchor'] = [p.z / delta.length for p in pts]
            for p, t in zip(pts, path['anchor']):
                p.z = t
            path['points'] = [rounded(p) for p in pts]
            bank.append(path)
    data['beam'].append(bank)
for i in range(7):
    data['impact'] += paths(bpy.data.objects[f'IMPACT | spatial fork {i}'], skin_width=0.009, group=0)

(DEST / 'lightning_paths.json').write_text(json.dumps(data, separators=(',', ':')))
print('LIGHTNING_PATHS_EXTRACTED', len(data['charge']), len(data['beam']), len(data['feed']))
