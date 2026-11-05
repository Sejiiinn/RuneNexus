#!/usr/bin/env python3
"""Run every check of the shared Godot CI action and report all failures together.

A failed stage never stops an independent one: a stage waits only for the stages
whose output it needs, and one blocked that way counts as failed. The run passes
only when every stage passed, so the APK release cannot continue past a failure.
"""
from __future__ import annotations

from collections import deque
from dataclasses import dataclass
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
TAIL_LINES = 40


@dataclass(frozen=True)
class Stage:
    name: str
    command: tuple[str, ...]
    needs: tuple[str, ...] = ()


def script(name: str, *arguments: str) -> tuple[str, ...]:
    return (sys.executable, f"scripts/{name}", *arguments)


STAGES = (
    Stage("python-unit", (sys.executable, "-m", "unittest", "discover", "-s", "scripts", "-p", "test_*.py")),
    Stage("godot-content", script("verify_godot_content.py")),
    Stage("native-regressions", script("run_godot_native_regressions.py")),
    Stage("account-services", script("verify_godot_account_services.py")),
    Stage("app-services", script("verify_godot_app_services.py")),
    Stage("godot-pack", script("build_godot_pack.py")),
    # Runs inside the project the pack step prepares.
    Stage("prepared-project", script("run_godot_project_checks.py",
                                     "--preset", "session", "--preset", "lifecycle",
                                     "--headless-only", "--require-complete",
                                     "--output", "build/godot-project-checks.json"),
          needs=("godot-pack",)),
)


def environment() -> dict[str, str]:
    # The verifiers read GODOT_BIN and the pack builder GODOT_EXECUTABLE.
    values = dict(os.environ)
    configured = values.get("GODOT_BIN") or values.get("GODOT_EXECUTABLE")
    if configured:
        values.setdefault("GODOT_BIN", configured)
        values.setdefault("GODOT_EXECUTABLE", configured)
    return values


def run_stage(stage: Stage) -> dict:
    """Streams one stage live and keeps its last lines for the closing report."""
    started = time.monotonic()
    tail: deque[str] = deque(maxlen=TAIL_LINES)
    code: int | None = None
    try:
        with subprocess.Popen(stage.command, cwd=ROOT, env=environment(), text=True, errors="replace",
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as process:
            for line in process.stdout:
                print(line, end="", flush=True)
                tail.append(line)
            code = process.wait()
    except OSError as error:
        tail.append(f"could not start: {error}\n")
    return {"name": stage.name, "status": "PASS" if code == 0 else "FAIL", "code": code,
            "seconds": round(time.monotonic() - started, 1), "tail": list(tail)}


def run_stages(stages: tuple[Stage, ...]) -> list[dict]:
    results: list[dict] = []
    passed: set[str] = set()
    annotate = "GITHUB_ACTIONS" in os.environ
    for stage in stages:
        missing = [need for need in stage.needs if need not in passed]
        if missing:
            results.append({"name": stage.name, "status": "BLOCKED", "needs": missing})
            continue
        if annotate:
            print(f"::group::{stage.name}", flush=True)
        else:
            print(f"=== {stage.name} ===", flush=True)
        result = run_stage(stage)
        if annotate:
            print("::endgroup::", flush=True)
        results.append(result)
        if result["status"] == "PASS":
            passed.add(stage.name)
    return results


def report(results: list[dict]) -> int:
    """Prints every stage's outcome and returns the exit code; only all-PASS is 0."""
    failed = [result for result in results if result["status"] != "PASS"]
    print(f"\n=== Godot checks: {len(results) - len(failed)} of {len(results)} stages passed ===")
    for result in results:
        if result["status"] == "BLOCKED":
            print(f"BLOCKED {result['name']} (needs {', '.join(result['needs'])})")
        else:
            print(f"{result['status']} {result['name']} (exit {result['code']}, {result['seconds']}s)")
    for result in failed:
        if result["status"] == "FAIL":
            print(f"\n--- {result['name']}: last {len(result['tail'])} lines ---")
            print("".join(result["tail"]), end="")
    if "GITHUB_ACTIONS" in os.environ:
        for result in failed:
            print(f"::error title=Godot checks::{result['name']} {result['status']}")
    return 1 if failed or not results else 0


def main() -> int:
    return report(run_stages(STAGES))


if __name__ == "__main__":
    sys.exit(main())
