#!/usr/bin/env python3
"""Validate the checked-in Godot content and regression fixtures without Dart."""
from __future__ import annotations

import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def read(relative: str):
    path = ROOT / relative
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs,
                      parse_constant=lambda value: (_ for _ in ()).throw(
                          ValueError(f"Non-finite JSON value: {value}")))


def verify() -> None:
    game = read("godot/content/game_content.json")
    growth = read("godot/content/growth_content.json")
    game_cases = read("test/fixtures/game_content_cases.json")
    growth_cases = read("test/fixtures/growth_cases.json")
    growth_game_cases = read("test/fixtures/growth_game_cases.json")
    progression_cases = read("test/fixtures/growth_progression_cases.json")
    for name, data in (("game content", game), ("growth content", growth),
                       ("growth cases", growth_cases), ("growth game cases", growth_game_cases),
                       ("growth progression cases", progression_cases)):
        if data.get("schemaVersion") != 1:
            raise ValueError(f"{name}: unsupported schemaVersion")
    enemies, turrets = set(game["enemies"]), set(game["turrets"])
    if enemies != set(game["enemyDefinitions"]) or not enemies or not turrets:
        raise ValueError("Enemy/turret definitions are incomplete")
    stages = game["stages"]
    if not stages or [stage["id"] for stage in stages] != list(range(1, len(stages) + 1)):
        raise ValueError("Stage IDs must be contiguous from 1")
    for stage in stages:
        game_map = stage["map"]
        columns, rows = game_map["columns"], game_map["rows"]
        if columns <= 0 or rows <= 0 or len(game_map["tiles"]) != columns * rows:
            raise ValueError(f"Stage {stage['id']} tile count mismatch")
        if not game_map["path"] or any(
            len(point) != 2 or not 0 <= point[0] < columns or not 0 <= point[1] < rows
            for point in game_map["path"]
        ):
            raise ValueError(f"Stage {stage['id']} path invalid")
        for wave in stage["waves"]:
            for entry in wave["groups"] + wave["spawnQueue"]:
                if entry["enemyType"] not in enemies:
                    raise ValueError(f"Stage {stage['id']} refers to unknown enemy")
            if set(wave["enemyDurability"]) != enemies:
                raise ValueError(f"Stage {stage['id']} durability coverage differs")
    if not game_cases["enemies"] or not game_cases["turrets"]:
        raise ValueError("Combat fixture cases are empty")
    if any(case["enemyType"] not in enemies for case in game_cases["enemies"]):
        raise ValueError("Enemy fixture refers to unknown content")
    if growth_game_cases["coreConfig"] != growth["coreConfig"]:
        raise ValueError("Growth fixture coreConfig differs from canonical content")
    if not growth_cases["cases"] or not progression_cases["cases"]:
        raise ValueError("Growth fixture cases are empty")
    for name, data in (("game", game), ("growth", growth)):
        def numbers(value):
            if isinstance(value, dict):
                for child in value.values(): numbers(child)
            elif isinstance(value, list):
                for child in value: numbers(child)
            elif isinstance(value, float) and not math.isfinite(value):
                raise ValueError(f"{name} has non-finite number")
        numbers(data)
    print(f"PASS Godot content: {len(stages)} stages, {len(enemies)} enemies, "
          f"{len(turrets)} turrets, checked-in growth and combat fixtures")


if __name__ == "__main__":
    try:
        verify()
    except (OSError, KeyError, TypeError, ValueError) as error:
        sys.exit(str(error))
