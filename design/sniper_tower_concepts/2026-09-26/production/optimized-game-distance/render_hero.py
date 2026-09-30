"""Source-scale hero check only; actual game-camera comparison is rendered in Godot."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
s=bpy.context.scene
s.cycles.samples=24
s.render.filepath=str(OUT/'sniper-swift-optimized-hero.png')
bpy.ops.render.render(write_still=True)
