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
    "verify_app_lifecycle.gd": ("APP_LIFECYCLE failures=[]", {}),
    "verify_app_resume.gd": ("APP_RESUME failures=[]", {}),
    "verify_auxiliary_display_cache.gd": ("Auxiliary display cache verification: 0 failures", {}),
    "verify_battlefield_effects.gd": ("Battlefield effects:", {}),
    "verify_battlefield_labels.gd": ("Battlefield labels verification: 0 failures", {}),
    "verify_battlefield_selection.gd": ("Battlefield selection verification: 0 failures", {}),
    "verify_blast_lifecycle.gd": ("Blast lifecycle integration: PASS (0 failures)", {}),
    "verify_boss_death.gd": ("failures=[]", {}),
    "verify_boss_presentation.gd": ("BOSS_PRESENTATION failures=[]", {}),
    "verify_camera.gd": ("Camera verification: 0 failures", {}),
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
    "verify_session_controller.gd": ("PASS shared session controller:", {}),
    "verify_session_restart.gd": ("failures=[]", {"steps": [["write", "{tmp}/save"], ["read", "{tmp}/save"]]}),
    "verify_shared_textures.gd": ("Shared textures verification: 0 failures", {"args": ["{build}/shared_texture_manifest.json"]}),
    "verify_skinned_enemy_presentation.gd": ("SKINNED_ENEMY_PRESENTATION PASS failures=0", {}),
    "verify_sniper_model.gd": ("SNIPER_MODEL failures=[]", {}),
    "verify_sniper_vfx.gd": ("failures=[]", {}),
    "verify_stage_effect_cache.gd": ("STAGE_EFFECT_CACHE failures=[]", {}),
    "verify_stage_loading_feedback.gd": ("STAGE_LOADING_FEEDBACK checks=", {}),
    "verify_stage_resource_lifecycle.gd": ("STAGE_RESOURCE_LIFECYCLE checks=", {}),
    "verify_standalone_session.gd": ("PASS standalone stages", {}),
    "verify_target_geometry_preparation.gd": ("failures=[]", {}),
    "verify_turret_labels.gd": ("Turret labels verification: 0 failures", {}),
}
FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error|Assertion failed|: SKIP\b")


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
    """Sources prepare_godot_project.py copies must match, or results describe old code."""
    stale = []
    for path in SOURCE.rglob("*"):
        relative = path.relative_to(SOURCE)
        if not path.is_file() or relative.parts[:2] == ("content", "source") or path.suffix not in {".gd", ".tscn", ".gdshader", ".json", ".tres"}:
            continue
        copy = PROJECT / relative
        if not copy.is_file() or copy.read_bytes() != path.read_bytes():
            stale.append(str(relative))
    return stale


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
        output = f"{process.stdout}\n{process.stderr}"
        (home / f"output-{'-'.join(step) or 'run'}.log".replace("/", "_")).write_text(output)
        if process.returncode or FAILURE.search(output) or marker not in output:
            return f"exit {process.returncode}, marker {'found' if marker in output else 'missing'}\n{output[-4000:]}"
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scripts", nargs="*", help="Run only named cases (default: all)")
    parser.add_argument("--headless-only", action="store_true",
                        help="Do not run renderer cases; they are reported as not run, never as passed")
    args = parser.parse_args()
    unknown = set(args.scripts) - CASES.keys()
    if unknown:
        parser.error("Unknown project checks: " + ", ".join(sorted(unknown)))
    covered = set(CASES) | {path.name for path in SOURCE.glob("verify_support_*.gd")}
    for runner in (NATIVE_RUNNER, *SERVICE_RUNNERS):
        covered |= set(re.findall(r"verify_[a-z0-9_]+\.gd", runner.read_text()))
    unassigned = sorted(path.name for path in SOURCE.glob("verify_*.gd") if path.name not in covered)
    if unassigned:
        sys.exit("verify scripts without a runner: " + ", ".join(unassigned))
    if not PROJECT.joinpath("project.godot").is_file():
        sys.exit(f"{PROJECT} is missing; run scripts/prepare_godot_project.py first")
    stale = stale_project_files()
    if stale:
        sys.exit(f"{PROJECT} differs from godot/ ({len(stale)} files, e.g. {stale[0]}); run scripts/prepare_godot_project.py")
    executable = godot_executable()
    selected = args.scripts or list(CASES)
    not_run = [name for name in selected if args.headless_only and CASES[name][1].get("renderer")]
    failures = []
    with tempfile.TemporaryDirectory(prefix="godot-project-checks-") as directory:
        for name in selected:
            if name in not_run:
                continue
            started = time.monotonic()
            failure = run_case(executable, name, *CASES[name], Path(directory))
            print(f"{'FAIL' if failure else 'PASS'} {name} ({time.monotonic() - started:.1f}s)", flush=True)
            if failure:
                failures.append(name)
                print(failure, file=sys.stderr)
    for name in not_run:
        print(f"NOT RUN {name} (renderer required)")
    passed = len(selected) - len(not_run) - len(failures)
    print(f"{passed} passed, {len(failures)} failed, {len(not_run)} not run")
    if failures:
        sys.exit("failed: " + ", ".join(failures))


if __name__ == "__main__":
    main()
