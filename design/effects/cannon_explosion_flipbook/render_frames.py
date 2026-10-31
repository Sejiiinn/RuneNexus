"""Re-render the baked explosion after a material change, without simulating again.

  Blender -b --python design/effects/cannon_explosion_flipbook/render_frames.py -- --out <dir> [--frames 6,10,16] [--samples 48]
Opens cannon_explosion_sim.blend (saved by build_sim.py after its bake) and rebuilds the volume material from build_sim.py.
"""
import argparse
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_sim  # noqa: E402  (main() only runs when build_sim.py is the script)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--frames", default="")
p.add_argument("--samples", type=int, default=48)
p.add_argument("--glow", default="", help="frame:strength pairs, e.g. 1:30,8:26,13:12")
p.add_argument("--thin-fire", type=float, default=0.85)
p.add_argument("--bounces", type=int, default=build_sim.VOLUME_BOUNCES)
a = p.parse_args(argv)

bpy.ops.wm.open_mainfile(filepath=str(HERE / "cannon_explosion_sim.blend"))
scene = bpy.context.scene
domain = bpy.data.objects["Domain"]
domain.data.materials.clear()
keys = tuple((int(k), float(v)) for k, v in (pair.split(":") for pair in a.glow.split(","))) if a.glow else build_sim.GLOW_KEYS
build_sim.domain_material(domain, keys, a.thin_fire)
scene.cycles.samples = a.samples
scene.cycles.volume_bounces = a.bounces
scene.view_settings.view_transform = "Standard"
frames = [int(f) for f in a.frames.split(",")] if a.frames else range(scene.frame_start, scene.frame_end + 1)
for frame in frames:
    scene.frame_set(frame)
    scene.render.filepath = str(Path(a.out) / f"f{frame:04d}.png")
    bpy.ops.render.render(write_still=True)
print("RENDER_DONE", flush=True)
