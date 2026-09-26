"""Render the body without changing VFX sources or game assets."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
s=bpy.context.scene;s.cycles.samples=32
s.render.resolution_x=1200;s.render.resolution_y=1200;s.render.resolution_percentage=100
s.render.filepath=str(OUT/'runic-fire-optimized-hero.png')
bpy.ops.render.render(write_still=True)
