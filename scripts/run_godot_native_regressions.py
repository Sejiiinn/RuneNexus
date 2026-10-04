#!/usr/bin/env python3
"""Run the former Dart native regression matrix with an isolated Godot project."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from content_compiler import check_generated
from compile_progression import compile_progression

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = {
    "verify_runtime_content_format.gd": "PASS runtime content format:",
    "verify_catalog_session_boundaries.gd": "PASS catalog session boundaries:",
    "verify_battle_menu_parity.gd": "PASS battle menu parity:",
    "verify_account_modal.gd": "PASS account modal:",
    "verify_content_queries.gd": "PASS content queries:",
    "verify_stage_expansion.gd": "STAGE_EXPANSION failures=0",
    "verify_growth_rules.gd": "PASS growth rules",
    "verify_content_catalog.gd": "PASS content catalog:",
    "verify_startup_screen.gd": "STARTUP_SCREEN failures=0",
    "verify_economy_service.gd": "ECONOMY_SERVICE failures=0",
    "verify_result_settlement.gd": "failures=0",
    "verify_battle_result_entrance.gd": "RESULT_ENTRANCE checks=",
    "verify_gem_reward_entrance.gd": "GEM_REWARD_ENTRANCE checks=",
    "verify_update_service.gd": "UPDATE_SERVICE failures=0",
    "verify_legacy_combat_regressions.gd": "PASS legacy combat replacements:",
    "verify_shared_turret_stats.gd": "SHARED_TURRET_STATS checks=",
    "verify_native_combat_runtime.gd": "PASS native combat runtime:",
    "verify_turret_placement.gd": "TURRET_PLACEMENT checks=",
    "verify_native_session.gd": "PASS native session:",
    "verify_native_wave_core.gd": "PASS native wave/core:",
    "verify_native_core_defense.gd": "PASS native core defense:",
    "verify_native_enemy_state.gd": None,
    "verify_teleport_gimmick.gd": None,
    "verify_save_codec.gd": "SAVE_CODEC_FIXTURES count=",
    "verify_local_save_store.gd": None,
    "verify_run_save_adapter.gd": "failures=[]",
    "verify_content_run_save.gd": "CONTENT_RUN_SAVE failures=0",
    "verify_damage_event_collection.gd": "DAMAGE_EVENT_COLLECTION failures=[]",
    "verify_event_batch.gd": "EVENT_BATCH failures=[]",
    "verify_run_transition.gd": "RUN_TRANSITION failures=[]",
    "verify_quest_progress.gd": "quest progression Dart parity PASS:",
    "verify_reward_snapshot.gd": "authoritative snapshot Dart parity PASS:",
    "verify_reward_settlement.gd": '"ok":true',
    "verify_run_commands.gd": "failures=[]",
    "verify_battle_hud.gd": "PASS battle HUD:",
    "verify_battlefield_input.gd": "PASS battlefield input:",
    "verify_diamond_event.gd": "PASS diamond event:",
    "verify_battle_rewards.gd": "PASS battle rewards:",
    "verify_lobby.gd": "LOBBY_SMOKE_OK",
    "verify_modal_input.gd": "PASS modal input:",
    "verify_leaderboard_ui.gd": "failures=[]",
    "verify_mailbox_ui.gd": '"failures":[]',
    "verify_lobby_growth.gd": "PASS growth pages:",
    "verify_research_stop.gd": "PASS research stop:",
    "verify_research_details.gd": "PASS research details:",
    "verify_ui_confirmations.gd": "PASS ui confirmations:",
    "verify_module_draw_results.gd": "PASS module draw results:",
    "verify_lobby_core.gd": "PASS lobby core:",
    "verify_lobby_collection.gd": "PASS lobby_collection:",
    "verify_quest_claim_ui.gd": "QUEST_CLAIM_UI checks=",
    "verify_ui_layout_stability.gd": "PASS UI_LAYOUT_STABILITY",
    "verify_modal_refresh.gd": "MODAL_REFRESH checks=",
    "verify_lobby_stages.gd": "PASS stage restoration:",
    "verify_app_selection.gd": "PASS app selection:",
    "verify_app_presentation.gd": "PASS independent presentation:",
}
FIXTURES = (
    "turret_stat_calculation.json", "native_wave_core_timing.json",
    "quest_progress_cases.json", "reward_snapshot_cases.json",
    "growth_cases.json", "growth_game_cases.json", "growth_progression_cases.json", "game_content_cases.json",
)
ERROR = re.compile(r"(^|\n)\s*(?:SCRIPT ERROR:|ERROR:|Parse Error|Assertion failed)", re.I)


def godot_executable() -> str:
    configured = os.environ.get("GODOT_BIN") or os.environ.get("GODOT_EXECUTABLE")
    if configured:
        if not Path(configured).is_file():
            raise RuntimeError(f"Godot executable unavailable: {configured}")
        return configured
    for candidate in (shutil.which("godot"), shutil.which("godot4"),
                      ROOT / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot",
                      ROOT / "build/godot/tools/Godot.app/Contents/MacOS/Godot",
                      ROOT / "build/godot/tools/godot"):
        if candidate and Path(candidate).is_file():
            return str(candidate)
    raise RuntimeError("Godot executable unavailable; set GODOT_BIN")


def copy_files(source: Path, target: Path, suffixes: set[str]) -> None:
    target.mkdir(parents=True, exist_ok=True)
    for path in source.iterdir():
        if path.is_file() and path.suffix in suffixes:
            shutil.copy2(path, target / path.name)


def prepare(directory: Path, executable: str) -> Path:
    check_generated(ROOT)
    compile_progression(ROOT, check=True)
    project = directory / "godot"
    for folder in ("combat", "app", "fixtures", "content", "session", "ui", "services"):
        (project / folder).mkdir(parents=True, exist_ok=True)
    for folder in ("session", "ui", "content", "services"):
        copy_files(ROOT / "godot" / folder, project / folder, {".gd", ".gdshader", ".json"})
    copy_files(ROOT / "godot/app", project / "app", {".gd"})
    copy_files(ROOT / "godot/combat", project / "combat", {".gd"})
    (project / "presentation").mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "godot/presentation/turret_placement.gd", project / "presentation/turret_placement.gd")
    for name in ("inputs", "expected"):
        path = f"godot_save_codec_{name}.json"
        shutil.copy2(ROOT / "test/fixtures" / path, project / "fixtures" / path)
    (directory / "test/fixtures").mkdir(parents=True)
    for name in FIXTURES:
        shutil.copy2(ROOT / "test/fixtures" / name, directory / "test/fixtures" / name)
    for name in SCRIPTS:
        shutil.copy2(ROOT / "godot" / name, project / name)
    app_assets = project / "assets/app"
    for relative in json.loads((ROOT / "godot/ui/assets.json").read_text()):
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"Invalid UI asset path: {relative}")
        destination = app_assets / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "assets/images" / path, destination)
    shutil.copytree(ROOT / "assets/images/stage1_3d/ui", project / "assets/ui", dirs_exist_ok=True)
    for source, target in (("assets/images/diamond_currency.png", "diamond_currency.png"),
                           ("assets/fonts/NotoSansKR-VF.ttf", "NotoSansKR-VF.ttf"),
                           ("assets/fonts/MaterialIcons-Regular.otf", "MaterialIcons-Regular.otf")):
        shutil.copy2(ROOT / source, project / "assets/ui" / target)
    (project / "project.godot").write_text(
        '[application]\nconfig/name="Native regression tests"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    imported = subprocess.run([executable, "--headless", "--editor", "--import",
                               "--path", str(project), "--quit"],
                              text=True, capture_output=True, timeout=120)
    if imported.returncode:
        raise RuntimeError(f"Godot import failed:\n{imported.stdout}\n{imported.stderr}")
    return project


def run_script(executable: str, project: Path, name: str, expected: str | None,
               temporary: Path) -> None:
    # Transition durability cases deliberately restart isolated Godot processes.
    timeout = 60 if name == "verify_run_transition.gd" else 20
    try:
        process = subprocess.run([executable, "--headless", "--path", str(project),
                                  "--script", f"res://{name}"],
                                 env={**os.environ, "TMPDIR": str(temporary)},
                                 text=True, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"{name} timed out after {timeout}s: {error.stdout} {error.stderr}") from error
    output = f"{process.stdout}\n{process.stderr}"
    if process.returncode or ERROR.search(output):
        raise RuntimeError(f"{name} failed (exit {process.returncode}):\n{output}")
    if expected is not None:
        if expected not in output:
            raise RuntimeError(f"{name} missing expected marker {expected!r}:\n{output}")
    else:
        summaries = [line for line in output.splitlines() if line.startswith("{")]
        if len(summaries) != 1:
            raise RuntimeError(f"{name} expected one JSON summary:\n{output}")
        result = json.loads(summaries[0])
        if result.get("checks", 0) <= 0 or result.get("failures") != []:
            raise RuntimeError(f"{name} checks failed:\n{output}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scripts", nargs="*", help="Run only named cases (default: all)")
    args = parser.parse_args()
    selected = args.scripts or list(SCRIPTS)
    unknown = set(selected) - SCRIPTS.keys()
    if unknown:
        parser.error("Unknown regression scripts: " + ", ".join(sorted(unknown)))
    executable = godot_executable()
    with tempfile.TemporaryDirectory(prefix="native-regressions-") as directory:
        temporary = Path(directory)
        project = prepare(temporary, executable)
        for name in selected:
            run_script(executable, project, name, SCRIPTS[name], temporary)
            print(f"PASS {name}")
    print(f"PASS {len(selected)} Godot native regressions")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
