#!/usr/bin/env python3
"""Build the 15-frame turret level badge atlas: draw every frame as SVG, let Godot rasterize it.

Geometry follows the retired TurretLevelRenderer.drawBadge. Frame colours walk gray, yellow, orange, red;
levels 11-15 keep the Lv.10 plaque and add stars and wider wings.
Usage: python3 design/stage1_3d/turret_level_labels/generator/export_turret_level_badges.py
"""
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from run_godot_project_checks import godot_executable

TARGET = ROOT / "assets/images/stage1_3d/ui/turret_levels.png"
FONT = ROOT / "assets/images/stage1_3d/ui/Roboto-VF.ttf"
LEVELS = 15
FRAME_WIDTH, FRAME_HEIGHT = 256, 144
TILE = 48.0
SCALE = FRAME_WIDTH / TILE
INK = "#050A12"
RAMP = ["#6F757C", "#8C9196", "#ABAAA0", "#CFC47E", "#EFD84E", "#FAD23A", "#FFC22F", "#FFAB28", "#FF9220", "#FF7A18",
        "#FB6418", "#F4501A", "#EA3E1C", "#DE2E1E", "#CF2020"]


def lerp(a, b, t):
    a, b = [int(a[i:i + 2], 16) for i in (1, 3, 5)], [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02X%02X%02X" % tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def tier(level):
    return 4 if level >= 10 else 3 if level >= 8 else 2 if level >= 5 else 1 if level >= 2 else 0


def star(cx, cy, radius):
    points = []
    for i in range(8):
        angle = -math.pi / 2 + i * math.pi / 4
        reach = radius if i % 2 == 0 else radius * .48
        points.append(f"{cx + math.cos(angle) * reach:.2f},{cy + math.sin(angle) * reach:.2f}")
    return " ".join(points)


def stars(level, cy):
    rows = [(0, cy, TILE * .055)]
    if level >= 13:
        rows[:0] = [(-TILE * .1, cy + TILE * .012, TILE * .036), (TILE * .1, cy + TILE * .012, TILE * .036)]
    if level >= 15:
        rows[:0] = [(-TILE * .19, cy + TILE * .022, TILE * .03), (TILE * .19, cy + TILE * .022, TILE * .03)]
    return rows


def wing_path(side, edge, level):
    """A short swept wing on the plaque side: two feathers, three from Lv.13."""
    reach = TILE * (.13 if level >= 13 else .1)
    x = lambda t: f"{side * (edge - 1 + (reach + 1) * t):.2f}"
    y = lambda t: f"{TILE * t:.2f}"
    path = f"M{x(0)} {y(-.07)}Q{x(.55)} {y(-.1)} {x(1)} {y(-.115)}Q{x(.86)} {y(-.05)} {x(.62)} {y(-.03)}Q{x(.72)} {y(-.022)} {x(.8)} {y(-.022)}"
    if level >= 13:
        path += f"Q{x(.66)} {y(.022)} {x(.42)} {y(.022)}Q{x(.5)} {y(.03)} {x(.58)} {y(.032)}"
        return path + f"Q{x(.32)} {y(.075)} {x(0)} {y(.07)}Z"
    return path + f"Q{x(.5)} {y(.052)} {x(0)} {y(.06)}Z"


def badge(level):
    frame = RAMP[level - 1]
    wing = lerp(frame, "#FFE7BE", .55)
    k = tier(level)
    w, h = TILE * (.54 if level >= 10 else .49), TILE * .21
    x, y, r = -w / 2, -h / 2, h * .34
    gradient = (f'<linearGradient id="g{level}" gradientUnits="userSpaceOnUse" x1="0" y1="{y:.2f}" x2="0" y2="{-y:.2f}">'
                f'<stop offset="0" stop-color="{lerp("#0A0E14", frame, .14)}"/><stop offset=".48" stop-color="#0A0E14"/>'
                '<stop offset="1" stop-color="#02050A"/></linearGradient>')
    s = [f'<rect x="{x - TILE*.016:.2f}" y="{y + TILE*.002:.2f}" width="{w + TILE*.032:.2f}" height="{h + TILE*.032:.2f}" rx="{r:.2f}" fill="#000000" fill-opacity=".69"/>']
    if level > 1:
        s.append(f'<rect x="{x - TILE*.012:.2f}" y="{y - TILE*.012:.2f}" width="{w + TILE*.024:.2f}" height="{h + TILE*.024:.2f}" rx="{r:.2f}" fill="none" stroke="{frame}" stroke-opacity="{.1 + k*.035:.3f}" stroke-width="{TILE*(.05 + k*.006):.2f}"/>')
    if k >= 4:
        for side in (-1, 1):
            path = wing_path(side, w / 2, level)
            s.append(f'<path d="{path}" transform="translate(0 {TILE*.014:.2f})" fill="{INK}" fill-opacity=".69"/>')
            s.append(f'<path d="{path}" fill="none" stroke="{frame}" stroke-opacity=".2" stroke-width="3"/>')
            s.append(f'<path d="{path}" fill="{wing}" stroke="{INK}" stroke-width="1.1" stroke-linejoin="round"/>')
    elif k >= 2:
        half = TILE * {2: .61, 3: .65}[k] / 2
        high, bevel = TILE * .055, TILE * .11 * .52
        path = f"M{-half:.2f} 0L{-half + bevel:.2f} {-high:.2f}L{half - bevel:.2f} {-high:.2f}L{half:.2f} 0L{half - bevel:.2f} {high:.2f}L{-half + bevel:.2f} {high:.2f}Z"
        s.append(f'<path d="{path}" transform="translate(0 {TILE*.014:.2f})" fill="{INK}" fill-opacity=".69"/>')
        s.append(f'<path d="{path}" fill="none" stroke="{frame}" stroke-opacity=".2" stroke-width="3"/>')
        s.append(f'<path d="{path}" fill="{wing}" stroke="{INK}" stroke-width="1.2"/>')
    s.append(f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" rx="{r:.2f}" fill="url(#g{level})" stroke="{frame}" stroke-width="{1 + k*.28:.2f}"/>')
    line, inset, width = w * (.17 if k >= 3 else .12), w * .13, 1.2 if k >= 3 else .9
    for x0, x1 in ((x + inset, x + inset + line), (-x - inset - line, -x - inset)):
        s.append(f'<path d="M{x0:.2f} {y:.2f}H{x1:.2f}" stroke="{lerp(frame, "#FFFFFF", .46)}" stroke-opacity=".7" stroke-width="{width}" stroke-linecap="round"/>')
        s.append(f'<path d="M{x0:.2f} {-y:.2f}H{x1:.2f}" stroke="{INK}" stroke-opacity=".88" stroke-width="{width}" stroke-linecap="round"/>')
    if k >= 3:
        d = TILE * .025
        s.append(f'<rect x="{x + d:.2f}" y="{y + d:.2f}" width="{w - 2*d:.2f}" height="{h - 2*d:.2f}" rx="{h*.22:.2f}" fill="none" stroke="{frame}" stroke-opacity=".46" stroke-width=".8"/>')
    if k >= 4:
        for cx, cy, radius in stars(level, y - TILE * .026):
            points = star(cx, cy, radius)
            s.append(f'<polygon points="{points}" transform="translate(0 {TILE*.01:.2f})" fill="{INK}" fill-opacity=".69"/>')
            s.append(f'<polygon points="{points}" fill="{lerp(frame, "#FFF0C8", .78)}" stroke="{INK}" stroke-width=".8"/>')
    elif level > 1:
        q, cy = TILE * (.035 if k >= 3 else .027), y - TILE * .012
        points = f"0,{cy - q:.2f} {q:.2f},{cy:.2f} 0,{cy + q:.2f} {-q:.2f},{cy:.2f}"
        s.append(f'<polygon points="{points}" transform="translate(0 {TILE*.008:.2f})" fill="{INK}" fill-opacity=".69"/>')
        s.append(f'<polygon points="{points}" fill="{frame}" stroke="{INK}" stroke-width=".7"/>')
    size = TILE * .125
    fill = "#F2F3F0" if level <= 1 else "#FFF6D6"
    s.append(f"<!--LABEL Lv.{level}|{size:.3f}|{size * .36 + .6:.3f}|#000000-->")
    s.append(f"<!--LABEL Lv.{level}|{size:.3f}|{size * .36:.3f}|{fill}-->")
    return gradient, "".join(s)


def main():
    gradients, frames = [], []
    for level in range(1, LEVELS + 1):
        gradient, body = badge(level)
        gradients.append(gradient)
        left = (level - 1) * FRAME_WIDTH + FRAME_WIDTH / 2
        frames.append(f'<g transform="translate({left} {FRAME_HEIGHT / 2}) scale({SCALE:.5f})">{body}</g>')
    width = LEVELS * FRAME_WIDTH
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{FRAME_HEIGHT}" viewBox="0 0 {width} {FRAME_HEIGHT}">'
           f'<defs>{"".join(gradients)}</defs>{"".join(frames)}</svg>')
    with tempfile.TemporaryDirectory() as temp:
        source = Path(temp) / "badges.svg"
        source.write_text(svg)
        (Path(temp) / "project.godot").write_text('config_version=5\n')
        env = {**os.environ, "BADGE_SVG": str(source), "BADGE_FONT": str(FONT), "BADGE_OUT": str(TARGET),
               "BADGE_FRAMES": str(LEVELS), "BADGE_FRAME_WIDTH": str(FRAME_WIDTH)}
        result = subprocess.run([godot_executable(), "--headless", "--path", temp, "--script", str(HERE / "rasterize_badges.gd")],
                                env=env, capture_output=True, text=True, timeout=120)
    print(result.stdout[-1500:])
    if result.returncode != 0 or "ATLAS OK" not in result.stdout:
        print(result.stderr[-1500:], file=sys.stderr)
        raise SystemExit("badge atlas failed")
    print(f"{TARGET} {TARGET.stat().st_size} bytes")


if __name__ == "__main__":
    main()
