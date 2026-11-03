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
    calibrate  explore runs that build every type; fits typeFactors from actual
               damage and with --write stores them in calibration.json:
               --job=calibrate --stages=1,3,17,20 --seeds=4
    ab         same seeds for each --variants='[{...},{...}]' params set at a
               fixed account/stage/spend rate:  --job=ab --stage=5 --spend-rate=0.6
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
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
CACHE = ROOT / "build/godot-balance-benchmark"
REPORTS = ROOT / "build/balance-benchmark"


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


def margin_row(levels: list[dict]) -> dict:
    """Lowest spend rate every seed still cleared, and the rate where none did."""
    reliable = min((level["spendRate"] for level in levels if level["clearRate"] >= 1.0), default=None)
    broken = max((level["spendRate"] for level in levels if level["clearRate"] == 0.0), default=None)
    return {"reliableSpendRate": reliable, "brokenSpendRate": broken,
            "levels": [[level["spendRate"], round(level["clearRate"], 2), level["coreHp"]] for level in levels]}


def campaign(runner: Runner, options, extra: list[str], mode: str = "campaign") -> dict:
    if options.params: extra = [*extra, f"--params={options.params}"]
    jobs = [(f"{mode}-{index + 1}", [f"--mode={mode}", f"--stages={options.stages}", "--trajectories=1",
                                     f"--seed={1 + index * 100000}", *extra])
            for index in range(options.trajectories)]
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
                         "turrets": sorted(((t["type"], t["level"]) for t in last["turrets"]), key=lambda t: -t[1])[:6]})
        trajectories.append(rows)
    errors = [(row["stage"], row["errors"]) for rows in trajectories for row in rows if row["errors"]]
    if errors: print(f"WARNING bot run errors: {errors}", file=sys.stderr)
    snapshots = reports[0]["clearSnapshots"]
    margin_jobs = []
    for stage_id, snapshot in snapshots.items():
        path = runner.folder / f"snapshot-{stage_id}.json"
        path.write_text(json.dumps(snapshot))
        margin_jobs.append((f"margin-{stage_id}", ["--mode=margin", f"--stage={stage_id}", f"--progression-file={path}",
                                                   f"--seeds={options.seeds}", *extra]))
    margins = {job[0].removeprefix("margin-"): margin_row(report["levels"])
               for job, report in zip(margin_jobs, runner.parallel(margin_jobs))}
    result = {"job": mode, "stages": options.stages, "trajectories": trajectories, "margins": margins}
    if "baseline" in reports[0]: result["baseline"] = reports[0]["baseline"]
    return result


def stage_ids(text: str) -> list[int]:
    if "-" in text and "," not in text:
        first, last = (int(value) for value in text.split("-"))
        order = json.loads((ROOT / "godot/content/source/progression.json").read_text())["order"]
        return order[order.index(first):order.index(last) + 1]
    return [int(value) for value in text.split(",")]


def calibrate(runner: Runner, options, extra: list[str]) -> dict:
    """Explore runs at a strong account so every unlocked type sees combat."""
    params = json.loads(options.params) if options.params else {}
    params["explore"] = True
    jobs = [(f"calibrate-{stage_id}", ["--mode=single", f"--stage={stage_id}", f"--seeds={options.seeds}",
                                       f"--runes={options.runes}", f"--cleared={options.cleared}",
                                       f"--params={json.dumps(params)}", *extra])
            for stage_id in stage_ids(options.stages)]
    totals: dict[str, dict[str, float]] = {}
    for report in runner.parallel(jobs):
        for run in report["runs"]:
            for type_name, stats in run["typeStats"].items():
                row = totals.setdefault(type_name, {"predicted": 0.0, "actual": 0.0, "turretWaves": 0})
                for key in row:
                    row[key] += stats[key]
    current = json.loads(CALIBRATION.read_text()) if CALIBRATION.is_file() else {}
    factors = dict(current.get("typeFactors", {}))
    ratios = {name: row["actual"] / row["predicted"] for name, row in totals.items() if row["predicted"] > 0}
    reference = ratios.get("machinegun") or (sum(ratios.values()) / len(ratios))
    fitted = {name: round(ratio / reference, 3) for name, ratio in ratios.items()}
    result = {"job": "calibrate", "totals": totals, "rawRatioToArrow": fitted}
    # Damage only: slows are tuned by ab, so frost keeps its value from dealt damage.
    result["typeFactors"] = fitted
    if options.write:
        current["typeFactors"] = fitted
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
    parser.add_argument("--params", default="")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--variants", default="[{}]")
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--spend-rate", type=float, default=1.0)
    parser.add_argument("--progression-file", default="")
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
