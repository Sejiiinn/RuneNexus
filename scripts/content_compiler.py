#!/usr/bin/env python3
"""Compile editable content sources to the committed, typed Godot catalog.

No generated catalog or design export is an input. Historical float corrections
are sparse ULP differences guarded by the calculation that originally made them.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
import re
import struct
import sys

from stage_progression import stage_ordinals
from content_runtime_format import encode_runtime, runtime_text, typed_digest

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("maxHp", "maxShield", "maxArmor")
FORMULA = "ordinal-v1"


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs,
                      parse_constant=lambda value: (_ for _ in ()).throw(
                          ValueError(f"Non-finite JSON value: {value}")))


def record_json(value) -> str:
    """One small numeric record per line; keep nested domains easy to inspect."""
    def render(item, depth=0):
        prefix = "  " * depth
        if isinstance(item, dict):
            if not item or all(not isinstance(child, (dict, list)) for child in item.values()):
                return json.dumps(item, ensure_ascii=False, allow_nan=False)
            rows = [json.dumps(key, ensure_ascii=False) + ": " + render(child, depth + 1)
                    for key, child in item.items()]
            return "{\n" + ",\n".join("  " + prefix + row for row in rows) + "\n" + prefix + "}"
        if isinstance(item, list):
            if not item or (len(item) <= 12 and all(not isinstance(child, (dict, list)) for child in item)):
                return json.dumps(item, ensure_ascii=False, allow_nan=False)
            return "[\n" + ",\n".join("  " + prefix + render(child, depth + 1) for child in item) + "\n" + prefix + "]"
        return json.dumps(item, ensure_ascii=False, allow_nan=False)
    return render(value) + "\n"


def apply_ulps(value: float, delta: int) -> float:
    if type(value) is not float or not math.isfinite(value) or value < 0:
        raise ValueError("ULP compatibility requires a finite nonnegative float")
    if type(delta) is not int or not -4 <= delta <= 4 or delta == 0:
        raise ValueError("Invalid sparse ULP correction")
    bits = struct.unpack(">Q", struct.pack(">d", value))[0] + delta
    if not 0 <= bits <= 0x7fefffffffffffff:
        raise ValueError("ULP correction outside nonnegative finite range")
    return struct.unpack(">d", struct.pack(">Q", bits))[0]


def queue_for(groups: list, precision: int | None = None) -> list:
    if precision is not None and (type(precision) is not int or precision != 9):
        raise ValueError("queuePrecision must be null or 9")
    events = []
    previous_end = 0.0
    for group in groups:
        if not isinstance(group, dict) or not {"enemyType", "count", "interval", "startDelay"} <= group.keys():
            raise ValueError("Incomplete spawn group")
        if (set(group) - {"enemyType", "count", "interval", "startDelay", "startAfterPrevious", "followDelay"}
                or ("startAfterPrevious" in group and type(group["startAfterPrevious"]) is not bool)):
            raise ValueError("Invalid spawn group fields")
        if (type(group["count"]) is not int or group["count"] <= 0
                or type(group["interval"]) is not float or not math.isfinite(group["interval"]) or group["interval"] <= 0
                or type(group["startDelay"]) is not float or not math.isfinite(group["startDelay"]) or group["startDelay"] < 0):
            raise ValueError("Invalid spawn group numeric types/values")
        start = group["startDelay"]
        if group.get("startAfterPrevious", False):
            follow = group.get("followDelay")
            if type(follow) is not float or not math.isfinite(follow) or follow < 0:
                raise ValueError("Invalid relative group followDelay")
            start = previous_end + follow
        previous_end = start + (group["count"] - 1) * group["interval"]
        events.extend((start + index * group["interval"], group["enemyType"])
                      for index in range(group["count"]))
    # Stable sort: equal timestamps keep original group and member order.
    events.sort(key=lambda event: event[0])
    previous = -0.18
    queue = []
    for requested, kind in events:
        actual = max(requested, previous + 0.18)
        if precision is not None:
            actual = round(actual, precision)
        if not math.isfinite(actual):
            raise ValueError("Non-finite spawn time")
        queue.append({"enemyType": kind, "delay": actual})
        previous = actual
    return queue


def durability_for(definition, round_number, ordinal, order="factor-first"):
    if order not in ("factor-first", "base-round-stage"):
        raise ValueError("Unknown durability multiplication order")
    round_factor = 2 ** ((round_number - 1) / 10)
    stage_factor = 1.15 ** (ordinal - 1)
    values = {}
    for field in FIELDS:
        base = definition[field]
        if type(base) not in (int, float) or not math.isfinite(base) or base < 0:
            raise ValueError(f"Invalid enemy base durability: {field}")
        values[field] = float(base * (round_factor * stage_factor) if order == "factor-first"
                              else (base * round_factor) * stage_factor)
    return values


def queue_inputs_digest(groups, precision):
    return typed_digest({"normalization": "stable-0.18-v1", "groups": groups, "precision": precision})


def load_sources(root: Path = ROOT):
    source = root / "godot/content/source"
    settings = read_json(source / "settings.json")
    if (not isinstance(settings, dict) or type(settings.get("sourceSchemaVersion")) is not int
            or settings.get("sourceSchemaVersion") != 1 or settings.get("durabilityFormula") != FORMULA
            or not isinstance(settings.get("catalog"), dict)):
        raise ValueError("Unsupported source schema/durability formula")
    definitions = read_json(source / "enemies.json")
    turrets = read_json(source / "turrets.json")
    if (not isinstance(definitions, dict) or not isinstance(definitions.get("enemyDefinitions"), dict)
            or not isinstance(definitions.get("enemies"), dict) or not isinstance(turrets, dict)):
        raise ValueError("Invalid enemy/turret source sections")
    ordinals = stage_ordinals(root)
    expected = {f"{stage_id:03}.json" for stage_id in ordinals}
    actual = {path.name for path in (source / "stages").glob("*.json")}
    if actual != expected:
        raise ValueError(f"Stage source inventory differs: missing={sorted(expected-actual)}, extra={sorted(actual-expected)}")
    stages = [read_json(source / "stages" / f"{stage_id:03}.json") for stage_id in sorted(ordinals)]
    if (any(not isinstance(stage, dict) or type(stage.get("id")) is not int for stage in stages)
            or [stage.get("id") for stage in stages] != sorted(ordinals)):
        raise ValueError("Stage source file names and fixed IDs differ")
    return settings, definitions, turrets, stages, ordinals


def validate_map(map_data: dict):
    columns, rows = map_data.get("columns"), map_data.get("rows")
    tiles, path = map_data.get("tiles"), map_data.get("path")
    if (type(columns) is not int or type(rows) is not int or columns <= 0 or rows <= 0
            or not isinstance(tiles, list) or len(tiles) != columns * rows
            or any(tile not in ("blocked", "build", "path", "spawn", "core") for tile in tiles)
            or not isinstance(path, list) or len(path) < 2):
        raise ValueError("Invalid map dimensions/tiles/path")
    def valid_point(point):
        return (isinstance(point, list) and len(point) == 2
                and all(type(v) is int for v in point)
                and 0 <= point[0] < columns and 0 <= point[1] < rows)
    if any(not valid_point(point) for point in path):
        raise ValueError("Invalid map path coordinates")
    pairs = map_data.get("teleportPairs", [])
    if not isinstance(pairs, list):
        raise ValueError("teleportPairs must be an array")
    colors, occupied, jumps = set(), set(), {}
    for pair in pairs:
        if not isinstance(pair, dict) or pair.get("color") not in ("blue", "orange") or pair["color"] in colors:
            raise ValueError("Invalid/duplicate teleport color")
        colors.add(pair["color"])
        indices = []
        for role in ("entrance", "exit"):
            point = pair.get(role)
            if (not valid_point(point) or tiles[point[1] * columns + point[0]] != "path"
                    or path.count(point) != 1):
                raise ValueError("Invalid teleport endpoint")
            index = path.index(point)
            if index in occupied:
                raise ValueError("Overlapping teleport endpoints")
            occupied.add(index)
            indices.append(index)
        if indices[0] >= indices[1]:
            raise ValueError("Teleport entrance must precede exit")
        jumps[indices[0]] = indices[1]
    for index, (start, end) in enumerate(zip(path, path[1:])):
        if abs(start[0] - end[0]) + abs(start[1] - end[1]) != 1 and jumps.get(index) != index + 1:
            raise ValueError("Disconnected path must be a registered teleport jump")


def validate_preview(text: str, groups: list, stage_id: int, round_number: int):
    """Reject explicit composition claims that the validated spawn groups cannot meet.

    Tactical prose stays authored; this is not a general natural-language parser.
    Keep these terms aligned with the Korean enemy names used in wave previews.
    """
    context = f"Stage {stage_id} round {round_number} preview"
    if not text.strip():
        raise ValueError(f"{context} must not be empty")
    kinds = {group["enemyType"] for group in groups}
    requirements = (
        (("일반",), {"normal"}),
        (("빠른 적", "빠름", "고속"), {"fast"}),
        (("탱커",), {"tank"}),
        (("보호막병",), {"shielded"}),
        (("보호막", "차폐"), {"shielded", "shieldBoss"}),
        (("장갑병",), {"armored"}),
        (("장갑",), {"armored", "forgeBoss"}),
        (("보스",), {"boss", "shieldBoss", "forgeBoss"}),
        (("보호막 보스", "방벽체"), {"shieldBoss"}),
        (("파쇄자",), {"forgeBoss"}),
    )
    for terms, required in requirements:
        for term in terms:
            if term in text and not kinds & required:
                raise ValueError(f"{context} mentions {term!r} without a matching enemy")
    if "혼합" in text and len(kinds) < 2:
        raise ValueError(f"{context} says 혼합 but has fewer than two enemy types")


def compile_content(root: Path = ROOT) -> dict:
    settings, definitions, turrets, sources, ordinals = load_sources(root)
    game = copy.deepcopy(settings["catalog"])
    game["enemyDefinitions"] = copy.deepcopy(definitions["enemyDefinitions"])
    game["enemies"] = copy.deepcopy(definitions["enemies"])
    game["turrets"] = copy.deepcopy(turrets)
    enemy_kinds = set(game["enemies"])
    if enemy_kinds != set(game["enemyDefinitions"]) or not enemy_kinds:
        raise ValueError("Enemy template/base definition inventory differs")
    game["stages"] = []
    for source in sources:
        if not {"id", "name", "firstClearCorePointReward", "firstClearTurretModuleTicketReward", "map", "waves"} <= source.keys():
            raise ValueError("Incomplete stage source")
        if set(source) - {"id", "name", "firstClearCorePointReward", "firstClearTurretModuleTicketReward", "map", "waves", "design"}:
            raise ValueError("Unknown stage source fields")
        stage = {key: copy.deepcopy(source[key]) for key in ("id", "name", "firstClearCorePointReward", "firstClearTurretModuleTicketReward", "map")}
        for field in ("firstClearCorePointReward", "firstClearTurretModuleTicketReward"):
            if type(stage[field]) is not int or stage[field] < 0:
                raise ValueError("First-clear reward must be a nonnegative integer")
        if not isinstance(stage["name"], str):
            raise ValueError("Stage name must be a string")
        validate_map(stage["map"])
        if (not isinstance(source["waves"], list)
                or any(not isinstance(wave, dict) or type(wave.get("round")) is not int for wave in source["waves"])
                or [wave.get("round") for wave in source["waves"]] != list(range(1, 41))):
            raise ValueError(f"Stage {stage['id']} requires rounds 1..40")
        stage["waves"] = []
        for source_wave in source["waves"]:
            if not {"round", "previewText", "clearRewardGold", "groups"} <= source_wave.keys():
                raise ValueError("Incomplete wave source")
            if set(source_wave) - {"round", "previewText", "clearRewardGold", "groups", "queuePrecision", "durabilityOrder", "compatibility", "design"}:
                raise ValueError("Unknown/derived fields must not be stored in wave source")
            wave = {key: copy.deepcopy(source_wave[key]) for key in ("round", "previewText", "clearRewardGold", "groups")}
            if (type(wave["clearRewardGold"]) is not int or wave["clearRewardGold"] < 0
                    or not isinstance(wave["previewText"], str) or not isinstance(wave["groups"], list)):
                raise ValueError("Invalid wave reward/preview/groups")
            precision = source_wave.get("queuePrecision")
            wave["spawnQueue"] = queue_for(wave["groups"], precision)
            if any(group["enemyType"] not in enemy_kinds for group in wave["groups"]):
                raise ValueError("Unknown enemy in spawn group")
            validate_preview(wave["previewText"], wave["groups"], stage["id"], wave["round"])
            compatibility = source_wave.get("compatibility", {})
            if (not isinstance(compatibility, dict)
                    or set(compatibility) - {"queueInputsDigest", "spawnDelayUlps", "durabilityUlps"}):
                raise ValueError("Invalid compatibility fields")
            queue_compat = compatibility.get("spawnDelayUlps", {})
            digest = queue_inputs_digest(wave["groups"], precision)
            if not isinstance(queue_compat, dict):
                raise ValueError("Spawn corrections must be an object")
            if queue_compat and (not isinstance(compatibility.get("queueInputsDigest"), str)
                                 or not re.fullmatch(r"[0-9a-f]{64}", compatibility["queueInputsDigest"])):
                raise ValueError("Missing/invalid queue compatibility guard")
            for index, delta in queue_compat.items():
                if not index.isdigit() or str(int(index)) != index:
                    raise ValueError("Invalid spawn correction index")
                if int(index) >= len(wave["spawnQueue"]):
                    # A changed schedule may legitimately contain fewer spawns.
                    if compatibility.get("queueInputsDigest") == digest:
                        raise ValueError("Invalid spawn correction index")
                apply_ulps(0.18, delta)  # Validate even inactive compatibility records.
            if queue_compat and compatibility.get("queueInputsDigest") == digest:
                for index, delta in queue_compat.items():
                    entry = wave["spawnQueue"][int(index)]
                    entry["delay"] = apply_ulps(entry["delay"], delta)
            if any(a["delay"] > b["delay"] or b["delay"] - a["delay"] < 0.18 - 1e-8
                   for a, b in zip(wave["spawnQueue"], wave["spawnQueue"][1:])):
                raise ValueError("Spawn compatibility breaks normalized queue order")
            wave["enemyDurability"] = {}
            order = source_wave.get("durabilityOrder", "factor-first")
            overrides = compatibility.get("durabilityUlps", {})
            if not isinstance(overrides, dict):
                raise ValueError("Durability corrections must be an object")
            for key, correction in overrides.items():
                if (not re.fullmatch(r"[^.]+\.(maxHp|maxShield|maxArmor)", key)
                        or key.split(".")[0] not in enemy_kinds
                        or not isinstance(correction, list) or len(correction) != 2):
                    raise ValueError("Invalid durability correction")
                apply_ulps(correction[0], correction[1])
            for kind, definition in game["enemyDefinitions"].items():
                values = durability_for(definition, wave["round"], ordinals[stage["id"]], order)
                for field, actual in values.items():
                    correction = overrides.get(kind + "." + field)
                    if correction and actual.hex() == correction[0].hex():
                        values[field] = apply_ulps(actual, correction[1])
                wave["enemyDurability"][kind] = values
            stage["waves"].append(wave)
        game["stages"].append(stage)
    return game


def generated_text(root: Path = ROOT) -> str:
    return runtime_text(encode_runtime(compile_content(root)))


def check_generated(root: Path = ROOT) -> dict:
    game = compile_content(root)
    path = root / "godot/content/game_content.json"
    if not path.is_file() or path.read_text(encoding="utf-8") != runtime_text(encode_runtime(game)):
        raise ValueError("Missing/stale generated game_content.json; run python3 scripts/content_compiler.py")
    return game


def write_generated(root: Path = ROOT) -> dict:
    game = compile_content(root)
    (root / "godot/content/game_content.json").write_text(runtime_text(encode_runtime(game)), encoding="utf-8")
    return game


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="reject missing/stale output without writing")
    args = parser.parse_args()
    game = check_generated() if args.check else write_generated()
    print(f"PASS content compiler: {len(game['stages'])} stages; typed digest {typed_digest(game)}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, TypeError, ValueError) as error:
        sys.exit(str(error))
