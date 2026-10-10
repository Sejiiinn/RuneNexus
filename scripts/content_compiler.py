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
SCHEDULING_POLICY = {"version": 1, "scope": "global", "minimumInterval": 0.18,
                     "tieBreak": "source-group-member-order", "dispatchTimeBasis": "spawn-queue-seconds"}


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
    return schedule_for(groups, precision)[0]


def schedule_for(groups: list, precision: int | None = None):
    if precision is not None and (type(precision) is not int or precision != 9):
        raise ValueError("queuePrecision must be null or 9")
    events = []
    previous_end = 0.0
    group_indices = [[] for _ in groups]
    requested_starts, ids = [], set()
    for group_index, group in enumerate(groups):
        if not isinstance(group, dict) or not {"enemyType", "count", "interval", "startDelay"} <= group.keys():
            raise ValueError("Incomplete spawn group")
        if (set(group) - {"enemyType", "count", "interval", "startDelay", "startAfterPrevious", "followDelay", "routeId", "id"}
                or ("startAfterPrevious" in group and type(group["startAfterPrevious"]) is not bool)):
            raise ValueError("Invalid spawn group fields")
        if (type(group["count"]) is not int or group["count"] <= 0
                or type(group["interval"]) is not float or not math.isfinite(group["interval"]) or group["interval"] <= 0
                or type(group["startDelay"]) is not float or not math.isfinite(group["startDelay"]) or group["startDelay"] < 0):
            raise ValueError("Invalid spawn group numeric types/values")
        if "routeId" in group and (not isinstance(group["routeId"], str) or not group["routeId"].strip()):
            raise ValueError("Invalid spawn group routeId")
        group_id = group.get("id", f"g{group_index + 1:02}")
        if (not isinstance(group_id, str) or not group_id.strip() or group_id != group_id.strip()
                or group_id in ids):
            raise ValueError("Invalid/duplicate spawn group id")
        ids.add(group_id)
        start = group["startDelay"]
        if group.get("startAfterPrevious", False):
            follow = group.get("followDelay")
            if type(follow) is not float or not math.isfinite(follow) or follow < 0:
                raise ValueError("Invalid relative group followDelay")
            start = previous_end + follow
        requested_starts.append(start)
        previous_end = start + (group["count"] - 1) * group["interval"]
        events.extend((start + index * group["interval"], group["enemyType"], group.get("routeId"), group_index)
                      for index in range(group["count"]))
    # Stable sort: equal timestamps keep original group and member order.
    events.sort(key=lambda event: event[0])
    minimum_interval = SCHEDULING_POLICY["minimumInterval"]
    previous = -minimum_interval
    queue = []
    for requested, kind, route_id, group_index in events:
        actual = max(requested, previous + minimum_interval)
        if precision is not None:
            actual = round(actual, precision)
        if not math.isfinite(actual):
            raise ValueError("Non-finite spawn time")
        entry = {"enemyType": kind, "delay": actual}
        if route_id is not None:
            entry["routeId"] = route_id
        group_indices[group_index].append(len(queue))
        queue.append(entry)
        previous = actual
    return queue, group_indices, requested_starts


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

    routes = map_data.get("routes")
    if "routes" in map_data:
        if not isinstance(routes, list) or len(routes) < 2:
            raise ValueError("routes must contain at least two routes")
        ids = set()
        for route in routes:
            if (not isinstance(route, dict) or not {"id", "label", "path"} <= route.keys()
                    or set(route) - {"id", "label", "path", "teleportPairs", "spawnPortalId"}
                    or not isinstance(route["id"], str) or not route["id"].strip() or route["id"] != route["id"].strip()
                    or route["id"] in ids or not isinstance(route["label"], str) or not route["label"].strip()):
                raise ValueError("Invalid/duplicate map route")
            ids.add(route["id"])
            child = {key: value for key, value in map_data.items() if key not in ("routes", "teleportPairs", "spawnPortals")}
            child["path"] = route["path"]
            child["teleportPairs"] = route.get("teleportPairs", [])
            validate_map(child)
            route_path = route["path"]
            if (tiles[route_path[0][1] * columns + route_path[0][0]] != "spawn"
                    or route_path[-1] != path[-1]
                    or tiles[route_path[-1][1] * columns + route_path[-1][0]] != "core"
                    or any(tiles[p[1] * columns + p[0]] != "path" for p in route_path[1:-1])
                    or len({tuple(p) for p in route_path}) != len(route_path)):
                raise ValueError("Route must follow traversable tiles from spawn to common core")
        if routes[0]["path"] != path:
            raise ValueError("Default map path must match first route")

    if "spawnPortals" in map_data:
        portals = map_data["spawnPortals"]
        if not isinstance(portals, list) or not portals:
            raise ValueError("spawnPortals must be a nonempty array")
        by_id, cells = {}, set()
        for portal in portals:
            if (not isinstance(portal, dict) or set(portal) != {"id", "label", "cell"}
                    or not isinstance(portal["id"], str) or not portal["id"].strip()
                    or portal["id"] != portal["id"].strip() or portal["id"] in by_id
                    or not isinstance(portal["label"], str) or not portal["label"].strip()
                    or not valid_point(portal["cell"])
                    or tiles[portal["cell"][1] * columns + portal["cell"][0]] != "spawn"
                    or tuple(portal["cell"]) in cells):
                raise ValueError("Invalid/duplicate spawn portal")
            by_id[portal["id"]] = portal
            cells.add(tuple(portal["cell"]))
        used = set()
        if routes:
            for route in routes:
                portal_id = route.get("spawnPortalId")
                if not isinstance(portal_id, str) or portal_id not in by_id or by_id[portal_id]["cell"] != route["path"][0]:
                    raise ValueError("Route spawnPortalId must match its starting cell")
                used.add(portal_id)
        elif len(portals) != 1 or portals[0]["cell"] != path[0]:
            raise ValueError("Single-path map requires one matching spawn portal")
        else:
            used.add(portals[0]["id"])
        if used != set(by_id):
            raise ValueError("Unreferenced spawn portal")
        if cells != {(index % columns, index // columns) for index, tile in enumerate(tiles) if tile == "spawn"}:
            raise ValueError("Spawn portal registry must cover every spawn tile")
    elif routes and any("spawnPortalId" in route for route in routes):
        raise ValueError("Route spawnPortalId requires map spawnPortals")


def spawn_portal_id(map_data, route_id):
    if "spawnPortals" not in map_data:
        return "default"
    if not route_id:
        return map_data["spawnPortals"][0]["id"]
    return next(route["spawnPortalId"] for route in map_data["routes"] if route["id"] == route_id)


def group_dispatch_for(wave, map_data, group_indices, requested_starts):
    result = []
    for index, group in enumerate(wave["groups"]):
        indices = group_indices[index]
        route_id = group.get("routeId", "")
        result.append({"groupId": group.get("id", f"g{index + 1:02}"), "groupIndex": index,
                       "enemyType": group["enemyType"], "count": group["count"],
                       "routeId": route_id, "spawnPortalId": spawn_portal_id(map_data, route_id),
                       "requestedDispatch": requested_starts[index],
                       "firstDispatch": wave["spawnQueue"][indices[0]]["delay"],
                       "lastDispatch": wave["spawnQueue"][indices[-1]]["delay"], "spawnIndices": indices})
    return sorted(result, key=lambda row: (row["firstDispatch"], row["groupIndex"]))


def validate_group_dispatch(wave, map_data):
    rows, queue, groups = wave.get("groupDispatch"), wave["spawnQueue"], wave["groups"]
    fields = {"groupId", "groupIndex", "enemyType", "count", "routeId", "spawnPortalId",
              "requestedDispatch", "firstDispatch", "lastDispatch", "spawnIndices"}
    if not isinstance(rows, list) or len(rows) != len(groups):
        raise ValueError("Invalid groupDispatch coverage")
    used, seen, ids, order = set(), set(), set(), []
    requested_starts, previous_end = [], 0.0
    for group in groups:
        start = previous_end + group["followDelay"] if group.get("startAfterPrevious", False) else group["startDelay"]
        requested_starts.append(start)
        previous_end = start + (group["count"] - 1) * group["interval"]
    requested_order = [None] * len(queue)
    for row in rows:
        if not isinstance(row, dict) or set(row) != fields:
            raise ValueError("Invalid groupDispatch fields")
        index = row["groupIndex"]
        if type(index) is not int or not 0 <= index < len(groups) or index in seen:
            raise ValueError("Invalid/duplicate groupDispatch groupIndex")
        seen.add(index)
        group = groups[index]
        group_id = row["groupId"]
        if (not isinstance(group_id, str) or group_id != group.get("id", f"g{index + 1:02}") or group_id in ids
                or row["enemyType"] != group["enemyType"] or type(row["count"]) is not int
                or row["count"] != group["count"] or row["routeId"] != group.get("routeId", "")
                or row["spawnPortalId"] != spawn_portal_id(map_data, group.get("routeId", ""))):
            raise ValueError("groupDispatch identity differs from group/route/portal")
        ids.add(group_id)
        indices = row["spawnIndices"]
        if (not isinstance(indices, list) or len(indices) != group["count"]
                or any(type(i) is not int or not 0 <= i < len(queue) or i in used for i in indices)
                or indices != sorted(set(indices))):
            raise ValueError("Invalid groupDispatch spawn ownership")
        used.update(indices)
        for member, i in enumerate(indices):
            requested_order[i] = (requested_starts[index] + member * group["interval"], index, member)
            if queue[i]["enemyType"] != row["enemyType"] or queue[i].get("routeId", "") != row["routeId"]:
                raise ValueError("groupDispatch spawn identity differs")
        for key in ("requestedDispatch", "firstDispatch", "lastDispatch"):
            if type(row[key]) is not float or not math.isfinite(row[key]) or row[key] < 0:
                raise ValueError("Invalid groupDispatch dispatch time")
        if (row["requestedDispatch"] != requested_starts[index]
                or row["firstDispatch"] != queue[indices[0]]["delay"] or row["lastDispatch"] != queue[indices[-1]]["delay"]
                or row["firstDispatch"] + 1e-8 < row["requestedDispatch"]):
            raise ValueError("groupDispatch time differs from actual queue")
        order.append((row["firstDispatch"], index))
    if used != set(range(len(queue))) or order != sorted(order):
        raise ValueError("groupDispatch must cover queue in chronological order")
    if any(a > b for a, b in zip(requested_order, requested_order[1:])):
        raise ValueError("groupDispatch ownership violates stable source request order")
    for request, entry in zip(requested_order, queue):
        if entry["delay"] + 1e-8 < request[0]:
            raise ValueError("groupDispatch precedes its requested time")


def validate_wave_routes(map_data: dict, groups: list, queue: list | None = None):
    ids = {route["id"] for route in map_data.get("routes", [])}
    for entry in groups + (queue or []):
        route_id = entry.get("routeId")
        if "routeId" in entry and (not isinstance(route_id, str) or not route_id.strip() or route_id != route_id.strip()):
            raise ValueError("Invalid spawn routeId")
        if ids and route_id not in ids:
            raise ValueError("Missing/unknown spawn routeId")
        if not ids and "routeId" in entry:
            raise ValueError("routeId requires map routes")


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
    game["schedulingPolicy"] = copy.deepcopy(SCHEDULING_POLICY)
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
            wave["spawnQueue"], group_indices, requested_starts = schedule_for(wave["groups"], precision)
            validate_wave_routes(stage["map"], wave["groups"], wave["spawnQueue"])
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
            wave["groupDispatch"] = group_dispatch_for(wave, stage["map"], group_indices, requested_starts)
            validate_group_dispatch(wave, stage["map"])
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
