#!/usr/bin/env python3
"""Materialize approved maps/schedules and ordinal durability for every fixed ID."""
import copy
import json
import math
from pathlib import Path

from stage_progression import stage_ordinals

ROOT = Path(__file__).resolve().parents[1]
DURABILITY_FIELDS = ("maxHp", "maxShield", "maxArmor")


def materialize(game, root=ROOT):
    """Preserve existing map/economy contracts; replace durability from definitions."""
    game = copy.deepcopy(game)
    prior_stages = {stage["id"]: stage for stage in game["stages"]}
    ordinals = stage_ordinals(root)
    ids = [stage["id"] for stage in game["stages"]]
    if len(ids) != len(set(ids)) or not set(range(1, 16)) <= set(ids) or set(ids) - ordinals.keys():
        raise ValueError("Content requires unique known IDs and every existing stage 1..15")
    original = sorted((s for s in game["stages"] if s["id"] <= 15), key=lambda s: s["id"])
    expanded = []
    for chapter, first_id in ((1, 16), (2, 21)):
        folder = root / f"design/chapter{chapter}_map_expansion"
        maps = json.loads((folder / "maps.json").read_text())["maps"]
        schedules = json.loads((folder / "rounds/rounds.json").read_text())["stages"]
        labels = [f"{chapter}-{n}" for n in range(6, 11)]
        if ([m["chapterStage"] for m in maps] != labels
                or [s["chapterStage"] for s in schedules] != labels):
            raise ValueError(f"Chapter {chapter} requires exactly its five approved expansion maps/schedules")
        for offset, (approved, schedule) in enumerate(zip(maps, schedules)):
            stage_id = first_id + offset
            if schedule["progressionOrdinal"] != ordinals[stage_id]:
                raise ValueError(f"Stage {stage_id} schedule ordinal differs from progression ORDER")
            game_map = {k: copy.deepcopy(approved[k]) for k in ("columns", "rows", "tileTheme", "tiles", "path")}
            if approved.get("teleportPairs"):
                game_map["teleportPairs"] = copy.deepcopy(approved["teleportPairs"])
            waves = [{"round": wave["round"], "previewText": wave["label"],
                      "clearRewardGold": wave["clearRewardGold"],
                      "groups": copy.deepcopy(wave["groups"]),
                      "spawnQueue": copy.deepcopy(wave["spawnQueue"])} for wave in schedule["rounds"]]
            expanded.append({"id": stage_id, "name": approved["name"],
                             "firstClearCorePointReward": 2, "firstClearTurretModuleTicketReward": 0,
                             "map": game_map, "waves": waves})
    game["stages"] = original + expanded
    for stage in game["stages"]:
        if [wave["round"] for wave in stage["waves"]] != list(range(1, 41)):
            raise ValueError(f"Stage {stage['id']} requires rounds 1..40")
        for wave in stage["waves"]:
            factor = 2 ** ((wave["round"] - 1) / 10) * 1.15 ** (ordinals[stage["id"]] - 1)
            computed = {
                kind: {field: float(definition[field] * factor) for field in DURABILITY_FIELDS}
                for kind, definition in game["enemyDefinitions"].items()}
            prior_waves = prior_stages.get(stage["id"], {}).get("waves", [])
            prior = next((w.get("enemyDurability", {}) for w in prior_waves if w["round"] == wave["round"]), {})
            # Keep already-correct serialized values, including historical
            # float multiplication rounding in chapter one, without ULP churn.
            for kind, values in computed.items():
                for field, value in values.items():
                    old = prior.get(kind, {}).get(field)
                    if type(old) is float and math.isclose(old, value, rel_tol=1e-12, abs_tol=1e-12):
                        values[field] = old
            wave["enemyDurability"] = computed
    return game


def apply():
    path = ROOT / "godot/content/game_content.json"
    game = materialize(json.loads(path.read_text()))
    path.write_text(json.dumps(game, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    apply()
