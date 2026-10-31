"""Pack rendered explosion frames into one flipbook sheet.

  python pack_sheet.py <render dir> <out.png> [--first 1] [--count 64] [--grid 8] [--cell 256]
Frames keep their position in each cell (no crop or re-centring), so the animation does not jitter.
"""
import argparse
from pathlib import Path

from PIL import Image

p = argparse.ArgumentParser()
p.add_argument("render"); p.add_argument("out")
p.add_argument("--first", type=int, default=1); p.add_argument("--count", type=int, default=64)
p.add_argument("--grid", type=int, default=8); p.add_argument("--cell", type=int, default=256)
a = p.parse_args()
sheet = Image.new("RGBA", (a.grid * a.cell, a.grid * a.cell), (0, 0, 0, 0))
for i in range(a.count):
    frame = Image.open(Path(a.render) / f"f{a.first + i:04d}.png").convert("RGBA").resize((a.cell, a.cell), Image.LANCZOS)
    sheet.paste(frame, ((i % a.grid) * a.cell, (i // a.grid) * a.cell))
sheet.save(a.out)
print(a.out, sheet.size)
