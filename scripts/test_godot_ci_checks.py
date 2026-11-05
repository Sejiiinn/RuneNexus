"""CI stage and verdict semantics, using stand-in processes instead of Godot."""
import contextlib
import io
from pathlib import Path
import re
import stat
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

import run_godot_ci_checks as ci
import run_godot_native_regressions as regressions


def python_stage(name, code, needs=()):
    return ci.Stage(name, "test", (sys.executable, "-c", code), needs)


class StageRunnerTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)

    def run_all(self, *stages):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            results = ci.run_stages(stages)
            code = ci.report(results)
        return code, {result["name"]: result for result in results}, output.getvalue()

    def touch(self, name):
        return f"from pathlib import Path; Path({str(self.work / name)!r}).touch()"

    def test_all_passing_stages_exit_zero(self):
        code, results, _ = self.run_all(python_stage("first", "pass"), python_stage("second", "pass"))
        self.assertEqual(code, 0)
        self.assertEqual([result["status"] for result in results.values()], ["PASS", "PASS"])

    def test_failure_runs_later_independent_stages_and_reports_every_failure(self):
        code, results, output = self.run_all(
            python_stage("first", "print('first detail'); raise SystemExit(3)"),
            python_stage("second", self.touch("second")),
            python_stage("third", "print('third detail'); raise SystemExit(1)"))
        self.assertEqual(code, 1)
        self.assertTrue((self.work / "second").exists(), "a failure must not skip an independent stage")
        self.assertEqual({name: result["status"] for name, result in results.items()},
                         {"first": "FAIL", "second": "PASS", "third": "FAIL"})
        summary = output[output.index("=== Godot checks"):]
        for expected in ("FAIL first (exit 3", "PASS second", "FAIL third (exit 1", "first detail", "third detail"):
            self.assertIn(expected, summary)

    def test_failed_prerequisite_blocks_only_its_dependent_and_fails_the_run(self):
        code, results, output = self.run_all(
            python_stage("pack", "raise SystemExit(1)"),
            python_stage("uses-pack", self.touch("dependent"), needs=("pack",)),
            python_stage("independent", self.touch("independent")))
        self.assertEqual(code, 1)
        self.assertEqual(results["uses-pack"]["status"], "BLOCKED")
        self.assertFalse((self.work / "dependent").exists())
        self.assertTrue((self.work / "independent").exists())
        self.assertIn("BLOCKED uses-pack (needs pack)", output)

    def test_blocked_stage_alone_fails_the_run(self):
        code, _, _ = self.run_all(python_stage("uses-pack", "pass", needs=("pack",)))
        self.assertEqual(code, 1)

    def test_passing_prerequisite_runs_dependent(self):
        code, _, _ = self.run_all(python_stage("pack", "pass"),
                                  python_stage("uses-pack", self.touch("dependent"), needs=("pack",)))
        self.assertEqual(code, 0)
        self.assertTrue((self.work / "dependent").exists())

    def test_signal_death_and_missing_command_fail_closed(self):
        code, results, _ = self.run_all(
            python_stage("killed", "import os, signal; os.kill(os.getpid(), signal.SIGKILL)"),
            ci.Stage("missing", "test", (str(self.work / "not-a-command"),)))
        self.assertEqual(code, 1)
        self.assertEqual(results["killed"]["status"], "FAIL")
        self.assertLess(results["killed"]["code"], 0)
        self.assertEqual(results["missing"]["status"], "FAIL")

    def test_no_results_cannot_pass(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ci.report([]), 1)

    def test_shared_action_runs_the_stage_runner_without_masking_failures(self):
        action = (ci.ROOT / ".github/actions/godot-checks/action.yml").read_text()
        self.assertIn('run: python3 scripts/run_godot_ci_checks.py --group "$GROUP"', action)
        for masking in ("continue-on-error", "|| true", "set +e"):
            self.assertNotIn(masking, action)

    def test_independent_checks_stay_independent(self):
        self.assertEqual({stage.name: stage.needs for stage in ci.STAGES if stage.needs},
                         {"prepared-project": ("godot-pack",)})

    def test_groups_partition_the_stages_and_keep_dependencies_together(self):
        self.assertEqual(ci.select("all"), ci.STAGES)
        self.assertCountEqual([stage for group in ci.GROUPS for stage in ci.select(group)], ci.STAGES)
        groups = {stage.name: stage.group for stage in ci.STAGES}
        for stage in ci.STAGES:
            for need in stage.needs:
                self.assertEqual(groups[need], stage.group)

    def test_push_matrix_runs_every_group_and_never_stops_the_others(self):
        workflow = (ci.ROOT / ".github/workflows/checks.yml").read_text()
        matrix = re.search(r"group: \[(.+)\]", workflow).group(1).split(", ")
        self.assertCountEqual(matrix, ["go", *ci.GROUPS])
        self.assertIn("fail-fast: false", workflow)
        self.assertIn("group: ${{ matrix.group }}", workflow)

    def test_release_runs_every_stage_on_its_one_runner(self):
        action = (ci.ROOT / ".github/actions/godot-checks/action.yml").read_text()
        self.assertRegex(action, r"group:\n(?:\s+description:.*\n)\s+default: all\n")
        release = (ci.ROOT / ".github/workflows/deploy-apk.yml").read_text()
        self.assertIn("uses: ./.github/actions/godot-checks\n\n", release)

    def test_unknown_group_is_rejected(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            ci.main(["--group", "nothing"])
        self.assertEqual(caught.exception.code, 2)


class NativeVerdictTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.godot = self.work / "godot"

    def verdict(self, body, expected="DONE", name="verify_case.gd"):
        self.godot.write_text(f"#!{sys.executable}\n" + textwrap.dedent(body))
        self.godot.chmod(self.godot.stat().st_mode | stat.S_IXUSR)
        regressions.run_script(str(self.godot), self.work, name, expected, self.work)

    def test_marker_and_clean_exit_pass(self):
        self.verdict("print('DONE')\n")

    def test_clean_exit_with_engine_error_is_a_failure_named_as_such(self):
        with self.assertRaisesRegex(RuntimeError, r"reported an engine error \(exit 0\)"):
            self.verdict("print('DONE'); print('SCRIPT ERROR: Invalid access')\n")

    def test_nonzero_exit_fails_even_with_the_marker(self):
        with self.assertRaisesRegex(RuntimeError, r"failed \(exit 1\)"):
            self.verdict("print('DONE'); raise SystemExit(1)\n")

    def test_missing_marker_fails(self):
        with self.assertRaisesRegex(RuntimeError, "missing expected marker"):
            self.verdict("print('other')\n")

    def test_failed_json_summary_fails(self):
        with self.assertRaisesRegex(RuntimeError, "checks failed"):
            self.verdict("""print('{"checks":1,"failures":["x"]}')\n""", expected=None)

    def test_timeout_reports_decoded_output(self):
        with patch.dict(regressions.TIMEOUTS, {"verify_case.gd": 1}):
            with self.assertRaises(RuntimeError) as caught:
                self.verdict("import time; print('started', flush=True); time.sleep(30)\n")
        self.assertIn("timed out after 1s:\nstarted", str(caught.exception))

    def test_pooled_cases_are_named_long_cases(self):
        self.assertLessEqual(regressions.POOLED, set(regressions.TIMEOUTS))
        self.assertFalse(regressions.POOLED & regressions.SERIAL)


if __name__ == "__main__":
    unittest.main()
