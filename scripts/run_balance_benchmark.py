#!/usr/bin/env python3
"""Run the headless balance bot (tool/balance_benchmark) in an isolated Godot project.

The project reuses the native regression manifest (runtime scripts and content
only) in its own cache directory, so saves and imports never touch the player
or the regression cache. Each bot process gets its own HOME.

Single process (options pass through to the bot):
    python3 scripts/run_balance_benchmark.py --stage=1 --mode=single --runes=300 --seeds=10

Parallel jobs (--job):
    campaign   trajectories in parallel, then each stage's margin at the account
               that cleared it:  --job=campaign --stages=1-20 --trajectories=3 --seeds=3
    checkpoint as campaign from a recommended-flow account (earlier stages cleared
               once); failed attempts add --farm-clears repeat clears:
               --job=checkpoint --stages=6-10 --trajectories=5 --farm-clears=3
    calibrate  one board per --types entry at a --runes account; fits typeFactors
               from actual damage in waves that hurt the core (saturated boards)
               and with --write stores them in calibration.json:
               --job=calibrate --stages=3,5,20,10,25,11,13 --seeds=2 --runes=3000 --cleared=1-20
    ab         same seeds for each --variants='[{...},{...}]' params set at a
               fixed account/stage/spend rate:  --job=ab --stage=5 --spend-rate=0.6

campaign/checkpoint store each trajectory's state after every clear in
run-*/checkpoints/t<n>/after-<id>/. --resume=<run folder> continues every
trajectory from the clear right before --stages under the same inputs (refused
when the fingerprint differs); --fork=<run folder> does the same on purpose with
changed inputs (new content, --params...) and records what differs.
    --job=checkpoint --resume=build/balance-benchmark/run-... --stages=26-30
--margins=0 skips the margin jobs that otherwise follow campaign/checkpoint.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import run_godot_native_regressions as regressions

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tool/balance_benchmark"
CALIBRATION = TOOL / "calibration.json"
# A second cache keeps a test run from rewriting the project a long run still loads.
CACHE = Path(os.environ.get("BALANCE_BENCHMARK_CACHE", ROOT / "build/godot-balance-benchmark")).resolve()
REPORTS = ROOT / "build/balance-benchmark"
# Turret-waves that hurt the core a type needs before calibrate fits from them alone.
MIN_PRESSURE_WAVES = 30


def manifest() -> dict[str, Path | bytes]:
    files = BASE_MANIFEST()
    files["godot/tools/balance_bot.gd"] = TOOL / "balance_bot.gd"
    if CALIBRATION.is_file():
        files["godot/tools/calibration.json"] = CALIBRATION
    return files


BASE_MANIFEST = regressions.manifest
regressions.manifest = manifest


class Runner:
    def __init__(self, timeout: int, jobs: int):
        self.executable = regressions.godot_executable()
        self.project = regressions.prepare(CACHE, self.executable)
        self.timeout = timeout
        self.jobs = jobs
        # The pid keeps launchers started in the same second apart.
        self.folder = REPORTS / f"{time.strftime('run-%Y%m%d-%H%M%S')}-{os.getpid()}"
        self.folder.mkdir(parents=True, exist_ok=True)
        self.count = 0

    def bot(self, label: str, bot_args: list[str]) -> dict:
        """Runs one bot process and returns its full JSON report."""
        report = self.folder / f"{label}.json"
        home = CACHE / "homes" / f"{label}-{os.getpid()}"
        environment = regressions.isolated_environment(home, CACHE / "tmp" / f"{label}-{os.getpid()}")
        command = [self.executable, "--headless", "--path", str(self.project), "--script",
                   "res://tools/balance_bot.gd", "--", *bot_args, f"--out={report}"]
        process = subprocess.run(command, env=environment, text=True, errors="replace",
                                 capture_output=True, timeout=self.timeout)
        output = f"{process.stdout}\n{process.stderr}"
        if process.returncode or "BALANCE_REPORT " not in output or regressions.ERROR.search(output):
            raise RuntimeError(f"{label} failed:\n{output[-4000:]}")
        return json.loads(report.read_text())

    def parallel(self, jobs: list[tuple[str, list[str]]]) -> list[dict]:
        with ThreadPoolExecutor(max_workers=self.jobs) as pool:
            return list(pool.map(lambda job: self.bot(*job), jobs))

    def engine(self) -> str:
        process = subprocess.run([self.executable, "--version"], text=True, capture_output=True, timeout=60)
        return process.stdout.strip()


def digest(chunks) -> str:
    hasher = hashlib.sha256()
    for chunk in chunks: hasher.update(chunk)
    return hasher.hexdigest()


def option_value(args: list[str], name: str, default: str = "") -> str:
    return next((arg.partition("=")[2] for arg in args if arg.partition("=")[0] == name), default)


def fingerprint(runner: Runner, mode: str, params: str, extra: list[str]) -> dict:
    """Inputs that decide what a stored trajectory state means: the project the bot
    runs (game code and content), the bot, the effective calibration, params and
    the account flow. Output paths, timeouts and job counts are left out."""
    files = manifest()
    bot = files.pop("godot/tools/balance_bot.gd")
    calibration = files.pop("godot/tools/calibration.json", None)
    def data(source): return source if isinstance(source, bytes) else Path(source).read_bytes()
    settings = json.loads(data(calibration)) if calibration is not None else {}
    settings.pop("_notes", None)
    return {"game": digest(name.encode() + b"\0" + data(files[name]) for name in sorted(files)),
            "bot": digest([data(bot)]),
            "calibration": json.dumps(settings, sort_keys=True),
            "params": json.dumps(json.loads(params), sort_keys=True) if params else "",
            "mode": mode,
            "farmClears": option_value(extra, "--farm-clears", "3") if mode == "checkpoint" else "",
            "engine": runner.engine()}


def resume_source(options, extra: list[str]) -> tuple[Path | None, dict]:
    """--resume/--fork run folder and its manifest; its params and bot options fill
    in whatever this call leaves out."""
    if not (options.resume or options.fork): return None, {}
    if options.resume and options.fork: raise SystemExit("use --resume or --fork, not both")
    source = Path(options.resume or options.fork).resolve()
    manifest_path = source / "manifest.json"
    if not manifest_path.is_file(): raise SystemExit(f"no run manifest in {source} (made before checkpoints?)")
    stored = json.loads(manifest_path.read_text())
    given = {arg.partition("=")[0] for arg in extra}
    extra[:0] = [arg for arg in stored["botArgs"] if arg.partition("=")[0] not in given]
    if not options.params: options.params = stored["params"]
    return source, stored


def resume_states(source: Path, stored: dict, first: int, trajectories: int) -> list[Path]:
    """Each trajectory's state at the clear right before the first stage. A missing
    trajectory fails the call: dropping it would change the measured group."""
    order = json.loads((ROOT / "godot/content/source/progression.json").read_text())["order"]
    position = order.index(first)
    if position == 0: raise SystemExit("nothing to resume before the first stage")
    previous = order[position - 1]
    states, missing = [], []
    for index in range(trajectories):
        folder = source / "checkpoints" / f"t{index + 1}" / f"after-{previous}"
        state = folder / "state.bin"
        info = folder / "manifest.json"
        if not info.is_file() or not state.is_file() or \
                json.loads(info.read_text())["stateSha256"] != hashlib.sha256(state.read_bytes()).hexdigest():
            missing.append(f"t{index + 1}")
        states.append(state)
    if missing: raise SystemExit(f"no complete state after stage {previous} for {missing} in {source}")
    return states


def margin_row(levels: list[dict]) -> dict:
    """Lowest spend rate every seed still cleared, and the rate where none did."""
    reliable = min((level["spendRate"] for level in levels if level["clearRate"] >= 1.0), default=None)
    broken = max((level["spendRate"] for level in levels if level["clearRate"] == 0.0), default=None)
    return {"reliableSpendRate": reliable, "brokenSpendRate": broken,
            "levels": [[level["spendRate"], round(level["clearRate"], 2), level["coreHp"]] for level in levels]}


DAMAGE_PARTS = ("direct", "splash", "chain", "burn")


def board_summary(boards: list[list[dict]]) -> dict:
    """Composition per board and each type's share of damage and damage kinds."""
    counts: dict[str, int] = {}
    damage: dict[str, float] = {}
    parts: dict[str, list[float]] = {}
    for turrets in boards:
        for turret in turrets:
            name = turret["type"]
            counts[name] = counts.get(name, 0) + 1
            damage[name] = damage.get(name, 0.0) + float(turret.get("damage", 0))
            split = turret.get("damageParts", [0, 0, 0, 0])
            parts[name] = [a + float(b) for a, b in zip(parts.get(name, [0.0] * 4), split)]
    total = sum(damage.values()) or 1.0
    return {"turretsPerBoard": {name: round(count / max(1, len(boards)), 1) for name, count in counts.items()},
            "damageShare": {name: round(value / total, 3) for name, value in sorted(damage.items(), key=lambda i: -i[1])},
            "damageKinds": {name: dict(zip(DAMAGE_PARTS, (round(v / (sum(split) or 1.0), 2) for v in split)))
                            for name, split in parts.items()}}


def campaign(runner: Runner, options, extra: list[str], mode: str = "campaign") -> dict:
    extra = list(extra)
    source, stored = resume_source(options, extra)
    count = stored.get("trajectories", options.trajectories)
    if source is not None and stored.get("mode") != mode:
        raise SystemExit(f"{source} is a {stored.get('mode')} run, not {mode}")
    current = fingerprint(runner, mode, options.params, extra)
    differs = sorted(key for key in current if source is not None and current[key] != stored["fingerprint"].get(key))
    if options.resume and differs:
        raise SystemExit(f"--resume refused, inputs differ from {source}: {differs} (use --fork for an experiment)")
    states = resume_states(source, stored, stage_ids(options.stages)[0], count) if source is not None else []
    (runner.folder / "manifest.json").write_text(json.dumps(
        {"mode": mode, "stages": options.stages, "trajectories": count, "params": options.params,
         "botArgs": extra, "fingerprint": current,
         "parent": None if source is None else {"run": options.resume or options.fork,
                                                "kind": "resume" if options.resume else "fork", "differs": differs}},
        ensure_ascii=False, indent=2) + "\n")
    if options.params: extra = [*extra, f"--params={options.params}"]
    jobs = [(f"{mode}-{index + 1}", [f"--mode={mode}", f"--stages={options.stages}", "--trajectories=1",
                                     f"--seed={1 + index * 100000}",
                                     f"--checkpoint-dir={runner.folder / 'checkpoints' / f't{index + 1}'}",
                                     *([f"--resume-state={states[index]}"] if states else []), *extra])
            for index in range(count)]
    reports = runner.parallel(jobs)
    trajectories = []
    for report in reports:
        rows = []
        for entry in report["trajectories"][0]["stages"]:
            last = entry["attempts"][-1]
            rows.append({"stage": entry["stage"], "cleared": entry["cleared"],
                         "wavesPerAttempt": [run["completedRounds"] for run in entry["attempts"]],
                         "runesInvested": last["runesInvestedBefore"], "corePoints": last["corePointsBefore"],
                         "farmClears": sum(run.get("farmedAfter", {}).get("clears", 0) for run in entry["attempts"]),
                         "research": last.get("researchBefore", {}), "clockHours": last.get("clockHoursBefore"),
                         "playHours": last.get("playHoursBefore"),
                         # A bot error ends the stage early; never read it as a plain failure.
                         "errors": [run["error"] for run in entry["attempts"] if run.get("error")],
                         "coreHp": round(last["coreHp"], 1), "coreMaxHp": round(last["coreMaxHp"], 1),
                         "turrets": sorted(((t["type"], t["level"]) for t in last["turrets"]), key=lambda t: -t[1])[:6],
                         "board": board_summary([last["turrets"]]),
                         "modules": [module[:3] for module in last.get("modulesBefore", [])]})
        trajectories.append(rows)
    errors = [(row["stage"], row["errors"]) for rows in trajectories for row in rows if row["errors"]]
    if errors: print(f"WARNING bot run errors: {errors}", file=sys.stderr)
    snapshots = reports[0]["clearSnapshots"] if options.margins else {}
    margin_jobs = []
    for stage_id, snapshot in snapshots.items():
        path = runner.folder / f"snapshot-{stage_id}.json"
        path.write_text(json.dumps(snapshot))
        margin_jobs.append((f"margin-{stage_id}", ["--mode=margin", f"--stage={stage_id}", f"--progression-file={path}",
                                                   f"--seeds={options.seeds}", *extra]))
    margins = {job[0].removeprefix("margin-"): margin_row(report["levels"])
               for job, report in zip(margin_jobs, runner.parallel(margin_jobs))}
    result = {"job": mode, "stages": options.stages, "trajectories": trajectories, "margins": margins}
    if source is not None: result["parent"] = json.loads((runner.folder / "manifest.json").read_text())["parent"]
    if "baseline" in reports[0]: result["baseline"] = reports[0]["baseline"]
    return result


def stage_ids(text: str) -> list[int]:
    if "-" in text and "," not in text:
        first, last = (int(value) for value in text.split("-"))
        order = json.loads((ROOT / "godot/content/source/progression.json").read_text())["order"]
        return order[order.index(first):order.index(last) + 1]
    return [int(value) for value in text.split(",")]


def calibrate(runner: Runner, options, extra: list[str]) -> dict:
    """Single-type boards at a weak account: each type alone, so none takes kills
    from another and the value model never has to pick an unfavoured type."""
    params = json.loads(options.params) if options.params else {}
    # Factors are relative to the machinegun, so it is always measured.
    types = list(dict.fromkeys(["machinegun", *options.types.split(",")]))
    jobs = [(f"calibrate-{stage_id}-{type_name}",
             ["--mode=single", f"--stage={stage_id}", f"--seeds={options.seeds}", f"--runes={options.runes}",
              f"--cleared={options.cleared}", f"--params={json.dumps({**params, 'typeShares': {type_name: 1.0}})}", *extra])
            for stage_id in stage_ids(options.stages) for type_name in types]
    totals: dict[str, dict[str, float]] = {}
    keys = ("predicted", "actual", "turretWaves", "pressurePredicted", "pressureActual", "pressureWaves")
    for (label, _), report in zip(jobs, runner.parallel(jobs)):
        type_name = label.rsplit("-", 1)[1]
        for run in report["runs"]:
            stats = run["typeStats"].get(type_name, {})
            row = totals.setdefault(type_name, dict.fromkeys(keys, 0.0))
            for key in keys:
                row[key] += stats.get(key, 0.0)
    current = json.loads(CALIBRATION.read_text()) if CALIBRATION.is_file() else {}
    # A type never built (locked by --cleared) has no samples and keeps its factor.
    unmeasured = sorted(name for name, row in totals.items() if row["predicted"] <= 0)
    measured = {name: row for name, row in totals.items() if row["predicted"] > 0}
    if "machinegun" not in measured:
        raise RuntimeError(f"calibrate: no machinegun samples to normalize against (unmeasured: {unmeasured})")
    # When a board clears a wave easily its turrets idle, so the stronger the type
    # the lower its actual/predicted ratio. Waves that hurt the core keep every
    # turret busy. Every type uses the same source so the ratios stay comparable:
    # those turret-waves when each type has enough, else all of them.
    pressure = all(row["pressureWaves"] >= MIN_PRESSURE_WAVES and row["pressurePredicted"] > 0
                   for row in measured.values())
    ratios = {name: (row["pressureActual"] / row["pressurePredicted"] if pressure else row["actual"] / row["predicted"])
              for name, row in measured.items()}
    fitted = {name: round(ratio / ratios["machinegun"], 3) for name, ratio in ratios.items()}
    # Types left out (frost: its value is the slow, tuned by ab through slowUptime)
    # or unmeasured keep their current factor.
    factors = {**current.get("typeFactors", {}), **fitted}
    result = {"job": "calibrate", "types": types, "totals": totals, "source": "pressure" if pressure else "all",
              "fitted": fitted, "unmeasured": unmeasured, "typeFactors": factors}
    if unmeasured: print(f"WARNING calibrate: no samples for {unmeasured}; their factors are unchanged", file=sys.stderr)
    if options.write:
        current["typeFactors"] = factors
        CALIBRATION.write_text(json.dumps(current, indent=2, sort_keys=True) + "\n")
        result["written"] = str(CALIBRATION.relative_to(ROOT))
    return result


def ab(runner: Runner, options, extra: list[str]) -> dict:
    variants = json.loads(options.variants)
    # Godot resolves relative paths against its own project, not this checkout.
    account = ([f"--progression-file={Path(options.progression_file).resolve()}"] if options.progression_file
               else [f"--runes={options.runes}"])
    # --params is the shared base; each variant overrides it.
    base = json.loads(options.params) if options.params else {}
    jobs = [(f"ab-{index}", ["--mode=single", f"--stage={options.stage}", f"--seeds={options.seeds}",
                             f"--spend-rate={options.spend_rate}", f"--params={json.dumps({**base, **variant})}", *account, *extra])
            for index, variant in enumerate(variants)]
    rows = []
    for variant, report in zip(variants, runner.parallel(jobs)):
        runs = report["runs"]
        errors = [run["error"] for run in runs if run.get("error")]
        rows.append({"params": variant, "errors": errors, "clearRate": sum(run["success"] for run in runs) / len(runs),
                     "meanWaves": round(sum(run["completedRounds"] for run in runs) / len(runs), 2),
                     "board": board_summary([run["turrets"] for run in runs]),
                     "meanCoreHp": round(sum(run["coreHp"] for run in runs) / len(runs), 2)})
    return {"job": "ab", "stage": options.stage, "spendRate": options.spend_rate, "variants": rows}


def main() -> int:
    # No prefix matching: --seed (a bot option) must not become --seeds.
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                     allow_abbrev=False)
    parser.add_argument("--timeout", type=int, default=3600, help="seconds before one bot process is stopped")
    parser.add_argument("--job", choices=["campaign", "checkpoint", "calibrate", "ab"])
    parser.add_argument("--jobs", type=int, default=6, help="parallel bot processes")
    parser.add_argument("--stages", default="1-5")
    parser.add_argument("--trajectories", type=int, default=3)
    parser.add_argument("--seeds", type=int, default=3)
    parser.add_argument("--runes", type=int, default=0)
    parser.add_argument("--cleared", default="1-10", help="calibrate: stages marked cleared for unlocks")
    parser.add_argument("--types", default="machinegun,cannon,flame,sniper,lightning,poison",
                        help="calibrate: turret types fitted, each on its own board")
    parser.add_argument("--params", default="")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--variants", default="[{}]")
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--spend-rate", type=float, default=1.0)
    parser.add_argument("--progression-file", default="")
    parser.add_argument("--resume", default="", help="campaign/checkpoint: continue this run folder's trajectories")
    parser.add_argument("--fork", default="", help="like --resume, but inputs may differ (recorded)")
    parser.add_argument("--margins", type=int, default=1, help="campaign/checkpoint: 0 skips the margin jobs")
    options, extra = parser.parse_known_args()
    started = time.monotonic()
    runner = Runner(options.timeout, options.jobs)
    if options.job is None:
        # Bot options pass through unchanged, including names the jobs share.
        report = runner.bot("single", _passthrough())
        print(json.dumps({key: report[key] for key in report if key not in ("runs", "trajectories", "levels", "margins",
                                                                           "clearSnapshots", "heuristics")},
                         ensure_ascii=False, indent=2))
    else:
        jobs = {"campaign": campaign, "checkpoint": lambda *a: campaign(*a, mode="checkpoint"),
                "calibrate": calibrate, "ab": ab}
        report = jobs[options.job](runner, options, extra)
        print(json.dumps(report, ensure_ascii=False, indent=1))
    report["wallSeconds"] = round(time.monotonic() - started, 1)
    (runner.folder / "summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"wall: {report['wallSeconds']}s  reports: {runner.folder.relative_to(ROOT)}")
    return 0


def _passthrough() -> list[str]:
    """Original arguments minus launcher-only options, for the single-process path."""
    launcher = {"--timeout", "--jobs", "--write", "--variants"}
    result = []
    for arg in sys.argv[1:]:
        name, _, value = arg.partition("=")
        if name in launcher: continue
        # Godot resolves relative paths against its own project, not this checkout.
        result.append(f"{name}={Path(value).resolve()}" if name == "--progression-file" and value else arg)
    return result


if __name__ == "__main__":
    sys.exit(main())
