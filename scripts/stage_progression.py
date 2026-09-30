"""Read fixed-ID progression order from its Godot authority; never duplicate it."""
import ast
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def stage_ordinals(root: Path = ROOT) -> dict[int, int]:
    source = (root / "godot/content/stage_progression.gd").read_text(encoding="utf-8")
    orders = re.findall(r"^const ORDER\s*:=\s*(\[[^\]\n]+\])\s*$", source, re.MULTILINE)
    if len(orders) != 1:
        raise ValueError("stage_progression.gd requires one literal ORDER")
    order = ast.literal_eval(orders[0])
    if (any(type(stage_id) is not int for stage_id in order)
            or len(order) != 25 or set(order) != set(range(1, 26))):
        raise ValueError("Progression ORDER must contain each fixed stage ID 1..25 once")
    return {stage_id: ordinal for ordinal, stage_id in enumerate(order, 1)}
