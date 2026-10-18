#!/usr/bin/env python3
"""Run the former Dart native regression matrix with an isolated Godot project."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from content_compiler import check_generated
from compile_progression import compile_progression
from compile_core_passive_tree import compile_core_tree
from prepare_godot_project import app_ui_source

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = {
    "verify_projectile_piercing.gd": "PROJECTILE_PIERCING checks=",
    "verify_piercing_content.gd": "PASS projectile gem content:",
    "verify_expanded_tree_combat.gd": "EXPANDED_TREE_COMBAT checks=",
    "verify_stockpile_firing.gd": None,
    "verify_expanded_tree_integration.gd": "EXPANDED_TREE_INTEGRATION checks=",
    "verify_expanded_core_tree.gd": "EXPANDED_CORE_TREE assertions=",
    "verify_gem_authority_protocol.gd": "GEM_AUTHORITY_PROTOCOL checks=",
    "verify_server_run_lifecycle.gd": "SERVER_RUN_LIFECYCLE checks=",
    "verify_gem_save_recovery.gd": "GEM_SAVE_RECOVERY checks=",
    "verify_gem_reroll.gd": "GEM_REROLL checks=",
    "verify_gem_reroll_ui.gd": "GEM_REROLL_UI checks=",
    "verify_gem_reroll_flip.gd": "GEM_REROLL_FLIP checks=",
    "verify_gem_deck.gd": "GEM_DECK checks=",
    "verify_fifth_link.gd": None,
    "verify_chapter_three_panels.gd": None,
    "verify_dispatch_portals.gd": None,
    "verify_chapter_three_normal_combat.gd": None,
    "verify_chapter_three_combat_checkpoint.gd": "PASS chapter three native-coordinate checkpoint and Continue UI contract",
    "verify_chapter_three_lifecycle.gd": None,
    "verify_enemy_routes.gd": None,
    "verify_runtime_content_format.gd": "PASS runtime content format:",
    "verify_catalog_session_boundaries.gd": "PASS catalog session boundaries:",
    "verify_battle_menu_parity.gd": "PASS battle menu parity:",
    "verify_account_modal.gd": "PASS account modal:",
    "verify_content_queries.gd": "PASS content queries:",
    "verify_menu_return.gd": "MENU_RETURN checks=",
    "verify_stage_expansion.gd": "STAGE_EXPANSION failures=0",
    "verify_growth_rules.gd": "PASS growth rules",
    "verify_content_catalog.gd": "PASS content catalog:",
    "verify_startup_screen.gd": "STARTUP_SCREEN failures=0",
    "verify_boot_load_lifecycle.gd": "BOOT_LOAD_LIFECYCLE checks=",
    "verify_economy_service.gd": "ECONOMY_SERVICE failures=0",
    "verify_result_settlement.gd": "failures=0",
    "verify_battle_result_entrance.gd": "RESULT_ENTRANCE checks=",
    "verify_gem_reward_entrance.gd": "GEM_REWARD_ENTRANCE checks=",
    "verify_gem_equip_burst.gd": "GEM_EQUIP_BURST checks=",
    "verify_update_service.gd": "UPDATE_SERVICE failures=0",
    "verify_legacy_combat_regressions.gd": "PASS legacy combat replacements:",
    "verify_shared_turret_stats.gd": "SHARED_TURRET_STATS checks=",
    "verify_native_combat_runtime.gd": "PASS native combat runtime:",
    "verify_fixed_combat_clock.gd": "FIXED_COMBAT_CLOCK checks=",
    "verify_lightning_target_priority.gd": "LIGHTNING_TARGET_PRIORITY checks=",
    "verify_turret_placement.gd": "TURRET_PLACEMENT checks=",
    "verify_battlefield_path.gd": "BATTLEFIELD_PATH checks=",
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
    "verify_async_checkpoint.gd": "failures=[]",
    "verify_quest_progress.gd": "quest progression Dart parity PASS:",
    "verify_reward_snapshot.gd": "authoritative snapshot Dart parity PASS:",
    "verify_reward_settlement.gd": '"ok":true',
    "verify_run_commands.gd": "failures=[]",
    "verify_hud_numbers.gd": "HUD_NUMBERS checks=",
    "verify_hud_number_layout.gd": "HUD_NUMBER_LAYOUT checks=",
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
    "verify_research_availability.gd": "PASS research availability:",
    "verify_research_slots.gd": "PASS research slots:",
    "verify_ui_confirmations.gd": "PASS ui confirmations:",
    "verify_module_draw_results.gd": "PASS module draw results:",
    "verify_lobby_core.gd": "PASS lobby core:",
    "verify_lobby_collection.gd": "PASS lobby_collection:",
    "verify_quest_claim_ui.gd": "QUEST_CLAIM_UI checks=",
    "verify_ui_layout_stability.gd": "PASS UI_LAYOUT_STABILITY",
    "verify_modal_refresh.gd": "MODAL_REFRESH checks=",
    "verify_lobby_stages.gd": "PASS stage restoration:",
    "verify_lobby_numbers.gd": "LOBBY_NUMBERS checks=",
    "verify_app_selection.gd": "PASS app selection:",
    "verify_app_presentation.gd": "PASS independent presentation:",
    "verify_combat_calculation.gd": None,
    "verify_turret_stat_calculation.gd": None,
}
# Shared helpers preloaded by the cases above; never run on their own.
HELPERS = ("verify_support_fixture_compare.gd", "verify_support_animation.gd", "verify_support_fake_battlefield.gd")
FIXTURES = (
    "chapter_three_map_signature_baseline.json", "combat_calculation.json",
    "turret_stat_calculation.json", "turret_stat_critical_boundaries.json", "native_wave_core_timing.json", "fixed_combat_clock_60hz.json",
    "quest_progress_cases.json", "reward_snapshot_cases.json",
    "growth_cases.json", "growth_game_cases.json", "growth_progression_cases.json", "game_content_cases.json",
    "research_prerequisite_cases.json",
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


CACHE = ROOT / "build/godot-native-regressions"
# Timing-sensitive cases (process restarts, fixed-clock replay, delayed HTTP and
# repeated UI layout) never overlap each other: they run one by one in a single
# lane beside the parallel pool, which leaves spare cores at the default jobs.
TIMEOUTS = {
    "verify_chapter_three_normal_combat.gd": 120, "verify_run_transition.gd": 120,
    "verify_result_settlement.gd": 60, "verify_fixed_combat_clock.gd": 60,
    "verify_gem_reroll_flip.gd": 60, "verify_gem_reroll.gd": 60,
    # These repeatedly create real app/save repositories; the checkpoint case
    # also drains real worker threads. Both exceed the short-case 20s budget on
    # CI under parallel load, so keep them in the bounded integration lane.
    "verify_server_run_lifecycle.gd": 60, "verify_async_checkpoint.gd": 60,
    # Enumerates every authored spawn and simulates all chapter endpoints.
    "verify_content_catalog.gd": 60,
}
SERIAL = frozenset(TIMEOUTS)
# Scripts and data load directly; only these need no editor import when changed.
UNIMPORTED = {".gd", ".json", ".gdshader"}
CLASS_NAME = re.compile(r"^class_name\s+(\w+)", re.M)


def isolated_environment(home: Path, temporary: Path) -> dict[str, str]:
    # Linux honors XDG paths before HOME. Override inherited app paths too so
    # every check (and import) stays in its own disposable save/cache directory.
    temporary.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, HOME=str(home), TMPDIR=str(temporary))
    for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"),
                        ("XDG_CONFIG_HOME", "config")):
        path = home / suffix
        path.mkdir(parents=True, exist_ok=True)
        environment[key] = str(path)
    return environment


def manifest() -> dict[str, Path | bytes]:
    """Every file of the regression project, keyed by its path below the cache root."""
    files: dict[str, Path | bytes] = {}
    def folder(source: Path, target: str, suffixes: set[str]) -> None:
        for path in sorted(source.iterdir()):
            if path.is_file() and path.suffix in suffixes:
                files[f"{target}/{path.name}"] = path
    for name in ("session", "ui", "content", "services"):
        folder(ROOT / "godot" / name, f"godot/{name}", {".gd", ".gdshader", ".json"})
    folder(ROOT / "godot/app", "godot/app", {".gd"})
    folder(ROOT / "godot/combat", "godot/combat", {".gd"})
    files["godot/environment/chapter_three_tiles.gd"] = ROOT / "godot/environment/chapter_three_tiles.gd"
    for name in ("turret_placement.gd", "battlefield_path.gd", "battlefield_path.gdshader", "stage_resources.gd", "frame_rows.gd"):
        files[f"godot/presentation/{name}"] = ROOT / "godot/presentation" / name
    for name in ("inputs", "expected"):
        files[f"godot/fixtures/godot_save_codec_{name}.json"] = ROOT / "test/fixtures" / f"godot_save_codec_{name}.json"
    for name in FIXTURES:
        files[f"test/fixtures/{name}"] = ROOT / "test/fixtures" / name
    for name in (*SCRIPTS, *HELPERS):
        files[f"godot/{name}"] = ROOT / "godot" / name
    for relative in json.loads((ROOT / "godot/ui/assets.json").read_text()):
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"Invalid UI asset path: {relative}")
        files[f"godot/assets/app/{path.as_posix()}"] = app_ui_source(ROOT, relative)
    shared = ROOT / "assets/images/stage1_3d/ui"
    for path in sorted(shared.rglob("*")):
        if path.is_file():
            files[f"godot/assets/ui/{path.relative_to(shared).as_posix()}"] = path
    for source, target in (("assets/images/diamond_currency.png", "diamond_currency.png"),
                           ("assets/fonts/NotoSansKR-VF.ttf", "NotoSansKR-VF.ttf"),
                           ("assets/fonts/MaterialIcons-Regular.otf", "MaterialIcons-Regular.otf")):
        files[f"godot/assets/ui/{target}"] = ROOT / source
    files["godot/project.godot"] = (b'[application]\nconfig/name="Native regression tests"\n'
                                    b'[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    return files


def synchronize(directory: Path, files: dict[str, Path | bytes]) -> set[str]:
    """Copies changed inputs, removes stale ones and returns the added or changed paths.

    Removals are not reported: nothing loads a removed input, and a removed
    class_name script changes the import signature on its own."""
    changed: set[str] = set()
    for relative, source in files.items():
        target = directory / relative
        existing = target.stat() if target.is_file() else None
        if isinstance(source, bytes):
            if existing and existing.st_size == len(source) and target.read_bytes() == source:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source)
            changed.add(relative)
            continue
        origin = source.stat()
        # Copies keep the source mtime, so unchanged inputs are never read.
        if existing and existing.st_size == origin.st_size:
            if existing.st_mtime_ns == origin.st_mtime_ns:
                continue
            if target.read_bytes() == source.read_bytes():
                os.utime(target, ns=(origin.st_atime_ns, origin.st_mtime_ns))
                continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        changed.add(relative)
    # Godot keeps its import data in .godot and in sidecars next to inputs.
    for root in (directory / "godot", directory / "test"):
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*"), reverse=True):
            relative = path.relative_to(directory).as_posix()
            if relative.startswith("godot/.godot"):
                continue
            if path.is_dir():
                if not any(path.iterdir()):
                    path.rmdir()
                continue
            owner = relative.removesuffix(".import").removesuffix(".uid")
            if relative not in files and owner not in files:
                path.unlink()
    return changed


def import_signature(directory: Path, executable: str) -> dict:
    classes = sorted(f"{path.relative_to(directory).as_posix()}:{name}"
                     for path in (directory / "godot").rglob("*.gd") if ".godot" not in path.parts
                     for name in CLASS_NAME.findall(path.read_text(encoding="utf-8", errors="replace")))
    return {"executable": str(Path(executable).resolve()), "classes": classes}


def prepare(directory: Path, executable: str) -> Path:
    return prepare_project(directory, executable)[0]


def prepare_project(directory: Path, executable: str) -> tuple[Path, bool]:
    """Builds or refreshes the project; the editor import only reruns when it can matter."""
    check_generated(ROOT)
    compile_progression(ROOT, check=True)
    compile_core_tree(ROOT, check=True)
    project = directory / "godot"
    state_path = directory / "import-state.json"
    changed = synchronize(directory, manifest())
    signature = import_signature(directory, executable)
    try:
        previous = json.loads(state_path.read_text())
    except (OSError, ValueError):
        previous = None
    if (previous == signature and (project / ".godot").is_dir()
            and all(Path(path).suffix in UNIMPORTED for path in changed)):
        return project, False
    state_path.unlink(missing_ok=True)
    imported = subprocess.run([executable, "--headless", "--editor", "--import",
                               "--path", str(project), "--quit"],
                              env=isolated_environment(directory / "import-home", directory / "import-tmp"),
                              text=True, capture_output=True, timeout=300)
    if imported.returncode:
        raise RuntimeError(f"Godot import failed:\n{imported.stdout}\n{imported.stderr}")
    state_path.write_text(json.dumps(signature, indent=2) + "\n")
    return project, True


def run_script(executable: str, project: Path, name: str, expected: str | None,
               temporary: Path) -> None:
    timeout = TIMEOUTS.get(name, 20)
    # user:// resolves under HOME; a per-case HOME and TMPDIR keep saves,
    # settings and temporary files apart, including while cases run in parallel.
    home = temporary / "home" / name.removesuffix(".gd")
    home.mkdir(parents=True, exist_ok=True)
    try:
        process = subprocess.run([executable, "--headless", "--path", str(project),
                                  "--script", f"res://{name}"],
                                 env=isolated_environment(home, temporary / "tmp" / name.removesuffix(".gd")),
                                 text=True, errors="replace", capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"{name} timed out after {timeout}s: {error.stdout} {error.stderr}") from error
    output = f"{process.stdout}\n{process.stderr}"
    # Only these controlled boot fixtures deliberately return ERR_FILE_CORRUPT.
    # Keep every other loader/script error fatal, including errors in this test.
    checked_output = output
    if name == "verify_boot_load_lifecycle.gd":
        checked_output = re.sub(
            r"(?m)^ERROR: Failed loading resource: res://boot-lifecycle-(?:retry|dispose-failed)\.bootprobe\.\n"
            r"[ \t]+at: _load \(core/io/resource_loader\.cpp:\d+\)\n?",
            "", output)
    if process.returncode or ERROR.search(checked_output):
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


def run_case(executable: str, project: Path, name: str, temporary: Path) -> dict:
    started = time.monotonic()
    try:
        run_script(executable, project, name, SCRIPTS[name], temporary)
        result = {"name": name, "status": "PASS"}
    except (OSError, RuntimeError, ValueError) as error:
        result = {"name": name, "status": "FAIL", "detail": str(error)[-4000:]}
    result["seconds"] = round(time.monotonic() - started, 3)
    print(f"{result['status']} {name} ({result['seconds']:.1f}s)", flush=True)
    return result


def execute(selected: list[str], jobs: int, fresh: bool) -> dict:
    """Runs every selected case; a failure never hides the cases after it."""
    report: dict = {"operation": "godot_native_regressions", "jobs": jobs, "errors": [],
                    "cases": {name: {"name": name, "status": "NOT_RUN"} for name in selected}}
    started = time.monotonic()
    try:
        executable = godot_executable()
        CACHE.mkdir(parents=True, exist_ok=True)
        with open(CACHE / ".lock", "w") as lock:
            # One run per checkout at a time: runs share the prepared project.
            fcntl.flock(lock, fcntl.LOCK_EX)
            if fresh:
                shutil.rmtree(CACHE / "godot", ignore_errors=True)
                (CACHE / "import-state.json").unlink(missing_ok=True)
            prepare_started = time.monotonic()
            project, report["imported"] = prepare_project(CACHE, executable)
            report["prepareSeconds"] = round(time.monotonic() - prepare_started, 3)
            print(f"Prepared regression project ({report['prepareSeconds']:.1f}s, "
                  f"{'imported' if report['imported'] else 'reused import'})", flush=True)
            with tempfile.TemporaryDirectory(prefix="native-regressions-") as directory:
                temporary = Path(directory)
                run = lambda name: run_case(executable, project, name, temporary)
                def serial_lane() -> list[dict]:
                    return [run(name) for name in selected if name in SERIAL]
                # The serial lane runs its cases one by one beside the parallel pool.
                with ThreadPoolExecutor(max_workers=1) as lane, ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
                    serial = lane.submit(serial_lane)
                    for result in pool.map(run, [name for name in selected if name not in SERIAL]):
                        report["cases"][result["name"]] = result
                    for result in serial.result():
                        report["cases"][result["name"]] = result
    except KeyboardInterrupt:
        report["errors"].append("interrupted")
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        report["errors"].append(str(error))
    report["seconds"] = round(time.monotonic() - started, 3)
    report["cases"] = list(report["cases"].values())
    counts = {status: sum(case["status"] == status for case in report["cases"]) for status in ("PASS", "FAIL", "NOT_RUN")}
    report["counts"] = counts
    report["status"] = "PASS" if counts["PASS"] == len(selected) and not report["errors"] else "FAIL"
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scripts", nargs="*", help="Run only named cases (default: all)")
    parser.add_argument("--jobs", type=int, default=max(1, min(8, (os.cpu_count() or 2) // 2)),
                        help="Parallel cases at once; the timing-sensitive group adds one serial lane")
    parser.add_argument("--fresh", action="store_true", help="Rebuild and reimport the cached project")
    parser.add_argument("--output", type=Path, help="Write case results, timings and failure details as JSON")
    args = parser.parse_args()
    selected = list(dict.fromkeys(args.scripts)) or list(SCRIPTS)
    unknown = set(selected) - SCRIPTS.keys()
    if unknown:
        parser.error("Unknown regression scripts: " + ", ".join(sorted(unknown)))
    report = execute(selected, args.jobs, args.fresh)
    failures = [case for case in report["cases"] if case["status"] == "FAIL"]
    for case in failures:
        print(f"\n=== FAIL {case['name']} ===\n{case['detail']}", file=sys.stderr)
    for error in report["errors"]:
        print(f"\n=== ERROR ===\n{error}", file=sys.stderr)
    slowest = sorted((case for case in report["cases"] if "seconds" in case), key=lambda case: -case["seconds"])[:5]
    if slowest:
        print("Slowest: " + ", ".join(f"{case['name']} {case['seconds']:.1f}s" for case in slowest))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts = report["counts"]
    if report["status"] == "PASS":
        print(f"PASS {len(selected)} Godot native regressions ({report['seconds']:.1f}s)")
        return 0
    print(f"FAIL Godot native regressions: {counts['PASS']} passed, {counts['FAIL']} failed, "
          f"{counts['NOT_RUN']} not run ({report['seconds']:.1f}s)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
