#!/usr/bin/env python3
"""Run Godot checks that need the prepared project (assets, main scene, renderer).

run_godot_native_regressions.py owns the asset-free contract cases, and
verify_godot_{account,app}_services.py own the service cases. This runner covers
the remaining godot/verify_*.gd scripts against build/godot/project after
scripts/prepare_godot_project.py. Every case gets its own HOME/TMPDIR, so user
play saves and other work are untouched.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot"
BUILD = ROOT / "build/godot"
PROJECT = BUILD / "project"
NATIVE_RUNNER = ROOT / "scripts/run_godot_native_regressions.py"
SERVICE_RUNNERS = (ROOT / "scripts/verify_godot_account_services.py", ROOT / "scripts/verify_godot_app_services.py")

# name: (marker printed on success, options)
# renderer: MultiMesh transforms, GPU occlusion and panel instances are only real
# with a rendering device; headless runs of these cases would skip or misreport.
# args/steps: "{build}", "{root}" and "{tmp}" expand to the build folder, the
# repository and the case's isolated temporary folder.
CASES: dict[str, tuple[str, dict]] = {
    "verify_expanded_core_ui.gd": ("EXPANDED_CORE_UI failures=[]", {}),
    "verify_stockpile_indicator.gd": ("STOCKPILE_INDICATOR failures=[]", {"args":["--fixture"]}),
    "verify_additional_hp_ui.gd": ("ADDITIONAL_HP_UI failures=[]", {}),
    "verify_app_lifecycle.gd": ("APP_LIFECYCLE failures=[]", {}),
    "verify_app_resume.gd": ("APP_RESUME failures=[]", {}),
    "verify_native_frame_coalescing.gd": ("NATIVE_FRAME_COALESCING checks=", {}),
    "verify_auxiliary_display_cache.gd": ("Auxiliary display cache verification: 0 failures", {}),
    "verify_battlefield_effects.gd": ("Battlefield effects:", {}),
    "verify_battlefield_labels.gd": ("Battlefield labels verification: 0 failures", {}),
    "verify_battlefield_selection.gd": ("Battlefield selection verification: 0 failures", {}),
    "verify_blast_lifecycle.gd": ("Blast lifecycle integration: PASS (0 failures)", {}),
    "verify_boss_death.gd": ("failures=[]", {}),
    "verify_boss_presentation.gd": ("BOSS_PRESENTATION failures=[]", {}),
    "verify_camera.gd": ("Camera verification: 0 failures", {}),
    "verify_chapter_one_expansion_preview.gd": ("CHAPTER_ONE_EXPANSION_PREVIEW failures=[]",
                                               {"env": {"RUNE_EXPANSION_DESIGN_ROOT": "{root}/design/chapter1_map_expansion"}}),
    "verify_chapter_one_stages.gd": ("Chapter one stages verification: 0 failures",
                                     {"renderer": True, "args": ["{build}/chapter_one_frames.json"]}),
    "verify_chapter_two_stages.gd": ("Chapter two stages verification: 0 failures",
                                     {"renderer": True, "args": ["{build}/chapter_two_frames.json", "{build}/chapter_one_frames.json"]}),
    "verify_chapter_two_paving.gd": ("Chapter two paving: 0 failures",
                                     {"renderer": True, "args": ["{build}/chapter_two_frames.json"]}),
    "verify_chapter_three_stage.gd": ("Chapter three verification: 0 failures",
                                      {"renderer": True, "args": ["{build}/chapter_three_frames.json"]}),
    "verify_chapter_three_combat_render.gd": ("CH3_NORMAL_COMBAT_RENDER failures=[]", {"timeout": 240, "env": {"RUNE_CH3_CAPTURE_DIR": "{tmp}"}}),
    "verify_chapter_three_routes_render.gd": ("CH3_ROUTES_RENDER failures=[]", {"env": {"RUNE_CH3_CAPTURE_DIR": "{tmp}"}}),
    "verify_combat_presentation_determinism.gd": ("PRESENTATION_DETERMINISM cases=", {"args": ["--session"]}),
    "verify_combat_space_mask.gd": ("COMBAT_SPACE_MASK checks=", {}),
    "verify_compressed_field.gd": ("Compressed field verification: 0 failures",
                                   {"args": ["{root}/assets/images/stage1_3d/effects/cannon_field.bin"]}),
    "verify_content_restart.gd": ("failures=[]", {"steps": [["write", "{tmp}/save"], ["read", "{tmp}/save"]]}),
    "verify_content_session.gd": ("CONTENT_SESSION failures=[]", {}),
    "verify_death_presentation_delivery.gd": ("failures=0", {}),
    "verify_effect_preparation.gd": ("EFFECT_PREPARATION failures=[]", {}),
    "verify_effects_cache.gd": ("Effects cache:", {}),
    "verify_enemy_burn.gd": ("Enemy burn verification: 0 failures", {}),
    "verify_enemy_frost.gd": ("Enemy frost verification: 0 failures", {}),
    "verify_environment.gd": ("Environment verification: 0 failures", {"renderer": True}),
    "verify_environment_resource_lifetime.gd": ("Environment resource lifetime:", {}),
    "verify_frost_charge.gd": ("FROST_CHARGE_CHECK failures=[]", {}),
    "verify_gem_orbit.gd": ("gem_orbit: PASS", {}),
    "verify_gem_ui.gd": ("PASS gem UI:", {}),
    "verify_graphics_options.gd": ("Graphics options verification: PASS", {}),
    "verify_hud_native_frames.gd": ("PASS native HUD frames:", {}),
    "verify_impact_motion.gd": ("IMPACT_MOTION_CONTRACT PASS",
                                {"args": ["--fixture", "{root}/test/fixtures/godot/impact_seed_1404.json"]}),
    "verify_lightning_attack.gd": ("LIGHTNING_MODULE_PASS", {}),
    "verify_lobby_frame.gd": ("PASS lobby_frame:", {}),
    "verify_lobby_header.gd": ("PASS lobby_header:", {}),
    "verify_lobby_modal.gd": ("PASS lobby_modal:", {}),
    "verify_machinegun.gd": ("Machinegun verification: 0 failures", {"renderer": True}),
    "verify_machinegun_ricochet.gd": ("MACHINEGUN_RICOCHET checks=", {"renderer": True}),
    "verify_menu_shell_parity.gd": ("PASS menu shell:", {}),
    "verify_native_contracts.gd": ("Native candidate contracts:", {}),
    "verify_overlay_cache_integration.gd": ("PASS overlay cache integration:", {}),
    "verify_presentation_protocol.gd": ("Presentation protocol: 0 failures", {}),
    "verify_projectiles.gd": ("Projectile verification: 0 failures", {}),
    "verify_range_projection_cache.gd": ("RANGE_CACHE_TEST PASS", {}),
    "verify_reward_quest_session.gd": ("failures=[]", {"steps": [["write", "{tmp}/save"], ["read", "{tmp}/save"]]}),
    "verify_run_session.gd": ("RUN_SESSION failures=[]", {}),
    "verify_runic_fire.gd": ("RunicFire MultiMesh instance buffer: PASS", {"renderer": True}),
    "verify_runic_fire_integration.gd": ("Runic fire runtime integration failures: 0", {}),
    "verify_runtime.gd": ("Runtime verification: 0 failures", {}),
    "verify_scene.gd": ("GPU verified drone", {"renderer": True}),
    "verify_selection_lifecycle.gd": ("Selection lifecycle verification failures: 0", {}),
    "verify_session_controller.gd": ("PASS shared session controller:", {"expected_errors": (
        "ERROR: Combat runtime rejected: 전투 명령을 적용하지 못했습니다 (testRejected)",
        "ERROR: Combat runtime rejected: 전투를 시작하지 못했습니다 (testRejected)",
    )}),
    "verify_session_restart.gd": ("failures=[]", {"steps": [["write", "{tmp}/save"], ["read", "{tmp}/save"]]}),
    "verify_shared_textures.gd": ("Shared textures verification: 0 failures", {"args": ["{build}/shared_texture_manifest.json"]}),
    "verify_skinned_enemy_presentation.gd": ("SKINNED_ENEMY_PRESENTATION PASS failures=0", {}),
    "verify_shielded_presentation.gd": ("failures=[]", {}),
    "verify_shielded_death.gd": ("SHIELDED_DEATH failures=[]", {}),
    "verify_sniper_model.gd": ("SNIPER_MODEL failures=[]", {}),
    "verify_sniper_vfx.gd": ("failures=[]", {}),
    "verify_stage_effect_cache.gd": ("STAGE_EFFECT_CACHE failures=[]", {}),
    "verify_stage_loading_feedback.gd": ("STAGE_LOADING_FEEDBACK checks=", {}),
    "verify_stage_resource_lifecycle.gd": ("STAGE_RESOURCE_LIFECYCLE checks=", {}),
    "verify_standalone_session.gd": ("PASS standalone stages", {}),
    "verify_target_geometry_preparation.gd": ("failures=[]", {}),
    "verify_turret_labels.gd": ("Turret labels verification: 0 failures", {}),
}
# Small, explicit selections for the prepared-project contracts. Renderer cases
# remain opt-in by name; CI headless checks do not stand in for visual review.
PRESETS = {
    "session": (
        "verify_session_controller.gd", "verify_run_session.gd",
        "verify_session_restart.gd", "verify_content_restart.gd",
        "verify_combat_presentation_determinism.gd",
    ),
    "lifecycle": ("verify_app_lifecycle.gd", "verify_app_resume.gd"),
}
FAILURE = re.compile(r"(?:^|\n)\s*(?:SCRIPT ERROR:|ERROR:|Parse Error|Assertion failed)|: SKIP\b", re.I)


def godot_executable() -> str:
    configured = os.environ.get("GODOT_BIN") or os.environ.get("GODOT_EXECUTABLE")
    candidates = [configured] if configured else [
        ROOT / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot",
        ROOT / "build/godot/tools/Godot.app/Contents/MacOS/Godot",
        ROOT / "build/godot/tools/godot"]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)
    raise RuntimeError("Godot executable unavailable; set GODOT_BIN")


def stale_project_files() -> list[str]:
    """Compare copied runtime inputs, including settings and binary resources.

    prepare_godot_project.py excludes editor/authoring data and regenerates the
    assets directory and app_config.json. Documentation is not an execution
    input. Everything else is copied verbatim; an extension allowlist would
    silently omit new resource types (and previously omitted .res/.cfg).
    """
    stale = []
    for path in SOURCE.rglob("*"):
        relative = path.relative_to(SOURCE)
        if (not path.is_file() or ".godot" in relative.parts
                or relative.parts[:2] == ("content", "source")
                or relative.parts[0] == "assets" or relative == Path("app_config.json")
                or path.suffix == ".md"):
            continue
        copy = PROJECT / relative
        if not copy.is_file() or copy.read_bytes() != path.read_bytes():
            stale.append(str(relative))
    return stale


def import_project(executable: str, work: Path) -> None:
    """prepare_godot_project.py rewrites .import settings without importing, so
    resources fail to load until the editor imports them. With a current cache
    this is a ~2 s no-op; it runs in its own HOME like every case."""
    home = work / "import"
    home.mkdir(parents=True)
    environment = {**os.environ, "HOME": str(home), "TMPDIR": str(home)}
    imported = subprocess.run([executable, "--headless", "--editor", "--path", str(PROJECT), "--import", "--quit"],
                              env=environment, text=True, errors="replace", capture_output=True, timeout=600)
    output = imported.stdout + imported.stderr
    # Godot can log "ERROR: Error importing" and still exit 0.
    if imported.returncode or FAILURE.search(output):
        raise RuntimeError(f"Godot import failed (exit {imported.returncode})\n{output[-8000:]}")


def run_case(executable: str, name: str, marker: str, options: dict, work: Path) -> str | None:
    """Returns a failure description, or None when every step passed."""
    home = work / name.removesuffix(".gd")
    home.mkdir(parents=True)
    expand = lambda value: value.format(build=BUILD, root=ROOT, tmp=home)
    environment = {**os.environ, "HOME": str(home), "TMPDIR": str(home),
                   **{key: expand(value) for key, value in options.get("env", {}).items()}}
    command = [executable] + ([] if options.get("renderer") else ["--headless"])
    command += ["--path", str(PROJECT), "--script", f"res://{name}"]
    for step in options.get("steps", [options.get("args", [])]):
        arguments = ["--", *map(expand, step)] if step else []
        try:
            process = subprocess.run(command + arguments, env=environment, text=True, errors="replace",
                                     capture_output=True, timeout=options.get("timeout", 120))
        except subprocess.TimeoutExpired as error:
            # Assert-based scripts stop without quitting; a timeout is a failure.
            return f"timed out after {error.timeout}s\n{error.stdout or ''}{error.stderr or ''}"
        except OSError as error:
            return f"could not run Godot: {error}"
        output = f"{process.stdout}\n{process.stderr}"
        (home / f"output-{'-'.join(step) or 'run'}.log".replace("/", "_")).write_text(output)
        checked_output = output
        # Negative contract fixtures deliberately report these exact failures.
        # Each declared line must occur once; unrelated or repeated errors fail.
        for expected in options.get("expected_errors", ()):
            checked_output, count = re.subn(r"(?m)^" + re.escape(expected) + r"\r?$", "", checked_output)
            if count != 1:
                return f"expected exactly one fixture error {expected!r}, found {count}\n{output[-4000:]}"
        if process.returncode or FAILURE.search(checked_output) or marker not in output:
            return f"exit {process.returncode}, marker {'found' if marker in output else 'missing'}\n{output[-4000:]}"
    return None


def validate_project() -> None:
    covered = set(CASES) | {path.name for path in SOURCE.glob("verify_support_*.gd")}
    for runner in (NATIVE_RUNNER, *SERVICE_RUNNERS):
        covered |= set(re.findall(r"verify_[a-z0-9_]+\.gd", runner.read_text()))
    unassigned = sorted(path.name for path in SOURCE.glob("verify_*.gd") if path.name not in covered)
    if unassigned:
        raise RuntimeError("verify scripts without a runner: " + ", ".join(unassigned))
    if not PROJECT.joinpath("project.godot").is_file():
        raise RuntimeError(f"{PROJECT} is missing; run scripts/prepare_godot_project.py first")
    stale = stale_project_files()
    if stale:
        raise RuntimeError(f"{PROJECT} differs from godot/ ({len(stale)} files, e.g. {stale[0]}); run scripts/prepare_godot_project.py")


def source_revision() -> dict:
    """A dirty checkout is not described as the pristine commit being tested."""
    try:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        dirty = subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=no"], cwd=ROOT, text=True)
        return {"head": head, "tracked_dirty": bool(dirty)}
    except (OSError, subprocess.CalledProcessError):
        return {"head": None, "tracked_dirty": None}


def execute(selected: list[str], headless_only: bool, require_complete: bool) -> tuple[dict, int]:
    report = {
        "operation": "godot_project_checks", "project": str(PROJECT),
        "source": source_revision(), "engine": None,
        "headless_only": headless_only, "require_complete": require_complete,
        "scope": "selected automated contracts; visual and device review are separate",
        "cases": [{"name": name, "status": "NOT_RUN", "reason": "not started"} for name in selected],
        "errors": [],
    }
    try:
        validate_project()
        executable = godot_executable()
        version = subprocess.check_output([executable, "--version"], text=True, timeout=20).strip()
        report["engine"] = {"path": str(executable), "version": version}
        with tempfile.TemporaryDirectory(prefix="godot-project-checks-") as directory:
            import_project(executable, Path(directory))
            for result in report["cases"]:
                name = result["name"]
                if headless_only and CASES[name][1].get("renderer"):
                    result["reason"] = "renderer required"
                    print(f"NOT RUN {name} (renderer required)", flush=True)
                    continue
                started = time.monotonic()
                failure = run_case(executable, name, *CASES[name], Path(directory))
                result.update(status="FAIL" if failure else "PASS", seconds=round(time.monotonic() - started, 3))
                result.pop("reason")
                print(f"{result['status']} {name} ({result['seconds']:.1f}s)", flush=True)
                if failure:
                    result["detail"] = failure
                    print(failure, file=sys.stderr)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        report["errors"].append(str(error))
        print(str(error), file=sys.stderr)
    counts = {status: sum(case["status"] == status for case in report["cases"])
              for status in ("PASS", "FAIL", "NOT_RUN")}
    report["counts"] = counts
    report["status"] = "FAIL" if report["errors"] or counts["FAIL"] else "INCOMPLETE" if counts["NOT_RUN"] else "PASS"
    # Keep the old optional --headless-only exit behavior; CI opts into strict
    # completion. In either mode the report can never call NOT_RUN a pass.
    code = 1 if report["status"] == "FAIL" else 2 if require_complete and counts["NOT_RUN"] else 0
    report["exit_code"] = code
    print(f"{counts['PASS']} passed, {counts['FAIL']} failed, {counts['NOT_RUN']} not run")
    return report, code


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scripts", nargs="*", help="Run only named cases (default: all, or the selected presets)")
    parser.add_argument("--preset", action="append", choices=PRESETS, default=[],
                        help="Add an explicit contract group; may be repeated or combined with case names")
    parser.add_argument("--headless-only", action="store_true",
                        help="Do not run renderer cases; they are reported as not run, never as passed")
    parser.add_argument("--require-complete", action="store_true",
                        help="Exit 2 when any selected case is NOT_RUN (for CI)")
    parser.add_argument("--output", type=Path, help="Write the selected case results and failure details as JSON")
    args = parser.parse_args(argv)
    unknown = set(args.scripts) - CASES.keys()
    if unknown:
        parser.error("Unknown project checks: " + ", ".join(sorted(unknown)))
    selected = list(dict.fromkeys([name for preset in args.preset for name in PRESETS[preset]] + args.scripts)) or list(CASES)
    report, code = execute(selected, args.headless_only, args.require_complete)
    report["presets"] = args.preset
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return code


if __name__ == "__main__":
    sys.exit(main())
