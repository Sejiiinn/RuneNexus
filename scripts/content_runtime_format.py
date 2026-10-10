#!/usr/bin/env python3
"""Versioned generated storage for the expanded content domain.

Schedules share exact typed content; returned expanded records are independently
owned. This codec does no balance calculation and reads no authoring sources.
"""
from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import re
import struct

SCHEMA_VERSION = 2
SPAWN_COLUMNS = ("enemyType", "delay")
ROUTE_SPAWN_COLUMNS = SPAWN_COLUMNS + ("routeId",)
DURABILITY_COLUMNS = ("maxHp", "maxShield", "maxArmor")
ROOT_FIELDS = {"schemaVersion", "units", "defaults", "randomization", "defenseConfig",
               "enemyDefinitions", "enemies", "turrets", "stages"}
STAGE_FIELDS = {"id", "name", "firstClearCorePointReward", "firstClearTurretModuleTicketReward", "map", "waves"}
WAVE_FIELDS = {"round", "previewText", "clearRewardGold", "groups", "spawnQueue", "enemyDurability"}
SCHEDULING_POLICY = {"version": 1, "scope": "global", "minimumInterval": 0.18,
                     "tieBreak": "source-group-member-order", "dispatchTimeBasis": "spawn-queue-seconds"}


def _dispatch_fields(game, base_fields, label):
    """Old fixture documents remain readable; the policy opts into a complete contract."""
    annotated = isinstance(game, dict) and "schedulingPolicy" in game
    _fields(game, base_fields | ({"schedulingPolicy"} if annotated else set()), label)
    if annotated:
        policy = game["schedulingPolicy"]
        _fields(policy, set(SCHEDULING_POLICY), "scheduling policy")
        if typed_digest(policy) != typed_digest(SCHEDULING_POLICY):
            raise ValueError("Unsupported scheduling policy")
    return annotated


def typed_digest(value) -> str:
    """Dictionary order is immaterial; list order and every number's type/bits matter."""
    def typed(item):
        if isinstance(item, dict):
            return ["object", [[key, typed(item[key])] for key in sorted(item)]]
        if isinstance(item, list):
            return ["array", [typed(child) for child in item]]
        if type(item) is float:
            return ["float", item.hex()]
        return [type(item).__name__, item]
    payload = json.dumps(typed(value), ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def schedule_digest(queue: list) -> str:
    """Cross-runtime exact queue identity: UTF-8 kinds and IEEE754 delay bits.

    Legacy queues retain rune-spawn-v1\0 and their original byte encoding.
    Routed queues use rune-spawn-routes-v1\0 and append a length-prefixed
    UTF-8 route ID after each delay (empty when the entry has no route ID).
    """
    if not isinstance(queue, list) or not queue:
        raise ValueError("Invalid/empty spawn schedule")
    routed = any(isinstance(entry, dict) and "routeId" in entry for entry in queue)
    payload = bytearray(b"rune-spawn-routes-v1\0" if routed else b"rune-spawn-v1\0")
    for entry in queue:
        _spawn_fields(entry)
        if type(entry["enemyType"]) is not str:
            raise ValueError("Invalid spawn enemyType")
        _float(entry["delay"], "spawn delay")
        kind = entry["enemyType"].encode("utf-8")
        payload.extend(struct.pack("<I", len(kind)))
        payload.extend(kind)
        payload.extend(struct.pack("<d", entry["delay"]))
        if routed:
            route = entry.get("routeId", "").encode("utf-8")
            payload.extend(struct.pack("<I", len(route)))
            payload.extend(route)
    return hashlib.sha256(payload).hexdigest()


def _fields(value, expected, label):
    if not isinstance(value, dict) or set(value) != expected:
        raise ValueError(f"Invalid {label} fields")


def _route_id(value):
    if type(value) is not str or not value or value != value.strip():
        raise ValueError("Invalid routeId")


def _spawn_fields(entry):
    if not isinstance(entry, dict) or set(entry) not in (set(SPAWN_COLUMNS), set(ROUTE_SPAWN_COLUMNS)):
        raise ValueError("Invalid spawn entry fields")
    if "routeId" in entry:
        _route_id(entry["routeId"])


def _integer(value, label, minimum=0):
    if type(value) is not int or value < minimum:
        raise ValueError(f"Invalid {label}: expected integer >= {minimum}")


def _float(value, label):
    if type(value) is not float or not math.isfinite(value) or value < 0:
        raise ValueError(f"Invalid {label}: expected finite nonnegative float")


def _json_values(value):
    if isinstance(value, dict):
        if any(type(key) is not str for key in value):
            raise ValueError("JSON object keys must be strings")
        for child in value.values(): _json_values(child)
    elif isinstance(value, list):
        for child in value: _json_values(child)
    elif type(value) is float:
        if not math.isfinite(value): raise ValueError("Non-finite runtime JSON number")
    elif value is not None and type(value) not in (str, int, bool):
        raise ValueError("Unsupported runtime JSON value")


def _queue(queue, enemies):
    if not isinstance(queue, list) or not queue:
        raise ValueError("Invalid/empty spawn schedule")
    previous = None
    for entry in queue:
        _spawn_fields(entry)
        if type(entry["enemyType"]) is not str or entry["enemyType"] not in enemies:
            raise ValueError("Unknown spawn enemyType")
        _float(entry["delay"], "spawn delay")
        if previous is not None and entry["delay"] - previous < 0.18 - 1e-8:
            raise ValueError("Invalid spawn schedule order/spacing")
        previous = entry["delay"]


def _metadata(game):
    _json_values(game)
    for field in ("units", "defaults", "randomization", "defenseConfig", "enemyDefinitions", "enemies", "turrets"):
        if not isinstance(game[field], dict) or not game[field]:
            raise ValueError(f"Invalid runtime {field}")
    enemies = set(game["enemies"])
    if enemies != set(game["enemyDefinitions"]):
        raise ValueError("Enemy template/base definition inventory differs")
    if not isinstance(game["stages"], list) or not game["stages"]:
        raise ValueError("Invalid runtime stages")
    return enemies


def _stage(stage):
    _fields(stage, STAGE_FIELDS, "stage")
    _integer(stage["id"], "stage id", 1)
    for field in ("firstClearCorePointReward", "firstClearTurretModuleTicketReward"):
        _integer(stage[field], field)
    if type(stage["name"]) is not str or not isinstance(stage["waves"], list) or not stage["waves"]:
        raise ValueError("Invalid stage name/waves")
    # Share map/group validation with the compiler; no source files are loaded.
    from content_compiler import validate_map
    if not isinstance(stage["map"], dict): raise ValueError("Invalid stage map")
    validate_map(stage["map"])


def _wave(wave, enemies, map_data):
    _integer(wave["round"], "wave round", 1)
    _integer(wave["clearRewardGold"], "clearRewardGold")
    if type(wave["previewText"]) is not str or not isinstance(wave["groups"], list) or not wave["groups"]:
        raise ValueError("Invalid wave preview/groups")
    from content_compiler import validate_wave_routes
    # Validate authoring records without reconstructing or re-sorting a schedule.
    group_ids = set()
    for index, group in enumerate(wave["groups"]):
        required = {"enemyType", "count", "interval", "startDelay"}
        allowed = required | {"id", "startAfterPrevious", "followDelay", "routeId"}
        if not isinstance(group, dict) or not required <= set(group) or set(group) - allowed:
            raise ValueError("Invalid spawn group fields")
        identifier = group.get("id", f"g{index + 1:02d}")
        if type(identifier) is not str or not identifier or identifier != identifier.strip() or identifier in group_ids:
            raise ValueError("Invalid/duplicate spawn group id")
        group_ids.add(identifier)
        _integer(group["count"], "spawn group count", 1)
        _float(group["interval"], "spawn group interval")
        if group["interval"] <= 0.0:
            raise ValueError("Invalid spawn group interval")
        _float(group["startDelay"], "spawn group startDelay")
        if "startAfterPrevious" in group and type(group["startAfterPrevious"]) is not bool:
            raise ValueError("Invalid spawn group relative flag")
        if group.get("startAfterPrevious", False):
            _float(group.get("followDelay"), "spawn group followDelay")
    validate_wave_routes(map_data, wave["groups"])
    if any(type(group["enemyType"]) is not str or group["enemyType"] not in enemies for group in wave["groups"]):
        raise ValueError("Unknown spawn group enemyType")
    durability = wave["enemyDurability"]
    if not isinstance(durability, dict) or set(durability) != enemies:
        raise ValueError("Incomplete enemy durability coverage")


def _order(game):
    ids = [stage["id"] for stage in game["stages"]]
    if ids != sorted(set(ids)):
        raise ValueError("Stage IDs must be unique and ordered")
    for stage in game["stages"]:
        rounds = [wave["round"] for wave in stage["waves"]]
        if rounds != list(range(1, len(rounds) + 1)):
            raise ValueError("Wave rounds must be contiguous and ordered")


def encode_runtime(game: dict) -> dict:
    """Copy expanded schema v1 into exact, deterministic runtime schema v2."""
    annotated = _dispatch_fields(game, ROOT_FIELDS, "expanded root")
    if type(game["schemaVersion"]) is not int or game["schemaVersion"] != 1:
        raise ValueError("Unsupported expanded content schemaVersion")
    enemies = _metadata(game)
    result = copy.deepcopy(game)
    result["schemaVersion"] = SCHEMA_VERSION
    result["runtimeFormat"] = {"spawnColumns": list(SPAWN_COLUMNS), "durabilityColumns": list(DURABILITY_COLUMNS)}
    schedules = {}
    for stage in result["stages"]:
        _stage(stage)
        for wave in stage["waves"]:
            _fields(wave, WAVE_FIELDS | ({"groupDispatch"} if annotated else set()), "expanded wave")
            _wave(wave, enemies, stage["map"])
            queue = wave["spawnQueue"]
            _queue(queue, enemies)
            from content_compiler import validate_wave_routes
            validate_wave_routes(stage["map"], wave["groups"], queue)
            if annotated:
                from content_compiler import validate_group_dispatch
                validate_group_dispatch(wave, stage["map"])
            del wave["spawnQueue"]
            identifier = "schedule_" + schedule_digest(queue)
            rows = [[entry[column] for column in (ROUTE_SPAWN_COLUMNS if "routeId" in entry else SPAWN_COLUMNS)] for entry in queue]
            if identifier in schedules and schedules[identifier] != rows:
                raise ValueError("Spawn schedule digest collision")
            schedules[identifier] = rows
            wave["spawnSchedule"] = identifier
            for kind, values in wave["enemyDurability"].items():
                _fields(values, set(DURABILITY_COLUMNS), "durability")
                for field in DURABILITY_COLUMNS: _float(values[field], field)
                wave["enemyDurability"][kind] = [values[field] for field in DURABILITY_COLUMNS]
    _order(result)
    result["spawnSchedules"] = {key: schedules[key] for key in sorted(schedules)}
    return result


def decode_runtime(document: dict) -> dict:
    """Validate and expand storage without sharing schedules between callers/waves."""
    annotated = _dispatch_fields(document, ROOT_FIELDS | {"runtimeFormat", "spawnSchedules"}, "runtime root")
    if type(document["schemaVersion"]) is not int or document["schemaVersion"] != SCHEMA_VERSION:
        raise ValueError("Unsupported runtime content schemaVersion")
    _fields(document["runtimeFormat"], {"spawnColumns", "durabilityColumns"}, "runtime format")
    if (document["runtimeFormat"]["spawnColumns"] != list(SPAWN_COLUMNS)
            or document["runtimeFormat"]["durabilityColumns"] != list(DURABILITY_COLUMNS)):
        raise ValueError("Unsupported runtime columns/order")
    enemies = _metadata(document)
    pools = document["spawnSchedules"]
    if not isinstance(pools, dict) or not pools:
        raise ValueError("Missing spawn schedules")
    queues = {}
    for identifier, rows in pools.items():
        if not re.fullmatch(r"schedule_[0-9a-f]{64}", identifier) or not isinstance(rows, list):
            raise ValueError("Invalid spawn schedule ID/rows")
        queue = []
        for row in rows:
            if not isinstance(row, list) or len(row) not in (len(SPAWN_COLUMNS), len(ROUTE_SPAWN_COLUMNS)):
                raise ValueError("Invalid spawn schedule row")
            queue.append(dict(zip(ROUTE_SPAWN_COLUMNS, row)))
        _queue(queue, enemies)
        if identifier != "schedule_" + schedule_digest(queue):
            raise ValueError("Spawn schedule content digest differs")
        queues[identifier] = queue
    result = copy.deepcopy(document)
    result["schemaVersion"] = 1
    del result["runtimeFormat"], result["spawnSchedules"]
    used = set()
    for stage in result["stages"]:
        _stage(stage)
        for wave in stage["waves"]:
            _fields(wave, WAVE_FIELDS - {"spawnQueue"} | {"spawnSchedule"} | ({"groupDispatch"} if annotated else set()), "runtime wave")
            _wave(wave, enemies, stage["map"])
            identifier = wave.pop("spawnSchedule")
            if type(identifier) is not str or identifier not in queues:
                raise ValueError("Missing/invalid spawn schedule reference")
            used.add(identifier)
            wave["spawnQueue"] = copy.deepcopy(queues[identifier])
            from content_compiler import validate_wave_routes
            validate_wave_routes(stage["map"], wave["groups"], wave["spawnQueue"])
            if annotated:
                from content_compiler import validate_group_dispatch
                validate_group_dispatch(wave, stage["map"])
            for kind, values in wave["enemyDurability"].items():
                if not isinstance(values, list) or len(values) != len(DURABILITY_COLUMNS):
                    raise ValueError("Invalid durability row")
                for value in values: _float(value, "durability value")
                wave["enemyDurability"][kind] = dict(zip(DURABILITY_COLUMNS, values))
    if used != set(queues): raise ValueError("Unreferenced spawn schedule")
    _order(result)
    return result


def load_compiled_content(path: Path) -> dict:
    """Read generated disk content, rejecting duplicate keys and invalid encoding."""
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result: raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result
    document = json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=pairs,
                          parse_constant=lambda value: (_ for _ in ()).throw(ValueError(f"Non-finite JSON value: {value}")))
    return decode_runtime(document)


def runtime_text(document: dict) -> str:
    """Render generated entity rows without hiding the named storage contract."""
    def compact(item):
        return json.dumps(item, ensure_ascii=False, allow_nan=False)
    def render(item, depth=0, key=None, columns=None):
        prefix = "  " * depth
        if isinstance(item, dict):
            if not item or key == "wave" or all(not isinstance(child, (dict, list)) for child in item.values()):
                return compact(item)
            rows = [compact(name) + ": " + render(child, depth + 1, name, item.get("columns") if key == "map" else None)
                    for name, child in item.items()]
            return "{\n" + ",\n".join("  " + prefix + row for row in rows) + "\n" + prefix + "}"
        if isinstance(item, list):
            if key == "tiles" and type(columns) is int and columns > 0:
                rows = [", ".join(compact(tile) for tile in item[start:start + columns])
                        for start in range(0, len(item), columns)]
                return "[\n" + ",\n".join("  " + prefix + row for row in rows) + "\n" + prefix + "]"
            if (key and key.startswith("schedule_")) or not item or all(not isinstance(child, (dict, list)) for child in item):
                return compact(item)
            child_key = "wave" if key == "waves" else None
            return "[\n" + ",\n".join("  " + prefix + render(child, depth + 1, child_key) for child in item) + "\n" + prefix + "]"
        return compact(item)
    return render(document) + "\n"
