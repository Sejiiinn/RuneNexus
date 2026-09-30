"""Validated fixed-ID progression metadata shared by content tools and generators."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path("godot/content/source/progression.json")


def _unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_nonfinite(value):
    raise ValueError(f"Non-finite JSON value: {value}")


def load_progression(root: Path = ROOT) -> dict:
    try:
        value = json.loads((root / SOURCE).read_text(encoding="utf-8"),
                           object_pairs_hook=_unique_pairs, parse_constant=_reject_nonfinite)
    except (OSError, ValueError) as error:
        raise ValueError(f"Cannot read progression registry: {error}") from error
    if (not isinstance(value, dict) or type(value.get("schemaVersion")) is not int
            or value["schemaVersion"] != 1):
        raise ValueError("Progression registry requires schemaVersion 1")
    for field in ("version", "legacyStageCount"):
        if type(value.get(field)) is not int or value[field] < 1:
            raise ValueError(f"Progression {field} must be a positive integer")
    stages, order = value.get("stages"), value.get("order")
    if not isinstance(stages, list) or not stages or not isinstance(order, list):
        raise ValueError("Progression stages and order must be nonempty arrays")
    ids, labels = set(), set()
    for stage in stages:
        if not isinstance(stage, dict):
            raise ValueError("Progression stage must be an object")
        for key in ("id", "chapter", "chapterStage", "rewardOrdinal"):
            if type(stage.get(key)) is not int or stage[key] < 1:
                raise ValueError(f"Progression stage {key} must be a positive integer")
        label = (stage["chapter"], stage["chapterStage"])
        if stage["id"] in ids or label in labels:
            raise ValueError("Progression stage IDs and chapter labels must be unique")
        ids.add(stage["id"])
        labels.add(label)
    if (any(type(stage_id) is not int for stage_id in order)
            or len(order) != len(ids) or set(order) != ids):
        raise ValueError("Progression order must contain each registered stage ID once")
    # Save/API stage bounds remain contiguous fixed IDs, while progression order is arbitrary.
    if ids != set(range(1, len(ids) + 1)):
        raise ValueError("Progression stages must retain contiguous fixed save IDs from 1")
    if not set(range(1, value["legacyStageCount"] + 1)).issubset(ids):
        raise ValueError("Progression must retain all legacy save IDs")
    for field in ("requirements", "legacyRequirements"):
        requirements = value.get(field)
        if not isinstance(requirements, dict):
            raise ValueError(f"Progression {field} must be an object")
        for kind, entries in requirements.items():
            if not isinstance(kind, str) or not kind or not isinstance(entries, dict):
                raise ValueError(f"Invalid {field} kind")
            for key, required in entries.items():
                if (not isinstance(key, str) or not key or type(required) is not int
                        or required != 0 and required not in ids):
                    raise ValueError(f"Invalid {field} requirement {kind}:{key}")
    seen = set()
    if not isinstance(value.get("unlockDisplay"), list):
        raise ValueError("Progression unlockDisplay must be an array")
    for item in value["unlockDisplay"]:
        if not isinstance(item, dict) or any(not isinstance(item.get(key), str) or not item[key]
                                           for key in ("kind", "key", "title", "icon", "category")):
            raise ValueError("Invalid unlock display metadata")
        key = (item["kind"], item["key"])
        if key in seen or not value["requirements"].get(key[0], {}).get(key[1]):
            raise ValueError(f"Unlock display requires one gated requirement: {key}")
        seen.add(key)
    return value


def stage_ordinals(root: Path = ROOT) -> dict[int, int]:
    return {stage_id: ordinal for ordinal, stage_id in enumerate(load_progression(root)["order"], 1)}
