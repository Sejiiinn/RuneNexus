import bpy
import sys
from pathlib import Path
scene = bpy.data.scenes['ImpactReview']
bpy.context.window.scene = scene
preferences = bpy.context.preferences.addons['cycles'].preferences
preferences.compute_device_type = 'METAL'
preferences.get_devices()
for device in preferences.devices:
    device.use = device.type == 'METAL'
scene.cycles.device = 'GPU'
root = Path(bpy.data.filepath).parent
(root / 'render').mkdir(exist_ok=True)
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
frames = [int(args[0])] if args else range(scene.frame_start, scene.frame_end + 1)
for frame in frames:
    scene.frame_set(frame)
    scene.render.filepath = str(root / 'render' / f'{frame:04d}.png')
    bpy.ops.render.render(write_still=True, scene=scene.name)
